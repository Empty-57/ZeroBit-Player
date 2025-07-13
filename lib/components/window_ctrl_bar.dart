import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/theme_manager.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';

final SettingController _settingController = Get.find<SettingController>();
final ThemeService _themeService = Get.find<ThemeService>();
final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();
final AudioController _audioController = Get.find<AudioController>();

final themeMode = _settingController.themeMode;

const double _controllerBarHeight = 48;
const double _itemHeight = 64;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class _WindowListener extends GetxController with WindowListener {
  final _isMaximized = false.obs;

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

  void windowClose() async => await windowManager.close();

  void windowMinimize() async => await windowManager.minimize();

  void toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      _isMaximized.value = false;
    } else {
      await windowManager.maximize();
      _isMaximized.value = true;
    }
  }

  @override
  void onWindowClose() async {
    windowManager.removeListener(this);
    await smtcClear();
    super.onClose();
  }

  @override
  void onWindowEvent(String eventName) {
    switch (eventName) {
      case 'maximize':
        _isMaximized.value = true;
        break;
      case 'unmaximize':
        _isMaximized.value = false;
        break;
    }
  }
}

class _SearchDialog extends StatelessWidget {
  const _SearchDialog();
  @override
  Widget build(BuildContext context) {
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    return ControllerButton(
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
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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

class ControllerButton extends StatelessWidget {
  final IconData icon;
  final Color? hoverColor;
  final VoidCallback fn;
  final String? tooltip;

  const ControllerButton({
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
        spacing: 8,
        children: <Widget>[
          ControllerButton(
            icon:
                useCaretDown!
                    ? PhosphorIconsLight.caretDown
                    : PhosphorIconsLight.caretLeft,
            fn: () {
              Get.back(id: isNestedRoute! ? 1 : null);
            },
            tooltip: "返回",
          ),
          if (showLogo!)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                Icon(
                  PhosphorIconsLight.code,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: getIconSize(size: 'lg'),
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
              child: Container(),
            ),
          ),

          if (useSearch!) const _SearchDialog(),

          Obx(
            () => ControllerButton(
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
          ),

          ControllerButton(
            icon: PhosphorIconsLight.minus,
            fn: windowListener.windowMinimize,
            tooltip: "最小化",
          ),

          Obx(
            () => ControllerButton(
              icon:
                  windowListener._isMaximized.value
                      ? PhosphorIconsLight.cornersIn
                      : PhosphorIconsLight.cornersOut,
              fn: windowListener.toggleMaximize,
              tooltip: windowListener._isMaximized.value ? "还原" : "最大化",
            ),
          ),

          ControllerButton(
            icon: PhosphorIconsLight.x,
            hoverColor: Theme.of(context).colorScheme.errorContainer,
            fn: () {
              windowListener.windowClose();
            },
            tooltip: "退出",
          ),
        ],
      ),
    );
  }
}
