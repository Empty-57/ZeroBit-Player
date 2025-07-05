import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cahce_model.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import '../custom_widgets/custom_button.dart';
import '../custom_widgets/custom_dropMenu.dart';
import '../field/audio_source.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/general_style.dart';
import '../tools/tag_suffix.dart';
import 'floating_button.dart';
import 'get_snack_bar.dart';
import 'music_list_tool.dart';

const double _itemHeight = 64.0;

const double _headCoverSize = 240;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

const int _coverBigRenderSize = 800;

const double btnHeight = 42;
const double btnWidth = 42;
const double resViewThresholds = 1100;

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();
final AudioSource _audioSource = Get.find<AudioSource>();

class AudioGenPages extends StatelessWidget {
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
    final isMulSelect = false.obs;

    final selectedList = <MusicCache>[].obs;

    final playListMenuController = MenuController();

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
            children: <Widget>[
              if (operateArea == OperateArea.playList)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: _coverBorderRadius,
                    child: Obx(() {
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
                    }),
                  ),
                ),

              Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      title,
                      style: generalTextStyle(
                        ctx: context,
                        size: 'title',
                        weight: FontWeight.w600,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Obx(
                      () => Text(
                        '共${controller.items.length}首音乐',
                        style: generalTextStyle(ctx: context, size: 'md'),
                      ),
                    ),

                    Row(
                      spacing: 8,
                      children: [
                        CustomBtn(
                          fn: () async {
                            _audioSource.currentAudioSource.value = audioSource;

                            if (controller.items.isEmpty) {
                              showSnackBar(
                                title: "WARNING",
                                msg: "此歌单暂无音乐！",
                                duration: Duration(milliseconds: 1500),
                              );
                              return;
                            }

                            if (_settingController.playMode.value == 2) {
                              await _audioController.audioPlay(
                                metadata:
                                    controller.items[Random().nextInt(
                                      controller.items.length,
                                    )],
                              );
                            } else {
                              await _audioController.audioPlay(
                                metadata: controller.items[0],
                              );
                            }
                          }.throttle(ms: 500),
                          icon: PhosphorIconsLight.play,
                          btnHeight: btnHeight,
                          btnWidth: 96,
                          mainAxisAlignment: MainAxisAlignment.center,
                          label: "播放",
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          contentColor: Theme.of(context).colorScheme.onPrimary,
                          overlayColor:
                              Theme.of(context).colorScheme.surfaceContainer,
                        ),

                        Obx(() {
                          if (!isMulSelect.value) {
                            return CustomDropdownMenu(
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
                              btnWidth: 128,
                              btnHeight: btnHeight,
                              itemWidth: 128,
                              itemHeight: btnHeight,
                              btnIcon: PhosphorIconsLight.funnelSimple,
                              mainAxisAlignment: MainAxisAlignment.start,
                              spacing: 6,
                            );
                          }

                          if (isMulSelect.value &&
                              operateArea == OperateArea.playList) {
                            return CustomBtn(
                              fn: () {
                                _audioController.audioRemoveAll(
                                  userKey: audioSource,
                                  removeList: [...selectedList],
                                );
                              },
                              icon: PhosphorIconsLight.trash,
                              btnHeight: btnHeight,
                              btnWidth: btnWidth,
                              contentColor: Colors.red,
                              tooltip: "删除所选项",
                            );
                          }

                          return const SizedBox.shrink();
                        }),

                        Obx(
                          () =>
                              isMulSelect.value
                                  ? MenuAnchor(
                                    menuChildren:
                                        _audioController.allUserKey.map((v) {
                                          return CustomBtn(
                                            fn: () {
                                              playListMenuController.close();
                                              _audioController
                                                  .addAllToAudioList(
                                                    selectedList: [
                                                      ...selectedList,
                                                    ],
                                                    userKey: v,
                                                  );
                                            },
                                            btnWidth: 160,
                                            btnHeight: btnHeight,
                                            label:
                                                v.split(playListTagSuffix)[0],
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            backgroundColor: Colors.transparent,
                                          );
                                        }).toList(),
                                    controller: playListMenuController,
                                    child: CustomBtn(
                                      fn: () {
                                        playListMenuController.open();
                                      },
                                      icon: PhosphorIconsLight.plus,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      btnHeight: btnHeight,
                                      btnWidth: 160,
                                      label: "添加到歌单",
                                    ),
                                  )
                                  : CustomBtn(
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
                                    btnHeight: btnHeight,
                                    btnWidth: btnWidth,
                                    tooltip:
                                        _settingController.isReverse.value
                                            ? '降序'
                                            : '升序',
                                  ),
                        ),

                        Obx(
                          () =>
                              isMulSelect.value
                                  ? CustomBtn(
                                    fn: () {
                                      if (selectedList.isNotEmpty) {
                                        selectedList.clear();
                                      } else {
                                        selectedList.value = [
                                          ...controller.items,
                                        ];
                                      }
                                    },
                                    icon:
                                        selectedList.isNotEmpty
                                            ? PhosphorIconsLight.selectionSlash
                                            : PhosphorIconsLight.selectionAll,
                                    btnHeight: btnHeight,
                                    btnWidth: btnWidth,
                                    tooltip:
                                        selectedList.isNotEmpty ? '清空选择' : '全选',
                                  )
                                  : CustomBtn(
                                    fn: () {
                                      _settingController
                                              .viewModeMap[operateArea] =
                                          !_settingController
                                              .viewModeMap[operateArea];
                                      _settingController.putCache();
                                    },
                                    icon:
                                        _settingController
                                                .viewModeMap[operateArea]
                                            ? PhosphorIconsLight.listDashes
                                            : PhosphorIconsLight.gridFour,
                                    btnHeight: btnHeight,
                                    btnWidth: btnWidth,
                                    spacing: 4,
                                    tooltip:
                                        _settingController
                                                .viewModeMap[operateArea]
                                            ? "列表视图"
                                            : "表格视图",
                                  ),
                        ),

                        Obx(
                          () => CustomBtn(
                            fn: () {
                              selectedList.clear();
                              isMulSelect.value = !isMulSelect.value;
                            },
                            icon:
                                isMulSelect.value
                                    ? PhosphorIconsLight.xSquare
                                    : PhosphorIconsLight.selection,
                            btnHeight: btnHeight,
                            btnWidth: btnWidth,
                            tooltip: isMulSelect.value ? '退出多选' : '多选模式',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Expanded(
            child: Obx(() {
              final viewMode = _settingController.viewModeMap[operateArea]!;
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
                      padding: EdgeInsets.only(bottom: _itemHeight * 2),
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
                          isMulSelect: isMulSelect,
                          selectedList: selectedList,
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
                        crossAxisCount:
                            context.width < resViewThresholds ? 3 : 4,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: 1.0,
                        mainAxisExtent: _itemHeight,
                      ),
                      padding: EdgeInsets.only(bottom: _itemHeight * 2),
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
                          isMulSelect: isMulSelect,
                          selectedList: selectedList,
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
