import 'package:hive_ce/hive.dart';
import 'package:zerobit_player/hive_manager/hive_types.dart';
import 'package:zerobit_player/hive_manager/models/statistics_cache_model.dart';

class StatisticsCacheAdapter extends TypeAdapter<StatisticsCache> {
  @override
  int get typeId => HiveTypes.statisticsCache;

  @override
  StatisticsCache read(BinaryReader reader) {
    return StatisticsCache(
      title: reader.readString(),
      playedCount: reader.readInt(),
      playedTime: reader.readDouble(),
      recordTimestamp: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, StatisticsCache obj) {
    writer.writeString(obj.title);
    writer.writeInt(obj.playedCount);
    writer.writeDouble(obj.playedTime);
    writer.writeInt(obj.recordTimestamp);
  }
}
