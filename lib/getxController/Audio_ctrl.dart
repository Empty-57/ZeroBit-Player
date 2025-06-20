import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';

import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/music_cahce_model.dart';
import '../field/operate_area.dart';
import 'music_cache_ctrl.dart';

enum AudioState{
  stop,
  playing,
  pause,
}

class AudioController extends GetxController{
  final currentPath=''.obs;
  final currentIndex=(-1).obs;
  String? _lastPath;
  final currentMs100=0.0.obs;
  final progress=0.0.obs;

  final currentState=AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
  final OperateArea _operateArea=Get.find<OperateArea>();

  late List playListCacheItems=[...Get.find<MusicCacheController>().items];

  String _hasNextAudioPath='';

  @override
  void onInit() {
    super.onInit();

    ever(currentMs100, (_) {
      if(currentIndex.value!=-1&&playListCacheItems.isNotEmpty&&currentIndex.value<playListCacheItems.length){
        progress.value=(currentMs100.value/playListCacheItems[currentIndex.value].duration).clamp(0.0, 1.0);
      }else{
        progress.value=0.0;
      }
    }
    );

    ever(_operateArea.currentFiled, (_){

      switch(_operateArea.currentFiled.value){
        case OperateArea.allMusic:
          playListCacheItems=[...Get.find<MusicCacheController>().items];
          break;
      }
    }

    );

  }

  void syncCurrentIndex(){
    currentIndex.value=playListCacheItems.indexWhere((metadata) => metadata.path == currentPath.value);
  }


  Future<void> audioPlay({required String path})async{
    final oldPath = currentPath.value;
  final oldIndex = currentIndex.value;
  final oldState = currentState.value;

  currentMs100.value=0.0;
    try{
      _lastPath=currentPath.value;
    currentPath.value=path;
    syncCurrentIndex();
    currentState.value=AudioState.playing;

    update([path,if (_lastPath != null) _lastPath!]);
    await playFile(path: path);
    }catch(e){
      currentPath.value = oldPath;
      currentIndex.value = oldIndex;
      currentState.value = oldState;
      update([path, if (oldPath != null) oldPath]);

      currentMs100.value=0.0;

      debugPrint(e.toString());
      currentState.value=AudioState.stop;
      showSnackBar(title: "ERR:",msg: e.toString());
    }
  }

  Future<void> audioResume() async{
    if(currentIndex.value==-1){return;}
    currentState.value=AudioState.playing;
    await resume();
  }

  Future<void> audioPause()async{
    if(currentIndex.value==-1){return;}
    currentState.value=AudioState.pause;
    await pause();
  }

  Future<void> audioStop()async{
    currentState.value=AudioState.stop;
    currentIndex.value=-1;
    await stop();
  }

  Future<void> audioToggle()async{
    if(currentIndex.value==-1){return;}
    if(currentState.value==AudioState.stop||currentState.value==AudioState.pause){
      currentState.value=AudioState.playing;
    }else{
      currentState.value=AudioState.pause;
    }

    await toggle();
  }

  Future<double> audioGetVolume()async{
    return await getVolume();
  }

  Future<void> audioSetVolume({required double vol})async{
    await setVolume(vol: vol);
  }

  void changePlayMode(){
    _settingController.playMode.value++;
    if(_settingController.playMode.value>2||_settingController.playMode.value<0){
      _settingController.playMode.value=0;
    }
    _settingController.putCache();
  }

  Future<void> _maybeRandomPlay()async{
    if(_settingController.playMode.value==2){
      currentIndex.value=Random().nextInt(playListCacheItems.length);
    }

    if(_hasNextAudioPath!=''){
      await audioPlay(path: _hasNextAudioPath);
      _hasNextAudioPath='';
      return;
    }

    await audioPlay(path: playListCacheItems[currentIndex.value].path);
  }

  Future<void> audioToPrevious()async{
    if(currentIndex.value==-1){return;}
    currentIndex.value--;
    if(currentIndex.value<0){
      currentIndex.value=playListCacheItems.length-1;
    }

    await _maybeRandomPlay();
  }

  Future<void> audioToNext()async{
    if(currentIndex.value==-1){return;}
    currentIndex.value++;
    if(currentIndex.value>playListCacheItems.length-1){
      currentIndex.value=0;
    }

    await _maybeRandomPlay();
  }

  Future<void> audioAutoPlay()async{
    if(currentIndex.value==-1){return;}
    switch (_settingController.playMode.value){
      case 0:
        await audioPlay(path: playListCacheItems[currentIndex.value].path);
        break;
      case 1:
        await audioToNext();
        break;
      case 2:
        await _maybeRandomPlay();
        break;
    }
  }

  void insertNext({required MusicCache metadata}){
    if(currentIndex.value==-1||playListCacheItems.length==1||playListCacheItems.isEmpty||playListCacheItems[currentIndex.value]==metadata){return;}
    playListCacheItems.remove(metadata);
    final toIndex = (playListCacheItems.indexWhere((v) => v.path == currentPath.value)+1).clamp(0, playListCacheItems.length);
    playListCacheItems.insert(toIndex, metadata);

    syncCurrentIndex();
    showSnackBar(title: "OK", msg: "已添加到下一首播放",duration: Duration(milliseconds: 1000));
    _hasNextAudioPath=metadata.path;
  }

  Future<void> audioRemove({required String filed,required MusicCache metadata})async{

    switch(filed){
      case OperateArea.allMusic:
        await HiveManager.musicCacheBox.del(key: metadata.path);
        break;
    }
    playListCacheItems.remove(metadata);
    syncCurrentIndex();

  }

}