import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:tray_manager/tray_manager.dart';
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
import '../components/spring_list_view.dart';
import '../field/audio_source.dart';
import '../field/tag_suffix.dart';
import 'album_list_crl.dart';
import 'artist_list_ctrl.dart';
import 'music_cache_ctrl.dart';

enum AudioState { stop, playing, pause, ended }

enum GetBuilderId { lyricRender }

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
        trackNumber: 0,
        genre: '',
        duration: 9999,
        bitrate: null,
        sampleRate: null,
        bitDepth: 16,
        channels: 1,
        path: '',
        src: null,
      ).obs;

  final currentDuration = 0.0.obs;

  final currentState = AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
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
  final currentSmallCover = kTransparentImage.obs;

  final currentSpeed = (1.0).obs;

  bool _isSyncing = false;

  final currentLyrics = Rxn<ParsedLyricModel>();

  final audioFFT = <double>[].obs;

  final _defaultFFT = List<double>.generate(bassDataFFT512, (i) => 0.0);

  static const bassDataFFT512 = 256;

  final _unplayedIndex = <int>[];

  final navigationIsExtend = true.obs;

  final coverPalette =
      <Color>[Colors.red, Colors.yellow, Colors.blue, Colors.green].obs;

  int reTryCount = 0;

  // 这里预先缓存已处理歌词数据
  List lineTextList = [];
  List<String> translateList = [];
  List<double> startTime = [];
  List<String> romaList = [];
  List<double> lineDurationList = [];

  bool showLyricRender = false;

  String currentlyricType = LyricFormat.lrc;

  bool _isFftCleared = true;

  String currentAudioSource = AudioSource.allMusic;

  SpringController get _springController => Get.find<SpringController>();

  /// 获取音频FFT数据
  void getAudioFFt() async {
    if (currentState.value == AudioState.pause ||
        currentState.value == AudioState.stop) {
      if (!_isFftCleared) {
        audioFFT.value = _defaultFFT;
        _isFftCleared = true;
      }
      return;
    }

    final fft = await getChanData();
    if (fft != null) {
      audioFFT.value = fft;
      _isFftCleared = false;
    }
  }

  @override
  void onInit() async {
    super.onInit();

    ever(currentMs100, (_) {
      if (currentDuration.value > 0 &&
          currentMetadata.value.path.isNotEmpty &&
          playListCacheItems.isNotEmpty) {
        progress.value = (currentMs100.value / currentDuration.value).clamp(
          0.0,
          1.0,
        );
      } else {
        progress.value = 0.0;
        currentMs100.value = 0.0;
      }
    });

    ever(currentMetadata, (_) async {
      currentMs100.value = 0;
      currentSec.value = 0;
      try {
        await _syncInfo();
      } catch (e) {
        debugPrint(e.toString());
        _isSyncing = false;
      }
      _settingController.lastAudioInfo[SettingController.lastAudioMetadataKey] =
          currentMetadata.value;
      await _settingController.putScalableCache();
      await _loadLyrics(currentMetadata.value.path);
    });
  }

  Future<void> initRestoreState() async {
    try {
      final lastMetadata =
          _settingController.lastAudioInfo[SettingController
                  .lastAudioMetadataKey]
              as MusicCache;
      if (playListCacheItems.isEmpty || lastMetadata.path.isEmpty) return;

      currentMetadata.value = lastMetadata;
      currentPath.value = lastMetadata.path;
      await setVolume(vol: 0.0);
      await audioPlay(metadata: lastMetadata);
      await audioPause();
      await setVolume(vol: _settingController.volume.value);

      // sync_cache 已经先执行了一次
      // 此操作放在这个位置的原因： 需要等待 main.dart 中的 await syncCache()先执行完 ， 因为上面两行await任务排在await syncCache();之后
      final lastPlayPathList =
          _settingController.lastAudioInfo[SettingController
                  .lastAudioPlayPathListKey]
              as List<String>;
      if (lastPlayPathList.isNotEmpty) {
        final pathSet = lastPlayPathList.toSet();
        playListCacheItems.value =
            _musicCacheController.items
                .where((v) => pathSet.contains(v.path))
                .toList();
      }
    } catch (e) {
      debugPrint("Restore State Error: $e");
    }
  }

  Future<void> _loadLyrics(String path) async {
    currentLyrics.value = await getParsedLyric(filePath: path);
    if (Get.isRegistered<SpringListView>()) {
      _springController.clearState();
    }

    final parsedLrc = currentLyrics.value?.parsedLrc;
    showLyricRender = parsedLrc != null && parsedLrc.isNotEmpty;

    // 重要：在这里就处理歌词数据，渲染端直接用,防止内存泄露
    if (showLyricRender) {
      currentlyricType = currentLyrics.value!.type;
      lineTextList = parsedLrc!.map((v) => v.lyricText).toList();
      translateList = parsedLrc.map((v) => v.translate).toList();
      startTime = parsedLrc.map((v) => v.start).toList();
      romaList = parsedLrc.map((v) => v.roma).toList();
      lineDurationList = parsedLrc.map((v) => v.nextTime - v.start).toList();
    }
    update([GetBuilderId.lyricRender]);
  }

  Future<void> _syncInfo() async {
    if (_isSyncing) {
      return;
    }

    final metadata = currentMetadata.value;
    if (metadata.path.isEmpty) {
      await windowManager.setTitle('ZeroBit Player');
      try {
        await trayManager.setToolTip('ZeroBit Player');
      } catch (_) {}

      return;
    }
    _isSyncing = true;
    if (_settingController.dynamicThemeColor.value) {
      await _setThemeColor4Cover();
    }

    try {
      currentDuration.value = await getLen();
    } catch (_) {
      _isSyncing = false;
      currentDuration.value = 999;
    } // 防止读取的时间不准

    final title = metadata.title;
    final artist =
        (metadata.artist.isNotEmpty && metadata.artist != 'UNKNOWN')
            ? ' - ${metadata.artist}'
            : '';

    final coverData = await getCover(path: currentPath.value, sizeFlag: 1);

    if (coverData != null && coverData.isNotEmpty) {
      currentCover.value = coverData;
    } else {
      final coverDataNet = await saveCoverByText(
        text: title + artist,
        songPath: metadata.path,
        saveCover: false,
      );

      if (coverDataNet != null && coverDataNet.isNotEmpty) {
        currentCover.value = Uint8List.fromList(coverDataNet);
      } else {
        currentCover.value = kTransparentImage;
      }
    }

    currentSmallCover.value = metadata.src ?? kTransparentImage;
    if (metadata.src == null || metadata.src!.isEmpty) {
      currentSmallCover.value =
          await getCover(path: currentPath.value, sizeFlag: 0) ??
          kTransparentImage;
    }

    await windowManager.setTitle(title + artist);
    try {
      await trayManager.setToolTip(title + artist);
    } catch (_) {
      _isSyncing = false;
    }
    try {
      await smtcUpdateMetadata(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        coverSrc: currentCover.value,
      );
    } catch (_) {
      await smtcClear();
      await initSmtc();
      _isSyncing = false;
    }
    _isSyncing = false;
  }

  void _setThemeColor({required int color}) {
    _settingController.themeColor.value = color;
    final newColor = Color(color);
    if (!coverPalette.contains(newColor)) {
      coverPalette.insert(0, newColor);
    }
    _settingController.putCache();
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
      size: Size(120, 120),
    );

    if (generator.paletteColors.length >= 4) {
      coverPalette.value = generator.paletteColors
          .map((v) => v.color)
          .toList()
          .sublist(0, 4);
    } else {
      coverPalette.addAll([
        Colors.red,
        Colors.yellow,
        Colors.blue,
        Colors.green,
      ]);
    }

    if (generator.vibrantColor != null) {
      _setThemeColor(color: generator.vibrantColor!.color.toARGB32());
      return;
    }

    if (generator.mutedColor != null) {
      _setThemeColor(color: generator.mutedColor!.color.toARGB32());
      return;
    }

    if (generator.dominantColor != null) {
      _setThemeColor(color: generator.dominantColor!.color.toARGB32());
      return;
    }

    _setThemeColor(color: 0xff27272a);
  }

  /// 同步 `currentIndex`
  void syncCurrentIndex() {
    currentIndex.value = playListCacheItems.indexWhere(
      (metadata) => metadata.path == currentPath.value,
    );
  }

  /// 播放音频
  Future<void> audioPlay({required MusicCache metadata}) async {
    currentMs100.value = 0.0;
    currentSec.value = 0.0;
    final prevMetadata = currentMetadata.value;
    try {
      await smtcUpdateState(state: SMTCState.playing);
      await playFile(path: metadata.path);

      if (currentSpeed.value != 1.0) {
        await setSpeed(speed: currentSpeed.value);
      }

      currentPath.value = metadata.path;
      currentMetadata.value = metadata;

      if (!playListCacheItems.any((v) => v.path == metadata.path)) {
        playListCacheItems.add(metadata);
      }

      syncCurrentIndex();
      reTryCount = 0;
    } catch (e) {
      showSnackBar(title: "ERR:", msg: 'playingERR | $e');
      if (reTryCount > 4) {
        return;
      }
      await setVolume(vol: 0.0);
      await audioPlay(metadata: prevMetadata);
      await audioPause();
      await setVolume(vol: _settingController.volume.value);
      reTryCount++;
    }
  }

  /// 恢复播放
  Future<void> audioResume() async {
    if (currentMetadata.value.path.isEmpty ||
        playListCacheItems.isEmpty ||
        currentState.value == AudioState.playing) {
      return;
    }
    try {
      await smtcUpdateState(state: SMTCState.playing);
      await resume();
    } catch (e) {
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR", msg: 'resumeERR | $e');
    }
  }

  /// 暂停
  Future<void> audioPause() async {
    if (currentMetadata.value.path.isEmpty ||
        playListCacheItems.isEmpty ||
        currentState.value == AudioState.pause) {
      return;
    }
    try {
      await smtcUpdateState(state: SMTCState.paused);
      await pause();
    } catch (e) {
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR", msg: 'pauseERR | $e');
    }
  }

  /// 停止播放
  Future<void> audioStop() async {
    currentState.value = AudioState.stop;
    currentIndex.value = -1;
    try {
      await smtcUpdateState(state: SMTCState.paused);
      await stop();
    } catch (e) {
      showSnackBar(title: "ERR", msg: 'stopERR | $e');
    }
  }

  /// 切换播放 / 暂停
  Future<void> audioToggle() async {
    if (currentMetadata.value.path.isEmpty || playListCacheItems.isEmpty) {
      return;
    }
    try {
      await toggle();
      await smtcUpdateState(
        state:
            currentState.value == AudioState.playing
                ? SMTCState.playing
                : SMTCState.paused,
      );
    } catch (e) {
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  /// 获取音量
  Future<double> audioGetVolume() async {
    try {
      return await getVolume();
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
      return 0.0;
    }
  }

  /// 设置音量
  Future<void> audioSetVolume({required double vol}) async {
    try {
      await setVolume(vol: vol);
    } catch (e) {
      showSnackBar(title: "ERR", msg: e.toString());
    }
  }

  /// 跳转进度条
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

  /// 改变播放模式
  void changePlayMode() {
    _settingController.playMode.value =
        (_settingController.playMode.value + 1) % 3;
    _settingController.putCache();
  }

  /// 改变歌词对齐模式
  void changeLrcAlignment() {
    _settingController.lrcAlignment.value =
        (_settingController.lrcAlignment.value + 1) % 3;
    _settingController.putCache();
  }

  void _pickNextRandomIndex() {
    if (_unplayedIndex.isEmpty ||
        currentIndex.value >= playListCacheItems.length) {
      _unplayedIndex.clear();
      _unplayedIndex.addAll(
        List.generate(playListCacheItems.length, (i) => i)
          ..remove(currentIndex.value), // 避免连续播同一首
      );
      _unplayedIndex.shuffle();
    }
    currentIndex.value = _unplayedIndex.removeLast();
  }

  Future<void> _maybeRandomPlay() async {
    if (_settingController.playMode.value == 2 &&
        playListCacheItems.length > 1) {
      _pickNextRandomIndex();
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

  /// 上一首播放
  Future<void> audioToPrevious() async {
    if (playListCacheItems.isEmpty) {
      return;
    }

    if (_settingController.playMode.value != 2) {
      if (currentIndex.value > 0 &&
          currentIndex.value < playListCacheItems.length) {
        currentIndex.value--;
      } else {
        currentIndex.value = playListCacheItems.length - 1;
      }
    }

    await _maybeRandomPlay();
  }

  /// 下一首播放
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

  /// 自动播放
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

  /// 插入到下一首
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

  /// 用于向自定义歌单添加所选的音频
  void addToAudioList({
    required MusicCache metadata,
    required String userKey,
  }) async {
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

    if (currentAudioSource == userKey) {
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

  /// 用于向自定义歌单添加所选的所有音频
  /// 用于向自定义歌单添加所选的所有音频
  void addAllToAudioList({
    required List<MusicCache> selectedList,
    required String userKey,
  }) async {
    if (!allUserKey.contains(userKey)) return;

    if (selectedList.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "未选择音频！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final targetList = _userPlayListCacheBox.get(key: userKey)!;
    final existingPathSet = targetList.pathList.toSet();

    selectedList.removeWhere((v) => existingPathSet.contains(v.path));

    if (selectedList.isEmpty) {
      showSnackBar(
        title: "WARNING",
        msg: "重复添加！歌曲均已存在于歌单中。",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    final addedCount = selectedList.length;

    targetList.pathList.addAll(selectedList.map((v) => v.path));
    await _userPlayListCacheBox.put(data: targetList, key: userKey);

    final currentPlaySet = playListCacheItems.map((v) => v.path).toSet();
    selectedList.removeWhere((v) => currentPlaySet.contains(v.path));

    if (currentAudioSource == userKey) {
      playListCacheItems.addAll(selectedList);
      syncCurrentIndex();
    }

    _userPlayListController.initHive();

    showSnackBar(
      title: "OK",
      msg: "已将去重后的 $addedCount 首歌添加到歌单 ${userKey.split(TagSuffix.playList)[0]}",
      duration: const Duration(milliseconds: 1500),
    );
  }

  /// 用于从自定义歌单删除所选的音频
  Future<void> audioRemove({
    required String userKey,
    required MusicCache metadata,
  }) async {
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

      if (currentAudioSource == userKey) {
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

  /// 用于从自定义歌单删除所有所选的音频
  void audioRemoveAll({
    required String userKey,
    required List<MusicCache> removeList,
  }) async {
    if (!allUserKey.contains(userKey)) {
      return;
    }

    if (removeList.isEmpty || !allUserKey.contains(userKey)) {
      showSnackBar(
        title: "WARNING",
        msg: "未选择音频！",
        duration: Duration(milliseconds: 1500),
      );
      return;
    }

    final removePathSet = removeList.map((v) => v.path).toSet();
    final targetList = _userPlayListCacheBox.get(key: userKey)!;

    targetList.pathList.removeWhere((path) => removePathSet.contains(path));
    await _userPlayListCacheBox.put(data: targetList, key: userKey);

    if (currentAudioSource == userKey) {
      playListCacheItems.removeWhere((v) => removePathSet.contains(v.path));
      syncCurrentIndex();
    }

    PlayListController.audioListItems.removeWhere(
      (v) => removePathSet.contains(v.path),
    );

    showSnackBar(
      title: "OK",
      msg:
          "已将去重后的 ${removeList.length} 首歌从歌单 ${userKey.split(TagSuffix.playList)[0]}删除！",
      duration: Duration(milliseconds: 1500),
    );
  }

  /// 用于同步元数据更改
  Future<void> audioListSyncMetadata({
    required String path,
    required MusicCache newCache,
  }) async {
    if (playListCacheItems.isEmpty || path != currentMetadata.value.path) {
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

  /// 若 `metadata` 不在 `playListCacheItems` 内 则添加并播放
  void searchInsert({required MusicCache metadata}) {
    if (!playListCacheItems.any((v) => v.path == metadata.path)) {
      playListCacheItems.add(metadata);
    }
    audioPlay(metadata: metadata);
  }
}
