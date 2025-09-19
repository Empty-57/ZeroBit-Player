import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:hive_ce/hive.dart';
import 'package:zerobit_player/HIveCtrl/hive_types.dart';

class MusicCacheAdapter extends TypeAdapter<MusicCache> {
  @override
  int get typeId => HiveTypes.musicCache;

  @override
  MusicCache read(BinaryReader reader) {
    return MusicCache(
      title: reader.readString(),
      artist: reader.readString(),
      album: reader.readString(),
      genre: reader.readString(),
      duration: reader.readDouble(),
      bitrate: reader.read(),
      sampleRate: reader.read(),
      path: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, MusicCache obj) {
    writer.writeString(obj.title);
    writer.writeString(obj.artist);
    writer.writeString(obj.album);
    writer.writeString(obj.genre);
    writer.writeDouble(obj.duration);
    writer.write(obj.bitrate);
    writer.write(obj.sampleRate);
    writer.writeString(obj.path);
  }
}
