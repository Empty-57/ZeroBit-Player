import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/lrcTool/krc_decryptor.dart';
import 'package:zerobit_player/tools/lrcTool/krc_extract_decode.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/tools/lrcTool/qrc_decryptor.dart';

const _neSearchUrl = "https://music.163.com/api/cloudsearch/pc";
const _neLrcUrl = "https://music.163.com/api/song/lyric";

const _qmSearchUrl = "https://u.y.qq.com/cgi-bin/musicu.fcg";
const _qmLrcUrl = "https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg";

const _kgSearchUrl = "http://mobilecdn.kugou.com/api/v3/search/song";
const _kgSearchLrcUrl = "http://lyrics.kugou.com/search";
const _kgDownloadLrcUrl = "http://lyrics.kugou.com/download";

const _coverSize = 800; // 150, 300, 500, 800

const _defaultConnectTimeout = Duration(seconds: 8);
const _defaultReceiveTimeout = Duration(seconds: 8);

final _dio = Dio(
  BaseOptions(
    connectTimeout: _defaultConnectTimeout,
    receiveTimeout: _defaultReceiveTimeout,
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
      'Connection': 'keep-alive',
    },
  ),
);

final _qmDio = Dio(
  BaseOptions(
    connectTimeout: _defaultConnectTimeout,
    receiveTimeout: _defaultReceiveTimeout,
    headers: {
      "Host": "u.y.qq.com",
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
      'Connection': 'keep-alive',
      "Content-Type": "text/plain; charset=utf-8",
    },
  ),
);

final SettingController _settingController = SettingController.instance;

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
      final bytes = pic.data is Uint8List
          ? (pic.data as Uint8List)
          : Uint8List.fromList(pic.data as List<int>);

      if (saveCover) {
        await editCover(path: songPath, src: bytes);
      }
      return bytes;
    }
  } catch (e, stackTrace) {
    LoggerUni.w('获取或保存封面失败 URL: $picUrl', e, stackTrace);
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
  bool saveCover = true,
}) async {
  String? picUrl;
  try {
    final dynamic rawData = await _qmSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    if (rawData is! Map<String, dynamic>) return null;

    final songList =
        rawData["music.search.SearchCgiService"]?["data"]?["body"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) return null;

    final firstSong = songList.first;
    if (firstSong is! Map) return null;

    final mid = firstSong['album']?['mid']?.toString().trim();
    if (mid != null && mid.isNotEmpty) {
      picUrl =
          "https://y.gtimg.cn/music/photo_new/T002R${_coverSize}x${_coverSize}M000$mid.jpg";
      return await _saveNetCover(
        songPath: songPath,
        picUrl: picUrl,
        saveCover: saveCover,
      );
    }
  } catch (e, stackTrace) {
    LoggerUni.w('接口0按关键词保存封面失败: $text, URL: $picUrl', e, stackTrace);
  }
  return null;
}

