import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'lyric_arg_constants.dart';

class _ProgressGradientTransform extends GradientTransform {
  const _ProgressGradientTransform({required this.offset, required this.scale});

  final double offset;
  final double scale;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      (Matrix4.diagonal3Values(scale, 1, 1)
        ..setTranslationRaw(scale * offset, 0, 0));

  @override
  bool operator ==(Object other) =>
      other is _ProgressGradientTransform &&
      other.offset == offset &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(offset, scale);
}

///逐字渐变遮罩
///
/// 这里自己管理 Shader 生命周期：区域与进度都没变就复用，变了先释放旧的
///
/// 渲染对象销毁时一并释放。
class ProgressShaderMask extends SingleChildRenderObjectWidget {
  const ProgressShaderMask({
    super.key,
    required this.progress,
    required this.scale,
    required this.gradientColors,
    required Widget super.child,
  });
  final double progress;
  final double scale;
  final List<Color> gradientColors;

  @override
  RenderProgressShaderMask createRenderObject(BuildContext context) =>
      RenderProgressShaderMask(
        progress: progress,
        scale: scale,
        gradientColors: gradientColors,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProgressShaderMask renderObject,
  ) {
    renderObject
      ..progress = progress
      ..scale = scale
      ..gradientColors = gradientColors;
  }
}

/// [ProgressShaderMask] 的渲染对象，负责着色器的复用与释放。
class RenderProgressShaderMask extends RenderProxyBox {
  RenderProgressShaderMask({
    required this._progress,
    required this._scale,
    required this._gradientColors,
  });

  double _progress;

  double get progress => _progress;

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    _markShaderDirty();
  }

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    _markShaderDirty();
  }

  List<Color> _gradientColors;

  List<Color> get gradientColors => _gradientColors;

  set gradientColors(List<Color> value) {
    if (_gradientColors == value) return;
    _gradientColors = value;
    _markShaderDirty();
  }

  /// 当前复用中的着色器，以及它对应的区域。
  ui.Shader? _shader;
  Rect? _shaderBounds;
  bool _shaderDirty = true;

  void _markShaderDirty() {
    _shaderDirty = true;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  ui.Shader _buildShader(Rect bounds) {
    // 颜色平均分三段：高亮区 过渡区 透明区
    // 在动画开始的时候，覆盖到 Text 上的应该是透明区，应该先把整个遮罩层应该向左移动
    // 但是因为遮罩层放大了3倍，所以应该用 -0.666 * bounds.width 得到透明区位置，负号为向左
    // 随着 progress 增大 遮罩会逐渐向右移动
    final double dx =
        LyricConstants.shaderOffsetFactor * bounds.width * (1 - _progress);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: _gradientColors,
      stops: LyricConstants.gradientStops,
      transform: _ProgressGradientTransform(offset: dx, scale: _scale),
    ).createShader(bounds);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      _releaseShader();
      return;
    }

    final bounds = Offset.zero & size;
    if (_shaderDirty || _shader == null || _shaderBounds != bounds) {
      // 更新shader之前先释放
      _shader?.dispose();
      _shader = _buildShader(bounds);
      _shaderBounds = bounds;
      _shaderDirty = false;
    }

    layer ??= ShaderMaskLayer();
    layer!
      ..shader = _shader
      ..maskRect = offset & size
      ..blendMode = BlendMode.srcIn;
    context.pushLayer(layer!, super.paint, offset);
  }

  void _releaseShader() {
    _shader?.dispose();
    _shader = null;
    _shaderBounds = null;
    _shaderDirty = true;
  }

  @override
  void dispose() {
    _releaseShader();
    super.dispose();
  }
}
