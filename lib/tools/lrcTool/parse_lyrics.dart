import 'dart:convert';
import 'dart:core';

import 'package:flutter/cupertino.dart';

import 'lyric_model.dart';

// ─────────────────────────── 正则表达式 ───────────────────────────

/// 解析 LRC 行的正则： [mm:ss.xx]text
final RegExp _lrcLineRegex = RegExp(
  r'\[(\d{2}):(\d{2}\.\d{2,3})](.*?)(\r?\n|$)',
); // /\[(\d{2}):(\d{2}\.\d{2,3})](.*?)(\r?\n|$)/g

/// 解析逐字 qrc yrc krc 行的正则
final RegExp _karaOkLineRegex = RegExp(
  r'\[(\d+),(\d+)](.*?)(\r?\n|$)',
); // /\[(\d+),(\d+)](.*?)(\r?\n|$)/g

/// 解析 yrc 逐字的正则
final RegExp _yrcWordRegex = RegExp(
  r'\((\d+),(\d+),\d+\)[^(]*?((?:.(?!\(\d+,))*.)',
); // /\((\d+),(\d+),\d+\)[^(]*?((?:.(?!\(\d+,))*.)/g

/// 解析 qrc 逐字的正则
final RegExp _qrcWordRegex = RegExp(
  r'[^(]*?((?:.(?!\(\d+,))*.)\((\d+),(\d+)\)',
); // /[^(]*?((?:.(?!\(\d+,))*.)\((\d+),(\d+)\)/g

/// 解析 krc 逐字的正则
final RegExp _krcWordRegex = RegExp(
  r'<(\d+),(\d+),\d+>[^<]*?((?:.(?!<\d+,))*.)',
);

/// 解析增强型 LRC 逐字的正则
final RegExp _enhancedLrcWordRegex = RegExp(
  r'<(\d{2}):(\d{2}\.\d{2,3})>([^<]*)',
);

/// 解析逐字 LRC 逐字的正则
final RegExp _wordByWordLrcWordRegex = RegExp(
  r'\[(\d{2}):(\d{2}\.\d{2,3})]([^\[]*)',
);

// ─────────────────────────── 枚举 ───────────────────────────

enum LrcType {
  /// 逐行Lrc: [00:24.212]歌词
  lineByLine,

  /// 逐字Lrc: [00:24.212]歌[00:24.352]词[00:24.488]
  wordByWord,

  /// 增强型Lrc: [00:24.212]<00:24.212>歌<00:24.352>词<00:24.488>
  enhanced,

  /// 未知类型
  unknown,
}

// ─────────────────────────── 工具函数 ───────────────────────────

/// 把 mm 和 ss.xx 转成秒数
double _parseTime(String m, String s) {
  final minutes = int.tryParse(m) ?? 0;
  final seconds = double.tryParse(s) ?? 0.0;
  return minutes * 60 + seconds;
}

/// 毫秒转秒（保留 3 位小数）
double _msToSec(String msStr) {
  final ms = int.tryParse(msStr) ?? 0;
  return double.parse((ms / 1000).toStringAsFixed(3));
}

/// 是否要合并两个单词块
bool _shouldMergeWords(WordEntry curr, WordEntry last) {
  return curr.start == last.start ||
      ((curr.duration <= 0.06 || last.duration <= 0.06) && last.start > 0);
}

/// 合并单词块
WordEntry _mergeWords(WordEntry last, WordEntry curr) {
  return WordEntry(
    start: last.start,
    duration: last.duration + curr.duration,
    lyricWord: last.lyricWord + curr.lyricWord,
  );
}

// ─────────────────────────── LRC 类型检测 ───────────────────────────

