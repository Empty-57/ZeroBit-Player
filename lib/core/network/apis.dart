import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:zerobit_player/features/setting/controller/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';

import '../../features/lyrics/models/lyric_model.dart';
import '../../features/lyrics/parsers/krc_decryptor.dart';
import '../../features/lyrics/parsers/krc_extract_decode.dart';
import '../../features/lyrics/parsers/qrc_decryptor.dart';
import '../utils/logger.dart';

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
    // 匹配标签内的 CDATA 内容，允许标签有属性：<tag ...><![CDATA[内容]]></tag>
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

Future<Uint8List?> saveNetCover({
  required String songPath,
  required String picUrl,
  required bool saveCover,
}) async {
  try {
    final pic = await _dio.get<List<int>>(
      picUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    final data = pic.data;
    if (data != null) {
      final Uint8List bytes = data is Uint8List
          ? data
          : Uint8List.fromList(data);

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
  final response = await _qmDio.post<List<int>>(
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
  final data = response.data;
  if (data != null) {
    final rawString = utf8.decode(data);
    return jsonDecode(rawString);
  }
  return null;
}

Future<List<String>> _qmGetCoverUrlByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  try {
    final dynamic rawData = await _qmSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return const [];
    final songList =
        rawData["music.search.SearchCgiService"]?["data"]?["body"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) return const [];

    return songList
        .map<String?>((song) {
          if (song is! Map) return null;
          final mid = song['album']?['mid']?.toString().trim();
          if (mid == null || mid.isEmpty) return null;
          return "https://y.gtimg.cn/music/photo_new/T002R${_coverSize}x${_coverSize}M000$mid.jpg";
        })
        .nonNulls
        .toList();
  } catch (e, stackTrace) {
    LoggerUni.w('接口0按关键词获取封面Url失败: $text', e, stackTrace);
    return [];
  }
}

Future<Uint8List?> _qmSaveCoverByText({
  required String text,
  required String songPath,
  bool saveCover = true,
}) async {
  final coverUrls = await _qmGetCoverUrlByText(
    text: text,
    offset: 1,
    limit: 10,
  );
  if (coverUrls.isEmpty || coverUrls.first.isEmpty) return null;

  return saveNetCover(
    songPath: songPath,
    picUrl: coverUrls.first,
    saveCover: saveCover,
  );
}

Future<Get4NetLrcModel?> _qmGetLrc({required int id}) async {
  try {
    final response = await _qmDio.get<String>(
      _qmLrcUrl,
      queryParameters: {"version": '15', "lrctype": '4', "musicid": id},
      options: Options(responseType: ResponseType.plain),
    );

    final String? body = response.data;
    if (body == null || body.isEmpty) {
      return const Get4NetLrcModel(
        lrc: null,
        verbatimLrc: null,
        translate: null,
        type: LyricFormat.qrc,
      );
    }

    // Original、ts、roma
    final data = _qrcParseLyricByRegex(body);
    final String? encryptedOriginal = data['lyric'];
    final String? encryptedTranslate = data['trans'];
    // String? decryptedRoma = data['roma'];

    String? qrcDecrypted;
    String? translateDecrypted;

    if (encryptedOriginal != null && encryptedOriginal.isNotEmpty) {
      final trimmed = encryptedOriginal.trimLeft();

      // 只要出现以下字符串开头或包含时间戳就代表已解压
      final isAlreadyDecrypted =
          trimmed.startsWith('<?xml') ||
          trimmed.startsWith('<Qrc') ||
          trimmed.contains('[00:');

      qrcDecrypted = isAlreadyDecrypted
          ? encryptedOriginal
          : await qrcDecrypt(encryptedQrc: encryptedOriginal, isLocal: false);
    }

    if (encryptedTranslate != null && encryptedTranslate.isNotEmpty) {
      final isAlreadyDecrypted =
          encryptedTranslate.contains("[00") ||
          encryptedTranslate.contains("[al");

      translateDecrypted = isAlreadyDecrypted
          ? encryptedTranslate
          : await qrcDecrypt(encryptedQrc: encryptedTranslate, isLocal: false);
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
  final response = await _dio.get<String>(
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
  final data = response.data;
  if (data != null) {
    return jsonDecode(data);
  }
  return null;
}

Future<List<String>> _neGetCoverUrlByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  try {
    final dynamic rawData = await _neSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return const [];

    final songCount = rawData["result"]?["songCount"];
    if (songCount is! int || songCount <= 0) return const [];

    final songList = rawData["result"]?["songs"];
    if (songList is! List || songList.isEmpty) return const [];

    return songList
        .map<String?>((song) {
          if (song is! Map) return null;
          final url = song["al"]?["picUrl"];
          if (url is! String || url.isEmpty) return null;
          return url;
        })
        .nonNulls
        .toList();
  } catch (e, stackTrace) {
    LoggerUni.w('接口1按关键词获取封面URL失败: $text', e, stackTrace);
    return [];
  }
}

Future<Uint8List?> _neSaveCoverByText({
  required String text,
  required String songPath,
  bool saveCover = true,
}) async {
  final coverUrls = await _neGetCoverUrlByText(text: text, offset: 1, limit: 5);
  if (coverUrls.isEmpty || coverUrls.first.isEmpty) return null;

  return saveNetCover(
    songPath: songPath,
    picUrl: coverUrls.first,
    saveCover: saveCover,
  );
}

Future<Get4NetLrcModel?> _neGetLrc({required int id}) async {
  try {
    final response = await _dio.get<String>(
      _neLrcUrl,
      queryParameters: {"id": id, "lv": -1, "yv": -1, "tv": -1, "os": 'pc'},
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.isEmpty) {
      return const Get4NetLrcModel(
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
  final response = await _dio.get<String>(
    _kgSearchUrl,
    queryParameters: {
      "format": "json",
      "keyword": text,
      "page": offset,
      "pagesize": limit,
    },
    options: Options(responseType: ResponseType.plain),
  );
  final data = response.data;
  if (data != null) {
    return jsonDecode(data);
  }
  return null;
}

Future<List<String>> _kgGetCoverUrlByText({
  required String text,
  required int offset,
  required int limit,
}) async {
  try {
    final dynamic rawData = await _kgSearchByText(
      text: text,
      offset: offset,
      limit: limit,
    );
    if (rawData is! Map<String, dynamic>) return [];

    final songList = rawData["data"]?["info"];
    if (songList is! List || songList.isEmpty) return [];

    return songList
        .map<String?>((song) {
          if (song is! Map) return null;

          String unionCover;
          final groupList = song['group'];

          if (groupList is! List || groupList.isEmpty) {
            final url = song['trans_param']?['union_cover'];
            if (url is! String || url.isEmpty) return null;
            unionCover = url;
          } else {
            final firstGroup = groupList.first;
            if (firstGroup is! Map) return null;
            final url = firstGroup['trans_param']?['union_cover'];
            if (url is! String || url.isEmpty) return null;
            unionCover = url;
          }

          return unionCover.replaceFirst("{size}", "$_coverSize");
        })
        .nonNulls
        .toList();
  } catch (e, stackTrace) {
    LoggerUni.w('接口2按关键词获取封面URL失败: $text,', e, stackTrace);
    return [];
  }
}

Future<Uint8List?> _kgSaveCoverByText({
  required String text,
  required String songPath,
  bool saveCover = true,
}) async {
  final coverUrls = await _kgGetCoverUrlByText(text: text, offset: 1, limit: 5);
  if (coverUrls.isEmpty || coverUrls.first.isEmpty) return null;

  return saveNetCover(
    songPath: songPath,
    picUrl: coverUrls.first,
    saveCover: saveCover,
  );
}

Future<Get4NetLrcModel?> _kgGetLrc({required String id}) async {
  const nullModel = Get4NetLrcModel(
    lrc: null,
    verbatimLrc: null,
    translate: null,
    type: LyricFormat.krc,
  );

  try {
    final response = await _dio.get<String>(
      _kgSearchLrcUrl,
      queryParameters: {"ver": '1', "man": 'yes', "client": "pc", "hash": id},
      options: Options(responseType: ResponseType.plain),
    );
    final data = response.data;
    if (data == null) return nullModel;

    final dynamic parsedData = jsonDecode(data);
    final candidate = parsedData?['candidates'];
    if (candidate is! List || candidate.isEmpty) return nullModel;

    final firstCandidate = candidate.first;
    if (firstCandidate is! Map) return nullModel;

    final String? id_ = firstCandidate['id'];
    final String? accesskey = firstCandidate['accesskey'];

    if (id_ == null || accesskey == null || id_.isEmpty || accesskey.isEmpty) {
      return nullModel;
    }

    final lyricResponse = await _dio.get<String>(
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
    final lyricData = lyricResponse.data;
    if (lyricData == null) return nullModel;

    final dynamic lyricJson = jsonDecode(lyricData);
    final String? content = lyricJson?['content'];
    if (content == null || content.isEmpty) return nullModel;

    final String? contentDecrypted = krcDecrypt(content);
    final String? translate = krcExtractAndDecodeLanguage(contentDecrypted);

    return Get4NetLrcModel(
      lrc: null,
      verbatimLrc: contentDecrypted,
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

Future<List<String>> getCoverUrlByText({
  required String text,
  required int offset,
  required int limit,
  int? apiIndex,
}) async {
  final handlers = [
    _qmGetCoverUrlByText,
    _neGetCoverUrlByText,
    _kgGetCoverUrlByText,
  ];
  final index = (apiIndex ?? _settingController.apiIndex.value).clamp(
    0,
    handlers.length - 1,
  );
  return await handlers[index](text: text, offset: offset, limit: limit);
}

Future<Uint8List?> saveCoverByText({
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
  int? apiIndex,
}) async {
  final handlers = [_qmGetLrcBySearch, _neGetLrcBySearch, _kgGetLrcBySearch];

  final index = (apiIndex ?? _settingController.apiIndex.value).clamp(
    0,
    handlers.length - 1,
  );
  return await handlers[index](text: text, offset: offset, limit: limit);
}
