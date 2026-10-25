import 'dart:io';
import 'package:flutter/services.dart';
import 'package:zerobit_player/core/utils/logger.dart';

/// 分词结果对象
///
/// `text`: 原文
///
/// `yomi`: 读音
///
/// `isPhraseStart`: 指示此单词是否是短语的开头
class JapanesePhoneticModel {
  final String text;
  final String yomi;
  final bool isPhraseStart;

  const JapanesePhoneticModel({
    required this.text,
    required this.yomi,
    required this.isPhraseStart,
  });

  static final RegExp _kanjiRegex = RegExp(r'\p{Script=Han}', unicode: true);

  /// 是否有注音
  bool get hasFurigana => _kanjiRegex.hasMatch(text) && text != yomi;

  @override
  String toString() => hasFurigana ? '$text($yomi)' : text;
}

/// 全角转半角工具（仅转换英数符号和空格）
String toHalfWidth(String input) {
  final units = input.codeUnits.toList();
  bool changed = false;

  for (var i = 0; i < units.length; i++) {
    final c = units[i];

    if (c >= 0xFF01 && c <= 0xFF5E) {
      units[i] = c - 0xFEE0;
      changed = true;
    } else if (c == 0x3000) {
      units[i] = 0x20;
      changed = true;
    }
  }

  return changed ? String.fromCharCodes(units) : input;
}

class JapaneseAnalyzer {
  static const MethodChannel _channel = MethodChannel(
    'japanese_analyzer_channel',
  );

  /// 系统是否支持日语解析器
  static bool? _isSupported;

  /// 检查当前系统环境是否支持日语分词注音
  static Future<bool> isAvailable() async {
    if (_isSupported != null) return _isSupported!;
    if (!Platform.isWindows) {
      _isSupported = false;
      return false;
    }

    String text = '';
    String yomi = '';

    try {
      final List<dynamic>? test = await _channel.invokeMethod('getWords', {
        'text': '日本語',
        'monoRuby': false,
      });
      if (test != null && test.isNotEmpty) {
        final first = Map<String, dynamic>.from(test.first as Map);
        text = first['text'] ?? '';
        yomi = first['yomi'] ?? '';

        _isSupported = text != yomi && yomi.isNotEmpty;
      } else {
        _isSupported = false;
      }
    } catch (e, s) {
      LoggerUni.w('原生分析错误', e, s);
      _isSupported = false;
    }

    LoggerUni.w(
      '此用户 ${_isSupported == true ? '支持' : '不支持'} 原生假名分析 | text: $text, yomi: $yomi',
    );

    return _isSupported!;
  }

  /// 将日文文本转为带假名注音的列表
  ///
  /// `monoRuby`:
  /// - `true`: 单字注音（如「未来」拆分为「未(み)」「来(らい)」）
  /// - `false`: 整词注音（如「未来(みらい)」）
  static Future<List<JapanesePhoneticModel>> getWords(
    String text, {
    bool monoRuby = true,
  }) async {
    try {
      return (await getWordsBatch([text], monoRuby: monoRuby)).single;
    } catch (_) {
      return const [];
    }
  }

  /// 批量将多行日文文本转为带假名注音的列表集合
  static Future<List<List<JapanesePhoneticModel>>> getWordsBatch(
    List<String> texts, {
    bool monoRuby = true,
  }) async {
    if (_isSupported == false || !Platform.isWindows || texts.isEmpty) {
      return List.generate(texts.length, (_) => const []);
    }

    try {
      final List<dynamic>? batchResult = await _channel.invokeMethod(
        'getWordsBatch',
        {'texts': texts, 'monoRuby': monoRuby},
      );

      if (batchResult == null) {
        return List.generate(texts.length, (_) => const []);
      }

      return batchResult.map((lineItem) {
        if (lineItem is! List) return <JapanesePhoneticModel>[];
        return lineItem.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return JapanesePhoneticModel(
            text: toHalfWidth(map['text'] as String),
            yomi: toHalfWidth(map['yomi'] as String),
            isPhraseStart: map['isPhraseStart'] as bool,
          );
        }).toList();
      }).toList();
    } catch (_) {
      _isSupported = false;
      return List.generate(texts.length, (_) => const []);
    }
  }
}
