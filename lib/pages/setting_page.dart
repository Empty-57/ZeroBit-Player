import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import 'package:zerobit_player/src/rust/api/get_fonts.dart';
import '../components/get_snack_bar.dart';
import '../getxController/desktop_lyrics_setting_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';

const double btnW = 108;
final SettingController _settingController = Get.find<SettingController>();
final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

final DesktopLyricsSettingController _desktopLyricsSettingController =
    Get.find<DesktopLyricsSettingController>();

List<String> _fontsList = [];

const double _setBtnHeight = 40;

const String _latestRepoApiUrl =
    "https://api.github.com/repos/Empty-57/ZeroBit-Player/releases/latest";
const String _latestRepoUrl =
    "https://github.com/Empty-57/ZeroBit-Player/releases/latest";

class _RepoInfo {
  final String version;
  final String updatedTime;
  final String title;
  final String body;

  const _RepoInfo({
    required this.version,
    required this.updatedTime,
    required this.title,
    required this.body,
  });
}

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
                  width: context.width / 2,
                  height: context.height / 2,
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
                                      overflow: TextOverflow.fade,
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
                        () => Visibility(
                          visible:
                              _musicCacheController.currentScanAudio.value == ''
                                  ? false
                                  : true,
                          child: Text(
                            '已扫描到：${_musicCacheController.currentScanAudio.value}',
                            style: generalTextStyle(ctx: context, size: 'md'),
                            softWrap: true,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      Obx(
                        () => Visibility(
                          visible:
                              _musicCacheController.currentScanAudio.value == ''
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                contentColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                overlayColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
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
        SettingController.apiMap.entries.map((entry) {
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
          label: SettingController.apiMap[_settingController.apiIndex.value],
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

Widget _getColorPicker(
  BuildContext context,
  int initColor,
  void Function(int color) fn, [
  bool enableAlpha = false,
]) {
  final TextEditingController hexController = TextEditingController();
  int themeColor_ = initColor;
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
                    pickerColor: Color(themeColor_),
                    colorPickerWidth: 400,
                    pickerAreaHeightPercent: 0.7,
                    enableAlpha: enableAlpha,
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
                          fn(themeColor_);
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        contentColor: Theme.of(context).colorScheme.onPrimary,
                        overlayColor:
                            Theme.of(context).colorScheme.surfaceContainer,
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

class _ColorPicker extends StatelessWidget {
  const _ColorPicker();

  @override
  Widget build(BuildContext context) {
    return _getColorPicker(context, _settingController.themeColor.value, (
      color,
    ) {
      _settingController.themeColor.value = color;
      _settingController.putCache();
    });
  }
}

Widget _getFontFamilyDialog(
  BuildContext context,
  String label,
  void Function(int i) fn,
) {
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
                width: context.width / 2,
                height: context.height / 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      "当前字体: $label",
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
                              fn(index);
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
                                overflow: TextOverflow.fade,
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

class _FontFamilyDialog extends StatelessWidget {
  const _FontFamilyDialog();

  @override
  Widget build(BuildContext context) {
    return _getFontFamilyDialog(context, _settingController.fontFamily.value, (
      index,
    ) {
      _settingController.fontFamily.value = _fontsList[index];
      _settingController.putCache();
    });
  }
}

List<CustomBtn<dynamic>> _getFontSizeList(void Function(int) fn) {
  return List.generate(21, (index) => index + 16).map((i) {
    return CustomBtn(
      fn: () => fn(i),
      btnWidth: btnW,
      btnHeight: _setBtnHeight,
      label: i.toString(),
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Colors.transparent,
    );
  }).toList();
}

List<CustomBtn<dynamic>> _getFontWeightList(void Function(int) fn) {
  return List.generate(9, (index) => index).map((i) {
    return CustomBtn(
      fn: () => fn(i),
      btnWidth: btnW,
      btnHeight: _setBtnHeight,
      label: (i * 100 + 100).toString(),
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Colors.transparent,
    );
  }).toList();
}

MenuAnchor _getMenuAnchorButton(
  MenuController menuController,
  BuildContext context,
  String label,
  List<Widget> menuChildren,
) {
  return MenuAnchor(
    menuChildren: menuChildren,
    controller: menuController,
    consumeOutsideTap: true,
    style: MenuStyle(
      maximumSize: WidgetStatePropertyAll(Size.fromHeight(context.height / 2)),
    ),
    child: CustomBtn(
      fn: () {
        if (menuController.isOpen) {
          menuController.close();
        } else {
          menuController.open();
        }
      },
      label: label,
      btnHeight: _setBtnHeight,
      btnWidth: btnW,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: Theme.of(context).colorScheme.onPrimary,
      mainAxisAlignment: MainAxisAlignment.center,
    ),
  );
}

class _LrcFontSizeDropMenu extends StatelessWidget {
  const _LrcFontSizeDropMenu();

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    return Obx(
      () => _getMenuAnchorButton(
        menuController,
        context,
        '${_settingController.lrcFontSize.value}',
        _getFontSizeList((i) {
          _settingController.lrcFontSize.value = i;
          _settingController.putCache(isSaveFolders: false);
          menuController.close();
        }),
      ),
    );
  }
}

class _LrcFontWeightDropMenu extends StatelessWidget {
  const _LrcFontWeightDropMenu();

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    return Obx(
      () => _getMenuAnchorButton(
        menuController,
        context,
        (_settingController.lrcFontWeight.value * 100 + 100).toString(),
        _getFontWeightList((i) {
          _settingController.lrcFontWeight.value = i;
          _settingController.putCache(isSaveFolders: false);
          menuController.close();
        }),
      ),
    );
  }
}

class _CheckVersion extends StatelessWidget {
  const _CheckVersion();

  @override
  Widget build(BuildContext context) {
    return CustomBtn(
      fn: () async {
        snackBar() => showSnackBar(
          title: "ERROR",
          msg: "获取更新失败",
          duration: Duration(milliseconds: 3000),
        );

        try {
          final dio = Dio(
            BaseOptions(
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
                'Connection': 'keep-alive',
              },
            ),
          );
          final response = await dio.get(
            _latestRepoApiUrl,
            options: Options(responseType: ResponseType.json),
          );
          if (response.data != null) {
            final Map<String, dynamic> jsonData = response.data;

            final List<int> latestVer =
                jsonData['tag_name']
                    .toString()
                    .replaceAll('v', '')
                    .split('.')
                    .map((v) => int.parse(v))
                    .toList();
            final List<int> localVer =
                (await PackageInfo.fromPlatform()).version
                    .split('.')
                    .map((v) => int.parse(v))
                    .toList();
            if (latestVer[0] > localVer[0] ||
                (latestVer[0] == localVer[0] && latestVer[1] > localVer[1]) ||
                (latestVer[0] == localVer[0] &&
                    latestVer[1] == localVer[1] &&
                    latestVer[2] > localVer[2])) {
              final repoInfo = _RepoInfo(
                version: jsonData['tag_name'].toString(),
                updatedTime: DateTime.parse(
                  jsonData['updated_at'].toString(),
                ).toLocal().toString().substring(0, 19),
                title: jsonData['name'].toString(),
                body: jsonData['body'].toString(),
              );

              if (context.mounted) {
                showDialog(
                  barrierDismissible: true,
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(repoInfo.title),
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
                          width: context.width / 2,
                          height: context.height / 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              Text(
                                '更新于：${repoInfo.updatedTime}\n更新信息：',
                                style: generalTextStyle(
                                  ctx: context,
                                  size: 'md',
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Markdown(data: repoInfo.body),
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
                                    contentColor:
                                        Theme.of(context).colorScheme.primary,
                                    btnWidth: 72,
                                    btnHeight: 36,
                                    label: "取消",
                                  ),
                                  CustomBtn(
                                    fn: () async {
                                      Navigator.pop(context, 'action');
                                      final Uri url = Uri.parse(_latestRepoUrl);
                                      try {
                                        await launchUrl(url);
                                      } catch (e) {
                                        debugPrint(e.toString());
                                        showSnackBar(
                                          title: "ERROR",
                                          msg: "跳转失败，请前往浏览器下载！",
                                          duration: Duration(
                                            milliseconds: 3000,
                                          ),
                                        );
                                      }
                                    },
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    contentColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    overlayColor:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainer,
                                    btnWidth: 128,
                                    btnHeight: 36,
                                    icon: PhosphorIconsLight.arrowUpRight,
                                    label: "获取更新",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
            } else {
              showSnackBar(
                title: "OK",
                msg: "目前是最新版本",
                duration: Duration(milliseconds: 3000),
              );
            }
          } else {
            snackBar();
          }
        } catch (err) {
          debugPrint(err.toString());
          snackBar();
        }
      },
      icon: PhosphorIconsLight.spinnerGap,
      label: '检查更新',
      btnHeight: _setBtnHeight,
      btnWidth: 148,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class _DesktopLrcFontSizeDropMenu extends StatelessWidget {
  const _DesktopLrcFontSizeDropMenu();

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    return Obx(
      () => _getMenuAnchorButton(
        menuController,
        context,
        '${_desktopLyricsSettingController.fontSize.value}',
        _getFontSizeList((i) {
          _desktopLyricsSettingController.fontSize.value = i;
          _desktopLyricsSettingController.setFontSize(size: i);
          menuController.close();
        }),
      ),
    );
  }
}

class _DesktopLrcFontWeightDropMenu extends StatelessWidget {
  const _DesktopLrcFontWeightDropMenu();

  @override
  Widget build(BuildContext context) {
    final menuController = MenuController();
    return Obx(
      () => _getMenuAnchorButton(
        menuController,
        context,
        '${_desktopLyricsSettingController.fontWeight.value * 100 + 100}',
        _getFontWeightList((i) {
          _desktopLyricsSettingController.fontWeight.value = i;
          _desktopLyricsSettingController.setFontWeight(weight: i);
          menuController.close();
        }),
      ),
    );
  }
}

class _DesktopLrcFontOpacityDropMenu extends StatelessWidget {
  const _DesktopLrcFontOpacityDropMenu();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(showValueIndicator: ShowValueIndicator.always),
        child: Obx(
          () => Slider(
            min: 0.0,
            max: 1.0,
            label: _desktopLyricsSettingController.fontOpacity.value
                .toStringAsFixed(2),
            value: _desktopLyricsSettingController.fontOpacity.value,

            onChanged: (v) {
              _desktopLyricsSettingController.fontOpacity.value = v;
              _desktopLyricsSettingController.setFontOpacity(opacity: v);
            },
            onChangeEnd: (v) {
              _desktopLyricsSettingController.setFontOpacity(opacity: v);
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopLyricsOverlayColorPicker extends StatelessWidget {
  const _DesktopLyricsOverlayColorPicker();

  @override
  Widget build(BuildContext context) {
    return _getColorPicker(
      context,
      _desktopLyricsSettingController.overlayColor.value,
      (color) {
        _desktopLyricsSettingController.overlayColor.value = color;
        _desktopLyricsSettingController.setOverlayColor(color: color);
      },
      true,
    );
  }
}

class _DesktopLyricsUnderColorPicker extends StatelessWidget {
  const _DesktopLyricsUnderColorPicker();

  @override
  Widget build(BuildContext context) {
    return _getColorPicker(
      context,
      _desktopLyricsSettingController.underColor.value,
      (color) {
        _desktopLyricsSettingController.underColor.value = color;
        _desktopLyricsSettingController.setUnderColor(color: color);
      },
      true,
    );
  }
}

class _DesktopLyricsFontFamilyDialog extends StatelessWidget {
  const _DesktopLyricsFontFamilyDialog();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _getFontFamilyDialog(
        context,
        _desktopLyricsSettingController.fontFamily.value,
        (index) {
          _desktopLyricsSettingController.fontFamily.value = _fontsList[index];
          _desktopLyricsSettingController.setFontFamily(
            family: _desktopLyricsSettingController.fontFamily.value,
          );
        },
      ),
    );
  }
}

class _DesktopLyricsAlignmentRadio extends StatelessWidget {
  const _DesktopLyricsAlignmentRadio();

  @override
  Widget build(BuildContext context) {
    final alignment = [0, 1, 2];
    return Material(
      child: Wrap(
        spacing: 8,
        children:
            alignment
                .map(
                  (v) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 2,
                    children: [
                      Obx(
                        () => Radio<int>(
                          value: v,
                          groupValue:
                              _desktopLyricsSettingController
                                  .lrcAlignment
                                  .value,
                          onChanged: (int? value) {
                            _desktopLyricsSettingController.setLrcAlignment(
                              alignment: value ?? 1,
                            );
                          },
                        ),
                      ),
                      Text(
                        DesktopLyricsSettingController.lrcAlignmentMap[v] ??
                            '左对齐',
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}

Widget _createHotKeyItem(
  BuildContext context, {
  required Rx<HotKey> myHotkey,
  required void Function(HotKey) fn,
}) {
  final hotKey_ = myHotkey;
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    spacing: 16,
    children: [
      Obx(
        () => Text(
          [
            ...(hotKey_.value.modifiers ?? []).map((e) {
              final firstPhysicalKey = e.physicalKeys.first;
              return firstPhysicalKey.keyLabel;
            }),
            hotKey_.value.key.keyLabel,
          ].join(' + '),
          style: generalTextStyle(ctx: context, size: 'md'),
        ),
      ),
      CustomBtn(
        fn: () {
          showDialog(
            barrierDismissible: true,
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("设置快捷键"),
                titleTextStyle: generalTextStyle(
                  ctx: context,
                  size: 'xl',
                  weight: FontWeight.w600,
                ),
                content: Obx(
                  () => Text(
                    [
                      ...(hotKey_.value.modifiers ?? []).map((e) {
                        final firstPhysicalKey = e.physicalKeys.first;
                        return firstPhysicalKey.keyLabel;
                      }),
                      hotKey_.value.key.keyLabel,
                    ].join(' + '),
                  ),
                ),
                contentTextStyle: generalTextStyle(
                  ctx: context,
                  size: 'md',
                  weight: FontWeight.w100,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,

                actionsAlignment: MainAxisAlignment.end,
                actions: <Widget>[
                  SizedBox(
                    width: context.width / 3,
                    height: context.height / 4,
                    child: Center(
                      child: Transform.scale(
                        scale: 1.5,
                        filterQuality: FilterQuality.high,
                        child: Obx(
                          () => HotKeyRecorder(
                            initalHotKey: hotKey_.value,
                            onHotKeyRecorded: (hotKey) async {
                              hotKey_.value = hotKey;
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ).then((_) {
            fn(hotKey_.value);
          });
        },
        icon: PhosphorIconsLight.option,
        label: '设置快捷键',
        btnHeight: _setBtnHeight,
        btnWidth: 148,
        mainAxisAlignment: MainAxisAlignment.center,
        backgroundColor: Theme.of(context).colorScheme.primary,
        overlayColor: Theme.of(context).colorScheme.surfaceContainer,
        contentColor: Theme.of(context).colorScheme.onPrimary,
      ),
    ],
  );
}

class _SetHotKeyToggleDialog extends StatelessWidget {
  const _SetHotKeyToggleDialog();

  AudioController get _audioController => Get.find<AudioController>();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyToggle,
      fn: (h) async {
        await hotKeyManager.unregister(_settingController.hotKeyToggle.value);
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyToggle.value = h;
        _settingController.setToggleHid(hid: h.physicalKey.usbHidUsage);
        await hotKeyManager.register(
          _settingController.hotKeyToggle.value,
          keyDownHandler: (hotKey) {
            _audioController.audioToggle();
          },
        );
      },
    );
  }
}

class _SetHotKeyNextDialog extends StatelessWidget {
  const _SetHotKeyNextDialog();

  AudioController get _audioController => Get.find<AudioController>();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyNext,
      fn: (h) async {
        await hotKeyManager.unregister(_settingController.hotKeyNext.value);
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyNext.value = h;
        _settingController.setNextHid(hid: h.physicalKey.usbHidUsage);
        await hotKeyManager.register(
          _settingController.hotKeyNext.value,
          keyDownHandler: (hotKey) {
            _audioController.audioToNext();
          },
        );
      },
    );
  }
}

class _SetHotKeyPreviousDialog extends StatelessWidget {
  const _SetHotKeyPreviousDialog();

  AudioController get _audioController => Get.find<AudioController>();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyPrevious,
      fn: (h) async {
        await hotKeyManager.unregister(_settingController.hotKeyPrevious.value);
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyPrevious.value = h;
        _settingController.setPreviousHid(hid: h.physicalKey.usbHidUsage);
        await hotKeyManager.register(
          _settingController.hotKeyPrevious.value,
          keyDownHandler: (hotKey) {
            _audioController.audioToPrevious();
          },
        );
      },
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

  Widget _createSetItem({
    required String text,
    required Widget child,
    required BuildContext context,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(text, style: generalTextStyle(ctx: context, size: 'lg')),
        child,
      ],
    );
  }

  Widget _createRadioBtn({
    required RxBool value,
    required WidgetStateProperty<Color?> trackColor,
    required BuildContext context,
    required void Function(bool) fn,
  }) {
    return Material(
      color: Colors.transparent,
      child: Obx(
        () => Switch(
          value: value.value,
          trackColor: trackColor,
          thumbColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.onPrimary,
          ),
          onChanged: fn,
        ),
      ),
    );
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

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  const _SetDivider(title: '常规'),

                  _createSetItem(
                    text: '歌曲文件夹',
                    child: const _FolderManagerDialog(),
                    context: context,
                  ),

                  _createSetItem(
                    text: 'API源',
                    child: const _ApiDropMenu(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '自动下载选择的歌词',
                    child: _createRadioBtn(
                      value: _settingController.autoDownloadLrc,
                      trackColor: switchTrackColor,
                      context: context,
                      fn: (bool value) {
                        _settingController.autoDownloadLrc.value = value;
                        _settingController.putCache();
                      },
                    ),
                    context: context,
                  ),

                  const _SetDivider(title: '个性化'),

                  _createSetItem(
                    text: '主题色',
                    child: const _ColorPicker(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '动态主题色',
                    child: _createRadioBtn(
                      value: _settingController.dynamicThemeColor,
                      trackColor: switchTrackColor,
                      context: context,
                      fn: (bool value) {
                        _settingController.dynamicThemeColor.value = value;
                        _settingController.putCache();
                      },
                    ),
                    context: context,
                  ),

                  _createSetItem(
                    text: '字体',
                    child: const _FontFamilyDialog(),
                    context: context,
                  ),

                  const _SetDivider(title: '歌词样式'),

                  _createSetItem(
                    text: '字号',
                    child: const _LrcFontSizeDropMenu(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '字重',
                    child: const _LrcFontWeightDropMenu(),
                    context: context,
                  ),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '预览',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      FractionallySizedBox(
                        widthFactor: 1,
                        child: Obx(() {
                          final lyricStyle = generalTextStyle(
                            ctx: context,
                            size: _settingController.lrcFontSize.value,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer.withValues(
                              alpha:
                                  _settingController.themeMode.value == 'dark'
                                      ? 0.2
                                      : 0.3,
                            ),
                            weight:
                                FontWeight.values[_settingController
                                    .lrcFontWeight
                                    .value],
                          );

                          final strutStyle = StrutStyle(
                            fontSize:
                                _settingController.lrcFontSize.value.toDouble(),
                            forceStrutHeight: true,
                          );

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.1,
                                child: Text(
                                  '预览 Preview プレビューです 123',
                                  style: lyricStyle.copyWith(
                                    color: lyricStyle.color?.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                  strutStyle: strutStyle,
                                ),
                              ),
                              Text(
                                '预览 Preview プレビューです 123',
                                style: lyricStyle,
                                strutStyle: strutStyle,
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),

                  Tooltip(
                    message: '此效果比较占用性能',
                    child: _createSetItem(
                      text: '歌词行模糊',
                      child: _createRadioBtn(
                        value: _settingController.useBlur,
                        trackColor: switchTrackColor,
                        context: context,
                        fn: (bool value) {
                          _settingController.useBlur.value = value;
                          _settingController.putCache();
                        },
                      ),
                      context: context,
                    ),
                  ),

                  const _SetDivider(title: '桌面歌词样式'),

                  _createSetItem(
                    text: '字号',
                    child: const _DesktopLrcFontSizeDropMenu(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '字重',
                    child: const _DesktopLrcFontWeightDropMenu(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '透明度',
                    child: const _DesktopLrcFontOpacityDropMenu(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '已播放颜色',
                    child: const _DesktopLyricsOverlayColorPicker(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '未播放颜色',
                    child: const _DesktopLyricsUnderColorPicker(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '歌词字体',
                    child: const _DesktopLyricsFontFamilyDialog(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '对齐方式',
                    child: const _DesktopLyricsAlignmentRadio(),
                    context: context,
                  ),

                  Tooltip(
                    message: '若开启，桌面歌词窗口将不接受任何鼠标事件',
                    child: _createSetItem(
                      text: '是否忽略鼠标事件',
                      child: _createRadioBtn(
                        value:
                            _desktopLyricsSettingController.isIgnoreMouseEvents,
                        trackColor: switchTrackColor,
                        context: context,
                        fn: (bool value) {
                          _desktopLyricsSettingController.setIgnoreMouseEvents(
                            isIgnore: value,
                          );
                        },
                      ),
                      context: context,
                    ),
                  ),

                  _createSetItem(
                    text: '竖排显示',
                    child: _createRadioBtn(
                      value:
                          _desktopLyricsSettingController
                              .useVerticalDisplayMode,
                      trackColor: switchTrackColor,
                      context: context,
                      fn: (bool value) {
                        _desktopLyricsSettingController
                            .setUseVerticalDisplayMode(use: value);
                      },
                    ),
                    context: context,
                  ),

                  const _SetDivider(title: '快捷键'),

                  // _createSetItem(
                  //     text: '是否将快捷键应用到全局',
                  //     child: _createRadioBtn(
                  //       value:
                  //           _settingController.hotKeyScope,
                  //       trackColor: switchTrackColor,
                  //       context: context,
                  //       fn: (bool value) async{
                  //         _settingController.setHotKeyScope(scope: value);
                  //         await hotKeyManager.unregisterAll();
                  //         _settingController.initHotKey();
                  //       },
                  //     ),
                  //     context: context,
                  //   ),
                  // 此库注册系统级别热键会导致软件崩溃，不使用，此bug处于未解决状态
                  _createSetItem(
                    text: '播放/暂停',
                    child: const _SetHotKeyToggleDialog(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '上一首',
                    child: const _SetHotKeyPreviousDialog(),
                    context: context,
                  ),

                  _createSetItem(
                    text: '下一首',
                    child: const _SetHotKeyNextDialog(),
                    context: context,
                  ),

                  const _SetDivider(title: '关于'),

                  _createSetItem(
                    text: '当前版本',
                    child: SizedBox(
                      width: 108,
                      child: Center(
                        child: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final style = generalTextStyle(
                              ctx: context,
                              size: 'md',
                            );
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              if (snapshot.hasData) {
                                return Text(
                                  snapshot.data!.version,
                                  style: style,
                                );
                              } else {
                                return Text('获取版本号失败！', style: style);
                              }
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    context: context,
                  ),

                  _createSetItem(
                    text: '检查更新',
                    child: const _CheckVersion(),
                    context: context,
                  ),

                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
