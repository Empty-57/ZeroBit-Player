import 'package:zerobit_player/HIveCtrl/hive_manager.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/audio_ctrl_mixin.dart';


class MusicCacheController extends GetxController with AudioControllerGenClass {

  @override
  final items = <MusicCache>[].obs;

  final _musicCacheBox = HiveManager.musicCacheBox;
  final SettingController _settingController = Get.find<SettingController>();

  final currentScanPath = ''.obs;

  @override
  void onInit() {
    loadData();
    super.onInit();
  }

  void loadData() {
    items.value = _musicCacheBox.getAll();
    itemReSort(type: _settingController.sortMap[OperateArea.allMusic]);
    if (_settingController.isReverse.value) {
      itemReverse();
    }
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

  @override
  void itemReSort({required int type}) {
    items.sort(
      (a, b) => _getSortType(
        type: type,
        data: a,
      ).compareTo(_getSortType(type: type, data: b)),
    );
  }

  @override
  void itemReverse() {
    items.assignAll(items.reversed.toList());
  }

  Future<void> remove({required MusicCache metadata}) async {
    items.removeWhere((v) => v.path == metadata.path);
    await HiveManager.musicCacheBox.del(key: metadata.path);
  }

  Future<MusicCache> putMetadata({
    required String path,
    required int index,
    required EditableMetadata data,
  }) async {
    await editTags(path: path, data: data);
    final newMetadata = await getMetadata(path: path);
    final newCache = MusicCache(
      title: newMetadata.title,
      artist: newMetadata.artist,
      album: newMetadata.album,
      genre: newMetadata.genre,
      duration: newMetadata.duration,
      bitrate: newMetadata.bitrate,
      sampleRate: newMetadata.sampleRate,
      path: newMetadata.path,
    );
    await _musicCacheBox.put(data: newCache, key: path);
    items[index] = newCache;
    return newCache;
  }
}
