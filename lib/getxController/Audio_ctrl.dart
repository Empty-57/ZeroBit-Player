import 'package:get/get.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';

enum AudioState{
  playing,
  pause,
  stop,
}

class AudioController extends GetxController{

  final currentPath=''.obs;

  final currentState=AudioState.stop.obs;

  Future<void> audioPlay({required String path})async{
    currentPath.value=path;
    await playFile(path: path);
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