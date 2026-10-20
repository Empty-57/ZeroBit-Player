import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/core/network/apis.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_button/app_tappable.dart';
import 'package:zerobit_player/core/widgets/app_card.dart';
import 'package:zerobit_player/core/widgets/app_dialog.dart';
import 'package:zerobit_player/core/widgets/app_interaction_widget.dart';
import 'package:zerobit_player/core/widgets/covers.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';

import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/utils/cover_lru_cache.dart';
import '../../../core/utils/format_time.dart';
import '../../../core/utils/func_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/app_button/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../setting/controller/setting_ctrl.dart';

const double _coverSize = 250.0;

/// 页面底部留白
const double _bottomInset = 128.0;

const double _actionButtonWidth = 132.0;
const double _actionButtonHeight = 38.0;
const double _ctrlButtonHeight = 42.0;

const double _inlineSpinnerSize = 16.0;
const double _inlineSpinnerStroke = 2.0;

class _NetworkCoverSearchController {
  final String initialTitle;
  final String initialArtist;

  _NetworkCoverSearchController({
    required this.initialTitle,
    required this.initialArtist,
  }) {
    _stopSearchEffect = effect(() {
      final params = _searchParams.value;
      _loadSearch(params.query, params.offset, ++_requestId, params.apiIndex);
    });
  }

  late final void Function() _stopSearchEffect;
  final currentNetLrcOffset = signal(0);
  final _queryText = signal('');
  late final apiIndex = signal(SettingController.instance.apiIndex.value);

  bool _isDisposed = false;
  int _requestId = 0;

  final searchResults = asyncSignal<List<String>>(AsyncState.data([]));

  late final _searchParams =
      computed<({String query, int offset, int apiIndex})>(
        () => (
          query: _queryText.value,
          offset: currentNetLrcOffset.value,
          apiIndex: apiIndex.value,
        ),
      );

  late final void Function(String) onInputChangedDebounce = ((String text) {
    if (_isDisposed) return;
    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }).debounceArgs();

  void setInitialQuery() {
    if (_isDisposed) return;

    final cleanArtist =
        (initialArtist.isNotEmpty && initialArtist.toUpperCase() != 'UNKNOWN')
        ? ' - $initialArtist'
        : '';
    final text = '$initialTitle$cleanArtist'.trim();

    batch(() {
      currentNetLrcOffset.value = 0;
      _queryText.value = text;
    });
  }

  Future<void> _loadSearch(
    String query,
    int offset,
    int requestId,
    int apiIndex,
  ) async {
    query = query.trim();
    if (_isDisposed || requestId != _requestId) return;

    if (query.isEmpty) {
      searchResults.value = AsyncState.data([]);
      return;
    }

    searchResults.value = AsyncState.loading();

    try {
      final result = await getCoverUrlByText(
        text: query,
        offset: offset,
        limit: 12,
        apiIndex: apiIndex,
      );

      if (_isDisposed || requestId != _requestId) return;
      searchResults.value = AsyncState.data(result);
    } catch (error, stackTrace) {
      if (_isDisposed || requestId != _requestId) return;
      searchResults.value = AsyncState.error(error, stackTrace);
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    ++_requestId;
    _stopSearchEffect();
    searchResults.dispose();
    _searchParams.dispose();
    _queryText.dispose();
    apiIndex.dispose();
    currentNetLrcOffset.dispose();
  }
}

class _NetworkCoverDialog extends StatefulWidget {
  final String title;
  final String artist;

  const _NetworkCoverDialog({required this.title, required this.artist});

  @override
  State<_NetworkCoverDialog> createState() => _NetworkCoverDialogState();
}

class _NetworkCoverDialogState extends State<_NetworkCoverDialog> {
  late final _NetworkCoverSearchController _controller;
  late final TextEditingController _textEditingController;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _controller = _NetworkCoverSearchController(
      initialTitle: widget.title,
      initialArtist: widget.artist,
    )..setInitialQuery();

