import 'japanese_analyzer.dart';
import 'lyric_model.dart';

final _kanji = RegExp(r'[\p{Script=Han}々〆〻]', unicode: true);
final _multiKanji = RegExp(r'[\p{Script=Han}々〆〻]{2,}', unicode: true);
final _separators = RegExp(r'^[\s\p{P}\p{S}]*$', unicode: true);

/// 等长规范化，先把全角字符转换成半角，再把日语片假名转换成平假名
String _normalize(String text) => String.fromCharCodes(
  toHalfWidth(text).runes.map((r) => r >= 0x30a1 && r <= 0x30f6 ? r - 0x60 : r),
);

/// 注音区间：原文 [start, end) 整体读作 reading，中间不可再切分。
typedef _RubySpan = (int start, int end, String reading);

/// 按原文定位整词读音，并把假名写回对应的时间块。
///
/// 注音组始终覆盖时间块的完整文本：区间内未被读音覆盖的送假名、助词会按原文补齐，
/// 跨时间块的读音（复合词、熟字训）则把相关时间块并成一组，
/// 因此 ruby 与下方歌词永远对齐，且逐字高亮仍沿用原始时间轴。
void alignJapaneseFurigana(
  List<WordEntry> words,
  List<JapanesePhoneticModel> phonemes,
) {
  if (words.isEmpty || phonemes.isEmpty) return;

  final source = _normalize(words.map((w) => w.lyricWord).join());
  if (source.isEmpty) return;

  // 获取原文每个时间块的开始位置
  final starts = List<int>.filled(words.length, 0);
  var offset = 0;
  for (var i = 0; i < words.length; i++) {
    starts[i] = offset;
    offset += words[i].lyricWord.length;
  }

  final spans = _collectRubySpans(source, phonemes);
  if (spans.isEmpty) return;

  _writeFurigana(words, starts, source, spans);
}

/// 逐个音素定位到原文下标，展开成互不重叠且递增的注音区间。
List<_RubySpan> _collectRubySpans(
  String source,
  List<JapanesePhoneticModel> phonemes,
) {
  final spans = <_RubySpan>[];
  var cursor = 0; // 指示当前读取到的位置

  for (final phoneme in phonemes) {
    if (cursor >= source.length) break;

    final phonemeText = _normalize(phoneme.text); // 规范化音素原文与读音
    if (phonemeText.isEmpty) continue;

    final start = _locate(source, phonemeText, cursor);
    if (start < 0) {
      // 分析器与原文不同步时按长度保守推进：只丢掉当前词的注音，
      // 而不是放弃整行让后面的汉字全部失去假名。
      cursor = (cursor + phonemeText.length).clamp(0, source.length);
      continue;
    }
    cursor = start + phonemeText.length; // 跳过空白后，更新游标

    final yomi = _normalize(phoneme.yomi);
    if (yomi.isEmpty || //跳过非法状态
        yomi == phonemeText ||
        !_kanji.hasMatch(phonemeText) ||
        _kanji.hasMatch(yomi)) {
      continue;
    }

    for (final (left, right, reading) in _splitReading(phonemeText, yomi)) {
      if (reading.isEmpty) continue;
      spans.add((start + left, start + right, reading));
    }
  }

  return spans;
}

/// 在原文中定位音素，返回 -1 表示无法可靠对齐。
int _locate(String source, String needle, int cursor) {
  // 常规情况：分析器逐词连续覆盖原文
  if (source.startsWith(needle, cursor)) return cursor;
  // 原生分析器可能省略空白、标点，允许跳过纯分隔符的间隔重新对齐；
  // 但不能跨过未匹配的正文猜测位置，否则读音会落到同形的其它字上。
  final found = source.indexOf(needle, cursor);
  if (found < 0) return -1;
  return _separators.hasMatch(source.substring(cursor, found)) ? found : -1;
}

