import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/hive_manager.dart';
import 'package:zerobit_player/field/operate_area.dart';

import '../src/rust/api/bass.dart';
import '../tools/sync_cache.dart';

class SettingController extends GetxController {
  final themeMode = 'dark'.obs;
  final apiIndex=0.obs;
  final volume=1.0.obs;
  final folders = <String>[].obs;
  final sortMap=<dynamic,dynamic>{
    OperateArea.allMusic:0,
    OperateArea.playList:0,
    OperateArea.artistList:0,
    OperateArea.albumList:0,
    OperateArea.foldersList:0,
  }.obs;
  final viewModeMap=<dynamic,dynamic>{
    OperateArea.allMusic:true, //列表/表格
    OperateArea.playList:true,
    OperateArea.artistList:true,
    OperateArea.albumList:true,
    OperateArea.foldersList:true,
  }.obs;
  final isReverse=false.obs;
  final themeColor=0xff27272a.obs;
  final playMode=0.obs;
  final dynamicThemeColor=true.obs;
  final fontFamily="Microsoft YaHei Light".obs;

  final lrcAlignment=0.obs;

  final lrcFontSize=24.obs; // 16-36

  final lrcFontWeight=5.obs; // 0-8  w100-w900

  final autoDownloadLrc=true.obs;

  final useBlur=false.obs;

  final Map<int,String> apiMap={
    0:"QQ音乐",
    1:"网易云音乐"
  };

  final Map<int,String> sortType={
    0:'标题',
    1:'艺术家',
    2:'专辑',
    3:'时长',
  };

  final Map<int,String> playModeMap={
    0:'单曲循环',
    1:'列表循环',
    2:'随机播放',
  };

  final Map<int,String> lrcAlignmentMap={
    0:'左对齐',
    1:'居中',
    2:'右对齐',
  };


  final String _key = 'setting';
  final _settingCacheBox = HiveManager.settingCacheBox;

  void _initHive() async{
    final cache = _settingCacheBox.get(key: _key);
    if (cache != null) {
      themeMode.value = cache.themeMode;
      apiIndex.value=cache.apiIndex;
      volume.value=cache.volume;
      folders.value = [...cache.folders];
      final sortMap_= cache.sortMap.isNotEmpty? Map<dynamic,dynamic>.of(cache.sortMap):{
        OperateArea.allMusic:0,
        OperateArea.playList:0,
        OperateArea.artistList:0,
        OperateArea.albumList:0,
        OperateArea.foldersList:0,
      };

      if(sortMap.length>sortMap_.length){
        await putCache();
      }else{
        sortMap.value=sortMap_;
      }

      final viewModeMap_=cache.viewModeMap.isNotEmpty? Map<dynamic,dynamic>.of(cache.viewModeMap):{
        OperateArea.allMusic:true, //列表/表格
        OperateArea.playList:true,
        OperateArea.artistList:true,
        OperateArea.albumList:true,
        OperateArea.foldersList:true,
      };

      if(viewModeMap.length>viewModeMap_.length){
        await putCache();
      }else{
        viewModeMap.value=viewModeMap_;
      }

      isReverse.value=cache.isReverse;
      themeColor.value=cache.themeColor;
      playMode.value=cache.playMode;
      dynamicThemeColor.value=cache.dynamicThemeColor;
      fontFamily.value=cache.fontFamily;
      lrcAlignment.value=cache.lrcAlignment;
      lrcFontSize.value=cache.lrcFontSize;
      lrcFontWeight.value=cache.lrcFontWeight;
      autoDownloadLrc.value=cache.autoDownloadLrc;
      useBlur.value=cache.useBlur;
    }

    await setVolume(vol: cache?.volume??1.0);
  }

  @override
  void onInit() {
    _initHive();
    super.onInit();
  }

  Future<void> putCache({bool isSaveFolders=false}) async {
    _settingCacheBox.put(
      data: SettingCache(
        themeMode: themeMode.value,
        apiIndex: apiIndex.value,
        volume: volume.value,
        folders: folders,
        sortMap: sortMap,
        viewModeMap: viewModeMap,
        isReverse: isReverse.value,
        themeColor: themeColor.value,
        playMode: playMode.value,
        dynamicThemeColor: dynamicThemeColor.value,
        fontFamily: fontFamily.value,
        lrcAlignment: lrcAlignment.value,
        lrcFontSize: lrcFontSize.value,
        lrcFontWeight: lrcFontWeight.value,
        autoDownloadLrc: autoDownloadLrc.value,
        useBlur: useBlur.value,
      ),
      key: _key,
    );
    if (isSaveFolders) {
      await syncCache();
    }
  }
}
