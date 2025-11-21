import 'dart:typed_data';
import 'package:transparent_image/transparent_image.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import 'package:get/get.dart';

import '../getxController/setting_ctrl.dart';
import 'get_sort_type.dart';

mixin AudioControllerGenClass {
  final SettingController _settingController = Get.find<SettingController>();
  RxList<MusicCache> get items;

  Rx<Uint8List> get headCover => kTransparentImage.obs;

  void itemReSort({required int type}){
    if(!_settingController.isReverse.value){
      items.sort(
      (a, b) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
    }else{
      items.sort(
      (b, a) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
    }
  }

  void itemReverse(){
    items.assignAll(items.reversed.toList());
  }
}
