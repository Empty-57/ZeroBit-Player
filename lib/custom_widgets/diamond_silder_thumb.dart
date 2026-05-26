import 'package:flutter/material.dart';

/// 自定义菱形按钮
class DiamondSliderThumbShape extends SliderComponentShape {
  /// 水平对角线长度
  final double horizontalDiagonal;

  /// 垂直对角线长度
  final double verticalDiagonal;

  const DiamondSliderThumbShape({
    this.horizontalDiagonal = 12,
    this.verticalDiagonal = 24,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    final width = verticalDiagonal;
    final height = verticalDiagonal;
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final paint =
        Paint()
          ..color = sliderTheme.thumbColor ?? Colors.blue
          ..style = PaintingStyle.fill;

    final hd2 = horizontalDiagonal / 2;
    final vd2 = verticalDiagonal / 2;

    final path =
        Path()
          ..moveTo(center.dx, center.dy - vd2) // 上顶点
          ..lineTo(center.dx + hd2, center.dy) // 右顶点
          ..lineTo(center.dx, center.dy + vd2) // 下顶点
          ..lineTo(center.dx - hd2, center.dy) // 左顶点
          ..close();

    canvas.drawPath(path, paint);
  }
}