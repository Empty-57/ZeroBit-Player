import 'package:get/get.dart';

class AudioSource extends GetxController {
  static const allMusic = 'allMusic';
  static const artist = 'artist';

  final currentAudioSource = AudioSource.allMusic.obs;
}
