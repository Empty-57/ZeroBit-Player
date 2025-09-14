import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../field/app_routes.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/general_style.dart';
import '../tools/sync_cache.dart';

final SettingController _settingController = Get.find<SettingController>();
const double _itemHeight = 64.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

final folderPathMap = <String, List<String>>{}.obs;

class FoldersViewPage extends StatelessWidget {
  const FoldersViewPage({super.key});

  void createMap() async {
    for (String folder in _settingController.folders) {
      folderPathMap[folder] = (await scanAudioPaths([folder])).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle1 = generalTextStyle(ctx: context, size: 'md');
    final textStyle2 = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    createMap();

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  '文件夹',
                  style: generalTextStyle(
                    ctx: context,
                    size: 'title',
                    weight: FontWeight.w600,
                  ),
                ),
                Obx(
                  () => Text(
                    '共${_settingController.folders.length}个文件夹',
                    style: generalTextStyle(ctx: context, size: 'md'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Obx(() {
              final folders = folderPathMap.keys.toList();
              return ListView.builder(
                itemCount: _settingController.folders.length,
                itemExtent: _itemHeight,
                cacheExtent: _itemHeight * 1,
                itemBuilder: (context, index) {
                  if (folders.isEmpty || index > folders.length - 1) {
                    return const SizedBox.shrink();
                  }

                  final folder = folders[index];
                  final pathList = folderPathMap[folder] ?? [];

                  return TextButton(
                    onPressed: () {
                      Get.toNamed(
                        AppRoutes.foldersList,
                        arguments: {'pathList': pathList, 'title': folder},
                        id: 1,
                      );
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: _borderRadius,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder,
                                style: textStyle1,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text("共${pathList.length}首音乐", style: textStyle2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
