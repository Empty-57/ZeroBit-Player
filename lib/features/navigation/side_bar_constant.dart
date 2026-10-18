import 'package:flutter/widgets.dart';
import 'package:zerobit_player/core/constants/ui_constants.dart';

/// 侧边栏尺寸常量。
abstract final class SideBarSpec {
  /// 展开宽度
  static const double expandedWidth = 220.0;

  /// 收起宽度
  static const double collapsedWidth = 64.0;

  /// 侧栏内边距
  static const EdgeInsets padding = EdgeInsets.symmetric(
    vertical: AppSpacing.xl,
    horizontal: AppSpacing.md,
  );

  /// 收起态下的内容宽度
  static const double collapsedContentWidth =
      collapsedWidth - AppSpacing.md * 2;

  /// 导航项高度
  static const double itemHeight = 48.0;

  /// 导航项之间的间距
  static const double itemSpacing = AppSpacing.sm;

  /// 导航项左内边距。取 `(收起态内容宽 - 图标宽) / 2`，
  /// 这样侧栏收起时图标才会居中
  static const double itemPaddingLeft =
      (collapsedContentWidth - AppIconSize.md) / 2;

  /// 导航项右内边距，未使用
  static const double itemPaddingRight = AppSpacing.xs;

  /// 指示条宽度
  static const double indicatorWidth = 3.0;

  /// 指示条上下内缩
  static const double indicatorInset = 10.0;

  /// 毛玻璃模糊半径
  static const double blurSigma = 16.0;

  /// 侧栏表面不透明度
  static const double surfaceAlpha = 0.4;

  static const BorderRadius radiusAll = AppRadius.mdAll;

  /// 侧栏在主布局里的外边距
  static const double outerPadding = AppSpacing.md;

  /// 侧栏在主布局里的占位宽度，含外边距。
  static double footprintWidth({required bool expanded}) =>
      (expanded ? expandedWidth : collapsedWidth) + outerPadding * 2;
}
