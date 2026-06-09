import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/sorted_list_view.dart';
import 'package:zerobit_player/controller/music_cache_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';

class AlbumPreviewPage extends GetView<MusicCacheController> {
  const AlbumPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SortedListView(
      title: '专辑',
      subTitle: '共${c.albumItemsDict.length}张专辑',
      sortedDict: c.albumItemsDict,
      toRoute: AppRoutes.albumDetails,
      items: c.items,
      letterList: c.albumHasLetter,
      rwScrollOffset: c.rwScrollOffset,
    );
  }
}
