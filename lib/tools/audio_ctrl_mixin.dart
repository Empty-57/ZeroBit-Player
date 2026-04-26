import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:transparent_image/transparent_image.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import 'package:get/get.dart';

import '../getxController/setting_ctrl.dart';
import 'get_sort_type.dart';

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
  RxList<MusicCache> get items;

  Rx<Uint8List> get headCover => kTransparentImage.obs;

  void itemReSort({required int type}) async {
    if (type == 4 || type == 5) {
      items.value = await _sortFilesByTime(
        items,
        descending: _settingController.isReverse.value,
        getTime: (File file) async {
          try {
            if (type == 4) {
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

    if (type == 6) {
      // 按照音轨排序数据量一般很小，不做处理
      items.sort(
        (a, b) =>
            _settingController.isReverse.value
                ? b.trackNumber.compareTo(a.trackNumber)
                : a.trackNumber.compareTo(b.trackNumber),
      );
      return;
    }

    if (items.length > _audioLimit) {
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
