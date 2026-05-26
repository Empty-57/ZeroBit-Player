import 'package:zerobit_player/hive_manager/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'hive_crud.dart';
import 'models/music_cache_model.dart';
import 'package:hive_ce/hive.dart';

import 'hive_boxes.dart';

abstract class HiveBox{
  static final musicCacheBox=StorageCRUD(cacheBox: Hive.box<MusicCache>(HiveBoxes.musicCacheBox));
  static final settingCacheBox=StorageCRUD(cacheBox: Hive.box<SettingCache>(HiveBoxes.settingCacheBox));
  static final userPlayListCacheBox=StorageCRUD(cacheBox: Hive.box<UserPlayListCache>(HiveBoxes.userPlayListCacheBox));
  static final scalableSettingCacheBox=StorageCRUD(cacheBox: Hive.box<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox));
}