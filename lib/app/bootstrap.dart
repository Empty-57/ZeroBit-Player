import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform/tray.dart';
import '../core/platform/window_ctrl.dart';
import '../core/platform/windows_taskbar_thumbnail.dart';
import '../core/storage/adapters/daily_stat_cache_adapter.dart';
import '../core/storage/adapters/monthly_song_cache_adapter.dart';
import '../core/storage/adapters/music_cache_adapter.dart';
import '../core/storage/adapters/scalable_setting_adapters.dart';
import '../core/storage/adapters/setting_cache_adapter.dart';
import '../core/storage/adapters/statistics_cache_adapter.dart';
import '../core/storage/adapters/user_playlist_adapter.dart';
import '../core/storage/hive_box.dart';
import '../core/storage/hive_boxes.dart';
import '../core/storage/models/daily_stat_cache_model.dart';
import '../core/storage/models/monthly_song_cache_model.dart';
import '../core/storage/models/music_cache_model.dart';
import '../core/storage/models/scalable_setting_cache_model.dart';
import '../core/storage/models/setting_cache_model.dart';
import '../core/storage/models/statistics_cache_model.dart';
import '../core/storage/models/user_playlist_model.dart';
import '../core/storage/sync_cache.dart';
import '../core/utils/func_extension.dart';
import '../core/utils/logger.dart';
import '../core/widgets/get_snack_bar.dart';
import '../features/lyrics/controller/desktop_lyrics_setting_ctrl.dart';
import '../features/lyrics/controller/lyric_ctrl.dart';
import '../features/lyrics/server/desktop_lyrics_server.dart';
import '../features/player/controller/audio_ctrl.dart';
import '../features/setting/controller/setting_ctrl.dart';
import '../features/statistics/controller/statistics_ctrl.dart';
import '../src/rust/api/bass.dart';
import '../src/rust/api/smtc.dart';

int _countMs100 = 0;
int _countSec = 0;

const String configDirectory = 'zerobit_config';

StreamSubscription<int>? _audioEventSub;
StreamSubscription<double>? _progressSub;
StreamSubscription<SMTCControlEvent>? _smtcSub;

Future<Box<T>> _openSafeBox<T>(String boxName) async {
  if (Hive.isBoxOpen(boxName)) {
    return Hive.box<T>(boxName);
  }
  try {
    return await Hive.openBox<T>(boxName);
  } catch (e, stackTrace) {
    LoggerUni.e('Hive Box <$boxName> 数据损坏或打开失败，开始尝试重置修复...', e, stackTrace);

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final docDir = await getApplicationDocumentsDirectory();
    final directory = p.join(docDir.path, configDirectory);
    final hiveFile = File(p.join(directory, '$boxName.hive'));
    final lockFile = File(p.join(directory, '$boxName.lock'));

    await _safeDeleteFile(hiveFile);
    await _safeDeleteFile(lockFile);

    // 二次兜底尝试打开
    try {
      final box = await Hive.openBox<T>(boxName);
      LoggerUni.i('Hive Box <$boxName> 损坏文件已重置，空 Box 重新打开成功');
      return box;
    } catch (secondErr, secondStack) {
      // 如果重置后依然无法打开，记录致命日志并向外抛出
      LoggerUni.f('Hive Box <$boxName> 重置后二次打开依然失败！', secondErr, secondStack);
      rethrow;
    }
  }
}

Future<void> initHive() async {
  await Hive.initFlutter(configDirectory);

  // await Hive.deleteBoxFromDisk(HiveBoxes.musicCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.settingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.userPlayListCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.scalableSettingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.statisticsCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.dailyStatCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.monthlySongCacheBox);

  _hiveSafeRegisterAdapter<MusicCache>(MusicCacheAdapter());
  _hiveSafeRegisterAdapter<SettingCache>(SettingCacheAdapter());
  _hiveSafeRegisterAdapter<UserPlayListCache>(UserPlayListAdapter());
  _hiveSafeRegisterAdapter<ScalableSettingCache>(ScalableSettingAdapter());
  _hiveSafeRegisterAdapter<StatisticsCache>(StatisticsCacheAdapter());
  _hiveSafeRegisterAdapter<DailyStatCache>(DailyStatCacheAdapter());
  _hiveSafeRegisterAdapter<MonthlySongCache>(MonthlySongCacheAdapter());

  await _openSafeBox<MusicCache>(HiveBoxes.musicCacheBox);
  await _openSafeBox<SettingCache>(HiveBoxes.settingCacheBox);
  await _openSafeBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);
  await _openSafeBox<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox);
  await _openSafeBox<StatisticsCache>(HiveBoxes.statisticsCacheBox);
  await _openSafeBox<DailyStatCache>(HiveBoxes.dailyStatCacheBox);
  await _openSafeBox<MonthlySongCache>(HiveBoxes.monthlySongCacheBox);
}

