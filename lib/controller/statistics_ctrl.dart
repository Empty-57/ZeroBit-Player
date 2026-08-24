import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:get/get.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/statistics_cache_model.dart';
import 'package:zerobit_player/tools/func/format_time.dart';

class StatisticsController {
  StatisticsController._();
  static final instance = StatisticsController._();

  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  final AudioController _audioController = Get.find<AudioController>();

  final _statisticsCacheBox = HiveBox.statisticsCacheBox;

  final totalTime = '0 M'.obs;
  final totalSize = '0 B'.obs;
  final albumArtist = '0 / 0'.obs;
  final totalSongCount = '0'.obs;

  double totalPlayedTimeRaw = 0;
  int totalPlayedCountRaw = 0;

  final totalPlayedTime = '0 M'.obs;
  final totalPlayedCount = '0'.obs;

  List<StatisticsCache> playedStatisticsList = [];

  final playedTop50 = <_RankedMusicItem>[].obs;
  final artistTop30 = <String, _RankedArtistItem>{}.obs;

  String? _lastTitle; // 上次统计对应的歌曲标题
  num _lastSec = 0; // 上次统计时的播放进度
  bool _countedThisPlay = false; // 本次收听是否已经记过一次播放数

  Future<void> init() async {
    playedStatisticsList = _statisticsCacheBox.getAll();
    await refresh();
    sortList();
  }

  Future<void> refresh() async {
    updateStatistics();
    totalTime.value = _getTotalTime();
    totalSize.value = await _getTotalSize();
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
          playedCount: isRecordCount ? 1 : 0,
          playedTime: delta,
          recordTimestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      final oldData = playedStatisticsList[index];
      playedStatisticsList[index] = StatisticsCache(
        title: oldData.title,
        playedCount: oldData.playedCount + (isRecordCount ? 1 : 0),
        playedTime: oldData.playedTime + delta,
        recordTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    totalPlayedTimeRaw += delta;
    totalPlayedTime.value = formatTimeDHMS(totalPlayedTimeRaw.toInt());

    if (isRecordCount) {
      totalPlayedCountRaw++;
      totalPlayedCount.value = totalPlayedCountRaw.toString();
    }

    sortList();
  }

  Future<void> saveStatistics() async {
    if (playedStatisticsList.isEmpty) return;
    final Map<String, StatisticsCache> statisticsMap = {
      for (final v in playedStatisticsList) v.title: v,
    };

    await _statisticsCacheBox.putAll(data: statisticsMap);
  }

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
    final totalSBytes = await _getFoldersTotalSize(
      SettingController.instance.folders,
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
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void sortList() {
    if (playedStatisticsList.isEmpty) {
      return;
    }
    playedStatisticsList.sort((a, b) {
      // 分别按照播放次数，时长，时间戳排序
      final countCompare = b.playedCount.compareTo(a.playedCount);
      if (countCompare != 0) return countCompare;

      final timeCompare = b.playedTime.compareTo(a.playedTime);
      if (timeCompare != 0) return timeCompare;

      return b.recordTimestamp.compareTo(a.recordTimestamp);
    });

    final musicMap = {
      for (final item in _musicCacheController.items) item.title: item,
    };

    final temp = playedStatisticsList
        .map((stat) {
          final music = musicMap[stat.title];
          return music != null
              ? _RankedMusicItem(metadata: music, statistics: stat)
              : null;
        })
        .nonNulls
        .toList(); // 过滤null

    playedTop50.value = temp.take(50).toList();

    final artistTop30Temp = <String, _RankedArtistItem>{};

    for (final item in temp) {
      final artists = item.metadata.artist.split('/');
      for (var ar in artists) {
        if (ar.trim().isEmpty) continue;
        artistTop30Temp.update(
          ar,
          (existing) => _RankedArtistItem(
            pathList: existing.pathList,
            playedCount: existing.playedCount + item.statistics.playedCount,
            playedTime: existing.playedTime + item.statistics.playedTime,
          ),
          ifAbsent: () {
            final dictKey = _musicCacheController.getLetter(str: ar) + ar;
            final pathList =
                _musicCacheController.artistItemsDict[dictKey] ?? [];

            return _RankedArtistItem(
              pathList: pathList,
              playedCount: item.statistics.playedCount,
              playedTime: item.statistics.playedTime,
            );
          },
        );
      }
    }

    final sortedArtists = artistTop30Temp.entries.toList()
      ..sort((a, b) {
        final countComp = b.value.playedCount.compareTo(a.value.playedCount);
        if (countComp != 0) return countComp;
        return b.value.playedTime.compareTo(a.value.playedTime);
      });

    artistTop30.assignAll(Map.fromEntries(sortedArtists.take(30)));
  }
}

class _RankedMusicItem {
  final MusicCache metadata;
  final StatisticsCache statistics;

  const _RankedMusicItem({required this.metadata, required this.statistics});
}

class _RankedArtistItem {
  final List<String> pathList;
  final int playedCount;
  final double playedTime;

  const _RankedArtistItem({
    required this.pathList,
    required this.playedCount,
    required this.playedTime,
  });
}
