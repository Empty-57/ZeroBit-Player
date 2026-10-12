import 'package:flutter/material.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';

final SettingController _settingController = SettingController.instance;

abstract final class AppFontSize {
  static const double xs = 11.0;
  static const double sm = 13.0;
  static const double md = 15.0;
  static const double lg = 17.0;
  static const double xl = 19.0;
  static const double xxl = 21.0;
  static const double subtitle = 24.0;
  static const double title = 31.0;
}

abstract final class AppIconSize {
  static const double sm = 18.0;
  static const double md = 20.0;
  static const double lg = 22.0;
}

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
    );
  }

  double getIconSize([dynamic size = AppIconSize.md]) =>
      AppTextStyle.iconSize(size);

  double getIconSizeWithFontHeight(TextStyle style) =>
      AppTextStyle.iconSizeWithFontHeight(style);
}
