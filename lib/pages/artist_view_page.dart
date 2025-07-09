import 'package:flutter/material.dart';
import 'package:transparent_image/transparent_image.dart';

import '../getxController/music_cache_ctrl.dart';
import '../tools/general_style.dart';
import 'package:get/get.dart';

const double _itemHeight = 64.0;
const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverSmallRenderSize = 150;
const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

final MusicCacheController _musicCacheController =
    Get.find<MusicCacheController>();

class ArtistViewPage extends StatelessWidget {
  const ArtistViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final letterTitleStyle = generalTextStyle(ctx: context, size: 'xl');
    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);

    final foregroundColorHover = WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.hovered)) {
        return Theme.of(context).colorScheme.primary;
      }

      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    });

    final scrollController=ScrollController();

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
                    '艺术家',
                    style: generalTextStyle(
                      ctx: context,
                      size: 'title',
                      weight: FontWeight.w600,
                    ),
                  ),
                  Obx(
                    () => Text(
                      '共${_musicCacheController.artistItemsDict.value.length}位艺术家',
                      style: generalTextStyle(ctx: context, size: 'md'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Obx(() {
                    final dict = _musicCacheController.artistItemsDict.value;
                    final keys =
                        _musicCacheController.artistItemsDict.value.keys
                            .toList();

                    return ListView.builder(
                      itemCount: dict.length,
                      // itemExtent: _itemHeight,
                      cacheExtent: _itemHeight * 1,
                      controller: scrollController,
                      itemExtentBuilder: (index, _) {
                        if (index < 1 || keys[index][0] != keys[index - 1][0]) {
                          return _itemHeight * 2;
                        }
                        return _itemHeight;
                      },
                      padding: EdgeInsets.only(bottom: _itemHeight * 2),
                      itemBuilder: (context, index) {
                        final item = dict[keys[index]]!;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index < 1 ||
                                keys[index][0] != keys[index - 1][0])
                              Container(
                                width: _itemHeight,
                                height: _itemHeight,
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: _itemSpacing),
                                child: Text(
                                  keys[index][0],
                                  style: letterTitleStyle,
                                ),
                              ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: _borderRadius,
                                ),
                                fixedSize: Size.fromHeight(_itemHeight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: _itemSpacing,
                                children: [
                                  ClipRRect(
                                    borderRadius: _coverBorderRadius,
                                    child: Image.memory(
                                      _musicCacheController.items
                                              .firstWhere(
                                                (v) => v.path == item[0],
                                              )
                                              .src ??
                                          kTransparentImage,
                                      cacheWidth: _coverSmallRenderSize,
                                      cacheHeight: _coverSmallRenderSize,
                                      height: _coverSize,
                                      width: _coverSize,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Text(
                                    keys[index].substring(1),
                                    style: titleStyle,
                                  ),
                                  Expanded(flex: 1, child: Container()),
                                  Text("共${item.length}首作品", style: subStyle),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }),
                ),
                SizedBox(
                  width: 24,
                  child: Obx(() {
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: ListView(
                        padding: EdgeInsets.only(bottom: _itemHeight * 2),
                        children:
                            _musicCacheController.artistHasLetter.map((v) {
                              return TextButton(
                                onPressed: () {
                                  final index=_musicCacheController.artistItemsDict.value.keys.toList().indexWhere((l)=>l[0]==v);
                                  final letterIndex=_musicCacheController.artistHasLetter.indexWhere((l)=>l==v);
                                  final double offset=((letterIndex+index)*_itemHeight).clamp(0, scrollController.position.maxScrollExtent);
                                  scrollController.jumpTo(offset);
                                },
                                style: ButtonStyle(
                                  foregroundColor: foregroundColorHover,
                                  padding: WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                                  borderRadius: _borderRadius,
                                )),
                                ),
                                child: Center(
                                  child: Text(
                                    v,
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
