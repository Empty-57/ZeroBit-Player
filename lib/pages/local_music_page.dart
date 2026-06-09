import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/field/operate_area.dart';

import '../components/audio_gen_pages.dart';

class LocalMusicPage extends GetView<MusicCacheController> {
  const LocalMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return AudioGenPages(
      title: "音乐",
      operateArea: OperateArea.allMusic,
      audioSource: AudioSource.allMusic,
      userKey: '',
      controller: c,
    );
  }
}
