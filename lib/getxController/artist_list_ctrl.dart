import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'dart:typed_data';
import '../API/apis.dart';
import '../field/operate_area.dart';
import '../src/rust/api/music_tag_tool.dart';
import '../tools/audio_ctrl_mixin.dart';
import 'music_cache_ctrl.dart';

class ArtistListController extends GetxController with AudioControllerGenClass {
  final List<String> pathList;
  ArtistListController({required this.pathList});

  final MusicCacheController _musicCacheController =
      Get.find<MusicCacheController>();
  final SettingController _settingController = Get.find<SettingController>();

  static final audioListItems = <MusicCache>[].obs;

  @override
  final Rx<Uint8List> headCover = kTransparentImage.obs;

  @override
  RxList<MusicCache> get items => audioListItems;

  @override
  void onInit() {
    super.onInit();
    _loadData();
  }

  Future<void> _loadData() async {
    final pathSet = pathList.toSet();

    audioListItems.value =
        _musicCacheController.items
            .where((v) => pathSet.contains(v.path))
            .toList();

    itemReSort(type: _settingController.sortMap[OperateArea.artistList]);

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
