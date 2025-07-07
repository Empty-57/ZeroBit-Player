import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../components/window_ctrl_bar.dart';
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
          const WindowControllerBar(isNestedRoute: false,useCaretDown: true),

          Expanded(
            child: Container(
              alignment: Alignment.center,

              child: Hero(
                tag: 'playingCover',
                child: ClipRRect(
                    borderRadius: _coverBorderRadius,
                    child: Obx(()=>AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: Image.memory(
                        _audioController.currentCover.value,
                        key: ValueKey(
                          _audioController.currentCover.value.hashCode,
                        ),
                        cacheWidth: _coverRenderSize,
                        cacheHeight: _coverRenderSize,
                        height: _coverSize,
                        width: _coverSize,
                        fit: BoxFit.cover,
                      ),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> anim,
                      ) {
                        return FadeTransition(opacity: anim, child: child);
                      },
                    )),
                  ),
              ),

            ),
          ),
        ],
      ),
    );
  }
}
