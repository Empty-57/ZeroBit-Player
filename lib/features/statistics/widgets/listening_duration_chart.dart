import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_card.dart';
import 'package:zerobit_player/core/widgets/slide_segmented_tabs.dart';
import 'package:zerobit_player/features/statistics/controller/statistics_ctrl.dart';
import 'package:zerobit_player/features/statistics/widgets/stat_surface.dart';
import 'package:zerobit_player/features/statistics/widgets/statistics_constant.dart';

import '../../../core/utils/format_time.dart';
import '../../../core/widgets/app_button/app_button.dart';

/// 绘图区左边界：让出 Y 轴刻度列与间隙。
/// 柱子层与标签层都以它为左起点，两层才能严格对齐。
const double _plotLeft =
    StatisticsChartSpec.axisLabelWidth + StatisticsChartSpec.axisGap;

/// 把峰值向上取整到 [StatisticsChartSpec.tickSteps] 内的刻度
double _niceAxisMax(double peakSeconds) {
  if (peakSeconds <= 0) return StatisticsChartSpec.emptyAxisMax;

  const divisions = StatisticsChartSpec.tickDivisions;
  final rawStep = peakSeconds / divisions;
  for (final step in StatisticsChartSpec.tickSteps) {
    if (step >= rawStep) return step * divisions;
  }
  // 超出候选步长时按整小时向上取
  return (rawStep / Duration.secondsPerHour).ceilToDouble() *
      Duration.secondsPerHour *
      divisions;
}

/// Y 轴刻度文案
String _formatTick(double seconds) {
  if (seconds <= 0) return '0';
  if (seconds < Duration.secondsPerHour) {
    return '${(seconds / Duration.secondsPerMinute).round()}分';
  }
  final hours = seconds / Duration.secondsPerHour;
  return hours == hours.roundToDouble()
      ? '${hours.round()}时'
      : '${hours.toStringAsFixed(1)}时';
}

