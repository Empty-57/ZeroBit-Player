import 'package:flutter/material.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';

import '../field/app_routes.dart';
import '../getxController/music_cache_ctrl.dart';
import 'package:get/get.dart';

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class ArtistViewPage extends StatelessWidget {
  const ArtistViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SortedListView(
      title: '艺术家',
      subTitle: '共${_musicCacheController.artistItemsDict.value.length}位艺术家',
      sortedDict: _musicCacheController.artistItemsDict,
      toRoute: AppRoutes.artistList,
      items: _musicCacheController.items,
      letterList: _musicCacheController.artistHasLetter,
    );
  }
}
