import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/getxController/music_cache_ctrl.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import 'package:zerobit_player/operate_area.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zerobit_player/custom_widgets/custom_widget.dart';
import 'package:transparent_image/transparent_image.dart';

import 'dart:typed_data';

import 'general_style.dart';

final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();
final SettingController _settingController =Get.find<SettingController>();

class LocalMusic extends StatelessWidget {
  const LocalMusic({super.key});

  String _formatTime(double totalSeconds) {
  // 向下取整获取整数秒
  final int seconds = totalSeconds.floor();
  // 计算分钟和剩余秒数
  final int minutes = seconds ~/ 60;
  final int remainingSeconds = seconds % 60;

  // 格式化为两位数
  final String minutesStr = minutes.toString().padLeft(2, '0');
  final String secondsStr = remainingSeconds.toString().padLeft(2, '0');

  return '$minutesStr:$secondsStr';
}


  @override
  Widget build(BuildContext context) {


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
        spacing: 8,
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
                    style: generalTextStyle(ctx: context,size: 28.0,weight: FontWeight.w400),
                  ),
                  Text(
                    '共${_musicCacheController.items.length}首',
                    style: generalTextStyle(ctx: context,size: 'md'),
                  ),
                ],
              ),
              Expanded(flex: 1, child: Container()),

              Obx(()=>CustomDropdownMenu(
                itemMap: {
                  0: [_settingController.sortType[0], PhosphorIconsRegular.textT],
                  1: [_settingController.sortType[1], PhosphorIconsRegular.vinylRecord],
                  2: [_settingController.sortType[2], PhosphorIconsRegular.userFocus],
                  3: [_settingController.sortType[3], PhosphorIconsRegular.clockCountdown],
                },
                fn: (entry){
                  _settingController.sortMap[OperateArea.local]=entry.key;
                _settingController.putCache();
                _musicCacheController.itemReSort(type: entry.key);
                },
                label: _settingController.sortType[_settingController.sortMap[OperateArea.local] as int]??"未指定",
                radius: 4,
                btnWidth: 140,
                btnHeight: 48,
                itemWidth: 140,
                itemHeight: 48,
                btnIcon: PhosphorIconsLight.funnelSimple,
                mainAxisAlignment: MainAxisAlignment.start,
                spacing: 6,
              )),

              Obx(()=>CustomBtn(
                fn: () {
                  _settingController.isReverse.value=!_settingController.isReverse.value;
                  _settingController.putCache();
                  _musicCacheController.itemReverse();
                },
                icon: _settingController.isReverse.value?PhosphorIconsLight.arrowDown:PhosphorIconsLight.arrowUp,
                radius: 4,
                btnHeight: 48,
                btnWidth: 48,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                tooltip: _settingController.isReverse.value? '降序':'升序',
              )
              ),

              Obx(()=>CustomBtn(
                fn: () {
                  _settingController.viewModeMap[OperateArea.local]=!_settingController.viewModeMap[OperateArea.local];
                  _settingController.putCache();
                },
                icon: _settingController.viewModeMap[OperateArea.local]?PhosphorIconsLight.listDashes:PhosphorIconsLight.gridFour,
                radius: 4,
                btnHeight: 48,
                btnWidth: 48,
                spacing: 4,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                tooltip: _settingController.viewModeMap[OperateArea.local]? "列表视图":"表格视图",
              )),

            ],
          ),

          Expanded(
            flex: 1,
            child:  Obx(()=> _settingController.viewModeMap[OperateArea.local]? ListView.builder(
              itemCount: _musicCacheController.items.length,
              itemExtent: 64,
              cacheExtent: 64 * 2,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onSecondaryTapUp: (e){
                    debugPrint(e.globalPosition.toString());

                  },
                  child: TextButton(
                  onPressed: () {
                    playFile(path: _musicCacheController.items[index].path);
                    },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 16,
                    children: [
                      AsyncCover(path: _musicCacheController.items[index].path, index: index),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _musicCacheController.items[index].title,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: generalTextStyle(ctx: context,size: 'md'),
                            ),
                            Text(
                              _musicCacheController.items[index].artist,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: generalTextStyle(ctx: context,size: 'sm',opacity: 0.8),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _musicCacheController.items[index].album,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: generalTextStyle(ctx: context,size: 'sm',opacity: 0.8),
                        ),
                      ),
                      Text(
                        _formatTime(_musicCacheController.items[index].duration),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: generalTextStyle(ctx: context,size: 'sm',opacity: 0.8),
                      ),
                    ],
                  ),
                ),
                );
              },
            ):GridView.builder(
              itemCount: _musicCacheController.items.length,
              cacheExtent: 64 * 2,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width<1100?3:4,
                  mainAxisSpacing: 4.0,
                  crossAxisSpacing: 8.0,
                  childAspectRatio: 1.0,
                  mainAxisExtent: 64,),
                itemBuilder: (context, index){
                return GestureDetector(
                  onSecondaryTapUp: (e){
                    debugPrint("2");

                  },
                  child: TextButton(
                  onPressed: () {
                    playFile(path: _musicCacheController.items[index].path);
                    },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 16,
                    children: [
                      AsyncCover(path: _musicCacheController.items[index].path, index: index),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _musicCacheController.items[index].title,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: generalTextStyle(ctx: context,size: 'md'),
                            ),
                            Text(
                              _musicCacheController.items[index].artist,
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: generalTextStyle(ctx: context,size: 'sm',opacity: 0.8),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(_musicCacheController.items[index].duration),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: generalTextStyle(ctx: context,size: 'sm',opacity: 0.8),
                      ),
                    ],
                  ),
                ),
                );
            }
            )
            ),
          ),
        ],
      ),
    );
  }
}

class AsyncCover extends StatelessWidget {
  final String path;
  final int index;
  const AsyncCover({super.key,required this.path,required this.index});

  Widget _renderCover(){
    return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: MemoryImage(_musicCacheController.items[index].src!),
              height: 48,
              width: 48,
              fit: BoxFit.cover,
            ),
          );
  }

  Future<Uint8List?> _loadCover()async{
    final coverData=await getCover(
        path: path,
        sizeFlag: 0,
      );
    if(coverData==null){
      final title = _musicCacheController.items[index].title;
      final artist = _musicCacheController.items[index].artist.isNotEmpty ? ' - ${_musicCacheController.items[index].artist}' : '';
      final coverData_= await saveCoverByText(text: title+artist, songPath: path);
      if(coverData_ != null && coverData_.isNotEmpty){
        return Uint8List.fromList(coverData_);
      }
    }
    return coverData;
  }

  @override
  Widget build(BuildContext context) {
    return _musicCacheController.items[index].src==null? FutureBuilder<Uint8List?>(
      future: _loadCover(),
      builder: (context, snapshot) {

        if (snapshot.hasData) {
          _musicCacheController.items[index].src=snapshot.data!;

          return _renderCover();
        }
        return SizedBox(height: 48, width: 48,);
      },
    ):_renderCover();
  }
}
