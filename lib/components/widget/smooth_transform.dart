import 'package:flutter/widgets.dart';

/// 平滑位移组件。
///
/// 根据isAnimating，切换 `filterQuality`，防止常驻saveLayer
class SmoothTranslate extends StatelessWidget {
  final double dy;
  final bool isAnimating;
  final Widget child;

  const SmoothTranslate({
    super.key,
    required this.dy,
    required this.isAnimating,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      filterQuality: isAnimating ? FilterQuality.low : null,
      offset: Offset(0, dy),
      child: child,
    );
  }
}

/// 平滑缩放组件，取舍思路同 [SmoothTranslate]。
class SmoothScale extends StatelessWidget {
  final double scale;
  final Alignment alignment;
  final Widget child;

  const SmoothScale({
    super.key,
    required this.scale,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      alignment: alignment,
      filterQuality: scale == 1.0 ? null : FilterQuality.low,
      child: child,
    );
  }
}
