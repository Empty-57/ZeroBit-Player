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
  double fontSize = 15.0;

  const Map<String, double> sizeMap = {'sm': 13.0, 'md': 15.0, 'lg': 17.0,'xl':19.0,'2xl':21.0,'subtitle':24.27,'title':30.742};

  if (size is String) {
    fontSize = sizeMap[size] ?? sizeMap['md']!;
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
    iconSize = sizeMap[size] ?? sizeMap['md']!;
  }

  if (size is double) {
    iconSize = double.parse(size.toString());
  }

  return iconSize;
}
