import 'package:flutter/material.dart';
import 'package:zerobit_player/core/constants/audio_source.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';

import '../widgets/audio_list_view.dart';

class LocalMusicPage extends StatelessWidget {
  const LocalMusicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MusicCacheController.instance;
    return AudioListView(
      title: "音乐",
      operateArea: OperateArea.allMusic,
      audioSource: AudioSource.allMusic,
      userKey: '',
      controller: c,
      rwScrollOffset: c.rwScrollOffset,
    );
  }
}
