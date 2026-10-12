import 'package:flutter/material.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';

final SettingController _settingController = SettingController.instance;

enum AppFontSize {
  xs(11.0),
  sm(13.0),
  md(15.0),
  lg(17.0),
  xl(19.0),
  xxl(21.0),
  subtitle(24.27),
  title(30.742);

  final double value;

  const AppFontSize(this.value);
}

enum AppIconSize {
  sm(18.0),
  md(20.0),
  lg(22.0);

  final double value;

  const AppIconSize(this.value);
}

class AppTextStyle {
  const AppTextStyle._();

  /// 通用样式生成
  static TextStyle create({
    BuildContext? context,
    Color? color,
    dynamic size = AppFontSize.md,
    FontWeight weight = FontWeight.w400,
    TextDecoration decoration = TextDecoration.none,
    double opacity = 1.0,
    String? fontFamily,
    double? letterSpacing,
  }) {
    final double resolvedSize = switch (size) {
      AppFontSize preset => preset.value,
      num number => number.toDouble(),
      _ => AppFontSize.md.value,
    };

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
      fontSize: resolvedSize,
      fontWeight: weight,
      decoration: decoration,
      fontFamily: fontFamily ?? _settingController.fontFamily.value,
      letterSpacing: letterSpacing,
    );
  }

  /// 通用图标大小解析
  static double iconSize([dynamic size = AppIconSize.md]) {
    return switch (size) {
      AppIconSize preset => preset.value,
      num number => number.toDouble(),
      _ => AppIconSize.md.value,
    };
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
    dynamic size = AppFontSize.md,
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
