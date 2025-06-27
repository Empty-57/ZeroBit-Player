import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import '../components/floating_button.dart';
import '../components/music_list_tool.dart';
import '../custom_widgets/custom_button.dart';
import '../custom_widgets/custom_dropMenu.dart';
import '../field/operate_area.dart';
import '../getxController/Audio_ctrl.dart';
import '../getxController/play_list_ctrl.dart';
import '../getxController/setting_ctrl.dart';

import '../getxController/user_playlist_ctrl.dart';
import '../tools/general_style.dart';

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();

const double _itemHeight = 64.0;

const double _headCoverSize = 240;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const int _coverBigRenderSize = 800;

class PlayList extends StatelessWidget {
  final Object? args;

  const PlayList({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final userArgs = (args as Map)['userPlayListCache'];
    late final PlayListController playListController;
    final isInit = false.obs;
    Future.microtask(() {
      Get.delete<PlayListController>(tag: userArgs.userKey);
      playListController = Get.put(
        PlayListController(userArgs: userArgs),
        tag: userArgs.userKey,
      );
      isInit.value = true;
    });

    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final highLightTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final highLightSubStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      opacity: 0.8,
      color: Theme.of(context).colorScheme.primary,
    );

    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
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
              Container(
                margin: EdgeInsets.only(left: 8),
                child: Obx(
                  () =>
                      isInit.value
                          ? FutureBuilder<Uint8List?>(
                            future: playListController.getHeadCover(),
                            builder: (context, snapshot) {
                              debugPrint(PlayListController.items[0].path);
                              if (snapshot.hasData) {
                                return ClipRRect(
                                  borderRadius: _coverBorderRadius,
                                  child: FadeInImage(
                                    placeholder: MemoryImage(kTransparentImage),
                                    image: ResizeImage(
                                      MemoryImage(snapshot.data!),
                                      width: _coverBigRenderSize,
                                      height: _coverBigRenderSize,
                                    ),
                                    height: _headCoverSize,
                                    width: _headCoverSize,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              }
                              return SizedBox(
                                height: _headCoverSize,
                                width: _headCoverSize,
                              );
                            },
                          )
                          : SizedBox(
                            height: _headCoverSize,
                            width: _headCoverSize,
                          ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      userArgs.userKey.split(playListTagSuffix)[0],
                      style: generalTextStyle(
                        ctx: context,
                        size: 28.0,
                        weight: FontWeight.w400,
                      ),
                    ),
                    Obx(
                      () => Text(
                        '共${PlayListController.items.length}首音乐',
                        style: generalTextStyle(ctx: context, size: 'md'),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(flex: 1, child: Container()),

              Obx(
                () => CustomDropdownMenu(
                  itemMap: {
                    0: [
                      _settingController.sortType[0],
                      PhosphorIconsRegular.textT,
                    ],
                    1: [
                      _settingController.sortType[1],
                      PhosphorIconsRegular.vinylRecord,
                    ],
                    2: [
                      _settingController.sortType[2],
                      PhosphorIconsRegular.userFocus,
                    ],
                    3: [
                      _settingController.sortType[3],
                      PhosphorIconsRegular.clockCountdown,
                    ],
                  },
                  fn: (entry) {
                    _settingController.sortMap[OperateArea.playList] =
                        entry.key;
                    _settingController.putCache();
                    playListController.itemReSort(type: entry.key);
                    _audioController.syncCurrentIndex();
                  },
                  label:
                      _settingController.sortType[_settingController
                              .sortMap[OperateArea.playList]
                          as int] ??
                      "未指定",
                  radius: 4,
                  btnWidth: 140,
                  btnHeight: 48,
                  itemWidth: 140,
                  itemHeight: 48,
                  btnIcon: PhosphorIconsLight.funnelSimple,
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 6,
                ),
              ),

              Obx(
                () => CustomBtn(
                  fn: () {
                    _settingController.isReverse.value =
                        !_settingController.isReverse.value;
                    _settingController.putCache();
                    playListController.itemReverse();
                    _audioController.syncCurrentIndex();
                  },
                  icon:
                      _settingController.isReverse.value
                          ? PhosphorIconsLight.arrowDown
                          : PhosphorIconsLight.arrowUp,
                  radius: 4,
                  btnHeight: 48,
                  btnWidth: 48,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  tooltip: _settingController.isReverse.value ? '降序' : '升序',
                ),
              ),

              Obx(
                () => CustomBtn(
                  fn: () {
                    _settingController.viewModeMap[OperateArea.playList] =
                        !_settingController.viewModeMap[OperateArea.playList];
                    _settingController.putCache();
                  },
                  icon:
                      _settingController.viewModeMap[OperateArea.playList]
                          ? PhosphorIconsLight.listDashes
                          : PhosphorIconsLight.gridFour,
                  radius: 4,
                  btnHeight: 48,
                  btnWidth: 48,
                  spacing: 4,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  tooltip:
                      _settingController.viewModeMap[OperateArea.playList]
                          ? "列表视图"
                          : "表格视图",
                ),
              ),
            ],
          ),

          Expanded(
            child: Obx(() {
              final viewMode =
                  _settingController.viewModeMap[OperateArea.playList]!;
              final ScrollController scrollControllerList = ScrollController();
              final ScrollController scrollControllerGrid = ScrollController();

              return Stack(
                children: [
                  Offstage(
                    offstage: !viewMode,
                    child: ListView.builder(
                      controller: scrollControllerList,
                      itemCount: PlayListController.items.length,
                      itemExtent: _itemHeight,
                      cacheExtent: _itemHeight * 1,
                      itemBuilder: (context, index) {
                        final metadata = PlayListController.items[index];

                        return MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                          audioSource: userArgs.userKey,
                          operateArea: OperateArea.playList,
                          index: index,
                        );
                      },
                    ),
                  ),
                  Offstage(
                    offstage: viewMode,
                    child: GridView.builder(
                      controller: scrollControllerGrid,
                      itemCount: PlayListController.items.length,
                      cacheExtent: _itemHeight * 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.width < 1100 ? 3 : 4,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: 1.0,
                        mainAxisExtent: _itemHeight,
                      ),
                      itemBuilder: (context, index) {
                        final metadata = PlayListController.items[index];

                        return MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                          audioSource: userArgs.userKey,
                          index: index,
                        );
                      },
                    ),
                  ),
                  FloatingButton(
                    scrollControllerList: scrollControllerList,
                    scrollControllerGrid: scrollControllerGrid,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
