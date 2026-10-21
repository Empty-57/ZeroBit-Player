import 'dart:async';

import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/features/lyrics/server/desktop_lyrics_server.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';

import '../utils/logger.dart';
import '../utils/memory_manager.dart';

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

  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
      isMaximized.value = false;
    } else {
      await windowManager.maximize();
      isMaximized.value = true;
    }
  }

  Future<void> toggleFullScreen() async {
    final isFullScreen_ = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!isFullScreen_);
    isFullScreen.value = !isFullScreen_;
  }

  Future<void> closeAndClean() async {
    // void onWindowClose() 不可用
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
  void onWindowBlur() {
    MemoryManager.startDisableTicker();
    MemoryManager.startTrim('onWindowBlur');
  }

  @override
  void onWindowFocus() {
    MemoryManager.cancelDisableTicker();
    MemoryManager.cancelTrim('onWindowFocus');
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
  Future<void> onWindowResized() async {
    final size = await windowManager.getSize();
    LoggerUni.d('now size | width: ${size.width} height: ${size.height}');

    var windowInfoSize =
        _settingController.lastWindowInfo[SettingController.lastWindowSizeKey]
            as List<double>?;
    if (windowInfoSize != null && windowInfoSize.isNotEmpty) {
      windowInfoSize = [size.width, size.height];

      _settingController.lastWindowInfo[SettingController.lastWindowSizeKey] =
          windowInfoSize;
      unawaited(_settingController.putScalableCache());
    }
  }

  @override
  Future<void> onWindowMoved() async {
    final position = await windowManager.getPosition();
    LoggerUni.d('now position | x: ${position.dx} y: ${position.dy}');

    var windowInfoPosition =
        _settingController.lastWindowInfo[SettingController
                .lastWindowPositonKey]
            as List<double>?;
    if (windowInfoPosition != null && windowInfoPosition.isNotEmpty) {
      windowInfoPosition = [position.dx, position.dy];

      _settingController.lastWindowInfo[SettingController
              .lastWindowPositonKey] =
          windowInfoPosition;
      unawaited(_settingController.putScalableCache());
    }
  }
}
