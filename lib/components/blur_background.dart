import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const int _coverBigRenderSize = 800;

class BlurWithCoverBackground extends StatelessWidget {
  final Rx<Uint8List> cover;
  final Widget child;
  final double sigma;
  final double coverScale;

  const BlurWithCoverBackground({super.key, required this.cover, required this.child,this.sigma=48,this.coverScale=1});

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
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
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
                      cover.value,
                      scale: coverScale,
                      key: ValueKey(cover.value.hashCode),
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
