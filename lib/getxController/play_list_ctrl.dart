import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/tools/audio_ctrl_mixin.dart';

import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/user_playlist_model.dart';
import '../field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/get_sort_type.dart';
import 'music_cache_ctrl.dart';

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class PlayListController extends GetxController with AudioControllerGenClass {
  final UserPlayListCache userArgs;
  PlayListController({required this.userArgs});

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  final SettingController _settingController = Get.find<SettingController>();

  @override
  final headCover =kTransparentImage.obs;

  static final audioListItems = <MusicCache>[].obs;

  @override
  RxList<MusicCache> get items => audioListItems;

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

  void _loadData() async{
    audioListItems.value =
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

    if(audioListItems.isNotEmpty){
      headCover.value=await getCover(
      path: audioListItems[0].path,
      sizeFlag: 1,
    )??kTransparentImage;
    }

  }

  @override
  void itemReSort({required int type}) {
    audioListItems.sort(
      (a, b) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
  }

  @override
  void itemReverse() {
    audioListItems.assignAll(audioListItems.reversed.toList());
  }


 static void audioListSyncMetadata({required int index, required MusicCache newCache,}){
    audioListItems[index] = newCache;
  }

}
