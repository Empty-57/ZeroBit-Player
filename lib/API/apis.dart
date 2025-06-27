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

Future<dynamic> _saveNetCover({required String songPath, required String picUrl,}) async {
  try{
    final pic = await _dio.get(
    picUrl,
    options: Options(responseType: ResponseType.bytes),
  );

    if (pic.data != null) {
    await editCover(path: songPath, src: Uint8List.fromList(pic.data));
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

Future<dynamic> _qmSaveCoverByText({required String text, required String songPath,}) async {
  String? picUrl;
  try {
    final data = await _qmSearchByText(text: text, offset: 1, limit: 1);
    final mid = data["data"]["song"]["list"][0]["albummid"];
    if (mid != null) {
      picUrl = "https://y.gtimg.cn/music/photo_new/T002R800x800M000$mid.jpg";
      return await _saveNetCover(songPath: songPath, picUrl: picUrl);
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

  if(response.data!=null){
    final data=response.data.toString();
    final regex = RegExp(r'CDATA\[(\S+)]]');
    final List<String?> lrcTs = []; //original,ts,roma

  for (final match in regex.allMatches(data)) {
    final extracted = match.group(1);
    if (extracted != null) {
      lrcTs.add(extracted);
    }
  }

  lrcTs[0]= await qrcDecrypt(encryptedQrc: lrcTs[0],isLocal: false);
  lrcTs[1]= await qrcDecrypt(encryptedQrc: lrcTs[1],isLocal: false);

    return {
      "lrc":null,
      "qrc": lrcTs[0],
      "translate": lrcTs[1],
      "type": '.qrc',
    };
  }
return null;
}

Future<List<Map<String, dynamic>>?> _qmGetLrcBySearch({required String text,required int offset,required int limit})async{
final List<Map<String,dynamic>> lrcData=[];
  try {
    final data=await _qmSearchByText(text: text,offset: offset,limit: limit);
    if (data["data"]["song"]["list"].isEmpty){
      return null;
    }
    for (final item in data["data"]["song"]["list"]) {
      final data=await _qmGetLrc(id:item["songid"]);
      if (data==null){
        continue;
      }

      lrcData.add({
        "name": item["songname"],
        "id": item["songid"],
        "artist": item["singer"][0]["name"]??'UNKNOWN',
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

Future<dynamic> _neSaveCoverByText({required String text, required String songPath,}) async {
  String? picUrl;
  try {
    final data = await _neSearchByText(text: text, offset: 1, limit: 1);
    if (data["result"]["songCount"] > 0) {
      final picUrl = data["result"]["songs"][0]["al"]["picUrl"];
      return await _saveNetCover(songPath: songPath, picUrl: picUrl);
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

if (response.data!=null){
  final data=jsonDecode(response.data);
    return {
      "lrc": data["lrc"]["lyric"],
      "yrc": data["yrc"]["lyric"],
      "translate": data["tlyric"]["lyric"],
      "type": data["yrc"]["lyric"].isNotEmpty? ".yrc":".lrc",
    };
  }
  return null;

}

Future<List<Map<String, dynamic>>?> _neGetLrcBySearch({required String text,required int offset,required int limit})async{
  final List<Map<String,dynamic>> lrcData=[];
  try {
    final data=await _neSearchByText(text: text,offset: offset,limit: limit);
    if (data["result"]["songs"].isEmpty){
      return null;
    }

    for (final item in data["result"]["songs"]) {
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


Future<dynamic> saveCoverByText({required String text, required String songPath,}) async {
  return await[_qmSaveCoverByText,_neSaveCoverByText][_settingController.apiIndex.value](text: text, songPath: songPath);
}

Future<dynamic> getLrcBySearch({required String text,required int offset,required int limit})async{
  return await[_qmGetLrcBySearch,_neGetLrcBySearch][_settingController.apiIndex.value](text: text,offset: offset,limit: limit);
}

