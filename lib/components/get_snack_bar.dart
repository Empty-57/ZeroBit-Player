import 'dart:async';

import 'package:flutter/material.dart';

/// SnackBar 的弹出位置
enum SnackPosition { top, bottom }

/// 根导航器 Key，用于在没有 BuildContext 的场景下取得 Overlay 与主题
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

OverlayEntry? _currentSnackBarEntry;

void _removeCurrentSnackBar() {
  _currentSnackBarEntry?.remove();
  _currentSnackBarEntry = null;
}

void showSnackBar({
  required String title,
  required String msg,
  SnackPosition position = SnackPosition.bottom,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor = Colors.red,
  Color? textColor = Colors.white,
}) {
  if (rootNavigatorKey.currentState?.overlay == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSnackBar(
        title: title,
        msg: msg,
        position: position,
        duration: duration,
        backgroundColor: backgroundColor,
        textColor: textColor,
      );
    });
    return;
  }

  _showSnackBar(
    title: title,
    msg: msg,
    position: position,
    duration: duration,
    backgroundColor: backgroundColor,
    textColor: textColor,
  );
}

void _showSnackBar({
  required String title,
  required String msg,
  required SnackPosition position,
  required Duration duration,
  Color? backgroundColor,
  Color? textColor,
}) {
  final OverlayState? overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) {
    return;
  }

  _removeCurrentSnackBar();

  final BuildContext ctx = overlay.context;
  backgroundColor = Theme.of(ctx).colorScheme.secondaryContainer;
  textColor = Theme.of(ctx).colorScheme.onSecondaryContainer;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _SnackBarView(
      title: title,
      msg: msg,
      position: position,
      duration: duration,
      backgroundColor: backgroundColor!,
      textColor: textColor!,
      onDismissed: () {
        if (identical(_currentSnackBarEntry, entry)) {
          _removeCurrentSnackBar();
        }
      },
    ),
  );

  _currentSnackBarEntry = entry;
  overlay.insert(entry);
}

class _SnackBarView extends StatefulWidget {
  const _SnackBarView({
    required this.title,
    required this.msg,
    required this.position,
    required this.duration,
    required this.backgroundColor,
    required this.textColor,
    required this.onDismissed,
  });

  final String title;
  final String msg;
  final SnackPosition position;
  final Duration duration;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onDismissed;

  @override
  State<_SnackBarView> createState() => _SnackBarViewState();
}

class _SnackBarViewState extends State<_SnackBarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: Offset(0, widget.position == SnackPosition.top ? -0.5 : 0.5),
    end: Offset.zero,
  ).animate(_curve);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    _timer = null;
    if (!mounted) {
      return;
    }
    await _controller.reverse();
    if (!mounted) {
      return;
    }
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTop = widget.position == SnackPosition.top;

    return Positioned(
      left: 0,
      right: 0,
      top: isTop ? 8 : null,
      bottom: isTop ? null : 8,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: _offset,
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.8,
              ),
              child: Material(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(4),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 15.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.msg,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 13.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
