import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/theme_manager.dart';
import '../desktop_lyrics_sever.dart';
import '../field/tag_suffix.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';
import 'get_snack_bar.dart';

final SettingController _settingController = Get.find<SettingController>();
final ThemeService _themeService = Get.find<ThemeService>();
final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();
final AudioController _audioController = Get.find<AudioController>();

final DesktopLyricsSever _desktopLyricsSever = Get.find<DesktopLyricsSever>();

final themeMode = _settingController.themeMode;

const double _controllerBarHeight = 48;
const double _itemHeight = 64;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _logoSize = 24.0;
const int _coverSmallRenderSize = 150;

class _WindowListener extends GetxController with WindowListener {
  final _isMaximized = false.obs;
  final _isFullScreen = false.obs;

  @override
  void onInit() {
    windowManager.addListener(this);
    super.onInit();
  }

  @override
  void onClose() {
    windowManager.removeListener(this);
    super.onClose();
  }

  void toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      _isMaximized.value = false;
    } else {
      await windowManager.maximize();
      _isMaximized.value = true;
    }
  }

  void toggleFullScreen() async {
    if (await windowManager.isFullScreen()) {
      await windowManager.setFullScreen(false);
      _isFullScreen.value = false;
    } else {
      await windowManager.setFullScreen(true);
      _isFullScreen.value = true;
    }
  }

  @override
  void onWindowClose() async {
    windowManager.removeListener(this);
    super.onClose();
  }

  @override
  void onWindowMaximize() {
    _isMaximized.value = true;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        _isMaximized.value;
    _settingController.putScalableCache();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized.value = false;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        _isMaximized.value;
    _settingController.putScalableCache();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    debugPrint('now size | width: ${size.width} height: ${size.height}');

    final windowInfoSize =
        _settingController.lastWindowInfo[SettingController.lastWindowSizeKey]
            as List<double>?;
    if (windowInfoSize != null && windowInfoSize.isNotEmpty) {
      windowInfoSize[SettingController.lastWindowInfoWidthAndDx] = size.width;
      windowInfoSize[SettingController.lastWindowInfoHeightAndDy] = size.height;

      _settingController.lastWindowInfo[SettingController.lastWindowSizeKey] =
          windowInfoSize;
      _settingController.putScalableCache();
    }
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    debugPrint('now position | x: ${position.dx} y: ${position.dy}');

    final windowInfoPosition =
        _settingController.lastWindowInfo[SettingController
                .lastWindowPositonKey]
            as List<double>?;
    if (windowInfoPosition != null && windowInfoPosition.isNotEmpty) {
      windowInfoPosition[SettingController.lastWindowInfoWidthAndDx] =
          position.dx;
      windowInfoPosition[SettingController.lastWindowInfoHeightAndDy] =
          position.dy;

      _settingController.lastWindowInfo[SettingController
              .lastWindowPositonKey] =
          windowInfoPosition;
      _settingController.putScalableCache();
    }
  }
}

