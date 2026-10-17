import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/widget/app_button/app_button.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 列表 / 表格视图的曲目行
class MusicTile extends SignalWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final String audioSource;
  final String operateArea;
  final Signal<bool> isMulSelect;
  final ListSignal<MusicCache> selectedList;
  final bool viewMode;
  final DetailsPageControllerBase baseController;

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
    required this.viewMode,
    required this.baseController,
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
      baseController.play(audioSource, metadata: metadata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying =
        baseController.audioController.currentPath.value == metadata.path;
    final isSelected = selectedList.any((v) => v.path == metadata.path);

    final textStyle = isPlaying ? highLightTitleStyle : titleStyle;
    final subTextStyle = isPlaying ? highLightSubStyle : subStyle;

    return AppButton.ghost(
      onPressed: _onTileTapped,
      selected: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.xl,
        children: [
          if (operateArea == OperateArea.albumDetails)
            Text(
              metadata.trackNumber.toString().padLeft(2, '0'),
              style: subTextStyle,
            ),
          LoadLocalOrNetCover(music: metadata, size: AppSize.coverSm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  metadata.title,
                  style: textStyle,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  metadata.artist,
                  style: subTextStyle,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (viewMode)
            Expanded(
              flex: 2,
              child: Text(
                metadata.album,
                style: subTextStyle,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          Text(
            formatTime(totalSeconds: metadata.duration),
            style: subTextStyle,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
