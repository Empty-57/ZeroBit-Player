import 'package:flutter/material.dart';

import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import 'package:get/get.dart';

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class ArtistViewPage extends StatelessWidget {
  const ArtistViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 8,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '歌单',
                    style: generalTextStyle(
                      ctx: context,
                      size: 'title',
                      weight: FontWeight.w600,
                    ),
                  ),
                  Obx(
                    () => Text(
                      '共${_musicCacheController.artistItemsDict.length}位艺术家',
                      style: generalTextStyle(ctx: context, size: 'md'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(flex: 1, child: Container()),
        ],
      ),
    );
  }
}
