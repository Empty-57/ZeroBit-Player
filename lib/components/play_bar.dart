import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/format_time.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../tools/rect_value_indicator.dart';
import 'audio_ctrl_btn.dart';

const double _barWidth = 700;
const double _barHeight = 64;
const double _barWidthHalf = 350;

const double _bottom = 4;
const double _navigationWidth = 260;
const double _navigationWidthSmall = 84;
const double resViewThresholds= 1100;

const double _radius = 6;

const double _coverSize = 48.0;

const double _ctrlBtnMinSize = 40.0;

final _isBarHover = false.obs;

final _isSeekBarDragging = false.obs;

final _seekDraggingValue = 0.0.obs;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverRenderSize = 150;

final AudioController _audioController = Get.find<AudioController>();

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final progressColor = Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.8);

    final fgPaint =
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.fill;

    return RepaintBoundary(
      child: Obx(() {
        return CustomPaint(
          willChange: true,
          size: Size(_barWidth, _barHeight),
          painter: _ProgressPainter(
            progress: _audioController.progress.value,
            color: progressColor,
            fgPaint: fgPaint,
          ),
        );
      }),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Paint fgPaint;
  const _ProgressPainter({
    required this.progress,
    required this.color,
    required this.fgPaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final progressRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      topLeft: Radius.circular(_radius),
      bottomLeft: Radius.circular(_radius),
    );

    canvas.drawRRect(progressRect, fgPaint);
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// 自定义菱形按钮
class _DiamondSliderThumbShape extends SliderComponentShape {
  /// 水平对角线长度
  final double horizontalDiagonal;

  /// 垂直对角线长度
  final double verticalDiagonal;

  const _DiamondSliderThumbShape({
    this.horizontalDiagonal = 12,
    this.verticalDiagonal = 24,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    final width = verticalDiagonal;
    final height = verticalDiagonal;
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final paint =
        Paint()
          ..color = sliderTheme.thumbColor ?? Colors.blue
          ..style = PaintingStyle.fill;

    final hd2 = horizontalDiagonal / 2;
    final vd2 = verticalDiagonal / 2;

    final path =
        Path()
          ..moveTo(center.dx, center.dy - vd2) // 上顶点
          ..lineTo(center.dx + hd2, center.dy) // 右顶点
          ..lineTo(center.dx, center.dy + vd2) // 下顶点
          ..lineTo(center.dx - hd2, center.dy) // 左顶点
          ..close();

    canvas.drawPath(path, paint);
  }
}

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    final timeTextStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
    );
    final audioCtrlWidget=AudioCtrlWidget(context: context,size: _ctrlBtnMinSize);

    return Positioned(
      bottom: _bottom,
      right: (context.width - (context.width>resViewThresholds? _navigationWidth:_navigationWidthSmall)) / 2 - _barWidthHalf,
      child: ClipRRect(
        borderRadius: _coverBorderRadius,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 1,
                  showValueIndicator: ShowValueIndicator.always,
                  thumbShape: const _DiamondSliderThumbShape(
                    horizontalDiagonal: 8,
                    verticalDiagonal: 16,
                  ),
                  padding: EdgeInsets.zero,
                  activeTrackColor: Colors.transparent,
                  thumbColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                  inactiveTrackColor: Colors.transparent,
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: 0,
                  ), // 按下圈大小
                  valueIndicatorShape: RectangularValueIndicatorShape(
                    width: 48,
                    height: 28,
                    radius: 4,
                  ),
                  valueIndicatorTextStyle:generalTextStyle(ctx: context,size: 'sm',color: Theme.of(context).colorScheme.onPrimary),
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.resizeLeftRight),
                ),
                child: Obx(() {
                  late final double duration;
                  if (_audioController.currentMetadata.value.path.isNotEmpty) {
                    duration = _audioController.currentMetadata.value.duration;
                  } else {
                    _seekDraggingValue.value=0.0;
                    duration = 9999.0;
                  }
                  return Container(
                    width: _barWidth+16,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Obx(
                      () => Slider(
                        min: 0.0,
                        max: duration,
                        label: _isSeekBarDragging.value ? formatTime(
                          totalSeconds: _seekDraggingValue.value,
                        ):'√',
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
            Stack(
              children: [
                Container(
                  width: _barWidth,
                  height: _barHeight,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38.withValues(alpha: 0.2),
                        spreadRadius: 2,
                        blurRadius: 4,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                ),
                const _ProgressBar(),
                TextButton(
                  onPressed: (){
                    Get.toNamed(AppRoutes.lrcView);
                  },
                  onHover: (v) {
                    _isBarHover.value = v;
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    fixedSize: Size(_barWidth, _barHeight),
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                  ),
                  child: Obx(() {
                    late final Uint8List src;
                    late final String title;
                    late final String artist;
                    late final String duration;
                    final currentMetadata =_audioController.currentMetadata.value;
                    if (currentMetadata.path.isNotEmpty) {
                      src = currentMetadata.src ?? kTransparentImage;
                      title = currentMetadata.title;
                      artist = currentMetadata.artist;
                      duration = formatTime(
                        totalSeconds: currentMetadata.duration,
                      );
                    } else {
                      src = kTransparentImage;
                      title = "ZeroBit Player";
                      artist = "39";
                      duration = "--:--";
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Hero(
                          tag: 'playingCover',
                          child: ClipRRect(
                          borderRadius: _coverBorderRadius,
                          child: FadeInImage(
                            placeholder: MemoryImage(kTransparentImage),
                            image: ResizeImage(
                              MemoryImage(src),
                              width: _coverRenderSize,
                              height: _coverRenderSize,
                            ),
                            height: _coverSize,
                            width: _coverSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(
                                title,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: generalTextStyle(
                                  ctx: context,
                                  size: 'md',
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                artist,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: timeTextStyle,
                              ),
                            ],
                          ),
                        ),
                        Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                audioCtrlWidget.volumeSet,
                                audioCtrlWidget.skipBack,
                                audioCtrlWidget.skipForward,
                                audioCtrlWidget.changeMode,
                              ],
                            )
                            .animate(target: _isBarHover.value ? 1 : 0)
                            .fade(duration: 150.ms),
                        audioCtrlWidget.toggle,

                        Obx(
                          ()=>Text(
                            "${formatTime(totalSeconds: _audioController.currentSec.value)} / $duration",
                            style: timeTextStyle,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
