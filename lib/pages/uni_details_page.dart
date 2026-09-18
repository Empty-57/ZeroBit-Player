import 'package:flutter/material.dart';
import 'package:zerobit_player/components/audio_gen_pages.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/controller/details_page_ctrl.dart';

class UniDetailsPage extends StatefulWidget {
  const UniDetailsPage({super.key});

  @override
  State<UniDetailsPage> createState() => _UniDetailsPageState();
}

class _UniDetailsPageState extends State<UniDetailsPage> {
  late final DetailsPageController detailsController;
  late final String audioSourceTag;
  late final String title;
  late final String operateArea;
  late final String userKey;

  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {};

      final pathList =
          (args['pathList'] as List<dynamic>?)?.cast<String>() ?? [];
      title = args['title'] ?? '未知详情页';
      operateArea = args['operateArea'] ?? '';
      userKey = args['userKey'] ?? '';

      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      audioSourceTag = '${title}_${operateArea}_$uniqueId';

      detailsController = DetailsPageController(
        pathList: pathList,
        operateArea: operateArea,
      )..init();

      _isInit = true;
    }
  }

  @override
  void dispose() {
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlurWithCoverBackground(
      cover: detailsController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: operateArea,
        audioSource: audioSourceTag,
        controller: detailsController,
        userKey: userKey,
      ),
    );
  }
}
