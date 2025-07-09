import 'package:flutter/material.dart';
import 'package:zerobit_player/components/blur_background.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/getxController/artist_list_ctrl.dart';

import '../components/audio_gen_pages.dart';
import '../field/operate_area.dart';

import 'package:get/get.dart';

import '../field/tag_suffix.dart';

class ArtistListPage extends StatelessWidget {
  const ArtistListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final pathList = args['pathList'];
    final title = args['title'];

    late final ArtistListController artistListController;

    Get.delete<ArtistListController>(tag: title + TagSuffix.artistList);
    artistListController = Get.put(
      ArtistListController(pathList: pathList),
      tag: title + TagSuffix.artistList,
    );

    return BlurBackground(
      controller: artistListController,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.artistList,
        audioSource: title + TagSuffix.artistList,
        controller: artistListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
