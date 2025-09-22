import 'dart:core';

import 'package:flutter/cupertino.dart';

import 'lyric_model.dart';

/// 解析 LRC 行的正则： [mm:ss.xx]text
final RegExp _lrcLineRegex = RegExp(
  r'\[(\d{2}):(\d{2}\.\d{2,3})](.*?)(\r?\n|$)',
); // /\[(\d{2}):(\d{2}\.\d{2,3})](.*?)(\r?\n|$)/g

/// 解析逐字 qrc yrc 行的正则
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

/// 把 mm 和 ss.xx 转成秒数
double _parseTime(String m, String s) {
  final minutes = int.tryParse(m) ?? 0;
  final seconds = double.tryParse(s) ?? 0.0;
  return minutes * 60 + seconds;
}

/// 将整首 LRC 文本解析成时间 + 文本的列表
List<LyricEntry> _parseLyrics(String text) {
  final List<LyricEntry> entries = [];
  for (final match in _lrcLineRegex.allMatches(text)) {
    try {
      final start = _parseTime(match[1]!, match[2]!);
      final lyric = match[3]!.trim();
      entries.add(LyricEntry(start: start, lyricText: lyric));
    } catch (e) {
      // 跳过格式错行
      debugPrint('Invalid lyric line: ${match.group(0)} → $e');
    }
  }
  return entries;
}

/// 合并主歌词与翻译歌词
List<LyricEntry> _mergeTranslations(
  List<LyricEntry> mainEntries,
  String? lyricDataTs, {
  String type = LyricFormat.lrc,
}) {
  // 如果是 LRC 格式并且没有指定 lyricDataTs ，就直接从 mainEntries 中提取翻译
  if (type == LyricFormat.lrc&&(lyricDataTs==null||lyricDataTs.isEmpty)) {
    // 按时间分组：同一时间点的列表
    final Map<double, List<LyricEntry>> grouped = {};
    for (final e in mainEntries) {
      grouped.putIfAbsent(e.start, () => []).add(e);
    }

    // 对每个组进行处理
    for (final group in grouped.values) {
      if (group.length > 1) {
        // 同一时间点多条，第 0 条为主歌词，第 1 条为翻译
        final primary = group[0];
        final trans = group[1];

        primary.translate = trans.lyricText.trim();
      } else {
        // 只有一条时，检查 “ / ” 拆分
        final entry = group[0];
        if (entry.lyricText.contains(' / ')) {
          final parts = entry.lyricText.split(' / ');
          entry.lyricText = parts[0].trim();
          entry.translate = parts[1].trim();
        }
      }
    }

    // 设置 nextTime 并返回
    for (var i = 0; i < mainEntries.length; i++) {
      mainEntries[i].nextTime =
          (i < mainEntries.length - 1)
              ? mainEntries[i + 1].start
              : double.infinity;
    }
    return mainEntries;
  }

  // 非 LRC，走基于时间匹配翻译逻辑
  final transQueue =
      lyricDataTs != null ? _parseLyrics(lyricDataTs) : <LyricEntry>[];
  var transIdx = 0;

  String Function(LyricEntry) getTranslate = (e) => e.lyricText;
  if (type == LyricFormat.qrc) {
    getTranslate = (e) => e.lyricText == '//' ? ' ' : e.lyricText;
  }
  final tolerance = (type ==  LyricFormat.qrc || type ==  LyricFormat.lrc) ? 0.1 : 0.8;

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

/// 解析 Lrc 格式歌词并合并翻译
List<LyricEntry>? parseLrc({String? lyricData, String? lyricDataTs = ''}) {
  if (lyricData == null || lyricData.isEmpty) return null;
  final main = _parseLyrics(lyricData);
  return _mergeTranslations(main, lyricDataTs);
}

/// 毫秒转秒（保留 3 位小数）
double _msToSec(String msStr) {
  final ms = int.tryParse(msStr) ?? 0;
  return double.parse((ms / 1000).toStringAsFixed(3));
}

/// 获取按类型对应的单词级别正则与索引
class _WordRegexConfig {
  final RegExp regex;
  final int startIdx, durIdx, textIdx;
  _WordRegexConfig(this.regex, this.startIdx, this.durIdx, this.textIdx);
}

_WordRegexConfig? _getWordRegexConfig(String type) {
  switch (type) {
    case LyricFormat.yrc:
      return _WordRegexConfig(_yrcWordRegex, 1, 2, 3);
    case LyricFormat.qrc:
      return _WordRegexConfig(_qrcWordRegex, 2, 3, 1);
    default:
      return null;
  }
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

/// 将一行内容里的所有单词解析并按需合并
List<WordEntry> _processWords(
  String content,
  RegExp wordRegex,
  int startIdx,
  int durIdx,
  int textIdx,
) {
  final List<WordEntry> words = [];
  for (final m in wordRegex.allMatches(content)) {
    final curr = WordEntry(
      start: _msToSec(m.group(startIdx)!),
      duration: _msToSec(m.group(durIdx)!),
      lyricWord: m.group(textIdx)!.replaceAll('\n', ''),
    );
    if (words.isNotEmpty && _shouldMergeWords(curr, words.last)) {
      final last = words.last;
      // 如果合并后时间不冲突就合并
      if (last.start + last.duration >= curr.start) {
        words[words.length - 1] = _mergeWords(last, curr);
      } else {
        words.add(curr);
      }
    } else {
      words.add(curr);
    }
  }

  for(var i=0;i<words.length;i++){
    words[i].nextTime=(i < words.length - 1)
            ? words[i + 1].start
            : double.infinity;
  }

  return words;
}

/// 解析卡拉 OK 格式歌词并合并翻译
List<LyricEntry>? parseKaraOkLyric(
    {
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
    final dur = _msToSec(m.group(2)!);
    final content = m.group(3)!;
    final words = _processWords(
      content,
      cfg.regex,
      cfg.startIdx,
      cfg.durIdx,
      cfg.textIdx,
    );
    segments.add(
      LyricEntry(start: start, lyricText: words, nextTime: start + dur),
    );
  }

  return _mergeTranslations(segments, lyricDataTs, type: type);
}
