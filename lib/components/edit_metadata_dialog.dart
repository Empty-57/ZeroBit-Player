import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';

import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import '../tools/cover_lru_cache.dart';
import 'get_snack_bar.dart';

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const double _bigCoverSize = 200;
const int _coverBigRenderSize = 800;
const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;

class EditMetadataDialog extends StatelessWidget {
  final MenuController menuController;
  final MusicCache metadata;
  final int index;
  final String operateArea;
  const EditMetadataDialog({
    super.key,
    required this.menuController,
    required this.metadata,
    required this.index,
    required this.operateArea,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBtn(
      fn: () {
        menuController.close();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return _MetadataEditor(
              metadata: metadata,
              index: index,
              operateArea: operateArea,
            );
          },
        );
      },
      btnHeight: _menuHeight,
      btnWidth: _menuWidth,
      radius: _menuRadius,
      icon: PhosphorIconsLight.pencilSimpleLine,
      label: "编辑元数据",
      mainAxisAlignment: MainAxisAlignment.start,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _MetadataEditor extends StatefulWidget {
  final MusicCache metadata;
  final int index;
  final String operateArea;

  const _MetadataEditor({
    required this.metadata,
    required this.index,
    required this.operateArea,
  });

  @override
  State<_MetadataEditor> createState() => _MetadataEditorState();
}

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

class _MetadataEditorState extends State<_MetadataEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _genreCtrl;

  late final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  late final AudioController _audioController = Get.find<AudioController>();

  static const _inputBorder = OutlineInputBorder();

  bool _isLoading = false;

  // 统一封面状态管理
  _CoverSource? _currentCoverSource;
  bool _isCoverLoading = true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.metadata.title);
    _artistCtrl = TextEditingController(text: widget.metadata.artist);
    _albumCtrl = TextEditingController(text: widget.metadata.album);
    _genreCtrl = TextEditingController(text: widget.metadata.genre);
    _loadInitialCover();
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
      final bytes = await getCover(path: widget.metadata.path, sizeFlag: 1);
      if (mounted) {
        setState(() {
          _currentCoverSource =
              bytes != null ? _InitialCover(bytes) : _NoCover();
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
        songPath: widget.metadata.path,
        saveCover: false,
      );

      if (mounted && coverData != null && coverData.isNotEmpty) {
        setState(
          () =>
              _currentCoverSource = _GeneratedCover(
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
          await editCover(path: widget.metadata.path, src: coverBytes);
          CoverLRUCache.put(widget.metadata.path, coverBytes);
        }
      }

      // 保存元数据
      final newCache = _musicCacheController.putMetadata(
        path: widget.metadata.path,
        index: _musicCacheController.items.indexWhere(
          (v) => v.path == widget.metadata.path,
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
        path: widget.metadata.path,
        newCache: newCache,
      );

      // 安全关闭弹窗
      if (mounted) Navigator.pop(context, 'actions');
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
    final textStyle = generalTextStyle(ctx: context, size: 'lg');

    return AlertDialog(
      title: Text(
        widget.metadata.title,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      titleTextStyle: generalTextStyle(
        ctx: context,
        size: 'xl',
        weight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actionsAlignment: MainAxisAlignment.end,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      actionsPadding: const EdgeInsets.all(24.0).copyWith(top: 0),
      content: SizedBox(
        width: context.width * 2 / 3,
        height: context.height * 2 / 3,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(child: _buildCover()),
              const SizedBox(height: 24),
              _buildTextField(controller: _titleCtrl, label: '标题'),
              _buildTextField(controller: _artistCtrl, label: '艺术家'),
              _buildTextField(controller: _albumCtrl, label: '专辑'),
              _buildTextField(controller: _genreCtrl, label: '流派'),
              _buildInfoSection(textStyle),
            ],
          ),
        ),
      ),
      actions: [_buildActionButtons()],
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

  Widget _buildInfoSection(TextStyle textStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoText(
          "时长  ${formatTime(totalSeconds: widget.metadata.duration)}",
          textStyle,
        ),
        _buildInfoText(
          "比特率  ${widget.metadata.bitrate ?? "UNKNOWN"}kbps",
          textStyle,
        ),
        _buildInfoText(
          "采样率  ${widget.metadata.sampleRate ?? "UNKNOWN"}hz",
          textStyle,
        ),
        _buildInfoText("音轨号  ${widget.metadata.trackNumber}", textStyle),
        _buildInfoText("位深度  ${widget.metadata.bitDepth}", textStyle),
        _buildInfoText("通道数  ${widget.metadata.channels}", textStyle),
        _buildInfoText("路径  ${widget.metadata.path}", textStyle, maxLines: 3),
      ],
    );
  }

  Widget _buildInfoText(String text, TextStyle style, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: style,
        softWrap: maxLines > 1,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child:
            _isLoading
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
                    _actionButton(label: "网络封面", onPressed: _fetchNetworkCover),
                    _actionButton(label: "本地封面", onPressed: _pickLocalCover),
                    const Spacer(),
                    _actionButton(
                      label: "取消",
                      onPressed: () => Navigator.pop(context),
                    ),
                    _actionButton(
                      label: "确定",
                      onPressed: _saveChanges,
                      isPrimary: true,
                    ),
                  ],
                ),
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
      backgroundColor: isPrimary ? colorScheme.primary : Colors.transparent,
      contentColor: isPrimary ? colorScheme.onPrimary : null,
      overlayColor: isPrimary ? colorScheme.surfaceContainer : null,
      btnWidth: 108,
      btnHeight: 36,
      label: label,
    );
  }
}
