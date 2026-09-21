import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

abstract class PlayPageConstant {
  static const double ctrlBtnMinSize = 40.0;
  static const double thumbRadius = 10.0;
  static const borderRadius = BorderRadius.all(Radius.circular(4));
  static const double audioCtrlBarHeight = 96;
  static const double spectrogramHeight = 100.0;
  static const double spectrogramWidthFactor = 0.94;
  static const double spectrogramWidthFactorDiff =
      (1 - spectrogramWidthFactor) / 2;
  static const lrcAlignmentIcons = [
    PhosphorIconsLight.textAlignLeft,
    PhosphorIconsLight.textAlignCenter,
    PhosphorIconsLight.textAlignRight,
  ];
  static const double menuBtnWidth = 180;
  static const double menuBtnHeight = 48;
  static const double menuBtnRadius = 0;
}
