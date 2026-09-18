import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/controller/window_ctrl.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

import 'get_snack_bar.dart';

const double _controllerBarHeight = 48;
const double _itemHeight = 64;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _logoSize = 24.0;
const int _coverSmallRenderSize = 150;

class _SearchDialog extends StatelessWidget {
  final AudioController ctrl;
  final MusicCacheController cacheCtrl;

  const _SearchDialog({required this.ctrl, required this.cacheCtrl});

  @override
  Widget build(BuildContext context) {
    return _ControllerButton(
      icon: PhosphorIconsLight.magnifyingGlass,
      fn: () {
        showDialog(
          barrierDismissible: true,
          context: context,
          builder: (BuildContext context) {
            return _SearchDialogContent(ctrl: ctrl, cacheCtrl: cacheCtrl);
          },
        );
      },
      tooltip: "搜索",
    );
  }
}

class _SearchDialogContent extends StatefulWidget {
  final AudioController ctrl;
  final MusicCacheController cacheCtrl;

  const _SearchDialogContent({required this.ctrl, required this.cacheCtrl});

  @override
  State<_SearchDialogContent> createState() => _SearchDialogContentState();
}

class _SearchDialogContentState extends State<_SearchDialogContent> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    widget.cacheCtrl.resetSearch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserPlayListController userPlayListController =
        UserPlayListController.instance;
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;

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
          width: width / 2,
          height: height / 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              TextField(
                autofocus: true,
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '搜索',
                ),
                onChanged: widget.cacheCtrl.onInputChanged,
              ),
              Expanded(
                flex: 1,
                child: SignalBuilder(
                  builder: (context) => ListView.builder(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(
                      _itemHeight * 1,
                    ),
                    itemCount: widget.cacheCtrl.searchResult.value.length,
                    itemExtent: _itemHeight,
                    padding: EdgeInsets.only(bottom: _itemHeight * 2),
                    itemBuilder: (context, index) {
                      final items = widget.cacheCtrl.searchResult.value[index];
                      final menuController = MenuController();
                      return TextButton(
                        onPressed: () {
                          widget.ctrl.searchInsert(metadata: items);
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: _borderRadius,
                          ),
                        ),
                        child: SizedBox.expand(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                icon: PhosphorIconsLight.arrowBendDownRight,
                                tooltip: '添加到下一首',
                                fn: () {
                                  widget.ctrl.insertNext(metadata: items);
                                },
                              ),
                              MenuAnchor(
                                menuChildren: userPlayListController.allUserKey
                                    .map((v) {
                                      return MenuItemButton(
                                        onPressed: () {
                                          userPlayListController.addToAudioList(
                                            metadata: items,
                                            userKey: v,
                                          );
                                        },
                                        child: Center(
                                          child: Text(v.split('_')[0]),
                                        ),
                                      );
                                    })
                                    .toList(),
                                controller: menuController,
                                consumeOutsideTap: true,
                                style: MenuStyle(
                                  maximumSize: WidgetStatePropertyAll(
                                    Size.fromHeight(height / 2),
                                  ),
                                ),
                                child: _ControllerButton(
                                  icon: PhosphorIconsLight.plus,
                                  tooltip: '添加到歌单',
                                  fn: () {
                                    if (userPlayListController
                                        .allUserKey
                                        .isEmpty) {
                                      showSnackBar(
                                        title: "WARNING",
                                        msg: "还未创建任何歌单",
                                        duration: const Duration(
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
  }
}

class _ControllerButton extends StatelessWidget {
  final IconData icon;
  final Color? hoverColor;
  final VoidCallback fn;
  final String? tooltip;
  final bool onlyDarkMode;

  const _ControllerButton({
    required this.icon,
    this.hoverColor,
    required this.fn,
    this.tooltip,
    this.onlyDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: onlyDarkMode
          ? ThemeService.instance.darkTheme.colorScheme.onSurface
          : Theme.of(context).colorScheme.onSurface,
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
  final bool isNestedRoute;
  final bool showLogo;
  final bool useCaretDown;
  final bool useSearch;
  final bool useThemeSwitch;
  final bool onlyDarkMode;
  final bool useBlur;

  const WindowControllerBar({
    super.key,
    this.isNestedRoute = true,
    this.showLogo = true,
    this.useCaretDown = false,
    this.useSearch = true,
    this.useThemeSwitch = true,
    this.onlyDarkMode = false,
    this.useBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final windowController = WindowController.instance;
    final AudioController audioController = AudioController.instance;
    final MusicCacheController musicCacheController =
        MusicCacheController.instance;
    final SettingController settingController = SettingController.instance;

    final content = Container(
      height: _controllerBarHeight,
      padding: EdgeInsets.only(left: 16, top: 0, right: 4, bottom: 0),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withValues(alpha: useBlur ? 0.4 : 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 0,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: _ControllerButton(
              onlyDarkMode: onlyDarkMode,
              icon: useCaretDown
                  ? PhosphorIconsLight.caretDown
                  : PhosphorIconsLight.caretLeft,
              fn: () {
                if (context.canPop()) {
                  context.pop();
                }
              },
              tooltip: "返回",
            ),
          ),
          if (showLogo)
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
              onDoubleTap: () => windowController.toggleMaximize(),
              child: Container(),
            ),
          ),

          if (useSearch)
            _SearchDialog(
              ctrl: audioController,
              cacheCtrl: musicCacheController,
            ),

          if (useThemeSwitch)
            Padding(
              padding: EdgeInsets.only(right: 8, left: 8),
              child: SignalBuilder(
                builder: (context) => _ControllerButton(
                  onlyDarkMode: onlyDarkMode,
                  icon: settingController.themeMode.value == 'dark'
                      ? PhosphorIconsLight.moon
                      : PhosphorIconsLight.sun,
                  fn: ThemeService.instance.setThemeMode,
                  tooltip: settingController.themeMode.value == 'dark'
                      ? "暗色主题"
                      : "亮色主题",
                ),
              ),
            ),

          SignalBuilder(
            builder: (context) => Visibility(
              visible: !windowController.isFullScreen.value,
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: _ControllerButton(
                  onlyDarkMode: onlyDarkMode,
                  icon: PhosphorIconsLight.minus,
                  fn: () async {
                    await windowManager.minimize();
                  },
                  tooltip: "最小化",
                ),
              ),
            ),
          ),

          SignalBuilder(
            builder: (context) => Visibility(
              visible: !windowController.isFullScreen.value,
              child: _ControllerButton(
                onlyDarkMode: onlyDarkMode,
                icon: windowController.isMaximized.value
                    ? PhosphorIconsLight.cornersIn
                    : PhosphorIconsLight.cornersOut,
                fn: windowController.toggleMaximize,
                tooltip: windowController.isMaximized.value ? "还原" : "最大化",
              ),
            ),
          ),

          SignalBuilder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                right: 8,
                left: windowController.isFullScreen.value ? 0 : 8,
              ),
              child: _ControllerButton(
                onlyDarkMode: onlyDarkMode,
                icon: windowController.isFullScreen.value
                    ? PhosphorIconsLight.arrowsInSimple
                    : PhosphorIconsLight.arrowsOutSimple,
                fn: windowController.toggleFullScreen,
                tooltip: windowController.isFullScreen.value ? "还原" : "全屏",
              ),
            ),
          ),

          _ControllerButton(
            onlyDarkMode: onlyDarkMode,
            icon: PhosphorIconsLight.x,
            hoverColor: Colors.red,
            fn: () async {
              if (settingController.close2Tray.value) {
                await windowManager.hide();
                return;
              }
              await windowController.closeAndClean();
            },
            tooltip: "退出",
          ),
        ],
      ),
    );

    return useBlur
        ? ClipRect(
            child: SignalBuilder(
              builder: (context) => BackdropFilter(
                enabled: settingController.backgroundImagePath.value.isNotEmpty,
                filter: ImageFilterCache.imageFilter(sigma: 16),
                child: content,
              ),
            ),
          )
        : content;
  }
}
