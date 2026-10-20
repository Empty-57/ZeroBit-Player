import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/constants/scalable_config_keys.dart';
import 'package:zerobit_player/core/constants/set_constants.dart';
import 'package:zerobit_player/core/constants/shared_preferences_key.dart';
import 'package:zerobit_player/core/platform/window_ctrl.dart';
import 'package:zerobit_player/core/widgets/get_snack_bar.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';

import '../../../core/platform/windows_taskbar_thumbnail.dart';
import '../../../core/storage/hive_box.dart';
import '../../../core/storage/models/music_cache_model.dart';
import '../../../core/storage/models/scalable_setting_cache_model.dart';
import '../../../core/storage/models/setting_cache_model.dart';
import '../../../core/storage/sync_cache.dart';
import '../../../core/utils/func_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../src/rust/api/bass.dart' as bass;
import '../../lyrics/server/desktop_lyrics_server.dart';
import '../../player/controller/audio_ctrl.dart';
import '../tools/hotkey_extension.dart';

class SettingController {
  SettingController._();

  static final instance = SettingController._();

  WindowController get _myWindowListener => WindowController.instance;

  DesktopLyricsSever get _desktopLyricsSever => DesktopLyricsSever.instance;

  AudioController get _audioController => AudioController.instance;

  // UI & 偏好设置状态
  final themeMode = signal('dark');
  final themeColor = signal(0xff27272a);
  final dynamicThemeColor = signal(true);
  final fontFamily = signal("Microsoft YaHei Light");
  final close2Tray = signal(false);
  final backgroundImagePath = signal('1');
  final backgroundImageOpacity = signal(0.5); // 0-1
  final backgroundImageBlur = signal(4.0); // 0-36
  final useTransparencyBackground = signal(false);
  final useAutoUpdate = signal(true);
  final useTilt3DCover = signal(true);

  // 歌词状态
  final lrcAlignment = signal(0); // 012 左中右
  final lrcFontSize = signal(32); // 24-48
  final lrcFontWeight = signal(5); // 0-8 w100-w900
  final lrcLetterSpacing = signal(0.0); // -5 - 10
  final autoDownloadLrc = signal(true);
  final showDesktopLyrics = signal(false);
  final autoGetLyrics = signal(true);
  final lyricSource = signal(0); // 0 本地 1 内嵌 2 网络
  final useBlur = signal(true);
  final useMesh = signal(true);
  final showKana = signal(true);
  final useSpringScroll = signal(true);
  final showTranslate = signal(true);
  final showRoma = signal(false);

  static const int lrcFontSizeMax = 48;
  static const int lrcFontSizeMin = 24;
  static const int lrcFontWeightMax = 8;
  static const int lrcFontWeightMin = 0;
  static const Map<int, String> lrcAlignmentMap = {
    LrcAlignmentType.left: '左对齐',
    LrcAlignmentType.center: '居中',
    LrcAlignmentType.right: '右对齐',
  };

  // 音频与播放状态
  final apiIndex = signal(0);
  final volume = signal(1.0);
  final playMode = signal(0);
  final useExclusiveMode = signal(false);
  final equalizerGains = listSignal(List.generate(10, (_) => 0.0));
  final useReplayGain = signal(false);
  final useTaskBarCtrl = signal(true);
  final useVolumeFade = signal(true);
  final spectrogramStyle = signal(0); // 0：无，1：柱状图，2：波形图，3：波浪
  final useCrossfade = signal(false);
  final crossfadeDuration = signal(2000.0); // 200 ~ 5000 ms
  final useSkipSilence = signal(false);
  final silenceThresholdDb = signal(-50.0); // -70.0 ~ -30.0 dB

