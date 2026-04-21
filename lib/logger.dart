import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FileLogger {
  static IOSink? _logSink;
  static String? _currentLogDate;

  /// 初始化日志文件
  static Future<void> init() async {
    try {
      final currentDir = p.dirname(Platform.resolvedExecutable);
      final logDirectory = Directory(p.join(currentDir, 'logs'));

      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      _openLogFileForToday(logDirectory.path);
    } catch (e) {
      debugPrint('日志系统初始化失败: $e');
    }
  }

  /// 按天生成日志文件 (例: log_2026-04-22.txt)
  static void _openLogFileForToday(String dirPath) {
    final now = DateTime.now();
    final dateString =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (_currentLogDate == dateString && _logSink != null) return;

    _logSink?.close(); // 关闭旧日期的文件流并更新日期
    _currentLogDate = dateString;

    final logFile = File(p.join(dirPath, 'log_$dateString.txt'));

    // 使用 IOSink 以追加模式 (append) 写入
    _logSink = logFile.openWrite(mode: FileMode.append);
    _logSink?.writeln('\n=======================================');
    _logSink?.writeln('====== APP LAUNCH: ${now.toIso8601String()} ======');
    _logSink?.writeln('=======================================\n');
  }

  /// 写入错误日志
  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('[$timeString] [ERROR] $message');

    if (error != null) {
      buffer.writeln('Exception: $error');
    }
    if (stackTrace != null) {
      buffer.writeln('StackTrace:\n$stackTrace');
    }
    buffer.writeln('--------------------------------------------------');
    debugPrint(buffer.toString());

    // 写入本地文件
    _logSink?.writeln(buffer.toString());
  }

  /// 写入普通信息日志
  static void logInfo(String message) {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final logMsg = '[$timeString] [INFO] $message';

    debugPrint(logMsg);
    _logSink?.writeln(logMsg);
    _logSink?.writeln('--------------------------------------------------');
  }
}
