import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import '../field/operate_area.dart';
import '../getxController/play_list_ctrl.dart';

import '../getxController/user_playlist_ctrl.dart';

class PlayList extends StatelessWidget {
  const PlayList({super.key});

  @override
  Widget build(BuildContext context) {
    final UserPlayListCache userArgs =
        (ModalRoute.of(context)!.settings.arguments
            as Map)['userPlayListCache'];

    late final PlayListController playListController;

    Get.delete<PlayListController>(tag: userArgs.userKey);
    playListController = Get.put(
      PlayListController(userArgs: userArgs),
      tag: userArgs.userKey,
    );

    return AudioGenPages(
      title: userArgs.userKey.split(playListTagSuffix)[0],
      operateArea: OperateArea.playList,
      audioSource: userArgs.userKey,
      controller: playListController,
    );
  }
}
