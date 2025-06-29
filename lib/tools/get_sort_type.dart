import 'package:pinyin/pinyin.dart';

import '../HIveCtrl/models/music_cahce_model.dart';

String getSortType({required int type, required MusicCache data}) {
    switch (type) {
      case 0:
        return PinyinHelper.getShortPinyin(data.title.trim().toLowerCase());
      case 1:
        return PinyinHelper.getShortPinyin(data.artist.trim().toLowerCase());
      case 2:
        return PinyinHelper.getShortPinyin(data.album.trim().toLowerCase());
      case 3:
        return data.duration.toString().trim().toLowerCase();
    }
    return data.title;
  }