  static const minGain = -12.0;
  static const maxGain = 12.0;
  static const equalizerFCenters = [
    80.0,
    100.0,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ]; //fCenter:fGain | fCenter: 80.0-16000.0 in Windows  fGain: -12.0db ~ 12.0db
  static const Map<String, List<double>> equalizerGainPresets = {
    'Default': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Pop': [4.0, 3.0, 2.0, 1.0, 0.0, 0.0, 1.0, 2.0, 3.0, 2.0],
    'Dance': [6.0, 5.0, 4.0, 2.0, 0.0, -1.0, 0.0, 1.0, 2.0, 1.0],
    'Blues': [2.0, 2.0, 2.0, 3.0, 2.0, 1.0, 2.0, 1.0, 0.0, -1.0],
    'Classical': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0],
    'Jazz': [2.0, 2.0, 1.0, 1.0, 0.0, 0.0, 1.0, 2.0, 1.0, 0.0],
    'Ballad': [1.0, 1.0, 0.0, 0.0, 2.0, 3.0, 2.0, 1.0, 0.0, -1.0],
    'Electronic': [5.0, 4.0, 3.0, 0.0, -1.0, -2.0, 0.0, 2.0, 4.0, 5.0],
    'Rock': [3.0, 2.0, 1.0, 0.0, -1.0, 0.0, 2.0, 3.0, 2.0, 1.0],
    'Country': [0.0, 0.0, 0.0, 1.0, 2.0, 2.0, 3.0, 2.0, 1.0, 0.0],
    'Vocal': [-2.0, -1.0, 0.0, 1.0, 3.0, 4.0, 3.0, 1.0, -1.0, -2.0],
  };
  static const Map<String, String> equalizerGainPresetsText = {
    'Default': '默认',
    'Pop': '流行',
    'Dance': '舞曲',
    'Blues': '蓝调',
    'Classical': '古典',
    'Jazz': '爵士',
    'Ballad': '慢歌',
    'Electronic': '电子乐',
    'Rock': '摇滚',
    'Country': '乡村',
    'Vocal': '人声',
  };

  static const Map<int, String> apiMap = {0: "QQ音乐", 1: "网易云音乐", 2: "酷狗音乐"};
  static const Map<int, String> playModeMap = {0: '单曲循环', 1: '列表循环', 2: '随机播放'};
  static const Map<int, String> spectrogramStyleMap = {
    SpectrogramStyleType.none: '无',
    SpectrogramStyleType.rect: '柱状图',
    SpectrogramStyleType.pixel: '像素',
    // SpectrogramStyleType.waveform: '波形图',
    // SpectrogramStyleType.wave: '波浪',
  };

  static const Map<int, String> lyricSourceMap = {
    LyricSourceType.local: '本地',
    LyricSourceType.embedded: '内嵌',
    LyricSourceType.net: '在线',
  };

  // 文件与列表状态
  final folders = listSignal(<String>[]);
  final sortMap = mapSignal(<dynamic, dynamic>{});
  final viewModeMap = mapSignal(<dynamic, dynamic>{});
  final isReverse = signal(false); // 以后将分别应用到每个列表视图

  static const _defaultSortMap = {
    OperateArea.allMusic: SortType.title,
    OperateArea.playListDetails: SortType.title,
    OperateArea.artistDetails: SortType.title,
    OperateArea.albumDetails: SortType.title,
    OperateArea.foldersDetails: SortType.title,
  };
  static const _defaultViewModeMap = {
    OperateArea.allMusic: true, //列表/表格
    OperateArea.playListDetails: true,
    OperateArea.artistDetails: true,
    OperateArea.albumDetails: true,
    OperateArea.foldersDetails: true,
  };

  static const Map<int, String> sortType = {
    SortType.title: '标题',
    SortType.artist: '艺术家',
    SortType.album: '专辑',
    SortType.duration: '时长',
    SortType.editTime: '修改时间',
    SortType.createTime: '创建时间',
    SortType.trackNumber: '音轨号',
  };

  // 缓存状态记录 (Last Info)
  static const lastAudioPlayPathListKey = 0;
  static const lastAudioMetadataKey = 1;
  final lastAudioInfo = <int, Object>{
    lastAudioPlayPathListKey: [],
    lastAudioMetadataKey: const MusicCache(
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
  };

  static const lastWindowSizeKey = 0;
  static const lastWindowPositonKey = 1;
  static const lastWindowIsMaximizedKey = 2;
  final lastWindowInfo = <int, Object>{
    lastWindowSizeKey: [1200.0, 800.0],
    lastWindowPositonKey: [50.0, 50.0],
    lastWindowIsMaximizedKey: false,
  };

  // 快捷键状态
  final hotKeyScope = signal(
    false,
  ); //false : HotKeyScope.inapp true: HotKeyScope.system
  final hotKeyToggle = signal(
    HotKey(key: PhysicalKeyboardKey.space, scope: HotKeyScope.inapp),
  );
  final hotKeyNext = signal(
    HotKey(key: PhysicalKeyboardKey.arrowRight, scope: HotKeyScope.inapp),
  );
  final hotKeyPrevious = signal(
    HotKey(key: PhysicalKeyboardKey.arrowLeft, scope: HotKeyScope.inapp),
  );
  final hotKeyFullScreen = signal(
    HotKey(key: PhysicalKeyboardKey.f1, scope: HotKeyScope.inapp),
  );

  late final Map<String, HotKeyBinding> hotKeyBindings = {
    SharedPreferencesKey.toggleHidString: (
      key: hotKeyToggle,
      defaultKey: PhysicalKeyboardKey.space,
      action: _audioController.audioToggleThrottled,
    ),
    SharedPreferencesKey.nextHidString: (
      key: hotKeyNext,
      defaultKey: PhysicalKeyboardKey.arrowRight,
      action: _audioController.audioToNextThrottled,
    ),
    SharedPreferencesKey.previousHidString: (
      key: hotKeyPrevious,
      defaultKey: PhysicalKeyboardKey.arrowLeft,
      action: _audioController.audioToPreviousThrottled,
    ),
    SharedPreferencesKey.fullScreenHidString: (
      key: hotKeyFullScreen,
      defaultKey: PhysicalKeyboardKey.f1,
      action: _myWindowListener.toggleFullScreen,
    ),
  };

  // 服务与依赖
  final String _key = 'setting';
  final String _scalableKey = 'scalable_setting';
  final _settingCacheBox = HiveBox.settingCacheBox;
  final _scalableSettingCacheBox = HiveBox.scalableSettingCacheBox;

  SharedPreferences? prefs;

  late final void Function() putCacheDebounce = putCache.debounce();

  Future<void> init() async {
    await _initHive();
    await _initPrefs();
    _initBassSet();

    await initHotKey();
  }

  void _initBassSet() {
    unawaited(() async {
      try {
        await setVolume(vol: volume.value);

        for (final (index, gain) in equalizerGains.indexed) {
          await setEqParams(freCenterIndex: index, gain: gain);
        }

        await bass.setUseVolumeFade(value: useVolumeFade.value);
        await setUseCrossfade(value: useCrossfade.value);
        await bass.setCrossfadeDuration(
          durationMs: crossfadeDuration.value.toInt(),
        );
        await setSkipSilence(enabled: useSkipSilence.value);
        await setSilenceThreshold(thresholdDb: silenceThresholdDb.value);
      } catch (e, stackTrace) {
        LoggerUni.e('初始化 BASS 音频设置失败', e, stackTrace);
      }
    }());
  }

  // 初始化逻辑
  Future<void> _initHive() async {
    final cache = _settingCacheBox.get(key: _key);
    final scalableCache = _scalableSettingCacheBox.get(key: _scalableKey);

    if (cache != null) {
      batch(() {
        themeMode.value = cache.themeMode;
        apiIndex.value = cache.apiIndex;
        volume.value = cache.volume;
        folders.value = [...cache.folders];
        isReverse.value = cache.isReverse;
        themeColor.value = cache.themeColor;
        playMode.value = cache.playMode;
        dynamicThemeColor.value = cache.dynamicThemeColor;
        fontFamily.value = cache.fontFamily;
        lrcAlignment.value = cache.lrcAlignment;
        lrcFontSize.value = cache.lrcFontSize;
        lrcFontWeight.value = cache.lrcFontWeight;
        autoDownloadLrc.value = cache.autoDownloadLrc;
        useBlur.value = cache.useBlur;
      });

      sortMap.value = Map.of(_defaultSortMap)
        ..addAll(cache.sortMap.cast<dynamic, dynamic>());
      viewModeMap.value = Map.of(_defaultViewModeMap)
        ..addAll(cache.viewModeMap.cast<dynamic, dynamic>());

      // 仅在默认设置补充了新项时合并写入一次
      final needsUpdate =
          sortMap.length > cache.sortMap.length ||
          viewModeMap.length > cache.viewModeMap.length;
      if (needsUpdate) await putCache();
    } else {
      batch(() {
        sortMap.value = Map.of(_defaultSortMap);
        viewModeMap.value = Map.of(_defaultViewModeMap);
      });
    }

    if (scalableCache != null && scalableCache.config.isNotEmpty) {
      final config = scalableCache.config;
      equalizerGains.value =
          config[ScalableConfigKeys.equalizerGains] ??
          equalizerGainPresets['Default']!;

      if (config.containsKey(ScalableConfigKeys.lastAudioInfo)) {
        lastAudioInfo.addAll(
          config[ScalableConfigKeys.lastAudioInfo].cast<int, Object>(),
        );
      }
      if (config.containsKey(ScalableConfigKeys.lastWindowInfo)) {
        lastWindowInfo.addAll(
          config[ScalableConfigKeys.lastWindowInfo].cast<int, Object>(),
        );
      }

      showDesktopLyrics.value =
          config[ScalableConfigKeys.showDesktopLyricsKey] ?? false;
    }
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    batch(() {
      showTranslate.value =
          prefs?.getBool(SharedPreferencesKey.showTranslate) ?? true;
      showRoma.value = prefs?.getBool(SharedPreferencesKey.showRoma) ?? false;
      hotKeyScope.value =
          prefs?.getBool(SharedPreferencesKey.hotKeyScope) ?? false;
      useMesh.value = prefs?.getBool(SharedPreferencesKey.useMesh) ?? true;
      useExclusiveMode.value =
          prefs?.getBool(SharedPreferencesKey.useExclusiveMode) ?? false;
      useSpringScroll.value =
          prefs?.getBool(SharedPreferencesKey.useSpringScroll) ?? true;
      close2Tray.value =
          prefs?.getBool(SharedPreferencesKey.close2Tray) ?? false;
      useReplayGain.value =
          prefs?.getBool(SharedPreferencesKey.useReplayGain) ?? false;
      autoGetLyrics.value =
          prefs?.getBool(SharedPreferencesKey.autoGetLyrics) ?? true;
      backgroundImageOpacity.value =
          prefs?.getDouble(SharedPreferencesKey.backgroundImageOpacity) ?? 0.5;
      backgroundImageBlur.value =
          prefs?.getDouble(SharedPreferencesKey.backgroundImageBlur) ?? 4.0;
      backgroundImagePath.value =
          prefs?.getString(SharedPreferencesKey.backgroundImagePath) ?? '';
      useAutoUpdate.value =
          prefs?.getBool(SharedPreferencesKey.useAutoUpdate) ?? true;
      useTransparencyBackground.value =
          prefs?.getBool(SharedPreferencesKey.useTransparencyBackground) ??
          false;
      useCrossfade.value =
          prefs?.getBool(SharedPreferencesKey.useCrossfade) ?? false;
      useVolumeFade.value =
          prefs?.getBool(SharedPreferencesKey.useVolumeFade) ?? true;
      spectrogramStyle.value =
          prefs?.getInt(SharedPreferencesKey.spectrogramStyle) ?? 0;
      lrcLetterSpacing.value =
          prefs?.getDouble(SharedPreferencesKey.lrcLetterSpacing) ?? 0.0;
      lyricSource.value = prefs?.getInt(SharedPreferencesKey.lyricSource) ?? 0;
      showKana.value = prefs?.getBool(SharedPreferencesKey.showKana) ?? true;
      crossfadeDuration.value =
          prefs?.getDouble(SharedPreferencesKey.crossfadeDuration) ?? 2000.0;
      useSkipSilence.value =
          prefs?.getBool(SharedPreferencesKey.useSkipSilence) ?? false;
      silenceThresholdDb.value =
          prefs?.getDouble(SharedPreferencesKey.silenceThresholdDb) ?? -50.0;
      useTilt3DCover.value =
          prefs?.getBool(SharedPreferencesKey.useTilt3DCover) ?? true;
    });
  }

  // 数据保存与业务方法
  Future<void> putCache({bool isSaveFolders = false}) async {
    await _settingCacheBox.put(
      key: _key,
      data: SettingCache(
        themeMode: themeMode.value,
        apiIndex: apiIndex.value,
        volume: volume.value,
        folders: folders,
        sortMap: sortMap,
        viewModeMap: viewModeMap,
        isReverse: isReverse.value,
        themeColor: themeColor.value,
        playMode: playMode.value,
        dynamicThemeColor: dynamicThemeColor.value,
        fontFamily: fontFamily.value,
        lrcAlignment: lrcAlignment.value,
        lrcFontSize: lrcFontSize.value,
        lrcFontWeight: lrcFontWeight.value,
        autoDownloadLrc: autoDownloadLrc.value,
        useBlur: useBlur.value,
      ),
    );
    if (isSaveFolders) await syncCache();
  }

  Future<void> putScalableCache() async {
    await _scalableSettingCacheBox.put(
      key: _scalableKey,
      data: ScalableSettingCache(
        config: {
          ScalableConfigKeys.equalizerGains: equalizerGains,
          ScalableConfigKeys.lastAudioInfo: lastAudioInfo,
          ScalableConfigKeys.lastWindowInfo: lastWindowInfo,
          // ScalableConfigKeys.showSpectrogramKey: showSpectrogram.value,
          ScalableConfigKeys.showDesktopLyricsKey: showDesktopLyrics.value,
        },
      ),
    );
  }

  // 辅助方法：保存偏好设置到 SharedPreferences
  void _setBoolPref(String key, Signal<bool> signal, {bool? overrideValue}) {
    signal.value = overrideValue ?? !signal.value;
    prefs?.setBool(key, signal.value);
  }

  void _setDoublePref(String key, Signal<double> signal, double value) {
    signal.value = value;
    prefs?.setDouble(key, value);
  }

  void _setIntPref(String key, Signal<int> signal, int value) {
    signal.value = value;
    prefs?.setInt(key, value);
  }

  void _setStringPref(String key, Signal<String> signal, String value) {
    signal.value = value;
    prefs?.setString(key, value);
  }

  void setShowTranslate() =>
      _setBoolPref(SharedPreferencesKey.showTranslate, showTranslate);

  void setShowRoma() => _setBoolPref(SharedPreferencesKey.showRoma, showRoma);

  void setShowKana() => _setBoolPref(SharedPreferencesKey.showKana, showKana);

  void setHotKeyScope({required bool value}) {
    // 暂不使用，目前只支持应用内快捷键
    _setBoolPref(
      SharedPreferencesKey.hotKeyScope,
      hotKeyScope,
      overrideValue: value,
    );
    unawaited(initHotKey());
  }

  void setUseMesh({required bool value}) =>
      _setBoolPref(SharedPreferencesKey.useMesh, useMesh, overrideValue: value);

  void setSpringScroll({bool? value}) => _setBoolPref(
    SharedPreferencesKey.useSpringScroll,
    useSpringScroll,
    overrideValue: value,
  );

  void setClose2Tray({required bool value}) => _setBoolPref(
    SharedPreferencesKey.close2Tray,
    close2Tray,
    overrideValue: value,
  );

  Future<void> setUseReplayGain({required bool value}) async {
    final metadata = _audioController.currentMetadata.value;
    await setReplayGain(
      gainDb: value ? metadata.trackGain : 0.0,
      peak: value ? metadata.trackPeak : 1.0,
    );
    _setBoolPref(
      SharedPreferencesKey.useReplayGain,
      useReplayGain,
      overrideValue: value,
    );
  }

  void setAutoGetLyrics({required bool value}) => _setBoolPref(
    SharedPreferencesKey.autoGetLyrics,
    autoGetLyrics,
    overrideValue: value,
  );

  Future<void> setShowDesktopLyrics([bool? value]) async {
    showDesktopLyrics.value = value ?? !showDesktopLyrics.value;
    await putScalableCache();

    if (showDesktopLyrics.value) {
      unawaited(_desktopLyricsSever.connect());
    } else {
      unawaited(_desktopLyricsSever.close());
    }
  }

  Future<void> setUseTaskBarCtrl({required bool value}) async {
    _setBoolPref(
      SharedPreferencesKey.useTaskBarCtrl,
      useTaskBarCtrl,
      overrideValue: value,
    );

    try {
      if (value) {
        await WindowsTaskbarThumbnail.setButtons(
          isPlaying: _audioController.currentState.value == AudioState.playing,
          visible: true,
        );
        await WindowsTaskbarThumbnail.setThumbnail(
          _audioController.currentSmallCover.value,
        );
      } else {
        await WindowsTaskbarThumbnail.resetAll();
      }
    } catch (e, stackTrace) {
      LoggerUni.w('设置taskBar失败', e, stackTrace);
      showSnackBar(type: .error, msg: 'settingERR | $e');
    }
  }

  void setBackgroundImageOpacity({required double value}) => _setDoublePref(
    SharedPreferencesKey.backgroundImageOpacity,
    backgroundImageOpacity,
    value,
  );

  void setBackgroundImageBlur({required double value}) => _setDoublePref(
    SharedPreferencesKey.backgroundImageBlur,
    backgroundImageBlur,
    value,
  );

  void setLrcLetterSpacing({required double value}) => _setDoublePref(
    SharedPreferencesKey.lrcLetterSpacing,
    lrcLetterSpacing,
    value,
  );

  void setBackgroundImagePath({required String value}) => _setStringPref(
    SharedPreferencesKey.backgroundImagePath,
    backgroundImagePath,
    value,
  );

  void setSpectrogramStyle({required int value}) => _setIntPref(
    SharedPreferencesKey.spectrogramStyle,
    spectrogramStyle,
    value,
  );

  void setLyricSource({required int value}) =>
      _setIntPref(SharedPreferencesKey.lyricSource, lyricSource, value);

  void setUseAutoUpdate({required bool value}) => _setBoolPref(
    SharedPreferencesKey.useAutoUpdate,
    useAutoUpdate,
    overrideValue: value,
  );

  void setUseTransparencyBackground({required bool value}) => _setBoolPref(
    SharedPreferencesKey.useTransparencyBackground,
    useTransparencyBackground,
    overrideValue: value,
  );

  void setUseTilt3DCover({required bool val}) => _setBoolPref(
    SharedPreferencesKey.useTilt3DCover,
    useTilt3DCover,
    overrideValue: val,
  );

  void setUseVolumeFade({required bool value}) {
    _setBoolPref(
      SharedPreferencesKey.useVolumeFade,
      useVolumeFade,
      overrideValue: value,
    );
    unawaited(bass.setUseVolumeFade(value: value));
  }

  Future<void> setUseCrossfade({required bool value}) async {
    _setBoolPref(
      SharedPreferencesKey.useCrossfade,
      useCrossfade,
      overrideValue: value,
    );
    unawaited(bass.setUseCrossfade(value: value));
  }

  void setCrossfadeDuration({required double value}) {
    _setDoublePref(
      SharedPreferencesKey.crossfadeDuration,
      crossfadeDuration,
      value,
    );
    unawaited(bass.setCrossfadeDuration(durationMs: value.toInt()));
  }

  void setUseSkipSilence({required bool value}) {
    _setBoolPref(
      SharedPreferencesKey.useSkipSilence,
      useSkipSilence,
      overrideValue: value,
    );
    unawaited(setSkipSilence(enabled: value));
  }

  void setSilenceThresholdDb({required double value}) {
    _setDoublePref(
      SharedPreferencesKey.silenceThresholdDb,
      silenceThresholdDb,
      value,
    );
    unawaited(setSilenceThreshold(thresholdDb: value));
  }

  Future<void> setExclusiveMode({required bool use}) async {
    final prev = useExclusiveMode.value;
    useExclusiveMode.value = use;
    try {
      await switchExclusiveMode(exclusive: use);
    } catch (e, stackTrace) {
      LoggerUni.w(
        '启用独占模式失败 Path: ${_audioController.currentPath.value}',
        e,
        stackTrace,
      );
      showSnackBar(type: .error, msg: 'settingERR | $e');
      useExclusiveMode.value = prev;
      await switchExclusiveMode(exclusive: prev);
    }
    // 不保存独占模式的配置
    // _setBoolPref(
    //     SharedPreferencesKey.useExclusiveMode,
    //     useExclusiveMode,
    //     overrideValue: use,
    //   );
  }
}
