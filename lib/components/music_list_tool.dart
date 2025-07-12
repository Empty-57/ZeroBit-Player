import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/getxController/audio_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zerobit_player/custom_widgets/custom_widget.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'package:zerobit_player/tools/general_style.dart';

import 'dart:typed_data';

import '../HIveCtrl/models/music_cache_model.dart';
import '../components/edit_metadata_dialog.dart';
import '../field/audio_source.dart';
import '../tools/format_time.dart';
import '../field/tag_suffix.dart';

const double _itemSpacing = 16.0;
const _borderRadius = BorderRadius.all(Radius.circular(4));

const double _menuWidth = 180;
const double _menuHeight = 48;
const double _menuRadius = 0;

final SettingController _settingController = Get.find<SettingController>();
final AudioController _audioController = Get.find<AudioController>();

final AudioSource _audioSource = Get.find<AudioSource>();

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
        EditMetadataDialog(menuController: menuController, metadata: metadata,index:index,operateArea:operateArea),

        SubmenuButton(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          menuStyle: MenuStyle(
            alignment: Alignment.topRight,
          ),
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

class MusicTile extends StatelessWidget {
  final MusicCache metadata;
  final TextStyle titleStyle;
  final TextStyle highLightTitleStyle;
  final TextStyle subStyle;
  final TextStyle highLightSubStyle;
  final MenuController menuController;
  final String audioSource;
  final String operateArea;
  final int index;
  final RxBool isMulSelect;
  final RxList<MusicCache> selectedList;

  const MusicTile({
    super.key,
    required this.metadata,
    required this.titleStyle,
    required this.highLightTitleStyle,
    required this.subStyle,
    required this.highLightSubStyle,
    required this.menuController,
    required this.audioSource,
    required this.operateArea,
    required this.index,
    required this.isMulSelect,
    required this.selectedList,
  });

  @override
  Widget build(BuildContext context) {

    final List<Widget> playList =
      _audioController.allUserKey.map((v) {
        return MenuItemButton(
          onPressed: () {
            _audioController.addToAudioList(metadata: metadata, userKey: v);
          },
          child: Center(
              child: Text(
                  v.split(TagSuffix.playList)[0]
              )
          ),
        );
      }).toList();

    return GestureDetector(
      onSecondaryTapUp: (e) {
        if(menuController.isOpen){
          menuController.close();
        }else{
          menuController.open(position: e.localPosition);
        }
      },
      child: RawMenuAnchor(
        controller: menuController,
        consumeOutsideTaps:true,
        overlayBuilder: (BuildContext context, RawMenuOverlayInfo info) {
          double top=info.position!=null?info.position!.dy+info.anchorRect.top:info.anchorRect.bottom+4;
          double left=info.position!=null?info.position!.dx+32:info.anchorRect.left;
          final itemCount=audioSource == AudioSource.allMusic ? 5: 6;
          if(top+_menuHeight*(itemCount+1.5)>Get.height){
            top=top-_menuHeight*itemCount;
          }
          if(left+_menuWidth*2>Get.width){
            left=left-_menuWidth-32;
          }

          return Positioned(
            top: top,
          left: left,
              child: TapRegion(
            onTapOutside: (PointerDownEvent event) {
              Future.delayed(Duration(milliseconds: 100),menuController.close);
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
          menuController: menuController,
          metadata: metadata,
          userKey: audioSource,
          index: index,
          renderMaybeDel: audioSource == AudioSource.allMusic ? false : true,
          operateArea: operateArea,
          playList: playList
        ),
          ),
                )
          ));
        },
        child: Obx((){

          final subTextStyle=_audioController.currentPath.value != metadata.path
                            ? subStyle
                            : highLightSubStyle;

          final textStyle=_audioController.currentPath.value !=
                                      metadata.path
                                  ? titleStyle
                                  : highLightTitleStyle;

          return TextButton(
          onPressed: () async {

            if(isMulSelect.value){
              if(selectedList.any((v)=>v.path==metadata.path)){
                selectedList.removeWhere((v)=>v.path==metadata.path);
              }else{
                selectedList.add(metadata);
              }
              return;
            }

            _audioSource.currentAudioSource.value = audioSource;
            menuController.close();
            await _audioController.audioPlay(metadata: metadata);
          }.throttle(ms: isMulSelect.value?10:500),

          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: _borderRadius),
            backgroundColor: selectedList.any((v)=>v.path==metadata.path)? Theme.of(context).colorScheme.secondaryContainer:null,
          ),
          child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: _itemSpacing,
                children: [
                  AsyncCover(path: metadata.path, music: metadata),
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
                          style: textStyle,
                        ),
                        Text(
                          metadata.artist,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: subTextStyle,
                        ),
                      ],
                    ),
                  ),
                  if (_settingController.viewModeMap[operateArea])
                    Expanded(
                      flex: 2,
                      child: Text(
                        metadata.album,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: subTextStyle,
                      ),
                    ),
                  Text(
                    formatTime(totalSeconds: metadata.duration),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: subTextStyle,
                  ),
                ],
              ),
        );

        }),
      ),
    );
  }
}

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverSmallRenderSize = 150;

class AsyncCover extends StatelessWidget {
  final String path;
  final MusicCache music;
  const AsyncCover({super.key, required this.path, required this.music});

  Widget _renderCover() {
    return ClipRRect(
        borderRadius: _coverBorderRadius,
        child: Image.memory(
          music.src!,
          width: _coverSize,
          height: _coverSize,
          fit: BoxFit.cover,
          cacheWidth: _coverSmallRenderSize,
          cacheHeight: _coverSmallRenderSize,
          gaplessPlayback: true, // 防止图片突然闪烁
        )
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
