import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:zerobit_player/components/play_bar.dart';
import 'package:zerobit_player/components/window_background.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/statistics_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/custom_widgets/index.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/hive_manager/adapters/scalable_setting_adapters.dart';
import 'package:zerobit_player/hive_manager/adapters/statistics_cache_adapter.dart';
import 'package:zerobit_player/hive_manager/adapters/user_playlist_adapter.dart';
import 'package:zerobit_player/hive_manager/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/statistics_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/pages/album_preview_page.dart';
import 'package:zerobit_player/pages/artist_preview_page.dart';
import 'package:zerobit_player/pages/audio_info_edit_page.dart';
import 'package:zerobit_player/pages/folders_preview_page.dart';
import 'package:zerobit_player/pages/local_music_page.dart';
import 'package:zerobit_player/pages/play_page.dart';
import 'package:zerobit_player/pages/playlists_preview_page.dart';
import 'package:zerobit_player/pages/setting_page.dart';
import 'package:zerobit_player/pages/statistics_page.dart';
import 'package:zerobit_player/pages/uni_details_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';
import 'package:zerobit_player/tools/version_checker.dart';
import 'package:zerobit_player/tray.dart';
import 'package:zerobit_player/windows_taskbar_thumbnail.dart';

import 'components/get_snack_bar.dart';
import 'controller/desktop_lyrics_setting_ctrl.dart';
import 'controller/lyric_ctrl.dart';
import 'controller/setting_ctrl.dart';
import 'controller/window_ctrl.dart';
import 'desktop_lyrics_sever.dart';
import 'field/app_routes.dart';
import 'hive_manager/adapters/music_cache_adapter.dart';
import 'hive_manager/adapters/setting_cache_adapter.dart';
import 'hive_manager/hive_boxes.dart';
import 'hive_manager/models/music_cache_model.dart';
import 'logger.dart';
import 'theme_manager.dart';

int _countMs100 = 0;
int _countSec = 0;
int _countSec30 = 0;

const String configDirectory = 'zerobit_config';

StreamSubscription? _audioEventSub;
StreamSubscription? _progressSub;
StreamSubscription? _smtcSub;

void _hiveSafeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

Future<Box> _openSafeBox<T>(String boxName) async {
  try {
    return await Hive.openBox<T>(boxName);
  } catch (e) {
    // 捕获到 HiveError 或者其他异常
    debugPrint('Box <$boxName> Damage，Reset... ErrMsg: $e');

    await Future.delayed(const Duration(milliseconds: 100));

    // 从磁盘删除损坏的 Box 不使用Hive.deleteBoxFromDisk是因为可能被占用
    final directory = p.join(
      (await getApplicationDocumentsDirectory()).path,
      configDirectory,
    );
    final file = File('$directory/$boxName.hive');
    final lockFile = File('$directory/$boxName.lock');

    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    if (await lockFile.exists()) {
      try {
        await lockFile.delete();
      } catch (_) {}
    }

    // 重新尝试打开（此时会创建一个新的空 Box）
    return await Hive.openBox<T>(boxName);
  }
}

