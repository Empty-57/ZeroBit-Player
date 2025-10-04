abstract class TimedEntry {
  double get start;
  double get nextTime;
}
/// 行时间轴
class LyricEntry<T> implements TimedEntry {
  @override
  final double start;
  @override
  double nextTime;
  T lyricText;
  String translate;

  LyricEntry({
    required this.start,
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
    return '[segmentStart: $start,\n lyricText: "$display",\n nextTime: $nextTime,\n translate: "$translate"\n]';
  }
}

/// 字时间轴
class WordEntry implements TimedEntry {
  @override
  final double start;
  final double duration;
  final String lyricWord;
  @override
  double nextTime;
  WordEntry({
    required this.start,
    required this.duration,
    required this.lyricWord,
    this.nextTime = double.infinity
  });

  static Map<String, dynamic> toJson(WordEntry value) =>
      {'start': value.start, 'duration': value.duration,'lyricWord':value.lyricWord};

}

class ParsedLyricModel{
  final List<LyricEntry<dynamic>>? parsedLrc;
  final String type;
  const ParsedLyricModel({required this.parsedLrc,required this.type});
}

class Get4NetLrcModel{
  final String? lrc;
  final String? verbatimLrc;
  final String? translate;
  final String type;
  const Get4NetLrcModel({required this.lrc,required this.verbatimLrc,required this.translate,required this.type});
}

class SearchLrcModel{
  final String title;
  final String artist;
  final int id;
  final Get4NetLrcModel? lyric;

  const SearchLrcModel({required this.title,required this.artist,required this.id,required this.lyric});
}

abstract class LyricFormat{
  static const qrc='.qrc';
  static const yrc='.yrc';
  static const lrc='.lrc';
}