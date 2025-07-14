import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../components/audio_ctrl_btn.dart';
import '../components/window_ctrl_bar.dart';
import '../getxController/audio_ctrl.dart';
import '../tools/format_time.dart';
import '../tools/rect_value_indicator.dart';

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

final AudioController _audioController = Get.find<AudioController>();
final _isSeekBarDragging = false.obs;

final _seekDraggingValue = 0.0.obs;

const int _coverRenderSize = 800;
const double _ctrlBtnMinSize = 40.0;
const double _thumbRadius = 10.0;
final _isBarHover = false.obs;
final _onlyCover = false.obs;

final double _audioCtrlBarHeight = 96;

class _GradientSliderTrackShape extends SliderTrackShape {
  final double activeTrackHeight;
  final double inactiveTrackHeight;
  final Color activeColor;
  const _GradientSliderTrackShape({
    this.activeTrackHeight = 6.0,
    this.inactiveTrackHeight = 4.0,
    required this.activeColor,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double height = activeTrackHeight;
    final double left = offset.dx;
    final double width = parentBox.size.width;
    final double top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    Offset? secondaryOffset,
    required Offset thumbCenter,
    required TextDirection textDirection,
  }) {
    final Canvas canvas = context.canvas;

    final Rect baseRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double inH = inactiveTrackHeight;
    final double inTop = offset.dy + (parentBox.size.height - inH) / 2;
    final Rect inactiveRect = Rect.fromLTWH(
      baseRect.left,
      inTop,
      baseRect.width,
      inH,
    );
    final Paint inactivePaint =
        Paint()
          ..color = sliderTheme.inactiveTrackColor!
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveRect, Radius.circular(inH / 2)),
      inactivePaint,
    );

    final Rect activeRect = Rect.fromLTRB(
      baseRect.left,
      baseRect.top,
      thumbCenter.dx,
      baseRect.bottom,
    );
    final Paint activePaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, activeColor],
            stops: [0.0, 0.1],
          ).createShader(activeRect)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        activeRect,
        Radius.circular(activeTrackHeight / 2),
      ),
      activePaint,
    );
  }
}

class LrcView extends StatelessWidget {
  const LrcView({super.key});

  @override
  Widget build(BuildContext context) {
    double coverSize = (context.width * 0.3).clamp(300, 500);
    final halfWidth = context.width / 2;
    final activeCover = Theme.of(context).colorScheme.primary;
    final timeCurrentStyle = generalTextStyle(
      ctx: context,
      size: 'xl',
      weight: FontWeight.w100,
      color: Theme.of(context).colorScheme.primary,
    );
    final timeTotalStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      weight: FontWeight.w100,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    );
    final audioCtrlWidget = AudioCtrlWidget(
      context: context,
      size: _ctrlBtnMinSize,
    );
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
                  child: Obx(() {
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                                color: Colors.blue,
                                width: halfWidth,
                                alignment: Alignment.center,
                                child: Text(
                                  "Lrc",
                                  style: generalTextStyle(ctx: context),
                                ),
                              )
                              .animate(target: _onlyCover.value ? 1 : 0)
                              .fade(duration: 300.ms, begin: 1.0, end: 0.0),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                                width: halfWidth,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            offset: Offset(0, 2),
                                            blurRadius: 6,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Hero(
                                        tag: 'playingCover',
                                        child: ClipRRect(
                                          borderRadius: _coverBorderRadius,
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onTap:
                                                  () =>
                                                      _onlyCover.value =
                                                          !_onlyCover.value,
                                              child: Obx(
                                                () => Image.memory(
                                                      _audioController
                                                          .currentCover
                                                          .value,
                                                      key: ValueKey(
                                                        _audioController
                                                            .currentCover
                                                            .value
                                                            .hashCode,
                                                      ),
                                                      cacheWidth:
                                                          _coverRenderSize,
                                                      cacheHeight:
                                                          _coverRenderSize,
                                                      height: coverSize,
                                                      width: coverSize,
                                                      fit: BoxFit.cover,
                                                    )
                                                    .animate(
                                                      key: ValueKey(
                                                        _audioController
                                                            .currentCover
                                                            .value
                                                            .hashCode,
                                                      ),
                                                    )
                                                    .fade(
                                                      duration: 300.ms,
                                                      curve: Curves.easeInOut,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: coverSize - 24,
                                      margin: EdgeInsets.only(top: 24),
                                      child: Obx(
                                        () => Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.8),
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
                              )
                              .animate(target: _onlyCover.value ? 1 : 0)
                              .moveX(
                                begin: 0,
                                end: halfWidth / 2,
                                duration: 300.ms,
                                curve: Curves.fastOutSlowIn,
                              ),
                        ),
                      ],
                    );
                  }),
                ),
                SizedBox(
                  height: _audioCtrlBarHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackShape: _GradientSliderTrackShape(
                              activeTrackHeight: 2,
                              inactiveTrackHeight: 1,
                              activeColor: activeCover,
                            ),
                            showValueIndicator: ShowValueIndicator.always,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: _thumbRadius,
                              elevation: 0,
                              pressedElevation: 0,
                            ),
                            padding: EdgeInsets.zero,

                            inactiveTrackColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            thumbColor: Colors.transparent,
                            overlayColor: Colors.transparent,
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
                            return Obx(
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
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: _thumbRadius,
                          ),
                          child: MouseRegion(
                            onEnter: (_) {
                              _isBarHover.value = true;
                            },
                            onExit: (_) {
                              _isBarHover.value = false;
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: context.width * 0.2,
                                  child: Obx(
                                    () => Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 2,
                                      children: [
                                        Text(
                                          formatTime(
                                            totalSeconds:
                                                _audioController
                                                    .currentMs100
                                                    .value,
                                          ),
                                          style: timeCurrentStyle,
                                        ),
                                        Text(
                                          formatTime(
                                            totalSeconds:
                                                _audioController
                                                    .currentMetadata
                                                    .value
                                                    .duration,
                                          ),
                                          style: timeTotalStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Obx(
                                    () => Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          spacing: 16,
                                          children: [
                                            audioCtrlWidget.volumeSet,
                                            audioCtrlWidget.skipBack,
                                            audioCtrlWidget.toggle,
                                            audioCtrlWidget.skipForward,
                                            audioCtrlWidget.changeMode,
                                          ],
                                        )
                                        .animate(
                                          target: _isBarHover.value ? 1 : 0,
                                        )
                                        .fade(duration: 150.ms),
                                  ),
                                ),
                                SizedBox(
                                  width: context.width * 0.2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    spacing: 16,
                                    children: [
                                      GenIconBtn(
                                        tooltip: '网络歌词',
                                        icon: PhosphorIconsLight.article,
                                        size: _ctrlBtnMinSize,
                                        fn: () {},
                                      ),
                                      GenIconBtn(
                                        tooltip: '桌面歌词',
                                        icon: PhosphorIconsLight.creditCard,
                                        size: _ctrlBtnMinSize,
                                        fn: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
