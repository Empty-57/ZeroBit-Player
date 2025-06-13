
import 'package:zerobit_player/HIveCtrl/hive_manager.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';
import 'package:get/get.dart';

import '../src/rust/api/music_tag_tool.dart';

class MusicCacheController extends GetxController{
  final items=<MusicCache>[].obs;

  final _musicCacheBox=HiveManager.musicCacheBox;

   @override
  void onInit() {
    loadData();
    super.onInit();
  }

  void loadData(){
    items.value=_musicCacheBox.getAll();
  }

  void putMetadata({required String path,required int index,required EditableMetadata data})async{
     await editTags(path: path, data: data);
     final newMetadata = await getMetadata(path: path);
     final newCache=MusicCache(
       title: newMetadata.title,
        artist: newMetadata.artist,
        album: newMetadata.album,
        genre: newMetadata.genre,
        duration: newMetadata.duration,
        bitrate: newMetadata.bitrate,
        sampleRate: newMetadata.sampleRate,
        path: newMetadata.path,
      );
     _musicCacheBox.put(data: newCache, key: path);
     items[index]=newCache;
  }
}