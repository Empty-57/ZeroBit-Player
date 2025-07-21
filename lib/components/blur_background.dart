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
  final bool useGradient;
  final bool useMask;

  const BlurWithCoverBackground({super.key, required this.cover, required this.child,this.sigma=48,this.coverScale=1,this.useGradient=true,this.useMask=false});

  Widget get _cover=>Transform.scale(
    scale: coverScale,
    child: Obx(
                () => SizedBox.expand(
                    child: Image.memory(
                      cover.value,
                      cacheWidth: _coverBigRenderSize,
                      cacheHeight: _coverBigRenderSize,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                  transitionBuilder: (Widget child, Animation<double> anim) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                ),
              ),
  );

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
            imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma,tileMode: TileMode.clamp),
            child: useGradient? ShaderMask(
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
              child: _cover,
            ):_cover,
          ),
        ),
        if(useMask) ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          child: Container(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4)),
        ),
        child,
      ],
    );
  }
}
