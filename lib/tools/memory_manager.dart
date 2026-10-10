import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/tools/paint_cache.dart';
import '../src/rust/api/trim_memory.dart' as rust_api;
import 'cover_lru_cache.dart';

class MemoryManager {
  const MemoryManager._();

  static Timer? _timer;
  static final Duration _maxWaitDuration = Duration(milliseconds: 30000);
  static int _lastRss = 0;

  static void printUsage([String label = 'Status']) {
    // 获取当前进程占用的物理内存
    final currentRss = ProcessInfo.currentRss;
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
      deltaStr =
          ' (相比上次: $sign${(diff / (1024 * 1024)).toStringAsFixed(2)} MB)';
    }
    _lastRss = currentRss;

    String toMB(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);

    final info =
        '''
[Memory Track: $label]
实际物理内存 (RSS) : ${toMB(currentRss)} MB $deltaStr
历史峰值内存       : ${toMB(maxRss)} MB
图片缓存           : ${toMB(imgBytes)} MB ($imgCount 张图片)''';
    LoggerUni.d(info);
  }

  /// 会在 [_maxWaitDuration]ms 之后调用 [trimMemory] 方法
  static void startTrim([String label = 'Status']) {
    printUsage(label);
    _timer?.cancel();
    _timer = Timer(_maxWaitDuration, () {
      _timer = null;
      trimMemory(label);
    });
  }

  /// 停止将要进行的 [trimMemory] 方法
  static void cancelTrim([String label = 'Status']) {
    printUsage(label);
    _timer?.cancel();
    _timer = null;
  }

  /// 立即执行一次内存裁剪
  static void trimMemory([String label = 'Status']) async {
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
      LoggerUni.e('强制修建工作集内存失败', e, s);
    }
    printUsage('$label After Trim');
  }
}
