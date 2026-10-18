import '../../utils/func_extension.dart';

/// 按「月 + 歌曲」聚合的收听统计。
///
/// key 为 `$monthKey|$path.hashHex`，所以按月查询只需过滤 key 前缀，
/// 不必把全部历史载入内存。用于统计本月最常听的歌与艺术家。
class MonthlySongCache {
  /// 月份键，格式 `yyyy-MM`（本地时区）
  final String monthKey;

  /// 歌曲路径，同时作为关联曲库元数据的外键
  final String path;

  /// 歌曲标题，曲库中已删除该文件时作为兜底显示
  final String title;

  /// 原始艺术家字段
  final String artist;

  /// 本月该曲播放次数
  final int playedCount;

  /// 本月该曲播放时长（秒）
  final double playedTime;

  const MonthlySongCache({
    required this.monthKey,
    required this.path,
    required this.title,
    required this.artist,
    required this.playedCount,
    required this.playedTime,
  });

  /// 拼出存储用的复合 key
  static String buildKey({required String monthKey, required String path}) =>
      '$monthKey|${path.hashHex}';

  String get storageKey => buildKey(monthKey: monthKey, path: path);

  MonthlySongCache accumulate({
    required double deltaTime,
    required bool countPlay,
  }) {
    return MonthlySongCache(
      monthKey: monthKey,
      path: path,
      title: title,
      artist: artist,
      playedCount: playedCount + (countPlay ? 1 : 0),
      playedTime: playedTime + deltaTime,
    );
  }
}
