import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import '../tools/details_ctrl_mixin.dart';

class DetailsPageController extends GetxController
    with DetailsPageControllerBase {
  final List<String> pathList;
  final String operateArea;

  DetailsPageController({required this.pathList, required this.operateArea});

  MusicCacheController get _musicCacheController =>
      Get.find<MusicCacheController>();

  UserPlayListController get _userPlayListController =>
      Get.find<UserPlayListController>();

  @override
  final items = <MusicCache>[].obs; // 也许可以去除Rx

  @override
  final Rx<Uint8List> headCover = kTransparentImage.obs;

  Worker? _syncSongEditedWorker;
  Worker? _syncRemoveWorker;

  @override
  void onInit() {
    super.onInit();

    _syncSongEditedWorker = ever(_musicCacheController.songUpdatedSignal, (
      MusicCache? updatedSong,
    ) {
      if (updatedSong == null) return;
      final index = items.indexWhere((m) => m.path == updatedSong.path);
      if (index != -1) {
        items[index] = updatedSong;
      }
    });

    _syncRemoveWorker = ever(_userPlayListController.songDeletedSignal, (
      List<String> removeList,
    ) {
      if (removeList.isEmpty) {
        return;
      }

      items.removeWhere((v) => removeList.contains(v.path));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetailsData(pathList, operateArea);
    });
  }

  @override
  void onClose() {
    _syncSongEditedWorker?.dispose();
    _syncRemoveWorker?.dispose();
    super.onClose();
  }

  Future<void> _loadDetailsData(
    List<String> pathList,
    String operateArea, {
    bool loadCover = true,
  }) async {
    final pathSet = pathList.toSet();
    items.value =
        _musicCacheController.items
            .where((v) => pathSet.contains(v.path))
            .toList();

    itemReSort(operateArea: operateArea);
    if (loadCover) {
      _loadCover();
    }
  }

  Future<void> _loadCover() async {
    if (items.isEmpty) return;
    try {
      final firstItem = items.first;
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
}
