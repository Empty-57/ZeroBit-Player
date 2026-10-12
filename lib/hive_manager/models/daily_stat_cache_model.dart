/// 按日聚合的收听统计。
///
/// 每天一条，key 为 [dayKey]。热力图、常听时段、日均播放数、最长连续天数、
/// 听歌最多日期都由它聚合得出。
class DailyStatCache {
  /// 日期键，格式 `yyyy-MM-dd`（本地时区）
  final String dayKey;

  /// 当日播放次数
  final int playedCount;

  /// 当日播放时长（秒）
  final double playedTime;

  /// 24 个小时槽的播放次数，索引即小时数
  final List<int> hourCounts;

  /// 24 个小时槽的播放时长（秒），索引即小时数
  final List<double> hourTimes;

  const DailyStatCache({
    required this.dayKey,
    required this.playedCount,
    required this.playedTime,
    required this.hourCounts,
    required this.hourTimes,
  });

  /// 小时槽数量
  static const int hourSlots = 24;

  DailyStatCache.empty(this.dayKey)
    : playedCount = 0,
      playedTime = 0.0,
      hourCounts = List<int>.filled(hourSlots, 0),
      hourTimes = List<double>.filled(hourSlots, 0.0);

  /// 在 [hour] 槽上累加一次收听。返回新实例，列表为复制后的新列表。
  DailyStatCache accumulate({
    required int hour,
    required double deltaTime,
    required bool countPlay,
  }) {
    final slot = hour.clamp(0, hourSlots - 1);
    final nextCounts = List<int>.of(hourCounts);
    final nextTimes = List<double>.of(hourTimes);
    if (countPlay) nextCounts[slot] += 1;
    nextTimes[slot] += deltaTime;

    return DailyStatCache(
      dayKey: dayKey,
      playedCount: playedCount + (countPlay ? 1 : 0),
      playedTime: playedTime + deltaTime,
      hourCounts: nextCounts,
      hourTimes: nextTimes,
    );
  }
}
