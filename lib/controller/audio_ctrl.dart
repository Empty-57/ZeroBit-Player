import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:signals/signals_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/tools/cover_lru_cache.dart';
import 'package:zerobit_player/tools/lrcTool/get_lyrics.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

import '../tools/func/func_extension.dart';
import '../tools/lrcTool/parse_lyrics.dart';
import '../tools/lrcTool/save_lyric.dart';
import '../windows_taskbar_thumbnail.dart';
import 'desktop_lyrics_setting_ctrl.dart';
import 'music_cache_ctrl.dart';

enum AudioState { stop, playing, pause, ended }

class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  int _metadataGeneration = 0; // 防异步竞态版本号

  final currentPath = signal('');
  final currentIndex = signal(-1);
  final ValueNotifier<double> currentMs100 = ValueNotifier<double>(0.0);
  final currentSec = signal(0.0);
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  // 歌词渲染刷新计数
  final lyricRenderRevision = signal(0);

  late final Signal<MusicCache> currentMetadata = signal(
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
    ),
  );

  final currentDuration = signal(0.0);
  final currentState = signal(AudioState.stop);

  SettingController get _settingController => SettingController.instance;
  MusicCacheController get _musicCacheController =>
      MusicCacheController.instance;

  late final ListSignal<MusicCache> playListCacheItems = listSignal([
    ..._musicCacheController.items,
  ]);

  MusicCache? _hasNextAudioMetadata;

  final currentCover = signal(kTransparentImage);
  final currentSmallCover = signal(kTransparentImage);

  final currentSpeed = signal(1.0);

  final currentLyrics = signal<ParsedLyricModel?>(null);
  final ValueNotifier<List<double>> audioFFT = ValueNotifier<List<double>>([]);
  final _defaultFFT = List<double>.generate(bassDataFFT512, (i) => 0.0);
  static const bassDataFFT512 = 256;

  final _unplayedIndex = <int>[];
  final navigationIsExtend = signal(true);

  final coverPalette = listSignal(<Color>[
    Colors.black12,
    Colors.white24,
    Colors.white,
    Colors.grey,
  ]);

  /// 封面调色板缓存（key 为 path）
  final Map<String, List<Color>> _paletteCache = {};
  static const int _paletteCacheMaxSize = 64;

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

  LyricController get _lyricController => LyricController.instance;
  DesktopLyricsSettingController get _desktopLyricsSettingController =>
      DesktopLyricsSettingController.instance;

  late final void Function(double pos) throttledSeek =
      ((double pos) => audioSetPositon(pos: pos)).throttleArgs(ms: 500);

  EffectCleanup? _metadataCleanup;

  void init() {
    _metadataCleanup = effect(() {
      final metadata = currentMetadata.value;
      if (metadata.path.isEmpty) return;

      untracked(() async {
        final generation = ++_metadataGeneration;
        await _handleResourceUpdate(metadata, generation);
      });
    });
  }

  /// 原子化资源更新
  Future<void> _handleResourceUpdate(
    MusicCache metadata,
    int generation,
  ) async {
    try {
      final path = metadata.path;

      final durationFuture = getLen().catchError((_) => 999.0);
      final localCoverFuture = _loadLocalCovers(path); // 先获取本地封面和歌词
      final lyricFuture = getParsedLyric(filePath: path);

      final results = await Future.wait([
        durationFuture,
        localCoverFuture,
        lyricFuture,
      ]);
      if (generation != _metadataGeneration) return;

      currentDuration.value = results[0] as double;
      final localCovers = results[1] as (Uint8List?, Uint8List?);
      var lyrics = results[2] as ParsedLyricModel?;

      Uint8List? bigCover = localCovers.$1;
      Uint8List smallCover = localCovers.$2 ?? kTransparentImage;

      // 更新系统UI
      final title = metadata.title;
      final artist =
          (metadata.artist.isNotEmpty && metadata.artist != 'UNKNOWN')
          ? ' - ${metadata.artist}'
          : '';
      final fullTitle = title + artist;
      unawaited(windowManager.setTitle(fullTitle).catchError((_) {}));
      unawaited(trayManager.setToolTip(fullTitle).catchError((_) {}));
      if (_settingController.useTaskBarCtrl.value) {
        unawaited(
          WindowsTaskbarThumbnail.setThumbnail(smallCover).catchError((_) {}),
        );
      }

      List<Color>? palette;
      palette = await _computePalette(path, smallCover, generation);

      if (bigCover == null || bigCover.isEmpty) {
        // 无大图则从网络后台获取
        _fetchNetworkCoverInBackground(metadata, path, generation);
        bigCover = smallCover;
      }
      //更新SMTC
      unawaited(
        smtcUpdateMetadata(
          title: metadata.title,
          artist: metadata.artist,
          album: metadata.album,
          coverSrc: bigCover,
        ).catchError((_) async {
          await smtcClear();
          await initSmtc();
        }),
      );

      if (generation != _metadataGeneration) return;

      // 歌词解析
      lyrics = await _checkAndGetLyrics4Net(lyrics, metadata);
      if (generation != _metadataGeneration) return;

      _parseLyricLists(lyrics);

      // 原子提交
      batch(() {
        currentCover.value = bigCover!;
        currentSmallCover.value = smallCover;
        if (palette != null) {
          _applyCoverPalette(palette);
        }

        currentLyrics.value = lyrics;
        lyricRenderRevision.value++; // 触发构建
      });

      _settingController.lastAudioInfo[SettingController.lastAudioMetadataKey] =
          metadata;
      unawaited(_settingController.putScalableCache());
    } catch (e) {
      debugPrint("切歌流程异常: $e");
    }
  }

  /// 读本地封面
  Future<(Uint8List?, Uint8List?)> _loadLocalCovers(String path) async {
    Uint8List? smallCover = CoverLRUCache.get(path);

    final bigFuture = getCover(path: path, sizeFlag: 1);
    final smallFuture = smallCover != null
        ? Future.value(smallCover)
        : getCover(path: path, sizeFlag: 0);

    final results = await Future.wait([bigFuture, smallFuture]);
    return (results[0], results[1]);
  }

  /// 后台静默下载网络封面
  void _fetchNetworkCoverInBackground(
    MusicCache metadata,
    String songPath,
    int generation,
  ) {
    unawaited(() async {
      try {
        final netSrc = await saveCoverByText(
          text: "${metadata.title} - ${metadata.artist}",
          songPath: songPath,
          saveCover: false,
        );

        // await后校验 generation
        if (generation != _metadataGeneration ||
            netSrc == null ||
            netSrc.isEmpty) {
          return;
        }
        currentCover.value = Uint8List.fromList(netSrc);
      } catch (e) {
        debugPrint("网络封面下载失败: $e");
      }
    }());
  }

  /// 提取歌词文本解析逻辑
  void _parseLyricLists(ParsedLyricModel? lyrics) {
    final parsedLrc = lyrics?.parsedLrc;
    showLyricRender = parsedLrc?.isNotEmpty ?? false;
    if (showLyricRender) {
      currentlyricType = lyrics!.type;
      lineTextList = parsedLrc!.map((v) => v.lyricText).toList();
      translateList = parsedLrc.map((v) => v.translate).toList();
      startTime = parsedLrc.map((v) => v.start).toList();
      romaList = parsedLrc.map((v) => v.roma).toList();
      lineDurationList = parsedLrc.map((v) => v.nextTime - v.start).toList();
    } else {
      currentlyricType = LyricFormat.lrc;
      lineTextList.clear();
      translateList.clear();
      startTime.clear();
      romaList.clear();
      lineDurationList.clear();
    }
    _lyricController.springController?.clearState();
  }

  /// 计算调色板
  Future<List<Color>?> _computePalette(
    String path,
    Uint8List coverBytes,
    int generation,
  ) async {
    if (path.isEmpty ||
        (!_settingController.dynamicThemeColor.value &&
            !_settingController.useMesh.value)) {
      return null;
    }

    // 命中缓存直接复用
    if (_paletteCache[path] case final cached?) {
      return List<Color>.of(cached);
    }

    ui.Codec? codec;
    ui.Image? image;
    try {
      // 裁剪为112*112大小
      codec = await ui.instantiateImageCodec(
        coverBytes,
        targetWidth: 112,
        targetHeight: 112,
      );
      final frameInfo = await codec.getNextFrame();
      image = frameInfo.image;
      // 按RGBA格式转为字节数组
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null || generation != _metadataGeneration) return null;

      // 将RGBA格式转为Material支持的ARGB格式
      final rgbaBytes = byteData.buffer.asUint8List();
      final pixelCount = rgbaBytes.length >> 2;
      final argbPixels = Int32List(pixelCount);

      for (int p = 0, i = 0; p < pixelCount; p++, i += 4) {
        // 合成 32 位 ARGB 整数
        argbPixels[p] =
            (rgbaBytes[i + 3] << 24) |
            (rgbaBytes[i] << 16) |
            (rgbaBytes[i + 1] << 8) |
            rgbaBytes[i + 2];
      }

      // 量化，评分，把最合适的颜色排在前面
      final quantizerResult = await QuantizerCelebi().quantize(argbPixels, 128);
      final rankedColors = Score.score(quantizerResult.colorToCount);
      // 转换格式，填充并更新 coverPalette
      final extractedColors = rankedColors.map((c) => Color(c)).toList();

      final palette = extractedColors.length >= 4
          ? extractedColors.sublist(0, 4)
          : (List<Color>.from(extractedColors)..addAll(
              [
                Colors.black12,
                Colors.white24,
                Colors.white,
                Colors.grey,
              ].sublist(0, 4 - extractedColors.length),
            ));

      if (_paletteCache.length >= _paletteCacheMaxSize) _paletteCache.clear();
      _paletteCache[path] = List<Color>.unmodifiable(palette);
      return palette;
    } catch (e) {
      debugPrint("调色板计算出错: $e");
      return [const Color(0xff27272a)];
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  void dispose() {
    _metadataCleanup?.call();
    currentMs100.dispose();
    progress.dispose();
    audioFFT.dispose();
    currentPath.dispose();
    currentIndex.dispose();
    currentSec.dispose();
    lyricRenderRevision.dispose();
    currentMetadata.dispose();
    currentDuration.dispose();
    currentState.dispose();
    playListCacheItems.dispose();
    currentCover.dispose();
    currentSmallCover.dispose();
    currentSpeed.dispose();
    currentLyrics.dispose();
    navigationIsExtend.dispose();
    coverPalette.dispose();
  }

  /// 获取音频FFT数据
  Future<void> getAudioFFt() async {
    if (currentState.value == AudioState.pause ||
        currentState.value == AudioState.stop) {
      if (!_isFftCleared) {
        audioFFT.value = _defaultFFT;
        _isFftCleared = true;
      }
      return;
    }

    final fft = await getChanData();
    if (fft != null && currentState.value == AudioState.playing) {
      audioFFT.value = fft;
      _isFftCleared = false;
    }
  }

  void updateProgress() {
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
  }

  Future<void> initRestoreState() async {
    try {
      final lastMetadata =
          _settingController.lastAudioInfo[SettingController
                  .lastAudioMetadataKey]
              as MusicCache?;
      if (lastMetadata == null ||
          playListCacheItems.isEmpty ||
          lastMetadata.path.isEmpty) {
        return;
      }

      await setVolume(vol: 0.0);
      await audioPlay(metadata: lastMetadata);
      await audioPause();
      await setVolume(vol: _settingController.volume.value);

      // sync_cache 已经先执行了一次
      // 此操作放在这个位置的原因： 需要等待 main.dart 中的 await syncCache()先执行完 ， 因为上面两行await任务排在await syncCache();之后
      final lastPlayPathList =
          _settingController.lastAudioInfo[SettingController
                  .lastAudioPlayPathListKey]
              as List<String>?;
      if (lastPlayPathList != null && lastPlayPathList.isNotEmpty) {
        final pathSet = lastPlayPathList.toSet();
        playListCacheItems.value = _musicCacheController.items
            .where((v) => pathSet.contains(v.path))
            .toList();
      }
    } catch (e) {
      debugPrint("Restore State Error: $e");
    }
  }

  /// 检查是否有本地歌词，没有则从API获取歌词并判断是否保存到本地
  Future<ParsedLyricModel?> _checkAndGetLyrics4Net(
    ParsedLyricModel? localLyrics,
    MusicCache metadata,
  ) async {
    final hasLocalLyrics = localLyrics?.parsedLrc?.isNotEmpty ?? false;
    if (hasLocalLyrics || !_settingController.autoGetLyrics.value) {
      return localLyrics;
    }

    try {
      final searchedLyric = await getLrcBySearch(
        text: "${metadata.title} - ${metadata.artist}",
        offset: 1,
        limit: 1,
      );

      if (searchedLyric.isEmpty) return localLyrics;

      final lyricInfo = searchedLyric.first?.lyric;
      if (lyricInfo == null) return localLyrics;

      final type = lyricInfo.type;
      List<LyricEntry<dynamic>>? parsedResult;

      if (type == LyricFormat.lrc) {
        parsedResult = parseLrc(
          lyricData: lyricInfo.lrc,
          lyricDataTs: lyricInfo.translate,
        );
      } else if (type == LyricFormat.yrc ||
          type == LyricFormat.qrc ||
          type == LyricFormat.krc) {
        parsedResult = parseKaraOkLyric(
          lyricData: lyricInfo.verbatimLrc,
          lyricDataTs: lyricInfo.translate,
          type: type,
        );
      }

      if (parsedResult == null || parsedResult.isEmpty) return localLyrics;

      if (_settingController.autoDownloadLrc.value) {
        unawaited(
          saveLyrics(path: metadata.path, lrcData: lyricInfo).catchError((e) {
            debugPrint('Failed to save lyrics: $e');
          }),
        );
      }
      return ParsedLyricModel(parsedLrc: parsedResult, type: type);
    } catch (e, stackTrace) {
      debugPrint('Error getting lyrics: $e\n$stackTrace');
      return localLyrics;
    }
  }

  Future<void> loadLyrics(String path, {bool changed = false}) async {
    final metadata = currentMetadata.value;
    final requestPath = changed ? metadata.path : path;
    if (requestPath != metadata.path) return;

    var lyrics = changed
        ? currentLyrics.value
        : await getParsedLyric(filePath: requestPath);

    // await后确认路径未变化
    if (currentMetadata.value.path != requestPath) return;

    lyrics = await _checkAndGetLyrics4Net(lyrics, metadata);

    // await后再次确认路径未变化
    if (currentMetadata.value.path != requestPath) return;

    final parsedLrc = lyrics?.parsedLrc;
    showLyricRender = parsedLrc?.isNotEmpty ?? false;

    if (showLyricRender) {
      currentlyricType = lyrics!.type;
      lineTextList = parsedLrc!.map((v) => v.lyricText).toList();
      translateList = parsedLrc.map((v) => v.translate).toList();
      startTime = parsedLrc.map((v) => v.start).toList();
      romaList = parsedLrc.map((v) => v.roma).toList();
      lineDurationList = parsedLrc.map((v) => v.nextTime - v.start).toList();
    } else {
      currentlyricType = LyricFormat.lrc;
      lineTextList.clear();
      translateList.clear();
      startTime.clear();
      romaList.clear();
      lineDurationList.clear();
    }

    _lyricController.springController?.clearState();
    batch(() {
      currentLyrics.value = lyrics;
      lyricRenderRevision.value++;
    });
  }

  void _setThemeColor({required int color}) {
    if (!_settingController.dynamicThemeColor.value) return;

    _settingController.themeColor.value = color;
    if (_desktopLyricsSettingController.useDynamicOverlayColor.value) {
      _desktopLyricsSettingController.setDynamicOverlayColor(color);
    }
    _settingController.putCache();
  }

  void _applyCoverPalette(List<Color> palette) {
    coverPalette.value = palette;
    if (palette.isNotEmpty) {
      // 第一个颜色即为主题色
      _setThemeColor(color: palette.first.toARGB32());
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
    final prevMetadata = currentMetadata.value;
    try {
      unawaited(smtcUpdateState(state: SMTCState.playing).catchError((_) {}));

      if (_settingController.useReplayGain.value) {
        await setReplayGain(
          gainDb: metadata.trackGain,
          peak: metadata.trackPeak,
        );
      }
      StatisticsController.instance.updateStatistics();
      await playFile(path: metadata.path);

      if (currentSpeed.value != 1.0) {
        await setSpeed(speed: currentSpeed.value);
      }

      batch(() {
        currentPath.value = metadata.path;
        currentMetadata.value = metadata;
        if (!playListCacheItems.any((v) => v.path == metadata.path)) {
          playListCacheItems.add(metadata);
        }
        syncCurrentIndex();
      });

      reTryCount = 0;
    } catch (e) {
      showSnackBar(title: "ERR:", msg: 'playingERR | $e');
      if (reTryCount > 4 || prevMetadata.path.isEmpty) return;
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
      unawaited(smtcUpdateState(state: SMTCState.playing).catchError((_) {}));
      await resume();
    } catch (e) {
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR", msg: 'resumeERR | $e');
    }
  }

  /// 暂停播放
  Future<void> audioPause() async {
    if (currentMetadata.value.path.isEmpty ||
        playListCacheItems.isEmpty ||
        currentState.value == AudioState.pause) {
      return;
    }
    try {
      unawaited(smtcUpdateState(state: SMTCState.paused).catchError((_) {}));
      await pause();
    } catch (e) {
      currentState.value = AudioState.stop;
      showSnackBar(title: "ERR", msg: 'pauseERR | $e');
    }
  }

  /// 停止播放
  Future<void> audioStop() async {
    batch(() {
      currentState.value = AudioState.stop;
      currentIndex.value = -1;
    });
    try {
      unawaited(smtcUpdateState(state: SMTCState.paused).catchError((_) {}));
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
      unawaited(
        smtcUpdateState(
          state: currentState.value == AudioState.playing
              ? SMTCState.playing
              : SMTCState.paused,
        ).catchError((_) {}),
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
    if (currentMetadata.value.path.isEmpty) return;
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
    lyricRenderRevision.value++;
  }

  void _pickNextRandomIndex() {
    final length = playListCacheItems.length;
    if (length == 0) return;

    if (_unplayedIndex.isEmpty || currentIndex.value >= length) {
      _unplayedIndex.clear();
      final pool = List.generate(length, (i) => i);
      if (length > 1) {
        pool.remove(currentIndex.value); // 避免连续随机到同一首
      }
      pool.shuffle();
      _unplayedIndex.addAll(pool);
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

    if (currentIndex.value >= 0 &&
        currentIndex.value < playListCacheItems.length) {
      await audioPlay(metadata: playListCacheItems[currentIndex.value]);
    }
  }

  /// 上一首播放
  Future<void> audioToPrevious() async {
    if (playListCacheItems.isEmpty) return;

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
    if (playListCacheItems.isEmpty) return;

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
    if (playListCacheItems.isEmpty) return;

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

  /// 插入下一首
  void insertNext({required MusicCache metadata}) {
    if (currentMetadata.value.path.isEmpty ||
        currentMetadata.value.path == metadata.path) {
      showSnackBar(
        title: "WARNING",
        msg: "无效操作！",
        duration: const Duration(milliseconds: 1500),
      );
      return;
    }

    batch(() {
      playListCacheItems.remove(metadata);
      final toIndex =
          (playListCacheItems.indexWhere((v) => v.path == currentPath.value) +
                  1)
              .clamp(0, playListCacheItems.length);
      playListCacheItems.insert(toIndex, metadata);
      syncCurrentIndex();
    });

    showSnackBar(
      title: "OK",
      msg: "已将 ${metadata.title} 添加到下一首播放",
      duration: const Duration(milliseconds: 1500),
    );
    _hasNextAudioMetadata = metadata;
  }

  /// 同步元数据更改
  Future<void> audioListSyncMetadata({
    required String path,
    required MusicCache newCache,
  }) async {
    if (playListCacheItems.isEmpty || path != currentMetadata.value.path) {
      return;
    }
    if (currentState.value == AudioState.playing) {
      unawaited(audioSetPositon(pos: currentMs100.value));
    }

    final targetIdx = playListCacheItems.indexWhere((v) => v.path == path);
    batch(() {
      if (targetIdx != -1) {
        playListCacheItems[targetIdx] = newCache;
      }
      currentMetadata.value = newCache;
    });

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
