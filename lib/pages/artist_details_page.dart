import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/controller/artist_details_ctrl.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/field/operate_area.dart';

class ArtistDetailsPage extends StatefulWidget {
  const ArtistDetailsPage({super.key});

  @override
  State<ArtistDetailsPage> createState() => _ArtistDetailsPageState();
}

class _ArtistDetailsPageState extends State<ArtistDetailsPage> {
  late ArtistDetailsController artistListController;
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
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};
      final pathList = args['pathList'] ?? [];
      title = args['title'] ?? '未知艺术家';

      ctrlTag = title+DateTime.now().millisecondsSinceEpoch.toString();

      artistListController = Get.put(
        ArtistDetailsController(pathList: pathList),
        tag: ctrlTag,
      );
      _isInit = true;
    }
  }

  @override
  void dispose() {
    Get.delete<ArtistDetailsController>(tag: ctrlTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: artistListController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.artistList,
        audioSource: ctrlTag,
        controller: artistListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
