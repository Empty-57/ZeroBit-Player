import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../field/audio_source.dart';
import '../tools/format_time.dart';

const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();
final AudioSource _audioSource = Get.find<AudioSource>();

class MusicTile extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final String audioSource;
  final String operateArea;
  final RxBool isMulSelect;
  final RxList<MusicCache> selectedList;

  const MusicTile({
    super.key,
    required this.metadata,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.audioSource,
    required this.operateArea,
    required this.isMulSelect,
    required this.selectedList,
  });

  void _onTileTapped() {
    if (isMulSelect.value) {
      final index = selectedList.indexWhere((v) => v.path == metadata.path);
      if (index != -1) {
        selectedList.removeAt(index);
      } else {
        selectedList.add(metadata);
      }
    } else {
      _audioSource.currentAudioSource.value = audioSource;
      _audioController.audioPlay(metadata: metadata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget cover = AsyncCover(music: metadata);

    return Obx(() {
      final isPlaying = _audioController.currentPath.value == metadata.path;
      final isSelected = selectedList.any((v) => v.path == metadata.path);
      final showAlbum = _settingController.viewModeMap[operateArea] ?? false;

      final subTextStyle = isPlaying ? highLightSubStyle : subStyle;
      final textStyle = isPlaying ? highLightTitleStyle : titleStyle;

      return TextButton(
        onPressed: _onTileTapped.throttle(ms: isMulSelect.value ? 10 : 500),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
          backgroundColor:
              isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: _itemSpacing,
          children: [
            if (operateArea == OperateArea.albumList)
              Text(
                metadata.trackNumber.toString().padLeft(2, '0'),
                style: subTextStyle,
              ),
            cover,
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.title,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: textStyle,
                  ),
                  Text(
                    metadata.artist,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: subTextStyle,
                  ),
                ],
              ),
            ),
            if (showAlbum)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _itemSpacing),
                  child: Text(
                    metadata.album,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: subTextStyle,
                  ),
                ),
              ),
            Text(
              formatTime(totalSeconds: metadata.duration),
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: subTextStyle,
            ),
          ],
        ),
      );
    });
  }
}

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

class AsyncCover extends StatefulWidget {
  final MusicCache music;
  const AsyncCover({super.key, required this.music});

  @override
  State<AsyncCover> createState() => _AsyncCoverState();
}

class _AsyncCoverState extends State<AsyncCover> {
  Future<Uint8List?>? _coverFuture;

  // 记录上一次渲染的图片内存地址，用于对比外部是否发生了修改
  Uint8List? _lastSrc;

  @override
  void initState() {
    super.initState();
    _lastSrc = widget.music.src;
    if (_lastSrc == null) {
      _coverFuture = _loadCoverAndSave();
    }
  }

  @override
  void didUpdateWidget(AsyncCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.music.src != _lastSrc) {
      setState(() {
        // 判断数据是否发生更改
        _lastSrc = widget.music.src;
        if (_lastSrc == null) {
          _coverFuture = _loadCoverAndSave();
        } else {
          _coverFuture = null;
        }
      });
    }
  }

  Future<Uint8List?> _loadCoverAndSave() async {
    Uint8List? finalData;
    final coverData = await getCover(path: widget.music.path, sizeFlag: 0);

    if (coverData == null) {
      final title = widget.music.title;
      final artist =
          (widget.music.artist.isNotEmpty && widget.music.artist != 'UNKNOWN')
              ? ' - ${widget.music.artist}'
              : '';
      final generatedData = await saveCoverByText(
        text: title + artist,
        songPath: widget.music.path,
      );
      if (generatedData != null && generatedData.isNotEmpty) {
        finalData = Uint8List.fromList(generatedData);
      }
    } else {
      finalData = coverData;
    }

    if (finalData != null && mounted) {
      widget.music.src = finalData;
      _lastSrc = finalData; // 同步记录，防止 didUpdateWidget 误判
    }

    return finalData;
  }

  Widget _renderCover(Uint8List imageBytes) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheResolution = (_coverSize * dpr).round();

    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Image.memory(
        imageBytes,
        key: ValueKey(imageBytes.hashCode), // 只要图片数据变了，就重建
        width: _coverSize,
        height: _coverSize,
        fit: BoxFit.cover,
        cacheWidth: cacheResolution,
        cacheHeight: cacheResolution,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lastSrc != null) {
      return _renderCover(_lastSrc!);
    }

    return FutureBuilder<Uint8List?>(
      future: _coverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return _renderCover(snapshot.data!);
        }
        return Container(
          height: _coverSize,
          width: _coverSize,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: _coverBorderRadius,
          ),
        );
      },
    );
  }
}
