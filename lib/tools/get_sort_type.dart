import 'package:pinyin/pinyin.dart';

import '../HIveCtrl/models/music_cache_model.dart';

String _getLetter({required String str}){
  if(str.isEmpty){
    return str;
  }
  final String letter=PinyinHelper.getFirstWordPinyin(str[0]);

    if(letter.isEmpty){
      return str;
    }
    return letter[0];
}

String getSortType({required int type, required MusicCache data}) {
    switch (type) {
      case 0:
        return _getLetter(str:data.title);
      case 1:
        return _getLetter(str:data.artist);
      case 2:
        return _getLetter(str:data.album);
      case 3:
        return data.duration.toStringAsFixed(4).padLeft(9,'0');
    }
    return data.title;
  }