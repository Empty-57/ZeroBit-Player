import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zerobit_player/hive_manager/adapters/scalable_setting_adapters.dart';
import 'package:zerobit_player/hive_manager/adapters/user_playlist_adapter.dart';
import 'package:zerobit_player/hive_manager/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/setting_cache_model.dart';
import 'package:zerobit_player/hive_manager/models/user_playlist_model.dart';
import 'package:zerobit_player/components/play_bar.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/pages/album_details_page.dart';
import 'package:zerobit_player/pages/album_preview_page.dart';
import 'package:zerobit_player/pages/artist_details_page.dart';
import 'package:zerobit_player/pages/artist_preview_page.dart';
import 'package:zerobit_player/pages/folders_details_page.dart';
import 'package:zerobit_player/pages/folders_preview_page.dart';
import 'package:zerobit_player/pages/local_music_page.dart';
import 'package:zerobit_player/pages/play_page.dart';
import 'package:zerobit_player/pages/playlist_details_page.dart';
import 'package:zerobit_player/pages/setting_page.dart';
import 'package:zerobit_player/pages/playlists_preview_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/sync_cache.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/tray.dart';
import 'hive_manager/adapters/setting_cache_adapter.dart';
import 'hive_manager/models/music_cache_model.dart';
import 'components/get_snack_bar.dart';
import 'desktop_lyrics_sever.dart';
import 'field/app_routes.dart';
import 'package:zerobit_player/custom_widgets/index.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'hive_manager/hive_boxes.dart';
import 'hive_manager/adapters/music_cache_adapter.dart';
import 'controller/desktop_lyrics_setting_ctrl.dart';
import 'controller/lyric_ctrl.dart';
import 'controller/music_cache_ctrl.dart';
import 'controller/setting_ctrl.dart';
import 'controller/window_ctrl.dart';
import 'logger.dart';
import 'theme_manager.dart';

int countMs100 = 0;
int countSec = 0;

const String configDirectory = 'zerobit_config';

StreamSubscription? _audioEventSub;
StreamSubscription? _progressSub;
StreamSubscription? _smtcSub;

void hiveSafeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  if (!Hive.isAdapterRegistered(adapter.typeId)) {
    Hive.registerAdapter<T>(adapter);
  }
}

Future<Box> openSafeBox<T>(String boxName) async {
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

void main() async {
  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();

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

  await windowManager.ensureInitialized();
  await RustLib.init();

  // 最多缓存 200 张图片（默认1000）
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // 最多缓存 20MB，超过就会清理（默认100MB）
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024;

  try {
    await loadLib();
    await initBass();
  } catch (_) {}

  try {
    await initSmtc();
  } catch (_) {}

  await Hive.initFlutter(configDirectory);

  // await Hive.deleteBoxFromDisk(HiveBoxes.musicCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.settingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.userPlayListCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.scalableSettingCacheBox);

  hiveSafeRegisterAdapter<MusicCache>(MusicCacheAdapter());
  hiveSafeRegisterAdapter<SettingCache>(SettingCacheAdapter());
  hiveSafeRegisterAdapter<UserPlayListCache>(UserPlayListAdapter());
  hiveSafeRegisterAdapter<ScalableSettingCache>(ScalableSettingAdapter());

  final musicBox = await openSafeBox<MusicCache>(HiveBoxes.musicCacheBox);

  await openSafeBox<SettingCache>(HiveBoxes.settingCacheBox);
  await openSafeBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);
  await openSafeBox<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox);

  Get.put(UserPlayListController());
  Get.put(SettingController());
  Get.put(MusicCacheController());
  Get.put(AudioController());
  Get.put(LyricController());
  Get.put(ThemeService());
  Get.put(DesktopLyricsSever());
  Get.put(DesktopLyricsSettingController());
  Get.put(Tray());
  Get.put(MyWindowListener());

  final SettingController settingController = Get.find<SettingController>();

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

  if (settingController.useExclusiveMode.value) {
    settingController.setExclusiveMode(
      use: settingController.useExclusiveMode.value,
    );
  }

  debugRepaintRainbowEnabled = false;
  runApp(const MainFrame());

  final AudioController audioController = Get.find<AudioController>();
  final LyricController lyricController = Get.find<LyricController>();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 异步进行缓存清理，不阻塞启动
    Future.delayed(const Duration(milliseconds: 300), () async {
      final keysToDelete =
          musicBox.values
              .map((v) => v.path)
              .where(
                (k) => !supportedExts.contains(p.extension(k).toLowerCase()),
              )
              .map((v) => md5.convert(utf8.encode(v)).toString())
              .toList();
      await musicBox.deleteAll(keysToDelete); //清除不是音频格式的路径，防止路径被污染
      await syncCache();
      await audioController.initRestoreState();
    });
  });

  await _audioEventSub?.cancel();
  await _progressSub?.cancel();
  await _smtcSub?.cancel();

  try {
    _audioEventSub = audioEventStream().listen((data) {
      final state = AudioState.values[data];
      audioController.currentState.value = state;
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
      lyricController.currentMs20.value = data;
      countMs100++;
      countSec++;
      if (countMs100 > 3) {
        audioController.currentMs100.value = data;
        countMs100 = 0;
      }
      if (countSec > 48) {
        audioController.currentSec.value = data;
        countSec = 0;
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

class _SlideTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: SidebarNavState.instance.beginOffset,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
        ),
        child: child,
      ),
    );
  }
}

