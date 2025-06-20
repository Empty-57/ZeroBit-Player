import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:zerobit_player/tools/format_time.dart';
import 'package:zerobit_player/tools/general_style.dart';
import 'package:zerobit_player/tools/func_extension.dart';

import '../HIveCtrl/models/music_cahce_model.dart';
import '../getxController/Audio_ctrl.dart';
import '../getxController/setting_ctrl.dart';

const double _barWidth = 700;
const double _barHeight = 64;
const double _barWidthHalf = 350;

const double _bottom = 12;
const double _navigationWidth = 260;

const double _radius = 6;

const double _coverSize = 48.0;

const double _ctrlBtnMinSize = 40.0;

final _isBarHover = false.obs;

const _playModeIcons = [
  PhosphorIconsFill.repeatOnce,
  PhosphorIconsFill.repeat,
  PhosphorIconsFill.shuffleSimple,
];

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
final double _dpr = Get.mediaQuery.devicePixelRatio;
final int _coverRenderSize = (_coverSize * _dpr).ceil();

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
    final progressColor=Theme.of(context,).colorScheme.secondaryContainer.withValues(alpha: 0.8);

    return RepaintBoundary(
      child: Obx(() {
        return CustomPaint(
          willChange: true,
          size: Size(_barWidth, _barHeight),
          painter: _ProgressPainter(
            progress: _audioController.progress.value,
            color: progressColor,
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
  _ProgressPainter({required this.progress, required this.color}): fgPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

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

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {

    final timeTextStyle=generalTextStyle(ctx: context,size: 'sm',color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6));

    return Positioned(
      bottom: _bottom,
      right: (context.width - _navigationWidth) / 2 - _barWidthHalf,
      child: ClipRRect(
        borderRadius: _coverBorderRadius,
        child: Stack(
          children: [
            Container(
              width: _barWidth,
              height: _barHeight,
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
              onPressed: () {},
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
                    _audioController.cacheItems.isNotEmpty&&_audioController.currentIndex.value<_audioController.cacheItems.length) {
                  final currentMetadata =
                      _audioController.cacheItems[_audioController
                          .currentIndex
                          .value];
                  src = currentMetadata.src ?? kTransparentImage;
                  title = currentMetadata.title;
                  artist = currentMetadata.artist;

                  audioState = _audioController.currentState.value;

                  duration= formatTime(totalSeconds: currentMetadata.duration);
                } else {
                  src = kTransparentImage;
                  title = "ZeroBit Player";
                  artist = "39";
                  audioState = AudioState.stop;
                  duration= "--:--";
                }
                debugPrint("upup");

                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8,
                  children: [
                    ClipRRect(
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
                                      (_settingController.volume.value * 100)
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
                                        value: _settingController.volume.value,
                                        onChanged: (v) {
                                          _audioController.audioSetVolume(
                                            vol: v,
                                          );
                                          _settingController.volume.value = v;
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
                              fn: () async {
                                await _audioController.audioToPrevious();
                              }.futureDebounce(ms: 300),
                            ),
                            _CtrlBtn(
                              tooltip: "下一首",
                              icon: PhosphorIconsFill.skipForward,
                              fn: () async {
                                await _audioController.audioToNext();
                              }.futureDebounce(ms: 300),
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
                      tooltip: audioState == AudioState.playing ? "暂停" : "播放",
                      icon:
                          audioState == AudioState.playing
                              ? PhosphorIconsFill.pause
                              : PhosphorIconsFill.play,
                      fn: () {
                        _audioController.audioToggle();
                      },
                    ),

                    Obx(()=>Text(
                            "${formatTime(totalSeconds: _audioController.currentMs100.value)} / $duration",
                          style: timeTextStyle,
                        )
                    ),

                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
