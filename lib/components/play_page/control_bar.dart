import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/play_page/play_page_constant.dart';
import 'package:zerobit_player/components/play_page/search_dialog.dart';
import 'package:zerobit_player/components/widget/audio_ctrl_btn.dart';
import 'package:zerobit_player/components/widget/rect_value_indicator.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

import '../play_queue_menu_anchor.dart';

class _GradientSliderTrackShape extends SliderTrackShape {
  final double activeTrackHeight;
  final double inactiveTrackHeight;
  final Color activeColor;

  const _GradientSliderTrackShape({
    this.activeTrackHeight = 6.0,
    this.inactiveTrackHeight = 4.0,
    required this.activeColor,
  });

  static final Paint _inactivePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _activePaint = Paint()..style = PaintingStyle.fill;
  static const List<double> _stops = <double>[0.0, 0.1];

  static Color? _lastActiveColor;
  static List<Color>? _cachedColors;

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
    final double top = offset.dy + (parentBox.size.height - height) * 0.5;
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

    final double trackLeft = baseRect.left;
    final double trackRight = baseRect.right;
    final double centerY = baseRect.top + baseRect.height * 0.5;

    final double inRadius = inactiveTrackHeight * 0.5;
    final RRect inactiveRRect = RRect.fromLTRBXY(
      trackLeft,
      centerY - inRadius,
      trackRight,
      centerY + inRadius,
      inRadius,
      inRadius,
    );

    _inactivePaint.color = sliderTheme.inactiveTrackColor!;
    canvas.drawRRect(inactiveRRect, _inactivePaint);

    final double currentThumbX = thumbCenter.dx;

    final double actRadius = activeTrackHeight * 0.5;

    final RRect activeRRect = RRect.fromLTRBXY(
      trackLeft,
      baseRect.top,
      currentThumbX,
      baseRect.bottom,
      actRadius,
      actRadius,
    );

    if (_lastActiveColor != activeColor || _cachedColors == null) {
      _lastActiveColor = activeColor;
      _cachedColors = <Color>[activeColor.withValues(alpha: 0.0), activeColor];
    }

    final shader = ui.Gradient.linear(
      Offset(trackLeft, centerY),
      Offset(currentThumbX, centerY),
      _cachedColors!,
      _stops,
    );

    _activePaint.shader = shader;
    try {
      canvas.drawRRect(activeRRect, _activePaint);
    } finally {
      _activePaint.shader = null;
      shader.dispose();
    }
  }
}

class ControlBar extends StatelessWidget {
  final Color? mixColor;
  final Color activeTrackCover;
  final Color inactiveTrackCover;
  final TextStyle timeCurrentStyle;
  final TextStyle timeTotalStyle;
  final ScrollController playQueueScrollController;
  final MenuController playQueueMenuController;
  final Signal<bool> isBarHover;

  const ControlBar({
    super.key,
    required this.mixColor,
    required this.activeTrackCover,
    required this.inactiveTrackCover,
    required this.timeCurrentStyle,
    required this.timeTotalStyle,
    required this.playQueueScrollController,
    required this.playQueueMenuController,
    required this.isBarHover,
  });

  @override
  Widget build(BuildContext context) {
    final AudioController audioController = AudioController.instance;
    final SettingController settingController = SettingController.instance;

    final audioCtrlWidget = AudioCtrlWidget(
      context: context,
      size: PlayPageConstant.ctrlBtnMinSize,
      color: mixColor,
    );

    final titleStyle = generalTextStyle(ctx: context, size: 'md');
    final highLightTitleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );
    final subStyle = generalTextStyle(ctx: context, size: 'sm', opacity: 0.8);
    final highLightSubStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
    );
    final width = MediaQuery.sizeOf(context).width;

    final void Function() toggleShowDesktopThrottle = settingController
        .setShowDesktopLyrics
        .throttle();

    return MouseRegion(
      onEnter: (_) => isBarHover.value = true,
      onExit: (_) => isBarHover.value = false,
      child: SizedBox(
        height: PlayPageConstant.audioCtrlBarHeight,
        child: Column(
          children: [
            RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackShape: _GradientSliderTrackShape(
                      activeTrackHeight: 2,
                      inactiveTrackHeight: 1,
                      activeColor: activeTrackCover,
                    ),
                    inactiveTrackColor: inactiveTrackCover,
                    showValueIndicator: ShowValueIndicator.onDrag,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: PlayPageConstant.thumbRadius,
                      elevation: 0,
                      pressedElevation: 0,
                    ),
                    padding: EdgeInsets.zero,
                    thumbColor: Colors.transparent,
                    overlayColor: Colors.transparent,
                    valueIndicatorShape: const RectangularValueIndicatorShape(
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
                  child: audioCtrlWidget.seekSlide,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: PlayPageConstant.thumbRadius,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: width * 0.25,
                      height: PlayPageConstant.audioCtrlBarHeight - 24,
                      child: RepaintBoundary(
                        child: SignalBuilder(
                          builder: (context) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatTime(
                                  totalSeconds:
                                      audioController.currentSec.value,
                                ),
                                style: timeCurrentStyle,
                              ),
                              Text(
                                formatTime(
                                  totalSeconds:
                                      audioController.currentDuration.value,
                                ),
                                style: timeTotalStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SignalBuilder(
                        builder: (context) => AnimatedOpacity(
                          opacity: isBarHover.value ? 1.0 : 0.0,
                          duration: 150.ms,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 16,
                            children: [
                              audioCtrlWidget.volumeSet,
                              audioCtrlWidget.skipBack,
                              audioCtrlWidget.toggle,
                              audioCtrlWidget.skipForward,
                              audioCtrlWidget.changeMode,
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width * 0.25,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 8,
                        children: [
                          SignalBuilder(
                            builder: (context) => GenIconBtn(
                              tooltip:
                                  SettingController
                                      .lrcAlignmentMap[settingController
                                      .lrcAlignment
                                      .value] ??
                                  '',
                              icon:
                                  PlayPageConstant
                                      .lrcAlignmentIcons[settingController
                                      .lrcAlignment
                                      .value],
                              size: PlayPageConstant.ctrlBtnMinSize,
                              color: mixColor,
                              fn: () => audioController.changeLrcAlignment(),
                            ),
                          ),
                          NetLrcDialog(color: mixColor),
                          PlayQueueMenuAnchor(
                            titleStyle: titleStyle,
                            highLightTitleStyle: highLightTitleStyle,
                            subStyle: subStyle,
                            highLightSubStyle: highLightSubStyle,
                            builder: (c) {
                              return GenIconBtn(
                                tooltip: '播放列表',
                                icon: PhosphorIconsLight.queue,
                                size: PlayPageConstant.ctrlBtnMinSize,
                                color: mixColor,
                                fn: () {
                                  if (c.isOpen) {
                                    c.close();
                                  } else {
                                    c.open();
                                  }
                                },
                              );
                            },
                          ),
                          audioCtrlWidget.equalizerSet,
                          SignalBuilder(
                            builder: (context) => GenIconBtn(
                              tooltip: '桌面歌词',
                              icon: settingController.showDesktopLyrics.value
                                  ? PhosphorIconsFill.creditCard
                                  : PhosphorIconsLight.creditCard,
                              size: PlayPageConstant.ctrlBtnMinSize,
                              color: mixColor,
                              fn: toggleShowDesktopThrottle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