LrcType detectLrcType(String lrcContent) {
  final lines = lrcContent.trim();

  // 增强型 Lrc：行内含 <hh:mm.sss> 格式时间戳，连续匹配 3 次
  if (RegExp(r'(<\d{2}:\d{2}\.\d{2,3}>[^\n\r]*){3}').hasMatch(lines)) {
    return LrcType.enhanced;
  }

  // 逐字 Lrc：行内含 [hh:mm.sss] 格式时间戳，连续匹配 3 次
  if (RegExp(r'(\[\d{2}:\d{2}\.\d{2,3}\][^\n\r]*){3}').hasMatch(lines)) {
    return LrcType.wordByWord;
  }

  // 逐行 Lrc：仅行首有一个时间戳
  if (RegExp(
    r'^\[\d{2}:\d{2}\.\d+\](?!.*\[\d{2}:\d{2}\.\d+\]).*$',
    multiLine: true,
  ).hasMatch(lines)) {
    return LrcType.lineByLine;
  }

  return LrcType.unknown;
}

// ─────────────────────────── 基础 LRC 解析 ───────────────────────────

/// 将整首 LRC 文本解析成时间 + 文本的列表
List<LyricEntry> _parseLyrics(String text) {
  // 用于剥离行内时间戳的正则
  final reg1 = RegExp(r'<\d{2}:\d{2}\.\d{2,3}>');
  final reg2 = RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]');

  return [
    for (final match in _lrcLineRegex.allMatches(text))
      () {
        try {
          final start = _parseTime(match[1]!, match[2]!);
          final lyric =
              match[3]!.replaceAll(reg1, '').replaceAll(reg2, '').trim();
          return LyricEntry(start: start, lyricText: lyric);
        } catch (e) {
          debugPrint('Invalid lyric line: ${match.group(0)} → $e');
          return null;
        }
      }(),
  ].whereType<LyricEntry>().toList();
}

// ─────────────────────────── 增强 / 逐字 LRC 解析 ───────────────────────────

List<WordEntry> _enhancedAndWordByWordLrcAnalysis(
  String lrcContent,
  RegExp reg,
) {
  final List<WordEntry> words = [];

  for (final m in reg.allMatches(lrcContent)) {
    final curr = WordEntry(
      start: _parseTime(m.group(1)!, m.group(2)!),
      duration: 5.0,
      lyricWord: m.group(3)!.replaceAll('\n', ''),
    );

    if (words.isNotEmpty) {
      words.last.duration = curr.start - words.last.start;
    }
    words.add(curr);
  }

  for (var i = 0; i < words.length; i++) {
    words[i].nextTime =
        (i < words.length - 1) ? words[i + 1].start : double.infinity;
  }

  // for(var i=0;i<words.length-1;i++){  // 对于逐字Lrc的合并
  //   final last=words[i];
  //   final curr=words[i+1];
  //   if((last.start + last.duration >= curr.start)&&_shouldMergeWords(curr, last)){
  //     words[i]=_mergeWords(last, curr);
  //     words.removeAt(i+1);
  //   }
  // }
  return words;
}

(List<LyricEntry>, String) _lrcAnalysis(String lrcContent) {
  final lrcType = detectLrcType(lrcContent);

  final RegExp? reg = switch (lrcType) {
    LrcType.enhanced => _enhancedLrcWordRegex,
    LrcType.wordByWord => _wordByWordLrcWordRegex,
    _ => null,
  };

  // 逐行或未知类型，直接走普通解析
  if (reg == null) {
    return (_parseLyrics(lrcContent), LyricFormat.lrc);
  }

  final List<LyricEntry> segments = [];
  for (final m in _lrcLineRegex.allMatches(lrcContent)) {
    final start = _parseTime(m[1]!, m[2]!);
    final lyric = m[3]!.trim();

    final words =
        reg == _wordByWordLrcWordRegex
            ? _enhancedAndWordByWordLrcAnalysis(m[0]!.trim(), reg)
            : _enhancedAndWordByWordLrcAnalysis(lyric, reg);

    segments.add(LyricEntry(start: start, lyricText: words));
  }

  return (segments, LyricFormat.byWordLrc);
}

