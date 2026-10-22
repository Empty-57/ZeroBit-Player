import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zerobit_player/features/lyrics/controller/lyric_ctrl.dart';
import 'package:zerobit_player/features/lyrics/widgets/blur_widget.dart';
import 'package:zerobit_player/features/lyrics/widgets/lyric_arg_constants.dart';
import 'package:zerobit_player/features/lyrics/widgets/word_render.dart';

import '../models/lyric_model.dart';

class LrcLyricWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool isCurrent;
  final TextAlign textAlign;
  final double highLightAlpha;
  final int blurSigma;

  const LrcLyricWidget({
    super.key,
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.textAlign,
    this.highLightAlpha = LyricConstants.highLightAlpha,
    this.blurSigma = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 600),
      style: style.copyWith(
        color: isCurrent
            ? style.color?.withValues(alpha: highLightAlpha)
            : style.color,
      ),
      child: BlurText(text, textAlign: textAlign, blurSigma: blurSigma),
    );
  }
}

/// 单个音节在当前时刻的渲染状态
enum _WordPhase {
  /// 当前行，正在唱的字
  singing,

  /// 当前行，已经唱过的字
  sung,

  /// 当前行，还没唱到的字
  pending,

  /// 上一行
  previous,
}

/// 渲染单个音节
class _WordSpan extends StatelessWidget {
  const _WordSpan({
    required this.entry,
    required this.wordIndex,
    required this.phase,
    required this.gradientColors,
    required this.style,
    required this.strutStyle,
    required this.blurSigma,
    required this.wordProgress,
  });

  final WordEntry entry;
  final int wordIndex;
  final _WordPhase phase;
  final List<Color> gradientColors;
  final TextStyle style;
  final StrutStyle strutStyle;
  final int blurSigma;
  final ValueListenable<double> wordProgress;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      _WordPhase.singing => _buildSinging(),
      _WordPhase.sung => _buildFading(
        begin: style.color!.withValues(alpha: LyricConstants.highLightAlpha),
        end: style.color!.withValues(alpha: LyricConstants.highLightAlpha),
      ),
      _WordPhase.pending => _buildFading(
        begin: style.color!.withValues(
          alpha: LyricConstants.notPlayedDarkAlpha,
        ),
        end: style.color!.withValues(alpha: LyricConstants.currentAlpha),
      ),
      _WordPhase.previous => _buildFading(
        begin: style.color!.withValues(alpha: LyricConstants.highLightAlpha),
        end: style.color!,
      ),
    };
  }

  /// 正在唱的字
  Widget _buildSinging() {
    final double dura = entry.duration;

    final List<Color> currentGradient = [
      gradientColors[0],
      gradientColors[1],
      style.color!.withValues(
        alpha: wordIndex == 0
            ? LyricConstants.currentAlpha - 0.15
            : LyricConstants.currentAlpha,
      ), // 视觉欺骗，防止颜色突变
    ];

    final translateGradientScale = dura >= 1.0 ? 3.0 : 2.0;

    double ripplesScaleMax = LyricConstants.ripplesScaleMin;
    double glowAlphaMax = LyricConstants.glowAlphaMin;

    if (dura >= LyricConstants.rippleThreshold) {
      // 将词的持续时间 dura 在 [LyricConstants.rippleThreshold, LyricConstants.rippleThresholdWindow] 区间内归一化为 [0.0, 1.0] 的比例值
      // 时间参数，根据dura的大小影响缩放和辉光效果的最大值
      final effectRatio =
          ((dura - LyricConstants.rippleThreshold) /
                  (LyricConstants.rippleThresholdWindow -
                      LyricConstants.rippleThreshold))
              .clamp(0.0, 1.0);
      ripplesScaleMax += LyricConstants.ripplesScaleExtra * effectRatio;
      glowAlphaMax += LyricConstants.glowAlphaExtra * effectRatio;
    }

    return HighlightedWord(
      text: entry.lyricWord,
      progressListenable: wordProgress,
      style: style,
      strutStyle: strutStyle,
      gradientColors: currentGradient,
      duration: dura,
      ripplesScaleMax: ripplesScaleMax,
      glowAlphaMax: glowAlphaMax,
      translateGradientScale: translateGradientScale,
    );
  }

  /// 非正在唱的字
  Widget _buildFading({required Color begin, required Color end}) {
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      tween: ColorTween(begin: begin, end: end),
      builder: (_, color, _) {
        return BlurText(
          entry.lyricWord,
          style: style.copyWith(color: color),
          strutStyle: strutStyle,
          blurSigma: blurSigma,
        );
      },
    );

    // 这套方案的问题：在歌词换行的时候最后一个词偶尔会直接跳变为透明色 但性能较优
    // return AnimatedDefaultTextStyle(
    //   key: ValueKey('word_$wordIndex'),
    //   duration: const Duration(milliseconds: 600),
    //   curve: Curves.easeInOut,
    //   style: style.copyWith(color: end),
    //   child: BlurText(
    //     entry.lyricWord,
    //     strutStyle: strutStyle,
    //     blurSigma: blurSigma,
    //   ),
    // );
  }
}