Future<void> _initLog() async {
  // 初始化本地日志系统
  await FileLogger.init();

  // 拦截 Flutter 框架级别的错误
  FlutterError.onError = (FlutterErrorDetails details) {
    // 控制台打印
    FlutterError.presentError(details);

    // 写入日志文件
    FileLogger.logError(
      'Flutter UI/Framework Error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // 拦截 Dart 异步/底层级别的错误
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    FileLogger.logError(
      'Dart Async/Unhandled Error',
      error: error,
      stackTrace: stack,
    );
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
  PaintingBinding.instance.imageCache.maximumSizeBytes = 10 * 1024 * 1024;

  try {
    await loadLib();
    await initBass();
  } catch (e) {
    debugPrint('Error on initBass: $e');
  }

  try {
    await initSmtc();
  } catch (e) {
    debugPrint('Error on initSmtc: $e');
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

  final musicBox = await _openSafeBox<MusicCache>(HiveBoxes.musicCacheBox);

  await _openSafeBox<SettingCache>(HiveBoxes.settingCacheBox);
  await _openSafeBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);
  await _openSafeBox<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox);
  await _openSafeBox<StatisticsCache>(HiveBoxes.statisticsCacheBox);

  DesktopLyricsSettingController.instance.init();
  SettingController.instance.init();
  AudioController.instance.init();
  UserPlayListController.instance.init();
  DesktopLyricsSever.instance.init();
  await TrayManagerService.instance.init();
  WindowController.instance.init();

  final SettingController settingController = SettingController.instance;

  double w = 1200;
  double h = 800;
  double x = 0;
  double y = 0;

  final lastSize =
      settingController.lastWindowInfo[SettingController.lastWindowSizeKey]
          as List<double>?;
  if (lastSize != null && lastSize.isNotEmpty) {
    [w, h] = lastSize;
  }

  WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(1000, 750),
    size: Size(w, h),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'ZeroBit Player',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    windowManager.setHasShadow(true);
    final lastPosition =
        settingController.lastWindowInfo[SettingController.lastWindowPositonKey]
            as List<double>?;
    if (lastPosition != null && lastPosition.isNotEmpty) {
      [x, y] = lastPosition;
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
      final keysToDelete = musicBox.values
          .map((v) => v.path)
          .where((k) => !supportedExts.contains(p.extension(k).toLowerCase()))
          .map((v) => md5.convert(utf8.encode(v)).toString())
          .toList();
      await musicBox.deleteAll(keysToDelete); //清除不是音频格式的路径，防止路径被污染
      await syncCache();
      await StatisticsController.instance.init();
      await audioController.initRestoreState();
    });
  });
  await initStream(audioController);

  // 初始化taskbar
  WindowsTaskbarThumbnail.init(
    onButtonClick: (action) {
      switch (action) {
        case TaskbarButtonAction.prev:
          audioController.audioToPrevious.throttle(ms: 500)();
          break;
        case TaskbarButtonAction.toggle:
          audioController.audioToggle.throttle(ms: 300)();
          break;
        case TaskbarButtonAction.next:
          audioController.audioToNext.throttle(ms: 500)();
          break;
      }
    },
  );
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
        for (var n in leaks.notDisposed) {
          debugPrint(n.toYaml("内存溢出检查 notDisposed:", phasesAreTests: true));
        }
        //统计未进行内存回收的对象
        for (var n in leaks.notGCed) {
          debugPrint(n.toYaml("内存溢出检查 notGCed:", phasesAreTests: true));
        }
        //统计对象进行了内存回收,但是回收时间不及时
        for (var n in leaks.gcedLate) {
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

  try {
    _audioEventSub = audioEventStream().listen((data) {
      final state = AudioState.values[data];
      audioController.currentState.value = state;
      WindowsTaskbarThumbnail.setButtons(
        isPlaying: state == AudioState.playing,
        visible: SettingController.instance.useTaskBarCtrl.value,
      );
      if (state == AudioState.ended) {
        audioController.audioAutoPlay();
      }
    });
  } catch (e) {
    debugPrint(e.toString());
    showSnackBar(title: "ERR:", msg: e.toString());
  }

  try {
    _progressSub = progressListen().listen((data) {
      lyricController.currentMs20Notifier.value = data;
      lyricController.updateProgress();
      _countMs100++;
      _countSec++;
      _countSec30++;
      if (_countMs100 > 4) {
        _countMs100 = 0;
        audioController.currentMs100.value = data;
        audioController.updateProgress();
      }
      if (_countSec > 49) {
        _countSec = 0;
        audioController.currentSec.value = data;
      }
      if (_countSec30 > 1499) {
        _countSec30 = 0;
        StatisticsController.instance.updateStatistics();
        unawaited(
          StatisticsController.instance.saveStatistics().then(
            (_) => debugPrint("Statistics Save OK!"),
            onError: (e) => debugPrint("Statistics Save ERR> $e"),
          ),
        );
      }
    });
  } catch (e) {
    debugPrint(e.toString());
    showSnackBar(title: "ERR:", msg: e.toString());
  }

  try {
    _smtcSub = smtcControlEvents().listen((event) {
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
    });
  } catch (e) {
    debugPrint(e.toString());
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
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        ),
        child: child,
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
    return SignalBuilder(
      builder: (context) => MaterialApp.router(
        routerConfig: _router,
        theme: themeService.lightTheme,
        darkTheme: themeService.darkTheme,
        themeMode: settingController.themeMode.value == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class NestedObserver extends NavigatorObserver {
  final void Function(String? routeName) onRouteChanged;

  NestedObserver({required this.onRouteChanged});

  String? _getName(Route? route) {
    final args = route?.settings.arguments as Map<String, dynamic>? ?? {};
    String? name;
    name = route?.settings.name;
    if (args['operateArea'] != null) {
      name = OperateArea.nameMap[args['operateArea']];
    }
    return name;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged(_getName(previousRoute));
  }

  @override
  void didPush(Route route, Route? previousRoute) {
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
    return ExcludeSemantics(
      child: Stack(
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
                    Padding(
                      padding: const EdgeInsetsGeometry.all(8),
                      child: CustomNavigation(
                        btnList: const <Widget>[
                          CustomNavigationBtn(
                            label: '音乐',
                            icon: PhosphorIconsLight.musicNoteSimple,
                            localIndex: AppRoutes.homeOrder,
                          ),
                          CustomNavigationBtn(
                            label: '艺术家',
                            icon: PhosphorIconsLight.userFocus,
                            localIndex: AppRoutes.artistPreviewOrder,
                          ),
                          CustomNavigationBtn(
                            label: '专辑',
                            icon: PhosphorIconsLight.vinylRecord,
                            localIndex: AppRoutes.albumPreviewOrder,
                          ),
                          CustomNavigationBtn(
                            label: '歌单',
                            icon: PhosphorIconsLight.playlist,
                            localIndex: AppRoutes.playListPreviewOrder,
                          ),
                          CustomNavigationBtn(
                            label: '文件夹',
                            icon: PhosphorIconsLight.folders,
                            localIndex: AppRoutes.foldersPreviewOrder,
                          ),
                          CustomNavigationBtn(
                            label: '统计',
                            icon: PhosphorIconsLight.chartLine,
                            localIndex: AppRoutes.statisticsOrder,
                          ),
                          CustomNavigationBtn(
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
      ),
    );
  }
}
