import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'dart:typed_data';

import 'general_style.dart';
import 'getxController/setting_ctrl.dart';

final SettingController _settingController = Get.find<SettingController>();

class AsyncCover extends StatelessWidget {
  const AsyncCover({super.key});

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<Uint8List?>(
      future: getCover(
        path: "D:\\Miku_Uta\\testaudio\\40mP - 心傷モノクローム (单色心伤).flac",
        sizeFlag: 0,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: MemoryImage(snapshot.data!),
              height: 256,
              width: 256,
              fit: BoxFit.cover,
            ),
          );
        }
        return Container();
      },
    );
  }
}

class AsyncText extends StatelessWidget {
  const AsyncText({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: getMetadata(
        path: "D:\\Miku_Uta\\testaudio\\40mP - 心傷モノクローム (单色心伤).flac",
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data!.title,
            style: generalTextStyle(ctx: context, size: 'md'),
          );
        }
        return Text(
          'default',
          style: generalTextStyle(ctx: context, size: 'md'),
        );
      },
    );
  }
}

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {

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
          Text('设置', style: generalTextStyle(ctx: context, size: 28.0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('文件夹', style: generalTextStyle(ctx: context, size: 'lg')),
              CustomBtn(
                fn: () {
                  var foldersClone = [..._settingController.folders];
                  showDialog(
                    barrierDismissible: true,
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("文件夹管理"),
                        titleTextStyle: generalTextStyle(
                          ctx: context,
                          size: 20,
                          weight: FontWeight.w700
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.surface,

                        actionsAlignment: MainAxisAlignment.end,
                        actions: <Widget>[
                          SizedBox(
                            width: 400,
                            height: 300,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Obx(() {
                                    return ListView.builder(
                                      itemCount:
                                          _settingController.folders.length,
                                      itemExtent: 24,
                                      cacheExtent: 24 * 2,
                                      itemBuilder: (context, index) {
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              _settingController.folders[index],
                                              style: generalTextStyle(ctx: context,size: 'md'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                _settingController.folders
                                                    .remove(
                                                      _settingController
                                                          .folders[index],
                                                    );
                                              },
                                              child: Tooltip(
                                                message: "del",
                                                child: Icon(
                                                PhosphorIconsLight.trash,
                                                color: Colors.red,
                                              ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }),
                                ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8,
                                  children: [
                                    CustomBtn(
                                      fn: () async {
                                        String? selectedDirectory =
                                            await FilePicker.platform
                                                .getDirectoryPath();
                                        if (selectedDirectory != null &&
                                            !_settingController.folders
                                                .contains(selectedDirectory)) {
                                          _settingController.folders.add(
                                            selectedDirectory,
                                          );
                                        }
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor: Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "添加",
                                    ),
                                    CustomBtn(
                                      fn: () {
                                        Navigator.pop(context, 'cancel');
                                        _settingController.folders.value =
                                            foldersClone;
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor: Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "取消",
                                    ),
                                    CustomBtn(
                                      fn: () {
                                        Navigator.pop(context, 'actions');
                                        foldersClone = [
                                          ..._settingController.folders,
                                        ];
                                        _settingController.putCache(
                                          isSaveFolders: true,
                                        );
                                      },
                                      backgroundColor: Colors.transparent,
                                      contentColor: Theme.of(context).colorScheme.primary,
                                      btnWidth: 72,
                                      btnHeight: 36,
                                      label: "确定",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ).then((value) {
                    if (value == null) {
                      _settingController.folders.value = foldersClone;
                    }
                  });
                },
                icon: PhosphorIconsLight.folder,
                label: '管理',
                btnHeight: 40,
                btnWidth: 96,
                backgroundColor: Theme.of(context).colorScheme.primary,
                contentColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ],
          ),
          const AsyncCover(),
          const AsyncText(),
        ],
      ),
    );
  }
}
