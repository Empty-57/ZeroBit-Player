import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/play_bar_constant.dart';
import 'package:zerobit_player/components/side_bar.dart';
import 'package:zerobit_player/components/side_bar_constant.dart';
import 'package:zerobit_player/components/widget/app_interaction_widget.dart';
import 'package:zerobit_player/components/widget/audio_ctrl_btn.dart';
import 'package:zerobit_player/components/widget/covers.dart';
import 'package:zerobit_player/components/widget/diamond_slider_thumb.dart';
import 'package:zerobit_player/components/widget/rect_value_indicator.dart';
import 'package:zerobit_player/components/widget/scroll_text.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/field/app_routes.dart';
import 'package:zerobit_player/tools/func/format_time.dart';
import 'package:zerobit_player/tools/func/style_manager.dart';

class PlayBar extends StatelessWidget {
  const PlayBar({super.key});

  /// 播放栏在「内容区」里水平居中。
  /// 内容区 = 窗口宽度减掉侧栏占位
  double _rightOffset(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final expanded =
        screenWidth > AppBreakpoint.wide &&
        SidebarNavState.navigationIsExtend.value;

    final sideBar = SideBarSpec.footprintWidth(expanded: expanded);
    return (screenWidth - sideBar) / 2 - PlayBarSpec.halfWidth;
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) => AnimatedPositioned(
        duration: PlayBarSpec.repositionDuration,
        curve: AppCurve.standard,
        bottom: PlayBarSpec.bottomInset,
        right: _rightOffset(context),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [_SeekSlider(), _PlayBarBody()],
        ),
      ),
    );
  }
}

/// 顶部的进度滑块
class _SeekSlider extends StatelessWidget {
  const _SeekSlider();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: PlayBarSpec.sliderTrackHeight,
            showValueIndicator: ShowValueIndicator.onDrag,
            thumbShape: const DiamondSliderThumbShape(
              horizontalDiagonal: PlayBarSpec.thumbHorizontalDiagonal,
              verticalDiagonal: PlayBarSpec.thumbVerticalDiagonal,
            ),
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: colorScheme.primary,
            overlayShape: SliderComponentShape.noOverlay,
            valueIndicatorShape: const RectangularValueIndicatorShape(
              width: PlayBarSpec.valueIndicatorWidth,
              height: PlayBarSpec.valueIndicatorHeight,
              radius: PlayBarSpec.valueIndicatorRadius,
            ),
            valueIndicatorTextStyle: context.createTextStyle(
              size: AppFontSize.sm,
              color: colorScheme.onPrimary,
              tabularFigures: true,
            ),
            mouseCursor: const WidgetStatePropertyAll(
              SystemMouseCursors.resizeLeftRight,
            ),
          ),
          child: SizedBox(
            width: PlayBarSpec.totalWidth,
            child: AudioCtrlWidget(
              context: context,
              size: PlayBarSpec.ctrlButtonSize,
            ).seekSlide,
          ),
        ),
      ),
    );
  }
}

/// 播放栏主体
class _PlayBarBody extends StatelessWidget {
  const _PlayBarBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final audioCtrl = AudioCtrlWidget(
      context: context,
      size: PlayBarSpec.ctrlButtonSize,
      color: colorScheme.primary,
    );

