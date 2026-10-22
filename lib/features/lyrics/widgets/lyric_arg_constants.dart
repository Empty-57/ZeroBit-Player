import 'package:flutter/material.dart';
import 'package:zerobit_player/core/constants/ui_constants.dart';

abstract class LyricConstants {
  static const double audioCtrlBarHeight = 96;
  static const double controllerBarHeight = 48;
  static const double highLightAlpha = 0.9;
  static const double currentAlpha = 0.4;
  static const double notPlayedLightAlpha = 0.25;
  static const double notPlayedDarkAlpha = 0.15;
  static const BorderRadius borderRadius = AppRadius.xsAll;
  static const double ctrlBtnMinSize = 32.0;
  static const double floatingY = -2.0;
  static const double rippleThreshold = 1.5;
  static const double rippleThresholdWindow = 3.0;
  static const double ripplesScaleMin = 1.1;
  static const double ripplesScaleExtra = 0.1;
  static const double glowAlphaMin = 0.2;
  static const double glowAlphaExtra = 0.3;

  static const lrcCrossAlignment = <CrossAxisAlignment>[
    CrossAxisAlignment.start,
    CrossAxisAlignment.center,
    CrossAxisAlignment.end,
  ];
  static const lrcMainAlignment = <MainAxisAlignment>[
    MainAxisAlignment.start,
    MainAxisAlignment.center,
    MainAxisAlignment.end,
  ];
  static const lrcScaleAlignment = <Alignment>[
    Alignment.topLeft,
    Alignment.topCenter,
    Alignment.topRight,
  ];

  static const lrcTextAlign = <TextAlign>[
    TextAlign.left,
    TextAlign.center,
    TextAlign.right,
  ];
  static const gradientStops = <double>[0.0, 0.333, 0.666];
  static const shaderOffsetFactor = -0.666;
  static const double lrcScale = 1.1;

  static const List<WrapAlignment> lrcWrapAlign = [
    WrapAlignment.start,
    WrapAlignment.center,
    WrapAlignment.end,
  ];
}
