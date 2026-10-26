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
    final results = List.generate(
      texts.length,
      (_) => <JapanesePhoneticModel>[],
    );

    if (_isSupported == false || !Platform.isWindows || texts.isEmpty) {
      return results;
    }

    // 歌曲内去重，副歌重复的句子只分析一次
    final textPositions = <String, List<int>>{};
    for (var i = 0; i < texts.length; i++) {
      final text = texts[i];
      if (_isValidInput(text)) {
        textPositions.putIfAbsent(text, () => []).add(i);
      }
    }
    if (textPositions.isEmpty) return results;
    final uniqueTexts = textPositions.keys.toList();

    try {
      final rawBatch = await _channel.invokeMethod('getWordsBatch', {
        'texts': uniqueTexts,
        'monoRuby': monoRuby,
      });

      if (rawBatch is! List || rawBatch.length != uniqueTexts.length) {
        return results;
      }

      // 解析结果并分发回原位置
      for (var i = 0; i < rawBatch.length; i++) {
        final models = _parsePhonemeList(rawBatch[i]);
        if (models == null) continue;

        // 将去重分析出的这句注音，一次性回填给所有相同歌词的行
        for (final index in textPositions[uniqueTexts[i]]!) {
          results[index] = List.of(models);
        }
      }
    } on PlatformException catch (e) {
      // 只有在明确报告分析器不可用时才彻底禁用
      if (e.code == 'ANALYZER_UNAVAILABLE') _isSupported = false;
    } catch (_) {
      // 偶发异常不影响后续歌曲解析
    }

    return results;
  }

  /// 校验输入文本是否合法
  static bool _isValidInput(String text) {
    return text.trim().isNotEmpty && text.length <= 100;
  }

  static List<JapanesePhoneticModel>? _parsePhonemeList(dynamic rawLine) {
    if (rawLine is! List) return null;
    final result = <JapanesePhoneticModel>[];
    for (final item in rawLine) {
      if (item case {
        'text': final String text,
        'yomi': final String yomi,
        'isPhraseStart': final bool isPhraseStart,
      }) {
        result.add(
          JapanesePhoneticModel(
            text: toHalfWidth(text),
            yomi: toHalfWidth(yomi),
            isPhraseStart: isPhraseStart,
          ),
        );
      } else {
        return null;
      }
    }
    return result;
  }
}