class _SearchDialog extends StatelessWidget {
  const _SearchDialog();
  @override
  Widget build(BuildContext context) {
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    return _ControllerButton(
      icon: PhosphorIconsLight.magnifyingGlass,
      fn: () {
        _musicCacheController.searchResult.clear();
        _musicCacheController.searchText.value = '';
        final searchCtrl = TextEditingController();
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("搜索"),
              titleTextStyle: generalTextStyle(
                ctx: context,
                size: 'xl',
                weight: FontWeight.w600,
              ),

              shape: RoundedRectangleBorder(borderRadius: _borderRadius),
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
                      TextField(
                        autofocus: true,
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '搜索',
                        ),
                        onChanged: (String text) {
                          _musicCacheController.searchText.value = text;
                        },
                      ),
                      Expanded(
                        flex: 1,
                        child: Obx(
                          () => ListView.builder(
                            itemCount:
                                _musicCacheController.searchResult.length,
                            itemExtent: _itemHeight,
                            cacheExtent: _itemHeight * 1,
                            padding: EdgeInsets.only(bottom: _itemHeight * 2),
                            itemBuilder: (context, index) {
                              final items =
                                  _musicCacheController.searchResult[index];
                              final menuController = MenuController();
                              return TextButton(
                                onPressed: () {
                                  _audioController.searchInsert(
                                    metadata: items,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: _borderRadius,
                                  ),
                                ),
                                child: SizedBox.expand(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              items.title,
                                              style: titleStyle,
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            Text(
                                              "${items.artist} - ${items.album}",
                                              style: subStyle,
                                              softWrap: true,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      _ControllerButton(
                                        icon:
                                            PhosphorIconsLight
                                                .arrowBendDownRight,
                                        tooltip: '添加到下一首',
                                        fn: () {
                                          _audioController.insertNext(
                                            metadata: items,
                                          );
                                        },
                                      ),
                                      MenuAnchor(
                                        menuChildren:
                                            _audioController.allUserKey.map((
                                              v,
                                            ) {
                                              return MenuItemButton(
                                                onPressed: () {
                                                  _audioController
                                                      .addToAudioList(
                                                        metadata: items,
                                                        userKey: v,
                                                      );
                                                },
                                                child: Center(
                                                  child: Text(
                                                    v.split(
                                                      TagSuffix.playList,
                                                    )[0],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        controller: menuController,
                                        consumeOutsideTap: true,
                                        style: MenuStyle(
                                          maximumSize: WidgetStatePropertyAll(
                                            Size.fromHeight(context.height / 2),
                                          ),
                                        ),
                                        child: _ControllerButton(
                                          icon: PhosphorIconsLight.plus,
                                          tooltip: '添加到歌单',
                                          fn: () {
                                            if (_audioController
                                                .allUserKey
                                                .isEmpty) {
                                              showSnackBar(
                                                title: "WARNING",
                                                msg: "还未创建任何歌单",
                                                duration: Duration(
                                                  milliseconds: 1500,
                                                ),
                                              );
                                              return;
                                            }

                                            if (menuController.isOpen) {
                                              menuController.close();
                                            } else {
                                              menuController.open();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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
      tooltip: "搜索",
    );
  }
}

class _ControllerButton extends StatelessWidget {
  final IconData icon;
  final Color? hoverColor;
  final VoidCallback fn;
  final String? tooltip;

  const _ControllerButton({
    super.key,
    required this.icon,
    this.hoverColor,
    required this.fn,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: Theme.of(context).colorScheme.onSurface,
      tooltip: tooltip,
      iconSize: getIconSize(size: 'lg'),
      hoverColor: hoverColor,
      style: ButtonStyle(
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      onPressed: () {
        fn();
      },
    );
  }
}

class WindowControllerBar extends StatelessWidget {
  final bool? isNestedRoute;
  final bool? showLogo;
  final bool? useCaretDown;
  final bool? useSearch;

  const WindowControllerBar({
    super.key,
    this.isNestedRoute = true,
    this.showLogo = true,
    this.useCaretDown = false,
    this.useSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    final windowListener = Get.put(_WindowListener());

    return Container(
      height: _controllerBarHeight,
      padding: EdgeInsets.only(left: 16, top: 0, right: 4, bottom: 0),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 0,
        children: <Widget>[
          Padding(padding: EdgeInsets.only(right: 8),child: _ControllerButton(
            icon:
                useCaretDown!
                    ? PhosphorIconsLight.caretDown
                    : PhosphorIconsLight.caretLeft,
            fn: () {
              Get.back(id: isNestedRoute! ? 1 : null);
            },
            tooltip: "返回",
          ),),
          if (showLogo!)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 4,
              children: [
                ClipRRect(
                  borderRadius: _borderRadius,
                  child: Image.asset(
                    r'assets/app_icon.ico',
                    width: _logoSize,
                    height: _logoSize,
                    fit: BoxFit.cover,
                    cacheWidth: _coverSmallRenderSize,
                    cacheHeight: _coverSmallRenderSize,
                    gaplessPlayback: true, // 防止图片突然闪烁
                  ),
                ),
                Text(
                  'ZeroBit Player',
                  style: generalTextStyle(ctx: context, size: 'sm'),
                ),
              ],
            ),

          Expanded(
            flex: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              onDoubleTap: () => windowListener.toggleMaximize(),
              child: Container(),
            ),
          ),

          if (useSearch!) const _SearchDialog(),

          Padding(padding: EdgeInsets.only(right: 8,left: 8),child: Obx(
            () => _ControllerButton(
              icon:
                  _settingController.themeMode.value == 'dark'
                      ? PhosphorIconsLight.moon
                      : PhosphorIconsLight.sun,
              fn: _themeService.setThemeMode,
              tooltip:
                  _settingController.themeMode.value == 'dark'
                      ? "暗色主题"
                      : "亮色主题",
            ),
          ),),

          Obx(
            () => Visibility(
              visible: !windowListener._isFullScreen.value,
              child: Padding(padding: EdgeInsets.only(right: 8),child: _ControllerButton(
                icon: PhosphorIconsLight.minus,
                fn: () async {
                  await windowManager.minimize();
                },
                tooltip: "最小化",
              ),),
            ),
          ),

          Obx(
            () => Visibility(
              visible: !windowListener._isFullScreen.value,
              child: _ControllerButton(
                icon:
                    windowListener._isMaximized.value
                        ? PhosphorIconsLight.cornersIn
                        : PhosphorIconsLight.cornersOut,
                fn: windowListener.toggleMaximize,
                tooltip: windowListener._isMaximized.value ? "还原" : "最大化",
              ),
            ),
          ),

          Obx(
            () => Padding(padding: EdgeInsets.only(right: 8,left:windowListener._isFullScreen.value? 0: 8),child: _ControllerButton(
              icon:
                  windowListener._isFullScreen.value
                      ? PhosphorIconsLight.arrowsInSimple
                      : PhosphorIconsLight.arrowsOutSimple,
              fn: windowListener.toggleFullScreen,
              tooltip: windowListener._isFullScreen.value ? "还原" : "全屏",
            ),),
          ),

          _ControllerButton(
            icon: PhosphorIconsLight.x,
            hoverColor: Colors.red,
            fn: () async {
              await smtcClear();
              await _desktopLyricsSever.close();
              await windowManager.close();
            },
            tooltip: "退出",
          ),
        ],
      ),
    );
  }
}
