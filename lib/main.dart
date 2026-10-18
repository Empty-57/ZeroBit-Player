import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobit_player/core/constants/operate_area.dart';
import 'package:zerobit_player/core/network/version_checker.dart';
import 'package:zerobit_player/core/platform/tray.dart';
import 'package:zerobit_player/core/platform/window_background.dart';
import 'package:zerobit_player/core/platform/window_ctrl_bar.dart';
import 'package:zerobit_player/core/platform/windows_taskbar_thumbnail.dart';
import 'package:zerobit_player/features/library/pages/album_preview_page.dart';
import 'package:zerobit_player/features/library/pages/artist_preview_page.dart';
import 'package:zerobit_player/features/library/pages/audio_info_edit_page.dart';
import 'package:zerobit_player/features/library/pages/folders_preview_page.dart';
import 'package:zerobit_player/features/library/pages/local_music_page.dart';
import 'package:zerobit_player/features/library/pages/uni_details_page.dart';
import 'package:zerobit_player/features/player/controller/audio_ctrl.dart';
import 'package:zerobit_player/features/player/views/play_page.dart';
import 'package:zerobit_player/features/player/widgets/play_bar.dart';
import 'package:zerobit_player/features/playlist/pages/playlists_preview_page.dart';
import 'package:zerobit_player/features/setting/pages/setting_page.dart';
import 'package:zerobit_player/features/statistics/controller/statistics_ctrl.dart';
import 'package:zerobit_player/features/statistics/pages/statistics_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';

import 'core/constants/app_routes.dart';
import 'core/platform/window_ctrl.dart';
import 'core/storage/adapters/daily_stat_cache_adapter.dart';
import 'core/storage/adapters/monthly_song_cache_adapter.dart';
import 'core/storage/adapters/music_cache_adapter.dart';
import 'core/storage/adapters/scalable_setting_adapters.dart';
import 'core/storage/adapters/setting_cache_adapter.dart';
import 'core/storage/adapters/statistics_cache_adapter.dart';
import 'core/storage/adapters/user_playlist_adapter.dart';
import 'core/storage/hive_boxes.dart';
import 'core/storage/models/daily_stat_cache_model.dart';
import 'core/storage/models/monthly_song_cache_model.dart';
import 'core/storage/models/music_cache_model.dart';
import 'core/storage/models/scalable_setting_cache_model.dart';
import 'core/storage/models/setting_cache_model.dart';
import 'core/storage/models/statistics_cache_model.dart';
import 'core/storage/models/user_playlist_model.dart';
import 'core/storage/sync_cache.dart';
import 'core/theme/theme_manager.dart';
import 'core/utils/func_extension.dart';
import 'core/utils/logger.dart';
import 'core/utils/memory_manager.dart';
import 'core/widgets/get_snack_bar.dart';
import 'features/lyrics/controller/desktop_lyrics_setting_ctrl.dart';
import 'features/lyrics/controller/lyric_ctrl.dart';
import 'features/lyrics/server/desktop_lyrics_server.dart';
import 'features/navigation/side_bar.dart';
import 'features/navigation/side_bar_constant.dart';
import 'features/setting/controller/setting_ctrl.dart';

int _countMs100 = 0;
int _countSec = 0;

const String configDirectory = 'zerobit_config';

/// Skia GPU 资源缓存上限
const int _skiaResourceCacheMaxBytes = 64 << 20;

StreamSubscription<int>? _audioEventSub;
StreamSubscription<double>? _progressSub;
StreamSubscription<SMTCControlEvent>? _smtcSub;

void _hiveSafeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

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

