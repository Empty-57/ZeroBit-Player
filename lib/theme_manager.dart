import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controller/setting_ctrl.dart';

class ThemeService {
  ThemeService._();
  static final instance = ThemeService._();
  final SettingController _settingController = Get.find<SettingController>();

  final _contrastLevel = 0.0;
  final _dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;

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
      fontFamily: _settingController.fontFamily.value,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(scheme.secondaryContainer),
        thickness: WidgetStatePropertyAll(_thickness),
        trackVisibility: WidgetStatePropertyAll(false),
        radius: Radius.circular(_radius),
        interactive: true,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          mouseCursor: WidgetStateProperty.resolveWith<MouseCursor>((states) {
            if (states.contains(WidgetState.disabled)) {
              return SystemMouseCursors.basic;
            }
            return SystemMouseCursors.click;
          }),
        ),
      ),
    );
  }

  ThemeData get lightTheme => _createThemeData(
    scheme: _createColorsScheme(brightness: Brightness.light),
  );

  ThemeData get darkTheme => _createThemeData(
    scheme: _createColorsScheme(brightness: Brightness.dark),
  );

  void setThemeMode() {
    _settingController.themeMode.value =
        _settingController.themeMode.value == 'dark' ? 'light' : 'dark';

    _settingController.putCache();

    Get.changeThemeMode(
      _settingController.themeMode.value == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
    );
  }
}
