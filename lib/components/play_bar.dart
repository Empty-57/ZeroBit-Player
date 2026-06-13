import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/custom_widgets/diamond_silder_thumb.dart';
import 'package:zerobit_player/custom_widgets/rect_value_indicator.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/general_style.dart';

import '../custom_widgets/scroll_text.dart';
import 'audio_ctrl_btn.dart';

const double _barWidth = 700;
const double _barHeight = 64;
const double _barWidthHalf = 350;

const double _bottom = 4;
const double _navigationWidth = 260;
const double _navigationWidthSmall = 84;
const double _resViewThresholds = 1100;

const double _radius = 6;

const double _coverSize = 48.0;
final double _dpr = PlatformDispatcher.instance.views.first.devicePixelRatio;

const double _ctrlBtnMinSize = 40.0;

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));

class _ProgressBar extends GetView<AudioController> {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final progressColor = Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.8);
    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.fill;

    return RepaintBoundary(
      child: ValueListenableBuilder(
        valueListenable: c.progress,
        builder: (_, p, _) {
          return CustomPaint(
            size: const Size(_barWidth, _barHeight),
            painter: _ProgressPainter(progress: p, fgPaint: fgPaint),
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;
  final Paint fgPaint;

  const _ProgressPainter({required this.progress, required this.fgPaint});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final progressRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
      topLeft: const Radius.circular(_radius),
      bottomLeft: const Radius.circular(_radius),
    );
    canvas.drawRRect(progressRect, fgPaint);
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) {
    // 仅在 progress 值变化时重绘
    return oldDelegate.progress != progress;
  }
}

final _isBarHover = false.obs;

class PlayBar extends GetView<AudioController> {
  const PlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audioCtrlWidget = AudioCtrlWidget(
      context: context,
      size: _ctrlBtnMinSize,
    );

    return Obx(() {
      final screenWidth = context.width;
      final rightOffset =
          (screenWidth -
                  (screenWidth > _resViewThresholds
                      ? controller.navigationIsExtend.value
                            ? _navigationWidth
                            : _navigationWidthSmall
                      : _navigationWidthSmall)) /
              2 -
          _barWidthHalf;
      return AnimatedPositioned(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        bottom: _bottom,
        right: rightOffset,
        child: ClipRRect(
          borderRadius: _coverBorderRadius,
          child: ExcludeSemantics(
            child: Column(
              children: [
                _buildSlider(context, audioCtrlWidget),
                _buildPlayBarBody(context, audioCtrlWidget),
              ],
            ),
          ),
        ),
      );
    });
  }

  // 构建 Slider 部分
  Widget _buildSlider(BuildContext context, AudioCtrlWidget audioCtrlWidget) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 1,
            showValueIndicator: ShowValueIndicator.onDrag,
            thumbShape: const DiamondSliderThumbShape(
              horizontalDiagonal: 8,
              verticalDiagonal: 16,
            ),
            activeTrackColor: Colors.transparent,
            thumbColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: Colors.transparent,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
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
              SystemMouseCursors.resizeLeftRight,
            ),
          ),
          child: Container(
            width: _barWidth + 16,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: audioCtrlWidget.seekSlide,
          ),
        ),
      ),
    );
  }

  // 构建播放条主体部分
  Widget _buildPlayBarBody(
    BuildContext context,
    AudioCtrlWidget audioCtrlWidget,
  ) {
    final timeTextStyle = generalTextStyle(
      ctx: context,
      size: 'sm',
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
    );

    final c = controller;

    return Stack(
      children: [
        // 背景容器
        Container(
          width: _barWidth,
          height: _barHeight,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            color: Theme.of(context).colorScheme.surfaceContainer,
            boxShadow: [
              BoxShadow(
                color: Colors.black38.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        // 进度条
        const _ProgressBar(),
        // 交互层
        RepaintBoundary(
          child: TextButton(
            onPressed: () => Get.toNamed(AppRoutes.playPage),
            onHover: (v) => _isBarHover.value = v,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              fixedSize: const Size(_barWidth, _barHeight),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 8,
              children: [
                _buildCoverAndInfo(context, timeTextStyle),
                _buildControlButtons(audioCtrlWidget),
                audioCtrlWidget.toggle,
                _buildTimeDisplay(c, timeTextStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollText(
    String text,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    return ScrollText(
      text: text,
      style: textStyle,
      velocity: 50.0,
      delayBefore: const Duration(milliseconds: 500),
      pauseBetween: const Duration(milliseconds: 1000),
      strutStyle: strutStyle,
    );
  }

  // 构建封面和歌曲信息
  Widget _buildCoverAndInfo(BuildContext context, TextStyle timeTextStyle) {
    final titleStyle = generalTextStyle(
      ctx: context,
      size: 'md',
      color: Theme.of(context).colorScheme.primary,
    );

    final titleStrut = StrutStyle(
      fontSize: titleStyle.fontSize,
      forceStrutHeight: true,
    );
    final subTitleStrut = StrutStyle(
      fontSize: timeTextStyle.fontSize,
      forceStrutHeight: true,
    );

    final cacheResolution = (_coverSize * _dpr).round();

    return Expanded(
      child: Row(
        spacing: 8,
        children: [
          Obx(
            () => Hero(
              tag: 'playingCover',
              child: ClipRRect(
                borderRadius: _coverBorderRadius,
                child: Image.memory(
                  controller.currentSmallCover.value,
                  key: ValueKey(controller.currentSmallCover.value.hashCode),
                  cacheWidth: cacheResolution,
                  cacheHeight: cacheResolution,
                  height: _coverSize,
                  width: _coverSize,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Obx(() {
                  final title =
                      controller.currentMetadata.value.title.isNotEmpty
                      ? controller.currentMetadata.value.title
                      : "ZeroBit Player";
                  return _isBarHover.value
                      ? _buildScrollText(title, titleStyle, titleStrut)
                      : Text(
                          title,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          strutStyle: titleStrut,
                          maxLines: 1,
                          style: titleStyle,
                          textAlign: TextAlign.left,
                        );
                }),
                Obx(() {
                  final artist =
                      controller.currentMetadata.value.artist.isNotEmpty
                      ? controller.currentMetadata.value.artist
                      : "39";
                  return _isBarHover.value
                      ? _buildScrollText(artist, timeTextStyle, subTitleStrut)
                      : Text(
                          artist,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          strutStyle: subTitleStrut,
                          maxLines: 1,
                          style: timeTextStyle,
                          textAlign: TextAlign.left,
                        );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建可显隐的控制按钮
  Widget _buildControlButtons(AudioCtrlWidget audioCtrlWidget) {
    return Obx(
      () => AnimatedOpacity(
        opacity: _isBarHover.value ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        // 即使透明，也不让它接收点击事件
        child: IgnorePointer(
          ignoring: !_isBarHover.value,
          child: Row(
            children: [
              audioCtrlWidget.volumeSet,
              audioCtrlWidget.skipBack,
              audioCtrlWidget.skipForward,
              audioCtrlWidget.changeMode,
            ],
          ),
        ),
      ),
    );
  }

  // 构建时间显示
  Widget _buildTimeDisplay(AudioController c, TextStyle timeTextStyle) {
    // 用最长的可能字符串测量宽度
    final maxText = "00:00 / 00:00";
    final tp = TextPainter(
      text: TextSpan(text: maxText, style: timeTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxWidth = tp.width + 4; // 留出余量防止误差
    tp.dispose();

    return SizedBox(
      height: _barHeight / 2,
      width: maxWidth,
      child: RepaintBoundary(
        child: Center(
          child: Obx(() {
            final duration = c.currentDuration.value > 0
                ? formatTime(totalSeconds: c.currentDuration.value)
                : "--:--";
            final currentSec = formatTime(totalSeconds: c.currentSec.value);
            return Text("$currentSec / $duration", style: timeTextStyle);
          }),
        ),
      ),
    );
  }
}