Future<void> _initLog() async {
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

void main() async {
  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();

  await _initLog();

  await windowManager.ensureInitialized();
  await RustLib.init();

  // 最多缓存 100 张图片（默认1000）
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // 最多缓存 10MB，超过就会清理（默认100MB）
  PaintingBinding.instance.imageCache.maximumSizeBytes = 10 << 20;

  // 设置 Skia GPU 资源缓存上限
  // 过小的值会导致纹理复用率下降，导致动画不流畅
  unawaited(
    SystemChannels.skia
        .invokeMethod<void>(
          'Skia.setResourceCacheMaxBytes',
          _skiaResourceCacheMaxBytes,
        )
        .catchError((Object e, StackTrace s) {
          LoggerUni.w('设置 Skia 资源缓存上限失败', e, s);
        }),
  );

  try {
    await loadLib();
    await initBass();
  } catch (e, stackTrace) {
    LoggerUni.e('初始化 BASS 音频引擎失败，播放功能可能受限', e, stackTrace);
  }

  try {
    await initSmtc();
  } catch (e, stackTrace) {
    LoggerUni.w('初始化 SMTC 系统媒体传输控制失败', e, stackTrace);
  }

  await Hive.initFlutter(configDirectory);

  // await Hive.deleteBoxFromDisk(HiveBoxes.musicCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.settingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.userPlayListCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.scalableSettingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.statisticsCacheBox);

  _hiveSafeRegisterAdapter<MusicCache>(MusicCacheAdapter());
  _hiveSafeRegisterAdapter<SettingCache>(SettingCacheAdapter());
  _hiveSafeRegisterAdapter<UserPlayListCache>(UserPlayListAdapter());
  _hiveSafeRegisterAdapter<ScalableSettingCache>(ScalableSettingAdapter());
  _hiveSafeRegisterAdapter<StatisticsCache>(StatisticsCacheAdapter());
  _hiveSafeRegisterAdapter<DailyStatCache>(DailyStatCacheAdapter());
  _hiveSafeRegisterAdapter<MonthlySongCache>(MonthlySongCacheAdapter());

  final musicBox = await _openSafeBox<MusicCache>(HiveBoxes.musicCacheBox);

  await _openSafeBox<SettingCache>(HiveBoxes.settingCacheBox);
  await _openSafeBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);
  await _openSafeBox<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox);
  await _openSafeBox<StatisticsCache>(HiveBoxes.statisticsCacheBox);
  await _openSafeBox<DailyStatCache>(HiveBoxes.dailyStatCacheBox);
  await _openSafeBox<MonthlySongCache>(HiveBoxes.monthlySongCacheBox);

  await DesktopLyricsSettingController.instance.init();
  await SettingController.instance.init();
  AudioController.instance.init();
  DesktopLyricsSever.instance.init();
  await TrayManagerService.instance.init();
  WindowController.instance.init();

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

  // if (settingController.useExclusiveMode.value) {
  //   settingController.setExclusiveMode(
  //     use: settingController.useExclusiveMode.value,
  //   );
  // }

  debugRepaintRainbowEnabled = false;
  if (kDebugMode) {
    // _initLeakTracking();
  }
  runApp(const MainFrame());

  final AudioController audioController = AudioController.instance;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 异步进行缓存清理，不阻塞启动
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        final keysToDelete = musicBox.values
            .map((v) => v.path)
            .where(
              (k) => !supportedExtension.contains(p.extension(k).toLowerCase()),
            )
            .map((v) => v.hashHex)
            .toList();
        await musicBox.deleteAll(keysToDelete); //清除不是音频格式的路径，防止路径被污染
        await syncCache();
        await StatisticsController.instance.init();
        await audioController.initRestoreState();
      } catch (e, stackTrace) {
        LoggerUni.e('启动后异步清理缓存或恢复播放状态失败', e, stackTrace);
      }
    });
  });
  await initStream(audioController);

  // 初始化taskbar
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

  MemoryManager.startLoopTrim('Loop');
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
          debugPrint(n.toYaml("内存溢出检查gcedLate:", phasesAreTests: true));
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

