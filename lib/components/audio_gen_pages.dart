import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/field/operate_area.dart';

import '../custom_widgets/custom_button.dart';
import '../custom_widgets/custom_dropMenu.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/general_style.dart';
import 'floating_button.dart';
import 'music_list_tool.dart';

const double _itemHeight = 64.0;

const double _headCoverSize = 240;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const int _coverBigRenderSize = 800;

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();


class AudioGenPages extends StatelessWidget{
  final String title;
  final String operateArea;
  final String audioSource;
  final AudioControllerGenClass controller;
  const AudioGenPages({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
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
            children: <Widget>[
              if (operateArea==OperateArea.playList) Container(
                margin: EdgeInsets.only(left: 8),
                child: ClipRRect(
                    borderRadius: _coverBorderRadius,
                    child: Obx((){
                      return FadeInImage(
                      placeholder: MemoryImage(kTransparentImage),
                      image: ResizeImage(
                        MemoryImage(controller.headCover.value),
                        width: _coverBigRenderSize,
                        height: _coverBigRenderSize,
                      ),
                      height: _headCoverSize,
                      width: _headCoverSize,
                      fit: BoxFit.cover,
                    );
                    }
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
                      title,
                      style: generalTextStyle(
                        ctx: context,
                        size: 28.0,
                        weight: FontWeight.w400,
                      ),
                    ),
                    Obx(
                      () => Text(
                        '共${controller.items.length}首音乐',
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
                    _settingController.sortMap[operateArea] =
                        entry.key;
                    _settingController.putCache();
                    controller.itemReSort(type: entry.key);
                    _audioController.syncCurrentIndex();
                  },
                  label:
                      _settingController.sortType[_settingController
                              .sortMap[operateArea]
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
                    controller.itemReverse();
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
                    _settingController.viewModeMap[operateArea] =
                        !_settingController.viewModeMap[operateArea];
                    _settingController.putCache();
                  },
                  icon:
                      _settingController.viewModeMap[operateArea]
                          ? PhosphorIconsLight.listDashes
                          : PhosphorIconsLight.gridFour,
                  radius: 4,
                  btnHeight: 48,
                  btnWidth: 48,
                  spacing: 4,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  tooltip:
                      _settingController.viewModeMap[operateArea]
                          ? "列表视图"
                          : "表格视图",
                ),
              ),
            ],
          ),

          Expanded(
            child: Obx(() {
              final viewMode =
                  _settingController.viewModeMap[operateArea]!;
              final ScrollController scrollControllerList = ScrollController();
              final ScrollController scrollControllerGrid = ScrollController();

              return Stack(
                children: [
                  Offstage(
                    offstage: !viewMode,
                    child: ListView.builder(
                      controller: scrollControllerList,
                      itemCount: controller.items.length,
                      itemExtent: _itemHeight,
                      cacheExtent: _itemHeight * 1,
                      padding: EdgeInsets.only(bottom: _itemHeight*2),
                      itemBuilder: (context, index) {
                        final metadata = controller.items[index];

                        return MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                          audioSource: audioSource,
                          operateArea: operateArea,
                          index: index,
                        );
                      },
                    ),
                  ),
                  Offstage(
                    offstage: viewMode,
                    child: GridView.builder(
                      controller: scrollControllerGrid,
                      itemCount: controller.items.length,
                      cacheExtent: _itemHeight * 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.width < 1100 ? 3 : 4,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: 1.0,
                        mainAxisExtent: _itemHeight,
                      ),
                      padding: EdgeInsets.only(bottom: _itemHeight*2),
                      itemBuilder: (context, index) {
                        final metadata = controller.items[index];

                        return MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                          audioSource: audioSource,
                          operateArea: operateArea,
                          index: index,
                        );
                      },
                    ),
                  ),
                  FloatingButton(
                    scrollControllerList: scrollControllerList,
                    scrollControllerGrid: scrollControllerGrid,
                    operateArea: operateArea,
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