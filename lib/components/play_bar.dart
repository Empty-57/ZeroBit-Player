import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/format_time.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';

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

const _playModeIcons = [
  PhosphorIconsFill.repeatOnce,
  PhosphorIconsFill.repeat,
  PhosphorIconsFill.shuffleSimple,
];

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverRenderSize = 150;

final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();

class _CtrlBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? fn;

  const _CtrlBtn({required this.tooltip, required this.icon, required this.fn});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: () {
          if (fn != null) {
            fn!();
          }
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(_ctrlBtnMinSize, _ctrlBtnMinSize),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: Icon(icon, size: getIconSize(size: 'lg')),
      ),
    );
  }
}

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

class _RectangularValueIndicatorShape extends SliderComponentShape {
  final double width, height, radius;
  const _RectangularValueIndicatorShape({
    this.width = 40,
    this.height = 24,
    this.radius = 4,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

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
    final canvas = context.canvas;
    final paint =
        Paint()
          ..color = sliderTheme.valueIndicatorColor!
          ..style = PaintingStyle.fill;

    // 先画一个圆角矩形
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, -height), // 往上偏移一点
        width: width,
        height: height,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, paint);

    // 然后把文字画上去
    final tp = labelPainter;
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - height - tp.height / 2),
    );
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
                  valueIndicatorShape: _RectangularValueIndicatorShape(
                    width: 48,
                    height: 28,
                    radius: 4,
                  ),
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.resizeLeftRight),
                ),
                child: Obx(() {
                  late final double duration;
                  if (_audioController.currentIndex.value != -1 &&
                      _audioController.playListCacheItems.isNotEmpty &&
                      _audioController.currentIndex.value <
                          _audioController.playListCacheItems.length) {
                    final currentMetadata =
                        _audioController.playListCacheItems[_audioController
                            .currentIndex
                            .value];

                    duration = currentMetadata.duration;
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
                        label: formatTime(
                          totalSeconds: _seekDraggingValue.value,
                        ),
                        value:
                            _isSeekBarDragging.value
                                ? _seekDraggingValue.value
                                : _audioController.currentMs100.value,
                        onChangeStart: (v) {
                          _isSeekBarDragging.value = true;
                          _seekDraggingValue.value = v;
                        },
                        onChanged: (v) {
                          _seekDraggingValue.value = v;
                        },
                        onChangeEnd: (v) {
                          _isSeekBarDragging.value = false;
                          _audioController.currentMs100.value = v;
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
                    late final AudioState audioState;
                    late final String duration;

                    if (_audioController.currentIndex.value != -1 &&
                        _audioController.playListCacheItems.isNotEmpty &&
                        _audioController.currentIndex.value <
                            _audioController.playListCacheItems.length) {
                      final currentMetadata =
                          _audioController.playListCacheItems[_audioController
                              .currentIndex
                              .value];
                      src = currentMetadata.src ?? kTransparentImage;
                      title = currentMetadata.title;
                      artist = currentMetadata.artist;

                      audioState = _audioController.currentState.value;

                      duration = formatTime(
                        totalSeconds: currentMetadata.duration,
                      );
                    } else {
                      src = kTransparentImage;
                      title = "ZeroBit Player";
                      artist = "39";
                      audioState = AudioState.stop;
                      duration = "--:--";
                    }
                    debugPrint("upup");

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
                                MenuAnchor(
                                  menuChildren: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Text(
                                          (_settingController.volume.value *
                                                  100)
                                              .round()
                                              .toString(),
                                          style: generalTextStyle(
                                            ctx: context,
                                            size: 'md',
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        RotatedBox(
                                          quarterTurns: 3,
                                          child: Slider(
                                            min: 0.0,
                                            max: 1.0,
                                            value:
                                                _settingController.volume.value,
                                            onChanged: (v) {
                                              _audioController.audioSetVolume(
                                                vol: v,
                                              );
                                              _settingController.volume.value =
                                                  v;
                                            },
                                            onChangeEnd: (v) {
                                              _settingController.putCache();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  style: MenuStyle(
                                    padding: WidgetStatePropertyAll(
                                      const EdgeInsets.only(top: 16),
                                    ),
                                  ),
                                  builder: (
                                    _,
                                    MenuController controller,
                                    Widget? child,
                                  ) {
                                    return _CtrlBtn(
                                      tooltip: "音量",
                                      icon: PhosphorIconsFill.speakerHigh,
                                      fn: () {
                                        if (controller.isOpen) {
                                          controller.close();
                                        } else {
                                          controller.open();
                                        }
                                      },
                                    );
                                  },
                                ),
                                _CtrlBtn(
                                  tooltip: "上一首",
                                  icon: PhosphorIconsFill.skipBack,
                                  fn: () async{
                                    await _audioController.audioToPrevious();
                                  }.futureDebounce(ms: 300),
                                ),
                                _CtrlBtn(
                                  tooltip: "下一首",
                                  icon: PhosphorIconsFill.skipForward,
                                  fn: () {
                                    _audioController.audioToNext();
                                  },
                                ),
                                _CtrlBtn(
                                  tooltip:
                                      _settingController
                                          .playModeMap[_settingController
                                          .playMode
                                          .value] ??
                                      "单曲循环",
                                  icon:
                                      _playModeIcons[_settingController
                                          .playMode
                                          .value],
                                  fn: () {
                                    _audioController.changePlayMode();
                                  },
                                ),
                              ],
                            )
                            .animate(target: _isBarHover.value ? 1 : 0)
                            .fade(duration: 150.ms),
                        _CtrlBtn(
                          tooltip:
                              audioState == AudioState.playing ? "暂停" : "播放",
                          icon:
                              audioState == AudioState.playing
                                  ? PhosphorIconsFill.pause
                                  : PhosphorIconsFill.play,
                          fn: () {
                            _audioController.audioToggle();
                          },
                        ),

                        Obx(
                          () => Text(
                            "${formatTime(totalSeconds: _audioController.currentMs100.value)} / $duration",
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
