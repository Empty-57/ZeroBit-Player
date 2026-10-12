import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

import '../src/rust/api/trim_memory.dart' as rust_api;
import 'cover_lru_cache.dart';

class MemoryManager {
  const MemoryManager._();

  static Timer? _timer;
  static Timer? _loopTimer;
  static const int _baseDuration = 60;
  static const Duration _maxTrimWaitDuration = Duration(seconds: _baseDuration);
  static const Duration _maxLoopTrimCycleDuration = Duration(
    seconds: _baseDuration * 2,
  );
  static const int _trimLimitOnBlur = 150;
  static const int _trimLimitOnFocus = 230;
  static int _lastRss = 0;

  static double _toMB(int bytes) => (bytes / (1 << 20));

  static int get _currentRss => ProcessInfo.currentRss;

  static void printUsage([String label = 'Status']) {
    // 获取当前进程占用的物理内存
    final currentRss = _currentRss;
    final maxRss = ProcessInfo.maxRss;

    // 获取 ImageCache占用
    final imageCache = PaintingBinding.instance.imageCache;
    final imgBytes = imageCache.currentSizeBytes;
    final imgCount = imageCache.currentSize;

    // 计算相对上次打印的增减变化
    String deltaStr = '';
    if (_lastRss != 0) {
      final diff = currentRss - _lastRss;
      final sign = diff >= 0 ? '+' : '';
      deltaStr = ' (相比上次: $sign${_toMB(diff).toStringAsFixed(2)} MB)';
    }
    _lastRss = currentRss;

    final info =
        '''
[Memory Track: $label]
实际物理内存 (RSS) : ${_toMB(currentRss).toStringAsFixed(2)} MB $deltaStr
历史峰值内存       : ${_toMB(maxRss).toStringAsFixed(2)} MB
图片缓存           : ${_toMB(imgBytes).toStringAsFixed(2)} MB ($imgCount 张图片)''';
    LoggerUni.d(info);
  }

  /// 启动循环修剪 每 [_maxLoopTrimCycleDuration] s 尝试修剪一次
  static void startLoopTrim([String label = 'Status']) {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(_maxLoopTrimCycleDuration, (_) async {
      final limit = await windowManager.isFocused()
          ? _trimLimitOnFocus
          : _trimLimitOnBlur;
      if (_toMB(_currentRss) < limit) {
        printUsage('$label Trim Canceled');
        return;
      }
      unawaited(trimMemory(label));
    });
  }

  /// 会在 [_maxTrimWaitDuration] s 之后调用 [trimMemory] 方法
  static void startTrim([String label = 'Status']) {
    printUsage(label);
    _timer?.cancel();
    _timer = Timer(_maxTrimWaitDuration, () {
      _timer = null;
      if (_toMB(_currentRss) < _trimLimitOnBlur) {
        trimMemory(label);
      }
    });
  }

  /// 停止将要进行的 [trimMemory] 方法
  static void cancelTrim([String label = 'Status']) {
    printUsage(label);
    _timer?.cancel();
    _timer = null;
  }

  /// 立即执行一次内存裁剪
  static Future<void> trimMemory([String label = 'Status']) async {
    // 通知框架进行清理
    WidgetsBinding.instance.handleMemoryPressure();

    // 清空位图缓存
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();

    CoverLRUCache.clear();
    ImageFilterCache.clear();

    // 强制修剪操作系统的工作集物理内存
    try {
      await rust_api.trimMemory();
    } catch (e, s) {
      LoggerUni.e('强制修剪工作集内存失败', e, s);
    }
    printUsage('$label After Trim');
  }
}
