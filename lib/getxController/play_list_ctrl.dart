import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';

import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/user_playlist_model.dart';
import '../field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import 'music_cache_ctrl.dart';

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class PlayListController extends GetxController {
  final UserPlayListCache userArgs;
  PlayListController({required this.userArgs});

  static final items = <MusicCache>[].obs;

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  final SettingController _settingController = Get.find<SettingController>();

  static final headCover =kTransparentImage.obs;

  @override
  void onInit() {
    headCover.value=kTransparentImage;
    super.onInit();
    _loadData();
  }

  Future<void> syncCache() async {
    await _userPlayListCacheBox.put(
      data: UserPlayListCache(
        pathList: userArgs.pathList,
        userKey: userArgs.userKey,
      ),
      key: userArgs.userKey,
    );
  }

  void _loadData() {
    items.value =
        _musicCacheController.items
            .where((v) => userArgs.pathList.contains(v.path))
            .toList();

    userArgs.pathList.retainWhere(
      (v) =>
          _musicCacheController.items.map((p) => p.path).toList().contains(v),
    );

    syncCache();

    itemReSort(type: _settingController.sortMap[OperateArea.playList]);
    if (_settingController.isReverse.value) {
      itemReverse();
    }
  }

  Future<Uint8List?> getHeadCover(){
    return getCover(
      path: items[0].path,
      sizeFlag: 1,
    );
  }

  String _getSortType({required int type, required MusicCache data}) {
    switch (type) {
      case 0:
        return data.title.trim().toLowerCase();
      case 1:
        return data.artist.trim().toLowerCase();
      case 2:
        return data.album.trim().toLowerCase();
      case 3:
        return data.duration.toString().trim().toLowerCase();
    }
    return data.title;
  }

  void itemReSort({required int type}) {
    items.sort(
      (a, b) => _getSortType(
        type: type,
        data: a,
      ).compareTo(_getSortType(type: type, data: b)),
    );
  }

  void itemReverse() {
    items.assignAll(items.reversed.toList());
  }

  Future<void> putMetadata({
    required String path,
    required int index,
    required EditableMetadata data,
  }) async {
    final newCache = await _musicCacheController.putMetadata(
      path: path,
      index: index,
      data: data,
    );
    items[index] = newCache;
  }

  static void syncMetadata({required int index, required MusicCache newCache,}){
    PlayListController.items[index] = newCache;
  }


}
