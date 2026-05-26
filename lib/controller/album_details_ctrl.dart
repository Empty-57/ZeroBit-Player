import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/controller/details_page_base_ctrl.dart';

class AlbumDetailsController extends GetxController
    with DetailsPageBaseController {
  final List<String> pathList;
  AlbumDetailsController({required this.pathList});

  static final audioListItems = <MusicCache>[].obs;

  @override
  final Rx<Uint8List> headCover = kTransparentImage.obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadDetailsData(pathList, OperateArea.albumList);
    });
  }

  static void audioListSyncMetadata({
    required int index,
    required MusicCache newCache,
  }) {
    if (audioListItems.isEmpty || index < 0 || index >= audioListItems.length) {
      return;
    }
    audioListItems[index] = newCache;
  }
}
