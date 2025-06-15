import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/theme_manager.dart';
import '../tools/general_style.dart';
import '../getxController/setting_ctrl.dart';


final SettingController _settingController = Get.find<SettingController>();
final ThemeService _themeService = Get.find<ThemeService>();

var themeMode = _settingController.themeMode;


void toggleTheme() {
  themeMode.value =
      themeMode.value == 'dark' ? 'light' : 'dark';

  _settingController.putCache();

  _themeService.setThemeMode();
}

const double _contorllerBarHeight = 48;

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
  void onWindowClose() {
    windowManager.removeListener(this);
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

class WindowController extends StatelessWidget {
  const WindowController({super.key});

  @override
  Widget build(BuildContext context) {
    final windowListener = Get.put(_WindowListener());

    return Container(
      height: _contorllerBarHeight,
      padding: EdgeInsets.only(left: 16, top: 0, right: 4, bottom: 0),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: <Widget>[
          ControllerButton(
            icon: PhosphorIconsLight.caretLeft,
            fn: () {
              Get.back(id: 1);
            },
            tooltip: "返回",
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Icon(
                PhosphorIconsLight.code,
                color:
                    Theme.of(context).colorScheme.onSurface,
                size:
                    getIconSize(size: 'lg'),
              ),
              Text(
                'Player',
                style: generalTextStyle(ctx: context,size: 'sm'),
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

          Obx(
            () => ControllerButton(
              icon:
                  themeMode.value == 'dark'
                      ? PhosphorIconsLight.moon
                      : PhosphorIconsLight.sun,
              fn: toggleTheme,
              tooltip: themeMode.value == 'dark'?"暗色主题":"亮色主题",
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
              tooltip: windowListener._isMaximized.value?"还原":"最大化",
            ),
          ),

          ControllerButton(
            icon: PhosphorIconsLight.x,
            hoverColor:
                Theme.of(context).colorScheme.secondaryContainer,
            fn: windowListener.windowClose,
            tooltip: "退出",
          ),
        ],
      ),
    );
  }
}
