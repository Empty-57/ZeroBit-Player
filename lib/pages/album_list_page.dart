import 'package:flutter/material.dart';
import 'package:zerobit_player/components/blur_background.dart';

import '../components/audio_gen_pages.dart';
import '../field/operate_area.dart';

import 'package:get/get.dart';

import '../field/tag_suffix.dart';
import '../getxController/album_list_crl.dart';

class AlbumListPage extends StatelessWidget {
  const AlbumListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final pathList = args['pathList'];
    final title = args['title'];

    late final AlbumListController albumListController;

    Get.delete<AlbumListController>(tag: title + TagSuffix.albumList);
    albumListController = Get.put(
      AlbumListController(pathList: pathList),
      tag: title + TagSuffix.albumList,
    );

    return BlurWithCoverBackground(
      cover: albumListController.headCover,
      child: AudioGenPages(
        title: title,
        operateArea: OperateArea.albumList,
        audioSource: title + TagSuffix.albumList,
        controller: albumListController,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
