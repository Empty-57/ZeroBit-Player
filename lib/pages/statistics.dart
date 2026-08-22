import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/components/music_list_tool.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

const double _resViewThresholds = 1100;
const double _itemHeight = 64.0;

class _DataCard extends StatelessWidget {
  final String title;
  final String subTitle;
  final IconData icon;

  const _DataCard({
    required this.title,
    required this.subTitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = generalTextStyle(
      ctx: context,
      size: 'xl',
      weight: .w800,
      color: colorScheme.onPrimaryContainer,
    );
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    return Row(
      spacing: 12,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),

          child: Icon(icon, color: colorScheme.primary, size: 18),
        ),
        Column(
          spacing: 2,
          crossAxisAlignment: .start,
          mainAxisAlignment: .center,
          children: [
            Text(
              title,
              style: titleStyle,
              softWrap: false,
              maxLines: 1,
              overflow: .fade,
            ),
            Text(
              subTitle,
              style: subStyle,
              softWrap: false,
              maxLines: 1,
              overflow: .fade,
            ),
          ],
        ),
      ],
    );
  }
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final AudioController audioController = Get.find<AudioController>();

    final titleStyle = generalTextStyle(ctx: context, size: 'md');

    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    final subTitleStyle = generalTextStyle(ctx: context, size: 'subtitle');

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            crossAxisAlignment: .center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '统计与数据',
                    style: generalTextStyle(
                      ctx: context,
                      size: 'title',
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '曲库概览与播放数据',
                    style: generalTextStyle(ctx: context, size: 'md'),
                  ),
                ],
              ),
              const Spacer(),
              CustomBtn(
                fn: () {
                  StatisticsController.instance.refresh();
                },
                icon: PhosphorIconsLight.arrowClockwise,
                tooltip: '刷新',
                contentColor: colorScheme.primary,
                btnHeight: 36,
                btnWidth: 36,
                backgroundColor: colorScheme.secondaryContainer.withValues(
                  alpha: 0.6,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: context.width > _resViewThresholds ? 3 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 64,
              children: [
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.totalPlayedCount.value,
                    subTitle: '累计播放数',
                    icon: PhosphorIconsRegular.play,
                  ),
                ),
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.totalPlayedTime.value,
                    subTitle: '累计播放时长',
                    icon: PhosphorIconsRegular.timer,
                  ),
                ),
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.totalTime.value,
                    subTitle: '曲库总时长',
                    icon: PhosphorIconsRegular.clock,
                  ),
                ),
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.totalSize.value,
                    subTitle: '曲库总大小',
                    icon: PhosphorIconsRegular.hardDrives,
                  ),
                ),
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.albumArtist.value,
                    subTitle: '专辑 / 艺术家',
                    icon: PhosphorIconsRegular.vinylRecord,
                  ),
                ),
                Obx(
                  () => _DataCard(
                    title: StatisticsController.instance.totalSongCount.value,
                    subTitle: '总曲目',
                    icon: PhosphorIconsRegular.musicNotes,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 8,
              children: [
                Text('播放榜 Top50', style: subTitleStyle),
                Expanded(
                  child: Obx(() {
                    final top50List = StatisticsController.instance.playedTop50;
                    if (top50List.isEmpty) {
                      return Center(child: Text('暂无数据', style: subTitleStyle));
                    }

                    return ListView.builder(
                      scrollCacheExtent: const ScrollCacheExtent.pixels(
                        _itemHeight * 4,
                      ),
                      itemCount: top50List.length,
                      itemExtent: _itemHeight,
                      padding: const EdgeInsets.only(bottom: _itemHeight * 2),
                      addRepaintBoundaries: true,
                      addAutomaticKeepAlives: false,
                      addSemanticIndexes: false,
                      itemBuilder: (_, index) {
                        final item = top50List[index];
                        final rank = index + 1;

                        return StatisticsMusicTile(
                          metadata: item.metadata,
                          titleStyle: titleStyle,
                          subStyle: subStyle,
                          audioController: audioController,
                          rank: rank,
                          playStatistics: item.statistics,
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