Future<void> initStream(AudioController audioController) async {
  final LyricController lyricController = LyricController.instance;

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
    showSnackBar(title: "ERR:", msg: e.toString());
  }

  // 音频进度流 (20ms一次)
  try {
    _progressSub = progressListen().listen(
      (data) {
        lyricController.currentMs20Notifier.value = data;
        lyricController.updateProgress();

        _countMs100++;
        _countSec++;

        if (_countMs100 > 4) {
          _countMs100 = 0;
          audioController.currentMs100.value = data;
          audioController.updateProgress();
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
    showSnackBar(title: "ERR:", msg: e.toString());
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

class _DiagonalSlide extends StatefulWidget {
  const _DiagonalSlide({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_DiagonalSlide> createState() => _DiagonalSlideState();
}

class _DiagonalSlideState extends State<_DiagonalSlide> {
  late CurvedAnimation _primaryCurved;
  late CurvedAnimation _secondaryCurved;

  late Animation<Offset> _inSlide;
  late Animation<double> _inFade;
  late Animation<Offset> _outSlide;
  late Animation<double> _outFade;

  @override
  void initState() {
    super.initState();
    _createAnimations();
  }

  @override
  void didUpdateWidget(_DiagonalSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _disposeAnimations();
      _createAnimations();
    }
  }

  void _createAnimations() {
    _primaryCurved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );

    _secondaryCurved = CurvedAnimation(
      parent: widget.secondaryAnimation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn.flipped,
    );

    _inSlide = Tween<Offset>(
      begin: SidebarNavState.beginOffset,
      end: Offset.zero,
    ).animate(_primaryCurved);

    _inFade = Tween<double>(begin: 0.0, end: 1.0).animate(_primaryCurved);

    _outSlide = Tween<Offset>(
      begin: Offset.zero,
      end: -SidebarNavState.beginOffset,
    ).animate(_secondaryCurved);

    _outFade = Tween<double>(begin: 1.0, end: 0.0).animate(_secondaryCurved);
  }

  void _disposeAnimations() {
    _primaryCurved.dispose();
    _secondaryCurved.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _inFade,
      child: SlideTransition(
        position: _inSlide,
        child: FadeTransition(
          opacity: _outFade,
          child: SlideTransition(position: _outSlide, child: widget.child),
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

// 路由切换动画页面构造函数
CustomTransitionPage<void> _buildNormalPage({
  required GoRouterState state,
  required Widget child,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    arguments: state.extra,
    maintainState: false,
    transitionDuration: 250.ms,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _DiagonalSlide(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

final CurveTween _playPageCurve = CurveTween(curve: Curves.fastOutSlowIn);

final Tween<Offset> _playPageSlideTween = Tween<Offset>(
  begin: const Offset(0.0, 0.2),
  end: Offset.zero,
);

// 播放页面切换动画构造函数
CustomTransitionPage<void> _buildPlayPage({
  required GoRouterState state,
  required Widget child,
  String? name,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: name,
    arguments: state.extra,
    maintainState: false,
    transitionDuration: 300.ms,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: _playPageSlideTween.animate(animation.drive(_playPageCurve)),
        child: FadeTransition(
          opacity: animation.drive(_playPageCurve),
          child: child,
        ),
      );
    },
  );
}

final GoRouter _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      observers: [
        NestedObserver(
          onRouteChanged: (name) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (AppRoutes.orderMap_[name] case final index?) {
                SidebarNavState.currentNavigationIndex.value = index;
              }
            });
          },
        ),
      ],
      builder: (context, state, child) {
        return HomePage(child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: AppRoutes.home,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.home,
            child: const LocalMusicPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.setting,
          name: AppRoutes.setting,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.setting,
            child: const SettingPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.playListPreview,
          name: AppRoutes.playListPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.playListPreview,
            child: const PlayListPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.artistPreview,
          name: AppRoutes.artistPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.artistPreview,
            child: const ArtistPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.albumPreview,
          name: AppRoutes.albumPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.albumPreview,
            child: const AlbumPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.foldersPreview,
          name: AppRoutes.foldersPreview,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.foldersPreview,
            child: const FoldersPreviewPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.statistics,
          name: AppRoutes.statistics,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.statistics,
            child: const StatisticsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.details,
          name: AppRoutes.details,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.details,
            child: const UniDetailsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.audioInfoEdit,
          name: AppRoutes.audioInfoEdit,
          pageBuilder: (context, state) => _buildNormalPage(
            state: state,
            name: AppRoutes.audioInfoEdit,
            child: const AudioInfoEditorPage(),
          ),
        ),
      ],
    ),

    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.playPage,
      name: AppRoutes.playPage,
      pageBuilder: (context, state) => _buildPlayPage(
        state: state,
        name: AppRoutes.playPage,
        child: const PlayPage(),
      ),
    ),
  ],
);

class MainFrame extends StatelessWidget {
  const MainFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = ThemeService.instance;
    final SettingController settingController = SettingController.instance;
    // 整个 App 外层套 ExcludeSemantics，规避 Flutter Windows 引擎的一个未修 bug: AccessibilityBridge 中的空父级解引用
    // issue #175041 / #192689 / #193410 / #193715，以及 PR #190903
    return ExcludeSemantics(
      child: SignalBuilder(
        builder: (context) => MaterialApp.router(
          routerConfig: _router,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: settingController.themeMode.value == 'dark'
              ? ThemeMode.dark
              : ThemeMode.light,
          // themeAnimationStyle: AnimationStyle.noAnimation,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class NestedObserver extends NavigatorObserver {
  final void Function(String? routeName) onRouteChanged;

  NestedObserver({required this.onRouteChanged});

  String? _getName(Route<dynamic>? route) {
    final args = route?.settings.arguments as Map<String, dynamic>? ?? {};
    String? name;
    name = route?.settings.name;
    if (args['operateArea'] != null) {
      name = OperateArea.nameMap[args['operateArea']];
    }
    return name;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged(_getName(previousRoute));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged(_getName(route));
  }
}

class HomePage extends StatefulWidget {
  final Widget child; // 接收 ShellRoute 分发的嵌套页面

  const HomePage({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SettingController.instance.useAutoUpdate.value) {
        VersionChecker.checkAndShowDialog(
          context,
          showNoUpdateToast: false,
          showErrorToast: false,
        );
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const WindowBackgroundImage(),
        const WindowBackgroundOverlay(),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const WindowControllerBar(),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(SideBarSpec.outerPadding),
                    child: SideBar(
                      btnList: <Widget>[
                        SideBarBtn(
                          label: '音乐',
                          icon: PhosphorIconsLight.musicNoteSimple,
                          localIndex: AppRoutes.homeOrder,
                        ),
                        SideBarBtn(
                          label: '艺术家',
                          icon: PhosphorIconsLight.userFocus,
                          localIndex: AppRoutes.artistPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '专辑',
                          icon: PhosphorIconsLight.vinylRecord,
                          localIndex: AppRoutes.albumPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '歌单',
                          icon: PhosphorIconsLight.playlist,
                          localIndex: AppRoutes.playListPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '文件夹',
                          icon: PhosphorIconsLight.folders,
                          localIndex: AppRoutes.foldersPreviewOrder,
                        ),
                        SideBarBtn(
                          label: '统计',
                          icon: PhosphorIconsLight.chartLine,
                          localIndex: AppRoutes.statisticsOrder,
                        ),
                        SideBarBtn(
                          label: '设置',
                          icon: PhosphorIconsLight.gearSix,
                          localIndex: AppRoutes.settingOrder,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
        const PlayBar(),
      ],
    );
  }
}
