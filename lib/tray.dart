import 'dart:io';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';

class Tray extends GetxController with TrayListener {
  AudioController get _audioController => Get.find<AudioController>();

  @override
  void onInit() async {
    super.onInit();
    await _init();
    await _updateTrayMenu();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconRightMouseDown() async {
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
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'toggle',
          label:
              _audioController.currentState.value == AudioState.playing
                  ? '暂停'
                  : '播放',
          onClick: (_) async {
            await _audioController.audioToggle();
            await _updateTrayMenu();
          },
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
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出ZeroBit Player',
          onClick: (_) async => await windowManager.close(),
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> _init() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );
    await trayManager.setToolTip("ZeroBit Player");
    trayManager.addListener(this);
  }
}
