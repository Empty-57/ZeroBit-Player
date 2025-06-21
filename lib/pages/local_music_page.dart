import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/components/floating_button.dart';
import 'package:zerobit_player/getxController/Audio_ctrl.dart';
import 'package:zerobit_player/getxController/music_cache_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/field/operate_area.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zerobit_player/custom_widgets/custom_widget.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import 'dart:typed_data';

import '../HIveCtrl/models/music_cahce_model.dart';
import '../tools/format_time.dart';
import '../tools/general_style.dart';

final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();
final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();

final OperateArea _operateArea=Get.find<OperateArea>();

const double _itemHeight = 64.0;

class LocalMusic extends StatelessWidget {
  const LocalMusic({super.key});

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
      padding: EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    '音乐',
                    style: generalTextStyle(
                      ctx: context,
                      size: 28.0,
                      weight: FontWeight.w400,
                    ),
                  ),
                  Obx(
                    () => Text(
                      '共${_musicCacheController.items.length}首',
                      style: generalTextStyle(ctx: context, size: 'md'),
                    ),
                  ),
                ],
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
                    _settingController.sortMap[OperateArea.allMusic] = entry.key;
                    _settingController.putCache();
                    _musicCacheController.itemReSort(type: entry.key);
                    _audioController.syncCurrentIndex();
                  },
                  label:
                      _settingController.sortType[_settingController
                              .sortMap[OperateArea.allMusic]
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
                    _musicCacheController.itemReverse();
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
                    _settingController.viewModeMap[OperateArea.allMusic] =
                        !_settingController.viewModeMap[OperateArea.allMusic];
                    _settingController.putCache();
                  },
                  icon:
                      _settingController.viewModeMap[OperateArea.allMusic]
                          ? PhosphorIconsLight.listDashes
                          : PhosphorIconsLight.gridFour,
                  radius: 4,
                  btnHeight: 48,
                  btnWidth: 48,
                  spacing: 4,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  tooltip:
                      _settingController.viewModeMap[OperateArea.allMusic]
                          ? "列表视图"
                          : "表格视图",
                ),
              ),
            ],
          ),

          Expanded(
            child: Obx(() {
              final viewMode =
                  _settingController.viewModeMap[OperateArea.allMusic]!;
              final ScrollController scrollControllerList=ScrollController();
              final ScrollController scrollControllerGrid=ScrollController();

              return Stack(
                children: [
                  Offstage(
                    offstage: !viewMode,
                    child: ListView.builder(
                      controller: scrollControllerList,
                      itemCount: _musicCacheController.items.length,
                      itemExtent: _itemHeight,
                      cacheExtent: _itemHeight * 1,
                      itemBuilder: (context, index) {
                        final metadata = _musicCacheController.items[index];

                        return _MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                        );
                      },
                    ),
                  ),
                  Offstage(
                    offstage: viewMode,
                    child: GridView.builder(
                      controller: scrollControllerGrid,
                      itemCount: _musicCacheController.items.length,
                      cacheExtent: _itemHeight * 1,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            context.width < 1100 ? 3 : 4,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 8.0,
                        childAspectRatio: 1.0,
                        mainAxisExtent: _itemHeight,
                      ),
                      itemBuilder: (context, index) {
                        final metadata = _musicCacheController.items[index];

                        return _MusicTile(
                          metadata: metadata,
                          titleStyle: titleStyle,
                          highLightTitleStyle: highLightTitleStyle,
                          subStyle: subStyle,
                          highLightSubStyle: highLightSubStyle,
                          menuController: MenuController(),
                        );
                      },
                    ),
                  ),
                  FloatingButton(scrollControllerList: scrollControllerList,scrollControllerGrid: scrollControllerGrid,),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;


List<Widget> _genMenuItems({required BuildContext context, required MenuController menuController,required MusicCache metadata,bool renderMaybeDel=false}){
  final List<Widget> maybeDel=renderMaybeDel? [

    Divider(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      height: 0.5,
      thickness: 0.5,
    ),
          CustomBtn(
            fn: () async{
              menuController.close();
              await _audioController.audioRemove(filed: OperateArea.allMusic,metadata: metadata);
            },
            btnHeight: _menuHeight,
            btnWidth: _menuWidth,
            radius: _menuRadius,
            icon: PhosphorIconsLight.trash,
            label: "删除",
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
          ),]:[];


  return <Widget>[
          CustomBtn(
            fn: () {
              _operateArea.currentFiled.value=OperateArea.allMusic;
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
          ),

          CustomBtn(
            fn: () {
              menuController.close();
              _audioController.insertNext(metadata: metadata);
            },
            btnHeight: _menuHeight,
            btnWidth: _menuWidth,
            radius: _menuRadius,
            icon: PhosphorIconsLight.arrowBendDownLeft,
            label: "添加到下一首",
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
          ),
          CustomBtn(
            fn: () {
              menuController.close();
            },
            btnHeight: _menuHeight,
            btnWidth: _menuWidth,
            radius: _menuRadius,
            icon: PhosphorIconsLight.pencilSimpleLine,
            label: "修改元数据",
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: Colors.transparent,
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
          ),
        ]+maybeDel;
}

class _MusicTile extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final MenuController menuController;

  const _MusicTile({
    required this.metadata,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.menuController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (e) {
        menuController.open(position: e.localPosition);
      },
      child: MenuAnchor(
        controller: menuController,
        consumeOutsideTap: true,
        menuChildren:_genMenuItems(context: context,menuController: menuController,metadata: metadata),

        child: TextButton(
          onPressed: () async {
             _operateArea.currentFiled.value=OperateArea.allMusic;
            menuController.close();
            await _audioController.audioPlay(metadata: metadata);
          }.futureDebounce(ms: 300),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: _borderRadius),
          ),
          child: GetBuilder<AudioController>(
            id: metadata.path,
            builder: (controller) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: _itemSpacing,
                children: [
                  _AsyncCover(path: metadata.path, music: metadata),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metadata.title,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              _audioController.currentPath.value !=
                                      metadata.path
                                  ? titleStyle
                                  : highLightTitleStyle,
                        ),
                        Text(
                          metadata.artist,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              _audioController.currentPath.value !=
                                      metadata.path
                                  ? subStyle
                                  : highLightSubStyle,
                        ),
                      ],
                    ),
                  ),
                  if (_settingController.viewModeMap[OperateArea.allMusic])
                    Expanded(
                      flex: 2,
                      child: Text(
                        metadata.album,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style:
                            _audioController.currentPath.value != metadata.path
                                ? subStyle
                                : highLightSubStyle,
                      ),
                    ),
                  Text(
                    formatTime(totalSeconds: metadata.duration),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style:
                        _audioController.currentPath.value != metadata.path
                            ? subStyle
                            : highLightSubStyle,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
final double _dpr = Get.mediaQuery.devicePixelRatio;
final int _coverRenderSize = (_coverSize * _dpr).ceil();

class _AsyncCover extends StatelessWidget {
  final String path;
  final MusicCache music;
  const _AsyncCover({required this.path, required this.music});

  Widget _renderCover() {
    return ClipRRect(
      borderRadius: _coverBorderRadius,
      child: FadeInImage(
        placeholder: MemoryImage(kTransparentImage),
        image: ResizeImage(
          MemoryImage(music.src!),
          width: _coverRenderSize,
          height: _coverRenderSize,
        ),
        height: _coverSize,
        width: _coverSize,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<Uint8List?> _loadCover() async {
    final coverData = await getCover(path: path, sizeFlag: 0);
    if (coverData == null) {
      final title = music.title;
      final artist = music.artist.isNotEmpty ? ' - ${music.artist}' : '';
      final coverData_ = await saveCoverByText(
        text: title + artist,
        songPath: path,
      );
      if (coverData_ != null && coverData_.isNotEmpty) {
        return Uint8List.fromList(coverData_);
      }
    }
    return coverData;
  }

  @override
  Widget build(BuildContext context) {
    return music.src == null
        ? FutureBuilder<Uint8List?>(
          future: _loadCover(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              music.src = snapshot.data!;

              return _renderCover();
            }
            return SizedBox(height: _coverSize, width: _coverSize);
          },
        )
        : _renderCover();
  }
}
