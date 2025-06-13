import 'dart:io';

import 'package:flutter/material.dart';

const _seedColor=0xff27272a;
final _contrastLevel=0.0;
final _dynamicSchemeVariant= DynamicSchemeVariant.tonalSpot;

ColorScheme _createColorsScheme({required Brightness brightness}){
  return ColorScheme.fromSeed(
  seedColor: Color(_seedColor),
  brightness: brightness,
  contrastLevel: _contrastLevel,
  dynamicSchemeVariant : _dynamicSchemeVariant,
);
}

final ColorScheme _lightScheme = _createColorsScheme(brightness: Brightness.light);
final ColorScheme _darkScheme = _createColorsScheme(brightness: Brightness.dark);

final _fontFamily=Platform.isWindows ? "微软雅黑" : null;
const _thumbColor =Color(0xff3f3f46);
const _thickness=8.0;
const _radius=8.0;

ThemeData _createThemeData({required ColorScheme scheme}){
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

ThemeData lightTheme = _createThemeData(scheme: _lightScheme);

ThemeData darkTheme = _createThemeData(scheme: _darkScheme);
