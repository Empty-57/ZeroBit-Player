import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// ImageFilter缓存类
class ImageFilterCache {
  ImageFilterCache._();

  static final Map<int, ui.ImageFilter> _blurCache = {};

  /// 缓存上限
  static const int _maxBlurCacheSize = 32;

  /// 带缓存的 [ui.ImageFilter.blur]。
  /// sigma 会被量化到 0.5 的步长
  static ui.ImageFilter imageFilter({
    required double sigma,
    ui.TileMode tileMode = ui.TileMode.clamp,
  }) {
    final int quantized = (sigma * 2).round();
    final int key = (quantized << 4) | tileMode.index;

    final ui.ImageFilter? cached = _blurCache[key];
    if (cached != null) return cached;

    if (_blurCache.length >= _maxBlurCacheSize) _blurCache.clear();

    final ui.ImageFilter filter = ui.ImageFilter.blur(
      sigmaX: quantized / 2,
      sigmaY: quantized / 2,
      tileMode: tileMode,
    );
    _blurCache[key] = filter;
    return filter;
  }

  /// 释放缓存
  static void clearCache() => _blurCache.clear();
}

/// 按 (矩形尺寸 + 渐变参数) 缓存 [ui.Shader]。
class GradientShaderCache {
  GradientShaderCache({this.maxSize = 8});

  final int maxSize;
  final Map<_ShaderKey, ui.Shader> _cache = {};

  ui.Shader shader({required Gradient gradient, required ui.Rect rect}) {
    final _ShaderKey key = _ShaderKey(gradient, rect);

    final ui.Shader? cached = _cache[key];
    if (cached != null) return cached;

    if (_cache.length >= maxSize) _cache.clear();

    final ui.Shader created = gradient.createShader(rect);
    _cache[key] = created;
    return created;
  }

  void clear() => _cache.clear();
}

class _ShaderKey {
  const _ShaderKey(this.gradient, this.rect);

  final Gradient gradient;
  final ui.Rect rect;

  @override
  bool operator ==(Object other) =>
      other is _ShaderKey && other.rect == rect && other.gradient == gradient;

  @override
  int get hashCode => Object.hash(gradient, rect);
}
