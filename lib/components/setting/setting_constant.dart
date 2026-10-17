library;

import 'package:flutter/material.dart';
import 'package:zerobit_player/field/ui_constants.dart';

/// 设置页布局常量
abstract final class SettingLayout {
  /// 顶部 Tab 单段宽度
  static const double tabSegmentWidth = 104.0;

  /// 设置行最小高度
  static const double rowMinHeight = 52.0;

  /// 设置行内边距
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.lg,
  );

  /// 行内「标题区 控件区」的最小间距
  static const double rowGap = AppSpacing.xxl;

  /// 分组之间的间距
  static const double groupSpacing = AppSpacing.xxl;

  /// 分组标题与卡片之间的间距
  static const double groupTitleGap = AppSpacing.md;

  /// Tab 内容底部留白
  static const double contentBottomInset = 96.0;

  /// 滚动条让位，防止内容压在滚动条下
  static const double scrollbarInset = AppSpacing.md;

  /// Tab 内容切换时的横向位移比例
  static const double tabSlideOffset = 0.08;
}

/// 设置页控件尺寸常量
abstract final class SettingControlSpec {
  /// 次要操作按钮
  static const double buttonHeight = 36.0;
  static const double buttonMinWidth = 72.0;
  static const double buttonMaxWidth = 180.0;

  /// 方形图标按钮
  static const double iconButton = 34.0;

  /// 步进按钮
  static const double stepButton = 28.0;

  /// 滑块
  static const double sliderWidth = 140.0;
  static const double sliderValueWidth = 60.0;

  /// 颜色色板
  static const double swatchSize = 22.0;

  /// 背景图片路径显示宽度
  static const double pathTextWidth = 190.0;

  /// 快捷键组合显示宽度
  static const double hotkeyLabelWidth = 150.0;
}

/// 设置页对话框尺寸常量
abstract final class SettingDialogSpec {
  /// 快捷键录制对话框尺寸比例
  static const double hotkeyWidthFactor = 0.3;
  static const double hotkeyHeightFactor = 0.25;

  /// 取色器画布
  static const double colorPickerWidth = 400.0;
  static const double colorPickerAreaPercent = 0.7;

  /// 快捷键录制器放大倍数，默认尺寸在桌面端偏小
  static const double hotkeyRecorderScale = 1.5;
}

/// 链接常量
abstract final class SettingLinks {
  static const String repo = 'https://github.com/Empty-57/ZeroBit-Player';
  static const String report =
      'https://github.com/Empty-57/ZeroBit-Player/issues/new/choose';
  static const String site = 'https://empty-57.github.io/ZeroBit-Player/';
}
