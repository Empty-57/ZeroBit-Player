import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/getxController/play_list_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';

import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/music_cahce_model.dart';
import '../field/audio_source.dart';
import '../tools/tag_suffix.dart';
import 'music_cache_ctrl.dart';

enum AudioState { stop, playing, pause }

class AudioController extends GetxController {
  final currentPath = ''.obs;
  final currentIndex = (-1).obs;
  final currentMs100 = 0.0.obs;
  final progress = 0.0.obs;

  final currentState = AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
  final AudioSource _audioSource = Get.find<AudioSource>();
  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  late List<MusicCache> playListCacheItems = [..._musicCacheController.items];

  MusicCache? _hasNextAudioMetadata;

  List get allUserKey => _userPlayListCacheBox.getKeyAll();

  final currentCover=kTransparentImage.obs;

  void syncPlayListCacheItems() {
    if (allUserKey.contains(_audioSource.currentAudioSource.value)) {
      playListCacheItems =
          _musicCacheController.items
              .where(
                (v) => _userPlayListCacheBox
                    .get(key: _audioSource.currentAudioSource.value)!
                    .pathList
                    .contains(v.path),
              )
              .toList();
      return;
    }

    switch (_audioSource.currentAudioSource.value) {
      case AudioSource.allMusic:
        playListCacheItems = [..._musicCacheController.items];
        return;
    }
  }

  @override
  void onInit() {
    super.onInit();

    ever(currentMs100, (_) {
      if (currentIndex.value != -1 &&
          playListCacheItems.isNotEmpty &&
          currentIndex.value < playListCacheItems.length) {
        progress.value = (currentMs100.value /
                playListCacheItems[currentIndex.value].duration)
            .clamp(0.0, 1.0);
      } else {
        progress.value = 0.0;
        currentMs100.value = 0.0;
      }
    });

    ever(_audioSource.currentAudioSource, (_) {
      syncPlayListCacheItems();
    });

    ever(currentIndex, (_) async {
      if (currentIndex.value == -1) {
        windowManager.setTitle('ZeroBit Player');
        return;
      }
      if (_settingController.dynamicThemeColor.value) {
        await _setThemeColor4Cover();
      }
      windowManager.setTitle("${playListCacheItems[currentIndex.value].title} - ${playListCacheItems[currentIndex.value].artist}");
    });

    ever(currentPath, (_) async {
      if (currentPath.value == '') {
        return;
      }

      currentCover.value=await getCover(path: currentPath.value, sizeFlag: 1)??kTransparentImage;
      await smtcUpdateMetadata(title: playListCacheItems[currentIndex.value].title, artist: playListCacheItems[currentIndex.value].artist, album: playListCacheItems[currentIndex.value].album, coverSrc: currentCover.value);
    });

  }

  Future<void> _setThemeColor4Cover() async {
    final src =
        playListCacheItems[currentIndex.value].src ??
        await getCover(
          path: playListCacheItems[currentIndex.value].path,
          sizeFlag: 0,
        ) ??
        kTransparentImage;
    final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
      MemoryImage(src),
      size: Size(150, 150),
    );

