import 'package:flutter/material.dart';

class RectangularValueIndicatorShape extends SliderComponentShape {
  final double width, height, radius;
  const RectangularValueIndicatorShape({
    this.width = 40,
    this.height = 24,
    this.radius = 4,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

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
    final canvas = context.canvas;
    final paint =
        Paint()
          ..color = sliderTheme.valueIndicatorColor!
          ..style = PaintingStyle.fill;

    // 先画一个圆角矩形
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -height), // 往上偏移一点
        width: width,
        height: height,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, paint);

    // 然后把文字画上去
    final tp = labelPainter;
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - height - tp.height / 2),
    );
  }
}