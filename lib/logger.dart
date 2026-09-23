import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

class RestrictionFileOutput extends AdvancedFileOutput {
  static final RegExp _ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');

  RestrictionFileOutput({
    required super.path,
    super.maxFileSizeKB,
    super.fileHeader,
    super.fileFooter,
    super.latestFileName,
    super.fileNameFormatter,
  });

  @override
  void output(OutputEvent event) {
    // 只允许写入 Level.warning 及以上级别
    if (event.level < Level.warning) {
      return;
    }

    // 清除控制台产生的 ANSI 彩色转义码
    final cleanLines = event.lines
        .map((l) => l.replaceAll(_ansiRegex, ''))
        .toList();

    super.output(OutputEvent(event.origin, cleanLines));
  }
}

/// 全局 Logger 单例工具类
class LoggerUni {
  static late final Logger _logger;
  LoggerUni._();

  static void init() {
    final currentDir = p.dirname(Platform.resolvedExecutable);
    final logDirectory = Directory(p.join(currentDir, 'logs'));
    if (!logDirectory.existsSync()) {
      logDirectory.createSync(recursive: true);
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final fileOutput = RestrictionFileOutput(
      path: logDirectory.path,
      maxFileSizeKB: 512,
      fileHeader:
          '—————————————————————————————— Start writing  ——————————————————————————————',
      fileFooter:
          '—————————————————————————————— Write complete ——————————————————————————————',
      latestFileName: '$todayStr.log',
      fileNameFormatter: (DateTime timestamp) {
        final hms =
            '${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';
        return '$todayStr-$hms.log';
      },
    );

    final List<LogOutput> outputs = [fileOutput];

    // Debug 模式输出到控制台，Release 模式不输出到控制台
    if (kDebugMode) {
      outputs.add(ConsoleOutput());
    }

    _logger = Logger(
      filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
      printer: PrettyPrinter(
        colors: kDebugMode,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
      output: MultiOutput(outputs),
    );
  }

  static void t(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.t(message, error: error, stackTrace: stackTrace);

  static void d(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  static void i(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  static void f(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.f(message, error: error, stackTrace: stackTrace);
}
