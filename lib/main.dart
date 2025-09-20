import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:zerobit_player/HIveCtrl/adapters/scalable_setting_adapters.dart';
import 'package:zerobit_player/HIveCtrl/adapters/user_playlist_adapter.dart';
import 'package:zerobit_player/HIveCtrl/models/scalable_setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/play_bar.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import 'package:zerobit_player/getxController/user_playlist_ctrl.dart';
import 'package:zerobit_player/pages/album_list_page.dart';
import 'package:zerobit_player/pages/album_view_page.dart';
import 'package:zerobit_player/pages/artist_list_page.dart';
import 'package:zerobit_player/pages/artist_view_page.dart';
import 'package:zerobit_player/pages/folders_list_page.dart';
import 'package:zerobit_player/pages/folders_view_page.dart';
import 'package:zerobit_player/pages/local_music_page.dart';
import 'package:zerobit_player/pages/lrc_view.dart';
import 'package:zerobit_player/pages/playlist_page.dart';
import 'package:zerobit_player/pages/setting_page.dart';
import 'package:zerobit_player/pages/user_playlists_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/smtc.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'package:zerobit_player/tools/sync_cache.dart';
import 'package:zerobit_player/components/window_ctrl_bar.dart';
import 'package:get/get.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'HIveCtrl/adapters/setting_cache_adapter.dart';
import 'HIveCtrl/models/music_cache_model.dart';
import 'components/get_snack_bar.dart';
import 'field/app_routes.dart';


import 'package:zerobit_player/custom_widgets/custom_widget.dart';

import 'package:window_manager/window_manager.dart';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'HIveCtrl/hive_boxes.dart';

import 'HIveCtrl/adapters/music_cache_adapter.dart';
import 'field/operate_area.dart';
import 'getxController/lyric_ctrl.dart';
import 'getxController/music_cache_ctrl.dart';
import 'getxController/setting_ctrl.dart';

import 'theme_manager.dart';

int countMs100=0;
int countSec=0;

enum AudioAction{
  play,
  pause,
  next,
  previous
}

void main() async {

  // ProcessSignal.sigint.watch().listen((signal) async{
  //   debugPrint("Received SIGTERM: process is exiting.");
  //   await setExclusiveMode(exclusive: false);
  // });

  if (!await FlutterSingleInstance().isFirstInstance()) {
    await FlutterSingleInstance().focus();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await RustLib.init();



  // 最多缓存 200 张图片（默认1000）
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // 最多缓存 20MB，超过就会清理（默认100MB）
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024;

  try{
    await loadLib();
    await initBass();
  }catch(e){
    debugPrint(e.toString());
  }

  await initSmtc();

  await Hive.initFlutter();

  // await Hive.deleteBoxFromDisk(HiveBoxes.musicCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.settingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.userPlayListCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.scalableSettingCacheBox);

  Hive.registerAdapter(MusicCacheAdapter());
  Hive.registerAdapter(SettingCacheAdapter());
  Hive.registerAdapter(UserPlayListAdapter());
  Hive.registerAdapter(ScalableSettingAdapter());
  await Hive.openBox<MusicCache>(HiveBoxes.musicCacheBox);
  await Hive.openBox<SettingCache>(HiveBoxes.settingCacheBox);
  await Hive.openBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);
  await Hive.openBox<ScalableSettingCache>(HiveBoxes.scalableSettingCacheBox);

  Get.put(AudioSource());
  Get.put(UserPlayListController());
  Get.put(OperateArea());
  Get.put(SettingController());
  Get.put(MusicCacheController());
  Get.put(AudioController());
  Get.put(LyricController());
  Get.put(ThemeService());



  await syncCache();


  // await setExclusiveMode(exclusive: false);


  WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(1000, 750),
    size: Size(1200, 800),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'ZeroBit Player',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });


  runApp(const MainFrame());

  final AudioController audioController =Get.find<AudioController>();
  final LyricController lyricController=Get.find<LyricController>();

  try{
    audioEventStream().listen((data) {
      if(data==AudioState.stop.index){
        audioController.audioAutoPlay();
      }
    });
  }catch(e){
    debugPrint(e.toString());
    showSnackBar(title: "ERR:",msg: e.toString());
  }

  try{
    progressListen().listen((data){
      lyricController.currentMs20.value=data;
      countMs100++;
      countSec++;
      if(countMs100>3){
        audioController.currentMs100.value=data;
        countMs100=0;
      }
      if(countSec>48){
        audioController.currentSec.value=data;
        countSec=0;
      }
    });
  }catch(e){
    debugPrint(e.toString());
    showSnackBar(title: "ERR:",msg: e.toString());
  }

  try{
    smtcControlEvents().listen((data){

      if(data==AudioAction.play.index||data==AudioAction.pause.index){
        audioController.audioToggle.throttle(ms: 300)();
      }

      if(data==AudioAction.next.index){
        audioController.audioToNext.throttle(ms: 500)();
      }

      if(data==AudioAction.previous.index){
        audioController.audioToPrevious.throttle(ms: 500)();
      }

    });

  }catch(e){
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
        begin: Offset(0.0, 0.1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
      ),
      child: child,
    );
  }
}

