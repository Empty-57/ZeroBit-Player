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
import '../tools/get_sort_type.dart';
import 'music_cache_ctrl.dart';

class PlayListController extends GetxController with AudioControllerGenClass {
  final UserPlayListCache userArgs;
  PlayListController({required this.userArgs});

  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();

  final SettingController _settingController = Get.find<SettingController>();

  final _userPlayListCacheBox = HiveManager.userPlayListCacheBox;

  @override
  final headCover = kTransparentImage.obs;

  static final audioListItems = <MusicCache>[].obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    headCover.value = kTransparentImage;
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

  void _loadData() async {
    audioListItems.value =
        _musicCacheController.items
            .where((v) => userArgs.pathList.contains(v.path))
            .toList();

    userArgs.pathList.retainWhere(
      (v) =>
          _musicCacheController.items.map((p) => p.path).toList().contains(v),
    );

    syncCache();

    itemReSort(type: _settingController.sortMap[OperateArea.playList]);
    if (_settingController.isReverse.value) {
      itemReverse();
    }

    if (audioListItems.isNotEmpty) {
      final title = audioListItems[0].title;
      final artist_ = audioListItems[0].artist;
      final artist =
          (artist_.isNotEmpty && artist_ != 'UNKNOWN') ? ' - $artist_' : '';
      final cover = await getCover(path: audioListItems[0].path, sizeFlag: 1);
      if (cover != null && cover.isNotEmpty) {
        headCover.value = cover;
      } else {
        final coverDataNet = await saveCoverByText(
          text: title + artist,
          songPath: audioListItems[0].path,
          saveCover: false,
        );

        if (coverDataNet != null && coverDataNet.isNotEmpty) {
          headCover.value = Uint8List.fromList(coverDataNet);
        } else {
          headCover.value = kTransparentImage;
        }
      }
    }
  }

  @override
  void itemReSort({required int type}) {
    audioListItems.sort(
      (a, b) => getSortType(
        type: type,
        data: a,
      ).compareTo(getSortType(type: type, data: b)),
    );
    if (_settingController.isReverse.value) {
      itemReverse();
    }
  }

  @override
  void itemReverse() {
    audioListItems.assignAll(audioListItems.reversed.toList());
  }

  static void audioListSyncMetadata({
    required int index,
    required MusicCache newCache,
  }) {
    if (audioListItems.isEmpty || index > audioListItems.length - 1) {
      return;
    }
    audioListItems[index] = newCache;
  }
}
