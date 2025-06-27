import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../HIveCtrl/hive_manager.dart';
import '../field/audio_source.dart';
import '../field/operate_area.dart';
import '../getxController/Audio_ctrl.dart';
import '../getxController/music_cache_ctrl.dart';
import '../getxController/play_list_ctrl.dart';
import '../tools/general_style.dart';



const double _bottom=96;

const double _radius = 6;

const double _ctrlBtnMinSize = 40.0;
const double _itemHeight = 64.0;
final MusicCacheController _musicCacheController = Get.find<MusicCacheController>();

final AudioController _audioController = Get.find<AudioController>();

final AudioSource _audioSource=Get.find<AudioSource>();

class _FloatingBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? fn;

  const _FloatingBtn({required this.tooltip, required this.icon, required this.fn});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: () {
          if (fn != null) {
            fn!();
          }
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(_ctrlBtnMinSize, _ctrlBtnMinSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: Icon(icon, size: getIconSize(size: 'lg')),
      ),
    );
  }
}

class FloatingButton extends StatelessWidget{
  final ScrollController scrollControllerList;
  final ScrollController scrollControllerGrid;

  const FloatingButton({super.key,required this.scrollControllerList,required this.scrollControllerGrid});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: _bottom,
        right: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8,
          children: [
            _FloatingBtn(tooltip: '回到顶部', icon:PhosphorIconsFill.arrowLineUp, fn: (){
              scrollControllerGrid.jumpTo(0.0);
              scrollControllerList.jumpTo(0.0);
            }),
            _FloatingBtn(tooltip: '定位', icon:PhosphorIconsLight.diamond, fn: (){
              final double middleOffset = (Get.height - _itemHeight - 144) / 2;

              int index=0;

              switch(_audioSource.currentAudioSource.value){
                case OperateArea.allMusic:
                  index=_musicCacheController.items.indexWhere((metadata) => metadata.path == _audioController.currentPath.value);
                  break;
              }

              if(_audioController.allUserKey.contains(_audioSource.currentAudioSource.value)){
                index=PlayListController.items.indexWhere((v)=>v.path==_audioController.currentPath.value);
              }

              double targetOffsetList = (index * _itemHeight - middleOffset).clamp(0.0, scrollControllerList.position.maxScrollExtent,);
              double targetOffsetGrid = (index ~/ (Get.width < 1100 ? 3 : 4) * (_itemHeight + 8) - middleOffset).clamp(0.0, scrollControllerGrid.position.maxScrollExtent,);

              scrollControllerList.jumpTo(targetOffsetList);
              scrollControllerGrid.jumpTo(targetOffsetGrid);

            }),
          ],
        )
    );
  }

}