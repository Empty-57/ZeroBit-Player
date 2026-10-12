import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/hive_manager/models/daily_stat_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/monthly_song_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/statistics_cache_model.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/statistics_models.dart';

import '../logger.dart';

export 'package:zerobit_player/tools/statistics_models.dart';

class ChartBarData {
  final String label;
  final String fullLabel;
  final double duration;

  const ChartBarData({
    required this.label,
    required this.fullLabel,
    required this.duration,
  });
}

class ChartData {
  final String periodTitle;
  final double totalDuration;
  final double maxDuration;
  final List<ChartBarData> bars;

  const ChartData({
    required this.periodTitle,
    required this.totalDuration,
    required this.maxDuration,
    required this.bars,
  });
}

String _formatMonthDay(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

extension StatisticsControllerChartExtension on StatisticsController {
  // 0: 每周视图, 1: 每日视图
  static final chartViewMode = signal<int>(0);

  // 0 为本周，最多到 3
  static final selectedWeekOffset = signal<int>(0);

  // 0 为今天，最多到 27
  static final selectedDayOffset = signal<int>(0);

  // 当前鼠标悬浮柱子索引（-1为无悬浮）
  static final hoveredBarIndex = signal<int>(-1);

  /// 获取当前选择的每周视图数据
  ChartData getWeeklyChartData() {
    final offset = selectedWeekOffset.value;
    final targetMonday = StatKeys.mondayOf(
      DateTime.now(),
    ).subtract(Duration(days: offset * 7));

    const weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final bars = <ChartBarData>[];
    double total = 0;
    double maxDuration = 0;

    for (int i = 0; i < 7; i++) {
      final date = targetMonday.add(Duration(days: i));
      final duration = dailyStatOf(date)?.playedTime ?? 0.0;
      total += duration;
      if (duration > maxDuration) maxDuration = duration;

      bars.add(
        ChartBarData(
          label: weekLabels[i],
          fullLabel: '${weekLabels[i]} (${_formatMonthDay(date)})',
          duration: duration,
        ),
      );
    }

    final targetSunday = targetMonday.add(const Duration(days: 6));
    final range =
        '${_formatMonthDay(targetMonday)} - ${_formatMonthDay(targetSunday)}';
    final periodTitle = switch (offset) {
      0 => '本周 ($range)',
      1 => '上周 ($range)',
      _ => '$offset周前 ($range)',
    };

    return ChartData(
      periodTitle: periodTitle,
      totalDuration: total,
      maxDuration: maxDuration,
      bars: bars,
    );
  }

  /// 获取当前选择的每日视图数据
  ChartData getDailyChartData() {
    final offset = selectedDayOffset.value;
    final targetDay = StatKeys.atMidnight(
      DateTime.now(),
    ).subtract(Duration(days: offset));

    final hourTimes =
        dailyStatOf(targetDay)?.hourTimes ??
        List<double>.filled(DailyStatCache.hourSlots, 0.0);

    final bars = <ChartBarData>[];
    double total = 0;
    double maxDuration = 0;

    for (int h = 0; h < DailyStatCache.hourSlots; h++) {
      final duration = hourTimes[h];
      total += duration;
      if (duration > maxDuration) maxDuration = duration;

      final hh = h.toString().padLeft(2, '0');
      final next = (h + 1).toString().padLeft(2, '0');
      bars.add(
        ChartBarData(
          label: (h % 4 == 0) ? '$hh:00' : '',
          fullLabel: '$hh:00 - $next:00',
          duration: duration,
        ),
      );
    }

    final periodTitle = switch (offset) {
      0 => '今天 (${_formatMonthDay(targetDay)})',
      1 => '昨天 (${_formatMonthDay(targetDay)})',
      _ => '$offset天前 (${_formatMonthDay(targetDay)})',
    };

    return ChartData(
      periodTitle: periodTitle,
      totalDuration: total,
      maxDuration: maxDuration,
      bars: bars,
    );
  }
}

class StatisticsController {
  StatisticsController._();

  static final instance = StatisticsController._();

  final MusicCacheController _musicCacheController =
      MusicCacheController.instance;

  final AudioController _audioController = AudioController.instance;

  final _statisticsCacheBox = HiveBox.statisticsCacheBox;
  final _dailyStatBox = HiveBox.dailyStatCacheBox;
  final _monthlySongBox = HiveBox.monthlySongCacheBox;

  final totalTime = signal('0 M');
  final totalSize = signal('0 B');
  final albumArtist = signal('0 / 0');
  final totalSongCount = signal('0');

  double totalPlayedTimeRaw = 0;
  int totalPlayedCountRaw = 0;

  final totalPlayedTime = signal('0 M');
  final totalPlayedCount = signal('0');

  List<StatisticsCache> playedStatisticsList = [];

  final playedTop50 = listSignal(<RankedMusicItem>[]);
  final artistTop30 = listSignal(<RankedArtistItem>[]);

  /// 按日聚合，key 为 `yyyy-MM-dd`
  final Map<String, DailyStatCache> _dailyStats = {};

  /// 当月「月 + 歌曲」聚合，key 为歌曲路径。跨月时重新装载。
  final Map<String, MonthlySongCache> _monthSongs = {};
  String _loadedMonthKey = '';

  /// 待落盘的键，避免每次 tick 全量写 Hive
  final Set<String> _dirtyDayKeys = {};
  final Set<String> _dirtyMonthSongKeys = {};

  /// 聚合结果的版本号。写入统计时自增，驱动下面几个 computed 重算。
  final statsRevision = signal(0);

  /// 热力图
  late final heatmap = computed(() {
    statsRevision.value;
    return _buildHeatmap();
  });

  /// 收听习惯概览（常听时段 / 日均 / 连续天数 / 最多日期）
  late final habits = computed(() {
    statsRevision.value;
    return _buildHabits();
  });

  /// 本月强调区（最常听的歌 / 艺术家）
  late final monthlyHighlight = computed(() {
    statsRevision.value;
    return _buildMonthlyHighlight();
  });

  String? _lastTitle; // 上次统计对应的歌曲标题
  num _lastSec = 0; // 上次统计时的播放进度
  bool _countedThisPlay = false; // 本次收听是否已经记过一次播放数
  bool _rankDirty = true; // 排行榜是否需要重算

  Timer? _updateLoopTimer;
  static const Duration _updateDuration = Duration(seconds: 30);

  /// 热力图展示的最大周数
  static const int _heatmapMaxWeeks = 52;

  /// 热力图展示的最小周数
  static const int _heatmapMinWeeks = 8;

  /// 按日数据保留天数，超出的在启动时清理
  static const int _dailyRetentionDays = 400;

  /// 按月歌曲数据保留月数
  static const int _monthlyRetentionMonths = 13;

  Future<void> init() async {
    playedStatisticsList = _statisticsCacheBox.getAll();
    _loadTimeSlicedStats();
    await refresh();
    sortList();

    _updateLoopTimer?.cancel();
    _updateLoopTimer = Timer.periodic(_updateDuration, (_) {
      updateStatistics();
      _saveStatistics().then(
        (_) => LoggerUni.i("听歌统计数据自动保存成功"),
        onError: (Object e, StackTrace stackTrace) {
          LoggerUni.e("自动保存统计数据失败", e, stackTrace);
        },
      );
    });
  }

  /// 装载按日 / 当月歌曲数据，并清掉过期记录
  void _loadTimeSlicedStats() {
    final today = StatKeys.atMidnight(DateTime.now());
    _loadedMonthKey = StatKeys.month(today);

    _dailyStats.clear();
    final staleDayKeys = <String>[];
    final earliestDay = today.subtract(
      const Duration(days: _dailyRetentionDays),
    );
    for (final stat in _dailyStatBox.getAll()) {
      final date = _parseDayKey(stat.dayKey);
      if (date == null || date.isBefore(earliestDay)) {
        staleDayKeys.add(stat.dayKey);
        continue;
      }
      _dailyStats[stat.dayKey] = stat;
    }

    _monthSongs.clear();
    final staleSongKeys = <String>[];
    final earliestMonth = DateTime(
      today.year,
      today.month - _monthlyRetentionMonths,
    );
    for (final song in _monthlySongBox.getAll()) {
      final month = _parseMonthKey(song.monthKey);
      if (month == null || month.isBefore(earliestMonth)) {
        staleSongKeys.add(song.storageKey);
        continue;
      }
      if (song.monthKey == _loadedMonthKey) {
        _monthSongs[song.path] = song;
      }
    }

    if (staleDayKeys.isNotEmpty) {
      unawaited(_dailyStatBox.delAll(keyList: staleDayKeys));
    }
    if (staleSongKeys.isNotEmpty) {
      unawaited(_monthlySongBox.delAll(keyList: staleSongKeys));
    }
  }

  static DateTime? _parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static DateTime? _parseMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return DateTime(y, m);
  }

  /// 读取某天的聚合记录，没有记录则为 null
  DailyStatCache? dailyStatOf(DateTime date) => _dailyStats[StatKeys.day(date)];

  Future<void> refresh() async {
    _rankDirty = true;
    updateStatistics();
    totalTime.value = _getTotalTime();
    totalSize.value = await _getTotalSize();
    batch(() {
      albumArtist.value =
          '${_musicCacheController.albumItemsDict.length} / ${_musicCacheController.artistItemsDict.length}';
      totalSongCount.value = _musicCacheController.items.length.toString();

      totalPlayedCountRaw = playedStatisticsList.fold(
        0,
        (sum, item) => sum + item.playedCount,
      );

      totalPlayedCount.value = totalPlayedCountRaw.toString();

      totalPlayedTimeRaw = playedStatisticsList.fold(
        0.0,
        (sum, item) => sum + item.playedTime,
      );

      totalPlayedTime.value = formatTimeDHMS(totalPlayedTimeRaw.toInt());
    });
    statsRevision.value++;
  }

  void updateStatistics() {
    final metadata = _audioController.currentMetadata.value;
    final sec = _audioController.currentSec.value;
    final duration = _audioController.currentDuration.value;
    if (duration <= 0) return;

    // 检测到歌曲切换：重置增量基准和计数标志
    if (_lastTitle != metadata.title) {
      _lastTitle = metadata.title;
      _lastSec = 0;
      _countedThisPlay = false;
    }

    if (sec < duration / 4) {
      sortList();
      return;
    } // 未达到统计门槛，不记录

    final delta = sec - _lastSec;
    if (delta <= 0) {
      // 用户往回 seek 了，或没有新增播放时长，不累加，但仍更新基准防止后续算错
      _lastSec = sec;
      return;
    }
    _lastSec = sec;

    final isRecordCount = !_countedThisPlay && sec >= duration / 2;
    if (isRecordCount) _countedThisPlay = true;

    final index = playedStatisticsList.indexWhere(
      (v) => v.title == metadata.title,
    );
    if (index == -1) {
      playedStatisticsList.add(
        StatisticsCache(
          title: metadata.title,
          path: metadata.path,
          playedCount: isRecordCount ? 1 : 0,
          playedTime: delta,
          recordTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      final oldData = playedStatisticsList[index];
      playedStatisticsList[index] = StatisticsCache(
        title: oldData.title,
        path: oldData.path,
        playedCount: oldData.playedCount + (isRecordCount ? 1 : 0),
        playedTime: oldData.playedTime + delta,
        recordTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    _recordTimeSliced(
      metadata: metadata,
      delta: delta.toDouble(),
      countPlay: isRecordCount,
    );

    batch(() {
      totalPlayedTimeRaw += delta;
      totalPlayedTime.value = formatTimeDHMS(totalPlayedTimeRaw.toInt());

      if (isRecordCount) {
        totalPlayedCountRaw++;
        totalPlayedCount.value = totalPlayedCountRaw.toString();
      }
      statsRevision.value++;
    });

    _rankDirty = true;
    sortList();
  }

  /// 把这次增量同时写进按日与按月聚合表
  void _recordTimeSliced({
    required MusicCache metadata,
    required double delta,
    required bool countPlay,
  }) {
    final now = DateTime.now();
    final dayKey = StatKeys.day(now);
    final monthKey = StatKeys.month(now);

    final daily = _dailyStats[dayKey] ?? DailyStatCache.empty(dayKey);
    _dailyStats[dayKey] = daily.accumulate(
      hour: now.hour,
      deltaTime: delta,
      countPlay: countPlay,
    );
    _dirtyDayKeys.add(dayKey);

    // 跨月后内存里装的是上个月的数据，先换成新月份再累加
    if (monthKey != _loadedMonthKey) {
      _loadedMonthKey = monthKey;
      _monthSongs.clear();
    }

    final existing = _monthSongs[metadata.path];
    _monthSongs[metadata.path] =
        existing?.accumulate(deltaTime: delta, countPlay: countPlay) ??
        MonthlySongCache(
          monthKey: monthKey,
          path: metadata.path,
          title: metadata.title,
          artist: metadata.artist,
          playedCount: countPlay ? 1 : 0,
          playedTime: delta,
        );
    _dirtyMonthSongKeys.add(metadata.path);
  }

  Future<void> _saveStatistics() async {
    if (playedStatisticsList.isNotEmpty) {
      final Map<String, StatisticsCache> statisticsMap = {
        for (final v in playedStatisticsList) v.title: v,
      };
      await _statisticsCacheBox.putAll(data: statisticsMap);
    }

    if (_dirtyDayKeys.isNotEmpty) {
      final payload = <String, DailyStatCache>{};
      for (final key in _dirtyDayKeys) {
        if (_dailyStats[key] case final stat?) payload[key] = stat;
      }
      _dirtyDayKeys.clear();
      if (payload.isNotEmpty) await _dailyStatBox.putAll(data: payload);
    }

    if (_dirtyMonthSongKeys.isNotEmpty) {
      final payload = <String, MonthlySongCache>{};
      for (final path in _dirtyMonthSongKeys) {
        if (_monthSongs[path] case final song?) {
          payload[song.storageKey] = song;
        }
      }
      _dirtyMonthSongKeys.clear();
      if (payload.isNotEmpty) await _monthlySongBox.putAll(data: payload);
    }
  }

  //聚合计算

  HeatmapData _buildHeatmap() {
    final today = StatKeys.atMidnight(DateTime.now());
    // 从「本周周一往前推 weekCount-1 周」开始，保证最后一列是本周
    final weekCount = (_dailyStats.length / 7).ceil().clamp(
      _heatmapMinWeeks,
      _heatmapMaxWeeks,
    );

    final firstMonday = StatKeys.mondayOf(
      today,
    ).subtract(Duration(days: (weekCount - 1) * 7));

    final weeks = <List<HeatmapCell>>[];
    final counts = <int>[];
    int maxCount = 0;
    int totalCount = 0;

    for (int w = 0; w < weekCount; w++) {
      final week = <HeatmapCell>[];
      for (int d = 0; d < 7; d++) {
        final date = firstMonday.add(Duration(days: w * 7 + d));
        final stat = _dailyStats[StatKeys.day(date)];
        final count = stat?.playedCount ?? 0;
        if (count > maxCount) maxCount = count;
        totalCount += count;
        counts.add(count);
        week.add(
          HeatmapCell(
            date: date,
            playedCount: count,
            playedTime: stat?.playedTime ?? 0.0,
            level: 0,
            // 需要全局最大值才能定档
            isFuture: date.isAfter(today),
          ),
        );
      }
      weeks.add(week);
    }

    // 拿到最大值后再定档，保证颜色深浅相对于当期峰值
    final leveled = [
      for (final week in weeks)
        [
          for (final cell in week)
            HeatmapCell(
              date: cell.date,
              playedCount: cell.playedCount,
              playedTime: cell.playedTime,
              level: _heatLevel(cell.playedCount, maxCount),
              isFuture: cell.isFuture,
            ),
        ],
    ];

    return HeatmapData(
      weeks: leveled,
      maxCount: maxCount,
      totalCount: totalCount,
    );
  }

  /// 把播放次数映射到 0~4 档：0 为无记录，其余按当期峰值四等分
  static int _heatLevel(int count, int maxCount) {
    if (count <= 0) return 0;
    if (maxCount <= 0) return 0;
    final ratio = count / maxCount;
    if (ratio <= 0.25) return 1;
    if (ratio <= 0.5) return 2;
    if (ratio <= 0.75) return 3;
    return 4;
  }

  ListeningHabits _buildHabits() {
    if (_dailyStats.isEmpty) return ListeningHabits.empty;

    final hourCounts = List<int>.filled(DailyStatCache.hourSlots, 0);
    int totalCount = 0;
    int activeDays = 0;
    DateTime? busiestDate;
    int busiestCount = 0;

    // 收集有记录的日期，供连续天数判断
    final activeDates = <DateTime>[];

    for (final stat in _dailyStats.values) {
      if (stat.playedCount <= 0 && stat.playedTime <= 0) continue;
      final date = _parseDayKey(stat.dayKey);
      if (date == null) continue;

      activeDays++;
      activeDates.add(date);
      totalCount += stat.playedCount;

      for (int h = 0; h < DailyStatCache.hourSlots; h++) {
        hourCounts[h] += stat.hourCounts[h];
      }

      if (stat.playedCount > busiestCount) {
        busiestCount = stat.playedCount;
        busiestDate = date;
      }
    }

    if (activeDays == 0) return ListeningHabits.empty;

    int peakHour = -1;
    int peakHourCount = 0;
    for (int h = 0; h < DailyStatCache.hourSlots; h++) {
      if (hourCounts[h] > peakHourCount) {
        peakHourCount = hourCounts[h];
        peakHour = h;
      }
    }

    return ListeningHabits(
      peakHour: peakHour,
      peakHourCount: peakHourCount,
      dailyAverage: totalCount / activeDays,
      longestStreak: _longestStreak(activeDates),
      busiestDate: busiestDate,
      busiestDateCount: busiestCount,
      activeDays: activeDays,
    );
  }

  /// 最长连续听歌天数：排序后数相邻日期差 1 天的最长链
  static int _longestStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    dates.sort();

    int longest = 1;
    int current = 1;
    for (int i = 1; i < dates.length; i++) {
      final gap = dates[i].difference(dates[i - 1]).inDays;
      if (gap == 1) {
        current++;
        if (current > longest) longest = current;
      } else if (gap > 1) {
        current = 1;
      }
    }
    return longest;
  }

  MonthlyHighlight _buildMonthlyHighlight() {
    if (_monthSongs.isEmpty) return MonthlyHighlight.empty;

    final musicMap = _musicCacheController.itemsMap;

    MonthlySongCache? topSong;
    for (final song in _monthSongs.values) {
      if (topSong == null || _isMoreListened(song, topSong)) topSong = song;
    }

    // 艺术家按 `/` 拆分后分别累加
    final artistCounts = <String, ({int count, double time, int songs})>{};
    for (final song in _monthSongs.values) {
      for (final raw in song.artist.split('/')) {
        final artist = raw.trim();
        if (artist.isEmpty) continue;
        final prev = artistCounts[artist];
        artistCounts[artist] = (
          count: (prev?.count ?? 0) + song.playedCount,
          time: (prev?.time ?? 0.0) + song.playedTime,
          songs: (prev?.songs ?? 0) + 1,
        );
      }
    }

    MapEntry<String, ({int count, double time, int songs})>? topArtistEntry;
    for (final entry in artistCounts.entries) {
      final best = topArtistEntry;
      if (best == null ||
          entry.value.count > best.value.count ||
          (entry.value.count == best.value.count &&
              entry.value.time > best.value.time)) {
        topArtistEntry = entry;
      }
    }

    return MonthlyHighlight(
      topSong: topSong == null
          ? null
          : MonthlyTopSong(
              title: topSong.title,
              artist: topSong.artist,
              playedCount: topSong.playedCount,
              playedTime: topSong.playedTime,
              metadata: musicMap[topSong.path],
            ),
      topArtist: topArtistEntry == null
          ? null
          : MonthlyTopArtist(
              artist: topArtistEntry.key,
              playedCount: topArtistEntry.value.count,
              playedTime: topArtistEntry.value.time,
              songCount: topArtistEntry.value.songs,
              pathList:
                  _musicCacheController.artistItemsDict[_musicCacheController
                          .getLetter(str: topArtistEntry.key) +
                      topArtistEntry.key] ??
                  const [],
            ),
    );
  }

  static bool _isMoreListened(MonthlySongCache a, MonthlySongCache b) {
    if (a.playedCount != b.playedCount) return a.playedCount > b.playedCount;
    return a.playedTime > b.playedTime;
  }

  // 曲库概览统计

  String _getTotalTime() {
    final totalSeconds = _calculateTotalDuration(_musicCacheController.items);
    return formatTimeDHMS(totalSeconds.toInt());
  }

  double _calculateTotalDuration(List<MusicCache> list) {
    double totalSeconds = 0;
    for (int i = 0; i < list.length; i++) {
      totalSeconds += list[i].duration;
    }
    return totalSeconds;
  }

  Future<String> _getTotalSize() async {
    // 先转成普通 List，避免把 signal 对象带进 Isolate
    final totalSBytes = await _getFoldersTotalSize(
      SettingController.instance.folders.toList(),
    );
    return _formatBytes(totalSBytes);
  }

  Future<int> _getFoldersTotalSize(List<String> folderPaths) async {
    if (folderPaths.isEmpty) return 0;

    return await Isolate.run(() {
      int totalBytes = 0;

      for (final path in folderPaths) {
        final dir = Directory(path);
        if (!dir.existsSync()) continue;

        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (int i = 0; i < entities.length; i++) {
            final entity = entities[i];
            if (entity is File) {
              try {
                totalBytes += entity.lengthSync();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      return totalBytes;
    });
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void sortList() {
    if (playedStatisticsList.isEmpty) {
      return;
    }
    if (!_rankDirty) return;
    _rankDirty = false;

    playedStatisticsList.sort((a, b) {
      // 分别按照播放次数，时长，时间戳排序
      final countCompare = b.playedCount.compareTo(a.playedCount);
      if (countCompare != 0) return countCompare;

      final timeCompare = b.playedTime.compareTo(a.playedTime);
      if (timeCompare != 0) return timeCompare;

      return b.recordTimestamp.compareTo(a.recordTimestamp);
    });

    final musicMap = _musicCacheController.itemsMap;
    final temp = [
      for (final stat in playedStatisticsList)
        if (musicMap[stat.path] case final music?)
          RankedMusicItem(metadata: music, statistics: stat),
    ];

    batch(() {
      playedTop50.value = temp.take(50).toList();

      final artistAgg =
          <String, ({List<String> pathList, int count, double time})>{};

      for (final item in temp) {
        final artists = item.metadata.artist.split('/');
        for (final raw in artists) {
          final ar = raw.trim();
          if (ar.isEmpty) continue;
          final prev = artistAgg[ar];
          if (prev == null) {
            final dictKey = _musicCacheController.getLetter(str: ar) + ar;
            artistAgg[ar] = (
              pathList: _musicCacheController.artistItemsDict[dictKey] ?? [],
              count: item.statistics.playedCount,
              time: item.statistics.playedTime,
            );
          } else {
            artistAgg[ar] = (
              pathList: prev.pathList,
              count: prev.count + item.statistics.playedCount,
              time: prev.time + item.statistics.playedTime,
            );
          }
        }
      }

      final sortedArtists = artistAgg.entries.toList()
        ..sort((a, b) {
          final countComp = b.value.count.compareTo(a.value.count);
          if (countComp != 0) return countComp;
          return b.value.time.compareTo(a.value.time);
        });

      artistTop30.value = [
        for (final entry in sortedArtists.take(30))
          RankedArtistItem(
            artist: entry.key,
            pathList: entry.value.pathList,
            playedCount: entry.value.count,
            playedTime: entry.value.time,
          ),
      ];
    });
  }
}

class RankedMusicItem {
  final MusicCache metadata;
  final StatisticsCache statistics;

  const RankedMusicItem({required this.metadata, required this.statistics});
}

class RankedArtistItem {
  final String artist;
  final List<String> pathList;
  final int playedCount;
  final double playedTime;

  const RankedArtistItem({
    required this.artist,
    required this.pathList,
    required this.playedCount,
    required this.playedTime,
  });
}
