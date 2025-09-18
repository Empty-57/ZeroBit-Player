import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobit_player/custom_widgets/custom_button.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/src/rust/api/get_fonts.dart';
import '../components/get_snack_bar.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';

final SettingController _settingController = Get.find<SettingController>();
final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

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
                              _musicCacheController.currentScanPath.value == ''
                                  ? false
                                  : true,
                          child: const Center(
                            child: CircularProgressIndicator(),
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
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
                  width: context.width / 2,
                  height: context.height / 2,
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
}

class _LrcFontSizeDropMenu extends StatelessWidget {
  const _LrcFontSizeDropMenu();

  @override
  Widget build(BuildContext context) {
    const double btnW = 108;

    final menuController = MenuController();
    final fontSizeList =
        List.generate(21, (index) => index + 16).map((i) {
          return CustomBtn(
            fn: () {
              _settingController.lrcFontSize.value = i;
              _settingController.putCache(isSaveFolders: false);
              menuController.close();
            },
            btnWidth: btnW,
            btnHeight: _setBtnHeight,
            label: i.toString(),
            mainAxisAlignment: MainAxisAlignment.center,
            backgroundColor: Colors.transparent,
          );
        }).toList();

    return MenuAnchor(
      menuChildren: fontSizeList,
      controller: menuController,
      consumeOutsideTap: true,
      style: MenuStyle(
        maximumSize: WidgetStatePropertyAll(
          Size.fromHeight(context.height / 2),
        ),
      ),
      child: Obx(
        () => CustomBtn(
          fn: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
          label: '${_settingController.lrcFontSize.value}',
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

class _LrcFontWeightDropMenu extends StatelessWidget {
  const _LrcFontWeightDropMenu();

  @override
  Widget build(BuildContext context) {
    const double btnW = 108;

    final menuController = MenuController();
    final fontSizeList =
        List.generate(9, (index) => index).map((i) {
          return CustomBtn(
            fn: () {
              _settingController.lrcFontWeight.value = i;
              _settingController.putCache(isSaveFolders: false);
              menuController.close();
            },
            btnWidth: btnW,
            btnHeight: _setBtnHeight,
            label: (i * 100 + 100).toString(),
            mainAxisAlignment: MainAxisAlignment.center,
            backgroundColor: Colors.transparent,
          );
        }).toList();

    return MenuAnchor(
      menuChildren: fontSizeList,
      controller: menuController,
      consumeOutsideTap: true,
      style: MenuStyle(
        maximumSize: WidgetStatePropertyAll(
          Size.fromHeight(context.height / 2),
        ),
      ),
      child: Obx(
        () => CustomBtn(
          fn: () {
            if (menuController.isOpen) {
              menuController.close();
            } else {
              menuController.open();
            }
          },
          label:
              (_settingController.lrcFontWeight.value * 100 + 100).toString(),
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
                (latestVer[0] == localVer[0]&&latestVer[1] > localVer[1]) ||
                (latestVer[0] == localVer[0]&&latestVer[1] == localVer[1]&&latestVer[2] > localVer[2]) )
            {
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

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  const _SetDivider(title: '常规'),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '歌曲文件夹',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _FolderManagerDialog(),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'API源',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _ApiDropMenu(),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '自动下载选择的歌词',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: Obx(
                          () => Switch(
                            value: _settingController.autoDownloadLrc.value,
                            trackColor: switchTrackColor,
                            thumbColor: WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                            onChanged: (bool value) {
                              _settingController.autoDownloadLrc.value = value;
                              _settingController.putCache();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const _SetDivider(title: '个性化'),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '主题色',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _ColorPicker(),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '动态主题色',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
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
                              _settingController.dynamicThemeColor.value =
                                  value;
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
                      Text(
                        '字体',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _FontFamilyDialog(),
                    ],
                  ),

                  const _SetDivider(title: '歌词样式'),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '字号',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _LrcFontSizeDropMenu(),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '字重',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _LrcFontWeightDropMenu(),
                    ],
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '歌词行模糊',
                          style: generalTextStyle(ctx: context, size: 'lg'),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: Obx(
                            () => Switch(
                              value: _settingController.useBlur.value,
                              trackColor: switchTrackColor,
                              thumbColor: WidgetStatePropertyAll(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                              onChanged: (bool value) {
                                _settingController.useBlur.value = value;
                                _settingController.putCache();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const _SetDivider(title: '关于'),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '当前版本',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      SizedBox(
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
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '检查更新',
                        style: generalTextStyle(ctx: context, size: 'lg'),
                      ),
                      const _CheckVersion(),
                    ],
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
