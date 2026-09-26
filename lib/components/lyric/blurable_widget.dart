import 'package:flutter/material.dart';

import '../../tools/paint_cache.dart';

/// 合成层模糊组件
class BlurableLine extends StatelessWidget {
  final Widget child;
  final int blurSigma;

  const BlurableLine({super.key, required this.child, this.blurSigma = 0})
    : assert(blurSigma >= 0 && blurSigma <= 4, 'blurSigma 必须在 0 到 4 之间');

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilterCache.imageFilter(sigma: blurSigma.toDouble()),
      enabled: blurSigma != 0,
      child: child,
    );
  }
}

/// 字形模糊组件
class BlurableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final int blurSigma;

  const BlurableText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.blurSigma = 0,
  }) : assert(blurSigma >= 0 && blurSigma <= 4, 'blurSigma 必须在 0 到 4 之间');

  // 静态常量列表常驻内存，避免重复创建 MaskFilter 实例
  static const List<MaskFilter?> _filters = [
    null,
    MaskFilter.blur(BlurStyle.normal, 1),
    MaskFilter.blur(BlurStyle.normal, 2),
    MaskFilter.blur(BlurStyle.normal, 3),
    MaskFilter.blur(BlurStyle.normal, 4),
  ];

  @override
  Widget build(BuildContext context) {
    final int sigma = blurSigma.clamp(0, 4);

    if (sigma == 0) {
      return Text(
        text,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        softWrap: true,
      );
    }

    TextStyle effectiveStyle = style ?? const TextStyle();
    if (effectiveStyle.inherit) {
      effectiveStyle = DefaultTextStyle.of(context).style.merge(effectiveStyle);
    }

    final Paint? sourceForeground = effectiveStyle.foreground;
    final Paint paint = sourceForeground != null
        ? Paint.from(sourceForeground)
        : (Paint()..color = effectiveStyle.color ?? Colors.black);

    paint.maskFilter = _filters[sigma];

    effectiveStyle = effectiveStyle.copyWith(foreground: paint, color: null);

    return Text(
      text,
      style: effectiveStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      softWrap: true,
    );
  }
}
