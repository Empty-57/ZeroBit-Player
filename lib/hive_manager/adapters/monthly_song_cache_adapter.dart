import 'package:hive_ce/hive.dart';
import 'package:zerobit_player/hive_manager/hive_types.dart';
import 'package:zerobit_player/hive_manager/models/monthly_song_cache_model.dart';

class MonthlySongCacheAdapter extends TypeAdapter<MonthlySongCache> {
  @override
  int get typeId => HiveTypes.monthlySongCache;

  @override
  MonthlySongCache read(BinaryReader reader) {
    return MonthlySongCache(
      monthKey: reader.readString(),
      path: reader.readString(),
      title: reader.readString(),
      artist: reader.readString(),
      playedCount: reader.readInt(),
      playedTime: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, MonthlySongCache obj) {
    writer.writeString(obj.monthKey);
    writer.writeString(obj.path);
    writer.writeString(obj.title);
    writer.writeString(obj.artist);
    writer.writeInt(obj.playedCount);
    writer.writeDouble(obj.playedTime);
  }
}