// ─────────────────────────── 逐字歌词解析（KRC / QRC / YRC）───────────────────────────

/// 获取按类型对应的单词级别正则与索引
class _WordRegexConfig {
  final RegExp regex;
  final int startIdx, durIdx, textIdx;
  const _WordRegexConfig(this.regex, this.startIdx, this.durIdx, this.textIdx);
}

_WordRegexConfig? _getWordRegexConfig(String type) {
  return switch (type) {
    LyricFormat.yrc => _WordRegexConfig(_yrcWordRegex, 1, 2, 3),
    LyricFormat.qrc => _WordRegexConfig(_qrcWordRegex, 2, 3, 1),
    LyricFormat.krc => _WordRegexConfig(_krcWordRegex, 1, 2, 3),
    _ => null,
  };
}

/// 将一行内容里的所有单词解析并按需合并
List<WordEntry> _processWords(
  String content,
  RegExp wordRegex,
  int startIdx,
  int durIdx,
  int textIdx, {
  required double Function() lineStart,
}) {
  final List<WordEntry> words = [];

  for (final m in wordRegex.allMatches(content)) {
    final curr = WordEntry(
      start: _msToSec(m.group(startIdx)!) + lineStart(),
      duration: _msToSec(m.group(durIdx)!),
      lyricWord: m.group(textIdx)!.replaceAll('\n', ''),
    );

    if (words.isNotEmpty && _shouldMergeWords(curr, words.last)) {
      final last = words.last;
      // 合并后时间不冲突才合并
      if (last.start + last.duration >= curr.start) {
        words[words.length - 1] = _mergeWords(last, curr);
        continue;
      }
    }
    words.add(curr);
  }

  for (var i = 0; i < words.length; i++) {
    words[i].nextTime =
        (i < words.length - 1) ? words[i + 1].start : double.infinity;
  }

  return words;
}

// ─────────────────────────── 翻译合并 ───────────────────────────

/// 合并主歌词与翻译歌词
List<LyricEntry> _mergeTranslations(
  List<LyricEntry> mainEntries,
  String? lyricDataTs, {
  String type = LyricFormat.lrc,
}) {
  // LRC 系列：从 mainEntries 自身提取翻译（同时间戳多行）
  if ((type == LyricFormat.lrc || type == LyricFormat.byWordLrc) &&
      (lyricDataTs == null || lyricDataTs.isEmpty)) {
    return _mergeLrcInlineTranslations(mainEntries, type);
  }

  // KRC：从 JSON 格式的 lyricDataTs 提取翻译 / 注音
  if (type == LyricFormat.krc && lyricDataTs != null) {
    return _mergeKrcTranslations(mainEntries, lyricDataTs);
  }

  // 其余格式：按时间匹配翻译
  return _mergeByTimeMatch(mainEntries, lyricDataTs, type);
}

/// LRC 内嵌翻译合并（同时间戳多行）
List<LyricEntry> _mergeLrcInlineTranslations(
  List<LyricEntry> mainEntries,
  String type,
) {
  // 按时间分组
  final Map<double, List<LyricEntry>> grouped = {};
  for (final e in mainEntries) {
    grouped.putIfAbsent(e.start, () => []).add(e);
  }

  // 统计最大同时间行数（用于区分 [原文+翻译] 还是 [注音+原文]）
  int maxSameLine = grouped.values.fold(
    0,
    (m, g) => g.length > m ? g.length : m,
  );

  // 需要适配不同情况下的注音，原文，翻译位置 待完成

  for (final group in grouped.values) {
    switch (group.length) {
      case 2:
        _handleTwoLineGroup(group, mainEntries, maxSameLine);
      case 3:
        _handleThreeLineGroup(group, mainEntries);
      case 1:
        _handleSingleLineGroup(group[0]);
    }
  }

  // 设置 nextTime
  for (var i = 0; i < mainEntries.length; i++) {
    mainEntries[i].nextTime =
        (i < mainEntries.length - 1)
            ? mainEntries[i + 1].start
            : double.infinity;
  }

  // byWordLrc 需要修正最后一个单词的 duration
  if (type == LyricFormat.byWordLrc) {
    _fixByWordLrcLastWordDuration(mainEntries);
  }

  return mainEntries;
}

