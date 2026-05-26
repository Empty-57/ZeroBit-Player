import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/controller/details_page_base_ctrl.dart';

class FoldersDetailsController extends GetxController
    with DetailsPageBaseController {
  final List<String> pathList;
  FoldersDetailsController({required this.pathList});

  static final audioListItems = <MusicCache>[].obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadDetailsData(pathList, OperateArea.foldersList, loadCover: false);
    });
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