class KaraOkLyricWidget extends StatelessWidget {
  final List<WordEntry> text;
  final TextStyle style;
  final bool isCurrentLine;
  final bool isPrevLine;
  final bool showKana;
  final int lrcAlignment;
  final LyricController lyricController;
  final StrutStyle strutStyle;
  final int blurSigma;
  final TextStyle furiganaLyricStyle;

  const KaraOkLyricWidget({
    super.key,
    required this.text,
    required this.style,
    required this.isCurrentLine,
    required this.lrcAlignment,
    required this.lyricController,
    required this.strutStyle,
    required this.isPrevLine,
    required this.blurSigma,
    required this.furiganaLyricStyle,
    required this.showKana,
  });

  /// 构建静态行（非当前行且非上一行）
  Widget _buildStaticLine() {
    return _buildFuriganaLine((wordIndex, entry) {
      return BlurText(
        entry.lyricWord,
        style: style,
        strutStyle: strutStyle,
        blurSigma: blurSigma,
      );
    });
  }

  /// 构建注音行
  Widget _buildFuriganaLine(Widget Function(int, WordEntry) build) {
    final List<Widget> lineChildren = [];
    int i = 0;

    while (i < text.length) {
      final entry = text[i];

      final groupLen =
          (entry.furigana.isNotEmpty && entry.furiganaGroupLength > 1)
          ? entry.furiganaGroupLength
          : 1;
      final end = (i + groupLen).clamp(0, text.length);

      final words = [for (int j = i; j < end; j++) build(j, text[j])];
      final wordWidget = words.length == 1
          ? words.first
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: words,
            );

      lineChildren.add(
        entry.furigana.isEmpty
            ? wordWidget
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    clipBehavior: .none,
                    child: showKana
                        ? BlurText(
                            entry.furigana,
                            style: furiganaLyricStyle,
                            textAlign: TextAlign.center,
                            blurSigma: blurSigma,
                          )
                        : const SizedBox.shrink(),
                  ),
                  wordWidget,
                ],
              ),
      );

      i = end;
    }

    return Wrap(
      alignment: LyricConstants.lrcWrapAlign[lrcAlignment],
      crossAxisAlignment: WrapCrossAlignment.end,
      children: lineChildren,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isCurrentLine && !isPrevLine) {
      return _buildStaticLine();
    }

    final gradientColors = <Color>[
      style.color!.withValues(alpha: LyricConstants.highLightAlpha),
      style.color!.withValues(alpha: LyricConstants.highLightAlpha),
      style.color!.withValues(alpha: LyricConstants.currentAlpha),
    ];

    return ValueListenableBuilder<int>(
      valueListenable: lyricController.currentWordIndexNotifier,
      builder: (_, currentIndex, _) {
        // 以下只会在“当前行”和“刚唱完的上一行”执行，保证了动画平滑且不被打断
        return _buildFuriganaLine((wordIndex, entry) {
          final double dura = entry.duration;
          final bool isFloating = isCurrentLine && wordIndex <= currentIndex;
          final floatingDuration = dura * (1000 * 1.8) + 50;
          final floatingDelay = dura * (1000 * 0.2);

          return _SyllableFloatWidget(
            isFloating: isFloating,
            duration: isFloating ? floatingDuration : 600,
            delay: isFloating ? floatingDelay : 0,
            child: _WordSpan(
              entry: entry,
              wordIndex: wordIndex,
              phase: _phaseOf(wordIndex, currentIndex),
              gradientColors: gradientColors,
              style: style,
              strutStyle: strutStyle,
              blurSigma: blurSigma,
              wordProgress: lyricController.wordProgress,
            ),
          );
        });
      },
    );
  }

  _WordPhase _phaseOf(int wordIndex, int currentIndex) {
    if (!isCurrentLine) return _WordPhase.previous;
    if (wordIndex < currentIndex) return _WordPhase.sung;
    if (wordIndex == currentIndex) return _WordPhase.singing;
    return _WordPhase.pending;
  }
}

class _SyllableFloatWidget extends StatefulWidget {
  final bool isFloating;
  final double duration;
  final double delay;
  final Widget child;

  const _SyllableFloatWidget({
    super.key,
    required this.isFloating,
    required this.duration,
    required this.delay,
    required this.child,
  });

  @override
  State<_SyllableFloatWidget> createState() => _SyllableFloatWidgetState();
}

class _SyllableFloatWidgetState extends State<_SyllableFloatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_SyllableFloatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFloating != widget.isFloating ||
        oldWidget.duration != widget.duration ||
        oldWidget.delay != widget.delay) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _timer?.cancel();
    _timer = null;
    _controller.duration = Duration(milliseconds: widget.duration.round());
    final target = widget.isFloating ? 1.0 : 0.0;
    if (widget.delay > 0 && widget.isFloating) {
      _controller.stop();
      _timer = Timer(Duration(milliseconds: widget.delay.round()), () {
        _timer = null;
        if (mounted) _controller.animateTo(target);
      });
    } else {
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = ui.lerpDouble(
          0,
          LyricConstants.floatingY,
          _controller.value,
        )!;
        return Transform.translate(
          filterQuality: .low,
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
