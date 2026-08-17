import 'dart:typed_data';

abstract class CoverLRUCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxSize = 100;

  static Uint8List? get(String path) {
    final data = _cache[path];
    if (data != null) {
      // 如果被访问了，先移除再重新插入，使其移动到 _cache 的末尾
      _cache.remove(path);
      _cache[path] = data;
    }
    return data;
  }

  static void put(String path, Uint8List data) {
    if (_cache.containsKey(path)) {
      _cache.remove(path);
    } else if (_cache.length >= _maxSize) {
      // 移除最旧的元素
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = data;
  }
}
