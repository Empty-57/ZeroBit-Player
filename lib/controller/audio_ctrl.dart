import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/tools/lrcTool/get_lyrics.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/field/audio_source.dart';
import '../tools/cover_lru_cache.dart';
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
      ).obs;

  final currentDuration = 0.0.obs;

  final currentState = AudioState.stop.obs;

  final SettingController _settingController = Get.find<SettingController>();
  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  late final RxList<MusicCache> playListCacheItems =
      [..._musicCacheController.items].obs;

  MusicCache? _hasNextAudioMetadata;

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
      await loadLyrics(currentMetadata.value.path);
    });
  }

  Future<void> initRestoreState() async {
    try {
      final lastMetadata =
          _settingController.lastAudioInfo[SettingController
                  .lastAudioMetadataKey]
              as MusicCache;
      if (playListCacheItems.isEmpty || lastMetadata.path.isEmpty) return;

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

  Future<void> loadLyrics(String path, {bool changed = false}) async {
    if (!changed) {
      currentLyrics.value = await getParsedLyric(filePath: path);
    }
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

    final oldCover = currentCover.value;
    if (await getCover(path: currentPath.value, sizeFlag: 1) case final src?
        when src.isNotEmpty) {
      currentCover.value = src;
    } else {
      if (await saveCoverByText(
            text: title + artist,
            songPath: metadata.path,
            saveCover: false,
          )
          case final netSrc? when netSrc.isNotEmpty) {
        currentCover.value = Uint8List.fromList(netSrc);
      } else {
        currentCover.value = kTransparentImage;
      }
    }
    PaintingBinding.instance.imageCache.evict(MemoryImage(oldCover));

    currentSmallCover.value =
        CoverLRUCache.get(currentPath.value) ??
        await getCover(path: currentPath.value, sizeFlag: 0) ??
        kTransparentImage;

    if (_settingController.dynamicThemeColor.value) {
      await _setThemeColor4Cover();
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
        CoverLRUCache.get(currentPath.value) ??
        await getCover(path: currentMetadata.value.path, sizeFlag: 0) ??
        kTransparentImage;

    final imageProvider = MemoryImage(src);

    final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: Size(120, 120),
    );

    PaintingBinding.instance.imageCache.evict(imageProvider);

    if (generator.paletteColors.length >= 4) {
      coverPalette.value = generator.paletteColors
          .map((v) => v.color)
          .toList()
          .sublist(0, 4);
    } else {
      coverPalette.value = generator.paletteColors
          .map((v) => v.color)
          .toList()..addAll([
        Colors.red,
        Colors.yellow,
        Colors.blue,
        Colors.green,
      ].sublist(0,4-generator.paletteColors.length));
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
      reTryCount++;
      await audioPlay(metadata: prevMetadata);
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

  /// 用于同步元数据更改
  Future<void> audioListSyncMetadata({
    required String path,
    required MusicCache newCache,
  }) async {
    if (playListCacheItems.isEmpty || path != currentMetadata.value.path) {
      return;
    }
    if (currentState.value == AudioState.playing) {
      audioSetPositon(pos: currentMs100.value);
    }

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
