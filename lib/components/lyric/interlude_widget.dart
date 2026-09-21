import 'package:flutter/material.dart';

import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/lyric/lyric_arg_constants.dart';
import 'package:zerobit_player/components/lyric/word_render.dart';

import 'package:zerobit_player/controller/lyric_ctrl.dart';

class _InterludeTransition extends StatefulWidget {
  final Animation<double> animation;
  final Alignment scaleAlignment;
  final Widget child;

  const _InterludeTransition({
    required this.animation,
    required this.scaleAlignment,
    required this.child,
  });

  @override
  State<_InterludeTransition> createState() => _InterludeTransitionState();
}

class _InterludeTransitionState extends State<_InterludeTransition> {
  late CurvedAnimation _sizeAnimation;
  late CurvedAnimation _fadeAnimation;
  late CurvedAnimation _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void didUpdateWidget(_InterludeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _disposeAnimations();
      _initAnimations();
    }
  }

  void _initAnimations() {
    _sizeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scaleAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
  }

  void _disposeAnimations() {
    _sizeAnimation.dispose();
    _fadeAnimation.dispose();
    _scaleAnimation.dispose();
  }

  @override
  void dispose() {
    _disposeAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: Axis.vertical,
      sizeFactor: _sizeAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.scaleAlignment,
          child: widget.child,
        ),
      ),
    );
  }
}

class InterludeWidget extends StatelessWidget {
  final LyricController lyricController;
  final int lrcAlignment;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final bool isCurrent;

  const InterludeWidget({
    super.key,
    required this.lyricController,
    required this.lrcAlignment,
    required this.interludeLyricStyle,
    required this.strutStyle,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor =
        interludeLyricStyle.color ?? const Color(0xFFFFFFFF);
    final List<Color> gradientColors = [
      baseColor.withValues(alpha: LyricConstants.highLightAlpha),
      baseColor.withValues(alpha: LyricConstants.highLightAlpha),
      baseColor,
    ];

    return SignalBuilder(
      builder: (context) {
        final bool show = lyricController.showInterlude.value;
        final bool isVisible = isCurrent && show;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return _InterludeTransition(
              animation: animation,
              scaleAlignment: LyricConstants.lrcScaleAlignment[lrcAlignment],
              child: child,
            );
          },
          child: isVisible
              ? Row(
                  key: const ValueKey('interlude_visible'),
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment:
                      LyricConstants.lrcMainAlignment[lrcAlignment],
                  children: [
                    RepaintBoundary(
                      child: _BreathingDots(
                        lyricController: lyricController,
                        interludeLyricStyle: interludeLyricStyle,
                        strutStyle: strutStyle,
                        gradientColors: gradientColors,
                        lrcAlignment: lrcAlignment,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('interlude_hidden')),
        );
      },
    );
  }
}

class _BreathingDots extends StatefulWidget {
  final LyricController lyricController;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final List<Color> gradientColors;
  final int lrcAlignment;

  const _BreathingDots({
    required this.lyricController,
    required this.interludeLyricStyle,
    required this.strutStyle,
    required this.gradientColors,
    required this.lrcAlignment,
  });

  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late CurvedAnimation _curvedAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _curvedAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: LyricConstants.lrcScale,
    ).animate(_curvedAnimation);
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          alignment: LyricConstants.lrcScaleAlignment[widget.lrcAlignment],
          scale: _scaleAnimation.value,
          filterQuality: FilterQuality.low, // 保持低质量抗锯齿，防止抖动
          child: child,
        );
      },
      child: ValueListenableBuilder(
        valueListenable: widget.lyricController.interludeProcess,
        builder: (context, progress, child) {
          return HighlightedWord(
            text: "  ● ● ●  ",
            progress: progress,
            style: widget.interludeLyricStyle,
            strutStyle: widget.strutStyle,
            gradientColors: widget.gradientColors,
            duartion: 0,
            ripplesScaleMax: 1.1,
            glowAlphaMax: 0.2,
            translateGradientScale: 2.0,
          );
        },
      ),
    );
  }
}