void _handleTwoLineGroup(
  List<LyricEntry> group,
  List<LyricEntry> mainEntries,
  int maxSameLine,
) {
  LyricEntry primary;
  LyricEntry trans;

  if (maxSameLine >= 3) {
    // 同时间戳行数为 3 的情况，可能是 [原文+翻译] 或 [注音+原文]，根据字符密度判断
    if (group[1].lyricText is List<WordEntry> &&
        group[1].lyricText.length <= 2) {
      // 逐字类型，group[1] 长度 ≤2 则为翻译，即 [原文+翻译]
      primary = group[0];
      trans = group[1];
    } else {
      // [注音+原文]
      final roma = group[0];
      primary = group[1];
      trans = LyricEntry(start: 0.0, lyricText: '');
      _applyRoma(roma, primary);
      mainEntries.remove(roma);
    }
  } else {
    // 同一时间点 2 条：第 0 条原文，第 1 条翻译
    primary = group[0];
    trans = group[1];
  }

  _applyTranslate(trans, primary);
  mainEntries.remove(trans);
}

void _handleThreeLineGroup(
  List<LyricEntry> group,
  List<LyricEntry> mainEntries,
) {
  // 同一时间点 3 条：第 0 条注音，第 1 条原文，第 2 条翻译
  final roma = group[0];
  final primary = group[1];
  final trans = group[2];

  _applyRoma(roma, primary);
  _applyTranslate(trans, primary);
  mainEntries
    ..remove(roma)
    ..remove(trans); // 合并进入primary后删除重复项目
}

void _handleSingleLineGroup(LyricEntry entry) {
  // 只有一条时，检查 " / " 拆分
  if (entry is String && entry.lyricText.contains(' / ')) {
    final parts = entry.lyricText.split(' / ');
    entry.lyricText = parts[0].trim();
    entry.translate = parts[1].trim();
  }
}

/// 将 roma 条目的文字写入 primary.roma
void _applyRoma(LyricEntry roma, LyricEntry primary) {
  if (roma.lyricText is String) {
    primary.roma = roma.lyricText as String;
  } else if (roma.lyricText is List<WordEntry>) {
    primary.roma =
        (roma.lyricText as List<WordEntry>).map((w) => w.lyricWord).join();
  }
}

/// 将 trans 条目的文字写入 primary.translate
void _applyTranslate(LyricEntry trans, LyricEntry primary) {
  if (trans.lyricText is String) {
    primary.translate = (trans.lyricText as String).trim();
  } else if (trans.lyricText is List<WordEntry> &&
      (trans.lyricText as List<WordEntry>).isNotEmpty) {
    primary.translate = (trans.lyricText as List<WordEntry>).first.lyricWord;
  }
}

/// 修正 byWordLrc 末尾单词的 duration
void _fixByWordLrcLastWordDuration(List<LyricEntry> mainEntries) {
  for (var i = 0; i < mainEntries.length - 1; i++) {
    double duration = 0.0;

    for (var j = 1; j < 4; j++) {
      // 因为最多三行：注音、原文、翻译
      if (i + j > mainEntries.length - 1) break;
      final start = mainEntries[i + j].start;
      final currStart =
          (mainEntries[i].lyricText as List<WordEntry>).first.start;
      if (start == currStart) continue;
      duration =
          start - (mainEntries[i].lyricText as List<WordEntry>).last.start;
      break;
    }

    (mainEntries[i].lyricText as List<WordEntry>).last.duration = duration;
  }
}

