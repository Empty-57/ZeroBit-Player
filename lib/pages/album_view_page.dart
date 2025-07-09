import 'package:flutter/material.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';

import '../field/app_routes.dart';
import '../getxController/music_cache_ctrl.dart';
import 'package:get/get.dart';

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();


class AlbumViewPage extends StatelessWidget {
  const AlbumViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SortedListView(
      title: '专辑',
      subTitle: '共${_musicCacheController.albumItemsDict.value.length}张专辑',
      sortedDict: _musicCacheController.albumItemsDict,
      toRoute: AppRoutes.albumList,
      items: _musicCacheController.items,
      letterList: _musicCacheController.albumHasLetter,
    );
  }
}