Future<void> initStream() async {
  final LyricController lyricController = LyricController.instance;
  final AudioController audioController = AudioController.instance;

  await _audioEventSub?.cancel();
  await _progressSub?.cancel();
  await _smtcSub?.cancel();
  _countMs100 = 0;
  _countSec = 0;

  //音频状态流
  try {
    _audioEventSub = audioEventStream().listen(
      (data) {
        if (data < 0 || data >= AudioState.values.length) {
          LoggerUni.w('收到未知的底层音频状态码: $data');
          return;
        }

        final state = AudioState.values[data];
        audioController.currentState.value = state;

        WindowsTaskbarThumbnail.setButtons(
          isPlaying: state == AudioState.playing,
          visible: SettingController.instance.useTaskBarCtrl.value,
        );

        if (state == AudioState.ended) {
          audioController.audioAutoPlay();
        }
      },
      onError: (Object e, StackTrace stackTrace) {
        LoggerUni.e('audioEventStream 数据流产生异步异常', e, stackTrace);
      },
    );
  } catch (e, stackTrace) {
    LoggerUni.e('订阅 audioEventStream 失败', e, stackTrace);
    showSnackBar(type: .error, msg: e.toString());
  }

  // 音频进度流 (20ms一次)
  try {
    _progressSub = progressListen().listen(
      (data) {
        if (lyricController.currentMs20Notifier.value != data) {
          lyricController.currentMs20Notifier.value = data;
          lyricController.updateProgress();
        }

        _countMs100++;
        _countSec++;

        if (_countMs100 > 4) {
          _countMs100 = 0;
          if (audioController.currentMs100.value != data) {
            audioController.currentMs100.value = data;
            audioController.updateProgress();
          }
        }

        if (_countSec > 49) {
          _countSec = 0;
          audioController.currentSec.value = data;
        }
      },
      onError: (Object e, StackTrace stackTrace) {
        LoggerUni.e('progressListen 进度数据流产生异常', e, stackTrace);
      },
    );
  } catch (e, stackTrace) {
    LoggerUni.e('订阅 progressListen 失败', e, stackTrace);
    showSnackBar(type: .error, msg: e.toString());
  }

  // SMTC事件流
  try {
    _smtcSub = smtcControlEvents().listen(
      (event) {
        switch (event) {
          case SMTCControlEvent.play:
            audioController.audioResume.throttle(ms: 300)();
            break;
          case SMTCControlEvent.pause:
            audioController.audioPause.throttle(ms: 300)();
            break;
          case SMTCControlEvent.next:
            audioController.audioToNext.throttle(ms: 500)();
            break;
          case SMTCControlEvent.previous:
            audioController.audioToPrevious.throttle(ms: 500)();
            break;
          case SMTCControlEvent.unknown:
            break;
        }
      },
      onError: (Object e, StackTrace stackTrace) {
        LoggerUni.w('SMTC 媒体传输事件流异常', e, stackTrace);
      },
    );
  } catch (e, stackTrace) {
    LoggerUni.w('订阅 SMTC 事件流失败 (系统可能不支持 SMTC)', e, stackTrace);
  }
}

Future<void> initLog() async {
  // 初始化本地日志系统
  await LoggerUni.init();

  // 拦截 Flutter 框架级别的错误
  FlutterError.onError = (FlutterErrorDetails details) {
    // 控制台打印
    FlutterError.presentError(details);

    // 写入日志文件
    LoggerUni.e('Flutter UI/Framework Error', details.exception, details.stack);
  };

  // 拦截 Dart 异步/底层级别的错误
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    LoggerUni.e('Dart Async/Unhandled Error', error, stack);
    // 返回 true 表示错误已经被我们处理了，防止向系统抛出导致崩溃
    return true;
  };
}

/// 安全删除文件并记录日志
Future<void> _safeDeleteFile(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (e, stackTrace) {
    LoggerUni.w('删除 Hive 缓存/锁文件失败 (可能被操作系统占用): ${file.path}', e, stackTrace);
  }
}

void _hiveSafeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

Future<void> initDependency() async {
  await DesktopLyricsSettingController.instance.init();
  await SettingController.instance.init();
  AudioController.instance.init();
  DesktopLyricsSever.instance.init();
  await TrayManagerService.instance.init();
  WindowController.instance.init();
}

