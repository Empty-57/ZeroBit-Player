import 'package:hive_ce/hive.dart';

import '../hive_types.dart';
import '../models/daily_stat_cache_model.dart';

class DailyStatCacheAdapter extends TypeAdapter<DailyStatCache> {
  @override
  int get typeId => HiveTypes.dailyStatCache;

  @override
  DailyStatCache read(BinaryReader reader) {
    return DailyStatCache(
      dayKey: reader.readString(),
      playedCount: reader.readInt(),
      playedTime: reader.readDouble(),
      // 两个列表长度固定，写入时省掉了长度前缀
      hourCounts: reader.readIntList(DailyStatCache.hourSlots),
      hourTimes: reader.readDoubleList(DailyStatCache.hourSlots),
    );
  }

  @override
  void write(BinaryWriter writer, DailyStatCache obj) {
    writer.writeString(obj.dayKey);
    writer.writeInt(obj.playedCount);
    writer.writeDouble(obj.playedTime);
    writer.writeIntList(obj.hourCounts, writeLength: false);
    writer.writeDoubleList(obj.hourTimes, writeLength: false);
  }
}
