import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart' hide Response;

import '../getxController/setting_ctrl.dart';
import '../tools/qrc_decryptor.dart';

const _qmSearchUrl = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp";
const _neSearchUrl = "https://music.163.com/api/cloudsearch/pc";

const _qmLrcUrl = "https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg";
const _neLrcUrl = "https://music.163.com/api/song/lyric";

final _dio = Dio();

final SettingController _settingController = Get.find<SettingController>();

Future<dynamic> _saveNetCover({required String songPath, required String picUrl,required bool saveCover}) async {
  try{
    final pic = await _dio.get(
    picUrl,
    options: Options(responseType: ResponseType.bytes),
  );

    if (pic.data != null) {
      if(saveCover){
        await editCover(path: songPath, src: Uint8List.fromList(pic.data));
      }
    return pic.data;
  }

  }catch(e){
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<dynamic> _qmSearchByText({required String text, required int offset, required int limit,}) async {
  final response = await _dio.get(
    _qmSearchUrl,
    queryParameters: {"format": 'json', "w": text, "n": limit, "p": offset},
    options: Options(responseType: ResponseType.json),
  );
  if (response.data != null) {
    return jsonDecode(response.data);
  }
  return null;
}

Future<dynamic> _qmSaveCoverByText({required String text, required String songPath,bool? saveCover=true}) async {
  String? picUrl;
  try {
    final Map<String, dynamic> data = await _qmSearchByText(text: text, offset: 1, limit: 1);
    final midList = data["data"]?["song"]?["list"];
    final mid = midList!=null ? (midList[0]?["albummid"]):null;
    if (mid != null) {
      picUrl = "https://y.gtimg.cn/music/photo_new/T002R800x800M000$mid.jpg";
      return await _saveNetCover(songPath: songPath, picUrl: picUrl,saveCover: saveCover!);
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<Map<String,dynamic>?> _qmGetLrc({required int id})async{
  final response = await _dio.get(
    _qmLrcUrl,
    queryParameters: {
      "version":'15',
      "lrctype":'4',
      "musicid":id,
    },
    options: Options(responseType: ResponseType.json),
  );

  final String? body = response.data?.toString();
  if (body == null || body.isEmpty) {
    return {
      'lrc': null,
      'qrc': null,
      'translate': null,
      'type': '.qrc',
    };
  }

  //Original、ts、roma
  final regex = RegExp(r'CDATA\[(\S+)]]');//CDATA\[(\S+?)\]\]
  final List<String> extracted = regex
      .allMatches(body)
      .map((m) => m.group(1))
      .whereType<String>()
      .toList();

  final String? encryptedOriginal = extracted.isNotEmpty ? extracted[0] : null;
  final String? encryptedTranslate =
      extracted.length > 1 ? extracted[1] : null;

  String? qrcDecrypted;
  String? translateDecrypted;

  if (encryptedOriginal != null && encryptedOriginal.isNotEmpty) {
    try {
      qrcDecrypted =
          await qrcDecrypt(encryptedQrc: encryptedOriginal, isLocal: false);
    } catch (e) {
      debugPrint('qrcDecrypt original error: $e');
      qrcDecrypted = null;
    }
  }

  if (encryptedTranslate != null && encryptedTranslate.isNotEmpty) {
    try {
      translateDecrypted =
          await qrcDecrypt(encryptedQrc: encryptedTranslate, isLocal: false);
    } catch (e) {
      debugPrint('qrcDecrypt translate error: $e');
      translateDecrypted = null;
    }
  }

  return {
    'lrc': null,
    'qrc': qrcDecrypted,
    'translate': translateDecrypted,
    'type': '.qrc',
  };
}

Future<List<Map<String, dynamic>>?> _qmGetLrcBySearch({required String text,required int offset,required int limit})async{
final List<Map<String,dynamic>> lrcData=[];
  try {
    final Map<String, dynamic> data=await _qmSearchByText(text: text,offset: offset,limit: limit);
    final songList = data["data"]?["song"]?["list"];
    if (songList is! List || songList.isEmpty) {
      return null;
    }

    for (final item in songList) {
      final data=await _qmGetLrc(id:item["songid"]);
      if (data==null){
        continue;
      }

      var singerList=item["singer"];
      String? singer;
      if(singerList is List&&singerList.isNotEmpty){
        singer=singerList[0]["name"];
      }

      lrcData.add({
        "name": item["songname"]??'UNKNOWN',
        "id": item["songid"]??'UNKNOWN',
        "artist": singer??'UNKNOWN',
        ...data
      });
    }
    return lrcData;
  }catch (err){
    debugPrint(err.toString());
    return null;
  }
}





Future<dynamic> _neSearchByText({required String text, required int offset, required int limit,}) async {
  final response = await _dio.get(
    _neSearchUrl,
    queryParameters: {
      "s": text,
      "type": 1,
      "offset": offset,
      "total": true,
      "limit": limit,
    },
    options: Options(responseType: ResponseType.json),
  );
  if (response.data != null) {
    return jsonDecode(response.data);
  }
  return null;
}

Future<dynamic> _neSaveCoverByText({required String text, required String songPath,bool? saveCover=true}) async {
  String? picUrl;
  try {
    final Map<String, dynamic> data = await _neSearchByText(text: text, offset: 1, limit: 1);
    final songCount=data["result"]?["songCount"];
    if (songCount is int && songCount > 0) {

      final songList=data["result"]?["songs"];
      if(songList is! List || songList.isEmpty) {
        return null;
      }

      final picUrl = songList[0]["al"]["picUrl"];
      return await _saveNetCover(songPath: songPath, picUrl: picUrl,saveCover: saveCover!);
    }
  } catch (e) {
    debugPrint('$e,$picUrl');
  }
  return null;
}

Future<Map<String,dynamic>?> _neGetLrc({required int id})async{
final response = await _dio.get(
    _neLrcUrl,
    queryParameters: {
      "id":id,
      "lv":-1,
      "yv":-1,
      "tv":-1,
      "os":'pc'
    },
    options: Options(responseType: ResponseType.json),
  );
final body = response.data as String?;
if (body == null || body.isEmpty) {
    return {
      'lrc': null,
      'yrc': null,
      'translate': null,
      'type': '.lrc',
    };
  }
  final Map<String, dynamic> data = jsonDecode(body);

  final String? lrcLyric = data['lrc']?['lyric'];
  final String? yrcLyric = data['yrc']?['lyric'];
  final String? tLyric   = data['tlyric']?['lyric'];
  final String type = yrcLyric!=null&&yrcLyric.isNotEmpty ? '.yrc' : '.lrc';

  return {
    'lrc': lrcLyric,
    'yrc': yrcLyric,
    'translate': tLyric,
    'type': type,
  };
}

Future<List<Map<String, dynamic>>?> _neGetLrcBySearch({required String text,required int offset,required int limit})async{
  final List<Map<String,dynamic>> lrcData=[];
  try {
    final data=await _neSearchByText(text: text,offset: offset,limit: limit);
    final songs=data["result"]?["songs"];
    if (songs is! List || songs.isEmpty){
      return null;
    }

    for (final item in songs) {
      final data=await _neGetLrc(id:item["id"]);
      if (data==null){
        continue;
      }
      lrcData.add({
        "name": item["name"],
        "id": item["id"],
        "artist": item["ar"][0]["name"]??'UNKNOWN',
        ...data
      });
    }
    return lrcData;
  }catch (err){
    debugPrint(err.toString());
    return null;
  }
}


Future<dynamic> saveCoverByText({required String text, required String songPath,bool? saveCover=true}) async {
  return await[_qmSaveCoverByText,_neSaveCoverByText][_settingController.apiIndex.value](text: text, songPath: songPath,saveCover: saveCover);
}

Future<dynamic> getLrcBySearch({required String text,required int offset,required int limit})async{
  return await[_qmGetLrcBySearch,_neGetLrcBySearch][_settingController.apiIndex.value](text: text,offset: offset,limit: limit);
}

