import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';

import '../field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/get_sort_type.dart';
import 'music_cache_ctrl.dart';
class ArtistListController extends GetxController with AudioControllerGenClass{

  final List<String> pathList;
  ArtistListController({required this.pathList});

  final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

  final SettingController _settingController = Get.find<SettingController>();

  static final audioListItems=<MusicCache>[].obs;

  @override
  final headCover =kTransparentImage.obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    headCover.value=kTransparentImage;
    super.onInit();
    _loadData();
  }

  void _loadData()async{

    audioListItems.value=_musicCacheController.items.where((v)=>pathList.contains(v.path)).toList();
    itemReSort(type: _settingController.sortMap[OperateArea.artistList]);
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

}