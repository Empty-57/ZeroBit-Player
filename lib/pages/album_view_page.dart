import 'package:flutter/material.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';

import '../field/app_routes.dart';
import '../getxController/music_cache_ctrl.dart';
import 'package:get/get.dart';

class AlbumViewPage extends StatelessWidget {
  const AlbumViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MusicCacheController musicCacheController =
        Get.find<MusicCacheController>();
    return SortedListView(
      title: '专辑',
      subTitle: '共${musicCacheController.albumItemsDict.value.length}张专辑',
      sortedDict: musicCacheController.albumItemsDict,
      toRoute: AppRoutes.albumList,
      items: musicCacheController.items,
      letterList: musicCacheController.albumHasLetter,
    );
  }
}
