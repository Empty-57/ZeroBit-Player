import 'package:flutter/material.dart';

/// 字形模糊歌词组件
class LyricText extends StatelessWidget {
  const LyricText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.blurSigma = 0,
  }) : assert(blurSigma >= 0 && blurSigma <= 4, 'blurSigma 必须在 0 到 4 之间');

  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final int blurSigma;

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
