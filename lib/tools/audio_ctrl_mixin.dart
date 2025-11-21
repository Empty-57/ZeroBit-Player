import 'dart:io';
import 'dart:typed_data';
import 'package:transparent_image/transparent_image.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import 'package:get/get.dart';

import '../getxController/setting_ctrl.dart';
import 'get_sort_type.dart';

Future<List<MusicCache>> _sortFilesByModificationTime(
  List<MusicCache> musicCaches, {
  bool descending = true,
}) async {
  // 创建 MusicCache 和修改时间的配对列表
  List<Map<String, dynamic>> fileInfoList = [];

  for (MusicCache m in musicCaches) {
    try {
      final filePath = m.path;
      File file = File(filePath);
      if (await file.exists()) {
        DateTime modifiedTime = await file.lastModified();
        fileInfoList.add({'cache': m, 'modifiedTime': modifiedTime});
      } else {
        fileInfoList.add({'cache': m, 'modifiedTime': DateTime.now()});
      }
    } catch (e) {
      fileInfoList.add({'cache': m, 'modifiedTime': DateTime.now()});
    }
  }

  // 根据修改时间排序
  fileInfoList.sort((a, b) {
    if (descending) {
      return b['modifiedTime'].compareTo(a['modifiedTime']); // 降序：最新的在前
    } else {
      return a['modifiedTime'].compareTo(b['modifiedTime']); // 升序：最旧的在前
    }
  });

  // 返回排序后的列表
  return fileInfoList.map((info) => info['cache'] as MusicCache).toList();
}

mixin AudioControllerGenClass {
  final SettingController _settingController = Get.find<SettingController>();
  RxList<MusicCache> get items;

  Rx<Uint8List> get headCover => kTransparentImage.obs;

  void itemReSort({required int type}) async {
    if (type == 4) {
      items.value = await _sortFilesByModificationTime(
        items,
        descending: _settingController.isReverse.value,
      );
      return;
    }

    if (!_settingController.isReverse.value) {
      items.sort(
        (a, b) => getSortType(
          type: type,
          data: a,
        ).compareTo(getSortType(type: type, data: b)),
      );
    } else {
      items.sort(
        (b, a) => getSortType(
          type: type,
          data: a,
        ).compareTo(getSortType(type: type, data: b)),
      );
    }
  }

  void itemReverse() {
    items.assignAll(items.reversed.toList());
  }
}
