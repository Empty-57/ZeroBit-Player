import 'package:flutter/material.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/album_details_ctrl.dart';

class AlbumDetailsPage extends StatefulWidget {
  const AlbumDetailsPage({super.key});

  @override
  State<AlbumDetailsPage> createState() => _AlbumDetailsPageState();
}

class _AlbumDetailsPageState extends State<AlbumDetailsPage> {
  late AlbumDetailsController albumListController;
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
      title = args['title'] ?? '未知专辑';

      ctrlTag = title + DateTime.now().millisecondsSinceEpoch.toString();

      albumListController = Get.put(
        AlbumDetailsController(pathList: pathList),
        tag: ctrlTag,
      );
      _isInit = true;
    }
  }

  @override
  void dispose() {
    Get.delete<AlbumDetailsController>(tag: ctrlTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: albumListController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.albumList,
        audioSource: ctrlTag,
        controller: albumListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
