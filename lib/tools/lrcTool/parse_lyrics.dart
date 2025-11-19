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

/// 解析 增强型Lrc 逐字的正则
final RegExp _enhancedLrcWordRegex = RegExp(
  r'<(\d{2}):(\d{2}\.\d{2,3})>([^<]*)',
);

/// 解析 逐字Lrc 逐字的正则
final RegExp _wordByWordLrcWordRegex = RegExp(
  r'\[(\d{2}):(\d{2}\.\d{2,3})]([^\[]*)',
);

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
  if ((type == LyricFormat.lrc || type == LyricFormat.byWordLrc) &&
      (lyricDataTs == null || lyricDataTs.isEmpty)) {
    // 按时间分组：同一时间点的列表
    int sameLine = 0;
    final Map<double, List<LyricEntry>> grouped = {};
    for (final e in mainEntries) {
      grouped.putIfAbsent(e.start, () => []).add(e);
    }
    for (final group in grouped.values) {
      sameLine = group.length;
      if (sameLine >= 3) {
        break;
      }
    }

    // 需要适配不同情况下的注音，原文，翻译位置 待完成

    // 对每个组进行处理
    for (final group in grouped.values) {
      if (group.length == 2) {
        LyricEntry primary;
        LyricEntry trans;

        if (sameLine >= 3) {
          // 同时间戳行数为3的情况，可能是 [原文 + 翻译] [注音 + 原文] 根据字符密度判断

          if (group[1].lyricText is List<WordEntry> &&
              group[1].lyricText.length <= 2) {
            //若是逐字类型 若group[1]长度小于等于2则为翻译，为[原文 + 翻译]
            primary = group[0];
            trans = group[1];
          } else {
            // 否则为 [注音 + 原文]
            final roma = group[0];
            primary = group[1];
            trans = LyricEntry(start: 0.0, lyricText: '');

            if (roma.lyricText is String) {
              primary.roma = roma.lyricText;
            }
            if (roma.lyricText is List<WordEntry> &&
                roma.lyricText.isNotEmpty) {
              for (var i = 0; i < roma.lyricText.length; i++) {
                primary.roma += roma.lyricText[i].lyricWord;
              }
            }

            mainEntries.remove(group[0]); // 删除注音
          }
        } else {
          // 同一时间点2条，第 0 条为原文，第 1 条为翻译
          primary = group[0];
          trans = group[1];
        }

        // 合并
        if (trans.lyricText is String) {
          primary.translate = trans.lyricText.trim();
        }
        if (trans.lyricText is List<WordEntry> && trans.lyricText.isNotEmpty) {
          primary.translate = trans.lyricText[0].lyricWord;
        }

        mainEntries.remove(trans);
      }

      if (group.length == 3) {
        // 同一时间点3条，第 0 条为注音，第 1 条为原文，第 2 条为翻译，
        final roma = group[0];
        final primary = group[1];
        final trans = group[2];

        if (roma.lyricText is String) {
          primary.roma = roma.lyricText;
        }
        if (roma.lyricText is List<WordEntry> && roma.lyricText.isNotEmpty) {
          for (var i = 0; i < roma.lyricText.length; i++) {
            primary.roma += roma.lyricText[i].lyricWord;
          }
        }

        // 合并
        if (trans.lyricText is String) {
          primary.translate = trans.lyricText.trim();
        }
        if (trans.lyricText is List<WordEntry> && trans.lyricText.isNotEmpty) {
          primary.translate = trans.lyricText[0].lyricWord;
        }
        mainEntries.remove(roma); //删除
        mainEntries.remove(trans);
      }

      if (group.length == 1) {
        // 只有一条时，检查 “ / ” 拆分
        final entry = group[0];
        if (entry is String && entry.lyricText.contains(' / ')) {
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

    if (type == LyricFormat.byWordLrc) {
      for (var i = 0; i < mainEntries.length - 1; i++) {
        double duration = 0.0;

        for (var j = 1; j < 4; j++) {
          // 因为最多三行，注音，原文，翻译
          if (!(i + j < mainEntries.length - 1)) {
            break;
          }
          final start = mainEntries[i + j].start;
          final currStart = mainEntries[i].lyricText.first.start;
          if (start == currStart) {
            continue;
          }
          duration = start - mainEntries[i].lyricText.last.start;
          break;
        }
        mainEntries[i].lyricText.last.duration = duration;
      }
    }

    return mainEntries;
  }

  // 走基于时间匹配翻译逻辑
  final transQueue =
      lyricDataTs != null ? _parseLyrics(lyricDataTs) : <LyricEntry>[];
  var transIdx = 0;

  String Function(LyricEntry) getTranslate = (e) => e.lyricText;
  if (type == LyricFormat.qrc) {
    getTranslate = (e) => e.lyricText == '//' ? ' ' : e.lyricText;
  }
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

LrcType detectLrcType(String lrcContent) {
  final lines = lrcContent.trim().split('\n');

  for (final line in lines) {
    final trimmedLine = line.trim();

    // 跳过空的行或元数据行（如 [ar:歌手名]）
    if (trimmedLine.isEmpty ||
        trimmedLine.startsWith('[ar:') ||
        trimmedLine.startsWith('[ti:') ||
        trimmedLine.startsWith('[al:') ||
        trimmedLine.startsWith('[by:') ||
        trimmedLine.startsWith('[tool:') ||
        trimmedLine.startsWith('[re:') ||
        trimmedLine.startsWith('[ve:') ||
        trimmedLine.startsWith('[le:') ||
        trimmedLine.startsWith('[length:') ||
        trimmedLine.startsWith('[version:') ||
        trimmedLine.startsWith('[offset:')) {
      continue;
    }

    // 检查是否是增强型Lrc (Enhanced)
    // 增强型 Lrc 特征是除了行首的时间戳，歌词内容中还有 <hh:mm.sss> 格式的时间戳
    if (RegExp(
      r'\[\d{2}:\d{2}\.\d{2,3}\]<(\d{2}:\d{2}\.\d{2,3}>)',
    ).hasMatch(trimmedLine)) {
      return LrcType.enhanced;
    }

    // 检查是否是逐字Lrc (WordByWord)
    // 逐字 Lrc 特征是歌词内容中包含 [hh:mm.sss] 格式的时间戳
    if (RegExp(
      r'\[\d{2}:\d{2}\.\d{2,3}\][^\[]*\[\d{2}:\d{2}\.\d{2,3}\]',
    ).hasMatch(trimmedLine)) {
      return LrcType.wordByWord;
    }

    // 检查是否是逐行Lrc (LineByLine)
    // 逐行 Lrc 特征是只有行首有一个时间戳，歌词内容没有时间戳
    if (RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\][^\[]*$').hasMatch(trimmedLine)) {
      return LrcType.lineByLine;
    }
  }

  return LrcType.unknown;
}

(List<LyricEntry>, String) _lrcAnalysis(String lrcContent) {
  final List<LyricEntry> segments = [];
  RegExp? reg;

  switch (detectLrcType(lrcContent)) {
    case LrcType.enhanced:
      reg = _enhancedLrcWordRegex;
    case LrcType.wordByWord:
      reg = _wordByWordLrcWordRegex;
    case LrcType.lineByLine:
      break;
    case LrcType.unknown:
      break;
  }

  if (reg == null) {
    return (_parseLyrics(lrcContent), LyricFormat.lrc);
  }

  for (final m in _lrcLineRegex.allMatches(lrcContent)) {
    final start = _parseTime(m[1]!, m[2]!);
    final lyric = m[3]!.trim();
    List<WordEntry> words;
    if (reg == _wordByWordLrcWordRegex) {
      words = _enhancedAndWordByWordLrcAnalysis(m[0]!.trim(), reg);
    } else {
      words = _enhancedAndWordByWordLrcAnalysis(lyric, reg);
    }
    segments.add(LyricEntry(start: start, lyricText: words));
  }

  return (segments, LyricFormat.byWordLrc);
}

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

/// 解析 Lrc 格式歌词并合并翻译
List<LyricEntry>? parseLrc({String? lyricData, String? lyricDataTs = ''}) {
  if (lyricData == null || lyricData.isEmpty) return null;
  final main = _lrcAnalysis(lyricData);
  return _mergeTranslations(main.$1, lyricDataTs, type: main.$2);
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

  for (var i = 0; i < words.length; i++) {
    words[i].nextTime =
        (i < words.length - 1) ? words[i + 1].start : double.infinity;
  }

  return words;
}

/// 解析 逐字 格式歌词并合并翻译
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