class MainFrame extends StatelessWidget {
  const MainFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = Get.find<ThemeService>();
    final SettingController settingController = Get.find<SettingController>();
    return Obx(
      () => GetMaterialApp(
        enableLog: false,
        theme: themeService.lightTheme,
        darkTheme: themeService.darkTheme,
        themeMode:
            settingController.themeMode.value == 'dark'
                ? ThemeMode.dark
                : ThemeMode.light,
        transitionDuration: 500.ms,
        customTransition: _SlideTransition(),
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.base,
        getPages: [
          GetPage(
            name: AppRoutes.base,
            page: () => const HomePage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.home,
            page: () => const LocalMusicPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.setting,
            page: () => const SettingPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.playListPreview,
            page: () => const PlayListPreviewPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.playListDetails,
            page: () => const PlayListDetailsPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.artistPreview,
            page: () => const ArtistPreviewPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.artistDetails,
            page: () => const ArtistDetailsPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.albumPreview,
            page: () => const AlbumPreviewPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.albumDetails,
            page: () => const AlbumDetailsPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.foldersPreview,
            page: () => const FoldersPreviewPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.foldersDetails,
            page: () => const FoldersDetailsPage(),
            maintainState: false,
          ),
          GetPage(
            name: AppRoutes.playPage,
            maintainState: false,
            page: () => const PlayPage(),
            transition: Transition.fade,
            curve: Curves.fastOutSlowIn,
            transitionDuration: 300.ms,
          ),
        ],
      ),
    );
  }
}

class NestedObserver extends NavigatorObserver {
  final void Function(String? routeName) onRoutePopped;

  NestedObserver({required this.onRoutePopped});

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    onRoutePopped(previousRoute?.settings.name);
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _getNamedPage({required String name}) {
    switch (name) {
      case AppRoutes.home:
        return const LocalMusicPage();
      case AppRoutes.playListPreview:
        return const PlayListPreviewPage();
      case AppRoutes.setting:
        return const SettingPage();
      case AppRoutes.playListDetails:
        return const PlayListDetailsPage();
      case AppRoutes.artistPreview:
        return const ArtistPreviewPage();
      case AppRoutes.artistDetails:
        return const ArtistDetailsPage();
      case AppRoutes.albumPreview:
        return const AlbumPreviewPage();
      case AppRoutes.albumDetails:
        return const AlbumDetailsPage();
      case AppRoutes.foldersPreview:
        return const FoldersPreviewPage();
      case AppRoutes.foldersDetails:
        return const FoldersDetailsPage();
    }
    return const LocalMusicPage();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),

      child: Stack(
        children: [
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
                    CustomNavigation(
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
                          label: '设置',
                          icon: PhosphorIconsLight.gearSix,
                          localIndex: AppRoutes.settingOrder,
                        ),
                      ],
                    ),
                    Expanded(
                      flex: 1,
                      child: Navigator(
                        observers: [
                          NestedObserver(
                            onRoutePopped: (name) {
                              SidebarNavState
                                  .instance
                                  .currentNavigationIndex
                                  .value = AppRoutes.orderMap_[name] ?? 0;
                            },
                          ),
                        ],
                        key: Get.nestedKey(1),
                        initialRoute: AppRoutes.home,
                        onGenerateRoute: (settings) {
                          return GetPageRoute(
                            settings: settings,
                            page: () => _getNamedPage(name: settings.name!),
                            maintainState: false,
                          );
                        },
                      ),
                    ),
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