    _textEditingController = TextEditingController(
      text: _controller._queryText.value,
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectCover(String url) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await saveNetCover(
        songPath: '',
        picUrl: url,
        saveCover: false,
      );
      if (bytes != null && mounted) {
        Navigator.of(context).pop(bytes);
      } else {
        showSnackBar(type: .error, msg: '下载所选封面失败');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = context.createTextStyle(size: AppFontSize.md);

    return AppDialog(
      title: '选择网络封面',
      content: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: AppTextField(
                      autofocus: true,
                      controller: _textEditingController,
                      label: '搜索封面',
                      icon: PhosphorIconsLight.magnifyingGlass,
                    ),
                  ),
                  SignalBuilder(
                    builder: (_) => AppButton.icon(
                      icon: PhosphorIconsLight.caretLeft,
                      style: .secondary,
                      height: _ctrlButtonHeight,
                      tooltip: _controller.currentNetLrcOffset.value == 0
                          ? null
                          : '上一页',
                      onPressed: _controller.currentNetLrcOffset.value == 0
                          ? null
                          : () {
                              if (_controller.currentNetLrcOffset.value > 0) {
                                _controller.currentNetLrcOffset.value--;
                              }
                            },
                    ),
                  ),
                  AppButton.icon(
                    icon: PhosphorIconsLight.caretRight,
                    style: .secondary,
                    height: _ctrlButtonHeight,
                    tooltip: '下一页',
                    onPressed: () => _controller.currentNetLrcOffset.value++,
                  ),
                ],
              ),
              Row(
                spacing: AppSpacing.sm,
                children: [
                  for (final key in SettingController.apiMap.keys) ...[
                    SignalBuilder(
                      builder: (context) => AppButton.secondary(
                        label: SettingController.apiMap[key] ?? 'QQ音乐',
                        selected: _controller.apiIndex.value == key,
                        onPressed: () {
                          _controller.apiIndex.value = key;
                          _controller.currentNetLrcOffset.value = 0;
                        },
                      ),
                    ),
                  ],
                ],
              ),
              Expanded(
                child: SignalBuilder(
                  builder: (context) {
                    return _controller.searchResults.value.map(
                      data: (data) {
                        if (data.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: AppSpacing.sm,
                              children: [
                                Icon(
                                  PhosphorIconsLight.imageBroken,
                                  size: AppFontSize.title * 1.5,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: AppAlpha.textFaint,
                                  ),
                                ),
                                Text(
                                  '没有找到封面',
                                  style: textStyle.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: AppAlpha.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return GridView.builder(
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            return HoverBuilder(
                              builder: (context, hovered) => AnimatedContainer(
                                duration: AppDuration.fast,
                                decoration: BoxDecoration(
                                  borderRadius: AppRadius.xsAll,
                                  border: Border.all(
                                    color: hovered
                                        ? scheme.primary
                                        : scheme.outlineVariant.withValues(
                                            alpha: AppAlpha.border,
                                          ),
                                    width: hovered
                                        ? AppSize.trackThin
                                        : AppSize.hairline,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: AppRadius.xsAll,
                                  child: AppTappable(
                                    onPressed: () =>
                                        unawaited(_selectCover(data[index])),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        LoadNetworkCover(
                                          url: data[index],
                                          coverResolutionFlag: .middle,
                                          size: 200,
                                        ),
                                        if (hovered)
                                          ColoredBox(
                                            color: Colors.black.withValues(
                                              alpha: AppAlpha.surfaceSubtle,
                                            ),
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  AppSpacing.sm,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  PhosphorIconsLight
                                                      .downloadSimple,
                                                  size: AppIconSize.sm,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                              ),
                        );
                      },
                      error: (_) =>
                          Center(child: Text("网络错误或没有找到封面", style: textStyle)),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isDownloading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: AppAlpha.surface),
                child: Center(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    borderRadius: AppRadius.xsAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.md,
                      children: [
                        const SizedBox.square(
                          dimension: _inlineSpinnerSize,
                          child: CircularProgressIndicator(
                            strokeWidth: _inlineSpinnerStroke,
                          ),
                        ),
                        Text(
                          '正在下载并应用封面……',
                          style: context.createTextStyle(
                            size: AppFontSize.sm,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 封面来源
sealed class _CoverSource {
  const _CoverSource();
}

/// 文件中原有的封面
class _ExistingCover extends _CoverSource {
  final Uint8List bytes;

  const _ExistingCover(this.bytes);
}

/// 用户新指定的封面
class _PendingCover extends _CoverSource {
  final Uint8List bytes;

  const _PendingCover(this.bytes);
}

class _NoCover extends _CoverSource {
  const _NoCover();
}

class AudioInfoEditorPage extends StatefulWidget {
  const AudioInfoEditorPage({super.key});

  @override
  State<AudioInfoEditorPage> createState() => _AudioInfoEditorPageState();
}

class _AudioInfoEditorPageState extends State<AudioInfoEditorPage> {
  final _isBusy = signal(false);
  final _isCoverLoading = signal(true);
  final _coverSource = signal<_CoverSource>(const _NoCover());
  final _fileInfo = signal<(String size, String lastEdit, String create)>((
    '0 MB',
    '',
    '',
  ));

  late final MusicCache _metadata;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _genreCtrl;

  final _musicCacheController = MusicCacheController.instance;
  final _audioController = AudioController.instance;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _isInitialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        const {};

    _metadata =
        args['metadata'] as MusicCache? ??
        const MusicCache(
          title: '',
          artist: '',
          album: '',
          trackNumber: 0,
          genre: '',
          duration: 9999,
          bitrate: null,
          sampleRate: null,
          bitDepth: 16,
          channels: 1,
          trackGain: 0.0,
          trackPeak: 1.0,
          path: '',
        );

    _titleCtrl = TextEditingController(text: _metadata.title);
    _artistCtrl = TextEditingController(text: _metadata.artist);
    _albumCtrl = TextEditingController(text: _metadata.album);
    _genreCtrl = TextEditingController(text: _metadata.genre);

    unawaited(_loadInitialCover());
    unawaited(_loadAudioFileInfo());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();

    _isBusy.dispose();
    _isCoverLoading.dispose();
    _coverSource.dispose();
    _fileInfo.dispose();
    super.dispose();
  }

  Future<void> _loadAudioFileInfo() async {
    try {
      final file = File(_metadata.path);
      if (!await file.exists()) return;

      final length = await file.length();
      final stat = await file.stat();
      final lastModified = await file.lastModified();

      _fileInfo.value = (
        '${(length / 1024 / 1024).toStringAsFixed(2)} MB',
        lastModified.toString().substring(0, 19),
        stat.changed.toString().substring(0, 19),
      );
    } catch (e, stackTrace) {
      LoggerUni.w('读取音频文件信息失败', e, stackTrace);
    }
  }

  Future<void> _loadInitialCover() async {
    try {
      final bytes = await getCover(
        path: _metadata.path,
        sizeFlag: CoverQuality.high,
      );
      _coverSource.value = bytes != null
          ? _ExistingCover(bytes)
          : const _NoCover();
    } catch (e, stackTrace) {
      LoggerUni.w('获取封面失败', e, stackTrace);
      _coverSource.value = const _NoCover();
    } finally {
      _isCoverLoading.value = false;
    }
  }

  Future<void> _pickLocalCover() async {
    try {
      final result = await FilePicker.pickFile(type: FileType.image);
      if (result == null) return;

      final bytes = await result.readAsBytes();
      if (bytes.isEmpty) {
        showSnackBar(type: .error, msg: '未能成功读取图片文件');
        return;
      }
      _coverSource.value = _PendingCover(bytes);
    } catch (e, stackTrace) {
      LoggerUni.w('选择本地封面失败', e, stackTrace);
      showSnackBar(type: .error, msg: '选择本地封面失败: $e');
    }
  }

  Future<void> _fetchNetworkCover() async {
    final title = _titleCtrl.text.isNotEmpty
        ? _titleCtrl.text
        : _metadata.title;
    final artist = _artistCtrl.text.isNotEmpty
        ? _artistCtrl.text
        : _metadata.artist;

    final coverBytes = await showDialog<Uint8List>(
      barrierDismissible: true,
      context: context,
      builder: (_) => _NetworkCoverDialog(title: title, artist: artist),
    );

    if (coverBytes != null && coverBytes.isNotEmpty) {
      _coverSource.value = _PendingCover(coverBytes);
    }
  }

  Future<void> _saveChanges() async {
    if (_isBusy.value) return;
    _isBusy.value = true;

    try {
      if (_coverSource.value case _PendingCover(:final bytes)) {
        await editCover(path: _metadata.path, src: bytes);
        CoverLRUCache.put(_metadata.path, bytes);
      }

      final newCache = _musicCacheController.putMetadata(
        path: _metadata.path,
        index: _musicCacheController.items.indexWhere(
          (v) => v.path == _metadata.path,
        ),
        data: EditableMetadata(
          title: _titleCtrl.text.trim(),
          artist: _artistCtrl.text.trim(),
          album: _albumCtrl.text.trim(),
          genre: _genreCtrl.text.trim(),
        ),
      );

      unawaited(
        _audioController.audioListSyncMetadata(
          path: _metadata.path,
          newCache: newCache,
        ),
      );

      if (mounted) context.pop();
      showSnackBar(type: .success, msg: '保存成功');
    } catch (e, stackTrace) {
      LoggerUni.w('保存音频信息失败', e, stackTrace);
      showSnackBar(type: .error, msg: '保存失败，请重试');
      _isBusy.value = false;
    }
  }

  Uint8List _getCoverBytes(_CoverSource source) => switch (source) {
    _ExistingCover(:final bytes) => bytes,
    _PendingCover(:final bytes) => bytes,
    _NoCover() => kTransparentImage,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          _bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            _buildHeader(),
            AppCard(
              borderRadius: AppRadius.xsAll,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxl,
                children: [
                  SignalBuilder(
                    builder: (_) {
                      final source = _coverSource.value;
                      return _CoverPanel(
                        bytes: _getCoverBytes(source),
                        isLoading: _isCoverLoading.value,
                        hasCover: source is! _NoCover,
                        onTap: _isBusy.value
                            ? null
                            : () => unawaited(_pickLocalCover()),
                      );
                    },
                  ),
                  Expanded(child: _buildForm()),
                ],
              ),
            ),
            _buildActions(),
            _buildInfoCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fileName = _metadata.path.isEmpty ? '' : p.basename(_metadata.path);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(
              '编辑音频信息',
              style: context.createTextStyle(
                size: AppFontSize.subtitle,
                weight: FontWeight.w600,
              ),
            ),
            if (fileName.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(
                    alpha: AppAlpha.controlFill,
                  ),
                  borderRadius: AppRadius.xsAll,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: AppAlpha.border,
                    ),
                    width: AppSize.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsLight.fileAudio,
                      size: AppIconSize.xs,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Text(
                        fileName,
                        style: context.createTextStyle(
                          size: AppFontSize.xs,
                          opacity: AppAlpha.textSecondary,
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        AppTextField(
          controller: _titleCtrl,
          label: '标题',
          icon: PhosphorIconsLight.musicNote,
        ),
        AppTextField(
          controller: _artistCtrl,
          label: '艺术家',
          icon: PhosphorIconsLight.user,
        ),
        AppTextField(
          controller: _albumCtrl,
          label: '专辑',
          icon: PhosphorIconsLight.disc,
        ),
        AppTextField(
          controller: _genreCtrl,
          label: '流派',
          icon: PhosphorIconsLight.tag,
        ),
      ],
    );
  }

  Widget _buildActions() {
    final colorScheme = Theme.of(context).colorScheme;

    return SignalBuilder(
      builder: (_) {
        final busy = _isBusy.value;
        return AnimatedSwitcher(
          duration: AppDuration.normal,
          child: busy
              ? Row(
                  key: const ValueKey('busy'),
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: AppSpacing.lg,
                  children: [
                    const SizedBox.square(
                      dimension: _inlineSpinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: _inlineSpinnerStroke,
                      ),
                    ),
                    Text(
                      '正在保存修改……',
                      style: context.createTextStyle(
                        size: AppFontSize.md,
                        color: colorScheme.primary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  spacing: AppSpacing.md,
                  children: [
                    _ActionButton(
                      label: '获取网络封面',
                      icon: PhosphorIconsLight.globe,
                      onPressed: () => unawaited(_fetchNetworkCover()),
                    ),
                    _ActionButton(
                      label: '使用本地封面',
                      icon: PhosphorIconsLight.folderOpen,
                      onPressed: () => unawaited(_pickLocalCover()),
                    ),
                    const Spacer(),
                    _ActionButton(label: '取消', onPressed: context.pop),
                    _ActionButton(
                      label: '保存',
                      isPrimary: true,
                      icon: PhosphorIconsLight.check,
                      onPressed: () => unawaited(_saveChanges()),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildInfoCards() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xl,
      children: [
        Expanded(
          child: _InfoCard(
            icon: PhosphorIconsFill.waveform,
            title: '音频参数',
            entries: [
              ('时长', formatTime(totalSeconds: _metadata.duration)),
              ('比特率', '${_metadata.bitrate ?? "UNKNOWN"} kbps'),
              ('采样率', '${_metadata.sampleRate ?? "UNKNOWN"} Hz'),
              ('位深度', '${_metadata.bitDepth} bit'),
              ('通道数', '${_metadata.channels} 声道'),
            ],
          ),
        ),
        Expanded(
          child: _InfoCard(
            icon: PhosphorIconsLight.slidersHorizontal,
            title: '电平与增益',
            entries: [
              ('音轨编号', '${_metadata.trackNumber}'),
              ('音轨峰值', _metadata.trackPeak.toStringAsFixed(2)),
              ('音轨增益', '${_metadata.trackGain.toStringAsFixed(2)} dB'),
            ],
          ),
        ),
        Expanded(
          child: SignalBuilder(
            builder: (_) {
              final info = _fileInfo.value;
              return _InfoCard(
                icon: PhosphorIconsFill.fileText,
                title: '存储信息',
                entries: [
                  (
                    '文件格式',
                    p
                        .extension(_metadata.path)
                        .replaceFirst('.', '')
                        .toUpperCase(),
                  ),
                  ('文件大小', info.$1),
                  ('修改时间', info.$2),
                  ('变更时间', info.$3),
                  ('完整路径', _metadata.path),
                ],
                lastEntryMaxLines: 4,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 封面面板
class _CoverPanel extends StatelessWidget {
  final Uint8List bytes;
  final bool isLoading;
  final bool hasCover;
  final VoidCallback? onTap;

  const _CoverPanel({
    required this.bytes,
    required this.isLoading,
    required this.hasCover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return Container(
        width: _coverSize,
        height: _coverSize,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(
            alpha: AppAlpha.surfaceSubtle,
          ),
          borderRadius: AppRadius.xsAll,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return HoverBuilder(
      onPressed: onTap,
      builder: (context, hovered) => SizedBox.square(
        dimension: _coverSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.xsAll,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: AppAlpha.border,
              ),
              width: AppSize.hairline,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xsAll,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  LoadU8Cover(
                    data: bytes,
                    coverResolutionFlag: CoverResolutionFlag.big,
                    size: _coverSize,
                  )
                else
                  ColoredBox(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: AppAlpha.controlFill,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: AppSpacing.sm,
                      children: [
                        Icon(
                          PhosphorIconsLight.imageSquare,
                          size: AppFontSize.title * 1.5,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppAlpha.textFaint,
                          ),
                        ),
                        Text(
                          '暂无封面\n点击选择本地图片',
                          textAlign: TextAlign.center,
                          style: context.createTextStyle(
                            size: AppFontSize.xs,
                            opacity: AppAlpha.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                AnimatedOpacity(
                  duration: AppDuration.fast,
                  opacity: hovered && onTap != null ? 1.0 : 0.0,
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: AppAlpha.surfaceStrong,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppSpacing.sm,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: AppAlpha.fillStrong,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsLight.cameraRotate,
                              size: AppIconSize.md,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '更换本地封面',
                            style: context.createTextStyle(
                              size: AppFontSize.sm,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一张只读信息卡
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;

  /// 键值对列表
  final List<(String, String)> entries;

  /// 末项允许的行数
  final int lastEntryMaxLines;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.entries,
    this.lastEntryMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textTertiary,
    );
    final valueStyle = context.createTextStyle(
      size: AppFontSize.sm,
      weight: FontWeight.w500,
    );

    return AppCard(
      borderRadius: AppRadius.xsAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: AppAlpha.fill),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Icon(
                  icon,
                  size: AppIconSize.xs,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                title,
                style: context.createTextStyle(
                  size: AppFontSize.md,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: AppSize.hairline,
                thickness: AppSize.hairline,
                color: colorScheme.outlineVariant.withValues(
                  alpha: AppAlpha.border,
                ),
              ),
            _InfoEntry(
              label: entries[i].$1,
              value: entries[i].$2,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
              maxLines: i == entries.length - 1 ? lastEntryMaxLines : 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoEntry extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final int maxLines;

  const _InfoEntry({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxs,
        children: [
          Text(label, style: labelStyle, maxLines: 1, softWrap: false),
          Text(
            value.isEmpty ? '—' : value,
            style: valueStyle,
            maxLines: maxLines,
            softWrap: maxLines > 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final btn = isPrimary ? AppButton.filled : AppButton.secondary;
    return btn(
      onPressed: onPressed,
      label: label,
      icon: icon,
      width: _actionButtonWidth,
      height: _actionButtonHeight,
    );
  }
}
