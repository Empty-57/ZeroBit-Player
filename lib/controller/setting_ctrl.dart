import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/widget/get_snack_bar.dart';
import 'package:zerobit_player/controller/window_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/field/scalable_config_keys.dart';
import 'package:zerobit_player/field/set_constants.dart';
import 'package:zerobit_player/field/shared_preferences_key.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/setting_cache_model.dart';
import 'package:zerobit_player/logger.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';

import '../desktop_lyrics_sever.dart';
import '../windows_taskbar_thumbnail.dart';
import 'audio_ctrl.dart';

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
  final useBlur = signal(true);
  final useMesh = signal(true);
  final useSpringScroll = signal(true);
  final close2Tray = signal(false);
  final showTranslate = signal(true);
  final showRoma = signal(false);
  final backgroundImagePath = signal('1');
  final backgroundImageOpacity = signal(0.5); // 0-1
  final backgroundImageBlur = signal(4.0); // 0-36
  final useTransparencyBackground = signal(false);
  final useAutoUpdate = signal(true);

  // 歌词状态
  final lrcAlignment = signal(0); // 012 左中右
  final lrcFontSize = signal(32); // 24-48
  final lrcFontWeight = signal(5); // 0-8 w100-w900
  final autoDownloadLrc = signal(true);
  final showDesktopLyrics = signal(false);
  final autoGetLyrics = signal(true);

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
  final equalizerGains = listSignal(List.generate(10, (_) => 0.0).toList());
  final useReplayGain = signal(false);
  final useTaskBarCtrl = signal(true);
  final useVolumeFade = signal(true);
  final spectrogramStyle = signal(0); // 0：无，1：柱状图，2：波形图，3：波浪

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
    // SpectrogramStyleType.waveform: '波形图',
    // SpectrogramStyleType.wave: '波浪',
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
    lastAudioMetadataKey: MusicCache(
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

  List<int> modifierToggleHidList = [];
  List<int> modifierNextHidList = [];
  List<int> modifierPreviousHidList = [];
  List<int> modifierFullScreenHidList = [];

  int hotKeyToggleHid = PhysicalKeyboardKey.space.usbHidUsage;
  int hotKeyNextHid = PhysicalKeyboardKey.arrowRight.usbHidUsage;
  int hotKeyPreviousHid = PhysicalKeyboardKey.arrowLeft.usbHidUsage;
  int hotKeyFullScreenHid = PhysicalKeyboardKey.f1.usbHidUsage;

  // 服务与依赖
  final String _key = 'setting';
  final String _scalableKey = 'scalable_setting';
  final _settingCacheBox = HiveBox.settingCacheBox;
  final _scalableSettingCacheBox = HiveBox.scalableSettingCacheBox;

  SharedPreferences? prefs;

  /// 检查当前是否在输入框内，防止快捷键冲突
  static bool get isTextFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || !primaryFocus.hasFocus) return false;
    return primaryFocus.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  void init() async {
    await _initHive();
    await _initPrefs();
    _initBassSet();
    await initHotKey();
  }

  void _initBassSet() {
    unawaited(() async {
      await setVolume(vol: volume.value);

      for (final v in equalizerGains.indexed) {
        await setEqParams(freCenterIndex: v.$1, gain: v.$2);
      }

      await setUseFade(value: useVolumeFade.value);
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
      if (sortMap.length > cache.sortMap.length) await putCache();

      viewModeMap.value = Map.of(_defaultViewModeMap)
        ..addAll(cache.viewModeMap.cast<dynamic, dynamic>());
      if (viewModeMap.length > cache.viewModeMap.length) await putCache();
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
      useVolumeFade.value =
          prefs?.getBool(SharedPreferencesKey.useVolumeFade) ?? true;
      spectrogramStyle.value =
          prefs?.getInt(SharedPreferencesKey.spectrogramStyle) ?? 0;
    });

    // 提取快捷键解析逻辑，消除冗余
    _loadKeyConfig(SharedPreferencesKey.toggleHidString, hotKeyToggleHid, (
      hid,
      modifiers,
    ) {
      hotKeyToggleHid = hid;
      modifierToggleHidList = modifiers;
    });
    _loadKeyConfig(SharedPreferencesKey.nextHidString, hotKeyNextHid, (
      hid,
      modifiers,
    ) {
      hotKeyNextHid = hid;
      modifierNextHidList = modifiers;
    });
    _loadKeyConfig(SharedPreferencesKey.previousHidString, hotKeyPreviousHid, (
      hid,
      modifiers,
    ) {
      hotKeyPreviousHid = hid;
      modifierPreviousHidList = modifiers;
    });
    _loadKeyConfig(
      SharedPreferencesKey.fullScreenHidString,
      hotKeyFullScreenHid,
      (hid, modifiers) {
        hotKeyFullScreenHid = hid;
        modifierFullScreenHidList = modifiers;
      },
    );
  }

  /// 辅助方法：解析存入的快捷键配置
  void _loadKeyConfig(
    String prefKey,
    int defaultHid,
    Function(int hid, List<int> modifiers) onLoaded,
  ) {
    try {
      final rawStr = prefs?.getString(prefKey);
      final keys = (rawStr != null)
          ? rawStr.split('_').map(int.parse).toList()
          : [defaultHid];
      onLoaded(
        keys.last,
        keys.length > 1 ? keys.sublist(0, keys.length - 1) : [],
      );
    } catch (e, stackTrace) {
      LoggerUni.w('加载快捷键失败', e, stackTrace);
      onLoaded(defaultHid, []);
    }
  }

  // 快捷键管理
  List<HotKeyModifier>? _getModifier(List<int> hidList) {
    if (hidList.isEmpty) return null;
    return hidList
        .map(
          (v) => HotKeyModifier.values.firstWhere(
            (k) => k.physicalKeys.first.usbHidUsage == v,
          ),
        )
        .toList();
  }

  Future<void> initHotKey() async {
    final scope = HotKeyScope.inapp; //目前只在应用范围内生效
    // final scope=hotKeyScope.value? HotKeyScope.system:HotKeyScope.inapp;
    batch(() {
      hotKeyToggle.value = HotKey(
        modifiers: _getModifier(modifierToggleHidList),
        key: PhysicalKeyboardKey(hotKeyToggleHid),
        scope: scope,
      );
      hotKeyNext.value = HotKey(
        modifiers: _getModifier(modifierNextHidList),
        key: PhysicalKeyboardKey(hotKeyNextHid),
        scope: scope,
      );
      hotKeyPrevious.value = HotKey(
        modifiers: _getModifier(modifierPreviousHidList),
        key: PhysicalKeyboardKey(hotKeyPreviousHid),
        scope: scope,
      );
      hotKeyFullScreen.value = HotKey(
        modifiers: _getModifier(modifierFullScreenHidList),
        key: PhysicalKeyboardKey(hotKeyFullScreenHid),
        scope: scope,
      );
    });

    await hotKeyManager.unregisterAll();

    _registerHotKey(hotKeyToggle.value, _audioController.audioToggle);
    _registerHotKey(hotKeyNext.value, _audioController.audioToNext);
    _registerHotKey(hotKeyPrevious.value, _audioController.audioToPrevious);
    _registerHotKey(hotKeyFullScreen.value, _myWindowListener.toggleFullScreen);
  }

  void _registerHotKey(HotKey hotKey, VoidCallback action) async {
    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) {
        if (!isTextFieldFocused) action();
      },
    );
  }

  // 数据保存与业务方法
  Future<void> putCache({bool isSaveFolders = false}) async {
    _settingCacheBox.put(
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
    _scalableSettingCacheBox.put(
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

  // 辅助方法：保存 Bool 到 SharedPreferences
  void _setBoolPref(
    String key,
    Signal<bool> boolSignal, {
    bool? overrideValue,
  }) {
    if (overrideValue != null) {
      boolSignal.value = overrideValue;
    } else {
      boolSignal.value = !boolSignal.value;
    }
    prefs?.setBool(key, boolSignal.value);
  }

  void setShowTranslate() =>
      _setBoolPref(SharedPreferencesKey.showTranslate, showTranslate);
  void setShowRoma() => _setBoolPref(SharedPreferencesKey.showRoma, showRoma);
  void setHotKeyScope({required bool value}) => _setBoolPref(
    SharedPreferencesKey.hotKeyScope,
    hotKeyScope,
    overrideValue: value,
  );
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

  void setUseReplayGain({required bool value}) async {
    await setReplayGain(gainDb: 0.0, peak: 1.0);
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

  /// 提取 HotKey 的主键和修饰键 (HID)
  (int, List<int>) _extractHid(HotKey key) {
    final modifiers =
        key.modifiers?.map((e) => e.physicalKeys.first.usbHidUsage).toList() ??
        <int>[];
    final mainHid = key.physicalKey.usbHidUsage;
    return (mainHid, modifiers);
  }

  /// 生成快捷键的唯一签名 (对修饰键排序，确保 Ctrl+Alt+A 和 Alt+Ctrl+A 视为相同)
  String _generateHotKeySignature(int mainHid, List<int> modifiers) {
    final sortedMods = List<int>.from(modifiers)..sort();
    return sortedMods.isEmpty
        ? mainHid.toString()
        : '${sortedMods.join('_')}_$mainHid';
  }

  /// 检查新设置的快捷键是否与现有的发生冲突
  bool checkHotConflict(HotKey newKey, String actionType) {
    final (newMainHid, newModifiers) = _extractHid(newKey);
    final newSig = _generateHotKeySignature(newMainHid, newModifiers);

    final toggleSig = _generateHotKeySignature(
      hotKeyToggleHid,
      modifierToggleHidList,
    );
    final nextSig = _generateHotKeySignature(
      hotKeyNextHid,
      modifierNextHidList,
    );
    final prevSig = _generateHotKeySignature(
      hotKeyPreviousHid,
      modifierPreviousHidList,
    );
    final fullScreenSig = _generateHotKeySignature(
      hotKeyFullScreenHid,
      modifierFullScreenHidList,
    );

    // 如果不是当前正在修改的快捷键，且签名相同，则说明冲突
    if (actionType != SharedPreferencesKey.toggleHidString &&
        newSig == toggleSig) {
      return true;
    }
    if (actionType != SharedPreferencesKey.nextHidString && newSig == nextSig) {
      return true;
    }
    if (actionType != SharedPreferencesKey.previousHidString &&
        newSig == prevSig) {
      return true;
    }
    if (actionType != SharedPreferencesKey.fullScreenHidString &&
        newSig == fullScreenSig) {
      return true;
    }

    return false;
  }

  // 快捷键保存逻辑合并
  void _saveHotKeyPref(
    String prefKey,
    List<int> modifierList,
    HotKey key,
    void Function(int hid) updateHid,
  ) {
    modifierList.clear();
    final keys = <int>[];

    key.modifiers?.forEach((v) {
      final hid = v.physicalKeys.first.usbHidUsage;
      modifierList.add(hid);
      keys.add(hid);
    });

    final mainHid = key.physicalKey.usbHidUsage;
    keys.add(mainHid);
    updateHid(mainHid);

    prefs?.setString(prefKey, keys.join('_'));
  }

  void setToggleHid({required HotKey key}) => _saveHotKeyPref(
    SharedPreferencesKey.toggleHidString,
    modifierToggleHidList,
    key,
    (hid) => hotKeyToggleHid = hid,
  );
  void setNextHid({required HotKey key}) => _saveHotKeyPref(
    SharedPreferencesKey.nextHidString,
    modifierNextHidList,
    key,
    (hid) => hotKeyNextHid = hid,
  );
  void setPreviousHid({required HotKey key}) => _saveHotKeyPref(
    SharedPreferencesKey.previousHidString,
    modifierPreviousHidList,
    key,
    (hid) => hotKeyPreviousHid = hid,
  );
  void setFullScreenHid({required HotKey key}) => _saveHotKeyPref(
    SharedPreferencesKey.fullScreenHidString,
    modifierFullScreenHidList,
    key,
    (hid) => hotKeyFullScreenHid = hid,
  );

  void setShowDesktopLyrics([bool? value]) async {
    if (value != null) {
      showDesktopLyrics.value = value;
    } else {
      showDesktopLyrics.value = !showDesktopLyrics.value;
    }

    await putScalableCache();

    if (showDesktopLyrics.value) {
      _desktopLyricsSever.connect();
    } else {
      _desktopLyricsSever.close();
    }
  }

  void setUseTaskBarCtrl({required bool value}) async {
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
      showSnackBar(title: 'Err', msg: 'settingERR | $e');
    }
  }

  void setBackgroundImageOpacity({required double value}) {
    backgroundImageOpacity.value = value;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(SharedPreferencesKey.backgroundImageOpacity, value);
  }

  void setBackgroundImageBlur({required double value}) {
    backgroundImageBlur.value = value;
    if (prefs == null) {
      return;
    }
    prefs!.setDouble(SharedPreferencesKey.backgroundImageBlur, value);
  }

  void setBackgroundImagePath({required String value}) {
    backgroundImagePath.value = value;
    if (prefs == null) {
      return;
    }
    prefs!.setString(SharedPreferencesKey.backgroundImagePath, value);
  }

  void setSpectrogramStyle({required int value}) {
    spectrogramStyle.value = value;
    if (prefs == null) {
      return;
    }
    prefs!.setInt(SharedPreferencesKey.spectrogramStyle, value);
  }

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

  void setUseVolumeFade({required bool value}) {
    _setBoolPref(
      SharedPreferencesKey.useVolumeFade,
      useVolumeFade,
      overrideValue: value,
    );
    unawaited(setUseFade(value: useVolumeFade.value));
  }

  void setExclusiveMode({required bool use}) async {
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
      showSnackBar(title: 'Err', msg: 'settingERR | $e');
      useExclusiveMode.value = prev;
      await switchExclusiveMode(exclusive: prev);
    }
    if (prefs == null) {
      return;
    }
    // 不保存独占模式的配置
    // prefs!.setBool('useExclusiveMode', useExclusiveMode.value);
  }
}
