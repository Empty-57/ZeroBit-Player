import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pinyin/pinyin.dart';
import 'package:zerobit_player/HIveCtrl/hive_manager.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/search.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/audio_ctrl_mixin.dart';


class MusicCacheController extends GetxController with AudioControllerGenClass {

  @override
  final items = <MusicCache>[].obs;

  final artistItemsDict=SplayTreeMap<String, List<String>>((a,b)=>a.compareTo(b)).obs;
  final artistHasLetter=<String>[].obs;

  final albumItemsDict=SplayTreeMap<String, List<String>>((a,b)=>a.compareTo(b)).obs;
  final albumHasLetter=<String>[].obs;

  final _musicCacheBox = HiveManager.musicCacheBox;
  final SettingController _settingController = Get.find<SettingController>();

  final currentScanAudio = ''.obs;

  final searchText=''.obs;

  final searchResult=<MusicCache>[].obs;

  @override
  void onInit() {
    loadData();
    super.onInit();

    debounce(searchText, (_){
      search(searchResult: searchResult, items: items, searchText: searchText.value);
    },time: Duration(milliseconds: 500));

  }

  void loadData() {
    items.value = _musicCacheBox.getAll();
    itemReSort(type: _settingController.sortMap[OperateArea.allMusic]);
    _loadItem4Artist();
    _loadItem4Album();
  }

  String _getLetter({required String str}){
    final str_=str.trim();
    if(str_.isEmpty){
      return '#';
    }

    final String letter=PinyinHelper.getFirstWordPinyin(str_[0]);

    if(letter.isEmpty){
      final String letter=str_[0].toUpperCase();
      return letter.contains(RegExp(r'[A-Z]'))? letter:'#';
    }
    return letter[0].toUpperCase();
  }

  void _loadItem4Artist(){
    artistItemsDict.value.clear();
    artistHasLetter.clear();
    for (var v in items) {
      v.artist.split('/').forEach((i){
        final String letter=_getLetter(str: i);
        artistItemsDict.value.putIfAbsent(letter+i, ()=><String>[]).add(v.path);
        artistHasLetter.addIf(!artistHasLetter.contains(letter),letter);
      });
    }
    artistHasLetter.sort((a,b)=>a.compareTo(b));
  }

  void _loadItem4Album(){
    albumItemsDict.value.clear();
    albumHasLetter.clear();
    for (var v in items) {
      String album=v.album;
      if(album.isEmpty){
        album='UNKNOWN';
      }
      final String letter=_getLetter(str: album);
      albumItemsDict.value.putIfAbsent(letter+album, ()=><String>[]).add(v.path);
      albumHasLetter.addIf(!albumHasLetter.contains(letter), letter);
    }
    albumHasLetter.sort((a,b)=>a.compareTo(b));
  }

  Future<void> remove({required MusicCache metadata}) async {
    items.removeWhere((v) => v.path == metadata.path);
    await HiveManager.musicCacheBox.del(key: md5.convert(utf8.encode(metadata.path)).toString());
  }

  MusicCache putMetadata({
    required String path,
    required int index,
    required EditableMetadata data,
  }) {

    editTags(path: path, data: data);
    final oldCache=items[index];
    final newCache = MusicCache(
      title: data.title??path,
      artist: data.artist??"UNKNOWN",
      album: data.album??"UNKNOWN",
      genre: data.genre??"UNKNOWN",
      duration: oldCache.duration,
      bitrate: oldCache.bitrate,
      sampleRate: oldCache.sampleRate,
      path: oldCache.path,
    );
    _musicCacheBox.put(data: newCache, key: md5.convert(utf8.encode(path)).toString());
    items[index] = newCache;
    return newCache;
  }
}
