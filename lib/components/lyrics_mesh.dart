import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';

class LyricsMesh extends GetView<AudioController> {
  const LyricsMesh({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx((){
      return AnimatedMeshGradient(
      colors: controller.coverPalette,
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
