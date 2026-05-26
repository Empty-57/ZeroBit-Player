import 'package:hive_ce_flutter/hive_flutter.dart';

class StorageCRUD<T> {
  final Box<T> cacheBox;
  const StorageCRUD({required this.cacheBox});

  Future<void> put({required T data, required String key}) async{
    await cacheBox.put(key, data);
  }

  Future<void> putAll({required Map<String, T> data})async {
    await cacheBox.putAll(data);
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

  Future<void> del({required String key})async {
    await cacheBox.delete(key);
  }

  Future<void> delAll({required List<String> keyList}) async{
    await cacheBox.deleteAll(keyList);
  }
}
