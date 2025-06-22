

import 'package:hive_ce/hive.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';

import '../hive_types.dart';

class UserPlayListAdapter extends TypeAdapter<UserPlayListCache>{
  @override
  final int typeId = HiveTypes.userPlayListCache;

  @override
  UserPlayListCache read(BinaryReader reader) {
    return UserPlayListCache(
        pathList: reader.readStringList(),
      userKey: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, UserPlayListCache obj) {
    writer.writeStringList(obj.pathList);
    writer.writeString(obj.userKey);
  }
}