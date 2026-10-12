import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/statistics/listening_habits_view.dart';
import 'package:zerobit_player/components/widget/general_btn.dart';
import 'package:zerobit_player/components/widget/music_tile.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

const double _resViewThresholds = 1100;
const double _itemHeight = 64.0;
const double _setBtnHeight = 40;

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
    final titleStyle = context.createTextStyle(
      size: AppFontSize.xl,
      weight: .w800,
      color: colorScheme.onPrimaryContainer,
    );
    final subStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: 0.8,
    );

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

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

/// 曲库概览
class _LibraryOverview extends StatelessWidget {
  const _LibraryOverview();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = StatisticsController.instance;

    final cards = <({Signal<String> value, String label, IconData icon})>[
      (
        value: controller.totalPlayedCount,
        label: '累计播放数',
        icon: PhosphorIconsRegular.play,
      ),
      (
        value: controller.totalPlayedTime,
        label: '累计播放时长',
        icon: PhosphorIconsRegular.timer,
      ),
      (
        value: controller.totalTime,
        label: '曲库总时长',
        icon: PhosphorIconsRegular.clock,
      ),
      (
        value: controller.totalSize,
        label: '曲库总大小',
        icon: PhosphorIconsRegular.hardDrives,
      ),
      (
        value: controller.albumArtist,
        label: '专辑 / 艺术家',
        icon: PhosphorIconsRegular.vinylRecord,
      ),
      (
        value: controller.totalSongCount,
        label: '总曲目',
        icon: PhosphorIconsRegular.musicNotes,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > _resViewThresholds ? 3 : 2;
        const spacing = 8.0;
        // 扣掉容器内边距与列间距后再均分
        final itemWidth =
            (constraints.maxWidth - 32 - spacing * (columns - 1)) / columns;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final card in cards)
                SizedBox(
                  width: itemWidth,
                  height: 56,
                  child: SignalBuilder(
                    builder: (_) => _DataCard(
                      title: card.value.value,
                      subTitle: card.label,
                      icon: card.icon,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _currentTabIndex = signal(0);
  bool _isForward = true;

  static const List<({IconData icon, String label, double width})> _tabs = [
    (icon: PhosphorIconsLight.ranking, label: '播放排行', width: 108),
    (icon: PhosphorIconsLight.chartBar, label: '收听分析', width: 108),
    (icon: PhosphorIconsLight.calendarDots, label: '收听习惯', width: 108),
  ];

  @override
  void dispose() {
    _currentTabIndex.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_currentTabIndex.value == index) return;
    _isForward = index > _currentTabIndex.value;
    _currentTabIndex.value = index;
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const _ListenRank();
      case 1:
        return const _ListeningDurationChart();
      case 2:
        return const ListeningHabitsView();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
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
                    style: context.createTextStyle(
                      size: AppFontSize.title,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '曲库概览与播放数据',
                    style: context.createTextStyle(size: AppFontSize.md),
                  ),
                  SignalBuilder(
                    builder: (_) {
                      return Row(
                        spacing: 8,
                        children: List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final isSelected = _currentTabIndex.value == index;
                          return GeneralBtn(
                            fn: () => _onTabChanged(index),
                            label: tab.label,
                            backgroundColor: colorScheme.secondaryContainer
                                .withValues(alpha: isSelected ? 0.6 : 0.2),
                            icon: tab.icon,
                            borderWidth: 1,
                            borderColor: colorScheme.primary.withValues(
                              alpha: isSelected ? 0.6 : 0.2,
                            ),
                            btnHeight: _setBtnHeight,
                            btnWidth: tab.width,
                            mainAxisAlignment: MainAxisAlignment.center,
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
              const Spacer(),
              GeneralBtn(
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
          const _LibraryOverview(),

          Expanded(
            child: SignalBuilder(
              builder: (_) {
                final tabIndex = _currentTabIndex.value;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    final isIncoming =
                        (child.key is ValueKey<int>) &&
                        (child.key as ValueKey<int>).value == tabIndex;

                    const double offsetDist = 0.1;
                    final double beginDx = _isForward
                        ? (isIncoming ? offsetDist : -offsetDist)
                        : (isIncoming ? -offsetDist : offsetDist);

                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(beginDx, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(tabIndex),
                    child: _buildContent(tabIndex),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListenRank extends StatefulWidget {
  const _ListenRank();

  @override
  State<_ListenRank> createState() => _ListenRankState();
}

class _ListenRankState extends State<_ListenRank> {
  final _currentRankIndex = signal(0);

  static const List<({IconData icon, String label, double width})> _rankTabs = [
    (icon: PhosphorIconsLight.musicNotes, label: '常听歌曲', width: 108),
    (icon: PhosphorIconsLight.user, label: '常听艺术家', width: 120),
  ];

  @override
  void dispose() {
    _currentRankIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final AudioController audioController = AudioController.instance;

    final statisticsTextStyle = context.createTextStyle(size: AppFontSize.md);
    final statisticsSubTextStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: 0.8,
    );
    final subTitleStyle = context.createTextStyle(size: AppFontSize.subtitle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SignalBuilder(
            builder: (_) {
              final tabIndex = _currentRankIndex.value;
              return Row(
                spacing: 8,
                children: List.generate(_rankTabs.length, (index) {
                  final tab = _rankTabs[index];
                  final isSelected = tabIndex == index;
                  return GeneralBtn(
                    fn: () {
                      if (tabIndex != index) {
                        _currentRankIndex.value = index;
                      }
                    },
                    label: tab.label,
                    icon: tab.icon,
                    backgroundColor: colorScheme.secondaryContainer.withValues(
                      alpha: isSelected ? 0.6 : 0.2,
                    ),
                    borderWidth: 1,
                    borderColor: colorScheme.primary.withValues(
                      alpha: isSelected ? 0.6 : 0.2,
                    ),
                    btnHeight: _setBtnHeight,
                    btnWidth: tab.width,
                    mainAxisAlignment: MainAxisAlignment.center,
                  );
                }),
              );
            },
          ),
        ),

        Expanded(
          child: SignalBuilder(
            builder: (_) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _currentRankIndex.value == 0
                    ? _buildMusicRank(
                        key: const ValueKey(0),
                        textStyle: statisticsTextStyle,
                        subTextStyle: statisticsSubTextStyle,
                        subTitleStyle: subTitleStyle,
                        audioController: audioController,
                      )
                    : _buildArtistRank(
                        key: const ValueKey(1),
                        textStyle: statisticsTextStyle,
                        subTextStyle: statisticsSubTextStyle,
                        subTitleStyle: subTitleStyle,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 歌手榜 Top30
  Widget _buildArtistRank({
    required Key key,
    required TextStyle textStyle,
    required TextStyle subTextStyle,
    required TextStyle subTitleStyle,
  }) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        return SignalBuilder(
          builder: (context) {
            final top30List = StatisticsController.instance.artistTop30;
            if (top30List.isEmpty) {
              return Center(child: Text('暂无数据', style: subTitleStyle));
            }

            return ListView.builder(
              scrollCacheExtent: const ScrollCacheExtent.pixels(
                _itemHeight * 4,
              ),
              itemCount: top30List.length,
              itemExtent: _itemHeight,
              addRepaintBoundaries: true,
              addAutomaticKeepAlives: false,
              addSemanticIndexes: false,
              padding: const EdgeInsets.only(bottom: _itemHeight * 2),
              itemBuilder: (_, index) {
                final item = top30List[index];

                return _StatisticsArtistTile(
                  textStyle: textStyle,
                  subTextStyle: subTextStyle,
                  rank: index + 1,
                  pathList: item.pathList,
                  artist: item.artist,
                  playedCount: item.playedCount,
                  playedTime: item.playedTime,
                  maxWidth: constraints.maxWidth,
                );
              },
            );
          },
        );
      },
    );
  }

  /// 播放榜 Top50
  Widget _buildMusicRank({
    required Key key,
    required TextStyle textStyle,
    required TextStyle subTextStyle,
    required TextStyle subTitleStyle,
    required AudioController audioController,
  }) {
    return SignalBuilder(
      key: key,
      builder: (context) {
        final top50List = StatisticsController.instance.playedTop50;
        if (top50List.isEmpty) {
          return Center(child: Text('暂无数据', style: subTitleStyle));
        }

        return ListView.builder(
          scrollCacheExtent: const ScrollCacheExtent.pixels(_itemHeight * 4),
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
              textStyle: textStyle,
              subTextStyle: subTextStyle,
              audioController: audioController,
              rank: rank,
              playStatistics: item.statistics,
            );
          },
        );
      },
    );
  }
}

const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class _StatisticsArtistTile extends StatelessWidget {
  final TextStyle textStyle;
  final TextStyle subTextStyle;
  final int rank;
  final List<String> pathList;
  final String artist;
  final int playedCount;
  final double playedTime;
  final double maxWidth;

  const _StatisticsArtistTile({
    required this.textStyle,
    required this.subTextStyle,
    required this.rank,
    required this.pathList,
    required this.artist,
    required this.playedCount,
    required this.playedTime,
    required this.maxWidth,
  });

  void _onTileTapped(BuildContext context) {
    context.push(
      AppRoutes.details,
      extra: {
        'pathList': pathList,
        'title': artist,
        'operateArea': OperateArea.artistDetails,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tertiaryColor = Theme.of(context).colorScheme.tertiary;
    final rankColor = rank < 4 ? primaryColor : null;

    double ratio = 0.0;
    final totalCount = StatisticsController.instance.totalPlayedCountRaw;
    if (totalCount > 0) {
      ratio = (playedCount / totalCount).clamp(0.0, 1.0);
    }

    return TextButton(
      onPressed: () => _onTileTapped(context),
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
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: textStyle,
                ),
                Row(
                  spacing: 8,
                  children: [
                    SizedBox(
                      child: Text(
                        '${(ratio * 100).toStringAsFixed(2).padLeft(6, ' ')}%',
                        style: subTextStyle,
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Container(
                      width: maxWidth * 0.9 * ratio,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: _borderRadius,
                        color: tertiaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: maxWidth * 0.1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$playedCount次',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: textStyle.copyWith(color: primaryColor),
                ),
                Text(
                  formatTimeDHMS(playedTime.toInt()),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: subTextStyle.copyWith(color: tertiaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeningDurationChart extends StatelessWidget {
  const _ListeningDurationChart();

  String _formatYAxisTime(double seconds) {
    if (seconds <= 0) return '0分';
    if (seconds < 3600) {
      return '${(seconds / 60).toStringAsFixed(0)}分';
    }
    return '${(seconds / 3600).toStringAsFixed(1)}时';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subTitleStyle = context.createTextStyle(size: AppFontSize.subtitle);
    final controller = StatisticsController.instance;

    return SignalBuilder(
      builder: (context) {
        final isWeekly =
            StatisticsControllerChartExtension.chartViewMode.value == 0;
        final chartData = isWeekly
            ? controller.getWeeklyChartData()
            : controller.getDailyChartData();

        final maxDuration = chartData.maxDuration > 0
            ? chartData.maxDuration
            : 3600.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                children: [
                  Text('收听时段分析', style: subTitleStyle),
                  const SizedBox(width: 16),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('每周')),
                      ButtonSegment(value: 1, label: Text('每日')),
                    ],
                    selected: {isWeekly ? 0 : 1},
                    onSelectionChanged: (val) {
                      StatisticsControllerChartExtension.hoveredBarIndex.value =
                          -1;
                      StatisticsControllerChartExtension.chartViewMode.value =
                          val.first;
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: colorScheme.primaryContainer,
                      selectedForegroundColor: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.caretLeft, size: 16),
                    tooltip: '向前切换',
                    onPressed: () {
                      StatisticsControllerChartExtension.hoveredBarIndex.value =
                          -1;
                      if (isWeekly) {
                        if (StatisticsControllerChartExtension
                                .selectedWeekOffset
                                .value <
                            3) {
                          StatisticsControllerChartExtension
                              .selectedWeekOffset
                              .value++;
                        }
                      } else {
                        if (StatisticsControllerChartExtension
                                .selectedDayOffset
                                .value <
                            27) {
                          StatisticsControllerChartExtension
                              .selectedDayOffset
                              .value++;
                        }
                      }
                    },
                  ),
                  Text(
                    chartData.periodTitle,
                    style: context.createTextStyle(
                      size: AppFontSize.md,
                      weight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.caretRight, size: 16),
                    tooltip: '向后切换',
                    onPressed: () {
                      StatisticsControllerChartExtension.hoveredBarIndex.value =
                          -1;
                      if (isWeekly) {
                        if (StatisticsControllerChartExtension
                                .selectedWeekOffset
                                .value >
                            0) {
                          StatisticsControllerChartExtension
                              .selectedWeekOffset
                              .value--;
                        }
                      } else {
                        if (StatisticsControllerChartExtension
                                .selectedDayOffset
                                .value >
                            0) {
                          StatisticsControllerChartExtension
                              .selectedDayOffset
                              .value--;
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '总计：${formatTimeDHMS(chartData.totalDuration.toInt())}',
                      style: context.createTextStyle(
                        size: AppFontSize.sm,
                        color: colorScheme.primary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: 20,
                child: SignalBuilder(
                  builder: (context) {
                    final hIdx = StatisticsControllerChartExtension
                        .hoveredBarIndex
                        .value;
                    if (hIdx >= 0 && hIdx < chartData.bars.length) {
                      return Text(
                        '${chartData.bars[hIdx].fullLabel}：${formatTimeDHMS(chartData.bars[hIdx].duration.toInt())}',
                        style: context.createTextStyle(
                          size: AppFontSize.sm,
                          color: colorScheme.tertiary,
                          weight: FontWeight.w600,
                        ),
                      );
                    }
                    return Text(
                      '鼠标悬停柱状图查看具体时段数据',
                      style: context.createTextStyle(
                        size: AppFontSize.sm,
                        opacity: 0.5,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    // Y轴刻度
                    SizedBox(
                      width: 48,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 4; i >= 0; i--)
                            Text(
                              _formatYAxisTime(maxDuration * (i / 4)),
                              style: context.createTextStyle(
                                size: AppFontSize.xs,
                                opacity: 0.6,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 绘图核心层
                    Expanded(
                      child: Stack(
                        children: [
                          // 背景 5 条参考线（填满）
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (int i = 0; i < 5; i++)
                                Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                            ],
                          ),

                          Positioned.fill(
                            child: RepaintBoundary(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (
                                      int i = 0;
                                      i < chartData.bars.length;
                                      i++
                                    )
                                      Expanded(
                                        child: _SmoothBarItem(
                                          key: ValueKey(
                                            '${isWeekly ? "w" : "d"}_$i',
                                          ),
                                          index: i,
                                          data: chartData.bars[i],
                                          maxDuration: maxDuration,
                                          maxHeight: 160.0,
                                          colorScheme: colorScheme,
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
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 0, right: 0),
                child: Row(
                  children: [
                    for (int i = 0; i < chartData.bars.length; i++)
                      Expanded(
                        child: Text(
                          chartData.bars[i].label,
                          textAlign: TextAlign.center,
                          style: context.createTextStyle(
                            size: AppFontSize.xs,
                            opacity: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SmoothBarItem extends StatefulWidget {
  final int index;
  final ChartBarData data;
  final double maxDuration;
  final double maxHeight;
  final ColorScheme colorScheme;

  const _SmoothBarItem({
    super.key,
    required this.index,
    required this.data,
    required this.maxDuration,
    required this.maxHeight,
    required this.colorScheme,
  });

  @override
  State<_SmoothBarItem> createState() => _SmoothBarItemState();
}

class _SmoothBarItemState extends State<_SmoothBarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ratio = (widget.data.duration / widget.maxDuration).clamp(0.0, 1.0);
    final targetHeight = ratio > 0
        ? (widget.maxHeight * ratio).clamp(4.0, widget.maxHeight)
        : 2.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        StatisticsControllerChartExtension.hoveredBarIndex.value = widget.index;
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (StatisticsControllerChartExtension.hoveredBarIndex.value ==
            widget.index) {
          StatisticsControllerChartExtension.hoveredBarIndex.value = -1;
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: targetHeight,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            color: _isHovered
                ? widget.colorScheme.primary
                : (ratio > 0
                      ? widget.colorScheme.primary.withValues(alpha: 0.65)
                      : widget.colorScheme.outlineVariant.withValues(
                          alpha: 0.2,
                        )),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.colorScheme.primary.withValues(alpha: 0.4)
                    : Colors.transparent,
                blurRadius: _isHovered ? 6 : 0,
                offset: const Offset(0, -1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
