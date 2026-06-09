import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/controller/details_page_ctrl.dart';

import '../field/operate_area.dart';

class UniDetailsPage extends StatefulWidget {
  const UniDetailsPage({super.key});

  @override
  State<UniDetailsPage> createState() => _UniDetailsPageState();
}

class _UniDetailsPageState extends State<UniDetailsPage> {
  late DetailsPageController detailsController;
  late String ctrlTag;
  late String title;
  late String operateArea;
  late String userKey;

  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};

      final pathList = args['pathList'] ?? [];
      title = args['title'] ?? '未知详情页';

      operateArea = args['operateArea'];

      userKey = args['userKey'] ?? '';

      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      ctrlTag = '${title}_${operateArea}_$uniqueId';

      detailsController = Get.put(
        DetailsPageController(pathList: pathList, operateArea: operateArea),
        tag: ctrlTag,
      );
      _isInit = true;
    }
  }

  @override
  void dispose() {
    Get.delete<DetailsPageController>(tag: ctrlTag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: detailsController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: operateArea,
        audioSource: ctrlTag,
        controller: detailsController,
        userKey: userKey,
        backgroundColor:
            (operateArea == OperateArea.artistDetails ||
                    operateArea == OperateArea.albumDetails ||
                    operateArea == OperateArea.playListDetails)
                ? Colors.transparent
                : null,
      ),
    );
  }
}
