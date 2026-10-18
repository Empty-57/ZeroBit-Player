class StatisticsCache {
  final String title;
  final String path;
  final int playedCount;
  final double playedTime;
  final int recordTimestamp;

  const StatisticsCache({
    required this.title,
    required this.path,
    required this.playedCount,
    required this.playedTime,
    required this.recordTimestamp,
  });
}
