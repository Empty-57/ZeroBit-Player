import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:get/get.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';
import 'package:zerobit_player/tools/lrcTool/get_lyrics.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

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
        trackGain: 0.0,
        trackPeak: 1.0,
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
      <Color>[Colors.black12, Colors.white24, Colors.white, Colors.grey].obs;

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

  SpringListController get _springController =>
      Get.find<SpringListController>();

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
      if (Get.isRegistered<SpringListController>()) {
        _springController.clearState();
      }
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
    if (_isSyncing) return;
    _isSyncing = true;
    final metadata = currentMetadata.value;
    try {
      try {
        currentDuration.value = await getLen();
      } catch (_) {
        currentDuration.value = 999;
      }

      final title = metadata.title;
      final artist =
          (metadata.artist.isNotEmpty && metadata.artist != 'UNKNOWN')
              ? ' - ${metadata.artist}'
              : '';

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

      currentSmallCover.value =
          CoverLRUCache.get(currentPath.value) ??
          await getCover(path: currentPath.value, sizeFlag: 0) ??
          kTransparentImage;

      await _setThemeColor4Cover();

      await windowManager.setTitle(title + artist);
      try {
        await trayManager.setToolTip(title + artist);
      } catch (_) {}

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
      }
    } catch (e) {
      debugPrint("syncErr: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void _setThemeColor({required int color}) {
    if (!_settingController.dynamicThemeColor.value) {
      return;
    }
    _settingController.themeColor.value = color;
    _settingController.putCache();
  }

  Future<void> _setThemeColor4Cover() async {
    if (currentMetadata.value.path.isEmpty ||
        (!_settingController.dynamicThemeColor.value &&
            !_settingController.useMesh.value)) {
      return;
    }

    final src =
        CoverLRUCache.get(currentPath.value) ??
        await getCover(path: currentMetadata.value.path, sizeFlag: 0) ??
        kTransparentImage;

    try {
      // 裁剪为112*112大小
      final ui.Codec codec = await ui.instantiateImageCodec(
        src,
        targetWidth: 112,
        targetHeight: 112,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // 按RGBA格式转为字节数组
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      // 释放资源
      image.dispose();
      codec.dispose();

      if (byteData == null) {
        return;
      }

      // 将RGBA格式转为Material支持的ARGB格式
      final Uint8List rgbaBytes = byteData.buffer.asUint8List();
      final List<int> argbPixels = [];

      for (int i = 0; i < rgbaBytes.length; i += 4) {
        final int r = rgbaBytes[i];
        final int g = rgbaBytes[i + 1];
        final int b = rgbaBytes[i + 2];
        final int a = rgbaBytes[i + 3];
        // 合成 32 位 ARGB 整数
        final int argb = (a << 24) | (r << 16) | (g << 8) | b;
        argbPixels.add(argb);
      }

      // 量化，评分，把最合适的颜色排在前面
      final quantizerResult = await QuantizerCelebi().quantize(argbPixels, 128);
      final Map<int, int> colorToCount = quantizerResult.colorToCount;
      final List<int> rankedColors = Score.score(colorToCount);

      // 转换格式，填充并更新 coverPalette
      final List<Color> extractedColors =
          rankedColors.map((c) => Color(c)).toList();
      if (extractedColors.length >= 4) {
        coverPalette.value = extractedColors.sublist(0, 4);
      } else {
        coverPalette.value = List<Color>.from(extractedColors)..addAll(
          [
            Colors.black12,
            Colors.white24,
            Colors.white,
            Colors.grey,
          ].sublist(0, 4 - extractedColors.length),
        );
      }

      if (coverPalette.isNotEmpty) {
        // 第一个颜色即为主题色
        _setThemeColor(color: coverPalette.first.toARGB32());
      }
    } catch (e) {
      debugPrint("使用 material_color_utilities 提取封面主题色出错: $e");
      _setThemeColor(color: 0xff27272a);
    }
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

      if (_settingController.useReplayGain.value) {
        await setReplayGain(
          gainDb: metadata.trackGain,
          peak: metadata.trackPeak,
        );
      }
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
    update([GetBuilderId.lyricRender]);
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
