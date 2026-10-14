import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/statistics/listening_heatmap.dart';
import 'package:zerobit_player/components/statistics/stat_surface.dart';
import 'package:zerobit_player/components/statistics/statistics_constant.dart';
import 'package:zerobit_player/components/widget/app_card.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 收听习惯页
class ListeningHabitsView extends StatelessWidget {
  const ListeningHabitsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StatisticsController.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: StatisticsLayout.listBottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: [
          SignalBuilder(
            builder: (_) => _MonthlyHighlightRow(
              highlight: controller.monthlyHighlight.value,
            ),
          ),
          SignalBuilder(
            builder: (_) => _HeatmapCard(data: controller.heatmap.value),
          ),
          SignalBuilder(
            builder: (_) => _HabitMetricsRow(habits: controller.habits.value),
          ),
        ],
      ),
    );
  }
}

/// 本月最常听的歌与艺术家
class _MonthlyHighlightRow extends StatelessWidget {
  final MonthlyHighlight highlight;

  const _MonthlyHighlightRow({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final song = highlight.topSong;
    final artist = highlight.topArtist;

    if (song == null && artist == null) {
      return const AppCard(
        child: StatEmptyState(
          text: '本月还没有收听记录',
          icon: PhosphorIconsLight.calendarBlank,
          dense: true,
        ),
      );
    }

    return Row(
      crossAxisAlignment: .center,
      spacing: AppSpacing.lg,
      children: [
        if (song != null) Expanded(child: _TopSongCard(song: song)),
        if (artist != null) Expanded(child: _TopArtistCard(artist: artist)),
      ],
    );
  }
}

class _TopSongCard extends StatelessWidget {
  final MonthlyTopSong song;

  const _TopSongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    final metadata = song.metadata;

    return _HighlightShell(
      badge: '本月最常听',
      badgeIcon: PhosphorIconsFill.musicNotes,
      onTap: metadata == null
          ? null
          : () => AudioController.instance.audioPlay(metadata: metadata),
      leading: metadata == null
          ? const _FallbackSquare(icon: PhosphorIconsLight.musicNote)
          : ClipRRect(
              borderRadius: AppRadius.smAll,
              child: LoadLocalOrNetCover(
                music: metadata,
                size: AppSize.coverMd,
              ),
            ),
      title: song.title,
      subtitle: song.artist,
      trailing: _CountBadge(
        count: song.playedCount,
        detail: formatTimeDHMS(song.playedTime.toInt()),
      ),
    );
  }
}

class _TopArtistCard extends StatelessWidget {
  final MonthlyTopArtist artist;

  const _TopArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = artist.artist;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return _HighlightShell(
      badge: '最常听艺术家',
      badgeIcon: PhosphorIconsFill.userSound,
      onTap: artist.pathList.isEmpty
          ? null
          : () => context.push(
              AppRoutes.details,
              extra: {
                'pathList': artist.pathList,
                'title': name,
                'operateArea': OperateArea.artistDetails,
              },
            ),
      leading: Container(
        width: AppSize.coverMd,
        height: AppSize.coverMd,
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
            size: AppFontSize.subtitle,
            weight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: name,
      subtitle: '听过 ${artist.songCount} 首',
      trailing: _CountBadge(
        count: artist.playedCount,
        detail: formatTimeDHMS(artist.playedTime.toInt()),
      ),
    );
  }
}

/// 两张强调卡共用的外壳
class _HighlightShell extends StatelessWidget {
  final String badge;
  final IconData badgeIcon;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _HighlightShell({
    required this.badge,
    required this.badgeIcon,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      emphasized: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          StatPill(text: badge, icon: badgeIcon),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: AppSpacing.lg,
            children: [
              leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      title,
                      style: context.createTextStyle(
                        size: AppFontSize.lg,
                        weight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: context.createTextStyle(
                        size: AppFontSize.sm,
                        opacity: AppAlpha.textSecondary,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final String detail;

  const _CountBadge({required this.count, required this.detail});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: AppSpacing.xxs,
      children: [
        Text(
          '$count',
          style: context.createTextStyle(
            size: AppFontSize.xxl,
            weight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        Text(
          '次 · $detail',
          style: context.createTextStyle(
            size: AppFontSize.xs,
            opacity: AppAlpha.textTertiary,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

class _FallbackSquare extends StatelessWidget {
  final IconData icon;

  const _FallbackSquare({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: AppSize.coverMd,
      height: AppSize.coverMd,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: AppAlpha.surface,
        ),
        borderRadius: AppRadius.smAll,
      ),
      child: Icon(
        icon,
        size: AppIconSize.lg,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 热力图卡
class _HeatmapCard extends StatelessWidget {
  final HeatmapData data;

  const _HeatmapCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.lg,
        children: [
          StatSectionHeader(
            title: '近期活跃度',
            caption: '共 ${data.totalCount} 次',
            trailing: const HeatmapLegend(),
          ),
          if (data.totalCount == 0)
            const StatEmptyState(
              text: '最近还没有收听记录',
              icon: PhosphorIconsLight.calendarBlank,
              dense: true,
            )
          else
            ListeningHeatmap(data: data),
        ],
      ),
    );
  }
}

/// 习惯指标
class _HabitMetricsRow extends StatelessWidget {
  final ListeningHabits habits;

  const _HabitMetricsRow({required this.habits});

  static String _formatHourRange(int hour) {
    if (hour < 0) return '—';
    final from = hour.toString().padLeft(2, '0');
    final to = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$from:00–$to:00';
  }

  @override
  Widget build(BuildContext context) {
    final busiest = habits.busiestDate;

    final metrics =
        <({String label, String value, String hint, IconData icon})>[
          (
            label: '常听时段',
            value: _formatHourRange(habits.peakHour),
            hint: habits.peakHourCount > 0
                ? '${habits.peakHourCount} 次'
                : '暂无数据',
            icon: PhosphorIconsLight.clockAfternoon,
          ),
          (
            label: '日均播放',
            value: habits.dailyAverage > 0
                ? habits.dailyAverage.toStringAsFixed(1)
                : '—',
            hint: '按 ${habits.activeDays} 个活跃日',
            icon: PhosphorIconsLight.chartLineUp,
          ),
          (
            label: '最长连续',
            value: habits.longestStreak > 0 ? '${habits.longestStreak} 天' : '—',
            hint: '连续收听天数',
            icon: PhosphorIconsLight.flame,
          ),
          (
            label: '最多播放',
            value: busiest == null ? '—' : '${busiest.month}/${busiest.day}',
            hint: habits.busiestDateCount > 0
                ? '${habits.busiestDateCount} 次'
                : '暂无数据',
            icon: PhosphorIconsLight.calendarStar,
          ),
        ];

    return SizedBox(
      height: StatisticsLayout.metricTileHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: [
          for (final m in metrics)
            Expanded(
              child: _MetricTile(
                label: m.label,
                value: m.value,
                hint: m.hint,
                icon: m.icon,
              ),
            ),
        ],
      ),
    );
  }
}

/// 指标卡
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Icon(
                icon,
                size: AppIconSize.xs,
                color: colorScheme.onSurfaceVariant,
              ),
              Text(
                label,
                style: context.createTextStyle(
                  size: AppFontSize.sm,
                  opacity: AppAlpha.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: context.createTextStyle(
              size: AppFontSize.xl,
              weight: FontWeight.w700,
              tabularFigures: true,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            hint,
            style: context.createTextStyle(
              size: AppFontSize.xs,
              opacity: AppAlpha.textTertiary,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
