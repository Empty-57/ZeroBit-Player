import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../components/audio_gen_pages.dart';
import '../field/operate_area.dart';
import '../field/tag_suffix.dart';
import '../getxController/folders_list_ctrl.dart';

class FoldersListPage extends StatelessWidget {
  const FoldersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final pathList = args['pathList'];
    final title = args['title'];

    late final FoldersListController foldersListController;

    Get.delete<FoldersListController>(tag: title + TagSuffix.foldersList);
    foldersListController = Get.put(
      FoldersListController(pathList: pathList),
      tag: title + TagSuffix.foldersList,
    );

    return AudioGenPages(
      title: title,
      operateArea: OperateArea.foldersList,
      audioSource: title + TagSuffix.foldersList,
      controller: foldersListController,
    );
  }
}
