import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:path/path.dart' as p;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const double _bigCoverSize = 260;
const int _coverBigRenderSize = 800;

sealed class _CoverSource {}

class _InitialCover extends _CoverSource {
  final Uint8List bytes;
  _InitialCover(this.bytes);
}

class _FileCover extends _CoverSource {
  final PlatformFile file;
  _FileCover(this.file);
}

class _GeneratedCover extends _CoverSource {
  final Uint8List bytes;
  _GeneratedCover(this.bytes);
}

class _NoCover extends _CoverSource {}

class AudioInfoEditorPage extends StatefulWidget {
  const AudioInfoEditorPage({super.key});

  @override
  State<AudioInfoEditorPage> createState() => _AudioInfoEditorPageState();
}

class _AudioInfoEditorPageState extends State<AudioInfoEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _genreCtrl;

  late final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  late final AudioController _audioController = Get.find<AudioController>();

  static const _inputBorder = OutlineInputBorder();

  late MusicCache metadata;
  late String operateArea;
  String audioSize = '0 MB';
  String lastEditTime = '';
  String createTime = '';

  bool _isLoading = false;

  // 统一封面状态管理
  _CoverSource? _currentCoverSource;
  bool _isCoverLoading = true;

  bool _isInit = false;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};

      metadata =
          args['metadata'] ??
          MusicCache(
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

      _titleCtrl = TextEditingController(text: metadata.title);
      _artistCtrl = TextEditingController(text: metadata.artist);
      _albumCtrl = TextEditingController(text: metadata.album);
      _genreCtrl = TextEditingController(text: metadata.genre);

      final file = File(metadata.path);
      audioSize =
          '${((await file.length()) / 1024 / 1024).toStringAsFixed(2)} MB';

      lastEditTime = (await file.lastModified()).toString().substring(0, 19);
      createTime = (await file.stat()).changed.toString().substring(0, 19);

      _loadInitialCover();

      _isInit = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCover() async {
    try {
      final bytes = await getCover(path: metadata.path, sizeFlag: 1);
      if (mounted) {
        setState(() {
          _currentCoverSource = bytes != null
              ? _InitialCover(bytes)
              : _NoCover();
          _isCoverLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentCoverSource = _NoCover();
          _isCoverLoading = false;
        });
      }
    }
  }

  Future<void> _pickLocalCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _currentCoverSource = _FileCover(result.files.first));
      }
    } catch (e) {
      _showError('选择本地封面失败: $e');
    }
  }

  Future<void> _fetchNetworkCover() async {
    setState(() => _isLoading = true);
    try {
      final title = _titleCtrl.text;
      final artist =
          (_artistCtrl.text.isNotEmpty && _artistCtrl.text != 'UNKNOWN')
          ? ' - ${_artistCtrl.text}'
          : '';

      final coverData = await saveCoverByText(
        text: title + artist,
        songPath: metadata.path,
        saveCover: false,
      );

      if (mounted && coverData != null && coverData.isNotEmpty) {
        setState(
          () => _currentCoverSource = _GeneratedCover(
            Uint8List.fromList(coverData),
          ),
        );
      } else {
        _showError('未找到网络封面');
      }
    } catch (e) {
      _showError('获取网络封面失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    debugPrint('123');

    try {
      // 保存封面
      if (_currentCoverSource != null) {
        Uint8List? coverBytes;
        if (_currentCoverSource is _FileCover) {
          coverBytes = (_currentCoverSource as _FileCover).file.bytes;
        } else if (_currentCoverSource is _GeneratedCover) {
          coverBytes = (_currentCoverSource as _GeneratedCover).bytes;
        }

        if (coverBytes != null) {
          await editCover(path: metadata.path, src: coverBytes);
          CoverLRUCache.put(metadata.path, coverBytes);
        }
      }

      // 保存元数据
      final newCache = _musicCacheController.putMetadata(
        path: metadata.path,
        index: _musicCacheController.items.indexWhere(
          (v) => v.path == metadata.path,
        ),
        data: EditableMetadata(
          title: _titleCtrl.text.trim(),
          artist: _artistCtrl.text.trim(),
          album: _albumCtrl.text.trim(),
          genre: _genreCtrl.text.trim(),
        ),
      );

      // 同步到播放列表
      _audioController.audioListSyncMetadata(
        path: metadata.path,
        newCache: newCache,
      );

      // 安全关闭
      if (mounted) Get.back(id: 1);
    } catch (e) {
      debugPrint("保存失败: $e");
      _showError('保存失败，请重试');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showSnackBar(
      title: 'Err',
      msg: message,
      duration: Duration(milliseconds: 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = generalTextStyle(ctx: context, size: 'md');
    final titleStyle = generalTextStyle(
      ctx: context,
      size: 'xl',
      weight: FontWeight.bold,
    );

    return Material(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsGeometry.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCover(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        _buildTextField(controller: _titleCtrl, label: '标题'),
                        _buildTextField(controller: _artistCtrl, label: '艺术家'),
                        _buildTextField(controller: _albumCtrl, label: '专辑'),
                        _buildTextField(controller: _genreCtrl, label: '流派'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActionButtons(),
              const SizedBox(height: 12),
              _buildInfoSection(textStyle, titleStyle),
              const SizedBox(height: 128),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (_isCoverLoading) {
      return const SizedBox(
        height: _bigCoverSize,
        width: _bigCoverSize,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _buildImageProvider(
      _getImageProvider(_currentCoverSource ?? _NoCover()),
    );
  }

  ImageProvider _getImageProvider(_CoverSource source) => switch (source) {
    _InitialCover(:final bytes) => MemoryImage(bytes),
    _GeneratedCover(:final bytes) => MemoryImage(bytes),
    _FileCover(:final file) => MemoryImage(file.bytes ?? kTransparentImage),
    _NoCover() => MemoryImage(kTransparentImage),
  };

  Widget _buildImageProvider(ImageProvider provider) {
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Image(
        image: ResizeImage(
          provider,
          width: _coverBigRenderSize,
          height: _coverBigRenderSize,
        ),
        height: _bigCoverSize,
        width: _bigCoverSize,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(border: _inputBorder, labelText: label),
      ),
    );
  }

  Widget _buildInfoSection(TextStyle textStyle, TextStyle titleStyle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Expanded(
          child: _buildInfoBox(textStyle, titleStyle, [
            Row(
              spacing: 4,
              children: [
                Icon(PhosphorIconsFill.musicNoteSimple, size: 20),
                Text('音频参数', style: titleStyle),
              ],
            ),
            const SizedBox.shrink(),
            _buildInfoText(
              "时长",
              formatTime(totalSeconds: metadata.duration),
              textStyle,
            ),
            _buildInfoText(
              "比特率",
              "${metadata.bitrate ?? "UNKNOWN"}kbps",
              textStyle,
            ),
            _buildInfoText(
              "采样率",
              "${metadata.sampleRate ?? "UNKNOWN"}hz",
              textStyle,
            ),
            _buildInfoText("位深度", "${metadata.bitDepth}", textStyle),
            _buildInfoText("通道数", "${metadata.channels}", textStyle),
          ]),
        ),

        Expanded(
          child: _buildInfoBox(textStyle, titleStyle, [
            Row(
              spacing: 4,
              children: [
                Icon(PhosphorIconsLight.hash, size: 20),
                Text('音频标签', style: titleStyle),
              ],
            ),
            const SizedBox.shrink(),
            _buildInfoText("音轨号", "${metadata.trackNumber}", textStyle),
            _buildInfoText(
              "峰值",
              metadata.trackPeak.toStringAsFixed(2),
              textStyle,
            ),
            _buildInfoText(
              "增益",
              metadata.trackGain.toStringAsFixed(2),
              textStyle,
            ),
          ]),
        ),

        Expanded(
          child: _buildInfoBox(textStyle, titleStyle, [
            Row(
              spacing: 4,
              children: [
                Icon(PhosphorIconsFill.folderSimple, size: 20),
                Text('文件信息', style: titleStyle),
              ],
            ),
            const SizedBox.shrink(),
            _buildInfoText(
              "格式",
              p.extension(metadata.path).replaceFirst('.', '').toUpperCase(),
              textStyle,
            ),
            _buildInfoText("文件大小", audioSize, textStyle),
            _buildInfoText("修改时间", lastEditTime, textStyle),
            _buildInfoText("创建时间", createTime, textStyle),
            _buildInfoText("路径", metadata.path, textStyle, maxLines: 5),
          ]),
        ),
      ],
    );
  }

  Widget _buildInfoBox(
    TextStyle textStyle,
    TextStyle titleStyle,
    List<Widget> childs,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: childs,
      ),
    );
  }

  Widget _buildInfoText(
    String title,
    String text,
    TextStyle style, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisAlignment: .center,
      spacing: 4,
      children: [
        Text(
          title,
          style: style.copyWith(color: style.color!.withValues(alpha: 0.8)),
          softWrap: maxLines > 1,
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines,
        ),
        Text(
          text,
          style: style,
          softWrap: maxLines > 1,
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines,
        ),
        Divider(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          height: 2,
          thickness: 0.5,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isLoading
          ? Row(
              key: const ValueKey('saving'),
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  "执行中……",
                  style: generalTextStyle(
                    ctx: context,
                    size: 'md',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            )
          : Row(
              key: const ValueKey('buttons'),
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                _actionButton(label: "获取网络封面", onPressed: _fetchNetworkCover),
                _actionButton(label: "使用本地封面", onPressed: _pickLocalCover),
                const Spacer(),
                _actionButton(label: "取消", onPressed: () => Get.back(id: 1)),
                _actionButton(
                  label: "确定",
                  onPressed: _saveChanges,
                  isPrimary: true,
                ),
              ],
            ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomBtn(
      fn: onPressed,
      backgroundColor: isPrimary
          ? colorScheme.primary
          : colorScheme.surfaceContainer,
      contentColor: isPrimary ? colorScheme.onPrimary : null,
      overlayColor: isPrimary ? colorScheme.surfaceContainer : null,
      btnWidth: 108,
      btnHeight: 36,
      label: label,
    );
  }
}
