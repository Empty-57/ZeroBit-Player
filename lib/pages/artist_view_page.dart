import 'package:flutter/material.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';

import '../field/app_routes.dart';
import '../getxController/music_cache_ctrl.dart';
import 'package:get/get.dart';

class ArtistViewPage extends StatelessWidget {
  const ArtistViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MusicCacheController musicCacheController =
        Get.find<MusicCacheController>();
    return SortedListView(
      title: '艺术家',
      subTitle: '共${musicCacheController.artistItemsDict.value.length}位艺术家',
      sortedDict: musicCacheController.artistItemsDict,
      toRoute: AppRoutes.artistList,
      items: musicCacheController.items,
      letterList: musicCacheController.artistHasLetter,
    );
  }
}
