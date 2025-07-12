import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/HIveCtrl/models/music_cache_model.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import '../custom_widgets/custom_button.dart';
import '../custom_widgets/custom_drop_menu.dart';
import '../field/audio_source.dart';
import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/audio_ctrl_mixin.dart';
import '../tools/general_style.dart';
import '../field/tag_suffix.dart';
import 'edit_metadata_dialog.dart';
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

const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

class _MusicMenuController extends GetxController {
  final menuController = MenuController();
  final Rxn<Offset> menuPosition = Rxn<Offset>();
  final Rxn<MusicCache> currentMetadata = Rxn<MusicCache>();
  final RxInt currentIndex = (-1).obs;

  void openMenu({
    required Offset overlayOffset,
    required MusicCache metadata,
    required int index,
  }) {
    menuPosition.value = overlayOffset;
    currentMetadata.value = metadata;
    currentIndex.value = index;
    menuController.open(position: Offset.zero);
  }
}

final _MusicMenuController _musicMenuCtrl = Get.put(_MusicMenuController());

List<Widget> _genMenuItems({
  required BuildContext context,
  required MenuController menuController,
  required MusicCache metadata,
  required String userKey,
  required int index,
  required String operateArea,
  required List<Widget> playList,
  bool renderMaybeDel = false,
}) {
  final List<Widget> maybeDel =
      renderMaybeDel
          ? [
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.8),
              height: 0.5,
              thickness: 0.5,
            ),
            CustomBtn(
              fn: () async {
                menuController.close();
                await _audioController.audioRemove(
                  userKey: userKey,
                  metadata: metadata,
                );
              },
              btnHeight: _menuHeight,
              btnWidth: _menuWidth,
              radius: _menuRadius,
              icon: PhosphorIconsLight.trash,
              label: "删除",
              mainAxisAlignment: MainAxisAlignment.start,
              backgroundColor: Colors.transparent,
            ),
          ]
          : [];

  return <Widget>[
        CustomBtn(
          fn: () {
            _audioSource.currentAudioSource.value = userKey;
            menuController.close();
            _audioController.audioPlay(metadata: metadata);
          },
          btnHeight: _menuHeight,
          btnWidth: _menuWidth,
          radius: _menuRadius,
          icon: PhosphorIconsLight.play,
          label: "播放",
          mainAxisAlignment: MainAxisAlignment.start,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),

        CustomBtn(
          fn: () {
            menuController.close();
            _audioController.insertNext(metadata: metadata);
          },
          btnHeight: _menuHeight,
          btnWidth: _menuWidth,
          radius: _menuRadius,
          icon: PhosphorIconsLight.arrowBendDownRight,
          label: "添加到下一首",
          mainAxisAlignment: MainAxisAlignment.start,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        EditMetadataDialog(
          menuController: menuController,
          metadata: metadata,
          index: index,
          operateArea: operateArea,
        ),

        SubmenuButton(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          menuStyle: MenuStyle(alignment: Alignment.topRight),
          menuChildren: playList,
          leadingIcon: Icon(
            PhosphorIconsLight.plus,
            size: getIconSize(size: 'md'),
          ),
          child: const Text('添加到歌单'),
        ),

        CustomBtn(
          fn: () {
            menuController.close();
            Process.run('explorer.exe', ['/select,', metadata.path]);
          },
          btnHeight: _menuHeight,
          btnWidth: _menuWidth,
          radius: _menuRadius,
          icon: PhosphorIconsLight.folderOpen,
          label: "打开本地资源",
          mainAxisAlignment: MainAxisAlignment.start,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ] +
      maybeDel;
}

List<Widget> Function(MusicCache metadata) _playListBuilder = (metadata) {
  return _audioController.allUserKey.map((v) {
    return MenuItemButton(
      onPressed: () {
        _audioController.addToAudioList(metadata: metadata, userKey: v);
      },
      child: Center(child: Text(v.split(TagSuffix.playList)[0])),
    );
  }).toList();
};

class AudioGenPages extends StatelessWidget {
  final String title;
  final String operateArea;
  final String audioSource;
  final AudioControllerGenClass controller;
  final Color? backgroundColor;
  const AudioGenPages({
    super.key,
    required this.title,
    required this.operateArea,
    required this.audioSource,
    required this.controller,
    this.backgroundColor,
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
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
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
              if (operateArea != OperateArea.allMusic)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: _coverBorderRadius,
                    child: Obx(() {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeIn,
                        switchOutCurve: Curves.easeOut,
                        child: Image.memory(
                          controller.headCover.value,
                          key: ValueKey(controller.headCover.value.hashCode),
                          cacheWidth: _coverBigRenderSize,
                          cacheHeight: _coverBigRenderSize,
                          height: _headCoverSize,
                          width: _headCoverSize,
                          fit: BoxFit.cover,
                        ),
                        transitionBuilder: (
                          Widget child,
                          Animation<double> anim,
                        ) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                      );
                    }),
                  ),
                ),

              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      FractionallySizedBox(
                        widthFactor: 1.0,
                        child: Text(
                          title,
                          style: generalTextStyle(
                            ctx: context,
                            size: 'title',
                            weight: FontWeight.w600,
                          ),
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
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
                              _audioSource.currentAudioSource.value =
                                  audioSource;

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
                            contentColor:
                                Theme.of(context).colorScheme.onPrimary,
                            overlayColor:
                                Theme.of(context).colorScheme.surfaceContainer,
                          ),

                          Obx(() {
                            final itemMap = {
                              0: [
                                _settingController.sortType[0],
                                PhosphorIconsRegular.textT,
                              ],
                              1: [
                                _settingController.sortType[1],
                                PhosphorIconsRegular.userFocus,
                              ],
                              2: [
                                _settingController.sortType[2],
                                PhosphorIconsRegular.vinylRecord,
                              ],
                              3: [
                                _settingController.sortType[3],
                                PhosphorIconsRegular.clockCountdown,
                              ],
                            };
                            if (operateArea == OperateArea.artistList) {
                              itemMap.remove(1);
                            }

                            if (operateArea == OperateArea.albumList) {
                              itemMap.remove(2);
                            }

                            if (!isMulSelect.value) {
                              return CustomDropdownMenu(
                                itemMap: itemMap,
                                fn: (entry) {
                                  _settingController.sortMap[operateArea] =
                                      entry.key;
                                  _settingController.putCache();
                                  controller.itemReSort(type: entry.key);
                                  _audioController.syncCurrentIndex();
                                },
                                label:
                                    _settingController
                                        .sortType[_settingController
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
                                                  v.split(
                                                    TagSuffix.playList,
                                                  )[0],
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              backgroundColor:
                                                  Colors.transparent,
                                            );
                                          }).toList(),
                                      controller: playListMenuController,
                                      child: CustomBtn(
                                        fn: () {
                                          if (_audioController
                                              .allUserKey
                                              .isEmpty) {
                                            showSnackBar(
                                              title: "WARNING",
                                              msg: "未创建歌单！",
                                              duration: Duration(
                                                milliseconds: 1500,
                                              ),
                                            );
                                            return;
                                          }
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
                                              ? PhosphorIconsLight
                                                  .selectionSlash
                                              : PhosphorIconsLight.selectionAll,
                                      btnHeight: btnHeight,
                                      btnWidth: btnWidth,
                                      tooltip:
                                          selectedList.isNotEmpty
                                              ? '清空选择'
                                              : '全选',
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
              ),
            ],
          ),

          Expanded(
            child: Obx(() {
              final viewMode = _settingController.viewModeMap[operateArea]!;
              final ScrollController scrollControllerList = ScrollController();
              final ScrollController scrollControllerGrid = ScrollController();

              return RawMenuAnchor(
                controller: _musicMenuCtrl.menuController,
                consumeOutsideTaps: true,
                overlayBuilder: (
                  BuildContext context,
                  RawMenuOverlayInfo info,
                ) {
                  final currentMetadata = _musicMenuCtrl.currentMetadata.value;
                  final position = _musicMenuCtrl.menuPosition.value;
                  if (currentMetadata == null || position == null) {
                    return SizedBox(
                      child: Text(
                        "发生了某些错误！",
                        style: generalTextStyle(ctx: context, size: 'md'),
                      ),
                    );
                  }

                  double left = position.dx + 16;
                  double top = position.dy;
                  final itemCount = operateArea == OperateArea.playList ? 6 : 5;
                  if (top + _menuHeight * (itemCount + 1.5) > Get.height) {
                    top = top - _menuHeight * itemCount;
                  }
                  if (left + _menuWidth * 2 > Get.width) {
                    left = left - _menuWidth - 16;
                  }

                  return Positioned(
                    top: top,
                    left: left,
                    child: TapRegion(
                      onTapOutside: (PointerDownEvent event) {
                        Future.delayed(
                          Duration(milliseconds: 100),
                          _musicMenuCtrl.menuController.close,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: _borderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.zero,
                        width: _menuWidth,
                        child: Column(
                          children: _genMenuItems(
                            context: context,
                            menuController: _musicMenuCtrl.menuController,
                            metadata: currentMetadata,
                            userKey: audioSource,
                            index: _musicMenuCtrl.currentIndex.value,
                            renderMaybeDel:
                                operateArea == OperateArea.playList
                                    ? true
                                    : false,
                            operateArea: operateArea,
                            playList: _playListBuilder(currentMetadata),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Stack(
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

                          return GestureDetector(
                            onSecondaryTapDown: (e) {
                              RenderBox overlayBox =
                                  Overlay.of(context).context.findRenderObject()
                                      as RenderBox;
                              Offset overlayOffset = overlayBox.globalToLocal(
                                e.globalPosition,
                              );
                              _musicMenuCtrl.openMenu(
                                overlayOffset: overlayOffset,
                                metadata: metadata,
                                index: index,
                              );
                            },
                            child: MusicTile(
                              key: ValueKey(metadata.path), //暂定
                              metadata: metadata,
                              titleStyle: titleStyle,
                              highLightTitleStyle: highLightTitleStyle,
                              subStyle: subStyle,
                              highLightSubStyle: highLightSubStyle,
                              audioSource: audioSource,
                              operateArea: operateArea,
                              isMulSelect: isMulSelect,
                              selectedList: selectedList,
                            ),
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

                          return GestureDetector(
                            onSecondaryTapDown: (e) {
                              RenderBox overlayBox =
                                  Overlay.of(context).context.findRenderObject()
                                      as RenderBox;
                              Offset overlayOffset = overlayBox.globalToLocal(
                                e.globalPosition,
                              );
                              _musicMenuCtrl.openMenu(
                                overlayOffset: overlayOffset,
                                metadata: metadata,
                                index: index,
                              );
                            },
                            child: MusicTile(
                              key: ValueKey(metadata.path), //暂定
                              metadata: metadata,
                              titleStyle: titleStyle,
                              highLightTitleStyle: highLightTitleStyle,
                              subStyle: subStyle,
                              highLightSubStyle: highLightSubStyle,
                              audioSource: audioSource,
                              operateArea: operateArea,
                              isMulSelect: isMulSelect,
                              selectedList: selectedList,
                            ),
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
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
