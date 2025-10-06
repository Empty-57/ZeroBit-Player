import 'package:zerobit_player/HIveCtrl/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/hive_manager.dart';
import 'package:zerobit_player/field/operate_area.dart';

import '../HIveCtrl/models/music_cache_model.dart';
import '../field/scalable_config_keys.dart';
import '../src/rust/api/bass.dart';
import '../tools/sync_cache.dart';

class SettingController extends GetxController {
  final themeMode = 'dark'.obs;
  final apiIndex = 0.obs;
  final volume = 1.0.obs;
  final folders = <String>[].obs;
  final sortMap =
      <dynamic, dynamic>{
        OperateArea.allMusic: 0,
        OperateArea.playList: 0,
        OperateArea.artistList: 0,
        OperateArea.albumList: 0,
        OperateArea.foldersList: 0,
      }.obs;
  final viewModeMap =
      <dynamic, dynamic>{
        OperateArea.allMusic: true, //列表/表格
        OperateArea.playList: true,
        OperateArea.artistList: true,
        OperateArea.albumList: true,
        OperateArea.foldersList: true,
      }.obs;
  final isReverse = false.obs;
  final themeColor = 0xff27272a.obs;
  final playMode = 0.obs;
  final dynamicThemeColor = true.obs;
  final fontFamily = "Microsoft YaHei Light".obs;

  final lrcAlignment = 0.obs;

  final lrcFontSize = 24.obs; // 16-36

  final lrcFontWeight = 5.obs; // 0-8  w100-w900

  final autoDownloadLrc = true.obs;

  final useBlur = false.obs;

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
  final equalizerGains = List.generate(10, (_) => 0.0).toList().obs;

  static const lastAudioPlayPathListKey = 0;
  static const lastAudioMetadataKey = 1;
  final lastAudioInfo = <int, Object>{
    lastAudioPlayPathListKey: [],
    lastAudioMetadataKey: MusicCache(
      title: '',
      artist: '',
      album: '',
      genre: '',
      duration: 9999,
      bitrate: null,
      sampleRate: null,
      path: '',
      src: null,
    ),
  };

  static const lastWindowSizeKey = 0;
  static const lastWindowPositonKey = 1;
  static const lastWindowIsMaximizedKey = 2;
  static const lastWindowInfoWidthAndDx = 0;
  static const lastWindowInfoHeightAndDy = 1;
  final lastWindowInfo = <int, Object>{
    lastWindowSizeKey: <double>[1200.0, 800.0],
    lastWindowPositonKey: <double>[50.0, 50.0],
    lastWindowIsMaximizedKey: false,
  };

  final showSpectrogram=true.obs;

  final showDesktopLyrics=false.obs;

  static const Map<int, String> apiMap = {0: "QQ音乐", 1: "网易云音乐"};

  static const Map<int, String> sortType = {
    0: '标题',
    1: '艺术家',
    2: '专辑',
    3: '时长',
  };

  static const Map<int, String> playModeMap = {0: '单曲循环', 1: '列表循环', 2: '随机播放'};

  static const Map<int, String> lrcAlignmentMap = {0: '左对齐', 1: '居中', 2: '右对齐'};

  final String _key = 'setting';
  final String _scalableKey = 'scalable_setting';
  final _settingCacheBox = HiveManager.settingCacheBox;
  final _scalableSettingCacheBox = HiveManager.scalableSettingCacheBox;

