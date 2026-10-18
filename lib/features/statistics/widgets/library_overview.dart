import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';
import 'package:zerobit_player/core/widgets/app_card.dart';
import 'package:zerobit_player/features/statistics/controller/statistics_ctrl.dart';
import 'package:zerobit_player/features/statistics/widgets/statistics_constant.dart';

/// 曲库概览
class LibraryOverview extends StatelessWidget {
  const LibraryOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StatisticsController.instance;

    final valueStyle = context.createTextStyle(
      size: AppFontSize.xl,
      weight: FontWeight.w700,
      tabularFigures: true,
    );
    final labelStyle = context.createTextStyle(
      size: AppFontSize.sm,
      opacity: AppAlpha.textTertiary,
    );

    final items = <({Signal<String> value, String label, IconData icon})>[
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

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > StatisticsLayout.wideBreakpoint
              ? StatisticsLayout.overviewColumnsWide
              : StatisticsLayout.overviewColumnsNarrow;

          // LayoutBuilder 位于卡片内边距之内，拿到的宽度已扣掉 padding，直接均分即可
          const double spacing = AppSpacing.lg;
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  height: StatisticsLayout.overviewTileHeight,
                  child: SignalBuilder(
                    builder: (_) => _OverviewTile(
                      value: item.value.value,
                      label: item.label,
                      icon: item.icon,
                      valueStyle: valueStyle,
                      labelStyle: labelStyle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  const _OverviewTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.valueStyle,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      spacing: AppSpacing.lg,
      children: [
        Container(
          width: StatisticsLayout.overviewIconBox,
          height: StatisticsLayout.overviewIconBox,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: AppAlpha.fill),
            borderRadius: AppRadius.xsAll,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: AppAlpha.border),
              width: AppSize.hairline,
            ),
          ),
          child: Center(
            child: Icon(icon, color: colorScheme.primary, size: AppIconSize.sm),
          ),
        ),
        Expanded(
          child: Column(
            spacing: AppSpacing.xxs,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: value,
                waitDuration: AppDuration.tooltipWait,
                child: Text(
                  value,
                  style: valueStyle,
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
              ),
              Text(
                label,
                style: labelStyle,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.fade,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
