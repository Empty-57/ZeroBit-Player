import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/desktop_lyrics_sever.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:window_manager/window_manager.dart';

class MyWindowListener extends GetxController with WindowListener {
  final isMaximized = false.obs;
  final isFullScreen = false.obs;
  final DesktopLyricsSever _desktopLyricsSever = Get.find<DesktopLyricsSever>();
  final SettingController _settingController = Get.find<SettingController>();

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
      isMaximized.value = false;
    } else {
      await windowManager.maximize();
      isMaximized.value = true;
    }
  }

  void toggleFullScreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullScreen);
    this.isFullScreen.value = !isFullScreen;
  }

  @override
  void onWindowClose() async {
    await smtcClear();
    await _desktopLyricsSever.close();
    windowManager.removeListener(this);
    super.onClose();
  }

  @override
  void onWindowMaximize() {
    isMaximized.value = true;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        isMaximized.value;
    _settingController.putScalableCache();
  }

  @override
  void onWindowUnmaximize() {
    isMaximized.value = false;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        isMaximized.value;
    _settingController.putScalableCache();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    debugPrint('now size | width: ${size.width} height: ${size.height}');

    var windowInfoSize =
        _settingController.lastWindowInfo[SettingController.lastWindowSizeKey]
            as List<double>?;
    if (windowInfoSize != null && windowInfoSize.isNotEmpty) {
      windowInfoSize = [size.width, size.height];

      _settingController.lastWindowInfo[SettingController.lastWindowSizeKey] =
          windowInfoSize;
      _settingController.putScalableCache();
    }
  }

  @override
  void onWindowMoved() async {
    final position = await windowManager.getPosition();
    debugPrint('now position | x: ${position.dx} y: ${position.dy}');

    var windowInfoPosition =
        _settingController.lastWindowInfo[SettingController
                .lastWindowPositonKey]
            as List<double>?;
    if (windowInfoPosition != null && windowInfoPosition.isNotEmpty) {
      windowInfoPosition = [position.dx, position.dy];

      _settingController.lastWindowInfo[SettingController
              .lastWindowPositonKey] =
          windowInfoPosition;
      _settingController.putScalableCache();
    }
  }
}
