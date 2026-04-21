import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/components/lyrics_mesh.dart';

import '../getxController/setting_ctrl.dart';
import '../theme_manager.dart';

const int _coverBigRenderSize = 800;

class BlurWithCoverBackground extends StatelessWidget {
  final Rx<Uint8List> cover;
  final Widget child;
  final double sigma;
  final double coverScale;
  final bool useGradient;
  final bool useMask;
  final double radius;
  final bool meshEnable;
  final bool onlyDarkMode;

  const BlurWithCoverBackground({
    super.key,
    required this.cover,
    required this.child,
    this.sigma = 48,
    this.coverScale = 1,
    this.useGradient = true,
    this.useMask = false,
    this.radius = 8.0,
    this.meshEnable = false,
    this.onlyDarkMode = false,
  });

  Widget get _cover => Transform.scale(
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
    ),
  );

  SettingController get _settingController => Get.find<SettingController>();
  ThemeService get _themeService => Get.find<ThemeService>();

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        onlyDarkMode
            ? _themeService.darkTheme.colorScheme.surface
            : Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
          child: Container(color: backgroundColor),
        ),

        RepaintBoundary(
          child: Obx(
            () =>
                _settingController.useMesh.value && meshEnable
                    ? LyricsMesh()
                    : Opacity(
                      opacity:
                          _settingController.themeMode.value == 'dark'
                              ? 0.9
                              : 0.6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(radius),
                        ),
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: sigma,
                            sigmaY: sigma,
                            tileMode: TileMode.clamp,
                          ),
                          child:
                              useGradient
                                  ? ShaderMask(
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
                                  )
                                  : _cover,
                        ),
                      ),
                    ),
          ),
        ),

        if (useMask)
          ClipRRect(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
            child: Container(
              color: backgroundColor.withValues(
                alpha:
                    _settingController.themeMode.value == 'dark' || onlyDarkMode
                        ? 0.4
                        : 0.2,
              ),
            ),
          ),
        RepaintBoundary(child: child),
      ],
    );
  }
}
