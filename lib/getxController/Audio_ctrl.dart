import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';

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

  final currentState=AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
  final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();

  late final cacheItems=_musicCacheController.items;

  Future<void> audioPlay({required String path})async{
    final oldPath = currentPath.value;
  final oldIndex = currentIndex.value;
  final oldState = currentState.value;


    try{
      _lastPath=currentPath.value;
    currentPath.value=path;
    currentIndex.value=cacheItems.indexWhere((metadata) => metadata.path == path);
    currentState.value=AudioState.playing;

    update([path,if (_lastPath != null) _lastPath!]);
    await playFile(path: path);
    }catch(e){
      currentPath.value = oldPath;
      currentIndex.value = oldIndex;
      currentState.value = oldState;
      update([path, if (oldPath != null) oldPath]);

      debugPrint(e.toString());
      currentState.value=AudioState.stop;
      showSnackBar(title: "ERR:",msg: e.toString());
    }
  }

  Future<void> audioResume() async{
    currentState.value=AudioState.playing;
    await resume();
  }

  Future<void> audioPause()async{
    currentState.value=AudioState.pause;
    await pause();
  }

  Future<void> audioStop()async{
    currentState.value=AudioState.stop;
    await stop();
  }

  Future<void> audioToggle()async{

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

  Future<void> audioToPrevious()async{
    if(currentIndex.value==-1){return;}
    currentIndex.value--;
    if(currentIndex.value<0){
      currentIndex.value=cacheItems.length-1;
    }
    if(_settingController.playMode.value==2){
      currentIndex.value=Random().nextInt(cacheItems.length);
    }
    await audioPlay(path: cacheItems[currentIndex.value].path);
  }

  Future<void> audioToNext()async{
    if(currentIndex.value==-1){return;}

    currentIndex.value++;
    if(currentIndex.value>cacheItems.length-1){
      currentIndex.value=0;
    }
    if(_settingController.playMode.value==2){
      currentIndex.value=Random().nextInt(cacheItems.length);
    }
    await audioPlay(path: cacheItems[currentIndex.value].path);
  }

  Future<void> audioAutoPlay()async{
    if(currentIndex.value==-1){return;}
    switch (_settingController.playMode.value){
      case 0:
        await audioPlay(path: cacheItems[currentIndex.value].path);
        break;
      case 1:
        currentIndex.value++;
        if(currentIndex.value>cacheItems.length-1){
          currentIndex.value=0;
        }
        await audioPlay(path: cacheItems[currentIndex.value].path);
        break;
      case 2:
        currentIndex.value=Random().nextInt(cacheItems.length);
        await audioPlay(path: cacheItems[currentIndex.value].path);
        break;
    }
  }

}