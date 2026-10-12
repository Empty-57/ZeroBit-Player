import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';

/// 日期键工具。统一走本地时区，保证写入与聚合用的是同一套键。
abstract class StatKeys {
  static String _two(int v) => v.toString().padLeft(2, '0');

  /// `yyyy-MM-dd`
  static String day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// `yyyy-MM`
  static String month(DateTime d) => '${d.year}-${_two(d.month)}';

  /// 把日期归一到当天零点，便于做天数差与连续性判断
  static DateTime atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 本周周一零点；热力图与周视图共用同一个周起点
  static DateTime mondayOf(DateTime d) =>
      atMidnight(d).subtract(Duration(days: d.weekday - 1));
}

/// 热力图中的一格
class HeatmapCell {
  final DateTime date;
  final int playedCount;
  final double playedTime;

  /// 0 表示无记录，1~4 为由当期最大值分出的强度档
  final int level;

  /// 是否是未来日期（本周尚未到来的格子，渲染为占位）
  final bool isFuture;

  const HeatmapCell({
    required this.date,
    required this.playedCount,
    required this.playedTime,
    required this.level,
    required this.isFuture,
  });
}

/// 最近 N 周的热力图数据，按周分列、周一起算
class HeatmapData {
  /// 外层为周（最早的一周在前），内层固定 7 天（周一 → 周日）
  final List<List<HeatmapCell>> weeks;
  final int maxCount;
  final int totalCount;

  const HeatmapData({
    required this.weeks,
    required this.maxCount,
    required this.totalCount,
  });

  static const HeatmapData empty = HeatmapData(
    weeks: [],
    maxCount: 0,
    totalCount: 0,
  );
}

/// 收听习惯概览指标
class ListeningHabits {
  /// 播放次数最多的小时（0~23），无数据时为 -1
  final int peakHour;

  /// 峰值小时的播放次数
  final int peakHourCount;

  /// 日均播放数，以「有记录的天数」为分母
  final double dailyAverage;

  /// 最长连续听歌天数
  final int longestStreak;

  /// 播放次数最多的日期，无数据时为 null
  final DateTime? busiestDate;
  final int busiestDateCount;

  /// 统计覆盖的有记录天数
  final int activeDays;

  const ListeningHabits({
    required this.peakHour,
    required this.peakHourCount,
    required this.dailyAverage,
    required this.longestStreak,
    required this.busiestDate,
    required this.busiestDateCount,
    required this.activeDays,
  });

  static const ListeningHabits empty = ListeningHabits(
    peakHour: -1,
    peakHourCount: 0,
    dailyAverage: 0,
    longestStreak: 0,
    busiestDate: null,
    busiestDateCount: 0,
    activeDays: 0,
  );
}

/// 本月最常听的歌
class MonthlyTopSong {
  final String title;
  final String artist;
  final int playedCount;
  final double playedTime;

  /// 曲库中对应的元数据，为 null 时说明文件已不在库里（仅用标题兜底显示）
  final MusicCache? metadata;

  const MonthlyTopSong({
    required this.title,
    required this.artist,
    required this.playedCount,
    required this.playedTime,
    required this.metadata,
  });
}

/// 本月最常听的艺术家
class MonthlyTopArtist {
  final String artist;
  final int playedCount;
  final double playedTime;

  /// 该艺术家本月听过的曲目数
  final int songCount;

  /// 该艺术家在曲库中的全部曲目路径，用于跳转艺术家详情页
  final List<String> pathList;

  const MonthlyTopArtist({
    required this.artist,
    required this.playedCount,
    required this.playedTime,
    required this.songCount,
    required this.pathList,
  });
}

/// 本月强调区数据
class MonthlyHighlight {
  final MonthlyTopSong? topSong;
  final MonthlyTopArtist? topArtist;

  const MonthlyHighlight({required this.topSong, required this.topArtist});

  static const MonthlyHighlight empty = MonthlyHighlight(
    topSong: null,
    topArtist: null,
  );
}
