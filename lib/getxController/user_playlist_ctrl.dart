import 'package:get/get.dart';
import 'package:zerobit_player/HIveCtrl/models/user_playlist_model.dart';
import 'package:zerobit_player/components/get_snack_bar.dart';

import '../HIveCtrl/hive_manager.dart';

class UserPlayListController extends GetxController{
  final items=<UserPlayListCache>[].obs;

  final _userPlayListCacheBox=HiveManager.userPlayListCacheBox;

  void _initHive(){
    items.value=_userPlayListCacheBox.getAll();
  }

  @override
  void onInit(){
    super.onInit();
    _initHive();
  }

  Future<void> createPlayList({required String userKey})async{
    final allKeys=_userPlayListCacheBox.getKeyAll();

    if(allKeys.contains(userKey)){
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }

    await _userPlayListCacheBox.put(
        data: UserPlayListCache(
            pathList: <String>[],
            userKey: userKey
        ),
        key: userKey
    );

    items.add(UserPlayListCache(
            pathList: <String>[],
            userKey: userKey
        ));

  }

  Future<void> removePlayList({required String userKey})async{
    await _userPlayListCacheBox.del(key: userKey);
    items.removeWhere((v)=>v.userKey==userKey);
  }

  Future<void> renamePlayList({required String oldKey,required String newKey})async{
    final allKeys=_userPlayListCacheBox.getKeyAll();

    if(allKeys.contains(newKey)){
      showSnackBar(title: "WARNING", msg: "重复的歌单名称！");
      return;
    }

    final oldValue =_userPlayListCacheBox.get(key: oldKey);
    if(oldValue==null){
      return;
    }

    await removePlayList(userKey: oldKey);

    await _userPlayListCacheBox.put(
        data: UserPlayListCache(
        pathList: oldValue.pathList,
            userKey: newKey
        ), key: newKey
    );
    items.add(UserPlayListCache(
        pathList: oldValue.pathList,
            userKey: newKey
        )
    );
  }

}