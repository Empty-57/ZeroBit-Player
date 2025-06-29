import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';

import '../HIveCtrl/hive_manager.dart';
import '../tools/tag_suffix.dart';


class UserPlayListController extends GetxController {
  final items = <UserPlayListCache>[].obs;

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  void initHive() {
    items.value = _userPlayListCacheBox.getAll();
  }

  @override
  void onInit() {
    super.onInit();
    initHive();
  }

  List get allUserKey => _userPlayListCacheBox.getKeyAll();

  Future<void> createPlayList({required String userKey}) async {
    userKey = userKey.trim();

    if (userKey.isEmpty) {
      showSnackBar(title: "WARNING", msg: "歌单名称为空！");
      return;
    }

    userKey += playListTagSuffix;

    if (allUserKey.contains(userKey)) {
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }

    await _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: <String>[], userKey: userKey),
      key: userKey,
    );

    items.add(UserPlayListCache(pathList: <String>[], userKey: userKey));
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
    newKey += playListTagSuffix;
    if (allUserKey.contains(newKey)) {
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }
    final oldValue = _userPlayListCacheBox.get(key: oldKey);
    if (oldValue == null) {
      return;
    }
    await removePlayList(userKey: oldKey);
    await _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: oldValue.pathList, userKey: newKey),
      key: newKey,
    );
    items.add(UserPlayListCache(pathList: oldValue.pathList, userKey: newKey));
  }
}
