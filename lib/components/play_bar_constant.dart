import 'package:flutter/widgets.dart';
import 'package:zerobit_player/field/ui_constants.dart';

/// 悬浮播放栏尺寸常量
abstract final class PlayBarSpec {
  /// 主体宽度
  static const double bodyWidth = 700.0;

  /// 进度滑块比主体宽出的部分，用来容纳两端的滑块手柄
  static const double sliderOverflow = AppSpacing.xl;

  /// 整体宽度
  static const double totalWidth = bodyWidth + sliderOverflow;
  static const double halfWidth = totalWidth / 2;

  static const double bodyHeight = 64.0;

  /// 距窗口底部
  static const double bottomInset = AppSpacing.xl;

  /// 播放栏在屏幕底部占用的高度。
  static const double occupiedHeight = bottomInset + bodyHeight;

  static const BorderRadius radiusAll = AppRadius.smAll;

  static const double ctrlButtonSize = 40.0;

  /// 时间读数宽度
  static const double timeWidth = 92.0;

  //进度滑块
  static const double sliderTrackHeight = 1.0;
  static const double thumbHorizontalDiagonal = 8.0;
  static const double thumbVerticalDiagonal = 16.0;
  static const double valueIndicatorWidth = 48.0;
  static const double valueIndicatorHeight = 28.0;
  static const double valueIndicatorRadius = AppRadius.xs;

  // 投影与进度填充
  static const double shadowAlpha = 0.1;
  static const double shadowBlur = AppSpacing.xs;
  static const double shadowSpread = 1.0;
  static const Offset shadowOffset = Offset(0, AppSpacing.xxs);

  /// 已播放区域的填充不透明度
  static const double progressAlpha = 0.8;

  //悬停时的滚动标题
  static const double scrollVelocity = 50.0;
  static const Duration scrollDelayBefore = Duration(milliseconds: 500);
  static const Duration scrollPauseBetween = Duration(milliseconds: 1000);

  /// 侧栏展开收起时，播放栏跟着平移的时长
  static const Duration repositionDuration = Duration(milliseconds: 300);
}
