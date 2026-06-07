import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

import 'package:zerobit_player/hive_manager/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/hive_box.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/controller/window_ctrl.dart';

import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';
import 'package:zerobit_player/field/scalable_config_keys.dart';
import 'package:zerobit_player/field/sort_type.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';
import '../field/shared_preferences_key.dart';
import 'audio_ctrl.dart';

class SettingController extends GetxController {
  MyWindowListener get _myWindowListener => Get.find<MyWindowListener>();

  // UI & 偏好设置状态
  final themeMode = 'dark'.obs;
  final themeColor = 0xff27272a.obs;
  final dynamicThemeColor = true.obs;
  final fontFamily = "Microsoft YaHei Light".obs;
  final useBlur = true.obs;
  final useMesh = true.obs;
  final useSpringScroll = true.obs;
  final close2Tray = false.obs;
  final showTranslate = true.obs;
  final showRoma = false.obs;

  // 歌词状态
  final lrcAlignment = 0.obs;
  final lrcFontSize = 32.obs; // 24-48
  final lrcFontWeight = 5.obs; // 0-8 w100-w900
  final autoDownloadLrc = true.obs;
  final showDesktopLyrics = false.obs;

  static const int lrcFontSizeMax = 48;
  static const int lrcFontSizeMin = 24;
  static const int lrcFontWeightMax = 8;
  static const int lrcFontWeightMin = 0;
  static const Map<int, String> lrcAlignmentMap = {0: '左对齐', 1: '居中', 2: '右对齐'};

  // 音频与播放状态
  final apiIndex = 0.obs;
  final volume = 1.0.obs;
  final playMode = 0.obs;
  final useExclusiveMode = false.obs;
  final showSpectrogram = false.obs;
  final equalizerGains = List.generate(10, (_) => 0.0).toList().obs;
  final useReplayGain=true.obs;

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

  // 文件与列表状态
  final folders = <String>[].obs;
  final sortMap = <dynamic, dynamic>{}.obs;
  final viewModeMap = <dynamic, dynamic>{}.obs;
  final isReverse = false.obs; // 以后将分别应用到每个列表视图

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
  final hotKeyScope =
      false.obs; //false : HotKeyScope.inapp.obs true: HotKeyScope.system.obs
  final hotKeyToggle =
      HotKey(key: PhysicalKeyboardKey.space, scope: HotKeyScope.inapp).obs;
  final hotKeyNext =
      HotKey(key: PhysicalKeyboardKey.arrowRight, scope: HotKeyScope.inapp).obs;
  final hotKeyPrevious =
      HotKey(key: PhysicalKeyboardKey.arrowLeft, scope: HotKeyScope.inapp).obs;
  final hotKeyFullScreen =
      HotKey(key: PhysicalKeyboardKey.f1, scope: HotKeyScope.inapp).obs;

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
  AudioController get _audioController => Get.find<AudioController>();

  /// 检查当前是否在输入框内，防止快捷键冲突
  static bool get isTextFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || !primaryFocus.hasFocus) return false;
    return primaryFocus.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  @override
  void onInit() async {
    super.onInit();
    await _initHive();
    await _initPrefs();
    await initHotKey();
  }

  // 初始化逻辑
  Future<void> _initHive() async {
    final cache = _settingCacheBox.get(key: _key);
    final scalableCache = _scalableSettingCacheBox.get(key: _scalableKey);

    if (cache != null) {
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

      sortMap.value = Map.of(_defaultSortMap)
        ..addAll(cache.sortMap.cast<dynamic, dynamic>());
      if (sortMap.length > cache.sortMap.length) await putCache();

      viewModeMap.value = Map.of(_defaultViewModeMap)
        ..addAll(cache.viewModeMap.cast<dynamic, dynamic>());
      if (viewModeMap.length > cache.viewModeMap.length) await putCache();
    } else {
      sortMap.value = Map.of(_defaultSortMap);
      viewModeMap.value = Map.of(_defaultViewModeMap);
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

      showSpectrogram.value =
          config[ScalableConfigKeys.showSpectrogramKey] ?? false;
      showDesktopLyrics.value =
          config[ScalableConfigKeys.showDesktopLyricsKey] ?? false;
    }

    await setVolume(vol: volume.value);
    for (final v in equalizerGains.indexed) {
      await setEqParams(freCenterIndex: v.$1, gain: v.$2);
    }
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();

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
    close2Tray.value = prefs?.getBool(SharedPreferencesKey.close2Tray) ?? false;

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
      final keys =
          (rawStr != null)
              ? rawStr.split('_').map(int.parse).toList()
              : [defaultHid];
      onLoaded(
        keys.last,
        keys.length > 1 ? keys.sublist(0, keys.length - 1) : [],
      );
    } catch (_) {
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
          ScalableConfigKeys.showSpectrogramKey: showSpectrogram.value,
          ScalableConfigKeys.showDesktopLyricsKey: showDesktopLyrics.value,
        },
      ),
    );
  }

  // 辅助方法：保存 Bool 到 SharedPreferences
  void _setBoolPref(String key, RxBool rxBool, {bool? overrideValue}) {
    if (overrideValue != null) {
      rxBool.value = overrideValue;
    } else {
      rxBool.toggle();
    }
    prefs?.setBool(key, rxBool.value);
  }

  void setShowTranslate() =>
      _setBoolPref(SharedPreferencesKey.showTranslate, showTranslate);
  void setShowRoma() => _setBoolPref(SharedPreferencesKey.showRoma, showRoma);
  void setHotKeyScope({required bool scope}) => _setBoolPref(
    SharedPreferencesKey.hotKeyScope,
    hotKeyScope,
    overrideValue: scope,
  );
  void setUseMesh({required bool show}) =>
      _setBoolPref(SharedPreferencesKey.useMesh, useMesh, overrideValue: show);
  void setSpringScroll({required bool use}) => _setBoolPref(
    SharedPreferencesKey.useSpringScroll,
    useSpringScroll,
    overrideValue: use,
  );
  void setClose2Tray({required bool use}) => _setBoolPref(
    SharedPreferencesKey.close2Tray,
    close2Tray,
    overrideValue: use,
  );

  void setUseReplayGain({required bool use})async{
    await setReplayGain(gainDb: 0.0, peak: 1.0);
    _setBoolPref(
    SharedPreferencesKey.useReplayGain,
    useReplayGain,
    overrideValue: use,
  );
}

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

  void setExclusiveMode({required bool use}) async {
    final prev = useExclusiveMode.value;
    useExclusiveMode.value = use;
    try {
      await switchExclusiveMode(exclusive: use);
    } catch (e) {
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
