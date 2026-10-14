import 'package:flutter/material.dart';
import 'package:zerobit_player/components/statistics/statistics_constant.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';
import 'package:zerobit_player/tools/statistics_models.dart';

/// 收听热力图的单色相色阶。
class HeatmapPalette {
  final Color emptyCell;
  final List<Color> levels;

  const HeatmapPalette({required this.emptyCell, required this.levels});

  factory HeatmapPalette.of(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = scheme.primary;
    // 向表面色混合
    final stops = isDark
        ? const [0.70, 0.50, 0.28, 0.0]
        : const [0.74, 0.52, 0.28, 0.0];

    return HeatmapPalette(
      emptyCell: isDark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.85),
      levels: [
        for (final t in stops) Color.lerp(base, scheme.surface, t) ?? base,
      ],
    );
  }

  /// level 0 为无记录，1~4 对应由浅到深的四档
  Color colorOf(int level) {
    if (level <= 0) return emptyCell;
    return levels[(level - 1).clamp(0, levels.length - 1)];
  }
}

/// 收听热力图
class ListeningHeatmap extends StatelessWidget {
  final HeatmapData data;

  const ListeningHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.weeks.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final palette = HeatmapPalette.of(colorScheme);
    final labelStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textTertiary,
    );

    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 列标签：每月
              Row(
                children: [
                  const SizedBox(width: StatisticsHeatmapSpec.weekLabelWidth),
                  for (int i = 0; i < data.weeks.length; i++)
                    SizedBox(
                      width: StatisticsHeatmapSpec.cellExtent,
                      height: StatisticsHeatmapSpec.columnLabelHeight,
                      child: Text(
                        // 跨月的那一列才标月份
                        i == 0 ||
                                data.weeks[i].first.date.month !=
                                    data.weeks[i - 1].first.date.month
                            ? '${data.weeks[i].first.date.month}月'
                            : '',
                        style: labelStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                ],
              ),
              // 7 行 × N 列栅格，按行排布便于左侧对齐星期标签
              for (
                int row = 0;
                row < StatisticsHeatmapSpec.weekdayLabels.length;
                row++
              )
                Row(
                  children: [
                    SizedBox(
                      width: StatisticsHeatmapSpec.weekLabelWidth,
                      height: StatisticsHeatmapSpec.cellExtent,
                      child: Center(
                        child: Text(
                          StatisticsHeatmapSpec.weekdayLabels[row],
                          style: labelStyle,
                        ),
                      ),
                    ),
                    for (final week in data.weeks)
                      _HeatmapCellTile(cell: week[row], palette: palette),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapCellTile extends StatelessWidget {
  final HeatmapCell cell;
  final HeatmapPalette palette;

  const _HeatmapCellTile({required this.cell, required this.palette});

  @override
  Widget build(BuildContext context) {
    // 未来的格子只占位，不画色块，避免读成「那天没听」
    if (cell.isFuture) {
      return const SizedBox(
        width: StatisticsHeatmapSpec.cellExtent,
        height: StatisticsHeatmapSpec.cellExtent,
      );
    }

    final detail = cell.playedCount > 0
        ? '${cell.date.month}月${cell.date.day}日 · ${cell.playedCount} 次 · ${formatTimeDHMS(cell.playedTime.toInt())}'
        : '${cell.date.month}月${cell.date.day}日 · 未收听';

    return Tooltip(
      message: detail,
      waitDuration: AppDuration.tooltipWait,
      // 外层 padding 既充当格子间隙，也把命中区域撑到 cellExtent
      child: Padding(
        padding: const EdgeInsets.all(StatisticsHeatmapSpec.cellGap),
        child: Container(
          width: StatisticsHeatmapSpec.cellSize,
          height: StatisticsHeatmapSpec.cellSize,
          decoration: BoxDecoration(
            color: palette.colorOf(cell.level),
            borderRadius: StatisticsHeatmapSpec.cellRadius,
          ),
        ),
      ),
    );
  }
}

/// 色阶图例
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = HeatmapPalette.of(colorScheme);
    final labelStyle = context.createTextStyle(
      size: AppFontSize.xs,
      opacity: AppAlpha.textTertiary,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.sm,
      children: [
        Text('少', style: labelStyle),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: StatisticsHeatmapSpec.legendGap,
          children: [
            for (
              int level = 0;
              level <= StatisticsHeatmapSpec.maxLevel;
              level++
            )
              Container(
                width: StatisticsHeatmapSpec.legendBoxSize,
                height: StatisticsHeatmapSpec.legendBoxSize,
                decoration: BoxDecoration(
                  color: palette.colorOf(level),
                  borderRadius: AppRadius.xsAll,
                ),
              ),
          ],
        ),
        Text('多', style: labelStyle),
      ],
    );
  }
}
