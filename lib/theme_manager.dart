import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'getxController/setting_ctrl.dart';

class ThemeService extends GetxService {
  final SettingController _settingController = Get.find<SettingController>();

  final _contrastLevel = 0.0;
  final _dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;

  final _fontFamily = Platform.isWindows ? "微软雅黑" : null;
  final _thumbColor = Color(0xff3f3f46);
  final _thickness = 8.0;
  final _radius = 8.0;

  ColorScheme _createColorsScheme({required Brightness brightness}) {
    return ColorScheme.fromSeed(
      seedColor: Color(_settingController.themeColor.value),
      brightness: brightness,
      contrastLevel: _contrastLevel,
      dynamicSchemeVariant: _dynamicSchemeVariant,
    );
  }

  ThemeData _createThemeData({required ColorScheme scheme}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(_thumbColor),
        thickness: WidgetStatePropertyAll(_thickness),
        trackVisibility: WidgetStatePropertyAll(false),
        radius: Radius.circular(_radius),
        interactive: true,
      ),
    );
  }

  ThemeData get lightTheme => _createThemeData(
    scheme: _createColorsScheme(brightness: Brightness.light),
  );

  ThemeData get darkTheme => _createThemeData(
    scheme: _createColorsScheme(brightness: Brightness.dark),
  );

  void setThemeMode(){
    Get.changeThemeMode(_settingController.themeMode.value == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }
}
