import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zerobit_player/HIveCtrl/models/setting_cache_model.dart';
import 'package:zerobit_player/local_music_page.dart';
import 'package:zerobit_player/setting_page.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';
import 'package:zerobit_player/tools/sync_cache.dart';
import 'package:zerobit_player/window_ctrl.dart';
import 'package:get/get.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'HIveCtrl/adapters/setting_cache_adapter.dart';
import 'HIveCtrl/models/music_cahce_model.dart';
import 'app_routes.dart';


import 'package:zerobit_player/custom_widgets/custom_widget.dart';

import 'package:window_manager/window_manager.dart';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'HIveCtrl/hive_boxes.dart';

import 'HIveCtrl/adapters/music_cache_adapter.dart';
import 'getxController/music_cache_ctrl.dart';
import 'getxController/setting_ctrl.dart';

import 'theme_manager.dart';

void main<T>() async {

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

  // await Hive.deleteBoxFromDisk('setting_box');

  Hive.registerAdapter(MusicCacheAdapter());
  Hive.registerAdapter(SettingCacheAdapter());
  await Hive.openBox<MusicCache>(HiveBoxes.musicCacheBox);
  await Hive.openBox<SettingCache>(HiveBoxes.settingCacheBox);

  Get.put(SettingController());
  Get.put(MusicCacheController());

  await syncCache();


  // await setExclusiveMode(exclusive: false);


  WindowOptions windowOptions = WindowOptions(
    minimumSize: Size(1000, 750),
    size: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'test',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });


  runApp(const MainFrame());
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

class MainFrame extends StatelessWidget {
  const MainFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode.value == 'dark' ? ThemeMode.dark : ThemeMode.light,
      transitionDuration: 200.ms,
      customTransition: _SlideTransition(),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.base,
      getPages: [
        GetPage(name: AppRoutes.base, page: () => const HomePage()),
        GetPage(name: AppRoutes.home, page: () => const LocalMusic()),
        GetPage(name: AppRoutes.setting, page: () => const Setting()),
      ],
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

  Widget _getNamedPage(String name) {
    switch (name) {
      case AppRoutes.home:
        return LocalMusic();
      case AppRoutes.setting:
        return Setting();
    }
    return LocalMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),

      child: Column(
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
                      label: '设置',
                      icon: PhosphorIconsLight.gearSix,
                      localIndex: 1,
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
                        page: () => _getNamedPage(settings.name!),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
