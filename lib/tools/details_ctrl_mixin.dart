import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:signals/signals_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/field/set_constants.dart';

import '../components/widget/get_snack_bar.dart';
import '../controller/audio_ctrl.dart';
import '../controller/setting_ctrl.dart';
import '../hive_manager/models/music_cache_model.dart';
import 'func/get_sort_type.dart';

const int _audioLimit = 400;

Future<List<MusicCache>> _sortFilesByTime(
  List<MusicCache> musicCaches, {
  bool descending = true,
  required Future<DateTime> Function(File) getTime,
  int concurrency = 20,
}) async {
  // IO 阶段仍在主 isolate 并发执行
  final List<(MusicCache, DateTime)> pairs = [];
  for (int i = 0; i < musicCaches.length; i += concurrency) {
    final batch = musicCaches.skip(i).take(concurrency); // 分块
    final batchResults = await Future.wait(
      batch.map((m) async {
        try {
          final time = await getTime(File(m.path));
          return (m, time);
        } catch (_) {
          return (m, DateTime.now());
        }
      }),
    );
    pairs.addAll(batchResults);
  }

  // 少于 400 条直接排序，超过才走 Isolate
  if (pairs.length < _audioLimit) {
    pairs.sort(
      (a, b) => descending ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2),
    );
    return [for (final p in pairs) p.$1];
  } else {
    return compute(_sortPairs, (pairs, descending));
  }
}

// Isolate的callback
List<MusicCache> _sortPairs((List<(MusicCache, DateTime)>, bool) args) {
  final (pairs, descending) = args;
  pairs.sort(
    (a, b) => descending ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2),
  );
  return [for (final p in pairs) p.$1];
}

List<MusicCache> _sortPairs2((List<MusicCache>, int, bool) args) {
  final (list, type, descending) = args;
  final decorated = [
    for (final item in list) (item, getSortType(type: type, data: item)),
  ];
  decorated.sort(
    (a, b) => descending ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2),
  );

  return [for (final d in decorated) d.$1];
}

mixin DetailsPageControllerBase {
  final ListSignal<MusicCache> items = listSignal([]);
  final itemsMap = mapSignal(<String, MusicCache>{});
  final Signal<Uint8List> headCover = signal(kTransparentImage);
  final SettingController _settingController = SettingController.instance;
  AudioController get audioController => AudioController.instance;

  void play(String audioSource, {MusicCache? metadata}) {
    if (audioController.currentAudioSource != audioSource ||
        audioController.playListCacheItems.length != items.length) {
      audioController.currentAudioSource = audioSource;
      audioController.playListCacheItems.value = [...items];
      _settingController.lastAudioInfo[SettingController
          .lastAudioPlayPathListKey] = items
          .map((v) => v.path)
          .toList();
    }
    if (items.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "此歌单暂无音乐！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final metadataToPlay =
        metadata ??
        (_settingController.playMode.value == PlayModeType.random
            ? items[audioController.pickNextRandomIndex() ?? 0]
            : items[0]);
    audioController.audioPlay(metadata: metadataToPlay);
  }

  void itemReSort({required String operateArea}) async {
    final int type = _settingController.sortMap[operateArea] ?? SortType.title;

    if (type == SortType.editTime || type == SortType.createTime) {
      items.value = await _sortFilesByTime(
        items,
        descending: _settingController.isReverse.value,
        getTime: (File file) async {
          try {
            if (type == SortType.editTime) {
              return file.lastModified();
            } else {
              return (await file.stat()).changed;
            }
          } catch (_) {
            return DateTime.now();
          }
        },
      );
      return;
    }

    if (type == SortType.trackNumber) {
      // 按照音轨排序数据量一般很小，不做处理
      items.sort(
        (a, b) => _settingController.isReverse.value
            ? b.trackNumber.compareTo(a.trackNumber)
            : a.trackNumber.compareTo(b.trackNumber),
      );
      return;
    }

    if (items.length < _audioLimit) {
      // 少于 400 条直接排序，超过才走 Isolate
      items.value = _sortPairs2((
        [...items],
        type,
        _settingController.isReverse.value,
      ));
    } else {
      items.value = await compute(_sortPairs2, (
        items.toList(),
        type,
        _settingController.isReverse.value,
      ));
    }
  }

  void itemReverse() {
    items.value = items.reversed.toList();
  }
}
