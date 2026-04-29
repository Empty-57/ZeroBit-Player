import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart' hide Response;

import '../getxController/setting_ctrl.dart';
import '../tools/krc_decryptor.dart';
import '../tools/lrcTool/krc_extract_decode.dart';
import '../tools/lrcTool/lyric_model.dart';
import '../tools/qrc_decryptor.dart';

const _neSearchUrl = "https://music.163.com/api/cloudsearch/pc";
const _neLrcUrl = "https://music.163.com/api/song/lyric";

const _qmSearchUrl = "https://u.y.qq.com/cgi-bin/musicu.fcg";
const _qmLrcUrl = "https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg";

const _kgSearchUrl = "http://mobilecdn.kugou.com/api/v3/search/song";
const _kgSearchLrcUrl = "http://lyrics.kugou.com/search";
const _kgDownloadLrcUrl = "http://lyrics.kugou.com/download";

const _coverSize = 800; // 150, 300, 500, 800

final _dio = Dio(
  BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
      'Connection': 'keep-alive',
    },
  ),
);

final _qmDio = Dio(
  BaseOptions(
    headers: {
      "Host": "u.y.qq.com",
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
      'Connection': 'keep-alive',
      "Content-Type": "text/plain; charset=utf-8",
    },
  ),
);

final SettingController _settingController = Get.find<SettingController>();

