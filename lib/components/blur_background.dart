import 'dart:ui';

import '../tools/audio_ctrl_mixin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const int _coverBigRenderSize=800;

class BlurBackground extends StatelessWidget {
  final AudioControllerGenClass controller;
  final Widget child;

  const BlurBackground({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          child: Container(color: Theme.of(context).colorScheme.surface),
        ),
        ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: ShaderMask(
              blendMode: BlendMode.modulate,
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  tileMode: TileMode.clamp,
                ).createShader(bounds);
              },
              child: Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: SizedBox.expand(
                    child: Image.memory(
                      controller.headCover.value,
                      key: ValueKey(controller.headCover.value.hashCode),
                      cacheWidth: _coverBigRenderSize,
                      cacheHeight: _coverBigRenderSize,
                      fit: BoxFit.fill,
                    ),
                  ),
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}