import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/controller/folders_details_ctrl.dart';
import 'package:zerobit_player/components/blur_background.dart';

class FoldersDetailsPage extends StatefulWidget {
  const FoldersDetailsPage({super.key});

  @override
  State<FoldersDetailsPage> createState() => _FoldersDetailsPageState();
}

class _FoldersDetailsPageState extends State<FoldersDetailsPage> {
  late FoldersDetailsController foldersListController;
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
      title = args['title'] ?? '未知文件夹';

      ctrlTag = title + DateTime.now().millisecondsSinceEpoch.toString();

      foldersListController = Get.put(
        FoldersDetailsController(pathList: pathList),
        tag: ctrlTag,
      );
      _isInit = true;
    }
  }

  @override
  void dispose() {
    Get.delete<FoldersDetailsController>(tag: ctrlTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: foldersListController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.foldersList,
        audioSource: ctrlTag,
        controller: foldersListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
