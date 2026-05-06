import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:get/get.dart';
import '../getxController/audio_ctrl.dart';

class LyricsMesh extends GetView<AudioController> {
  const LyricsMesh({super.key});

  @override
  Widget build(BuildContext context) {
    final c=controller;

    return Obx((){
      List<Color> coverList=c.coverPalette;
      if(coverList.length>=4){
        coverList=coverList.sublist(0,4);
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
