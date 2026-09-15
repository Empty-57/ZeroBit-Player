import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';

/// 桌面背景图组件
class WindowBackgroundImage extends StatelessWidget {
  const WindowBackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Obx(() {
        final path = SettingController.instance.backgroundImagePath.value;
        if (path.isEmpty) return const SizedBox.shrink();

        final blur = SettingController.instance.backgroundImageBlur.value;

        Widget image = Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          cacheWidth: blur > 0 ? 960 : 1920, // 固定解码宽度不重复解码
        );

        if (blur > 0) {
          image = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.clamp,
            ),
            child: image,
          );
        }

        return RepaintBoundary(child: image);
      }),
    );
  }
}

/// 背景半透明蒙层组件
class WindowBackgroundOverlay extends StatelessWidget {
  const WindowBackgroundOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Obx(() {
        final hasImage =
            SettingController.instance.backgroundImagePath.value.isNotEmpty;
        final opacity = SettingController.instance.backgroundImageOpacity.value;

        return ColoredBox(
          color: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: hasImage ? opacity : 1.0),
        );
      }),
    );
  }
}
