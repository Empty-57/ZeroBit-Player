import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';
import 'package:zerobit_player/tools/statistics_models.dart';

/// 格子边长
const double _cellSize = 15.0;

/// 格子之间留的表面间隙
const double _cellGap = 3.0;

/// 行列标签宽/高
const double _weekLabelWidth = 30.0;
const double _columnLabelHeight = 18.0;

const BorderRadius _cellRadius = BorderRadius.all(Radius.circular(3));

const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
      opacity: 0.6,
    );

    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: .horizontal,
        child: Padding(
          padding: const EdgeInsetsGeometry.only(right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 列标签：每月
              Row(
                children: [
                  const SizedBox(width: _weekLabelWidth),
                  for (int i = 0; i < data.weeks.length; i++)
                    () {
                      final m = data.weeks[i].first.date.month;
                      return SizedBox(
                        width: _cellSize + _cellGap * 2,
                        height: _columnLabelHeight,
                        child: Text(
                          i == 0 || m != data.weeks[i - 1].first.date.month
                              ? '$m月'
                              : '',
                          style: labelStyle,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                      );
                    }(),
                ],
              ),
              // 7 行 × N 列栅格，按行排布便于左侧对齐星期标签
              for (int row = 0; row < 7; row++)
                Row(
                  children: [
                    SizedBox(
                      width: _weekLabelWidth,
                      height: _cellSize + _cellGap * 2,
                      child: Center(
                        child: Text(_weekdayLabels[row], style: labelStyle),
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
        width: _cellSize + _cellGap * 2,
        height: _cellSize + _cellGap * 2,
      );
    }

    final detail = cell.playedCount > 0
        ? '${cell.date.month}月${cell.date.day}日 · ${cell.playedCount} 次 · ${formatTimeDHMS(cell.playedTime.toInt())}'
        : '${cell.date.month}月${cell.date.day}日 · 未收听';

    return Tooltip(
      message: detail,
      waitDuration: const Duration(milliseconds: 120),
      // 外层 padding 既充当格子间隙，也把命中区域撑到 21px
      child: Padding(
        padding: const EdgeInsets.all(_cellGap),
        child: Container(
          width: _cellSize,
          height: _cellSize,
          decoration: BoxDecoration(
            color: palette.colorOf(cell.level),
            borderRadius: _cellRadius,
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
      opacity: 0.6,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('少', style: labelStyle),
        const SizedBox(width: 6),
        for (int level = 0; level <= 4; level++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: palette.colorOf(level),
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text('多', style: labelStyle),
      ],
    );
  }
}
