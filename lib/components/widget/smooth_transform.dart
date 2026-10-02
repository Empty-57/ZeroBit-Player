import 'package:flutter/widgets.dart';

/// 平滑位移组件，为了消除亚像素抖动，将useFilterQuality设为true
///
/// 根据useFilterQuality，切换 `filterQuality`，防止常驻saveLayer
class SmoothTranslate extends StatelessWidget {
  final double dy;
  final double dx;
  final bool useFilterQuality;
  final Widget child;

  const SmoothTranslate({
    super.key,
    required this.dy,
    this.dx = 0.0,
    required this.useFilterQuality,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      filterQuality: useFilterQuality ? .low : null,
      offset: Offset(dx, dy),
      child: child,
    );
  }
}

/// 平滑缩放组件，取舍思路同 [SmoothTranslate]。
class SmoothScale extends StatelessWidget {
  final double scale;
  final bool useFilterQuality;
  final Alignment alignment;
  final Widget child;

  const SmoothScale({
    super.key,
    required this.useFilterQuality,
    required this.alignment,
    required this.child,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      alignment: alignment,
      filterQuality: useFilterQuality ? .low : null,
      child: child,
    );
  }
}