Future<Get4NetLrcModel?> _qmGetLrc({required int id}) async {
  try {
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

    // Original、ts、roma
    final data = _qrcParseLyricByRegex(body);
    String? encryptedOriginal = data['lyric'];
    String? encryptedTranslate = data['trans'];
    // String? decryptedRoma = data['roma'];

    String? qrcDecrypted;
    String? translateDecrypted;

    if (encryptedOriginal != null && encryptedOriginal.isNotEmpty) {
      final trimmed = encryptedOriginal.trimLeft();
      if (!trimmed.startsWith('<?xml') &&
          !trimmed.startsWith('<Qrc') &&
          !trimmed.contains('[00:')) {
        // 只要以上述字符串开头或包含时间戳就代表已解压
        try {
          qrcDecrypted = await qrcDecrypt(
            encryptedQrc: encryptedOriginal,
            isLocal: false,
          );
        } catch (e, stackTrace) {
          LoggerUni.w('QRC 解压异常', e, stackTrace);
          qrcDecrypted = null;
        }
      } else {
        qrcDecrypted = encryptedOriginal;
      }
    }

    if (encryptedTranslate != null && encryptedTranslate.isNotEmpty) {
      if (!encryptedTranslate.contains("[00") &&
          !encryptedTranslate.contains("[al")) {
        // 只要包含时间戳或者专辑信息就不解压
        try {
          translateDecrypted = await qrcDecrypt(
            encryptedQrc: encryptedTranslate,
            isLocal: false,
          );
        } catch (e, stackTrace) {
          LoggerUni.w('QRC 翻译解压异常', e, stackTrace);
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
  } catch (e, stackTrace) {
    LoggerUni.w('接口0获取歌词异常 (ID: $id)', e, stackTrace);
    return null;
  }
}

Future<List<SearchLrcModel?>> _qmGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final dynamic rawData = await _qmSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return [];

    final songList =
        rawData["music.search.SearchCgiService"]?["data"]?["body"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) return [];

    for (final item in songList) {
      if (item is! Map) continue;
      final songId = item["id"];
      if (songId == null) continue;

      final data = await _qmGetLrc(id: songId);
      if (data == null) continue;

      String singer = 'UNKNOWN';
      final singerList = item["singer"];
      if (singerList is List && singerList.isNotEmpty && singerList[0] is Map) {
        singer = singerList[0]["name"]?.toString() ?? 'UNKNOWN';
      }

      lrcData.add(
        SearchLrcModel(
          title: item["title"]?.toString() ?? 'UNKNOWN',
          artist: singer,
          id: songId,
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err, stackTrace) {
    LoggerUni.w('接口0搜索歌词异常: $text', err, stackTrace);
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
  bool saveCover = true,
}) async {
  String? picUrl;
  try {
    final dynamic rawData = await _neSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    if (rawData is! Map<String, dynamic>) return null;

    final songCount = rawData["result"]?["songCount"];
    if (songCount is int && songCount > 0) {
      final songList = rawData["result"]?["songs"];
      if (songList is! List || songList.isEmpty) return null;

      final firstSong = songList[0];
      if (firstSong is! Map) return null;

      picUrl = firstSong["al"]?["picUrl"]?.toString();
      if (picUrl != null && picUrl.isNotEmpty) {
        return await _saveNetCover(
          songPath: songPath,
          picUrl: picUrl,
          saveCover: saveCover,
        );
      }
    }
  } catch (e, stackTrace) {
    LoggerUni.w('接口1按关键词保存封面失败: $text, URL: $picUrl', e, stackTrace);
  }
  return null;
}

Future<Get4NetLrcModel?> _neGetLrc({required int id}) async {
  try {
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
    final dynamic rawData = jsonDecode(body);
    if (rawData is! Map<String, dynamic>) return null;

    final String? lrcLyric = rawData['lrc']?['lyric'];
    final String? yrcLyric = rawData['yrc']?['lyric'];
    final String? tLyric = rawData['tlyric']?['lyric'];
    final String type = yrcLyric != null && yrcLyric.isNotEmpty
        ? LyricFormat.yrc
        : LyricFormat.lrc;

    return Get4NetLrcModel(
      lrc: lrcLyric,
      verbatimLrc: yrcLyric,
      translate: tLyric,
      type: type,
    );
  } catch (e, stackTrace) {
    LoggerUni.w('接口1获取歌词异常 (ID: $id)', e, stackTrace);
    return null;
  }
}

Future<List<SearchLrcModel?>> _neGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final dynamic rawData = await _neSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return [];

    final songs = rawData["result"]?["songs"];
    if (songs is! List || songs.isEmpty) return [];

    for (final item in songs) {
      if (item is! Map) continue;
      final songId = item["id"];
      if (songId == null) continue;

      final data = await _neGetLrc(id: songId);
      if (data == null) continue;

      String artist = 'UNKNOWN';
      final arList = item["ar"];
      if (arList is List && arList.isNotEmpty && arList[0] is Map) {
        artist = arList[0]["name"]?.toString() ?? 'UNKNOWN';
      }

      lrcData.add(
        SearchLrcModel(
          title: item["name"]?.toString() ?? 'UNKNOWN',
          artist: artist,
          id: songId,
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err, stackTrace) {
    LoggerUni.w('接口1搜索歌词异常: $text', err, stackTrace);
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
  bool saveCover = true,
}) async {
  String? picUrl;
  try {
    final dynamic rawData = await _kgSearchByText(
      text: text,
      offset: 1,
      limit: 1,
    );
    if (rawData is! Map<String, dynamic>) return null;

    final songList = rawData["data"]?["info"];
    if (songList is! List || songList.isEmpty) return null;

    final firstSong = songList.first;
    if (firstSong is! Map) return null;

    final groupList = firstSong['group'];
    if (groupList is! List || groupList.isEmpty) return null;

    final firstGroup = groupList.first;
    if (firstGroup is! Map) return null;

    final unionCover = firstGroup['trans_param']?['union_cover'];
    if (unionCover != null && unionCover.isNotEmpty) {
      picUrl = unionCover.toString().replaceFirst("{size}", "$_coverSize");
      return await _saveNetCover(
        songPath: songPath,
        picUrl: picUrl,
        saveCover: saveCover,
      );
    }
  } catch (e, stackTrace) {
    LoggerUni.w('接口2按关键词保存封面失败: $text, URL: $picUrl', e, stackTrace);
  }
  return null;
}

Future<Get4NetLrcModel?> _kgGetLrc({required String id}) async {
  final nullModel = Get4NetLrcModel(
    lrc: null,
    verbatimLrc: null,
    translate: null,
    type: LyricFormat.krc,
  );

  try {
    final response = await _dio.get(
      _kgSearchLrcUrl,
      queryParameters: {"ver": '1', "man": 'yes', "client": "pc", "hash": id},
      options: Options(responseType: ResponseType.plain),
    );

    if (response.data == null) return nullModel;

    final dynamic parsedData = jsonDecode(response.data);
    final candidate = parsedData?['candidates'];
    if (candidate is! List || candidate.isEmpty) return nullModel;

    final firstCandidate = candidate.first;
    if (firstCandidate is! Map) return nullModel;

    final String? id_ = firstCandidate['id'];
    final String? accesskey = firstCandidate['accesskey'];

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

    if (lyricResponse.data == null) return nullModel;

    final dynamic lyricJson = jsonDecode(lyricResponse.data);
    final String? content = lyricJson?['content'];
    if (content == null || content.isEmpty) return nullModel;

    final String? contentcDecrypted = krcDecrypt(content);
    final String? translate = krcExtractAndDecodeLanguage(contentcDecrypted);

    return Get4NetLrcModel(
      lrc: null,
      verbatimLrc: contentcDecrypted,
      translate: translate,
      type: LyricFormat.krc,
    );
  } catch (e, stackTrace) {
    LoggerUni.w('接口2获取歌词异常 (ID: $id)', e, stackTrace);
    return nullModel;
  }
}

Future<List<SearchLrcModel?>> _kgGetLrcBySearch({
  required String text,
  required int offset,
  required int limit,
}) async {
  final List<SearchLrcModel> lrcData = [];
  try {
    final dynamic rawData = await _kgSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return [];

    final songList = rawData["data"]?["info"];
    if (songList is! List || songList.isEmpty) return [];

    for (final item in songList) {
      if (item is! Map) continue;
      final songHash = item["hash"];
      if (songHash == null) continue;

      final data = await _kgGetLrc(id: songHash);
      if (data == null) continue;

      lrcData.add(
        SearchLrcModel(
          title: item["songname"]?.toString() ?? 'UNKNOWN',
          artist: item["singername"]?.toString() ?? 'UNKNOWN',
          id: songHash,
          lyric: data,
        ),
      );
    }
    return lrcData;
  } catch (err, stackTrace) {
    LoggerUni.w('接口2搜索歌词异常: $text', err, stackTrace);
    return lrcData;
  }
}

Future<dynamic> saveCoverByText({
  required String text,
  required String songPath,
  bool saveCover = true,
}) async {
  final handlers = [_qmSaveCoverByText, _neSaveCoverByText, _kgSaveCoverByText];

  final index = _settingController.apiIndex.value.clamp(0, handlers.length - 1);
  return await handlers[index](
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
  final handlers = [_qmGetLrcBySearch, _neGetLrcBySearch, _kgGetLrcBySearch];

  final index = _settingController.apiIndex.value.clamp(0, handlers.length - 1);
  return await handlers[index](text: text, offset: offset, limit: limit);
}
