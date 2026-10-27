import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'func_extension.dart';

class AutoHideCursor extends StatefulWidget {
  final Widget child;
  final int timeout;
  final bool enabled;

  const AutoHideCursor({
    super.key,
    required this.child,
    this.timeout = 3000,
    this.enabled = true,
  });

  @override
  State<AutoHideCursor> createState() => _AutoHideCursorState();
}

class _AutoHideCursorState extends State<AutoHideCursor> {
  final Signal<bool> _visible = signal(true);
  late final void Function() _hideCursorDebounce = _hideCursor.debounce(
    ms: widget.timeout,
  );
  late final void Function() _showCursorThrottle = _showCursor.throttle();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _hideCursorDebounce();
    }
  }

  @override
  void didUpdateWidget(covariant AutoHideCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _hideCursorDebounce();
      } else {
        _showCursor();
      }
    }
  }

  @override
  void dispose() {
    _visible.dispose();
    super.dispose();
  }

  void _showCursor() {
    if (!_visible.value) {
      _visible.value = true;
    }
    _hideCursorDebounce();
  }

  void _hideCursor() {
    if (!mounted || !widget.enabled) return;
    if (_visible.value) {
      _visible.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (_) => _showCursorThrottle(),
      onPointerMove: (_) => _showCursorThrottle(),
      onPointerDown: (_) => _showCursorThrottle(),
      onPointerSignal: (_) => _showCursorThrottle(),
      child: Stack(
        children: [
          widget.child,

          Positioned.fill(
            child: SignalBuilder(
              builder: (_) {
                final isVisible = _visible.value;
                return MouseRegion(
                  cursor: isVisible
                      ? MouseCursor.defer
                      : SystemMouseCursors.none,
                  hitTestBehavior: isVisible
                      ? HitTestBehavior.deferToChild
                      : HitTestBehavior.opaque,
                  opaque: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
