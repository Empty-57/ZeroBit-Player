import 'package:flutter/material.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/field/ui_constants.dart';

export 'package:zerobit_player/field/ui_constants.dart';

final SettingController _settingController = SettingController.instance;

/// 等宽数字
const List<FontFeature> _tabularFigures = [FontFeature.tabularFigures()];

class AppTextStyle {
  const AppTextStyle._();

  /// 通用样式生成
  static TextStyle create({
    BuildContext? context,
    Color? color,
    double size = AppFontSize.md,
    FontWeight weight = FontWeight.w400,
    TextDecoration decoration = TextDecoration.none,
    double opacity = 1.0,
    String? fontFamily,
    double? letterSpacing,
    bool tabularFigures = false,
  }) {
    Color effectiveColor;
    if (color != null) {
      effectiveColor = color;
    } else if (context != null) {
      effectiveColor = Theme.of(context).colorScheme.onSurface;
    } else {
      effectiveColor = const Color(0xFFFF0000);
    }

    if (opacity != 1.0) {
      effectiveColor = effectiveColor.withValues(alpha: opacity);
    }

    return TextStyle(
      color: effectiveColor,
      fontSize: size,
      fontWeight: weight,
      decoration: decoration,
      fontFamily: fontFamily ?? _settingController.fontFamily.value,
      letterSpacing: letterSpacing,
      fontFeatures: tabularFigures ? _tabularFigures : null,
    );
  }

  /// 通用图标大小解析
  static double iconSize([double size = AppIconSize.md]) {
    return size;
  }

  /// 根据行高获取图标大小
  static double iconSizeWithFontHeight(TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: 'A', style: style),
      textDirection: TextDirection.ltr,
    );
    final h = tp.preferredLineHeight;
    tp.dispose();
    return h;
  }
}

/// 在BuildContext上下文下的语法糖
extension TextStyleContextX on BuildContext {
  TextStyle createTextStyle({
    Color? color,
    double size = AppFontSize.md,
    FontWeight weight = FontWeight.w400,
    TextDecoration decoration = .none,
    double opacity = 1.0,
    String? fontFamily,
    double? letterSpacing,
    bool tabularFigures = false,
  }) {
    return AppTextStyle.create(
      context: this,
      color: color,
      size: size,
      weight: weight,
      decoration: decoration,
      opacity: opacity,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
      tabularFigures: tabularFigures,
    );
  }

  double getIconSize([dynamic size = AppIconSize.md]) =>
      AppTextStyle.iconSize(size);

  double getIconSizeWithFontHeight(TextStyle style) =>
      AppTextStyle.iconSizeWithFontHeight(style);
}
