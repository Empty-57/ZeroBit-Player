import 'package:flutter/material.dart';
import 'package:zerobit_player/core/theme/style_manager.dart';

/// 仅提供 Hover 动画、点击事件与 Tooltip
class AppTappable extends StatefulWidget {
  final VoidCallback? onPressed;
  final String? tooltip;
  final BorderRadius borderRadius;
  final Color? background;
  final Color? hoverBackground;
  final BoxBorder? border;
  final Widget child;

  const AppTappable({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.borderRadius = AppRadius.xsAll,
    this.background,
    this.hoverBackground,
    this.border,
  });

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _hovered = false;

  @override
  void didUpdateWidget(covariant AppTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _hovered = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isHovering = enabled && _hovered;

    Widget content = AnimatedContainer(
      duration: AppDuration.instant,
      curve: AppCurve.standard,
      decoration: BoxDecoration(
        color: isHovering
            ? (widget.hoverBackground ?? widget.background)
            : widget.background,
        borderRadius: widget.borderRadius,
        border: widget.border,
      ),
      child: widget.child,
    );

    if (enabled) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }

    return content;
  }
}
