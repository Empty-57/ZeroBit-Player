import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerobit_player/API/apis.dart';
import 'package:zerobit_player/getxController/music_cache_ctrl.dart';
import 'package:zerobit_player/src/rust/api/bass.dart';
import 'package:zerobit_player/src/rust/api/music_tag_tool.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zerobit_player/custom_widgets/custom_widget.dart';
import 'package:transparent_image/transparent_image.dart';

import 'dart:typed_data';

import 'general_style.dart';

final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();

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
                spacing: 4,
                children: [
                  Text(
                    '音乐',
                    style: generalTextStyle(ctx: context,size: 28.0),
                  ),
                  Text(
                    '${_musicCacheController.items.length}首',
                    style: generalTextStyle(ctx: context,size: 'md'),
                  ),
                ],
              ),
              Expanded(flex: 1, child: Container()),
              CustomDropdownMenu(
                itemMap: {
                  '专辑': [1, PhosphorIconsRegular.vinylRecord],
                  '艺术家': [2, PhosphorIconsRegular.userFocus],
                },
                radius: 4,
                btnWidth: 160,
                btnHeight: 48,
                itemWidth: 160,
                itemHeight: 60,
                btnIcon: PhosphorIconsLight.funnelSimple,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
              CustomBtn(
                fn: () {
                  toggle();
                },
                label: '功能1',
                icon: PhosphorIconsLight.code,
                radius: 4,
                btnHeight: 48,
                btnWidth: 128,
                spacing: 4,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
              ),
              CustomBtn(
                fn: () {
                  resume();
                },
                icon: PhosphorIconsLight.sortAscending,
                radius: 4,
                btnHeight: 48,
                btnWidth: 64,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
              ),
            ],
          ),
          Expanded(
            flex: 1,
            child: Obx(()=>ListView.builder(
              itemCount: _musicCacheController.items.length,
              itemExtent: 64,
              cacheExtent: 64 * 2,
              itemBuilder: (context, index) {

                return TextButton(
                  onPressed: () {
                    playFile(path: _musicCacheController.items[index].path);
                    },
                  style: TextButton.styleFrom(
                    overlayColor:
                        Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
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
                );
              },
            )),
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
