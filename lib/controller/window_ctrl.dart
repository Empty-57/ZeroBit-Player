import 'package:flutter/foundation.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/desktop_lyrics_sever.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';

class WindowController with WindowListener {
  WindowController._();
  static final WindowController instance = WindowController._();

  final isMaximized = signal(false);
  final isFullScreen = signal(false);

  final DesktopLyricsSever _desktopLyricsSever = DesktopLyricsSever.instance;
  SettingController get _settingController => SettingController.instance;

  void init() {
    windowManager.addListener(this);
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
    final isFullScreen_ = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullScreen_);
    isFullScreen.value = !isFullScreen_;
  }

  Future<void> closeAndClean() async {
    try {
      await smtcClear();
      await _desktopLyricsSever.close();
    } catch (e, stackTrace) {
      LoggerUni.w("资源清理异常", e, stackTrace);
    } finally {
      windowManager.removeListener(this);
      isMaximized.dispose();
      isFullScreen.dispose();
      await windowManager.close();
    }
  }

  @override
  void onWindowMaximize() {
    isMaximized.value = true;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        true;
    _settingController.putScalableCache();
  }

  @override
  void onWindowUnmaximize() {
    isMaximized.value = false;
    _settingController.lastWindowInfo[SettingController
            .lastWindowIsMaximizedKey] =
        false;
    _settingController.putScalableCache();
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    LoggerUni.i('now size | width: ${size.width} height: ${size.height}');

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
    LoggerUni.i('now position | x: ${position.dx} y: ${position.dy}');

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
