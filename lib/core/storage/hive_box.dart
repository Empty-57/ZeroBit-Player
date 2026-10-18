import 'package:hive_ce/hive.dart';

import 'hive_boxes.dart';
import 'hive_crud.dart';
import 'models/daily_stat_cache_model.dart';
import 'models/monthly_song_cache_model.dart';
import 'models/music_cache_model.dart';
import 'models/scalable_setting_cache_model.dart';
import 'models/setting_cache_model.dart';
import 'models/statistics_cache_model.dart';
import 'models/user_playlist_model.dart';

abstract class HiveBox {
  static final musicCacheBox = StorageCRUD(
    cacheBox: Hive.box<MusicCache>(HiveBoxes.musicCacheBox),
  );
  static final settingCacheBox = StorageCRUD(
    cacheBox: Hive.box<SettingCache>(HiveBoxes.settingCacheBox),
  );
  static final userPlayListCacheBox = StorageCRUD(
    cacheBox: Hive.box<UserPlayListCache>(HiveBoxes.userPlayListCacheBox),
  );
  static final scalableSettingCacheBox = StorageCRUD(
    cacheBox: Hive.box<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox),
  );
  static final statisticsCacheBox = StorageCRUD(
    cacheBox: Hive.box<StatisticsCache>(HiveBoxes.statisticsCacheBox),
  );
  static final dailyStatCacheBox = StorageCRUD(
    cacheBox: Hive.box<DailyStatCache>(HiveBoxes.dailyStatCacheBox),
  );
  static final monthlySongCacheBox = StorageCRUD(
    cacheBox: Hive.box<MonthlySongCache>(HiveBoxes.monthlySongCacheBox),
  );
}
