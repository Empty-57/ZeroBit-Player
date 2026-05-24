import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/tools/audio_ctrl_mixin.dart';
import 'dart:typed_data';
import '../API/apis.dart';
import '../HIveCtrl/hive_manager.dart';
import '../HIveCtrl/models/user_playlist_model.dart';
import '../field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import 'music_cache_ctrl.dart';

class PlayListController extends GetxController with AudioControllerGenClass {
  final UserPlayListCache userArgs;
  PlayListController({required this.userArgs});

  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  final SettingController _settingController = Get.find<SettingController>();
  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  static final RxList<MusicCache> audioListItems = <MusicCache>[].obs;

  @override
  final Rx<Uint8List> headCover = kTransparentImage.obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    super.onInit();
    _loadData();
  }

  @override
  void onClose() {
    headCover.value = kTransparentImage;
    audioListItems.value = [];
    super.onClose();
  }

  Future<void> syncCache() async {
    await _userPlayListCacheBox.put(
      data: UserPlayListCache(
        pathList: userArgs.pathList,
        userKey: userArgs.userKey,
      ),
      key: userArgs.userKey,
    );
  }

  Future<void> _loadData() async {
    final allLibraryPaths =
        _musicCacheController.items.map((e) => e.path).toSet();

    final originalLength = userArgs.pathList.length;

    userArgs.pathList.retainWhere((path) => allLibraryPaths.contains(path));

    // 只有当确实清理了失效歌曲时，才进行 I/O 写库操作
    if (userArgs.pathList.length != originalLength) {
      await syncCache();
    }

    final playlistPathSet = userArgs.pathList.toSet();
    audioListItems.value =
        _musicCacheController.items
            .where((v) => playlistPathSet.contains(v.path))
            .toList();

    itemReSort(type: _settingController.sortMap[OperateArea.playList]);

    if (audioListItems.isEmpty) return;

    try {
      final firstItem = audioListItems.first;
      final title = firstItem.title;
      final artist = firstItem.artist;
      final artistText =
          (artist.isNotEmpty && artist != 'UNKNOWN') ? ' - $artist' : '';

      final cover = await getCover(path: firstItem.path, sizeFlag: 1);
      if (cover != null && cover.isNotEmpty) {
        headCover.value = cover;
        return;
      }

      final coverDataNet = await saveCoverByText(
        text: '$title$artistText',
        songPath: firstItem.path,
        saveCover: false,
      );

      if (coverDataNet != null && coverDataNet.isNotEmpty) {
        headCover.value = Uint8List.fromList(coverDataNet);
      } else {
        headCover.value = kTransparentImage;
      }
    } catch (e) {
      headCover.value = kTransparentImage;
    }
  }

  static void audioListSyncMetadata({
    required int index,
    required MusicCache newCache,
  }) {
    if (audioListItems.isEmpty || index < 0 || index >= audioListItems.length) {
      return;
    }
    audioListItems[index] = newCache;
  }
}
