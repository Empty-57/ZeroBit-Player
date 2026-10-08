import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

class _TiltData {
  final Offset offset;
  final double scale;

  const _TiltData({required this.offset, required this.scale});

  static _TiltData lerp(_TiltData a, _TiltData b, double t) {
    return _TiltData(
      offset: Offset.lerp(a.offset, b.offset, t) ?? Offset.zero,
      scale: lerpDouble(a.scale, b.scale, t) ?? 1.0,
    );
  }
}

/// 自定义的Tween，倾斜与缩放一起同步计算
class _TiltDataTween extends Tween<_TiltData> {
  _TiltDataTween({super.begin, super.end});

  @override
  _TiltData lerp(double t) {
    return _TiltData.lerp(
      begin ?? const _TiltData(offset: Offset.zero, scale: 1.0),
      end ?? const _TiltData(offset: Offset.zero, scale: 1.0),
      t,
    );
  }
}

/// 3D 透视倾斜组件
class Tilt3D extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double maxAngle;
  final double scale;
  final bool enableGlare;
  final Color glareColor;

  const Tilt3D({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.maxAngle = 0.15,
    this.scale = 1.04,
    this.enableGlare = true,
    this.glareColor = Colors.white,
  });

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  late final _targetData = signal<_TiltData>(
    const _TiltData(offset: Offset.zero, scale: 1.0),
  );
  late final _isHover = signal<bool>(false);

  @override
  void dispose() {
    _targetData.dispose();
    _isHover.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;

    // 计算鼠标相对于组件中心的归一化偏移量 [-1.0, 1.0]
    final x = (((event.localPosition.dx / size.width) - 0.5) * 2).clamp(
      -1.0,
      1.0,
    );
    final y = (((event.localPosition.dy / size.height) - 0.5) * 2).clamp(
      -1.0,
      1.0,
    );

    _targetData.value = _TiltData(offset: Offset(x, y), scale: widget.scale);
    _isHover.value = true;
  }

  void _onExit(PointerExitEvent event) {
    _targetData.value = const _TiltData(offset: Offset.zero, scale: 1.0);
    _isHover.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final rbWarpedChild = RepaintBoundary(child: widget.child);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          onHover: (e) => _onHover(e, size),
          onExit: _onExit,
          cursor: SystemMouseCursors.basic,
          child: SignalBuilder(
            builder: (context) {
              final target = _targetData.value;
              final isHovering = _isHover.value;

              return TweenAnimationBuilder<_TiltData>(
                tween: _TiltDataTween(
                  begin: const _TiltData(offset: Offset.zero, scale: 1.0),
                  end: target,
                ),
                duration: Duration(milliseconds: isHovering ? 150 : 400),
                curve: Curves.easeOutCubic,
                child: rbWarpedChild,
                builder: (context, current, child) {
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0012) // 设置 m32 透视除数
                    ..rotateX(
                      current.offset.dy * widget.maxAngle,
                    ) // 上下移动控制绕 X 轴旋转
                    ..rotateY(
                      -current.offset.dx * widget.maxAngle,
                    ) // 左右移动控制绕 Y 轴旋转
                    ..scaleByDouble(current.scale, current.scale, 1.0, 1.0);

                  // 计算当前动画进展比例
                  final scaleDelta = (widget.scale - 1.0).abs();
                  final progress = scaleDelta > 0.001
                      ? ((current.scale - 1.0) / scaleDelta).clamp(0.0, 1.0)
                      : (isHovering ? 1.0 : 0.0);

                  return Transform(
                    filterQuality: FilterQuality.low,
                    transform: transform,
                    alignment: FractionalOffset.center,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: widget.borderRadius,
                        // 阴影平滑过渡
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: lerpDouble(0.15, 0.35, progress)!,
                            ),
                            offset: Offset(
                              -current.offset.dx * 12,
                              lerpDouble(
                                2.0,
                                12.0 - current.offset.dy * 10,
                                progress,
                              )!,
                            ),
                            blurRadius: lerpDouble(8.0, 16.0, progress)!,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: widget.borderRadius,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            child!,
                            // 反光层
                            if (widget.enableGlare && progress > 0.01)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        center: Alignment(
                                          current.offset.dx,
                                          current.offset.dy,
                                        ),
                                        radius: 1.2,
                                        colors: [
                                          widget.glareColor.withValues(
                                            alpha: 0.2 * progress,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
