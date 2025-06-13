import 'package:flutter/cupertino.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/hive_manager.dart';

import '../src/rust/api/bass.dart';
import '../tools/sync_cache.dart';

class SettingController extends GetxController {
  final themeMode = 'dark'.obs;
  final apiIndex=0.obs;
  final volume=1.0.obs;
  final folders = <String>[].obs;


  final String _key = 'setting';
  final _settingCacheBox = HiveManager.settingCacheBox;

  void _initHive() async{
    final cache = _settingCacheBox.get(key: _key);
    if (cache != null) {
      themeMode.value = cache.themeMode;
      apiIndex.value=cache.apiIndex;
      // volume.value=cache.volume;
      folders.value = [...cache.folders];
    }
    // await setVolume(vol: cache?.volume??0.6);
    await setVolume(vol: volume.value);
  }

  @override
  void onInit() {
    _initHive();
    super.onInit();
  }

  Future<void> putCache({required bool isSaveFolders}) async {
    _settingCacheBox.put(
      data: SettingCache(themeMode: themeMode.value, apiIndex: apiIndex.value,volume: volume.value,folders: folders),
      key: _key,
    );
    if (isSaveFolders) {
      await syncCache();
    }
  }
}
