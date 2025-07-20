import 'package:flutter/material.dart';
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

const _coverBorderRadius = BorderRadius.all(Radius.circular(6));
const int _coverRenderSize = 150;

final AudioController _audioController = Get.find<AudioController>();

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final progressColor = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8);
    final fgPaint = Paint()..color = progressColor..style = PaintingStyle.fill;

    return RepaintBoundary(
      child: Obx(()=>CustomPaint(
            size: const Size(_barWidth, _barHeight),
            painter: _ProgressPainter(
              progress: _audioController.progress.value,
              fgPaint: fgPaint,
            ),
          )),
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

class PlayBar extends StatefulWidget {
  const PlayBar({super.key});

  @override
  State<PlayBar> createState() => _PlayBarState();
}

class _PlayBarState extends State<PlayBar> {
  bool _isBarHover = false;

  @override
  Widget build(BuildContext context) {
    final audioCtrlWidget = AudioCtrlWidget(context: context, size: _ctrlBtnMinSize);

    final screenWidth = context.width;
        final rightOffset = (screenWidth - (screenWidth > resViewThresholds ? _navigationWidth : _navigationWidthSmall)) / 2 - _barWidthHalf;

    return Positioned(
          bottom: _bottom,
          right: rightOffset,
          child: ClipRRect(
            borderRadius: _coverBorderRadius,
            child: Column(
              children: [
                _buildSlider(context, audioCtrlWidget),
                _buildPlayBarBody(context, audioCtrlWidget),
              ],
            ),
          ),
        );
  }

  // 构建 Slider 部分
  Widget _buildSlider(BuildContext context, AudioCtrlWidget audioCtrlWidget) {
    return Material(
      color:Colors.transparent,
      child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 1,
        showValueIndicator: ShowValueIndicator.always,
        thumbShape: const _DiamondSliderThumbShape(horizontalDiagonal: 8, verticalDiagonal: 16),
        activeTrackColor: Colors.transparent,
        thumbColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: Colors.transparent,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
        valueIndicatorShape: const RectangularValueIndicatorShape(width: 48, height: 28, radius: 4),
        valueIndicatorTextStyle: generalTextStyle(ctx: context, size: 'sm', color: Theme.of(context).colorScheme.onPrimary),
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.resizeLeftRight),
      ),
      child: Container(
        width: _barWidth + 16,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: audioCtrlWidget.seekSlide,
      ),
    ),
    );
  }

  // 构建播放条主体部分
  Widget _buildPlayBarBody(BuildContext context, AudioCtrlWidget audioCtrlWidget) {
    final timeTextStyle = generalTextStyle(ctx: context, size: 'sm', color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6));

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
        TextButton(
          onPressed: () => Get.toNamed(AppRoutes.lrcView),
          onHover: (v) => setState(() => _isBarHover = v),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            fixedSize: const Size(_barWidth, _barHeight),
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              _buildCoverAndInfo(timeTextStyle),
              _buildControlButtons(audioCtrlWidget),
              audioCtrlWidget.toggle,
              _buildTimeDisplay(timeTextStyle),
            ],
          ),
        ),
      ],
    );
  }

  // 构建封面和歌曲信息
  Widget _buildCoverAndInfo(TextStyle timeTextStyle) {
    return Expanded(
      child: Row(
        spacing: 8,
        children: [
          Obx(() {
            final src = _audioController.currentMetadata.value.src ?? kTransparentImage;
            return Hero(
              tag: 'playingCover',
              child: ClipRRect(
                borderRadius: _coverBorderRadius,
                child: FadeInImage(
                  placeholder: MemoryImage(kTransparentImage),
                  image: ResizeImage(MemoryImage(src), width: _coverRenderSize, height: _coverRenderSize),
                  height: _coverSize,
                  width: _coverSize,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                ),
              ),
            );
          }),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Obx(() => Text(
                  _audioController.currentMetadata.value.title.isNotEmpty ? _audioController.currentMetadata.value.title : "ZeroBit Player",
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                  style: generalTextStyle(ctx: context, size: 'md', color: Theme.of(context).colorScheme.primary),
                )),
                Obx(() => Text(
                  _audioController.currentMetadata.value.artist.isNotEmpty ? _audioController.currentMetadata.value.artist : "39",
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  maxLines: 1,
                  style: timeTextStyle,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建可显隐的控制按钮
  Widget _buildControlButtons(AudioCtrlWidget audioCtrlWidget) {
    return AnimatedOpacity(
      opacity: _isBarHover ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      // 即使透明，也不让它接收点击事件
      child: IgnorePointer(
        ignoring: !_isBarHover,
        child: Row(
          children: [
            audioCtrlWidget.volumeSet,
            audioCtrlWidget.skipBack,
            audioCtrlWidget.skipForward,
            audioCtrlWidget.changeMode,
          ],
        ),
      ),
    );
  }

  // 构建时间显示
  Widget _buildTimeDisplay(TextStyle timeTextStyle) {
    return Obx(() {
      final duration = _audioController.currentMetadata.value.duration > 0
          ? formatTime(totalSeconds: _audioController.currentMetadata.value.duration)
          : "--:--";
      final currentSec = formatTime(totalSeconds: _audioController.currentSec.value);
      return Text("$currentSec / $duration", style: timeTextStyle);
    });
  }
}