    if (generator.dominantColor != null) {
      _settingController.themeColor.value =
          generator.dominantColor!.color.toARGB32();
      _settingController.putCache();
    }
  }

  void syncCurrentIndex() {
    currentIndex.value = playListCacheItems.indexWhere(
      (metadata) => metadata.path == currentPath.value,
    );
  }

  Future<void> audioPlay({required MusicCache metadata}) async {
    final oldPath = currentPath.value;
    final oldIndex = currentIndex.value;
    final oldState = currentState.value;

    currentMs100.value = 0.0;
    try {
      currentPath.value = metadata.path;

      if (!playListCacheItems.any((v) => v.path == metadata.path)) {
        playListCacheItems.add(metadata);
      }

      syncCurrentIndex();
      currentState.value = AudioState.playing;
      await smtcUpdateState(state: currentState.value.index);
      await playFile(path: metadata.path);
    } catch (e) {
      currentPath.value = oldPath;
      currentIndex.value = oldIndex;
      currentState.value = oldState;
      currentMs100.value = 0.0;

      debugPrint(e.toString());
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR:", msg: e.toString());
    }
  }

  Future<void> audioResume() async {
    if (currentIndex.value == -1 || currentState.value == AudioState.playing) {
      return;
    }
    currentState.value = AudioState.playing;
    try {
      await smtcUpdateState(state: currentState.value.index);
      await resume();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  Future<void> audioPause() async {
    if (currentIndex.value == -1 || currentState.value == AudioState.pause) {
      return;
    }
    currentState.value = AudioState.pause;
    try {
      await smtcUpdateState(state: currentState.value.index);
      await pause();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  Future<void> audioStop() async {
    currentState.value = AudioState.stop;
    currentIndex.value = -1;
    try {
      await smtcUpdateState(state: currentState.value.index);
      await stop();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  Future<void> audioToggle() async {
    if (currentIndex.value == -1) {
      return;
    }
    if (currentState.value == AudioState.stop ||
        currentState.value == AudioState.pause) {
      currentState.value = AudioState.playing;
    } else {
      currentState.value = AudioState.pause;
    }
    try {
      await smtcUpdateState(state: currentState.value.index);
      await toggle();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  Future<double> audioGetVolume() async {
    try {
      return await getVolume();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
      return 0.0;
    }
  }

  Future<void> audioSetVolume({required double vol}) async {
    try {
      await setVolume(vol: vol);
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  Future<void> audioSetPositon({required double pos}) async {
    if (currentIndex.value == -1) {
      return;
    }
    try {
      await setPosition(pos: pos);
      await audioResume();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  void changePlayMode() {
    _settingController.playMode.value++;
    if (_settingController.playMode.value > 2 ||
        _settingController.playMode.value < 0) {
      _settingController.playMode.value = 0;
    }
    _settingController.putCache();
  }

  Future<void> _maybeRandomPlay() async {
    if (_settingController.playMode.value == 2&&playListCacheItems.length>1) {
      syncCurrentIndex();
      for(int i=0;i<10;i++){
        final index=Random().nextInt(playListCacheItems.length);
        if(index!=currentIndex.value){
          currentIndex.value=index;
          break;
        }
      }

    }

    if (_hasNextAudioMetadata != null) {
      await audioPlay(metadata: _hasNextAudioMetadata!);
      _hasNextAudioMetadata = null;
      return;
    }

    await audioPlay(metadata: playListCacheItems[currentIndex.value]);
  }

  Future<void> audioToPrevious() async {
    if (currentIndex.value == -1) {
      return;
    }

    if(_settingController.playMode.value != 2){
      currentIndex.value--;
    if (currentIndex.value < 0) {
      currentIndex.value = playListCacheItems.length - 1;
    }
    }


    await _maybeRandomPlay();
  }

  Future<void> audioToNext() async {
    if (currentIndex.value == -1) {
      return;
    }

    if(_settingController.playMode.value != 2){

    if (currentIndex.value < playListCacheItems.length-1) {
      currentIndex.value++;
    if (currentIndex.value > playListCacheItems.length - 1) {
      currentIndex.value = 0;
    }
    }



    await _maybeRandomPlay();
  }

  Future<void> audioAutoPlay() async {
    if (currentIndex.value == -1) {
      return;
    }
    switch (_settingController.playMode.value) {
      case 0:
        await audioPlay(metadata: playListCacheItems[currentIndex.value]);
        break;
      case 1:
        await audioToNext();
        break;
      case 2:
        await _maybeRandomPlay();
        break;
    }
  }

  void insertNext({required MusicCache metadata}) {
    if (currentIndex.value == -1 ||
        playListCacheItems[currentIndex.value].path == metadata.path) {
      showSnackBar(
        title: "WARNING",
        msg: "无效操作！",
        duration: Duration(milliseconds: 1500),
      );
      return;
    }
    playListCacheItems.remove(metadata);
    final toIndex =
        (playListCacheItems.indexWhere((v) => v.path == currentPath.value) + 1)
            .clamp(0, playListCacheItems.length);
    playListCacheItems.insert(toIndex, metadata);

    syncCurrentIndex();
    showSnackBar(
      title: "OK",
      msg: "已将 ${metadata.title} 添加到下一首播放",
      duration: Duration(milliseconds: 1500),
    );
    _hasNextAudioMetadata = metadata;
  }

  void addToAudioList({required MusicCache metadata, required String userKey}) {
    if (!allUserKey.contains(userKey)) {
      return;
    }
    List<String> newList = _userPlayListCacheBox.get(key: userKey)!.pathList;
    if (newList.contains(metadata.path)) {
      showSnackBar(
        title: "WARNING",
        msg:
            "歌单 ${userKey.split(playListTagSuffix)[0]} 存在重复歌曲 ${metadata.title} ！",
        duration: Duration(milliseconds: 1500),
      );
      return;
    }
    newList.add(metadata.path);
    _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: newList, userKey: userKey),
      key: userKey,
    );

    if (_audioSource.currentAudioSource.value == userKey) {
      if (!playListCacheItems.any((v) => v.path == metadata.path)) {
        playListCacheItems.add(metadata);
        syncCurrentIndex();
      }
    }

    showSnackBar(
      title: "OK",
      msg: "已将 ${metadata.title} 添加到歌单 ${userKey.split(playListTagSuffix)[0]}",
      duration: Duration(milliseconds: 1500),
    );
  }

  void addAllToAudioList({required List<MusicCache> selectedList, required String userKey,}) {
    if (!allUserKey.contains(userKey)) {
      return;
    }

    if(selectedList.isEmpty){
      showSnackBar(
      title: "WARNING",
      msg: "未选择音频！",
      duration: Duration(milliseconds: 1500),
    );
      return;
    }

    List<String> newList = _userPlayListCacheBox.get(key: userKey)!.pathList;

    selectedList.removeWhere((v) => newList.contains(v.path));

    final l = selectedList.length;

    newList.addAll(selectedList.map((v) => v.path));

    _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: newList, userKey: userKey),
      key: userKey,
    );

    selectedList.removeWhere(
      (v) => playListCacheItems.any((p) => p.path == v.path),
    );

    if (_audioSource.currentAudioSource.value == userKey) {
      playListCacheItems.addAll(selectedList);
      syncCurrentIndex();
    }

    showSnackBar(
      title: "OK",
      msg: "已将去重后的 $l 首歌添加到歌单 ${userKey.split(playListTagSuffix)[0]}",
      duration: Duration(milliseconds: 1500),
    );
  }

  Future<void> audioRemove({required String userKey, required MusicCache metadata,}) async {
    switch (userKey) {
      case AudioSource.allMusic:
        await _musicCacheController.remove(metadata: metadata);
        break;
    }

    if (allUserKey.contains(userKey)) {
      final List<String> newList =
          _userPlayListCacheBox.get(key: userKey)!.pathList;
      newList.remove(metadata.path);

      PlayListController.audioListItems.removeWhere(
        (v) => v.path == metadata.path,
      );
      _userPlayListCacheBox.put(
        data: UserPlayListCache(pathList: newList, userKey: userKey),
        key: userKey,
      );

      if (_audioSource.currentAudioSource.value == userKey) {
        playListCacheItems.remove(metadata);
        syncCurrentIndex();
      }

      showSnackBar(
        title: "OK",
        msg:
            "已将 ${metadata.title} 从歌单 ${userKey.split(playListTagSuffix)[0]}删除！",
        duration: Duration(milliseconds: 1500),
      );
    }
  }

  void audioRemoveAll({required String userKey, required List<MusicCache> removeList,}) {
    if (!allUserKey.contains(userKey)) {
      return;
    }

    if(removeList.isEmpty){
      showSnackBar(
      title: "WARNING",
      msg: "未选择音频！",
      duration: Duration(milliseconds: 1500),
    );
      return;
    }

    List<String> newList = _userPlayListCacheBox.get(key: userKey)!.pathList;

    newList.removeWhere((v) => removeList.any((p) => p.path == v));

    _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: newList, userKey: userKey),
      key: userKey,
    );

    if (_audioSource.currentAudioSource.value == userKey) {
      playListCacheItems.removeWhere(
        (v) => removeList.any((p) => p.path == v.path),
      );
      syncCurrentIndex();
    }

    PlayListController.audioListItems.removeWhere(
      (v) => removeList.any((p) => p.path == v.path),
    );

    showSnackBar(
      title: "OK",
      msg:
          "已将去重后的 ${removeList.length} 首歌从歌单 ${userKey.split(playListTagSuffix)[0]}删除！",
      duration: Duration(milliseconds: 1500),
    );
  }
}
