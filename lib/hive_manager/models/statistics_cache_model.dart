class StatisticsCache {
  final String title;
  final int playedCount;
  final double playedTime;
  final int recordTimestamp;

  const StatisticsCache({
    required this.title,
    required this.playedCount,
    required this.playedTime,
    required this.recordTimestamp,
  });
}