/// 收听时段分析：按周 / 按日两种维度的柱状图。
class ListeningDurationChart extends SignalWidget {
  const ListeningDurationChart({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = StatisticsController.instance;

    // 订阅版本号依赖
    controller.statsRevision.value;

    final isWeekly = StatisticsChartState.isWeekly;
    final chartData = isWeekly
        ? controller.getWeeklyChartData()
        : controller.getDailyChartData();
    final axisMax = _niceAxisMax(chartData.maxDuration);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: StatisticsLayout.listBottomInset),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.lg,
          children: [
            _ChartToolbar(
              isWeekly: isWeekly,
              offset: StatisticsChartState.offsetOf.value,
              maxOffset: StatisticsChartState.maxOffset,
              periodTitle: chartData.periodTitle,
            ),
            _ChartCanvas(
              bars: chartData.bars,
              axisMax: axisMax,
              totalDuration: chartData.totalDuration,
              isWeekly: isWeekly,
            ),
            Divider(
              height: AppSize.trackThin,
              thickness: AppSize.trackThin,
              color: colorScheme.outlineVariant.withValues(
                alpha: AppAlpha.border,
              ),
            ),
            _ChartSummary(
              bars: chartData.bars,
              totalDuration: chartData.totalDuration,
              isWeekly: isWeekly,
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部工具条
class _ChartToolbar extends StatelessWidget {
  final bool isWeekly;
  final int offset;
  final int maxOffset;
  final String periodTitle;

  const _ChartToolbar({
    required this.isWeekly,
    required this.offset,
    required this.maxOffset,
    required this.periodTitle,
  });

  static const List<SegmentedTabItem> _modes = [
    SegmentedTabItem(icon: PhosphorIconsLight.calendarBlank, label: '每周'),
    SegmentedTabItem(icon: PhosphorIconsLight.clock, label: '每日'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.lg,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: AppSpacing.lg,
            children: [
              Flexible(
                child: Text(
                  '收听时段分析',
                  style: context.createTextStyle(
                    size: AppFontSize.lg,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
              SlideSegmentedTabs(
                items: _modes,
                selectedIndex: isWeekly
                    ? ChartViewMode.weekly
                    : ChartViewMode.daily,
                onChanged: StatisticsChartState.switchViewMode,
                segmentWidth: StatisticsChartSpec.modeSegmentWidth,
                height: StatisticsChartSpec.modeSegmentHeight,
              ),
              const Spacer(),
            ],
          ),
        ),
        _PeriodPager(
          isWeekly: isWeekly,
          offset: offset,
          maxOffset: maxOffset,
          title: periodTitle,
        ),
      ],
    );
  }
}

/// 时段翻页器
class _PeriodPager extends StatelessWidget {
  final bool isWeekly;
  final int offset;
  final int maxOffset;
  final String title;

  const _PeriodPager({
    required this.isWeekly,
    required this.offset,
    required this.maxOffset,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final unit = isWeekly ? '周' : '天';

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.md,
      children: [
        _PagerButton(
          icon: PhosphorIconsLight.caretLeft,
          tooltip: '上一$unit',
          onPressed: offset < maxOffset
              ? () => StatisticsChartState.shiftPeriod(1)
              : null,
        ),
        SizedBox(
          width: StatisticsChartSpec.periodTitleWidth,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.createTextStyle(
              size: AppFontSize.md,
              weight: FontWeight.w600,
              tabularFigures: true,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
          ),
        ),
        _PagerButton(
          icon: PhosphorIconsLight.caretRight,
          tooltip: '下一$unit',
          onPressed: offset > 0
              ? () => StatisticsChartState.shiftPeriod(-1)
              : null,
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _PagerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return AppButton.icon(
      onPressed: onPressed,
      tooltip: enabled ? tooltip : null,
      icon: icon,
      height: StatisticsChartSpec.pagerButton,
      size: .small,
    );
  }
}

/// 绘图区
class _ChartCanvas extends StatefulWidget {
  final List<ChartBarData> bars;
  final double axisMax;
  final double totalDuration;
  final bool isWeekly;

  const _ChartCanvas({
    required this.bars,
    required this.axisMax,
    required this.totalDuration,
    required this.isWeekly,
  });

  @override
  State<_ChartCanvas> createState() => _ChartCanvasState();
}

class _ChartCanvasState extends State<_ChartCanvas> {
  /// 悬停的柱子索引
  int _hovered = -1;

  @override
  void didUpdateWidget(_ChartCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isWeekly != widget.isWeekly ||
        oldWidget.bars.length != widget.bars.length) {
      _hovered = -1;
    }
  }

  void _setHovered(int index) {
    if (!mounted || _hovered == index) return;
    setState(() => _hovered = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        _ReadoutLine(
          bars: widget.bars,
          hoveredIndex: _hovered,
          totalDuration: widget.totalDuration,
        ),
        _ChartBody(
          bars: widget.bars,
          axisMax: widget.axisMax,
          isWeekly: widget.isWeekly,
          hoveredIndex: _hovered,
          onHover: _setHovered,
        ),
      ],
    );
  }
}

/// 读数行
class _ReadoutLine extends StatelessWidget {
  final List<ChartBarData> bars;
  final int hoveredIndex;
  final double totalDuration;

  const _ReadoutLine({
    required this.bars,
    required this.hoveredIndex,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bar = hoveredIndex >= 0 && hoveredIndex < bars.length
        ? bars[hoveredIndex]
        : null;

    return SizedBox(
      height: StatisticsChartSpec.readoutHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.lg,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDuration.instant,
              child: bar == null
                  ? Row(
                      key: const ValueKey(-1),
                      spacing: AppSpacing.sm,
                      children: [
                        Icon(
                          PhosphorIconsLight.cursorClick,
                          size: AppIconSize.xs,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppAlpha.textFaint,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '悬停柱状图查看具体时段数据',
                            style: context.createTextStyle(
                              size: AppFontSize.sm,
                              opacity: AppAlpha.textFaint,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: ValueKey(hoveredIndex),
                      spacing: AppSpacing.md,
                      children: [
                        Container(
                          width: AppSpacing.md,
                          height: AppSpacing.md,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary,
                            borderRadius: AppRadius.xsAll,
                          ),
                        ),
                        Text(
                          bar.fullLabel,
                          style: context.createTextStyle(
                            size: AppFontSize.sm,
                            weight: FontWeight.w600,
                            tabularFigures: true,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                        Flexible(
                          child: Text(
                            formatTimeDHMS(bar.duration.toInt()),
                            style: context.createTextStyle(
                              size: AppFontSize.sm,
                              color: colorScheme.tertiary,
                              weight: FontWeight.w600,
                              tabularFigures: true,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          StatPill(
            text: '总计 ${formatTimeDHMS(totalDuration.toInt())}',
            icon: PhosphorIconsLight.hourglass,
          ),
        ],
      ),
    );
  }
}

/// 图表主体
class _ChartBody extends StatelessWidget {
  final List<ChartBarData> bars;
  final double axisMax;
  final bool isWeekly;
  final int hoveredIndex;
  final ValueChanged<int> onHover;

  const _ChartBody({
    required this.bars,
    required this.axisMax,
    required this.isWeekly,
    required this.hoveredIndex,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          StatisticsChartSpec.plotHeight + StatisticsChartSpec.labelRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: StatisticsChartSpec.plotHeight,
            child: _GridLayer(axisMax: axisMax),
          ),
          Positioned(
            left: _plotLeft,
            right: 0,
            top: 0,
            height: StatisticsChartSpec.plotHeight,
            child: RepaintBoundary(
              child: Row(
                children: [
                  for (int i = 0; i < bars.length; i++)
                    Expanded(
                      child: _ChartBar(
                        key: ValueKey('${isWeekly ? 'w' : 'd'}_$i'),
                        data: bars[i],
                        axisMax: axisMax,
                        hovered: i == hoveredIndex,
                        onEnter: () => onHover(i),
                        onExit: () => onHover(-1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: _plotLeft,
            right: 0,
            bottom: 0,
            height: StatisticsChartSpec.labelRowHeight,
            child: _LabelsLayer(bars: bars, hoveredIndex: hoveredIndex),
          ),
        ],
      ),
    );
  }
}

/// 网格层 + Y标签
class _GridLayer extends StatelessWidget {
  final double axisMax;

  const _GridLayer({required this.axisMax});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tickStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textTertiary,
      tabularFigures: true,
    );
    const divisions = StatisticsChartSpec.tickDivisions;
    const rowHeight = StatisticsChartSpec.tickRowHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i <= divisions; i++)
          Positioned(
            // 自上往下第 i 条线对应刻度值 axisMax * (divisions - i) / divisions
            top: StatisticsChartSpec.plotHeight * i / divisions - rowHeight / 2,
            left: 0,
            right: 0,
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: StatisticsChartSpec.axisLabelWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatTick(axisMax * (divisions - i) / divisions),
                      style: tickStyle,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: StatisticsChartSpec.axisGap),
                Expanded(
                  child: SizedBox(
                    height: AppSize.hairline,
                    child: ColoredBox(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: i == divisions
                            ? AppAlpha.borderStrong
                            : AppAlpha.border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// X 轴标签层
class _LabelsLayer extends StatelessWidget {
  final List<ChartBarData> bars;
  final int hoveredIndex;

  const _LabelsLayer({required this.bars, required this.hoveredIndex});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final idleStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textSecondary,
      tabularFigures: true,
    );
    final activeStyle = idleStyle.copyWith(
      color: colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    return Row(
      children: [
        for (int i = 0; i < bars.length; i++)
          Expanded(
            child: Text(
              bars[i].label,
              textAlign: TextAlign.center,
              style: i == hoveredIndex ? activeStyle : idleStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
      ],
    );
  }
}

/// 单根柱子
class _ChartBar extends StatelessWidget {
  final ChartBarData data;
  final double axisMax;
  final bool hovered;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const _ChartBar({
    super.key,
    required this.data,
    required this.axisMax,
    required this.hovered,
    required this.onEnter,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = data.duration > 0;
    final ratio = (data.duration / axisMax).clamp(0.0, 1.0);
    final height = hasData
        ? (StatisticsChartSpec.plotHeight * ratio).clamp(
            StatisticsChartSpec.barMinHeight,
            StatisticsChartSpec.plotHeight,
          )
        : StatisticsChartSpec.barEmptyHeight;

    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StatisticsChartSpec.barGap / 2,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: StatisticsChartSpec.barFactor,
            child: AnimatedContainer(
              duration: AppDuration.slow,
              curve: AppCurve.standard,
              height: height,
              decoration: BoxDecoration(
                color: hasData
                    ? colorScheme.primary.withValues(
                        alpha: hovered
                            ? StatisticsChartSpec.barHoverAlpha
                            : StatisticsChartSpec.barAlpha,
                      )
                    : colorScheme.primary.withValues(
                        alpha: hovered
                            ? StatisticsChartSpec.barHoverAlpha
                            : AppAlpha.hover,
                      ),
                borderRadius: const BorderRadius.vertical(
                  top: StatisticsChartSpec.barTopRadius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 本期摘要
class _ChartSummary extends StatelessWidget {
  final List<ChartBarData> bars;
  final double totalDuration;
  final bool isWeekly;

  const _ChartSummary({
    required this.bars,
    required this.totalDuration,
    required this.isWeekly,
  });

  @override
  Widget build(BuildContext context) {
    int activeCount = 0;
    ChartBarData? peak;
    for (final bar in bars) {
      if (bar.duration <= 0) continue;
      activeCount++;
      if (peak == null || bar.duration > peak.duration) peak = bar;
    }

    final style = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: AppAlpha.textTertiary,
      tabularFigures: true,
    );

    if (activeCount == 0 || peak == null) {
      return Text('本期没有收听记录', style: style);
    }

    final unit = isWeekly ? '天' : '个时段';
    final average = totalDuration / activeCount;
    final text = [
      '${bars.length}$unit中 $activeCount$unit有收听',
      '峰值 ${peak.fullLabel} · ${formatTimeDHMS(peak.duration.toInt())}',
      '活跃均值 ${formatTimeDHMS(average.toInt())}',
    ].join('   ·   ');

    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.fade);
  }
}
