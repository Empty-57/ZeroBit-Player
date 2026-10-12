import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/statistics/listening_heatmap.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

const double _cardRadius = 10.0;
const BorderRadius _cardBorderRadius = BorderRadius.all(
  Radius.circular(_cardRadius),
);

/// 收听习惯页
class ListeningHabitsView extends StatelessWidget {
  const ListeningHabitsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StatisticsController.instance;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
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
          const SizedBox(height: 64),
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
      return const _EmptyHint(text: '本月还没有收听记录');
    }

    // 外层是可滚动区，垂直方向无界，stretch 无从确定高度；
    // 用 IntrinsicHeight 让并列的卡片按最高者对齐（只有两张，开销可忽略）
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (song != null) Expanded(child: _TopSongCard(song: song)),
          if (artist != null) Expanded(child: _TopArtistCard(artist: artist)),
        ],
      ),
    );
  }
}

class _TopSongCard extends StatelessWidget {
  final MonthlyTopSong song;

  const _TopSongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = song.metadata;

    return _HighlightShell(
      badge: '本月最常听',
      badgeIcon: PhosphorIconsFill.musicNotes,
      onTap: metadata == null
          ? null
          : () => AudioController.instance.audioPlay(metadata: metadata),
      leading: metadata == null
          ? _FallbackSquare(
              icon: PhosphorIconsLight.musicNote,
              colorScheme: colorScheme,
            )
          : ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: LoadLocalOrNetCover(music: metadata, size: 56),
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
    // 按字素簇取首字，避免把 emoji 或组合字符切坏
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
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.7),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Text(
          initial,
          style: generalTextStyle(
            ctx: context,
            size: 'subtitle',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
      borderRadius: _cardBorderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: _cardBorderRadius,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: _cardBorderRadius,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(badgeIcon, size: 13, color: colorScheme.primary),
                  Text(
                    badge,
                    style: generalTextStyle(
                      ctx: context,
                      size: 'xs',
                      color: colorScheme.primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 12,
                children: [
                  leading,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          title,
                          style: generalTextStyle(
                            ctx: context,
                            size: 'lg',
                            weight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: generalTextStyle(
                            ctx: context,
                            size: 'sm',
                            opacity: 0.7,
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
        ),
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
      spacing: 2,
      children: [
        // 数值用比例字形，不加等宽：等宽会让这种大号数字看起来松散
        Text(
          '$count',
          style: generalTextStyle(
            ctx: context,
            size: '2xl',
            weight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        Text(
          '次 · $detail',
          style: generalTextStyle(ctx: context, size: 'xs', opacity: 0.6),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}

class _FallbackSquare extends StatelessWidget {
  final IconData icon;
  final ColorScheme colorScheme;

  const _FallbackSquare({required this.icon, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
    );
  }
}

/// 热力图卡
class _HeatmapCard extends StatelessWidget {
  final HeatmapData data;

  const _HeatmapCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: _cardBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '近期活跃度',
                style: generalTextStyle(
                  ctx: context,
                  size: 'subtitle',
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '共 ${data.totalCount} 次',
                style: generalTextStyle(
                  ctx: context,
                  size: 'sm',
                  opacity: 0.65,
                ),
              ),
              const Spacer(),
              const HeatmapLegend(),
            ],
          ),
          if (data.totalCount == 0)
            const _EmptyHint(text: '最近还没有收听记录')
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
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: _cardBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
              Text(
                label,
                style: generalTextStyle(
                  ctx: context,
                  size: 'sm',
                  opacity: 0.75,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: generalTextStyle(
              ctx: context,
              size: 'xl',
              weight: FontWeight.w700,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            hint,
            style: generalTextStyle(ctx: context, size: 'xs', opacity: 0.55),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        text,
        style: generalTextStyle(ctx: context, size: 'md', opacity: 0.5),
      ),
    );
  }
}
