import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/statistics_cache_model.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';

const double _coverSize = 48.0;
const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class MusicTile extends StatelessWidget {
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
    final Widget cover = LoadLocalOrNetCover(music: metadata, size: _coverSize);

    return SignalBuilder(
      builder: (context) {
        final isPlaying =
            baseController.audioController.currentPath.value == metadata.path;
        final isSelected = selectedList.any((v) => v.path == metadata.path);

        final subTextStyle = isPlaying ? highLightSubStyle : subStyle;
        final textStyle = isPlaying ? highLightTitleStyle : titleStyle;

        return TextButton(
          onPressed: _onTileTapped.throttle(ms: isMulSelect.value ? 10 : 500),
          style: TextButton.styleFrom(
            shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: _itemSpacing,
            children: [
              if (operateArea == OperateArea.albumDetails)
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
              if (viewMode)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _itemSpacing,
                    ),
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
      },
    );
  }
}

class StatisticsMusicTile extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle textStyle;
  final TextStyle subTextStyle;
  final int rank;
  final StatisticsCache playStatistics;
  final AudioController audioController;

  const StatisticsMusicTile({
    super.key,
    required this.metadata,
    required this.textStyle,
    required this.subTextStyle,
    required this.audioController,
    required this.rank,
    required this.playStatistics,
  });

  void _onTileTapped() {
    audioController.audioPlay(metadata: metadata);
  }

  @override
  Widget build(BuildContext context) {
    final Widget cover = LoadLocalOrNetCover(music: metadata, size: _coverSize);

    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;
    final rankColor = rank < 4 ? primaryColor : null;

    return TextButton(
      onPressed: _onTileTapped.throttle(ms: 500),
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: _itemSpacing,
        children: [
          Text(
            rank.toString().padLeft(2, ' '),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: textStyle.copyWith(color: rankColor),
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
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${playStatistics.playedCount}次',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: textStyle.copyWith(color: primaryColor),
              ),
              Text(
                formatTimeDHMS(playStatistics.playedTime.toInt()),
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: subTextStyle.copyWith(color: tertiaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
