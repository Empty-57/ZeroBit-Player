import 'package:zerobit_player/HIveCtrl/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'hive_crud.dart';
import 'models/music_cache_model.dart';
import 'package:hive_ce/hive.dart';

import 'hive_boxes.dart';

abstract class HiveManager{
  static final musicCacheBox=StorageCRUD(cacheBox: Hive.box<MusicCache>(HiveBoxes.musicCacheBox));
  static final settingCacheBox=StorageCRUD(cacheBox: Hive.box<SettingCache>(HiveBoxes.settingCacheBox));
  static final userPlayListCacheBox=StorageCRUD(cacheBox: Hive.box<UserPlayListCache>(HiveBoxes.userPlayListCacheBox));
  static final scalableSettingCacheBox=StorageCRUD(cacheBox: Hive.box<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox));
}