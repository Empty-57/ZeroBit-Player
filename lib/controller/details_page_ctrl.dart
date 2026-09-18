import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:signals/signals_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/controller/user_playlist_ctrl.dart';
import 'package:zerobit_player/hive_manager/models/music_cache_model.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/details_ctrl_mixin.dart';

class DetailsPageController with DetailsPageControllerBase {
  final List<String> pathList;
  final String operateArea;

  DetailsPageController({required this.pathList, required this.operateArea});

  MusicCacheController get _musicCacheController =>
      MusicCacheController.instance;

  UserPlayListController get _userPlayListController =>
      UserPlayListController.instance;

  @override
  final items = listSignal(<MusicCache>[]); // 也许可以去除Rx

  @override
  final Signal<Uint8List> headCover = signal(kTransparentImage);

  EffectCleanup? _syncSongEditedWorker;
  EffectCleanup? _syncRemoveWorker;

  void init() {
    _syncSongEditedWorker = effect(() {
      final MusicCache? updatedSong =
          _musicCacheController.songUpdatedSignal.value;
      if (updatedSong == null) return;
      untracked(() {
        final index = items.indexWhere((m) => m.path == updatedSong.path);
        if (index != -1) {
          items[index] = updatedSong;
        }
      });
    });

    bool isFirstSongDeleted = true;
    _syncRemoveWorker = effect(() {
      final List<String> removeList =
          _userPlayListController.songDeletedSignal.value;
      if (isFirstSongDeleted) {
        isFirstSongDeleted = false;
        return;
      }
      if (removeList.isEmpty) {
        return;
      }

      untracked(() {
        items.removeWhere((v) => removeList.contains(v.path));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetailsData(pathList, operateArea);
    });
  }

  void dispose() {
    _syncSongEditedWorker?.call();
    _syncRemoveWorker?.call();
    items.dispose();
    headCover.dispose();
  }

  Future<void> _loadDetailsData(
    List<String> pathList,
    String operateArea, {
    bool loadCover = true,
  }) async {
    final pathSet = pathList.toSet();
    items.value = _musicCacheController.items
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
      final artistText = (artist.isNotEmpty && artist != 'UNKNOWN')
          ? ' - $artist'
          : '';

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
