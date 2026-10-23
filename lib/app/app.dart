import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/app/router.dart';

import '../core/theme/theme_manager.dart';
import '../features/setting/controller/setting_ctrl.dart';

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
        builder: (_) => MaterialApp.router(
          routerConfig: appRouter,
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
