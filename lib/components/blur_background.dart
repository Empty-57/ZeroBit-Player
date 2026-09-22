import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/covers.dart';
import 'package:zerobit_player/components/play_page/play_page_mesh.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/paint_cache.dart';

final LinearGradient _maskGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Colors.white.withValues(alpha: 0.4), Colors.transparent],
  tileMode: TileMode.clamp,
);

final GradientShaderCache _gradientShaderCache = GradientShaderCache();

class BlurWithCoverBackground extends StatelessWidget {
  final Signal<Uint8List> cover;
  final Widget child;
  final double sigma;
  final double coverScale;
  final bool useGradient;
  final bool useMask;
  final double radius;
  final bool meshEnable;
  final bool onlyDarkMode;
  final bool isPlayPage;

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
    this.isPlayPage = false,
  });

  SettingController get _settingController => SettingController.instance;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = onlyDarkMode
        ? ThemeService.instance.darkTheme.colorScheme.surface
        : Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        ClipRRect(
          child: Container(
            color:
                _settingController.backgroundImagePath.value.isNotEmpty ||
                    _settingController.useTransparencyBackground.value
                ? null
                : backgroundColor,
          ),
        ),

        RepaintBoundary(
          child: () {
            final bool useMesh = _settingController.useMesh.value && meshEnable;
            if (useMesh) {
              return PlayPageMesh();
            }

            if (!isPlayPage &&
                (_settingController.backgroundImagePath.value.isNotEmpty ||
                    _settingController.useTransparencyBackground.value)) {
              return const SizedBox.shrink();
            }

            return SignalBuilder(
              builder: (context) {
                final String themeMode = _settingController.themeMode.value;
                final Uint8List coverBytes = cover.value;

                final rawCover = Transform.scale(
                  scale: coverScale,
                  child: SizedBox.expand(child: LoadU8Cover(data: coverBytes)),
                );

                return Opacity(
                  opacity: isPlayPage
                      ? 1.0
                      : themeMode == 'dark'
                      ? 0.9
                      : 0.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radius),
                    ),
                    child: ImageFiltered(
                      imageFilter: ImageFilterCache.imageFilter(
                        sigma: sigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: useGradient
                          ? ShaderMask(
                              blendMode: BlendMode.modulate,
                              shaderCallback: (Rect bounds) {
                                return _gradientShaderCache.shader(
                                  gradient: _maskGradient,
                                  rect: bounds,
                                );
                              },
                              child: rawCover,
                            )
                          : rawCover,
                    ),
                  ),
                );
              },
            );
          }(),
        ),

        if (useMask)
          Container(
            color: backgroundColor.withValues(
              alpha:
                  _settingController.themeMode.value == 'dark' || onlyDarkMode
                  ? 0.4
                  : 0.2,
            ),
          ),
        RepaintBoundary(child: child),
      ],
    );
  }
}
