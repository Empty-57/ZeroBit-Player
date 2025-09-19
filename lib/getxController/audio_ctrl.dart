import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/getxController/folders_list_ctrl.dart';
import 'package:zerobit_player/getxController/play_list_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/getxController/user_playlist_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/tools/lrcTool/get_lyrics.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import '../API/apis.dart';
import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/music_cache_model.dart';
import '../field/audio_source.dart';
import '../field/tag_suffix.dart';
import 'album_list_crl.dart';
import 'artist_list_ctrl.dart';
import 'music_cache_ctrl.dart';

enum AudioState { stop, playing, pause }

class AudioController extends GetxController {
  final currentPath = ''.obs;
  final currentIndex = (-1).obs;
  final currentMs100 = 0.0.obs;
  final currentSec = 0.0.obs;
  final progress = 0.0.obs;

  late final Rx<MusicCache> currentMetadata =
      MusicCache(
        title: '',
        artist: '',
        album: '',
        genre: '',
        duration: 9999,
        bitrate: null,
        sampleRate: null,
        path: '',
        src: null,
      ).obs;

  final currentDuration=0.0.obs;

  final currentState = AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
  final AudioSource _audioSource = Get.find<AudioSource>();
  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  final UserPlayListController _userPlayListController =
      Get.find<UserPlayListController>();

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  late final RxList<MusicCache> playListCacheItems =
      [..._musicCacheController.items].obs;

  MusicCache? _hasNextAudioMetadata;

  List get allUserKey => _userPlayListCacheBox.getKeyAll();

  final currentCover = kTransparentImage.obs;

  final currentSpeed=(1.0).obs;

  bool _isSyncing = false;

  final currentLyrics = Rxn<ParsedLyricModel>();

  void syncPlayListCacheItems() {
    if (allUserKey.contains(_audioSource.currentAudioSource.value)) {
      playListCacheItems.value =
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

    if (_musicCacheController.artistItemsDict.value.keys.any(
      (v) =>
          v.substring(1) + TagSuffix.artistList ==
          _audioSource.currentAudioSource.value,
    )) {
      playListCacheItems.value = [...ArtistListController.audioListItems];
      return;
    }

    if (_musicCacheController.albumItemsDict.value.keys.any(
      (v) =>
          v.substring(1) + TagSuffix.albumList ==
          _audioSource.currentAudioSource.value,
    )) {
      playListCacheItems.value = [...AlbumListController.audioListItems];
      return;
    }

    if (_settingController.folders.any(
      (v) =>
          v + TagSuffix.foldersList ==
          _audioSource.currentAudioSource.value,
    )) {
      playListCacheItems.value = [...FoldersListController.audioListItems];
      return;
    }

    switch (_audioSource.currentAudioSource.value) {
      case AudioSource.allMusic:
        playListCacheItems.value = [..._musicCacheController.items];
        return;
    }
  }

  @override
  void onInit() {
    super.onInit();

    ever(currentMs100, (_) {
      if (currentDuration.value > 0 &&
          currentMetadata.value.path.isNotEmpty &&
          playListCacheItems.isNotEmpty) {
        progress.value = (currentMs100.value / currentDuration.value)
            .clamp(0.0, 1.0);
      } else {
        progress.value = 0.0;
        currentMs100.value = 0.0;
      }
    });

    ever(_audioSource.currentAudioSource, (_) {
      syncPlayListCacheItems();
    });

    ever(currentMetadata, (_) async {
      currentMs100.value = 0;
      currentSec.value = 0;
      try {
        _syncInfo();
      } catch (e) {
        debugPrint(e.toString());
        _isSyncing = false;
      }

      currentLyrics.value = await getParsedLyric(
        filePath: currentMetadata.value.path,
      );
      debugPrint(currentLyrics.value?.type.toString());
    });
  }

  void _syncInfo() async {
    if (_isSyncing) {
      return;
    }

    if (currentMetadata.value.path.isEmpty) {
      windowManager.setTitle('ZeroBit Player');
      return;
    }
    _isSyncing = true;
    if (_settingController.dynamicThemeColor.value) {
      await _setThemeColor4Cover();
    }

    if(currentMetadata.value.duration<=0){
      currentDuration.value=await getLen();
    }
    else{
      currentDuration.value=currentMetadata.value.duration;
    }

    final title = currentMetadata.value.title;
    final artist =
        (currentMetadata.value.artist.isNotEmpty &&
                currentMetadata.value.artist != 'UNKNOWN')
            ? ' - ${currentMetadata.value.artist}'
            : '';

    final coverData = await getCover(path: currentPath.value, sizeFlag: 1);

    if (coverData != null && coverData.isNotEmpty) {
      currentCover.value = coverData;
    } else {
      final coverDataNet = await saveCoverByText(
        text: title + artist,
        songPath: currentMetadata.value.path,
        saveCover: false,
      );

      if (coverDataNet != null && coverDataNet.isNotEmpty) {
        currentCover.value = Uint8List.fromList(coverDataNet);
      } else {
        currentCover.value = kTransparentImage;
      }
    }

    if (currentMetadata.value.src == null ||
        currentMetadata.value.src!.isEmpty) {
      currentMetadata.value.src =
          await getCover(path: currentPath.value, sizeFlag: 0) ??
          playListCacheItems
              .firstWhere((v) => v.path == currentPath.value)
              .src ??
          kTransparentImage;
    }

    windowManager.setTitle(title + artist);
    await smtcUpdateMetadata(
      title: currentMetadata.value.title,
      artist: currentMetadata.value.artist,
      album: currentMetadata.value.album,
      coverSrc: currentCover.value,
    );
    debugPrint("currentIndex:set");
    _isSyncing = false;
  }

  Future<void> _setThemeColor4Cover() async {
    if (currentMetadata.value.path.isEmpty) {
      return;
    }
    final src =
        currentMetadata.value.src ??
        await getCover(path: currentMetadata.value.path, sizeFlag: 0) ??
        kTransparentImage;
    final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
      MemoryImage(src),
      size: Size(150, 150),
    );

    if (generator.vibrantColor != null) {
      _settingController.themeColor.value =
          generator.vibrantColor!.color.toARGB32();
      _settingController.putCache();
      return;
    }

    if (generator.mutedColor != null) {
      _settingController.themeColor.value =
          generator.mutedColor!.color.toARGB32();
      _settingController.putCache();
      return;
    }

    if (generator.dominantColor != null) {
      _settingController.themeColor.value =
          generator.dominantColor!.color.toARGB32();
      _settingController.putCache();
      return;
    }

    _settingController.themeColor.value = 0xff27272a;
    _settingController.putCache();
  }

