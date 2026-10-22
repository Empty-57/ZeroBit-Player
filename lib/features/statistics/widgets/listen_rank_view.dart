import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_empty_state.dart';
import 'package:zerobit_player/core/widgets/covers.dart';
import 'package:zerobit_player/core/widgets/slide_segmented_tabs.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/statistics/controller/statistics_ctrl.dart';
import 'package:zerobit_player/features/statistics/widgets/statistics_constant.dart';

import '../../../core/utils/format_time.dart';
import '../../../core/widgets/app_button/app_button.dart';

/// 榜单行用到的文本样式
typedef _RankTextStyles = ({
  TextStyle title,
  TextStyle sub,
  TextStyle count,
  TextStyle detail,
});

/// 播放排行
class ListenRankView extends StatefulWidget {
  const ListenRankView({super.key});

  @override
  State<ListenRankView> createState() => _ListenRankViewState();
}

class _ListenRankViewState extends State<ListenRankView> {
  int _tabIndex = 0;

  static const List<SegmentedTabItem> _tabs = [
    SegmentedTabItem(icon: PhosphorIconsLight.musicNotes, label: '常听歌曲'),
    SegmentedTabItem(icon: PhosphorIconsLight.user, label: '常听艺术家'),
  ];

  void _onTabChanged(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final styles = (
      title: context.createTextStyle(size: AppFontSize.md),
      sub: context.createTextStyle(
        size: AppFontSize.sm,
        opacity: AppAlpha.textTertiary,
      ),
      count: context.createTextStyle(
        size: AppFontSize.md,
        color: colorScheme.primary,
        weight: FontWeight.w600,
        tabularFigures: true,
      ),
      detail: context.createTextStyle(
        size: AppFontSize.xs,
        color: colorScheme.tertiary,
        tabularFigures: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        SlideSegmentedTabs(
          items: _tabs,
          selectedIndex: _tabIndex,
          onChanged: _onTabChanged,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppDuration.fast,
            child: _tabIndex == 0
                ? _MusicRankList(key: const ValueKey(0), styles: styles)
                : _ArtistRankList(key: const ValueKey(1), styles: styles),
          ),
        ),
      ],
    );
  }
}

/// 歌曲榜 Top50。
class _MusicRankList extends SignalWidget {
  final _RankTextStyles styles;

  const _MusicRankList({super.key, required this.styles});

  @override
  Widget build(BuildContext context) {
    final controller = StatisticsController.instance;
    final list = controller.playedTop50;

    if (list.isEmpty) {
      return const AppEmptyState(
        text: '还没有播放记录，听几首歌再回来看看',
        icon: PhosphorIconsLight.musicNotes,
      );
    }

    // 热度条以榜首为基准
    final topCount = list.first.statistics.playedCount;
    final totalCount = controller.totalPlayedCountRaw;

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(
        StatisticsLayout.rankTileHeight * 4,
      ),
      itemCount: list.length,
      itemExtent: StatisticsLayout.rankTileHeight,
      padding: const EdgeInsets.only(bottom: StatisticsLayout.listBottomInset),
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final item = list[index];
        final stat = item.statistics;

        return _RankTile(
          rank: index + 1,
          leading: LoadLocalOrNetCover(
            music: item.metadata,
            size: AppSize.coverSm,
            borderRadius: AppRadius.smAll,
          ),
          title: item.metadata.title,
          subtitle: item.metadata.artist,
          countText: '${stat.playedCount} 次',
          detailText: _detailOf(
            playedTime: stat.playedTime,
            count: stat.playedCount,
            totalCount: totalCount,
          ),
          heatRatio: _heatRatio(stat.playedCount, topCount),
          styles: styles,
          onTap: () =>
              AudioController.instance.audioPlay(metadata: item.metadata),
        );
      },
    );
  }
}

/// 艺术家榜 Top30
class _ArtistRankList extends SignalWidget {
  final _RankTextStyles styles;

  const _ArtistRankList({super.key, required this.styles});

