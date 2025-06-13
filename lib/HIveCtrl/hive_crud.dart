import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageCRUD<T> {
  final Box<T> cacheBox;
  const StorageCRUD({required this.cacheBox});

  void put({required T data, required String key}) {
    cacheBox.put(key, data);
  }

  void putAll({required Map<String, T> data}) {
    cacheBox.putAll(data);
  }

  T? get({required String key}) {
    return cacheBox.get(key);
  }

  List<T> getAll() {
    return cacheBox.values.toList();
  }
  
  List getKeyAll(){
    return cacheBox.keys.toList();
  }

  void del({required String key}) {
    cacheBox.delete(key);
  }

  void delAll({required List<String> keyList}) {
    cacheBox.deleteAll(keyList);
  }
}
