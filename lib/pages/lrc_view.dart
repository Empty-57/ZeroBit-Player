import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';

import '../components/window_ctrl.dart';
import '../getxController/audio_ctrl.dart';

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

final AudioController _audioController = Get.find<AudioController>();

const double _coverSize = 400;
const int _coverRenderSize = 800;

class LrcView extends StatelessWidget {
  const LrcView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const WindowController(isNestedRoute: false),

          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Hero(
                tag: 'playingCover',
                child: Obx(
                  () => ClipRRect(
                    borderRadius: _coverBorderRadius,
                    child: FadeInImage(
                      placeholder: MemoryImage(kTransparentImage),
                      image: ResizeImage(
                        MemoryImage(_audioController.currentCover.value),
                        width: _coverRenderSize,
                        height: _coverRenderSize,
                      ),
                      height: _coverSize,
                      width: _coverSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
