import 'package:get/get.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';

import 'package:zerobit_player/hive_manager/hive_box.dart';

import '../hive_manager/models/music_cache_model.dart';

class UserPlayListController extends GetxController {
  final items = <UserPlayListCache>[].obs;
  final _userPlayListCacheBox = HiveBox.userPlayListCacheBox;
  AudioController get _audioController => Get.find<AudioController>();

  List<String> get allUserKey => items.map((e) => e.userKey).toList();

  final songDeletedSignal = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadData();
  }

  void _loadData() {
    items.value = _userPlayListCacheBox.getAll();
  }

  String _getDisplayName(String userKey) => userKey.split('_')[0];

  bool _isValidName(String name) {
    if (name.isEmpty) {
      showSnackBar(title: "WARNING", msg: "歌单名称为空！");
      return false;
    }
    if (name.length > 223) {
      showSnackBar(title: "WARNING", msg: "歌单名称过长！（最大223个字符）");
      return false;
    }

    if (items.any((e) => _getDisplayName(e.userKey) == name)) {
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return false;
    }
    return true;
  }

  Future<void> createPlayList({required String userKey}) async {
    final cleanName = userKey.trim();

    if (!_isValidName(cleanName)) return;

    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final fullUserKey = '${cleanName}_${OperateArea.playListDetails}_$uniqueId';

    final newPlaylist = UserPlayListCache(
      pathList: <String>[],
      userKey: fullUserKey,
    );

    await _userPlayListCacheBox.put(data: newPlaylist, key: fullUserKey);
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
    final cleanNewName = newKey.trim();

    if (!_isValidName(cleanNewName)) return;

    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final fullNewKey =
        '${cleanNewName}_${OperateArea.playListDetails}_$uniqueId';

    final index = items.indexWhere((v) => v.userKey == oldKey);
    if (index == -1) return;

    final updatedPlaylist = UserPlayListCache(
      pathList: items[index].pathList,
      userKey: fullNewKey,
    );

    // 更新 Hive 数据库
    await _userPlayListCacheBox.del(key: oldKey);
    await _userPlayListCacheBox.put(data: updatedPlaylist, key: fullNewKey);

    items[index] = updatedPlaylist;
  }

  /// 用于向自定义歌单添加所选的音频
  void addToAudioList({
    required MusicCache metadata,
    required String userKey,
  }) async {
    final index = items.indexWhere((v) => v.userKey == userKey);
    if (index == -1) return;

    final targetList = items[index];

    if (targetList.pathList.contains(metadata.path)) {
      showSnackBar(
        title: "WARNING",
        msg: "歌单 ${_getDisplayName(userKey)} 存在重复歌曲 ${metadata.title} ！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    targetList.pathList.add(metadata.path);
    items[index] = targetList; // 触发 Obx 刷新

    await _userPlayListCacheBox.put(data: targetList, key: userKey);

    if (_audioController.currentAudioSource == userKey) {
      if (!_audioController.playListCacheItems.any(
        (v) => v.path == metadata.path,
      )) {
        _audioController.playListCacheItems.add(metadata);
        _audioController.syncCurrentIndex();
      }
    }

    showSnackBar(
      title: "OK",
      msg: "已将 ${metadata.title} 添加到歌单 ${_getDisplayName(userKey)}",
      duration: const Duration(milliseconds: 1500),
    );
  }

  /// 用于向自定义歌单添加所选的所有音频
  void addAllToAudioList({
    required List<MusicCache> selectedList,
    required String userKey,
  }) async {
    if (selectedList.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "未选择音频！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final index = items.indexWhere((v) => v.userKey == userKey);
    if (index == -1) return;

    final targetList = items[index];
    final existingPathSet = targetList.pathList.toSet();

    // 过滤出真正需要添加的新歌
    final songsToAdd =
        selectedList.where((v) => !existingPathSet.contains(v.path)).toList();

    if (songsToAdd.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "重复添加！歌曲均已存在于歌单中。",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final addedCount = songsToAdd.length;

    targetList.pathList.addAll(songsToAdd.map((v) => v.path));
    items[index] = targetList;

    await _userPlayListCacheBox.put(data: targetList, key: userKey);

    if (_audioController.currentAudioSource == userKey) {
      final currentPlaySet =
          _audioController.playListCacheItems.map((v) => v.path).toSet();
      final playSongsToAdd =
          songsToAdd.where((v) => !currentPlaySet.contains(v.path)).toList();

      _audioController.playListCacheItems.addAll(playSongsToAdd);
      _audioController.syncCurrentIndex();
    }

    showSnackBar(
      title: "OK",
      msg: "已将去重后的 $addedCount 首歌添加到歌单 ${_getDisplayName(userKey)}",
      duration: const Duration(milliseconds: 1500),
    );
  }

  /// 用于从自定义歌单删除所选的音频
  Future<void> audioRemove({
    required String userKey,
    required MusicCache metadata,
  }) async {
    final index = items.indexWhere((v) => v.userKey == userKey);
    if (index != -1) {
      final targetList = items[index];
      targetList.pathList.remove(metadata.path);

      items[index] = targetList;
      songDeletedSignal.value = [metadata.path];

      await _userPlayListCacheBox.put(data: targetList, key: userKey);

      if (_audioController.currentAudioSource == userKey) {
        _audioController.playListCacheItems.remove(metadata);
        _audioController.syncCurrentIndex();
      }

      showSnackBar(
        title: "OK",
        msg: "已将 ${metadata.title} 从歌单 ${_getDisplayName(userKey)}删除！",
        duration: const Duration(milliseconds: 1500),
      );
    }
  }

  /// 用于从自定义歌单删除所有所选的音频
  void audioRemoveAll({
    required String userKey,
    required List<MusicCache> removeList,
  }) async {
    if (removeList.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "未选择音频！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final index = items.indexWhere((v) => v.userKey == userKey);
    if (index == -1) return;

    final targetList = items[index];
    final removePathSet = removeList.map((v) => v.path).toSet();

    targetList.pathList.removeWhere((path) => removePathSet.contains(path));

    items[index] = targetList;
    songDeletedSignal.value = removeList.map((v) => v.path).toList();

    await _userPlayListCacheBox.put(data: targetList, key: userKey);

    if (_audioController.currentAudioSource == userKey) {
      _audioController.playListCacheItems.removeWhere(
        (v) => removePathSet.contains(v.path),
      );
      _audioController.syncCurrentIndex();
    }

    showSnackBar(
      title: "OK",
      msg: "已将去重后的 ${removeList.length} 首歌从歌单 ${_getDisplayName(userKey)}删除！",
      duration: const Duration(milliseconds: 1500),
    );
  }
}
