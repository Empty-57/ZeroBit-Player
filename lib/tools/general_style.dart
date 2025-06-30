import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../getxController/setting_ctrl.dart';
final SettingController _settingController = Get.find<SettingController>();
TextStyle generalTextStyle<T>({
  required BuildContext ctx,
  Color? color,
  T? size,
  FontWeight? weight,
  TextDecoration? decoration,
  double? opacity,
  String? fontFamily,
}) {
  double fontSize = 14.0;

  const Map<String, double> sizeMap = {'sm': 12.0, 'md': 14.0, 'lg': 16.0};

  if (size is String) {
    fontSize = sizeMap[size] ?? 14.0;
  }

  if (size is double||size is int) {
    fontSize = double.parse(size.toString());
  }

  return TextStyle(
    color: color ?? Theme.of(ctx).colorScheme.onSurface.withValues(alpha: opacity??1.0),
    fontSize: fontSize,
    fontWeight: weight ?? FontWeight.w400,
    decoration: decoration ?? TextDecoration.none,
    fontFamily: fontFamily??_settingController.fontFamily.value,
  );
}

double getIconSize<T>({T? size}){
  double iconSize = 20.0;

  const Map<String, double> sizeMap = {'sm': 18.0, 'md': 20.0, 'lg': 22.0};

  if (size is String) {
    iconSize = sizeMap[size] ?? 20.0;
  }

  if (size is double) {
    iconSize = double.parse(size.toString());
  }

  return iconSize;
}

// fontSizeSmall: 12,
// fontSizeMiddle: 14,
// fontSizeLarge: 16,
//
// iconSizeSmall: 18,
// iconSizeMiddle: 20,
// iconSizeLarge: 22,