/// 把注音区间合并成与时间块边界对齐的注音组并写回。
void _writeFurigana(
  List<WordEntry> words,
  List<int> starts,
  String source,
  List<_RubySpan> spans,
) {
  // 注音区间内部不可切分，落在区间内部的时间块边界必须合并
  final breakable = List<bool>.filled(source.length + 1, true);
  for (final (start, end, _) in spans) {
    for (var p = start + 1; p < end; p++) {
      breakable[p] = false;
    }
  }

  var spanIdx = 0;
  var i = 0;
  while (i < words.length) {
    final left = starts[i];
    var last = i;
    var right = left + words[i].lyricWord.length;
    // 跨时间块的读音（复合词、熟字训）把相关时间块并成一个注音组
    while (last + 1 < words.length && !breakable[right]) {
      last++;
      right = starts[last] + words[last].lyricWord.length;
    }

    // 区间与注音组同为递增序列，游标只需单向前进
    while (spanIdx < spans.length && spans[spanIdx].$2 <= left) {
      spanIdx++;
    }

    final ruby = StringBuffer();
    var pos = left;
    var next = spanIdx;
    while (next < spans.length && spans[next].$1 < right) {
      final (start, end, reading) = spans[next];
      // 未被读音覆盖的送假名、助词按原文补齐，保证 ruby 与整组文字等价
      if (start > pos) ruby.write(source.substring(pos, start));
      ruby.write(reading);
      pos = end;
      next++;
    }

    if (next > spanIdx) {
      if (pos < right) ruby.write(source.substring(pos, right));
      _applyRuby(
        words,
        i,
        last,
        ruby.toString().trim(),
        source.substring(left, right),
      );
      spanIdx = next;
    }

    i = last + 1;
  }
}

/// 写入一个注音组；已有人工注音时保留，避免覆盖歌词文件提供的特殊唱法。
void _applyRuby(
  List<WordEntry> words,
  int first,
  int last,
  String ruby,
  String surface,
) {
  if (ruby.isEmpty || ruby == surface) return;
  for (var i = first; i <= last; i++) {
    if (words[i].furigana.isNotEmpty) return;
  }
  words[first].furigana = ruby;
  words[first].furiganaGroupLength = last - first + 1;
}

/// 整词分析里存在连续汉字时，单字分析才可能给出更细的注音定位。
bool canRefinePhonemes(List<JapanesePhoneticModel> phonemes) =>
    phonemes.any((p) => p.hasFurigana && _multiKanji.hasMatch(p.text));

/// 用单字分析结果细化整词分析结果，使复合词的假名落到各自的汉字上。
///
/// 仅当细分片段与整词逐字对齐、且读音拼接与整词读音完全一致时才采纳；
/// 熟字训（今日→きょう）无法由单字拼出，分析器也不会拆分，于是继续使用整词读音。
List<JapanesePhoneticModel> refinePhonemes(
  List<JapanesePhoneticModel> words,
  List<JapanesePhoneticModel> mono,
) {
  if (words.isEmpty || mono.length <= words.length) return words;

  final refined = <JapanesePhoneticModel>[];
  var cursor = 0;

  for (final word in words) {
    final pieces = <JapanesePhoneticModel>[];
    final covered = StringBuffer();
    while (cursor < mono.length && covered.length < word.text.length) {
      final piece = mono[cursor++];
      pieces.add(piece);
      covered.write(piece.text);
    }

    // 两次分析的切分边界必须重合，否则无法安全细化
    if (covered.toString() != word.text) return words;
    if (pieces.length < 2) {
      refined.add(word);
      continue;
    }

    final usable =
        pieces.every((p) => p.yomi.isNotEmpty) &&
        pieces.map((p) => _normalize(p.yomi)).join() == _normalize(word.yomi);
    if (usable) {
      refined.addAll(pieces);
    } else {
      refined.add(word);
    }
  }

  return cursor == mono.length ? refined : words;
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
    final subEnd = next.$2.clamp(0, surface.length);
    final anchor = surface.substring(next.$1.clamp(0, subEnd), subEnd);
    var end = reading.indexOf(anchor, (pos + 1).clamp(0, reading.length));
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
