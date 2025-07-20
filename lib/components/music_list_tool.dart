import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'dart:typed_data';
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
      // 使用 Set 进行contains检查会更快，但对于小列表List也可以接受。
      if (selectedList.any((v) => v.path == metadata.path)) {
        selectedList.removeWhere((v) => v.path == metadata.path);
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
    final Widget cover = AsyncCover(path: metadata.path, music: metadata);

    return Obx(() {
      final isPlaying = _audioController.currentPath.value == metadata.path;
      final isSelected = selectedList.any((v) => v.path == metadata.path);

      final subTextStyle = isPlaying ? highLightSubStyle : subStyle;
      final textStyle = isPlaying ? highLightTitleStyle : titleStyle;

      return TextButton(
        onPressed: _onTileTapped.throttle(ms: isMulSelect.value ? 10 : 500),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius), // 使用const
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: _itemSpacing,
          children: [
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
            Obx(() {
              if (_settingController.viewModeMap[operateArea]??false) {
                return Expanded(
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
                );
              }
              return const SizedBox.shrink();
            }),
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
const int _coverSmallRenderSize = 150;

class AsyncCover extends StatelessWidget {
  final String path;
  final MusicCache music;
  const AsyncCover({super.key, required this.path, required this.music});

  Widget _renderCover() {
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: Image.memory(
        music.src!,
        width: _coverSize,
        height: _coverSize,
        fit: BoxFit.cover,
        cacheWidth: _coverSmallRenderSize,
        cacheHeight: _coverSmallRenderSize,
        gaplessPlayback: true, // 防止图片突然闪烁
      ),
    );
  }

  Future<Uint8List?> _loadCover() async {
    final coverData = await getCover(path: path, sizeFlag: 0);
    if (coverData == null) {
      final title = music.title;
      final artist = music.artist.isNotEmpty ? ' - ${music.artist}' : '';
      final coverData_ = await saveCoverByText(
        text: title + artist,
        songPath: path,
      );
      if (coverData_ != null && coverData_.isNotEmpty) {
        return Uint8List.fromList(coverData_);
      }
    }
    return coverData;
  }

  @override
  Widget build(BuildContext context) {
    return music.src == null
        ? FutureBuilder<Uint8List?>(
          future: _loadCover(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              music.src = snapshot.data!;

              return _renderCover();
            }
            return SizedBox(height: _coverSize, width: _coverSize);
          },
        )
        : _renderCover();
  }
}
