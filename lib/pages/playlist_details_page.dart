import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/controller/playlist_details_ctrl.dart';
import 'package:zerobit_player/field/tag_suffix.dart';

class PlayListDetailsPage extends StatefulWidget {
  const PlayListDetailsPage({super.key});

  @override
  State<PlayListDetailsPage> createState() => _PlayListDetailsPageState();
}

class _PlayListDetailsPageState extends State<PlayListDetailsPage> {
  late PlayListDetailsController playListController;
  late String ctrlTag;
  late String title;

  // didChangeDependencies 可能会被系统调用多次
  // 用于保证 Controller 只初始化一次
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as UserPlayListCache;
      title = args.userKey.split(TagSuffix.playList)[0];

      ctrlTag = args.userKey;

      playListController = Get.put(
        PlayListDetailsController(pathList: args.pathList),
        tag: ctrlTag,
      );
      _isInit = true;
    }
  }

  @override
  void dispose() {
    Get.delete<PlayListDetailsController>(tag: ctrlTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: playListController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.playList,
        audioSource: ctrlTag,
        controller: playListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
