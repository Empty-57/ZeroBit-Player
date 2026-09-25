import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:zerobit_player/components/lyric/blurable_text.dart';
import 'package:zerobit_player/components/lyric/lyric_arg_constants.dart';
import 'package:zerobit_player/components/lyric/word_render.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

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
      child: BlurableText(text, textAlign: textAlign, blurSigma: blurSigma),
    );
  }
}

class KaraOkLyricWidget extends StatelessWidget {
  final List<WordEntry> text;
  final TextStyle style;
  final bool isCurrentLine;
  final bool isPrevLine;
  final int lrcAlignment;
  final LyricController lyricController;
  final StrutStyle strutStyle;
  final int blurSigma;

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
  });

  Widget _createPlainText() {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i].lyricWord);
    }

    return BlurableText(
      buffer.toString(),
      style: style,
      strutStyle: strutStyle,
      textAlign: LyricConstants.lrcTextAlign[lrcAlignment],
      blurSigma: blurSigma,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isCurrentLine && !isPrevLine) {
      return _createPlainText();
    }

    final gradientColors = <Color>[
      style.color!.withValues(alpha: LyricConstants.highLightAlpha),
      style.color!.withValues(alpha: LyricConstants.highLightAlpha),
      style.color!.withValues(alpha: LyricConstants.currentAlpha),
    ];

    final TextAlign textAlign = LyricConstants.lrcTextAlign[lrcAlignment];

    return ValueListenableBuilder<int>(
      valueListenable: lyricController.currentWordIndexNotifier,
      builder: (_, currentIndex, _) {
        // 以下只会在“当前行”和“刚唱完的上一行”执行，保证了动画平滑且不被打断
        return Text.rich(
          TextSpan(
            children: List.generate(text.length, (wordIndex) {
              final entry = text[wordIndex];
              final word = entry.lyricWord;
              final double dura = entry.duration;

              final bool isFloating =
                  isCurrentLine && wordIndex <= currentIndex;
              final floatingDuration = dura * (1000 * 1.8) + 50;
              final floatingDelay = dura * (1000 * 0.2);

              Widget wordWidget;

              if (isCurrentLine && wordIndex == currentIndex) {
                gradientColors[2] = style.color!.withValues(
                  alpha: wordIndex == 0
                      ? LyricConstants.currentAlpha - 0.15
                      : LyricConstants.currentAlpha,
                ); // 视觉欺骗，防止颜色突变

                final translateGradientScale = dura >= 1.0
                    ? 3.0
                    : 2.0; // 动态改变渐变区宽度
                double ripplesScaleMax = LyricConstants.ripplesScaleMin;
                double glowAlphaMax = LyricConstants.glowAlphaMin;

                if (dura >= LyricConstants.rippleThreshold) {
                  // 将词的持续时间 dura 在 [LyricConstants.rippleThreshold, 3] 区间内归一化为 [0.0, 1.0] 的比例值
                  // 时间参数，根据dura的大小影响缩放和辉光效果的最大值
                  final effectRatio =
                      (((dura - LyricConstants.rippleThreshold) /
                              (3 -
                                  LyricConstants.rippleThreshold))) // 最大观测长度 3s
                          .clamp(0.0, 1.0);
                  ripplesScaleMax +=
                      LyricConstants.ripplesScaleExtra * effectRatio;
                  glowAlphaMax += LyricConstants.glowAlphaExtra * effectRatio;
                }

                // 正在唱的字
                wordWidget = ValueListenableBuilder<double>(
                  valueListenable: lyricController.wordProgress,
                  builder: (context, progress, child) {
                    return HighlightedWord(
                      text: word,
                      progress: progress,
                      style: style,
                      strutStyle: strutStyle,
                      gradientColors: gradientColors,
                      duartion: dura,
                      ripplesScaleMax: ripplesScaleMax,
                      glowAlphaMax: glowAlphaMax,
                      translateGradientScale: translateGradientScale,
                    );
                  },
                );
              } else {
                // 目标颜色
                Color targetColor;
                Color beginColor;

                if (isCurrentLine) {
                  if (wordIndex < currentIndex) {
                    targetColor = style.color!.withValues(
                      alpha: LyricConstants.highLightAlpha,
                    );
                    beginColor = targetColor; // 已经唱过的字，保持高亮
                  } else {
                    targetColor = style.color!.withValues(
                      alpha: LyricConstants.currentAlpha,
                    );
                    beginColor = style.color!.withValues(
                      alpha: LyricConstants.notPlayedDarkAlpha,
                    ); // 还没唱到的字，从暗色过渡到稍微高亮的颜色
                  }
                } else {
                  targetColor = style.color!;
                  beginColor = style.color!.withValues(
                    alpha: LyricConstants.highLightAlpha,
                  ); // 刚唱完的上一行，最终褪回普通颜色
                }

                wordWidget = TweenAnimationBuilder<Color?>(
                  key: ValueKey('word_$wordIndex'),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  tween: ColorTween(begin: beginColor, end: targetColor),
                  builder: (_, color, __) {
                    return BlurableText(
                      word,
                      style: style.copyWith(color: color),
                      strutStyle: strutStyle,
                      blurSigma: blurSigma,
                    );
                  },
                );

                // 这套方案的问题： 在歌词换行的时候最后一个词偶尔会直接跳变为透明色 但性能较优
                // wordWidget = AnimatedDefaultTextStyle(
                //   key: ValueKey('word_$wordIndex'),
                //   duration: const Duration(milliseconds: 600),
                //   curve: Curves.easeInOut,
                //   style: style.copyWith(color: targetColor),
                //   child: Text(word, strutStyle: strutStyle),
                // );
              }

              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _SyllableFloatWidget(
                  isFloating: isFloating,
                  duration: isFloating ? floatingDuration : 600,
                  delay: isFloating ? floatingDelay : 0,
                  child: wordWidget,
                ),
              );
            }),
          ),
          textAlign: textAlign,
          strutStyle: strutStyle,
          softWrap: true,
        );
      },
    );
  }
}

class _SyllableFloatWidget extends StatefulWidget {
  final bool isFloating;
  final double duration;
  final double delay;
  final Widget child;

  const _SyllableFloatWidget({
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
  late CurvedAnimation _curvedAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration.round()),
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.isFloating ? Curves.easeInOut : Curves.easeInCubic,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_SyllableFloatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFloating != widget.isFloating ||
        oldWidget.duration != widget.duration ||
        oldWidget.delay != widget.delay) {
      _controller.duration = Duration(milliseconds: widget.duration.round());

      _curvedAnimation.dispose();
      _curvedAnimation = CurvedAnimation(
        parent: _controller,
        curve: widget.isFloating ? Curves.easeInOut : Curves.easeInCubic,
      );

      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _timer?.cancel();
    final double target = widget.isFloating ? 1.0 : 0.0;

    if (widget.delay > 0 && widget.isFloating) {
      _timer = Timer(Duration(milliseconds: widget.delay.round()), () {
        if (mounted) {
          _controller.animateTo(target);
        }
      });
    } else {
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curvedAnimation,
      builder: (context, child) {
        final double dy = ui.lerpDouble(
          0.0,
          LyricConstants.floatingY,
          _curvedAnimation.value,
        )!;
        return Transform.translate(
          offset: Offset(0, dy),
          filterQuality: FilterQuality.low,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
