import 'package:flutter/material.dart';
import 'package:zerobit_player/core/constants/app_routes.dart';
import 'package:zerobit_player/core/widgets/sorted_list_view.dart';
import 'package:zerobit_player/features/library/controller/music_cache_ctrl.dart';

class ArtistPreviewPage extends StatelessWidget {
  const ArtistPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MusicCacheController.instance;
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
