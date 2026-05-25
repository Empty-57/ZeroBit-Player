import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import 'package:get/get.dart';

import '../components/get_snack_bar.dart';
import '../getxController/setting_ctrl.dart';
import 'get_sort_type.dart';
import '../field/sort_type.dart';

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
          final file = File(m.path);
          final exists = await file.exists();
          final time = exists ? await getTime(file) : DateTime.now();
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
    return pairs.map((p) => p.$1).toList();
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
  return pairs.map((p) => p.$1).toList();
}

List<MusicCache> _sortPairs2((List<MusicCache>, int, bool) args) {
  final (pairs, type, descending) = args;
  pairs.sort(
    (a, b) =>
        descending
            ? getSortType(
              type: type,
              data: b,
            ).compareTo(getSortType(type: type, data: a))
            : getSortType(
              type: type,
              data: a,
            ).compareTo(getSortType(type: type, data: b)),
  );
  return pairs.map((p) => p).toList();
}

mixin AudioControllerGenClass {
  final SettingController _settingController = Get.find<SettingController>();
  AudioController get audioController => Get.find<AudioController>();
  RxList<MusicCache> get items;

  Rx<Uint8List> get headCover => kTransparentImage.obs;

  void play(String audioSource, {MusicCache? metadata}) {
    final audioCtrl = audioController;
    if (audioCtrl.currentAudioSource != audioSource ||
        audioCtrl.playListCacheItems.length != items.length) {
      audioCtrl.currentAudioSource = audioSource;
      audioCtrl.playListCacheItems.value = [...items];
      _settingController.lastAudioInfo[SettingController
              .lastAudioPlayPathListKey] =
          items.map((v) => v.path).toList();
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
        (_settingController.playMode.value == 2
            ? items[Random().nextInt(items.length)]
            : items[0]);
    audioCtrl.audioPlay(metadata: metadataToPlay);
  }

  void itemReSort({required int type}) async {
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
        (a, b) =>
            _settingController.isReverse.value
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
    items.assignAll(items.reversed.toList());
  }
}
