import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/controller/desktop_lyrics_setting_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:zerobit_player/src/rust/api/get_fonts.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:path/path.dart' as p;
import '../field/shared_preferences_key.dart';
import '../tools/version_checker.dart';

const double btnW = 108;
final SettingController _settingController = SettingController.instance;

final DesktopLyricsSettingController _desktopLyricsSettingController =
    DesktopLyricsSettingController.instance;

List<String> _fontsList = [];

const double _setBtnHeight = 40;

const String _latestRepoApiUrl =
    "https://api.github.com/repos/Empty-57/ZeroBit-Player/releases/latest";
const String _latestRepoUrl =
    "https://github.com/Empty-57/ZeroBit-Player/releases/latest";
const String _repoUrl = "https://github.com/Empty-57/ZeroBit-Player";

const String _reportUrl =
    "https://github.com/Empty-57/ZeroBit-Player/issues/new/choose";

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

class _FolderManagerDialog extends GetView<MusicCacheController> {
  const _FolderManagerDialog();

  @override
  Widget build(BuildContext context) {
    final musicCacheController = controller;
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
                            scrollCacheExtent: const ScrollCacheExtent.pixels(
                              36 * 1,
                            ),
                            itemCount: _settingController.folders.length,
                            itemExtent: 36,
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
                              musicCacheController.currentScanAudio.value == ''
                              ? false
                              : true,
                          child: Text(
                            '已扫描到：${musicCacheController.currentScanAudio.value}',
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
                              musicCacheController.currentScanAudio.value == ''
                              ? true
                              : false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              CustomBtn(
                                fn: () async {
                                  String? selectedDirectory = await FilePicker
                                      .platform
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
                                contentColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
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
                                contentColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                contentColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                overlayColor: Theme.of(
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
    final apiMenuList = SettingController.apiMap.entries.map((entry) {
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
  final RxInt themeColor_ = initColor.obs;

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    spacing: 16,
    children: [
      Obx(
        () => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Color(themeColor_.value),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      CustomBtn(
        fn: () {
          showDialog<String>(
            barrierDismissible: true,
            context: context,
            builder: (BuildContext context) {
              return _ColorPickerDialog(
                themeColor: themeColor_,
                enableAlpha: enableAlpha,
              );
            },
          ).then((result) {
            if (result == 'action') {
              fn(themeColor_.value);
            }
          });
        },
        icon: PhosphorIconsLight.palette,
        label: '取色器',
        btnHeight: _setBtnHeight,
        btnWidth: 108,
        mainAxisAlignment: MainAxisAlignment.center,
        backgroundColor: Theme.of(context).colorScheme.primary,
        overlayColor: Theme.of(context).colorScheme.surfaceContainer,
        contentColor: Theme.of(context).colorScheme.onPrimary,
      ),
    ],
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final RxInt themeColor;
  final bool enableAlpha;

  const _ColorPickerDialog({
    required this.themeColor,
    required this.enableAlpha,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _hexController;
  late final int _initialColor;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController();
    _initialColor = widget.themeColor.value;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('取色器'),
      titleTextStyle: generalTextStyle(
        ctx: context,
        size: 'xl',
        weight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(
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
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Hex RGB',
              ),
              controller: _hexController,
              autofocus: true,
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(kValidHexPattern)),
              ],
            ),

            ColorPicker(
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(4),
              ),
              pickerColor: Color(widget.themeColor.value),
              colorPickerWidth: 400,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: widget.enableAlpha,
              displayThumbColor: true,
              labelTypes: [],
              portraitOnly: true,
              hexInputBar: false,
              hexInputController: _hexController,
              onColorChanged: (Color color) {
                widget.themeColor.value = color.toARGB32();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                CustomBtn(
                  fn: () {
                    widget.themeColor.value = _initialColor;
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
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  contentColor: Theme.of(context).colorScheme.onPrimary,
                  overlayColor: Theme.of(context).colorScheme.surfaceContainer,
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
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker();

  @override
  Widget build(BuildContext context) {
    return _getColorPicker(context, _settingController.themeColor.value, (
      color,
    ) {
      _settingController.themeColor.value = color;
      if (_desktopLyricsSettingController.useDynamicOverlayColor.value) {
        _desktopLyricsSettingController.setDynamicOverlayColor(color);
      }
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
                        scrollCacheExtent: const ScrollCacheExtent.pixels(
                          36 * 1,
                        ),
                        itemCount: _fontsList.length,
                        itemExtent: 36,
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

List<CustomBtn<dynamic>> _getFontSizeList(
  void Function(int) fn, {
  int min = SettingController.lrcFontSizeMin,
  int max = SettingController.lrcFontSizeMax,
}) {
  return List.generate(max + 1 - min, (index) => index + min).map((i) {
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
  return List.generate(
    SettingController.lrcFontWeightMax + 1,
    (index) => index,
  ).map((i) {
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

class _CheckVersion extends StatefulWidget {
  const _CheckVersion();

  @override
  State<_CheckVersion> createState() => _CheckVersionState();
}

class _CheckVersionState extends State<_CheckVersion>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _handleCheck() async {
    if (_loading) return;

    setState(() => _loading = true);
    _loadingController.repeat();

    await VersionChecker.checkAndShowDialog(
      context,
      showNoUpdateToast: true,
      showErrorToast: true,
    );

    if (mounted) {
      _loadingController.stop();
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;

    return CustomBtn(
      fn: _loading ? null : _handleCheck,
      btnHeight: _setBtnHeight,
      btnWidth: 128,
      mainAxisAlignment: MainAxisAlignment.center,
      backgroundColor: Theme.of(context).colorScheme.primary,
      overlayColor: Theme.of(context).colorScheme.surfaceContainer,
      contentColor: color,
      children: [
        AnimatedBuilder(
          animation: _loadingController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _loading ? _loadingController.value * 2 * math.pi : 0,
              child: child,
            );
          },
          child: Icon(
            _loading
                ? PhosphorIconsLight.spinnerGap
                : PhosphorIconsLight.arrowClockwise,
            color: color,
            size: getIconSize(size: 'md'),
          ),
        ),
        Flexible(
          child: Text(
            _loading ? '检查中...' : '检查更新',
            style: generalTextStyle(ctx: context, size: 'md', color: color),
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.fade,
          ),
        ),
      ],
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
        _getFontSizeList(
          (i) {
            _desktopLyricsSettingController.setFontSize(size: i);
            menuController.close();
          },
          max: DesktopLyricsSettingController.fontSizeMax,
          min: DesktopLyricsSettingController.fontSizeMin,
        ),
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
          _desktopLyricsSettingController.setFontWeight(weight: i);
          menuController.close();
        }),
      ),
    );
  }
}

class _DesktopLrcFontOpacitySlider extends StatelessWidget {
  const _DesktopLrcFontOpacitySlider();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(showValueIndicator: ShowValueIndicator.onDrag),
        child: Obx(
          () => Row(
            children: [
              Text(
                _desktopLyricsSettingController.fontOpacity.value
                    .toStringAsFixed(2),
              ),
              Slider(
                min: 0.0,
                max: 1.0,
                label: _desktopLyricsSettingController.fontOpacity.value
                    .toStringAsFixed(2),
                value: _desktopLyricsSettingController.fontOpacity.value,

                onChanged: (v) {
                  _desktopLyricsSettingController.setFontOpacity(opacity: v);
                },
                onChangeEnd: (v) {
                  _desktopLyricsSettingController.setFontOpacity(opacity: v);
                },
              ),
            ],
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
          _desktopLyricsSettingController.setFontFamily(
            family: _fontsList[index],
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
    final alignment = [0, 1, 2, 3];
    return Material(
      color: Colors.transparent,
      child: Obx(
        () => RadioGroup<int>(
          groupValue: _desktopLyricsSettingController.lrcAlignment.value,
          onChanged: (int? v) {
            _desktopLyricsSettingController.setLrcAlignment(alignment: v ?? 1);
          },
          child: Wrap(
            spacing: 8,
            children: alignment
                .map(
                  (v) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 2,
                    children: [
                      Radio<int>(value: v),
                      Text(
                        DesktopLyricsSettingController.lrcAlignmentMap[v] ??
                            '左对齐',
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _LyricsSwitchAnimateModeRadio extends StatelessWidget {
  const _LyricsSwitchAnimateModeRadio();

  @override
  Widget build(BuildContext context) {
    final alignment = [0, 1, 2, 3];
    return Material(
      color: Colors.transparent,
      child: Obx(
        () => RadioGroup<int>(
          groupValue:
              _desktopLyricsSettingController.lyricsSwitchAnimateMode.value,
          onChanged: (int? v) {
            _desktopLyricsSettingController.setLyricsSwitchAnimateMode(
              mode: v ?? 1,
            );
          },
          child: Wrap(
            spacing: 8,
            children: alignment
                .map(
                  (v) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 2,
                    children: [
                      Radio<int>(value: v),
                      Text(
                        DesktopLyricsSettingController
                                .lyricsSwitchAnimateModeMap[v] ??
                            '无',
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

Widget _createHotKeyItem(
  BuildContext context, {
  required Rx<HotKey> myHotkey,
  required String prefKey,
  required Future<void> Function(HotKey) fn,
}) {
  final prev = myHotkey.value;
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
        fn: () async {
          await hotKeyManager.unregisterAll();
          if (!context.mounted) {
            await _settingController.initHotKey();
            return;
          }
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
          ).then((_) async {
            if (_settingController.checkHotConflict(hotKey_.value, prefKey)) {
              hotKey_.value = prev;
              showSnackBar(
                title: 'Err',
                msg: '快捷键已被占用，请更换。',
                duration: Duration(milliseconds: 1000),
              );
            }
            await fn(hotKey_.value);
            await _settingController.initHotKey();
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

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyToggle,
      prefKey: SharedPreferencesKey.toggleHidString,
      fn: (h) async {
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyToggle.value = h;
        _settingController.setToggleHid(key: h);
      },
    );
  }
}

class _SetHotKeyNextDialog extends StatelessWidget {
  const _SetHotKeyNextDialog();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyNext,
      prefKey: SharedPreferencesKey.nextHidString,
      fn: (h) async {
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyNext.value = h;
        _settingController.setNextHid(key: h);
      },
    );
  }
}

class _SetHotKeyPreviousDialog extends StatelessWidget {
  const _SetHotKeyPreviousDialog();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyPrevious,
      prefKey: SharedPreferencesKey.previousHidString,
      fn: (h) async {
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyPrevious.value = h;
        _settingController.setPreviousHid(key: h);
      },
    );
  }
}

class _SetHotKeyFullScreenDialog extends StatelessWidget {
  const _SetHotKeyFullScreenDialog();

  @override
  Widget build(BuildContext context) {
    return _createHotKeyItem(
      context,
      myHotkey: _settingController.hotKeyFullScreen,
      prefKey: SharedPreferencesKey.fullScreenHidString,
      fn: (h) async {
        // final hotKey_=HotKey(key: h.key,modifiers: h.modifiers,scope: _settingController.hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp);// 因库原因无法使用
        _settingController.hotKeyFullScreen.value = h;
        _settingController.setFullScreenHid(key: h);
      },
    );
  }
}

class _DesktopLyricsStrokeColor extends StatelessWidget {
  const _DesktopLyricsStrokeColor();
  @override
  Widget build(BuildContext context) {
    return _getColorPicker(
      context,
      _desktopLyricsSettingController.strokeColor.value,
      (color) {
        _desktopLyricsSettingController.strokeColor.value = color;
        _desktopLyricsSettingController.setStrokeColor(color: color);
      },
      true,
    );
  }
}

class _BackgroundImagePathPicker extends StatelessWidget {
  const _BackgroundImagePathPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 8,
      children: [
        Obx(
          () => SizedBox(
            width: 200,
            child: Text(
              p.basename(_settingController.backgroundImagePath.value),
              style: generalTextStyle(ctx: context, size: 'md'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ),
        CustomBtn(
          fn: () async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null && result.paths.isNotEmpty) {
                _settingController.backgroundImagePath.value =
                    result.paths.first!;
                _settingController.setBackgroundImagePath(
                  value: result.paths.first!,
                );
              } else {
                showSnackBar(title: 'ERR', msg: '发生未知问题');
              }
            } catch (e) {
              showSnackBar(title: 'ERR', msg: '发生错误： $e');
            }
          },
          icon: PhosphorIconsLight.image,
          tooltip: '选择背景图片',
          contentColor: theme.colorScheme.primary,
          btnHeight: 36,
          btnWidth: 36,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
        CustomBtn(
          fn: () {
            _settingController.backgroundImagePath.value = '';
            _settingController.setBackgroundImagePath(value: '');
          },
          icon: PhosphorIconsLight.arrowClockwise,
          tooltip: '还原背景',
          contentColor: theme.colorScheme.primary,
          btnHeight: 36,
          btnWidth: 36,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}

class _BackgroundImageOpacitySlider extends StatelessWidget {
  const _BackgroundImageOpacitySlider();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(showValueIndicator: ShowValueIndicator.onDrag),
        child: Obx(
          () => Row(
            children: [
              Text(
                _settingController.backgroundImageOpacity.value.toStringAsFixed(
                  2,
                ),
              ),
              Slider(
                min: 0.0,
                max: 1.0,
                label: _settingController.backgroundImageOpacity.value
                    .toStringAsFixed(2),
                value: _settingController.backgroundImageOpacity.value,

                onChanged: (v) {
                  _settingController.backgroundImageOpacity.value = v;
                },
                onChangeEnd: (v) {
                  _settingController.setBackgroundImageOpacity(value: v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundImageBlurSlider extends StatelessWidget {
  const _BackgroundImageBlurSlider();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SliderTheme(
        data: SliderTheme.of(
          context,
        ).copyWith(showValueIndicator: ShowValueIndicator.onDrag),
        child: Obx(
          () => Row(
            children: [
              Text(
                _settingController.backgroundImageBlur.value.toStringAsFixed(2),
              ),
              Slider(
                min: 0.0,
                max: 36.0,
                divisions: 18,
                label: _settingController.backgroundImageBlur.value
                    .toStringAsFixed(2),
                value: _settingController.backgroundImageBlur.value,

                onChanged: (v) {
                  _settingController.backgroundImageBlur.value = v;
                },
                onChangeEnd: (v) {
                  _settingController.setBackgroundImageBlur(value: v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  int _currentTabIndex = 0;
  bool _isForward = true;
  late final Future<PackageInfo> _packageInfoFuture;

  static const List<({IconData icon, String label, double width})> _tabs = [
    (icon: PhosphorIconsLight.gearSix, label: '常规', width: 96),
    (icon: PhosphorIconsLight.palette, label: '外观', width: 96),
    (icon: PhosphorIconsLight.playlist, label: '歌词', width: 96),
    (icon: PhosphorIconsLight.creditCard, label: '桌面歌词', width: 108),
    (icon: PhosphorIconsLight.option, label: '快捷键', width: 96),
    (icon: PhosphorIconsLight.warningCircle, label: '关于', width: 96),
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _packageInfoFuture = PackageInfo.fromPlatform();
    if (_fontsList.isEmpty) {
      getFontsList().then((list) => _fontsList = list);
    }
  }

  /// 点击 Tab 时更新索引与方向
  void _onTabChanged(int index) {
    if (_currentTabIndex == index) return;
    setState(() {
      _isForward = index > _currentTabIndex;
      _currentTabIndex = index;
    });
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const _GeneralTab();
      case 1:
        return const _AppearanceTab();
      case 2:
        return const _LyricsTab();
      case 3:
        return const _DesktopLyricsTab();
      case 4:
        return const _HotkeysTab();
      case 5:
        return _AboutTab(packageInfoFuture: _packageInfoFuture);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      child: Column(
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

          // 顶部 Tab 栏
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = _currentTabIndex == index;
                return CustomBtn(
                  fn: () => _onTabChanged(index),
                  label: tab.label,
                  backgroundColor: theme.colorScheme.secondaryContainer
                      .withValues(alpha: isSelected ? 0.6 : 0.2),
                  icon: tab.icon,
                  borderWidth: 1,
                  borderColor: theme.colorScheme.primary.withValues(
                    alpha: isSelected ? 0.6 : 0.2,
                  ),
                  btnHeight: _setBtnHeight,
                  btnWidth: tab.width,
                  mainAxisAlignment: MainAxisAlignment.center,
                );
              }),
            ),
          ),

          // 页面内容切换区（动态双向滑动）
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                // 判断当前正在执行动画的子组件是"进入"还是"离开"
                final isIncoming =
                    (child.key is ValueKey<int>) &&
                    (child.key as ValueKey<int>).value == _currentTabIndex;

                const double offsetDist = 0.1;

                // 根据前进/后退方向及是否是新页面，动态计算起点
                // 向右切(_isForward == true):
                //    - 新页(isIncoming)：从右(+offsetDist)滑入到 0.0
                //    - 旧页(!isIncoming)：从 0.0 滑向左(-offsetDist)淡出
                // 向左切(_isForward == false):
                //    - 新页(isIncoming)：从左(-offsetDist)滑入到 0.0
                //    - 旧页(!isIncoming)：从 0.0 滑向右(+offsetDist)淡出
                final double beginDx = _isForward
                    ? (isIncoming ? offsetDist : -offsetDist)
                    : (isIncoming ? -offsetDist : offsetDist);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(beginDx, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentTabIndex),
                child: _buildContent(_currentTabIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单行设置项封装
class _SettingItem extends StatelessWidget {
  final String text;
  final Widget child;
  final String? tooltip;

  const _SettingItem({
    super.key,
    required this.text,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final item = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: generalTextStyle(ctx: context, size: 'lg'),
        ),
        child,
      ],
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: item);
    }
    return item;
  }
}

/// 开关设置项封装
class _SettingSwitchItem extends StatelessWidget {
  final String text;
  final RxBool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;

  const _SettingSwitchItem({
    super.key,
    required this.text,
    required this.value,
    required this.onChanged,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingItem(
      text: text,
      tooltip: tooltip,
      child: Material(
        color: Colors.transparent,
        child: Obx(
          () => Switch(
            value: value.value,
            trackColor: WidgetStateProperty<Color?>.fromMap({
              WidgetState.selected: theme.colorScheme.primary,
            }),
            thumbColor: WidgetStatePropertyAll(theme.colorScheme.onPrimary),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Tab 滚动布局容器
class _SettingsTabWrapper extends StatelessWidget {
  final List<Widget> children;

  const _SettingsTabWrapper({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [...children, const SizedBox(height: 96)],
      ),
    );
  }
}

/// 常规设置
class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    return _SettingsTabWrapper(
      children: [
        const _SettingItem(text: '歌曲文件夹', child: _FolderManagerDialog()),
        const _SettingItem(text: 'API源', child: _ApiDropMenu()),
        _SettingSwitchItem(
          text: '自动保存获取的歌词',
          value: _settingController.autoDownloadLrc,
          onChanged: (val) {
            _settingController.autoDownloadLrc.value = val;
            _settingController.putCache();
          },
        ),
        _SettingSwitchItem(
          text: '自动从API获取歌词',
          value: _settingController.autoGetLyrics,
          onChanged: (val) => _settingController.setAutoGetLyrics(value: val),
        ),
        _SettingSwitchItem(
          text: '启用独占模式',
          value: _settingController.useExclusiveMode,
          onChanged: (val) => _settingController.setExclusiveMode(use: val),
        ),
        _SettingSwitchItem(
          text: '启用音量平衡（ReplayGain）',
          tooltip: '需要音频有ReplayGain标签才能生效',
          value: _settingController.useReplayGain,
          onChanged: (val) => _settingController.setUseReplayGain(value: val),
        ),
        _SettingSwitchItem(
          text: '使用任务栏缩略图工具栏控制播放',
          value: _settingController.useTaskBarCtrl,
          onChanged: (val) => _settingController.setUseTaskBarCtrl(value: val),
        ),
        _SettingSwitchItem(
          text: '关闭窗口后在后台运行',
          value: _settingController.close2Tray,
          onChanged: (val) => _settingController.setClose2Tray(value: val),
        ),
      ],
    );
  }
}

/// 外观设置
class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    return _SettingsTabWrapper(
      children: [
        const _SettingItem(text: '主题色', child: _ColorPicker()),
        _SettingSwitchItem(
          text: '动态主题色',
          value: _settingController.dynamicThemeColor,
          onChanged: (val) {
            _settingController.dynamicThemeColor.value = val;
            _settingController.putCache();
          },
        ),
        const _SettingItem(text: '字体', child: _FontFamilyDialog()),
        const _SettingItem(text: '更改背景', child: _BackgroundImagePathPicker()),
        const _SettingItem(
          text: '背景图片不透明度',
          child: _BackgroundImageOpacitySlider(),
        ),
        const _SettingItem(
          text: '背景图片模糊值',
          child: _BackgroundImageBlurSlider(),
        ),
      ],
    );
  }
}

/// 歌词设置
class _LyricsTab extends StatelessWidget {
  const _LyricsTab();

  @override
  Widget build(BuildContext context) {
    return _SettingsTabWrapper(
      children: [
        const _SettingItem(text: '字号', child: _LrcFontSizeDropMenu()),
        const _SettingItem(text: '字重', child: _LrcFontWeightDropMenu()),
        // 预览模块
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预览',
              style: generalTextStyle(ctx: context, size: 'lg'),
            ),
            FractionallySizedBox(
              widthFactor: 1,
              child: Obx(() {
                final isDark = _settingController.themeMode.value == 'dark';
                final lyricStyle = generalTextStyle(
                  ctx: context,
                  size: _settingController.lrcFontSize.value,
                  color: Theme.of(context).colorScheme.onSecondaryContainer
                      .withValues(alpha: isDark ? 0.2 : 0.3),
                  weight:
                      FontWeight.values[_settingController.lrcFontWeight.value],
                );
                final strutStyle = StrutStyle(
                  fontSize: _settingController.lrcFontSize.value.toDouble(),
                  forceStrutHeight: true,
                );

                return Column(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Text(
                        '预览 Preview プレビューです 123',
                        style: lyricStyle.copyWith(
                          color: lyricStyle.color?.withValues(alpha: 0.8),
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
        _SettingSwitchItem(
          text: '使用动态背景',
          tooltip: '此效果比较占用性能',
          value: _settingController.useMesh,
          onChanged: (val) => _settingController.setUseMesh(value: val),
        ),
        _SettingSwitchItem(
          text: '歌词行模糊',
          tooltip: '此效果比较占用性能',
          value: _settingController.useBlur,
          onChanged: (val) {
            _settingController.useBlur.value = val;
            _settingController.putCache();
          },
        ),
        _SettingSwitchItem(
          text: '使用弹性滚动',
          tooltip: '此效果比较占用性能',
          value: _settingController.useSpringScroll,
          onChanged: (val) => _settingController.setSpringScroll(value: val),
        ),
      ],
    );
  }
}

/// 桌面歌词设置
class _DesktopLyricsTab extends StatelessWidget {
  const _DesktopLyricsTab();

  @override
  Widget build(BuildContext context) {
    return _SettingsTabWrapper(
      children: [
        _SettingSwitchItem(
          text: '开启桌面歌词',
          value: _settingController.showDesktopLyrics,
          onChanged: (val) => _settingController.setShowDesktopLyrics(val),
        ),
        const _SettingItem(text: '字号', child: _DesktopLrcFontSizeDropMenu()),
        const _SettingItem(text: '字重', child: _DesktopLrcFontWeightDropMenu()),
        const _SettingItem(text: '不透明度', child: _DesktopLrcFontOpacitySlider()),
        _SettingSwitchItem(
          text: '已播放颜色跟随主题色',
          value: _desktopLyricsSettingController.useDynamicOverlayColor,
          onChanged: (val) {
            _desktopLyricsSettingController.setUseDynamicOverlayColor(
              value: val,
              color: _settingController.themeColor.value,
            );
          },
        ),
        const _SettingItem(
          text: '已播放颜色',
          child: _DesktopLyricsOverlayColorPicker(),
        ),
        const _SettingItem(
          text: '未播放颜色',
          child: _DesktopLyricsUnderColorPicker(),
        ),
        const _SettingItem(
          text: '歌词字体',
          child: _DesktopLyricsFontFamilyDialog(),
        ),
        const _SettingItem(text: '对齐方式', child: _DesktopLyricsAlignmentRadio()),
        const _SettingItem(
          text: '歌词切换特效',
          child: _LyricsSwitchAnimateModeRadio(),
        ),
        _SettingSwitchItem(
          text: '使用双行显示',
          value: _desktopLyricsSettingController.showDoubleLine,
          onChanged: (val) =>
              _desktopLyricsSettingController.setShowDoubleLine(show: val),
        ),
        _SettingSwitchItem(
          text: '边框',
          value: _desktopLyricsSettingController.useStroke,
          onChanged: (val) =>
              _desktopLyricsSettingController.setStrokeEnable(enable: val),
        ),
        const _SettingItem(text: '边框颜色', child: _DesktopLyricsStrokeColor()),
        _SettingSwitchItem(
          text: '是否忽略鼠标事件',
          tooltip: '若开启，桌面歌词窗口将不接受任何鼠标事件',
          value: _desktopLyricsSettingController.isIgnoreMouseEvents,
          onChanged: (val) => _desktopLyricsSettingController
              .setIgnoreMouseEvents(isIgnore: val),
        ),
        _SettingSwitchItem(
          text: '竖排显示',
          value: _desktopLyricsSettingController.useVerticalDisplayMode,
          onChanged: (val) => _desktopLyricsSettingController
              .setUseVerticalDisplayMode(use: val),
        ),
      ],
    );
  }
}

/// 快捷键设置
class _HotkeysTab extends StatelessWidget {
  const _HotkeysTab();

  @override
  Widget build(BuildContext context) {
    return const _SettingsTabWrapper(
      children: [
        _SettingItem(text: '播放/暂停', child: _SetHotKeyToggleDialog()),
        _SettingItem(text: '上一首', child: _SetHotKeyPreviousDialog()),
        _SettingItem(text: '下一首', child: _SetHotKeyNextDialog()),
        _SettingItem(text: '切换全屏', child: _SetHotKeyFullScreenDialog()),
      ],
    );
  }
}

/// 关于设置
class _AboutTab extends StatelessWidget {
  final Future<PackageInfo> packageInfoFuture;

  const _AboutTab({required this.packageInfoFuture});

  Future<void> _launch(BuildContext context, String urlStr) async {
    try {
      await launchUrl(Uri.parse(urlStr));
    } catch (e) {
      debugPrint(e.toString());
      showSnackBar(
        title: "ERROR",
        msg: "跳转失败！",
        duration: const Duration(milliseconds: 3000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SettingsTabWrapper(
      children: [
        _SettingItem(
          text: '当前版本',
          child: SizedBox(
            width: 128,
            height: _setBtnHeight,
            child: Center(
              child: FutureBuilder<PackageInfo>(
                future: packageInfoFuture,
                builder: (context, snapshot) {
                  final style = generalTextStyle(
                    ctx: context,
                    size: 'lg',
                    color: Theme.of(context).colorScheme.primary,
                  );
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData) {
                      return Text(snapshot.data!.version, style: style);
                    }
                    return Text('获取版本号失败！', style: style);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
        _SettingSwitchItem(
          text: '自动检查更新',
          value: _settingController.useAutoUpdate,
          onChanged: (val) => _settingController.setUseAutoUpdate(value: val),
        ),
        const _SettingItem(text: '检查更新', child: _CheckVersion()),
        _SettingItem(
          text: '项目主页',
          child: CustomBtn(
            fn: () => _launch(context, _repoUrl),
            contentColor: theme.colorScheme.onPrimary,
            btnHeight: _setBtnHeight,
            btnWidth: 128,
            mainAxisAlignment: MainAxisAlignment.center,
            backgroundColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.surfaceContainer,
            icon: PhosphorIconsLight.code,
            label: "前往仓库",
          ),
        ),
        _SettingItem(
          text: '反馈',
          child: CustomBtn(
            fn: () => _launch(context, _reportUrl),
            contentColor: theme.colorScheme.onPrimary,
            btnHeight: _setBtnHeight,
            btnWidth: 128,
            mainAxisAlignment: MainAxisAlignment.center,
            backgroundColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.surfaceContainer,
            icon: PhosphorIconsLight.bug,
            label: "创建问题",
          ),
        ),
      ],
    );
  }
}
