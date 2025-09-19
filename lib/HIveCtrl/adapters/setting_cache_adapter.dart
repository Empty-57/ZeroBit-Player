import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:hive_ce/hive.dart';

import '../hive_types.dart';

class SettingCacheAdapter extends TypeAdapter<SettingCache> {
  @override
  int get typeId => HiveTypes.settingCache;

  @override
  SettingCache read(BinaryReader reader) {
    return SettingCache(
      themeMode: reader.readString(),
      apiIndex: reader.readInt(),
      volume: reader.readDouble(),
      folders: reader.readStringList(),
      sortMap: reader.readMap(),
      viewModeMap: reader.readMap(),
      isReverse: reader.readBool(),
      themeColor: reader.readInt(),
      playMode: reader.readInt(),
      dynamicThemeColor: reader.readBool(),
      fontFamily: reader.readString(),
      lrcAlignment: reader.readInt(),
      lrcFontSize: reader.readInt(),
      lrcFontWeight: reader.readInt(),
      autoDownloadLrc: reader.readBool(),
      useBlur: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, SettingCache obj) {
    writer.writeString(obj.themeMode);
    writer.writeInt(obj.apiIndex);
    writer.writeDouble(obj.volume);
    writer.writeStringList(obj.folders);
    writer.writeMap(obj.sortMap);
    writer.writeMap(obj.viewModeMap);
    writer.writeBool(obj.isReverse);
    writer.writeInt(obj.themeColor);
    writer.writeInt(obj.playMode);
    writer.writeBool(obj.dynamicThemeColor);
    writer.writeString(obj.fontFamily);
    writer.writeInt(obj.lrcAlignment);
    writer.writeInt(obj.lrcFontSize);
    writer.writeInt(obj.lrcFontWeight);
    writer.writeBool(obj.autoDownloadLrc);
    writer.writeBool(obj.useBlur);
  }
}
