import 'dart:io';
import 'package:flutter/services.dart';

enum TaskbarButtonAction { prev, toggle, next }

class WindowsTaskbarThumbnail {
  static const MethodChannel _channel = MethodChannel(
    'com.app.windows_taskbar',
  );

  static void init({
    required Function(TaskbarButtonAction action) onButtonClick,
  }) {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onButtonClick') {
        final actionStr = call.arguments as String?;
        switch (actionStr) {
          case 'prev':
            onButtonClick(TaskbarButtonAction.prev);
            break;
          case 'toggle':
            onButtonClick(TaskbarButtonAction.toggle);
            break;
          case 'next':
            onButtonClick(TaskbarButtonAction.next);
            break;
        }
      }
    });
  }

  /// 更新按钮状态 (isPlaying 用于切换播放/暂停图标, visible 控制显示/隐藏)
  static Future<void> setButtons({
    required bool isPlaying,
    bool visible = true,
  }) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod('setButtons', {
      'isPlaying': isPlaying,
      'visible': visible,
    });
  }

  /// 设置自定义任务栏缩略图
  static Future<void> setThumbnail(Uint8List imageBytes) async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod('setThumbnail', {'bytes': imageBytes});
  }

  /// 还原为系统默认缩略图
  static Future<void> resetThumbnail() async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod('resetThumbnail');
  }

  /// 还原所有状态
  static Future<void> resetAll() async {
    if (!Platform.isWindows) return;
    await _channel.invokeMethod('resetAll');
  }
}
