import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 使 [builder] 能便捷地响应 hover 和 tap 事件的包装器
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;

  /// [onPressed] 为 null 则 [hovered] 恒为false
  final VoidCallback? onPressed;

  const HoverBuilder({super.key, required this.builder, this.onPressed});

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  void didUpdateWidget(HoverBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _hovered = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onPressed == null) return widget.builder(context, false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}

/// 让鼠标滚轮调整数值，并且不把滚动继续传给外层滚动视图。
class ScrollAdjustRegion extends StatelessWidget {
  final Widget child;

  /// 方向：向上滚为 +1，向下滚为 -1
  final ValueChanged<int> onAdjust;

  const ScrollAdjustRegion({
    super.key,
    required this.child,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        GestureBinding.instance.pointerSignalResolver.register(event, (
          // 内层先注册，不会传到外层
          resolved,
        ) {
          final scroll = resolved as PointerScrollEvent;
          final dy = scroll.scrollDelta.dy;
          if (dy == 0) return;
          onAdjust(dy < 0 ? 1 : -1);
        });
      },
      child: child,
    );
  }
}
