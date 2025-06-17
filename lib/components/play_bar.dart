import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/Audio_ctrl.dart';

const double _barWidth=600;
const double _barHeight=64;
const double _barWidthHalf=300;


const double _bottom=25;
const double _navigationWidth = 300;

const double _radius=6;

const double _coverSize = 48.0;
const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
final double _dpr = Get.mediaQuery.devicePixelRatio;
final int _coverRenderSize = (_coverSize * _dpr).ceil();

final AudioController _audioController =Get.find<AudioController>();

class PlayBar extends StatelessWidget{
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _bottom,
      right: (context.width-_navigationWidth)/2-_barWidthHalf,
      child: ClipRRect(
        borderRadius: _coverBorderRadius,
        child: Stack(
        children: [
          Container(
          width: _barWidth,
          height: _barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            color: Theme.of(context).colorScheme.surfaceContainer,
            boxShadow: [BoxShadow(
               color: Colors.black38.withValues(alpha: 0.2),
        spreadRadius: 2,
        blurRadius: 4,
        offset: Offset(1, 2),
            )],
          ),
        ),
          Container(
            width: _barWidth/2,
          height: _barHeight,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(_radius),bottomLeft: Radius.circular(_radius)),
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
          ),

          ),
          TextButton(onPressed: (){},
              onHover: (isEnter){
            debugPrint(isEnter.toString());
              },
              style: TextButton.styleFrom(
                fixedSize: Size(_barWidth, _barHeight),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
              ),
              child: Obx(()=>
                  Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
      borderRadius: _coverBorderRadius,
      child: FadeInImage(
        key: ValueKey(_audioController.currentIndex.value),
        placeholder: MemoryImage(kTransparentImage),
        image: ResizeImage(
          MemoryImage(_audioController.currentIndex.value!=-1 && _audioController.cacheItems.isNotEmpty? _audioController.cacheItems[_audioController.currentIndex.value].src!:kTransparentImage),
          width: _coverRenderSize ,
          height: _coverRenderSize ,
        ),
        height: _coverSize,
        width: _coverSize,
        fit: BoxFit.cover,
      ),
    )
                ],
              ))
          ),
        ],
      ),
      ),
    );
  }
}