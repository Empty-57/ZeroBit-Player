/// 时间轴条目
class LyricEntry<T> {
  final double segmentStart;
  double nextTime;
  T lyricText;
  String translate;

  LyricEntry({
    required this.segmentStart,
    this.nextTime = double.infinity,
    required this.lyricText,
    this.translate = '',
  });

  @override
  String toString() {
    final display =
        lyricText is String
            ? lyricText
            : (lyricText as List<WordEntry>)
                .map(
                  (w) =>
                      "word:${w.lyricWord} start:${w.start} duration:${w.duration} \n",
                )
                .join();
    return '[segmentStart: $segmentStart,\n lyricText: "$display",\n nextTime: $nextTime,\n translate: "$translate"\n]';
  }
}

/// 逐字时间轴
class WordEntry {
  final double start, duration;
  final String lyricWord;
  WordEntry({
    required this.start,
    required this.duration,
    required this.lyricWord,
  });
}

abstract class LyricFormat{
  static const qrc='.qrc';
  static const yrc='.yrc';
  static const lrc='.lrc';
}