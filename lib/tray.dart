import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/window_ctrl.dart';

class TrayManagerService with TrayListener {
  TrayManagerService._();
  static final TrayManagerService instance = TrayManagerService._();

  AudioController get _audioController => AudioController.instance;
  SettingController get _settingController => SettingController.instance;
  WindowController get _windowListener => WindowController.instance;

  Future<void> init() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );
      await trayManager.setToolTip("ZeroBit Player");
      trayManager.addListener(this);

      await _updateTrayMenu();
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
  }

  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await _updateTrayMenu();
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseDown() async {
    if (await windowManager.isVisible()) {
      await windowManager.focus();
    } else {
      await windowManager.show();
    }
  }

  // 更新Menu
  Future<void> _updateTrayMenu() async {
    final Menu menu = Menu(
      items: [
        MenuItem(
          key: 'toggle',
          label: _audioController.currentState.value == AudioState.playing
              ? '暂停'
              : '播放',
          onClick: (_) async => await _audioController.audioToggle(),
        ),
        MenuItem(
          key: 'last',
          label: '上一首',
          onClick: (_) async => await _audioController.audioToPrevious(),
        ),
        MenuItem(
          key: 'next',
          label: '下一首',
          onClick: (_) async => await _audioController.audioToNext(),
        ),
        MenuItem(
          key: 'desktopLyric',
          label: _settingController.showDesktopLyrics.value
              ? '关闭桌面歌词'
              : '显示桌面歌词',
          onClick: (_) async {
            _settingController.setShowDesktopLyrics();
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出ZeroBit Player',
          onClick: (_) async {
            await destroy();
            await _windowListener.closeAndClean();
          },
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }
}
