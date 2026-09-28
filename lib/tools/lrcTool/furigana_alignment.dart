import 'japanese_analyzer.dart';
import 'lyric_model.dart';

final _kanji = RegExp(r'[\p{Script=Han}々〆〻]', unicode: true);
final _separators = RegExp(r'^[\s\p{P}\p{S}]*$', unicode: true);

/// 等长规范化，先把全角字符转换成半角，再把日语片假名转换成平假名
String _normalize(String text) => String.fromCharCodes(
  toHalfWidth(text).runes.map((r) => r >= 0x30a1 && r <= 0x30f6 ? r - 0x60 : r),
);

/// 按原文定位整词读音；不可分的复合词/熟字训共用一个注音组，保留原时间轴。
void alignJapaneseFurigana(
  List<WordEntry> words,
  List<JapanesePhoneticModel> phonemes,
) {
  if (words.isEmpty || phonemes.isEmpty) return;
  final source = _normalize(words.map((w) => w.lyricWord).join());
  final starts = <int>[];
  var offset = 0;

  // 获取原文每个字的开始位置
  for (final word in words) {
    starts.add(offset);
    offset += word.lyricWord.length;
  }

  final readings = List.generate(words.length, (_) => StringBuffer());
  final groupEnds = List.generate(words.length, (i) => i);
  var cursor = 0; // 指示当前读取到的位置

  for (final phoneme in phonemes) {
    final phonemeText = _normalize(phoneme.text); // 规范化音素原文与读音
    final yomi = _normalize(phoneme.yomi);
    if (phonemeText.isEmpty) continue;

    final start = source.indexOf(phonemeText, cursor); // 从cursor的位置开始找音素原文第一次在原句出现的位置
    // 原生分析器可能省略空白、标点；不能跨过未匹配的正文后猜测位置。
    if (start < 0 || !_separators.hasMatch(source.substring(cursor, start))) {
      break;
    }
    cursor = start + phonemeText.length; // 跳过空白后，更新游标
    if (!_kanji.hasMatch(phonemeText) || //跳过非法状态
        yomi.isEmpty ||
        yomi == phonemeText ||
        _kanji.hasMatch(yomi)) {
      continue;
    }

    final spans = _splitReading(phonemeText, yomi);
    for (final span in spans) {
      final left = start + span.$1;
      final right = start + span.$2;
      var first = -1;
      var last = -1;
      for (var i = 0; i < words.length; i++) {
        if (starts[i] >= right) break;
        if (starts[i] + words[i].lyricWord.length > left) {
          first = first < 0 ? i : first;
          last = i;
        }
      }
      if (first < 0) continue;
      // 已有人工注音优先，避免覆盖歌词文件提供的特殊唱法。
      if (words.sublist(first, last + 1).any((w) => w.furigana.isNotEmpty)) {
        continue;
      }
      readings[first].write(span.$3);
      for (var i = first; i < last; i++) {
        groupEnds[i] = last > groupEnds[i] ? last : groupEnds[i];
      }
    }
  }

  for (var i = 0; i < words.length; i++) {
    var end = groupEnds[i];
    final ruby = StringBuffer()..write(readings[i]);
    // 合并有重叠的注音组，但不合并时间块，逐字高亮仍沿用原始时间。
    for (var j = i + 1; j <= end; j++) {
      if (groupEnds[j] > end) end = groupEnds[j];
      ruby.write(readings[j]);
    }
    if (words[i].furigana.isEmpty && ruby.isNotEmpty) {
      words[i].furigana = ruby.toString();
      words[i].furiganaGroupLength = end - i + 1;
    }
    i = end;
  }
}

/// 用假名锚点分离送假名。只接受唯一的完整匹配，歧义时保留整词注音。
List<(int, int, String)> _splitReading(String surface, String reading) {
  final runs = <(int, int, bool)>[];
  var offset = 0;
  for (final rune in surface.runes) {
    final char = String.fromCharCode(rune);
    final han = _kanji.hasMatch(char);
    if (runs.isNotEmpty && runs.last.$3 == han) {
      final last = runs.removeLast();
      runs.add((last.$1, offset + char.length, han));
    } else {
      runs.add((offset, offset + char.length, han));
    }
    offset += char.length;
  }
  final solutions = <List<(int, int, String)>>[];
  final path = <(int, int, String)>[];
  var budget = 2048; // 歧义歌词的回溯上限
  void visit(int index, int pos) {
    if (--budget < 0 || solutions.length > 1) return;
    if (index == runs.length) {
      if (pos == reading.length) solutions.add(List.of(path));
      return;
    }
    final run = runs[index];
    if (!run.$3) {
      final literal = surface.substring(run.$1, run.$2);
      if (reading.startsWith(literal, pos)) {
        visit(index + 1, pos + literal.length);
      }
      return;
    }
    if (index == runs.length - 1) {
      if (pos < reading.length) {
        path.add((run.$1, run.$2, reading.substring(pos)));
        visit(index + 1, reading.length);
        path.removeLast();
      }
      return;
    }
    final next = runs[index + 1];
    final anchor = surface.substring(next.$1, next.$2);
    var end = reading.indexOf(anchor, pos + 1);
    while (end >= 0 && budget > 0 && solutions.length < 2) {
      path.add((run.$1, run.$2, reading.substring(pos, end)));
      visit(index + 1, end);
      path.removeLast();
      end = reading.indexOf(anchor, end + 1);
    }
  }

  visit(0, 0);
  return solutions.length == 1 && budget >= 0
      ? solutions.single
      : [(0, surface.length, reading)];
}