    return HoverBuilder(
      onPressed: () => context.push(AppRoutes.playPage),
      builder: (context, hovered) => SizedBox(
        width: PlayBarSpec.bodyWidth,
        height: PlayBarSpec.bodyHeight,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: PlayBarSpec.radiusAll,
                color: colorScheme.surfaceContainer,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: PlayBarSpec.shadowAlpha,
                    ),
                    spreadRadius: PlayBarSpec.shadowSpread,
                    blurRadius: PlayBarSpec.shadowBlur,
                    offset: PlayBarSpec.shadowOffset,
                  ),
                ],
              ),
              child: const SizedBox.expand(),
            ),
            const _ProgressFill(),
            if (hovered)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: PlayBarSpec.radiusAll,
                  color: colorScheme.primary.withValues(alpha: AppAlpha.hover),
                ),
                child: const SizedBox.expand(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: AppSpacing.md,
                children: [
                  _CoverAndInfo(hovered: hovered),
                  _HoverControls(audioCtrl: audioCtrl, hovered: hovered),
                  audioCtrl.toggle,
                  const _TimeDisplay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已播放区域的填充
class _ProgressFill extends StatelessWidget {
  const _ProgressFill();

  @override
  Widget build(BuildContext context) {
    final fgPaint = Paint()
      ..color = Theme.of(context).colorScheme.secondaryContainer.withValues(
        alpha: PlayBarSpec.progressAlpha,
      )
      ..style = PaintingStyle.fill;

    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: AudioController.instance.progress,
        builder: (_, progress, _) => CustomPaint(
          size: const Size(PlayBarSpec.bodyWidth, PlayBarSpec.bodyHeight),
          painter: _ProgressPainter(progress: progress, fgPaint: fgPaint),
        ),
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
      topLeft: PlayBarSpec.radiusAll.topLeft,
      bottomLeft: PlayBarSpec.radiusAll.bottomLeft,
    );
    canvas.drawRRect(progressRect, fgPaint);
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 封面与曲目信息
class _CoverAndInfo extends StatelessWidget {
  final bool hovered;

  const _CoverAndInfo({required this.hovered});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = AudioController.instance;

    final titleStyle = context.createTextStyle(
      size: AppFontSize.md,
      color: colorScheme.primary,
    );
    final subStyle = context.createTextStyle(
      size: AppFontSize.sm,
      color: colorScheme.primary.withValues(alpha: AppAlpha.textTertiary),
    );

    return Expanded(
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Hero(
            tag: 'playingCover',
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            child: ClipRRect(
              borderRadius: PlayBarSpec.radiusAll,
              child: SignalBuilder(
                builder: (_) => LoadU8Cover(
                  data: controller.currentSmallCover.value,
                  size: AppSize.coverSm,
                  evictOnDispose: false,
                ),
              ),
            ),
          ),
          Expanded(
            child: SignalBuilder(
              builder: (_) {
                final metadata = controller.currentMetadata.value;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    _InfoLine(
                      text: metadata.title.isNotEmpty
                          ? metadata.title
                          : 'ZeroBit Player',
                      style: titleStyle,
                      scrolling: hovered,
                    ),
                    _InfoLine(
                      text: metadata.artist.isNotEmpty ? metadata.artist : '39',
                      style: subStyle,
                      scrolling: hovered,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行曲目信息。静止时截断，悬停时滚动
class _InfoLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool scrolling;

  const _InfoLine({
    required this.text,
    required this.style,
    required this.scrolling,
  });

  @override
  Widget build(BuildContext context) {
    final strutStyle = StrutStyle(
      fontSize: style.fontSize,
      forceStrutHeight: true,
    );

    if (scrolling) {
      return ScrollText(
        text: text,
        style: style,
        velocity: PlayBarSpec.scrollVelocity,
        delayBefore: PlayBarSpec.scrollDelayBefore,
        pauseBetween: PlayBarSpec.scrollPauseBetween,
        strutStyle: strutStyle,
      );
    }

    return Text(
      text,
      style: style,
      strutStyle: strutStyle,
      textAlign: TextAlign.left,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.fade,
    );
  }
}

/// 悬停才出现的控制键
class _HoverControls extends StatelessWidget {
  final AudioCtrlWidget audioCtrl;
  final bool hovered;

  const _HoverControls({required this.audioCtrl, required this.hovered});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: hovered ? 1.0 : 0.0,
      duration: AppDuration.normal,
      curve: AppCurve.standard,
      child: IgnorePointer(
        ignoring: !hovered,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            audioCtrl.volumeSet,
            audioCtrl.skipBack,
            audioCtrl.skipForward,
            audioCtrl.changeMode,
          ],
        ),
      ),
    );
  }
}

/// 播放进度读数
class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay();

  @override
  Widget build(BuildContext context) {
    final controller = AudioController.instance;
    final style = context.createTextStyle(
      size: AppFontSize.sm,
      color: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: AppAlpha.textTertiary),
      tabularFigures: true,
    );

    return SizedBox(
      width: PlayBarSpec.timeWidth,
      child: RepaintBoundary(
        child: Center(
          child: SignalBuilder(
            builder: (_) {
              final total = controller.currentDuration.value > 0
                  ? formatTime(totalSeconds: controller.currentDuration.value)
                  : '--:--';
              final current = formatTime(
                totalSeconds: controller.currentSec.value,
              );
              return Text(
                '$current / $total',
                style: style,
                maxLines: 1,
                softWrap: false,
              );
            },
          ),
        ),
      ),
    );
  }
}