  void _initHive() async {
    final cache = _settingCacheBox.get(key: _key);
    final scalableCache = _scalableSettingCacheBox.get(key: _scalableKey);
    if (cache != null) {
      themeMode.value = cache.themeMode;
      apiIndex.value = cache.apiIndex;
      volume.value = cache.volume;
      folders.value = [...cache.folders];
      final sortMap_ =
          cache.sortMap.isNotEmpty
              ? Map<dynamic, dynamic>.of(cache.sortMap)
              : {
                OperateArea.allMusic: 0,
                OperateArea.playList: 0,
                OperateArea.artistList: 0,
                OperateArea.albumList: 0,
                OperateArea.foldersList: 0,
              };

      if (sortMap.length > sortMap_.length) {
        for (final entry in sortMap_.entries) {
          sortMap[entry.key] = entry.value;
        }

        await putCache();
      } else {
        sortMap.value = sortMap_;
      }

      final viewModeMap_ =
          cache.viewModeMap.isNotEmpty
              ? Map<dynamic, dynamic>.of(cache.viewModeMap)
              : {
                OperateArea.allMusic: true, //列表/表格
                OperateArea.playList: true,
                OperateArea.artistList: true,
                OperateArea.albumList: true,
                OperateArea.foldersList: true,
              };

      if (viewModeMap.length > viewModeMap_.length) {
        for (final entry in viewModeMap_.entries) {
          viewModeMap[entry.key] = entry.value;
        }

        await putCache();
      } else {
        viewModeMap.value = viewModeMap_;
      }

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
    }

    if (scalableCache != null) {
      final config = scalableCache.config;
      if (config.isNotEmpty) {

        if (config.containsKey(ScalableConfigKeys.equalizerGains)) {
          equalizerGains.value = config[ScalableConfigKeys.equalizerGains];
        }

        if (config.containsKey(ScalableConfigKeys.lastAudioInfo)) {
          lastAudioInfo[lastAudioPlayPathListKey] =
              config[ScalableConfigKeys
                  .lastAudioInfo][lastAudioPlayPathListKey] ??
              [];
          lastAudioInfo[lastAudioMetadataKey] =
              config[ScalableConfigKeys.lastAudioInfo][lastAudioMetadataKey] ??
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
              );
        }

        if (config.containsKey(ScalableConfigKeys.lastWindowInfo)) {
          lastWindowInfo[lastWindowSizeKey] =
              config[ScalableConfigKeys.lastWindowInfo][lastWindowSizeKey] ??
              [1200, 800];
          lastWindowInfo[lastWindowPositonKey] =
              config[ScalableConfigKeys.lastWindowInfo][lastWindowPositonKey] ??
              [50, 50];
          lastWindowInfo[lastWindowIsMaximizedKey] =
              config[ScalableConfigKeys
                  .lastWindowInfo][lastWindowIsMaximizedKey] ??
              false;
        }

        if(config.containsKey(ScalableConfigKeys.showSpectrogramKey)){
          showSpectrogram.value=config[ScalableConfigKeys.showSpectrogramKey];
        }

        if(config.containsKey(ScalableConfigKeys.showDesktopLyricsKey)){
          showDesktopLyrics.value=config[ScalableConfigKeys.showDesktopLyricsKey];
        }

      }
    }

    await setVolume(vol: cache?.volume ?? 1.0);

    for (final v in equalizerGains.indexed) {
      await setEqParams(freCenterIndex: v.$1, gain: v.$2);
    }
  }

  @override
  void onInit() {
    _initHive();
    super.onInit();
  }

  Future<void> putCache({bool isSaveFolders = false}) async {
    _settingCacheBox.put(
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
      key: _key,
    );
    if (isSaveFolders) {
      await syncCache();
    }
  }

  Future<void> putScalableCache() async {
    _scalableSettingCacheBox.put(
      data: ScalableSettingCache(
        config: {
          ScalableConfigKeys.equalizerGains: equalizerGains,
          ScalableConfigKeys.lastAudioInfo: lastAudioInfo,
          ScalableConfigKeys.lastWindowInfo: lastWindowInfo,
          ScalableConfigKeys.showSpectrogramKey:showSpectrogram.value,
          ScalableConfigKeys.showDesktopLyricsKey:showDesktopLyrics.value,
        },
      ),
      key: _scalableKey,
    );
  }
}
