import 'package:pinyin/pinyin.dart';
import 'package:zerobit_player/field/sort_type.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';

String _getLetter({required String str}) {
  if (str.isEmpty) {
    return str;
  }
  final String letter = PinyinHelper.getFirstWordPinyin(str[0]);

  if (letter.isEmpty) {
    return str;
  }
  return letter[0];
}

String getSortType({required int type, required MusicCache data}) {
  switch (type) {
    case SortType.title:
      return _getLetter(str: data.title);
    case SortType.artist:
      return _getLetter(str: data.artist);
    case SortType.album:
      return _getLetter(str: data.album) +
          data.trackNumber.toString().padLeft(3, '0');
    case SortType.duration:
      return data.duration.toStringAsFixed(4).padLeft(9, '0');
  }
  return data.title;
}
