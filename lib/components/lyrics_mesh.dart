import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:get/get.dart';
import '../getxController/audio_ctrl.dart';

final AudioController _audioController = Get.find<AudioController>();

class LyricsMesh extends StatelessWidget {
  const LyricsMesh({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx((){
      List<Color> coverList=_audioController.coverPalette;
      if(_audioController.coverPalette.length>=4){
        coverList=_audioController.coverPalette.sublist(0,4);
      }
      return AnimatedMeshGradient(
      colors: coverList,
      options: AnimatedMeshGradientOptions(
        frequency: 5,
        amplitude:30,
        speed: 0.6,
        grain: 0,
      ),
      child: Container(),
    );
    });
  }
}
