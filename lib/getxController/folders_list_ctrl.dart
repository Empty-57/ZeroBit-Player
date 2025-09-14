import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import '../field/operate_area.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/get_sort_type.dart';
import 'music_cache_ctrl.dart';

class FoldersListController extends GetxController with AudioControllerGenClass {
  final List<String> pathList;
  FoldersListController({required this.pathList});

  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  final SettingController _settingController = Get.find<SettingController>();

  static final audioListItems = <MusicCache>[].obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    super.onInit();
    _loadData();
  }

  @override
  void onClose() {
    audioListItems.value = [];
    super.onClose();
  }

  void _loadData() async {
    audioListItems.value =
        _musicCacheController.items
            .where((v) => pathList.contains(v.path))
            .toList();
    itemReSort(type: _settingController.sortMap[OperateArea.foldersList]);
  }

  @override
  void itemReSort({required int type}) {
    if(!_settingController.isReverse.value){
      audioListItems.sort(
      (a, b) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
    }else{
      audioListItems.sort(
      (b, a) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
    }
  }

  @override
  void itemReverse() {
    audioListItems.assignAll(audioListItems.reversed.toList());
  }

  static void audioListSyncMetadata({
    required int index,
    required MusicCache newCache,
  }) {
    if (audioListItems.isEmpty || index > audioListItems.length - 1) {
      return;
    }
    audioListItems[index] = newCache;
  }
}
