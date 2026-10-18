import 'package:hive_ce/hive.dart';

import '../hive_types.dart';
import '../models/scalable_setting_cache_model.dart';

class ScalableSettingAdapter extends TypeAdapter<ScalableSettingCache> {
  @override
  int get typeId => HiveTypes.scalableSettingCache;

  @override
  ScalableSettingCache read(BinaryReader reader) {
    return ScalableSettingCache(config: reader.readMap());
  }

  @override
  void write(BinaryWriter writer, ScalableSettingCache obj) {
    writer.writeMap(obj.config);
  }
}