  void syncCurrentIndex() {
    currentIndex.value = playListCacheItems.indexWhere(
      (metadata) => metadata.path == currentPath.value,
    );
  }

  Future<void> audioPlay({required MusicCache metadata}) async {
    currentMs100.value = 0.0;
    currentSec.value = 0.0;
    try {
      currentState.value = AudioState.playing;
      await smtcUpdateState(state: currentState.value.index);
      await playFile(path: metadata.path);

      if(currentSpeed.value!=1.0){
        await setSpeed(speed: currentSpeed.value);
      }

      currentPath.value = metadata.path;
      currentMetadata.value = metadata;

      if (!playListCacheItems.any((v) => v.path == metadata.path)) {
        playListCacheItems.add(metadata);
      }

      syncCurrentIndex();

    } catch (e) {
      currentMs100.value = 0.0;
      currentSec.value = 0.0;

      debugPrint(e.toString());
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR:", msg: e.toString());
    }
  }

  Future<void> audioResume() async {
    if (currentMetadata.value.path.isEmpty ||
        playListCacheItems.isEmpty ||
        currentState.value == AudioState.playing) {
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
    if (currentMetadata.value.path.isEmpty ||
        playListCacheItems.isEmpty ||
        currentState.value == AudioState.pause) {
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
    if (currentMetadata.value.path.isEmpty || playListCacheItems.isEmpty) {
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
    if (currentMetadata.value.path.isEmpty) {
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
    if (_settingController.playMode.value >= 0 &&
        _settingController.playMode.value < 2) {
      _settingController.playMode.value++;
    } else {
      _settingController.playMode.value = 0;
    }
    _settingController.putCache();
  }

  void changeLrcAlignment() {
    if (_settingController.lrcAlignment.value >= 0 &&
        _settingController.lrcAlignment.value < 2) {
      _settingController.lrcAlignment.value++;
    } else {
      _settingController.lrcAlignment.value = 0;
    }
    _settingController.putCache();
  }

  Future<void> _maybeRandomPlay() async {
    if (_settingController.playMode.value == 2 &&
        playListCacheItems.length > 1) {
      syncCurrentIndex();
      for (int i = 0; i < 10; i++) {
        final index = Random().nextInt(playListCacheItems.length);
        if (index != currentIndex.value) {
          currentIndex.value = index;
          break;
        }
      }
    }

    if (_hasNextAudioMetadata != null) {
      await audioPlay(metadata: _hasNextAudioMetadata!);
      _hasNextAudioMetadata = null;
      return;
    }

    if (playListCacheItems.length == 1) {
      currentIndex.value = 0;
    }

    await audioPlay(metadata: playListCacheItems[currentIndex.value]);
  }

  Future<void> audioToPrevious() async {
    if (playListCacheItems.isEmpty) {
      return;
    }

    if (_settingController.playMode.value != 2) {
      if (currentIndex.value > 0) {
        currentIndex.value--;
      } else {
        currentIndex.value = playListCacheItems.length - 1;
      }
    }

    await _maybeRandomPlay();
  }

  Future<void> audioToNext() async {
    if (playListCacheItems.isEmpty) {
      return;
    }

    if (_settingController.playMode.value != 2) {
      if (currentIndex.value < playListCacheItems.length - 1 &&
          currentIndex.value >= 0) {
        currentIndex.value++;
      } else {
        currentIndex.value = 0;
      }
    }

    await _maybeRandomPlay();
  }

  Future<void> audioAutoPlay() async {
    if (playListCacheItems.isEmpty) {
      return;
    }
    switch (_settingController.playMode.value) {
      case 0:
        await audioPlay(metadata: currentMetadata.value);
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
    if (currentMetadata.value.path.isEmpty ||
        currentMetadata.value.path == metadata.path) {
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

  void addToAudioList({required MusicCache metadata, required String userKey}) async{
    if (!allUserKey.contains(userKey)) {
      return;
    }
    List<String> newList = _userPlayListCacheBox.get(key: userKey)!.pathList;
    if (newList.contains(metadata.path)) {
      showSnackBar(
        title: "WARNING",
        msg:
            "歌单 ${userKey.split(TagSuffix.playList)[0]} 存在重复歌曲 ${metadata.title} ！",
        duration: Duration(milliseconds: 1500),
      );
      return;
    }
    newList.add(metadata.path);
    await _userPlayListCacheBox.put(
      data: UserPlayListCache(pathList: newList, userKey: userKey),
      key: userKey,
    );

    if (_audioSource.currentAudioSource.value == userKey) {
      if (!playListCacheItems.any((v) => v.path == metadata.path)) {
        playListCacheItems.add(metadata);
        syncCurrentIndex();
      }
    }

    _userPlayListController.initHive();

    showSnackBar(
      title: "OK",
      msg: "已将 ${metadata.title} 添加到歌单 ${userKey.split(TagSuffix.playList)[0]}",
      duration: Duration(milliseconds: 1500),
    );
  }

  void addAllToAudioList({required List<MusicCache> selectedList, required String userKey,}) async{
    if (!allUserKey.contains(userKey)) {
      return;
    }

    if (selectedList.isEmpty) {
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

    await _userPlayListCacheBox.put(
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

    _userPlayListController.initHive();

    showSnackBar(
      title: "OK",
      msg: "已将去重后的 $l 首歌添加到歌单 ${userKey.split(TagSuffix.playList)[0]}",
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
            "已将 ${metadata.title} 从歌单 ${userKey.split(TagSuffix.playList)[0]}删除！",
        duration: Duration(milliseconds: 1500),
      );
    }
  }

  void audioRemoveAll({required String userKey, required List<MusicCache> removeList,}) async{
    if (!allUserKey.contains(userKey)) {
      return;
    }

    if (removeList.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "未选择音频！",
        duration: Duration(milliseconds: 1500),
      );
      return;
    }

    List<String> newList = _userPlayListCacheBox.get(key: userKey)!.pathList;

    newList.removeWhere((v) => removeList.any((p) => p.path == v));

    await _userPlayListCacheBox.put(
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
          "已将去重后的 ${removeList.length} 首歌从歌单 ${userKey.split(TagSuffix.playList)[0]}删除！",
      duration: Duration(milliseconds: 1500),
    );
  }

  Future<void> audioListSyncMetadata({required String path, required MusicCache newCache,})async{
    if(playListCacheItems.isEmpty||path!=currentMetadata.value.path){
      return;
    }
    audioSetPositon(pos: currentMs100.value);
    playListCacheItems[playListCacheItems.indexWhere((v) => v.path == path)] =
        newCache;
    currentMetadata.value = newCache;
    currentCover.value =
        await getCover(path: currentPath.value, sizeFlag: 1) ??
        kTransparentImage;
  }

  void searchInsert({required MusicCache metadata}) {
    if (!playListCacheItems.any((v) => v.path == metadata.path)) {
      playListCacheItems.add(metadata);
    }
    audioPlay(metadata: metadata);
  }
}
