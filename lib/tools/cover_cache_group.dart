import 'package:flutter/widgets.dart';

/// ImageProvider缓存类
class ImageProviderCache {
  ImageProviderCache._();
  static final instance = ImageProviderCache._();

  /// 最多跟踪的 provider 数量，默认对齐全局 ImageCache 的条数上限
  static final int _maxTracked =
      PaintingBinding.instance.imageCache.maximumSize;

  final Set<ImageProvider> _providers = {};

  /// 跟踪并逐出
  void track(ImageProvider provider) {
    if (_providers.contains(provider)) return;

    if (_maxTracked > 0 && _providers.length >= _maxTracked) {
      _providers.first.evict();
      _providers.remove(_providers.first);
    }
    _providers.add(provider);
  }

  void evictAll() {
    if (_providers.isEmpty) return;
    for (final provider in _providers) {
      provider.evict();
    }
    _providers.clear();
  }
}
