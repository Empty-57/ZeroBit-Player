import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zerobit_player/HIveCtrl/adapters/user_playlist_adapter.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/play_bar.dart';
import 'package:zerobit_player/field/audio_source.dart';
import 'package:zerobit_player/getxController/Audio_ctrl.dart';
import 'package:zerobit_player/getxController/user_playlist_ctrl.dart';
import 'package:zerobit_player/pages/local_music_page.dart';
import 'package:zerobit_player/pages/playlist_page.dart';
import 'package:zerobit_player/pages/setting_page.dart';
import 'package:zerobit_player/pages/user_playlists_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';
import 'package:zerobit_player/tools/sync_cache.dart';
import 'package:zerobit_player/components/window_ctrl.dart';
import 'package:get/get.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'HIveCtrl/adapters/setting_cache_adapter.dart';
import 'HIveCtrl/models/music_cahce_model.dart';
import 'components/get_snack_bar.dart';
import 'field/app_routes.dart';


import 'package:zerobit_player/custom_widgets/custom_widget.dart';

import 'package:window_manager/window_manager.dart';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'HIveCtrl/hive_boxes.dart';

import 'HIveCtrl/adapters/music_cache_adapter.dart';
import 'field/operate_area.dart';
import 'getxController/music_cache_ctrl.dart';
import 'getxController/setting_ctrl.dart';

import 'theme_manager.dart';

int count=0;

void main() async {

  // ProcessSignal.sigint.watch().listen((signal) async{
  //   debugPrint("Received SIGTERM: process is exiting.");
  //   await setExclusiveMode(exclusive: false);
  // });

  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  await RustLib.init();

  try{
    await loadLib();
    await initBass();
  }catch(e){
    debugPrint(e.toString());
  }

  await Hive.initFlutter();

  // await Hive.deleteBoxFromDisk(HiveBoxes.musicCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.settingCacheBox);
  // await Hive.deleteBoxFromDisk(HiveBoxes.userPlayListCacheBox);

  Hive.registerAdapter(MusicCacheAdapter());
  Hive.registerAdapter(SettingCacheAdapter());
  Hive.registerAdapter(UserPlayListAdapter());
  await Hive.openBox<MusicCache>(HiveBoxes.musicCacheBox);
  await Hive.openBox<SettingCache>(HiveBoxes.settingCacheBox);
  await Hive.openBox<UserPlayListCache>(HiveBoxes.userPlayListCacheBox);

  Get.put(AudioSource());
  Get.put(UserPlayListController());
  Get.put(OperateArea());
  Get.put(SettingController());
  Get.put(MusicCacheController());
  Get.put(AudioController());
  Get.put(ThemeService());



  await syncCache();


  // await setExclusiveMode(exclusive: false);


  WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(1000, 750),
    size: Size(1200, 800),
    center: true,
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

  try{
    audioEventStream().listen((data) {
      if(data==AudioState.stop.index){
        audioController.audioAutoPlay();
      }
    });

    progressListen().listen((data){
      count++;
      if(count>3){
        audioController.currentMs100.value=data;
        count=0;
      }
    });

  }catch(e){
    debugPrint(e.toString());
    showSnackBar(title: "ERR:",msg: e.toString());
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
        GetPage(name: AppRoutes.playList, page: () => const PlayList(args: null,)),
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
        return PlayList();
    }
    return LocalMusic();
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
          const WindowController(),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: <Widget>[
                CustomNavigation(
                  btnList: const [
                    CustomNavigationBtn(
                      label: '音乐',
                      icon: PhosphorIconsLight.musicNoteSimple,
                      localIndex: 0,
                    ),
                    CustomNavigationBtn(
                      label: '歌单',
                      icon: PhosphorIconsLight.playlist,
                      localIndex: 1,
                    ),
                    CustomNavigationBtn(
                      label: '设置',
                      icon: PhosphorIconsLight.gearSix,
                      localIndex: 2,
                    ),
                  ],
                ),
                Expanded(
                  flex: 1,
                  child: Navigator(
                    observers: [
                      NestedObserver(
                        onRoutePopped: (name) {
                          currentNavigationIndex.value = routesMap[name] ?? 0;
                        },
                      ),
                    ],
                    key: Get.nestedKey(1),
                    initialRoute: AppRoutes.home,
                    onGenerateRoute: (settings) {
                      return GetPageRoute(
                        settings: settings,
                        page: () => _getNamedPage(name: settings.name!,args: settings.arguments),
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
