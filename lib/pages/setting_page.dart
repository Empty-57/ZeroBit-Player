import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/src/rust/api/get_fonts.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';

final SettingController _settingController = Get.find<SettingController>();
final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

List<String> _fontsList = [];

const double _setBtnHeight = 40;

class _SetDivider extends StatelessWidget {
  final String title;
  const _SetDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          margin: EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            title,
            style: generalTextStyle(
              ctx: context,
              size: 'xl',
              weight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(bottom: 12),
          child: Divider(
            height: 0,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

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
                size: 'xl',
                weight: FontWeight.w600,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,

              actionsAlignment: MainAxisAlignment.end,
              actions: <Widget>[
                SizedBox(
                  width: Get.width/2,
                  height: Get.height/2,
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
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      _settingController.folders[index],
                                      style: generalTextStyle(
                                        ctx: context,
                                        size: 'md',
                                      ),
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
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
                      Obx(
                        () => Text(
                          _musicCacheController.currentScanPath.value,
                          style: generalTextStyle(
                            ctx: context,
                            size: 'md',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),

                      Obx(
                        () => Visibility(
                          visible:
                              _musicCacheController.currentScanPath.value == ''
                                  ? true
                                  : false,
                          child: Row(
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
                                      !_settingController.folders.contains(
                                        selectedDirectory,
                                      )) {
                                    _settingController.folders.add(
                                      selectedDirectory,
                                    );
                                  }
                                },
                                backgroundColor: Colors.transparent,
                                contentColor:
                                    Theme.of(context).colorScheme.primary,
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
                                contentColor:
                                    Theme.of(context).colorScheme.primary,
                                btnWidth: 72,
                                btnHeight: 36,
                                label: "取消",
                              ),
                              CustomBtn(
                                fn: () async {
                                  foldersClone = [
                                    ..._settingController.folders,
                                  ];
                                  await _settingController.putCache(
                                    isSaveFolders: true,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, 'actions');
                                  }
                                },
                                backgroundColor: Colors.transparent,
                                contentColor:
                                    Theme.of(context).colorScheme.primary,
                                btnWidth: 72,
                                btnHeight: 36,
                                label: "确定",
                              ),
                            ],
                          ),
                        ),
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
      btnHeight: _setBtnHeight,
      btnWidth: 96,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class _ApiDropMenu extends StatelessWidget {
  const _ApiDropMenu();

  @override
  Widget build(BuildContext context) {
    const double btnW = 148;

    final menuController = MenuController();
    final apiMenuList =
        _settingController.apiMap.entries.map((entry) {
          return CustomBtn(
            fn: () {
              _settingController.apiIndex.value = entry.key;
              _settingController.putCache(isSaveFolders: false);
              menuController.close();
            },
            btnWidth: btnW,
            btnHeight: _setBtnHeight,
            label: entry.value,
            mainAxisAlignment: MainAxisAlignment.center,
            backgroundColor: Colors.transparent,
          );
        }).toList();

    return MenuAnchor(
      menuChildren: apiMenuList,
      controller: menuController,
      consumeOutsideTap: true,
      child: Obx(
        () => CustomBtn(
          fn: () {
            if (menuController.isOpen) {
            menuController.close();
          } else {
            menuController.open();
          }
          },
          icon: PhosphorIconsLight.plugs,
          label: _settingController.apiMap[_settingController.apiIndex.value],
          btnHeight: _setBtnHeight,
          btnWidth: btnW,
          backgroundColor: Theme.of(context).colorScheme.primary,
          overlayColor: Theme.of(context).colorScheme.surfaceContainer,
          contentColor: Theme.of(context).colorScheme.onPrimary,
          mainAxisAlignment: MainAxisAlignment.center,
        ),
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
                size: 'xl',
                weight: FontWeight.w600,
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
      btnHeight: _setBtnHeight,
      btnWidth: 108,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class _FontFamilyDialog extends StatelessWidget {
  const _FontFamilyDialog();

  @override
  Widget build(BuildContext context) {
    return CustomBtn(
      fn: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("选择字体"),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 'xl',
                weight: FontWeight.w600,
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
                      Text(
                        "当前字体: ${_settingController.fontFamily.value}",
                        style: generalTextStyle(ctx: context, size: 'md'),
                      ),
                      Expanded(
                        flex: 1,
                        child: ListView.builder(
                          itemCount: _fontsList.length,
                          itemExtent: 36,
                          cacheExtent: 36 * 1,
                          itemBuilder: (context, index) {
                            return TextButton(
                              onPressed: () {
                                _settingController.fontFamily.value =
                                    _fontsList[index];
                                _settingController.putCache();
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _fontsList[index],
                                  style: generalTextStyle(
                                    ctx: context,
                                    size: 'md',
                                    fontFamily: _fontsList[index],
                                  ),
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
      icon: PhosphorIconsLight.textAa,
      label: '选择字体',
      btnHeight: _setBtnHeight,
      btnWidth: 128,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class Setting extends StatelessWidget {
  const Setting({super.key});

  void _getFonts() async {
    if (_fontsList.isEmpty) {
      _fontsList = await getFontsList();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetStateProperty<Color?> switchTrackColor =
        WidgetStateProperty<Color?>.fromMap(<WidgetStatesConstraint, Color>{
          WidgetState.selected: Theme.of(context).colorScheme.primary,
        });

    _getFonts();

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
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
              size: 'title',
              weight: FontWeight.w600,
            ),
          ),

          const _SetDivider(title: '常规'),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('歌曲文件夹', style: generalTextStyle(ctx: context, size: 'lg')),
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

          const _SetDivider(title: '个性化'),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('主题色', style: generalTextStyle(ctx: context, size: 'lg')),
              const _ColorPicker(),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('动态主题色', style: generalTextStyle(ctx: context, size: 'lg')),
              Material(
                color: Colors.transparent,
                child: Obx(
                  () => Switch(
                    value: _settingController.dynamicThemeColor.value,
                    trackColor: switchTrackColor,
                    thumbColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                    onChanged: (bool value) {
                      _settingController.dynamicThemeColor.value = value;
                      _settingController.putCache();
                    },
                  ),
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text('字体', style: generalTextStyle(ctx: context, size: 'lg')),
              const _FontFamilyDialog(),
            ],
          ),
        ],
      ),
    );
  }
}
