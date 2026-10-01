import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'controller/setting_ctrl.dart';

class ThemeService {
  ThemeService._();
  static final instance = ThemeService._();
  final SettingController _settingController = SettingController.instance;

  final _contrastLevel = 0.0;
  final _dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot;

  final _thickness = 4.0;
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
        thumbColor: WidgetStatePropertyAll(
          scheme.secondary.withValues(alpha: 0.8),
        ),
        thickness: const WidgetStatePropertyAll(4.0),
        trackVisibility: const WidgetStatePropertyAll(false),
        radius: const Radius.circular(8.0),
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

  late final _lightThemeComputed = computed(
    () => _createThemeData(
      scheme: _createColorsScheme(brightness: Brightness.light),
    ),
  );

  late final _darkThemeComputed = computed(
    () => _createThemeData(
      scheme: _createColorsScheme(brightness: Brightness.dark),
    ),
  );

  ThemeData get lightTheme => _lightThemeComputed.value;
  ThemeData get darkTheme => _darkThemeComputed.value;

  void setThemeMode() {
    _settingController.themeMode.value =
        _settingController.themeMode.value == 'dark' ? 'light' : 'dark';
    _settingController.putCache();
  }
}
