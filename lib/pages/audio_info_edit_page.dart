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
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/widget/app_interaction_widget.dart';
import 'package:zerobit_player/components/widget/app_button/app_button.dart';
import 'package:zerobit_player/components/widget/app_card.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/components/widget/get_snack_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

const double _coverSize = 260.0;

/// 页面底部留白
const double _bottomInset = 128.0;

const double _actionButtonWidth = 108.0;
const double _actionButtonHeight = 36.0;

const double _inlineSpinnerSize = 16.0;
const double _inlineSpinnerStroke = 2.0;

const Duration _snackDuration = Duration(milliseconds: 1000);

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
    // 释放控制器
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
        _showError('未能成功读取图片文件');
        return;
      }
      _coverSource.value = _PendingCover(bytes);
    } catch (e, stackTrace) {
      LoggerUni.w('选择本地封面失败', e, stackTrace);
      _showError('选择本地封面失败: $e');
    }
  }

  Future<void> _fetchNetworkCover() async {
    if (_isBusy.value) return;
    _isBusy.value = true;

    try {
      final artist = _artistCtrl.text;
      final suffix = artist.isNotEmpty && artist != 'UNKNOWN'
          ? ' - $artist'
          : '';

      final coverData = await saveCoverByText(
        text: _titleCtrl.text + suffix,
        songPath: _metadata.path,
        saveCover: false,
      );

      if (coverData == null || coverData.isEmpty) {
        _showError('未找到网络封面');
        return;
      }
      _coverSource.value = _PendingCover(Uint8List.fromList(coverData));
    } catch (e, stackTrace) {
      LoggerUni.w('获取网络封面失败', e, stackTrace);
      _showError('获取网络封面失败: $e');
    } finally {
      _isBusy.value = false;
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
    } catch (e, stackTrace) {
      LoggerUni.w('保存音频信息失败', e, stackTrace);
      _showError('保存失败，请重试');
      _isBusy.value = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showSnackBar(title: 'Err', msg: message, duration: _snackDuration);
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xl,
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
            _buildActions(),
            _buildInfoCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fileName = _metadata.path.isEmpty ? '' : p.basename(_metadata.path);

    return Column(
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
        Text(
          fileName,
          style: context.createTextStyle(
            size: AppFontSize.sm,
            opacity: AppAlpha.textTertiary,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xl,
      children: [
        _MetadataField(controller: _titleCtrl, label: '标题'),
        _MetadataField(controller: _artistCtrl, label: '艺术家'),
        _MetadataField(controller: _albumCtrl, label: '专辑'),
        _MetadataField(controller: _genreCtrl, label: '流派'),
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
                      '执行中……',
                      style: context.createTextStyle(
                        size: AppFontSize.md,
                        color: colorScheme.primary,
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
                      onPressed: () => unawaited(_fetchNetworkCover()),
                    ),
                    _ActionButton(
                      label: '使用本地封面',
                      onPressed: () => unawaited(_pickLocalCover()),
                    ),
                    const Spacer(),
                    _ActionButton(label: '取消', onPressed: context.pop),
                    _ActionButton(
                      label: '保存',
                      isPrimary: true,
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
            icon: PhosphorIconsFill.musicNoteSimple,
            title: '音频参数',
            entries: [
              ('时长', formatTime(totalSeconds: _metadata.duration)),
              ('比特率', '${_metadata.bitrate ?? "UNKNOWN"} kbps'),
              ('采样率', '${_metadata.sampleRate ?? "UNKNOWN"} Hz'),
              ('位深度', '${_metadata.bitDepth}'),
              ('通道数', '${_metadata.channels}'),
            ],
          ),
        ),
        Expanded(
          child: _InfoCard(
            icon: PhosphorIconsLight.hash,
            title: '音频标签',
            entries: [
              ('音轨号', '${_metadata.trackNumber}'),
              ('峰值', _metadata.trackPeak.toStringAsFixed(2)),
              ('增益', _metadata.trackGain.toStringAsFixed(2)),
            ],
          ),
        ),
        Expanded(
          child: SignalBuilder(
            builder: (_) {
              final info = _fileInfo.value;
              return _InfoCard(
                icon: PhosphorIconsFill.folderSimple,
                title: '文件信息',
                entries: [
                  (
                    '格式',
                    p
                        .extension(_metadata.path)
                        .replaceFirst('.', '')
                        .toUpperCase(),
                  ),
                  ('文件大小', info.$1),
                  ('修改时间', info.$2),
                  ('变更时间', info.$3),
                  ('路径', _metadata.path),
                ],
                lastEntryMaxLines: 5,
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
      return const SizedBox.square(
        dimension: _coverSize,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return HoverBuilder(
      onPressed: onTap,
      builder: (context, hovered) => SizedBox.square(
        dimension: _coverSize,
        child: ClipRRect(
          borderRadius: AppRadius.smAll,
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
                    alpha: AppAlpha.surface,
                  ),
                  child: Icon(
                    PhosphorIconsLight.image,
                    size: AppFontSize.title,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppAlpha.textFaint,
                    ),
                  ),
                ),
              // 悬停时压一层提示
              AnimatedOpacity(
                duration: AppDuration.instant,
                opacity: hovered && onTap != null ? 1 : 0,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: AppAlpha.surface),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.md,
                      children: [
                        Icon(
                          PhosphorIconsLight.image,
                          size: AppIconSize.lg,
                          color: colorScheme.onPrimary,
                        ),
                        Text(
                          '更换封面',
                          style: context.createTextStyle(
                            size: AppFontSize.sm,
                            color: colorScheme.onPrimary,
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
    );
  }
}

class _MetadataField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _MetadataField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: context.createTextStyle(size: AppFontSize.md),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.createTextStyle(
          size: AppFontSize.md,
          opacity: AppAlpha.textSecondary,
        ),
        border: const OutlineInputBorder(borderRadius: AppRadius.xsAll),
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
      size: AppFontSize.sm,
      opacity: AppAlpha.textTertiary,
    );
    final valueStyle = context.createTextStyle(size: AppFontSize.md);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Icon(icon, size: AppIconSize.sm, color: colorScheme.primary),
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
    return Column(
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = isPrimary ? AppButton.filled : AppButton.secondary;
    return btn(
      onPressed: onPressed,
      label: label,
      width: _actionButtonWidth,
      height: _actionButtonHeight,
    );
  }
}