  @override
  Widget build(BuildContext context) {
    final controller = StatisticsController.instance;
    final list = controller.artistTop30;

    if (list.isEmpty) {
      return const AppEmptyState(
        text: '还没有足够的数据生成艺术家榜',
        icon: PhosphorIconsLight.user,
      );
    }

    final topCount = list.first.playedCount;
    final totalCount = controller.totalPlayedCountRaw;

    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(
        StatisticsLayout.rankTileHeight * 4,
      ),
      itemCount: list.length,
      itemExtent: StatisticsLayout.rankTileHeight,
      padding: const EdgeInsets.only(bottom: StatisticsLayout.listBottomInset),
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        final item = list[index];
        final canOpen = item.pathList.isNotEmpty;

        return _RankTile(
          rank: index + 1,
          leading: _ArtistInitial(name: item.artist),
          title: item.artist,
          subtitle: '${item.pathList.length} 首曲目',
          countText: '${item.playedCount} 次',
          detailText: _detailOf(
            playedTime: item.playedTime,
            count: item.playedCount,
            totalCount: totalCount,
          ),
          heatRatio: _heatRatio(item.playedCount, topCount),
          styles: styles,
          onTap: canOpen
              ? () => context.push(
                  AppRoutes.details,
                  extra: {
                    'pathList': item.pathList,
                    'title': item.artist,
                    'operateArea': OperateArea.artistDetails,
                  },
                )
              : null,
        );
      },
    );
  }
}

double _heatRatio(int count, int topCount) =>
    topCount > 0 ? (count / topCount).clamp(0.0, 1.0) : 0.0;

/// 时长占总播放比例
String _detailOf({
  required double playedTime,
  required int count,
  required int totalCount,
}) {
  final time = formatTimeDHMS(playedTime.toInt());
  if (totalCount <= 0) return time;
  final share = count / totalCount * 100;
  return '$time · ${share.toStringAsFixed(1)}%';
}

/// 榜单行
class _RankTile extends StatelessWidget {
  final int rank;
  final Widget leading;
  final String title;
  final String subtitle;
  final String countText;
  final String detailText;

  /// 相对榜首的热度，0~1
  final double heatRatio;

  final _RankTextStyles styles;
  final VoidCallback? onTap;

  const _RankTile({
    required this.rank,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.countText,
    required this.detailText,
    required this.heatRatio,
    required this.styles,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: AppButton.ghost(
        onPressed: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: AppSpacing.lg,
                children: [
                  _RankBadge(rank: rank),
                  leading,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xxs,
                      children: [
                        Text(
                          title,
                          style: styles.title,
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: styles.sub,
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: StatisticsLayout.rankTrailingWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: AppSpacing.xxs,
                      children: [
                        Text(
                          countText,
                          style: styles.count,
                          softWrap: false,
                          maxLines: 1,
                        ),
                        Text(
                          detailText,
                          style: styles.detail,
                          softWrap: false,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 0,
              child: _HeatBar(ratio: heatRatio),
            ),
          ],
        ),
      ),
    );
  }
}

/// 排名徽章
class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (Color background, Color foreground) = switch (rank) {
      1 => (colorScheme.primary, colorScheme.onPrimary),
      2 || 3 => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      _ => (
        Colors.transparent,
        colorScheme.onSurfaceVariant.withValues(alpha: AppAlpha.textTertiary),
      ),
    };

    return Container(
      width: StatisticsLayout.rankBadgeSize,
      height: StatisticsLayout.rankBadgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.xsAll,
      ),
      child: Text(
        '$rank',
        style: context.createTextStyle(
          size: AppFontSize.sm,
          color: foreground,
          weight: FontWeight.w700,
          tabularFigures: true,
        ),
      ),
    );
  }
}

/// 艺术家缩略块
class _ArtistInitial extends StatelessWidget {
  final String name;

  const _ArtistInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Container(
      width: AppSize.coverSm,
      height: AppSize.coverSm,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: AppAlpha.surfaceStrong,
        ),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        initial,
        style: context.createTextStyle(
          size: AppFontSize.xl,
          weight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 行底部热度线
class _HeatBar extends StatelessWidget {
  final double ratio;

  const _HeatBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: AppSize.trackThin,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.outlineVariant.withValues(
                alpha: AppAlpha.track,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 0.6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: AppAlpha.surfaceStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