/// 提取 qrc 正文 翻译 罗马音
Map<String, String?> _qrcParseLyricByRegex(String rawXml) {
  String? extract(String tagName) {
    // 匹配标签内的 CDATA 内容
    // 允许标签有属性，匹配 <tag ...><![CDATA[内容]]></tag>
    final regExp = RegExp(
      '<$tagName[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\\/$tagName>',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(rawXml);
    return match?.group(1);
  }

  return {
    'lyric': extract('content'),
    'trans': extract('contentts'),
    'roma': extract('contentroma'),
  };
}

Future<dynamic> _saveNetCover({
  required String songPath,
  required String picUrl,
  required bool saveCover,
}) async {
  try {
    final pic = await _dio.get(
      picUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    if (pic.data != null) {
      if (saveCover) {
        await editCover(path: songPath, src: Uint8List.fromList(pic.data));
      }
      return pic.data;
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<dynamic> _qmSearchByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  final response = await _qmDio.post(
    _qmSearchUrl,
    data: jsonEncode({
      "comm": {"ct": "19", "cv": "1873", "uin": "0"},
      "music.search.SearchCgiService": {
        "method": "DoSearchForQQMusicDesktop",
        "module": "music.search.SearchCgiService",
        "param": {
          "grp": 1,
          "num_per_page": limit,
          "page_num": offset,
          "query": text,
          "search_type": 0,
        },
      },
    }),
    options: Options(responseType: ResponseType.bytes), // 接口返回的数据不规范，防止报错
  );
  if (response.data != null) {
    final rawString = utf8.decode(response.data as List<int>);
    return jsonDecode(rawString);
  }
  return null;
}

Future<dynamic> _qmSaveCoverByText({
  required String text,
  required String songPath,
  bool? saveCover = true,
}) async {
  String? picUrl;
  try {
    final Map<String, dynamic> data = await _qmSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    final songList =
        data["music.search.SearchCgiService"]?["data"]?["body"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) {
      return null;
    }
    final mid = songList.first?['album']?['mid']?.toString().trim();
    if (mid != null && mid.isNotEmpty) {
      picUrl =
          "https://y.gtimg.cn/music/photo_new/T002R${_coverSize}x${_coverSize}M000$mid.jpg";
      return await _saveNetCover(
        songPath: songPath,
        picUrl: picUrl,
        saveCover: saveCover!,
      );
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<Get4NetLrcModel?> _qmGetLrc({required int id}) async {
  final response = await _qmDio.get(
    _qmLrcUrl,
    queryParameters: {"version": '15', "lrctype": '4', "musicid": id},
    options: Options(responseType: ResponseType.plain),
  );

  final String? body = response.data?.toString();
  if (body == null || body.isEmpty) {
    return Get4NetLrcModel(
      lrc: null,
      verbatimLrc: null,
      translate: null,
      type: LyricFormat.qrc,
    );
  }

  //Original、ts、roma
  final data = _qrcParseLyricByRegex(body);
  String? encryptedOriginal = data['lyric'];
  String? encryptedTranslate = data['trans'];
  String? decryptedRoma = data['roma'];

  String? qrcDecrypted;
  String? translateDecrypted;

  if (encryptedOriginal != null && encryptedOriginal.isNotEmpty) {
    if (!encryptedOriginal.trimLeft().startsWith('<?xml') &&
        !encryptedOriginal.trimLeft().startsWith('<Qrc')) {
      // 只要以以上俩字符串开头就代表已解压
      try {
        qrcDecrypted = await qrcDecrypt(
          encryptedQrc: encryptedOriginal,
          isLocal: false,
        );
      } catch (e) {
        debugPrint('qrcDecrypt original error: $e');
        qrcDecrypted = null;
      }
    }
  }

  if (encryptedTranslate != null && encryptedTranslate.isNotEmpty) {
    if (!encryptedTranslate.contains("[00") &&
        !encryptedTranslate.contains("[al")) {
      // 只要包含时间戳或者专辑信息就不解密
      try {
        translateDecrypted = await qrcDecrypt(
          encryptedQrc: encryptedTranslate,
          isLocal: false,
        );
      } catch (e) {
        debugPrint('qrcDecrypt translate error: $e');
        translateDecrypted = null;
      }
    } else {
      translateDecrypted = encryptedTranslate;
    }
  }

  return Get4NetLrcModel(
    lrc: null,
    verbatimLrc: qrcDecrypted,
    translate: translateDecrypted,
    type: LyricFormat.qrc,
  );
}

Future<List<SearchLrcModel?>> _qmGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final Map<String, dynamic> data = await _qmSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    final songList =
        data["music.search.SearchCgiService"]?["data"]?["body"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) {
      return [];
    }

    for (final item in songList) {
      final data = await _qmGetLrc(id: item["id"]);
      if (data == null) {
        continue;
      }

      var singerList = item["singer"];
      String? singer;
      if (singerList is List && singerList.isNotEmpty) {
        singer = singerList[0]["name"];
      }

      lrcData.add(
        SearchLrcModel(
          title: item["title"] ?? 'UNKNOWN',
          artist: singer ?? 'UNKNOWN',
          id: item["id"] ?? 'UNKNOWN',
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err) {
    debugPrint(err.toString());
    return lrcData;
  }
}

Future<dynamic> _neSearchByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  final response = await _dio.get(
    _neSearchUrl,
    queryParameters: {
      "s": text,
      "type": 1,
      "offset": offset,
      "total": true,
      "limit": limit,
    },
    options: Options(responseType: ResponseType.plain),
  );
  if (response.data != null) {
    return jsonDecode(response.data);
  }
  return null;
}

Future<dynamic> _neSaveCoverByText({
  required String text,
  required String songPath,
  bool? saveCover = true,
}) async {
  String? picUrl;
  try {
    final Map<String, dynamic> data = await _neSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    final songCount = data["result"]?["songCount"];
    if (songCount is int && songCount > 0) {
      final songList = data["result"]?["songs"];
      if (songList is! List || songList.isEmpty) {
        return null;
      }

      final picUrl = songList[0]["al"]["picUrl"];
      return await _saveNetCover(
        songPath: songPath,
        picUrl: picUrl,
        saveCover: saveCover!,
      );
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<Get4NetLrcModel?> _neGetLrc({required int id}) async {
  final response = await _dio.get(
    _neLrcUrl,
    queryParameters: {"id": id, "lv": -1, "yv": -1, "tv": -1, "os": 'pc'},
    options: Options(responseType: ResponseType.plain),
  );
  final body = response.data as String?;
  if (body == null || body.isEmpty) {
    return Get4NetLrcModel(
      lrc: null,
      verbatimLrc: null,
      translate: null,
      type: LyricFormat.lrc,
    );
  }
  final Map<String, dynamic> data = jsonDecode(body);

  final String? lrcLyric = data['lrc']?['lyric'];
  final String? yrcLyric = data['yrc']?['lyric'];
  final String? tLyric = data['tlyric']?['lyric'];
  final String type =
      yrcLyric != null && yrcLyric.isNotEmpty
          ? LyricFormat.yrc
          : LyricFormat.lrc;

  return Get4NetLrcModel(
    lrc: lrcLyric,
    verbatimLrc: yrcLyric,
    translate: tLyric,
    type: type,
  );
}

Future<List<SearchLrcModel?>> _neGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final data = await _neSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    final songs = data["result"]?["songs"];
    if (songs is! List || songs.isEmpty) {
      return [];
    }

    for (final item in songs) {
      final data = await _neGetLrc(id: item["id"]);
      if (data == null) {
        continue;
      }

      lrcData.add(
        SearchLrcModel(
          title: item["name"] ?? 'UNKNOWN',
          artist: item["ar"][0]["name"] ?? 'UNKNOWN',
          id: item["id"] ?? 'UNKNOWN',
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err) {
    debugPrint(err.toString());
    return [];
  }
}

Future<dynamic> _kgSearchByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  final response = await _dio.get(
    _kgSearchUrl,
    queryParameters: {
      "format": "json",
      "keyword": text,
      "page": offset,
      "pagesize": limit,
    },
    options: Options(responseType: ResponseType.plain),
  );
  if (response.data != null) {
    return jsonDecode(response.data);
  }
  return null;
}

Future<dynamic> _kgSaveCoverByText({
  required String text,
  required String songPath,
  bool? saveCover = true,
}) async {
  String? picUrl;
  try {
    final Map<String, dynamic> data = await _kgSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    final songList = data["data"]?["info"];
    if (songList is! List || songList.isEmpty) {
      return null;
    }

    final groupList = songList.first['group'];

    if (groupList is! List || groupList.isEmpty) {
      return null;
    }

    final unionCover = groupList.first['trans_param']?['union_cover'];

    if (unionCover != null && unionCover.isNotEmpty) {
      picUrl = unionCover.toString().replaceFirst("{size}", "$_coverSize");
      return await _saveNetCover(
        songPath: songPath,
        picUrl: picUrl,
        saveCover: saveCover!,
      );
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<Get4NetLrcModel?> _kgGetLrc({required String id}) async {
  final response = await _dio.get(
    _kgSearchLrcUrl,
    queryParameters: {"ver": '1', "man": 'yes', "client": "pc", "hash": id},
    options: Options(responseType: ResponseType.plain),
  );

  final nullModel = Get4NetLrcModel(
    lrc: null,
    verbatimLrc: null,
    translate: null,
    type: LyricFormat.krc,
  );

  if (response.data == null) {
    return nullModel;
  }

  final candidate = jsonDecode(response.data)?['candidates'];

  if (candidate is! List || candidate.isEmpty) {
    return nullModel;
  }

  final String? id_ = candidate.first['id'];
  final String? accesskey = candidate.first['accesskey'];

  if (id_ == null || accesskey == null || id_.isEmpty || accesskey.isEmpty) {
    return nullModel;
  }

  final lyricResponse = await _dio.get(
    _kgDownloadLrcUrl,
    queryParameters: {
      "ver": '1',
      "client": "pc",
      "id": id_,
      "accesskey": accesskey,
      'fmt': 'krc',
      'charset': 'utf8',
    },
    options: Options(responseType: ResponseType.plain),
  );

  if (lyricResponse.data == null) {
    return nullModel;
  }

  final String? content = jsonDecode(lyricResponse.data)?['content'];

  if (content == null || content.isEmpty) {
    return nullModel;
  }

  final String? contentcDecrypted = krcDecrypt(content);

  final String? translate = krcExtractAndDecodeLanguage(contentcDecrypted);

  return Get4NetLrcModel(
    lrc: null,
    verbatimLrc: contentcDecrypted,
    translate: translate,
    type: LyricFormat.krc,
  );
}

Future<List<SearchLrcModel?>> _kgGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final Map<String, dynamic> data = await _kgSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    final songList = data["data"]?["info"];
    if (songList is! List || songList.isEmpty) {
      return [];
    }

    for (final item in songList) {
      final data = await _kgGetLrc(id: item["hash"]);
      if (data == null) {
        continue;
      }

      lrcData.add(
        SearchLrcModel(
          title: item["songname"] ?? 'UNKNOWN',
          artist: item["singername"] ?? 'UNKNOWN',
          id: item["hash"] ?? 'UNKNOWN',
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err) {
    debugPrint(err.toString());
    return lrcData;
  }
}

Future<dynamic> saveCoverByText({
  required String text,
  required String songPath,
  bool? saveCover = true,
}) async {
  return await [
    _qmSaveCoverByText,
    _neSaveCoverByText,
    _kgSaveCoverByText,
  ][_settingController.apiIndex.value](
    text: text,
    songPath: songPath,
    saveCover: saveCover,
  );
}

Future<List<SearchLrcModel?>> getLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  return await [
    _qmGetLrcBySearch,
    _neGetLrcBySearch,
    _kgGetLrcBySearch,
  ][_settingController.apiIndex.value](
    text: text,
    offset: offset,
    limit: limit,
  );
}
