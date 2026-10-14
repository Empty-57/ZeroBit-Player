import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 使子元素拥有 点击/hover 状态与点击事件，不使用[TextButton]
class AppTappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  final BorderRadius borderRadius;

  /// 常态背景，null 为透明
  final Color? background;

  /// 悬停时的背景色，null 表示不做悬停反馈
  final Color? hoverBackground;

  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;

  const AppTappable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = AppRadius.xsAll,
    this.background,
    this.hoverBackground,
    this.border,
    this.padding,
    this.tooltip,
  });

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _hovered = false;

  void _setHovered(bool value) {
    // 防止误响应
    if (!mounted || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  void didUpdateWidget(AppTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 变为不可点击时清掉悬停态，否则会停在高亮色上。
    // 这里已经处于重建流程中，直接改字段即可，不必再 setState
    if (widget.onTap == null) _hovered = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final showHover = enabled && _hovered && widget.hoverBackground != null;

    Widget content = AnimatedContainer(
      duration: AppDuration.instant,
      curve: AppCurve.standard,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: showHover ? widget.hoverBackground : widget.background,
        borderRadius: widget.borderRadius,
        border: widget.border,
      ),
      child: widget.child,
    );

    if (enabled) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        waitDuration: AppDuration.tooltipWait,
        child: content,
      );
    }

    return content;
  }
}

/// 使 [builder] 能便捷地响应 hover 事件的包装器
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;

  /// [onTap] 为 null 则 [hovered] 恒为false
  final VoidCallback? onTap;

  const HoverBuilder({super.key, required this.builder, this.onTap});

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
    if (widget.onTap == null) _hovered = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.builder(context, false);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
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
