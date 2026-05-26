import 'package:get/get.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';

import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/field/tag_suffix.dart';

class UserPlayListController extends GetxController {
  final items = <UserPlayListCache>[].obs;
  final _userPlayListCacheBox = HiveBox.userPlayListCacheBox;

  @override
  void onInit() {
    super.onInit();
    initHive();
  }

  void initHive() {
    items.value = _userPlayListCacheBox.getAll();
  }

  Future<void> createPlayList({required String userKey}) async {
    userKey = userKey.trim();

    if (userKey.isEmpty) {
      showSnackBar(title: "WARNING", msg: "歌单名称为空！");
      return;
    }

    userKey += TagSuffix.playList;

    if (userKey.length > 255) {
      showSnackBar(title: "WARNING", msg: "歌单名称过长！（最大255个字符）");
      return;
    }

    if (items.any((e) => e.userKey == userKey)) {
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }

    final newPlaylist = UserPlayListCache(
      pathList: <String>[],
      userKey: userKey,
    );

    await _userPlayListCacheBox.put(data: newPlaylist, key: userKey);
    items.add(newPlaylist);
  }

  Future<void> removePlayList({required String userKey}) async {
    await _userPlayListCacheBox.del(key: userKey);
    items.removeWhere((v) => v.userKey == userKey);
  }

  Future<void> renamePlayList({
    required String oldKey,
    required String newKey,
  }) async {
    newKey = newKey.trim();
    if (newKey.isEmpty) {
      showSnackBar(title: "WARNING", msg: "歌单名称为空！");
      return;
    }

    newKey += TagSuffix.playList;

    if (newKey.length > 255) {
      showSnackBar(title: "WARNING", msg: "歌单名称过长！（最大255个字符）");
      return;
    }

    if (items.any((e) => e.userKey == newKey)) {
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }

    final oldValue = _userPlayListCacheBox.get(key: oldKey);
    if (oldValue == null) return;

    final updatedPlaylist = UserPlayListCache(
      pathList: oldValue.pathList,
      userKey: newKey,
    );

    // 更新 Hive 数据库
    await _userPlayListCacheBox.del(key: oldKey);
    await _userPlayListCacheBox.put(data: updatedPlaylist, key: newKey);

    final index = items.indexWhere((v) => v.userKey == oldKey);
    if (index != -1) {
      items[index] = updatedPlaylist;
    } else {
      items.add(updatedPlaylist);
    }
  }
}