/// KRC 翻译合并（从 JSON lyricDataTs 提取）
List<LyricEntry> _mergeKrcTranslations(
  List<LyricEntry> mainEntries,
  String lyricDataTs,
) {
  try {
    final info = jsonDecode(lyricDataTs); // 从网络获取的歌词，翻译在 language:内 为json格式
    final contentList = info['content'];
    if (contentList is! List || contentList.isEmpty) return mainEntries;

    for (final content in contentList) {
      switch (content['type']) {
        case 1: // 翻译
          final translateList = content['lyricContent'];
          if (translateList is List && translateList.isNotEmpty) {
            for (var i = 0; i < translateList.length; i++) {
              final ts = (translateList[i] as List).first as String;
              mainEntries[i].translate = ts.trim();
            }
          }
        case 0: // 注音
          final romaList = content['lyricContent'];
          if (romaList is List && romaList.isNotEmpty) {
            for (var i = 0; i < romaList.length; i++) {
              mainEntries[i].roma = (romaList[i] as List).join();
            }
          }
      }
    }
  } catch (e) {
    debugPrint(e.toString());
  }
  return mainEntries;
}

/// 按时间匹配翻译（QRC / YRC 等）
List<LyricEntry> _mergeByTimeMatch(
  List<LyricEntry> mainEntries,
  String? lyricDataTs,
  String type,
) {
  final transQueue =
      lyricDataTs != null ? _parseLyrics(lyricDataTs) : <LyricEntry>[];
  int transIdx = 0;

  final String Function(LyricEntry) getTranslate =
      type == LyricFormat.qrc
          ? (e) => e.lyricText == '//' ? ' ' : e.lyricText as String
          : (e) => e.lyricText as String;

  final tolerance =
      (type == LyricFormat.qrc || type == LyricFormat.lrc) ? 0.1 : 0.8;

  for (var i = 0; i < mainEntries.length; i++) {
    final curr = mainEntries[i];
    curr.nextTime =
        (i < mainEntries.length - 1)
            ? mainEntries[i + 1].start
            : double.infinity;
    if (curr.lyricText.isEmpty) continue;

    while (transIdx < transQueue.length) {
      final te = transQueue[transIdx];
      if (curr.start >= te.start - tolerance) {
        if (curr.start <= te.start + tolerance) {
          curr.translate = getTranslate(te).trim();
        }
      } else {
        break;
      }
      transIdx++;
    }
  }
  return mainEntries;
}

// ─────────────────────────── 公开 API ───────────────────────────

/// 解析 LRC 格式歌词并合并翻译
List<LyricEntry>? parseLrc({String? lyricData, String? lyricDataTs = ''}) {
  if (lyricData == null || lyricData.isEmpty) return null;
  final (entries, format) = _lrcAnalysis(lyricData);
  return _mergeTranslations(entries, lyricDataTs, type: format);
}

/// 解析逐字格式歌词（KRC / QRC / YRC）并合并翻译
List<LyricEntry>? parseKaraOkLyric({
  String? lyricData,
  String? lyricDataTs,
  required String type,
}) {
  if (lyricData == null || lyricData.isEmpty) return null;

  final cfg = _getWordRegexConfig(type);
  if (cfg == null) return null;

  final List<LyricEntry> segments = [];
  for (final m in _karaOkLineRegex.allMatches(lyricData)) {
    final start = _msToSec(m.group(1)!);
    final content = m.group(3)!;

    final words = _processWords(
      content,
      cfg.regex,
      cfg.startIdx,
      cfg.durIdx,
      cfg.textIdx,
      lineStart: () => type == LyricFormat.krc ? start : 0,
    );
    segments.add(LyricEntry(start: start, lyricText: words, nextTime: 0));
  }

  // 本行 start+dur 不一定等于下一行 start，手动赋值 nextTime
  for (var i = 0; i < segments.length; i++) {
    segments[i].nextTime =
        (i < segments.length - 1) ? segments[i + 1].start : double.infinity;
  }

  debugPrint("currentLyrics | type: $type");
  return _mergeTranslations(segments, lyricDataTs, type: type);
}
