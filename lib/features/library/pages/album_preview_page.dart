import 'package:flutter/material.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/widgets/sorted_list_view.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';

class AlbumPreviewPage extends StatelessWidget {
  const AlbumPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MusicCacheController.instance;
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
