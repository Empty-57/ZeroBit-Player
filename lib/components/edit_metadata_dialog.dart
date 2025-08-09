import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/field/operate_area.dart';

import '../API/apis.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../custom_widgets/custom_button.dart';
import '../getxController/album_list_crl.dart';
import '../getxController/artist_list_ctrl.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/play_list_ctrl.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/format_time.dart';
import '../tools/general_style.dart';

const double _metadataDialogW = 600;
const double _metadataDialogH = 580;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const double _bigCoverSize = 200;
const int _coverBigRenderSize = 800;
const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

final AudioController _audioController = Get.find<AudioController>();

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
      label: "修改元数据",
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

// 定义一个类来管理封面的不同来源
abstract class _CoverSource {}
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

  bool _isLoading = false;

  Future<_CoverSource>? _initialCoverFuture;
  _CoverSource? _currentCoverSource;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.metadata.title);
    _artistCtrl = TextEditingController(text: widget.metadata.artist);
    _albumCtrl = TextEditingController(text: widget.metadata.album);
    _genreCtrl = TextEditingController(text: widget.metadata.genre);
    _initialCoverFuture = _loadInitialCover();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    super.dispose();
  }

  Future<_CoverSource> _loadInitialCover() async {
    final bytes = await getCover(path: widget.metadata.path, sizeFlag: 1);
    if (bytes != null) {
      return _InitialCover(bytes);
    }
    return _NoCover();
  }

  Future<void> _pickLocalCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _currentCoverSource = _FileCover(result.files.first);
      });
    }
  }

  Future<void> _fetchNetworkCover() async {
    setState(() => _isLoading = true);
    final title = widget.metadata.title;
    final artist = widget.metadata.artist.isNotEmpty ? ' - ${widget.metadata.artist}' : '';
    final coverData = await saveCoverByText(
      text: title + artist,
      songPath: widget.metadata.path,
      saveCover: false,
    );
    if (mounted && coverData != null && coverData.isNotEmpty) {
      setState(() {
        _currentCoverSource = _GeneratedCover(Uint8List.fromList(coverData));
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    // 保存封面
    if (_currentCoverSource != null) {
      Uint8List? coverBytes;
      if (_currentCoverSource is _FileCover) {
        final file = (_currentCoverSource as _FileCover).file;
        coverBytes = file.bytes;

      } else if (_currentCoverSource is _GeneratedCover) {
        coverBytes = (_currentCoverSource as _GeneratedCover).bytes;
      }

      if (coverBytes != null) {
        try{
          await editCover(path: widget.metadata.path, src: coverBytes);
        }catch(e){
          debugPrint(e.toString());
        }
        // 清除旧的封面缓存，让它下次重新加载
        _musicCacheController.items[widget.index].src = null;
      }
    }

    // 保存元数据
    final newCache = _musicCacheController.putMetadata(
      path: widget.metadata.path,
      index: _musicCacheController.items.indexWhere((v) => v.path == widget.metadata.path),
      data: EditableMetadata(
        title: _titleCtrl.text,
        artist: _artistCtrl.text,
        album: _albumCtrl.text,
        genre: _genreCtrl.text,
      ),
    );

    // 同步到其他列表
    switch (widget.operateArea) {
      case OperateArea.playList:
        PlayListController.audioListSyncMetadata(index: widget.index, newCache: newCache);
        break;
      case OperateArea.artistList:
        ArtistListController.audioListSyncMetadata(index: widget.index, newCache: newCache);
        break;
      case OperateArea.albumList:
        AlbumListController.audioListSyncMetadata(index: widget.index, newCache: newCache);
        break;
    }
    _audioController.audioListSyncMetadata(path: widget.metadata.path, newCache: newCache);

    if (mounted) {
      Navigator.pop(context, 'actions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = generalTextStyle(ctx: context, size: 'lg');
    final border = OutlineInputBorder();

    return AlertDialog(
      title: SizedBox(
        width: _metadataDialogW,
        child: Text(
          widget.metadata.title,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      titleTextStyle: generalTextStyle(ctx: context, size: 20, weight: FontWeight.w700),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      backgroundColor: Theme.of(context).colorScheme.surface,
      actionsAlignment: MainAxisAlignment.end,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      actionsPadding: const EdgeInsets.all(24.0).copyWith(top: 0),
      content: SizedBox(
        width: _metadataDialogW,
        height: _metadataDialogH,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Center(child: _buildCover()),
              const SizedBox(height: 24),
              _buildTextField(controller: _titleCtrl, label: '标题', border: border),
              _buildTextField(controller: _artistCtrl, label: '艺术家', border: border),
              _buildTextField(controller: _albumCtrl, label: '专辑', border: border),
              _buildTextField(controller: _genreCtrl, label: '流派', border: border),
              _buildInfoText("时长  ${formatTime(totalSeconds: widget.metadata.duration)}", textStyle),
              _buildInfoText("比特率  ${widget.metadata.bitrate ?? "UNKNOWN"}kbps", textStyle),
              _buildInfoText("采样率  ${widget.metadata.sampleRate ?? "UNKNOWN"}hz", textStyle),
              _buildInfoText("路径  ${widget.metadata.path}", textStyle, maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [_buildActionButtons()],
    );
  }

  Widget _buildCover() {
    // 优先显示用户选择的新封面
    if (_currentCoverSource != null) {
      return _buildImageProvider(_getImageProvider(_currentCoverSource!));
    }

    // 否则，显示从文件加载的初始封面
    return FutureBuilder<_CoverSource>(
      future: _initialCoverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return _buildImageProvider(_getImageProvider(snapshot.data!));
        }
        // 加载中或失败时显示占位符
        return const SizedBox(height: _bigCoverSize, width: _bigCoverSize);
      },
    );
  }

  ImageProvider _getImageProvider(_CoverSource source) {
    if (source is _InitialCover) return MemoryImage(source.bytes);
    if (source is _GeneratedCover) return MemoryImage(source.bytes);
    if (source is _FileCover) {
        if (source.file.bytes != null) {
      return MemoryImage(source.file.bytes!);
    }
    }
    return MemoryImage(kTransparentImage);
  }

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
    required OutlineInputBorder border,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(border: border, labelText: label),
      ),
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
    return Padding(padding: const EdgeInsets.only(top: 16.0),child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isLoading
          ? Row(
              key: const ValueKey('saving'),
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "执行中……",
                  style: generalTextStyle(ctx: context, size: 'md', color: Theme.of(context).colorScheme.primary),
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
                _actionButton(label: "取消", onPressed: () => Navigator.pop(context)),
                _actionButton(label: "确定", onPressed: _saveChanges, isPrimary: true),
              ],
            ),
    ),);
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return CustomBtn(
      fn: onPressed,
      backgroundColor: isPrimary ? Theme.of(context).colorScheme.primary : Colors.transparent,
      contentColor: isPrimary ? Theme.of(context).colorScheme.onPrimary : null,
      overlayColor: isPrimary ? Theme.of(context).colorScheme.surfaceContainer : null,
      btnWidth: 108,
      btnHeight: 36,
      label: label,
    );
  }
}
