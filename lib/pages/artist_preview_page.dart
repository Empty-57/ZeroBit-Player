import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';

class ArtistPreviewPage extends GetView<MusicCacheController> {
  const ArtistPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SortedListView(
      title: '艺术家',
      subTitle: '共${c.artistItemsDict.length}位艺术家',
      sortedDict: c.artistItemsDict,
      toRoute: AppRoutes.artistDetails,
      items: c.items,
      letterList: c.artistHasLetter,
      rwScrollOffset: c.rwScrollOffset,
    );
  }
}
