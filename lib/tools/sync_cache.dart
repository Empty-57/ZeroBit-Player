import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../src/rust/api/music_tag_tool.dart';

const Set<String> _supportedExts = {
  '.aac',
  '.ape',
  '.aiff',
  '.aif',
  '.flac',
  '.mp3',
  '.mp4', '.m4a', '.m4b', '.m4p', '.m4v',
  '.mpc',
  '.opus',
  '.ogg',
  '.oga',
  '.spx',
  '.wav',
  '.wv',
};

Future<Set<String>> scanAudioPaths(List<String> folders) async {
  final Set<String> paths = {};
  for (final dirPath in folders) {
    final directory = Directory(dirPath);
    if (!await directory.exists()) continue;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          _supportedExts.contains(p.extension(entity.path).toLowerCase())) {
        paths.add(entity.path);
      }
    }
  }
  return paths;
}

Future<Map<String, MusicCache>> _fetchMetadataBatch(
  Set<String> newPaths,
  ValueSetter<String> onScanProgress,
) async {
  final futures = newPaths.map((path) async {
    try {
      onScanProgress(path);
      final meta = await getMetadata(path: path);
      return MapEntry(
        path,
        MusicCache(
          artist: meta.artist,
          album: meta.album,
          title: meta.title,
          genre: meta.genre,
          duration: meta.duration,
          bitrate: meta.bitrate,
          sampleRate: meta.sampleRate,
          path: meta.path,
        ),
      );
    } catch (e) {
      debugPrint('Metadata error for $path: \$e');
      return null;
    }
  });

  final entries = await Future.wait(futures);
  return Map.fromEntries(entries.whereType<MapEntry<String, MusicCache>>());
}

/// 同步本地音乐缓存
Future<void> syncCache() async {
  final settingCtrl = Get.find<SettingController>();
  final musicCacheCtrl = Get.find<MusicCacheController>();
  final audioCtrl = Get.find<AudioController>();
  final musicBox = HiveManager.musicCacheBox;

  final scannedPaths = await scanAudioPaths(settingCtrl.folders);

  final existingKeys = Set<String>.from(musicBox.getKeyAll());

  final newPaths = scannedPaths.difference(existingKeys);
  final removedPaths = existingKeys.difference(scannedPaths);

  if (removedPaths.isNotEmpty) {
    await musicBox.delAll(keyList: removedPaths.toList());
  }

  if (newPaths.isNotEmpty) {
    final tagBuffer = await _fetchMetadataBatch(
      newPaths,
      (path) => musicCacheCtrl.currentScanPath.value = path,
    );
    await musicBox.putAll(data: tagBuffer);
  }

  musicCacheCtrl.currentScanPath.value = '';
  musicCacheCtrl.items.clear();
  musicCacheCtrl.loadData();

  audioCtrl.syncPlayListCacheItems();
  audioCtrl.syncCurrentIndex();
}
