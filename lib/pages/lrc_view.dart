import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../components/window_ctrl_bar.dart';
import '../getxController/audio_ctrl.dart';
import '../tools/format_time.dart';
import '../tools/rect_value_indicator.dart';

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

final AudioController _audioController = Get.find<AudioController>();

final _isSeekBarDragging = false.obs;

final _seekDraggingValue = 0.0.obs;

const int _coverRenderSize = 800;

class LrcView extends StatelessWidget {
  const LrcView({super.key});

  @override
  Widget build(BuildContext context) {
    double coverSize = (context.width * 0.3).clamp(300, 500);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const WindowControllerBar(
            isNestedRoute: false,
            showLogo: false,
            useCaretDown: true,
            useSearch: false,
          ),

          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'playingCover',
                                child: ClipRRect(
                                  borderRadius: _coverBorderRadius,
                                  child: Obx(
                                    () => AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      switchInCurve: Curves.easeIn,
                                      switchOutCurve: Curves.easeOut,
                                      child: Image.memory(
                                        _audioController.currentCover.value,
                                        key: ValueKey(
                                          _audioController
                                              .currentCover
                                              .value
                                              .hashCode,
                                        ),
                                        cacheWidth: _coverRenderSize,
                                        cacheHeight: _coverRenderSize,
                                        height: coverSize,
                                        width: coverSize,
                                        fit: BoxFit.cover,
                                      ),
                                      transitionBuilder: (
                                        Widget child,
                                        Animation<double> anim,
                                      ) {
                                        return FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: coverSize - 20,
                                margin: EdgeInsets.only(top: 24),
                                child: Obx(
                                  () => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 2,
                                    children: [
                                      Text(
                                        _audioController
                                            .currentMetadata
                                            .value
                                            .title,
                                        style: generalTextStyle(
                                          ctx: context,
                                          size: 'xl',
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          weight: FontWeight.w600,
                                        ),
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      Text(
                                        "${_audioController.currentMetadata.value.artist} - ${_audioController.currentMetadata.value.album}",
                                        style: generalTextStyle(
                                          ctx: context,
                                          size: 'md',
                                          weight: FontWeight.w100,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.blue,
                          alignment: Alignment.center,
                          child: Text(
                            "Lrc",
                            style: generalTextStyle(ctx: context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 84,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 1,
                            showValueIndicator: ShowValueIndicator.always,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10.0,
                              elevation: 0,
                              pressedElevation: 0,
                            ),
                            padding: EdgeInsets.zero,
                            activeTrackColor:
                                Theme.of(context).colorScheme.primary,
                            thumbColor: Colors.transparent,
                            overlayColor: Colors.transparent,
                            inactiveTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.6),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: 0,
                            ),
                            valueIndicatorShape: RectangularValueIndicatorShape(
                              width: 48,
                              height: 28,
                              radius: 4,
                            ),
                            valueIndicatorTextStyle: generalTextStyle(
                              ctx: context,
                              size: 'sm',
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            mouseCursor: WidgetStateProperty.all(
                              SystemMouseCursors.click,
                            ),
                          ),
                          child: Obx(() {
                            late final double duration;
                            if (_audioController
                                .currentMetadata
                                .value
                                .path
                                .isNotEmpty) {
                              duration =
                                  _audioController
                                      .currentMetadata
                                      .value
                                      .duration;
                            } else {
                              _seekDraggingValue.value = 0.0;
                              duration = 9999.0;
                            }
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Obx(
                                () => Slider(
                                  min: 0.0,
                                  max: duration,
                                  label:
                                      _isSeekBarDragging.value
                                          ? formatTime(
                                            totalSeconds:
                                                _seekDraggingValue.value,
                                          )
                                          : '√',
                                  value:
                                      _isSeekBarDragging.value
                                          ? _seekDraggingValue.value
                                          : _audioController.currentMs100.value,
                                  onChangeStart: (v) {
                                    _seekDraggingValue.value = v;
                                    _isSeekBarDragging.value = true;
                                  },
                                  onChanged: (v) {
                                    _seekDraggingValue.value = v;
                                  },
                                  onChangeEnd: (v) {
                                    _audioController.currentMs100.value = v;
                                    _isSeekBarDragging.value = false;
                                    _audioController.audioSetPositon(pos: v);
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
