import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zerobit_player/components/play_bar_constant.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

/// 提示条的弹出位置
enum SnackPosition { top, bottom }

/// 提示语义
enum SnackType { info, success, warning, error }

/// 根导航器 Key，用于在没有 BuildContext 的场景下取得 Overlay 与主题
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

const double _edgeInset = AppSpacing.md;

/// 顶部位置要让开窗口控制栏
const double _topBarHeight = 48.0;

/// 内容最大宽度占窗口的比例
const double _maxWidthFactor = 0.8;

const double _shadowBlur = AppSpacing.lg;
const double _shadowAlpha = 0.18;

const Duration _enterDuration = AppDuration.slow;

OverlayEntry? _currentEntry;
GlobalKey<_SnackBarViewState>? _currentKey;

/// 当前这条的内容指纹，防抖
String? _currentSignature;

void _removeCurrent() {
  _currentEntry?.remove();
  _currentEntry = null;
  _currentKey = null;
  _currentSignature = null;
}

/// 按语义给出默认停留时长
Duration _defaultDurationOf(SnackType type) => switch (type) {
  SnackType.error => AppDuration.snackBarError,
  SnackType.warning => AppDuration.snackBarWarning,
  SnackType.success || SnackType.info => AppDuration.snackBarInfo,
};

/// 从 title 推断语义
SnackType _inferType(String title) {
  final upper = title.toUpperCase();
  if (upper.startsWith('ERR')) return SnackType.error;
  if (upper.startsWith('WARN')) return SnackType.warning;
  if (upper == 'OK') return SnackType.success;
  return SnackType.info;
}

/// 弹出一条全局提示，防抖
void showSnackBar({
  required String title,
  required String msg,
  SnackType? type,
  SnackPosition position = SnackPosition.bottom,
  Duration? duration,
}) {
  // Overlay 还没挂上，推到下一帧再弹
  if (rootNavigatorKey.currentState?.overlay == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _show(
        title: title,
        msg: msg,
        type: type,
        position: position,
        duration: duration,
      );
    });
    return;
  }

  _show(
    title: title,
    msg: msg,
    type: type,
    position: position,
    duration: duration,
  );
}

void _show({
  required String title,
  required String msg,
  required SnackType? type,
  required SnackPosition position,
  required Duration? duration,
}) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;

  final effectiveType = type ?? _inferType(title);
  final effectiveDuration = duration ?? _defaultDurationOf(effectiveType);
  final signature = '$title\u0000$msg\u0000${effectiveType.index}';

  // 防抖处理
  if (_currentEntry != null && _currentSignature == signature) {
    _currentKey?.currentState?.refresh(effectiveDuration);
    return;
  }

  _removeCurrent();

  final key = GlobalKey<_SnackBarViewState>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SnackBarView(
      key: key,
      title: title,
      msg: msg,
      type: effectiveType,
      position: position,
      duration: effectiveDuration,
      onDismissed: () {
        if (identical(_currentEntry, entry)) _removeCurrent();
      },
    ),
  );

  _currentEntry = entry;
  _currentKey = key;
  _currentSignature = signature;
  overlay.insert(entry);
}

/// 一种语义对应的外观
typedef _SnackStyle = ({Color background, Color foreground, IconData icon});

_SnackStyle _styleOf(SnackType type, ColorScheme scheme) => switch (type) {
  SnackType.error => (
    background: scheme.errorContainer,
    foreground: scheme.onErrorContainer,
    icon: PhosphorIconsFill.warningCircle,
  ),
  SnackType.warning => (
    background: scheme.tertiaryContainer,
    foreground: scheme.onTertiaryContainer,
    icon: PhosphorIconsFill.warning,
  ),
  SnackType.success => (
    background: scheme.primaryContainer,
    foreground: scheme.onPrimaryContainer,
    icon: PhosphorIconsFill.checkCircle,
  ),
  SnackType.info => (
    background: scheme.secondaryContainer,
    foreground: scheme.onSecondaryContainer,
    icon: PhosphorIconsFill.info,
  ),
};

class _SnackBarView extends StatefulWidget {
  const _SnackBarView({
    super.key,
    required this.title,
    required this.msg,
    required this.type,
    required this.position,
    required this.duration,
    required this.onDismissed,
  });

  final String title;
  final String msg;
  final SnackType type;
  final SnackPosition position;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_SnackBarView> createState() => _SnackBarViewState();
}

class _SnackBarViewState extends State<_SnackBarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _enterDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppCurve.standard,
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
    _restartTimer(widget.duration);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, _dismiss);
  }

  /// 同一条提示再次弹出：续上停留时间；若正在退场则拉回来
  void refresh(Duration duration) {
    if (!mounted) return;
    _controller.forward();
    _restartTimer(duration);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;

    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final isTop = widget.position == SnackPosition.top;
    final style = _styleOf(widget.type, Theme.of(context).colorScheme);
    final hasTitle = widget.title.trim().isNotEmpty;

    return Positioned(
      left: 0,
      right: 0,
      top: isTop ? _topBarHeight + _edgeInset : null,
      bottom: isTop ? null : PlayBarSpec.occupiedHeight + _edgeInset,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: _offset,
          child: Align(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * _maxWidthFactor,
              ),
              child: _SnackCard(
                style: style,
                title: hasTitle ? widget.title : null,
                msg: widget.msg,
                onTap: () => unawaited(_dismiss()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackCard extends StatelessWidget {
  final _SnackStyle style;
  final String? title;
  final String msg;
  final VoidCallback onTap;

  const _SnackCard({
    required this.style,
    required this.title,
    required this.msg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: AppRadius.smAll,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _shadowAlpha),
                  blurRadius: _shadowBlur,
                  offset: const Offset(0, AppSpacing.xs),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.lg,
                children: [
                  Icon(
                    style.icon,
                    size: AppIconSize.md,
                    color: style.foreground,
                  ),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xxs,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: context.createTextStyle(
                              size: AppFontSize.md,
                              color: style.foreground,
                              weight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          msg,
                          style: context.createTextStyle(
                            size: AppFontSize.sm,
                            color: style.foreground,
                            opacity: title != null
                                ? AppAlpha.textSecondary
                                : 1.0,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
