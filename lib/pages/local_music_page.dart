import 'package:flutter/material.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/getxController/music_cache_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:get/get.dart';

import '../components/audio_gen_pages.dart';



class LocalMusic extends StatelessWidget {
  const LocalMusic({super.key});

  @override
  Widget build(BuildContext context) {
    final MusicCacheController musicCacheController =
    Get.find<MusicCacheController>();
    return AudioGenPages(
      title: "音乐",
      operateArea: OperateArea.allMusic,
      audioSource: AudioSource.allMusic,
      controller: musicCacheController,
    );
  }
}
