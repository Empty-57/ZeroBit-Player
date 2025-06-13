import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:hive_ce/hive.dart';

import '../hive_typs.dart';

class SettingCacheAdapter extends TypeAdapter<SettingCache> {
  @override
  final int typeId = HiveTypes.settingCache;

  @override
  SettingCache read(BinaryReader reader) {
    return SettingCache(
      themeMode: reader.readString(),
      apiIndex: reader.readInt(),
      volume: reader.readDouble(),
      folders: reader.readStringList(),
    );
  }

  @override
  void write(BinaryWriter writer, SettingCache obj) {
    writer.writeString(obj.themeMode);
    writer.writeInt(obj.apiIndex);
    writer.writeDouble(obj.volume);
    writer.writeStringList(obj.folders);
  }
}
