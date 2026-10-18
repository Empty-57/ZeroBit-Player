import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/slide_segmented_tabs.dart';
import 'package:zerobit_player/features/statistics/controller/statistics_ctrl.dart';

import '../../../core/widgets/app_button/app_button.dart';
import '../widgets/library_overview.dart';
import '../widgets/listen_rank_view.dart';
import '../widgets/listening_duration_chart.dart';
import '../widgets/listening_habits_view.dart';
import '../widgets/statistics_constant.dart';

/// 统计页
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _tabIndex = 0;
  bool _isForward = true;

  static const List<SegmentedTabItem> _tabs = [
    SegmentedTabItem(icon: PhosphorIconsLight.ranking, label: '播放排行'),
    SegmentedTabItem(icon: PhosphorIconsLight.chartBar, label: '收听分析'),
    SegmentedTabItem(icon: PhosphorIconsLight.calendarDots, label: '收听习惯'),
  ];

  void _onTabChanged(int index) {
    if (_tabIndex == index) return;
    setState(() {
      _isForward = index > _tabIndex;
      _tabIndex = index;
    });
  }

  Widget _buildContent(int index) => switch (index) {
    0 => const ListenRankView(),
    1 => const ListeningDurationChart(),
    _ => const ListeningHabitsView(),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xl,
        children: [
          _buildHeader(context),
          const LibraryOverview(),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDuration.fast,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) {
                // 进场的一方从切换方向的一侧滑入，离场的一方往反方向退出
                final isIncoming =
                    child.key is ValueKey<int> &&
                    (child.key as ValueKey<int>).value == _tabIndex;
                const distance = StatisticsLayout.tabSlideOffset;
                final beginDx = _isForward == isIncoming ? distance : -distance;

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
                key: ValueKey(_tabIndex),
                child: _buildContent(_tabIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
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
                style: context.createTextStyle(
                  size: AppFontSize.md,
                  opacity: AppAlpha.textSecondary,
                ),
              ),
              SlideSegmentedTabs(
                items: _tabs,
                selectedIndex: _tabIndex,
                onChanged: _onTabChanged,
              ),
            ],
          ),
        ),
        const _RefreshButton(),
      ],
    );
  }
}

/// 刷新按钮
class _RefreshButton extends StatefulWidget {
  const _RefreshButton();

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  );

  bool _refreshing = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    unawaited(_spin.forward(from: 0));
    try {
      await StatisticsController.instance.refresh();
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppButton.secondary(
      onPressed: () => unawaited(_refresh()),
      tooltip: '刷新统计数据',
      padding: const EdgeInsets.all(0),
      width: AppSize.iconButton,
      height: AppSize.iconButton,
      child: RotationTransition(
        turns: _spin.drive(CurveTween(curve: AppCurve.inOut)),
        child: Icon(
          PhosphorIconsLight.arrowClockwise,
          size: AppIconSize.sm,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