Future<void> initWindow() async {
  final SettingController settingController = SettingController.instance;

  double w = 1200;
  double h = 800;
  double x = 0;
  double y = 0;

  final rawLastSize =
      settingController.lastWindowInfo[SettingController.lastWindowSizeKey];
  if (rawLastSize is List && rawLastSize.length >= 2) {
    w = (rawLastSize[0] as num).toDouble();
    h = (rawLastSize[1] as num).toDouble();
  }

  final WindowOptions windowOptions = WindowOptions(
    minimumSize: const Size(1000, 750),
    size: Size(w, h),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'ZeroBit Player',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    unawaited(windowManager.setHasShadow(true));
    final rawLastPos = settingController
        .lastWindowInfo[SettingController.lastWindowPositonKey];
    if (rawLastPos is List && rawLastPos.length >= 2) {
      x = (rawLastPos[0] as num).toDouble();
      y = (rawLastPos[1] as num).toDouble();
      await windowManager.setPosition(Offset(x, y));
    }

    final lastIsMaximized =
        settingController.lastWindowInfo[SettingController
                .lastWindowIsMaximizedKey]
            as bool?;
    if (lastIsMaximized != null) {
      if (lastIsMaximized) {
        await windowManager.maximize();
      } else {
        await windowManager.unmaximize();
      }
    }

    await windowManager.show();
    await windowManager.focus();
  });
}

void _initLeakTracking() {
  //打印保存堆栈信息
  LeakTracking.phase = const PhaseSettings(
    leakDiagnosticConfig: LeakDiagnosticConfig(
      collectRetainingPathForNotGCed: true,
      collectStackTraceOnStart: true,
      collectStackTraceOnDisposal: true,
    ),
  );
  LeakTracking.start(
    config: LeakTrackingConfig(
      onLeaks: (s) async {
        //打印当前内存溢出整体情况
        debugPrint("onLeak: ${s.toJson()}");

        //收集所有内存溢出异常,调用这个方法后会清空LeakTracking里的所有已收集的异常
        final leaks = await LeakTracking.collectLeaks();

        // debugPrint(leaks.toYaml(phasesAreTests: true));

        //一些组件需要在 Widget 回收之后调用其 dispose 方法，通过此可以检测出未调用 dispose 方法的组件
        for (final n in leaks.notDisposed) {
          debugPrint(n.toYaml("内存溢出检查 notDisposed:", phasesAreTests: true));
        }
        //统计未进行内存回收的对象
        for (final n in leaks.notGCed) {
          debugPrint(n.toYaml("内存溢出检查 notGCed:", phasesAreTests: true));
        }
        //统计对象进行了内存回收,但是回收时间不及时
        for (final n in leaks.gcedLate) {
          debugPrint(n.toYaml("内存溢出检查GCedLate:", phasesAreTests: true));
        }
      },
    ),
  );
  //   LeakTracking.phase = PhaseSettings(
  //   ignoredLeaks: IgnoredLeaks(experimentalNotGCed: IgnoredLeaksSet()),
  // );
  FlutterMemoryAllocations.instance.addListener(
    (ObjectEvent event) => LeakTracking.dispatchObjectEvent(event.toMap()),
  );
}

void initDebugOption() {
  debugRepaintRainbowEnabled = false;
  // _initLeakTracking();
}

Future<void> checkInstance() async {
  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }
}

void initResourceLimit() {
  // 最多缓存 100 张图片（默认1000）
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // 最多缓存 10MB，超过就会清理（默认100MB）
  PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20;
}

void loadAudioResource() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 异步进行缓存清理，不阻塞启动
    Future.delayed(const Duration(milliseconds: 300), () async {
      final musicBox = HiveBox.musicCacheBox;
      try {
        final keysToDelete = musicBox
            .getAll()
            .map((v) => v.path)
            .where(
              (k) => !supportedExtension.contains(p.extension(k).toLowerCase()),
            )
            .map((v) => v.hashHex)
            .toList();
        await musicBox.delAll(keyList: keysToDelete); //清除不是音频格式的路径，防止路径被污染
        await syncCache();
        await StatisticsController.instance.init();
        await AudioController.instance.initRestoreState();
      } catch (e, stackTrace) {
        LoggerUni.e('启动后异步清理缓存或恢复播放状态失败', e, stackTrace);
      }
    });
  });
}

void initTaskbar() {
  final audioController = AudioController.instance;
  try {
    WindowsTaskbarThumbnail.init(
      onButtonClick: (action) {
        switch (action) {
          case TaskbarButtonAction.prev:
            audioController.audioToPreviousThrottled();
            break;
          case TaskbarButtonAction.toggle:
            audioController.audioToggleThrottled();
            break;
          case TaskbarButtonAction.next:
            audioController.audioToNextThrottled();
            break;
        }
      },
    );
  } catch (e, stackTrace) {
    LoggerUni.w('初始化 Windows 任务栏缩略图控制失败', e, stackTrace);
  }
}

Future<void> initBassSupport() async {
  try {
    await loadLib();
    await initBass();
  } catch (e, stackTrace) {
    LoggerUni.e('初始化 BASS 音频引擎失败，播放功能可能受限', e, stackTrace);
  }
}

Future<void> initSmtcSupport() async {
  try {
    await initSmtc();
  } catch (e, stackTrace) {
    LoggerUni.w('初始化 SMTC 系统媒体传输控制失败', e, stackTrace);
  }
}
