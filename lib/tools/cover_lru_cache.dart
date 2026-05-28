import 'dart:typed_data';

abstract class CoverLRUCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxSize = 300;

  static Uint8List? get(String path) => _cache[path];

  static void put(String path, Uint8List data) {
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = data;
  }
}