final ThemeService themeService = Get.find<ThemeService>();

class MainFrame extends StatelessWidget {
  const MainFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(()=>GetMaterialApp(
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: themeMode.value == 'dark' ? ThemeMode.dark : ThemeMode.light,
      transitionDuration: 200.ms,
      customTransition: _SlideTransition(),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.base,
      getPages: [
        GetPage(name: AppRoutes.base, page: () => const HomePage()),
        GetPage(name: AppRoutes.home, page: () => const LocalMusic()),
        GetPage(name: AppRoutes.setting, page: () => const Setting()),
        GetPage(name: AppRoutes.userPlayList, page: () => const UserPlayList()),
        GetPage(name: AppRoutes.playList, page: () => const PlayList()),
        GetPage(name: AppRoutes.artistView, page: () => const ArtistViewPage()),
        GetPage(name: AppRoutes.artistList, page: () => const ArtistListPage()),
        GetPage(name: AppRoutes.albumView, page: () => const AlbumViewPage()),
        GetPage(name: AppRoutes.albumList, page: () => const AlbumListPage()),
        GetPage(name: AppRoutes.foldersView, page: () => const FoldersViewPage()),
        GetPage(name: AppRoutes.foldersList, page: () => const FoldersListPage()),
        GetPage(name: AppRoutes.lrcView, page: () => const LrcView(),transition: Transition.fade,curve: Curves.fastOutSlowIn,transitionDuration: 300.ms,),
      ],
    )
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
        return const LocalMusic();
      case AppRoutes.userPlayList:
        return const UserPlayList();
      case AppRoutes.setting:
        return const Setting();
      case AppRoutes.playList:
        return const PlayList();
      case AppRoutes.artistView:
        return const ArtistViewPage();
      case AppRoutes.artistList:
        return const ArtistListPage();
      case AppRoutes.albumView:
        return const AlbumViewPage();
      case AppRoutes.albumList:
        return const AlbumListPage();
      case AppRoutes.foldersView:
        return const FoldersViewPage();
      case AppRoutes.foldersList:
        return const FoldersListPage();
    }
    return const LocalMusic();
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
                      localIndex: AppRoutes.artistViewOrder,
                    ),
                    CustomNavigationBtn(
                      label: '专辑',
                      icon: PhosphorIconsLight.vinylRecord,
                      localIndex: AppRoutes.albumViewOrder,
                    ),
                    CustomNavigationBtn(
                      label: '歌单',
                      icon: PhosphorIconsLight.playlist,
                      localIndex: AppRoutes.userPlayListOrder,
                    ),
                    CustomNavigationBtn(
                      label: '文件夹',
                      icon: PhosphorIconsLight.folders,
                      localIndex: AppRoutes.foldersViewOrder,
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
                          currentNavigationIndex.value = AppRoutes.orderMap[name] ?? 0;
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
