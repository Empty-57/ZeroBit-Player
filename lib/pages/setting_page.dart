import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';

final SettingController _settingController = Get.find<SettingController>();
final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();
final AudioController _audioController = Get.find<AudioController>();

class _FolderManagerDialog extends StatelessWidget {
  const _FolderManagerDialog();

  @override
  Widget build(BuildContext context) {
    return CustomBtn(
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
                weight: FontWeight.w700,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

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
                            itemCount: _settingController.folders.length,
                            itemExtent: 36,
                            cacheExtent: 36 * 1,
                            itemBuilder: (context, index) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _settingController.folders[index],
                                    style: generalTextStyle(
                                      ctx: context,
                                      size: 'md',
                                    ),
                                  ),
                                  Tooltip(
                                    message: "删除",
                                    child: TextButton(
                                      onPressed: () {
                                        _settingController.folders.remove(
                                          _settingController.folders[index],
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        shape: const CircleBorder(),
                                      ),
                                      child: Icon(
                                        PhosphorIconsLight.trash,
                                        size: getIconSize(size: 'lg'),
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
                      Obx(()=>Text(
                          _musicCacheController.currentScanPath.value,
                        style: generalTextStyle(ctx: context,size: 'md',color: Theme.of(context).colorScheme.primary),
                      )
                      ),

                      Obx(()=>
                      Visibility(
                        visible: _musicCacheController.currentScanPath.value==''?true:false,
                          child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 8,
                        children: [
                          CustomBtn(
                            fn: () async {
                              String? selectedDirectory =
                                  await FilePicker.platform.getDirectoryPath();
                              if (selectedDirectory != null &&
                                  !_settingController.folders.contains(
                                    selectedDirectory,
                                  )) {
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
                              _settingController.folders.value = foldersClone;
                            },
                            backgroundColor: Colors.transparent,
                            contentColor: Theme.of(context).colorScheme.primary,
                            btnWidth: 72,
                            btnHeight: 36,
                            label: "取消",
                          ),
                          CustomBtn(
                            fn: () async{
                              foldersClone = [..._settingController.folders];
                              await _settingController.putCache(isSaveFolders: true);
                              Navigator.pop(context, 'actions');
                            },
                            backgroundColor: Colors.transparent,
                            contentColor: Theme.of(context).colorScheme.primary,
                            btnWidth: 72,
                            btnHeight: 36,
                            label: "确定",
                          ),
                        ],
                      )
                      )
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
    );
  }
}

class _ApiDropMenu extends StatelessWidget {
  const _ApiDropMenu();

  @override
  Widget build(BuildContext context) {
    const double btnW = 148;
    const double btnH = 40;

    final apiMenuList =
        _settingController.apiMap.entries.map((entry) {
          return PopupMenuItem<int>(
            padding: EdgeInsets.zero,
            value: entry.key,
            height: 40,
            child: InkWell(
              onTap: () {
                // 记得手动 pop 返回 value
                Navigator.pop(context, entry.key);
                _settingController.apiIndex.value = entry.key;
                _settingController.putCache(isSaveFolders: false);
              },
              child: Container(
                width: btnW,
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    entry.value,
                    style: generalTextStyle(ctx: context, size: 'md'),
                  ),
                ),
              ),
            ),
          );
        }).toList();

    return Obx(
      () => CustomBtn(
        fn: () {
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final offset = renderBox.localToGlobal(Offset.zero);
          showMenu(
            constraints: BoxConstraints(
              minWidth: btnW, // 约束最小宽度
              maxWidth: btnW, // 约束最大宽度
            ),
            context: context,
            position: RelativeRect.fromRect(
              // 定义菜单锚点区域
              Rect.fromLTWH(
                offset.dx + (renderBox.size.width - btnW) / 2, // 水平居中
                offset.dy + 0, // 父组件底部Y坐标
                btnW, // 菜单宽度
                0, // 高度由内容决定
              ),
              // 屏幕边界约束
              Offset.zero & MediaQuery.of(context).size,
            ),
            items: apiMenuList,
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
        icon: PhosphorIconsLight.plugs,
        label: _settingController.apiMap[_settingController.apiIndex.value],
        btnHeight: btnH,
        btnWidth: btnW,
        backgroundColor: Theme.of(context).colorScheme.primary,
        contentColor: Theme.of(context).colorScheme.onPrimary,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker();

  @override
  Widget build(BuildContext context) {
    final TextEditingController hexController = TextEditingController();
    int themeColor_ = _settingController.themeColor.value;

    return CustomBtn(
      fn: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('取色器'),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 20,
                weight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

              actionsAlignment: MainAxisAlignment.end,
              actions: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Hex RGB',
                      ),
                      controller: hexController,
                      autofocus: true,
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(
                          RegExp(kValidHexPattern),
                        ),
                      ],
                    ),

                    ColorPicker(
                      pickerAreaBorderRadius: BorderRadius.all(
                        Radius.circular(4),
                      ),
                      pickerColor: Color(_settingController.themeColor.value),
                      colorPickerWidth: 400,
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      labelTypes: [],
                      portraitOnly: true,
                      hexInputBar: false,
                      hexInputController: hexController,
                      onColorChanged: (Color color) {
                        themeColor_ = color.toARGB32();
                      },
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        CustomBtn(
                          fn: () {
                            Navigator.pop(context, 'cancel');
                          },
                          backgroundColor: Colors.transparent,
                          contentColor: Theme.of(context).colorScheme.primary,
                          btnWidth: 72,
                          btnHeight: 36,
                          label: "取消",
                        ),
                        CustomBtn(
                          fn: () {
                            Navigator.pop(context, 'action');
                            _settingController.themeColor.value = themeColor_;
                            _settingController.putCache();
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
              ],
            );
          },
        );
      },
      icon: PhosphorIconsLight.palette,
      label: '取色器',
      btnHeight: 40,
      btnWidth: 120,
      backgroundColor: Theme.of(context).colorScheme.primary,
      contentColor: Theme.of(context).colorScheme.onPrimary,
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
          Text(
            '设置',
            style: generalTextStyle(
              ctx: context,
              size: 28.0,
              weight: FontWeight.w400,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('文件夹', style: generalTextStyle(ctx: context, size: 'lg')),
              const _FolderManagerDialog(),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('API源', style: generalTextStyle(ctx: context, size: 'lg')),
              const _ApiDropMenu(),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('主题色', style: generalTextStyle(ctx: context, size: 'lg')),
              const _ColorPicker(),
            ],
          ),


          Expanded(child: ListView.builder(
            itemCount: _audioController.playListCacheItems.length,
              itemExtent: 48,
              cacheExtent: 48*1,
              itemBuilder: (context, index){
            return Text(_audioController.playListCacheItems[index].path,style: generalTextStyle(ctx: context),);
          }
          )
          ),


        ],
      ),
    );
  }
}
