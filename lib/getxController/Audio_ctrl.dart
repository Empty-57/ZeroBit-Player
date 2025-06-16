import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';

enum AudioState{
  playing,
  pause,
  stop,
}

class AudioController extends GetxController{
  final currentPath=''.obs;
  String? _lastPath;

  final currentState=AudioState.stop.obs;

  Future<void> audioPlay({required String path})async{
    try{
      _lastPath=currentPath.value;
    currentPath.value=path;
    update([path,if (_lastPath != null) _lastPath!]);
    await playFile(path: path);
    }catch(e){
      debugPrint(e.toString());
      showSnackBar(title: "ERR:",msg: e.toString());
    }
  }

  Future<void> audioResume() async{
    await resume();
  }

  Future<void> audioPause()async{
    await pause();
  }

  Future<void> audioStop()async{
    await stop();
  }

  Future<void> audioToggle()async{
    await toggle();
  }

  Future<double> audioGetVolume()async{
    return await getVolume();
  }

  Future<void> audioSetVolume({required double vol})async{
    await setVolume(vol: vol);
  }

}