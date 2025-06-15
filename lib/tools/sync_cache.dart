import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';

import '../HIveCtrl/hive_manager.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../src/rust/api/music_tag_tool.dart';

const _exts = [
  'aac',
  'ape',
  'aiff',
  'aif',
  'flac',
  'mp3',
  'mp4', 'm4a', 'm4b', 'm4p', 'm4v',
  'mpc',
  'opus',
  'ogg',
  'oga',
  'spx',
  'wav',
  'wv',
];

Future<void> syncCache() async {
  final audioPaths = <String>[];
  final musicCacheBox = HiveManager.musicCacheBox;
  final SettingController settingController = Get.find<SettingController>();
  final MusicCacheController musicCacheController = Get.find<MusicCacheController>();

  final folders=settingController.folders;

  try {
    for (final dir in folders) {
      final d = Directory(dir);
      await for (final entity in d.list(recursive: true)) {
        if (entity is File) {
          final path = entity.path;
          final ext = path.toLowerCase().split('.').last;
          if (_exts.contains(ext)) {
            audioPaths.add(path);
          }
        }
      }
    }
  } catch (err) {
    debugPrint(err.toString());
  }

  final musicKeys = musicCacheBox.getKeyAll();

  final Map<String, MusicCache> tagBuffer = {};
  final removeKeys=<String>[];

  for (final path in audioPaths) {
    if (!musicKeys.contains(path)) {
      final metaData = await getMetadata(path: path);
      tagBuffer[path] = MusicCache(
        artist: metaData.artist,
        album: metaData.album,
        title: metaData.title,
        genre: metaData.genre,
        duration: metaData.duration,
        bitrate: metaData.bitrate,
        sampleRate: metaData.sampleRate,
        path: metaData.path,
      );
    }
  }

  for(final key in musicKeys){
    if(!audioPaths.contains(key)){
      removeKeys.add(key);
    }
  }

  musicCacheBox.delAll(keyList:removeKeys);
  musicCacheBox.putAll(data:tagBuffer);

  musicCacheController.items.clear();
  musicCacheController.loadData();
}
