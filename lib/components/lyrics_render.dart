import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/controller/lyric_ctrl.dart';
import 'package:zerobit_player/controller/setting_ctrl.dart';
import 'package:zerobit_player/theme_manager.dart';
import 'package:zerobit_player/tools/func/func_extension.dart';
import 'package:zerobit_player/tools/func/general_style.dart';
import 'package:zerobit_player/tools/lrcTool/lyric_model.dart';

import 'audio_ctrl_btn.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const double _highLightAlpha = 0.9;
const double _currentAlpha = 0.4;
const double _notPlayedLightAlpha = 0.25;
const double _notPlayedDarkAlpha = 0.15;
const BorderRadius _borderRadius = BorderRadius.all(Radius.circular(4));
const double _ctrlBtnMinSize = 40.0;
const double _floatingY = -1.5;
const double _rippleThreshold = 1.5;
const double _ripplesScaleMin = 1.1;
const double _glowAlphaMin = 0.2;
const double _ripplesScaleExtra = 0.1;
const double _glowAlphaExtra = 0.3;

const _lrcCrossAlignment = <CrossAxisAlignment>[
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
];
const _lrcMainAlignment = <MainAxisAlignment>[
  MainAxisAlignment.start,
  MainAxisAlignment.center,
  MainAxisAlignment.end,
];
const _lrcScaleAlignment = <Alignment>[
  Alignment.centerLeft,
  Alignment.center,
  Alignment.centerRight,
];
const _lrcWrapAlignment = <WrapAlignment>[
  WrapAlignment.start,
  WrapAlignment.center,
  WrapAlignment.end,
];

const _lrcTextAlign = <TextAlign>[
  TextAlign.left,
  TextAlign.center,
  TextAlign.right,
];
const _gradientStops = <double>[0.0, 0.333, 0.666];
const double _lrcScale = 1.1;

class _LyricsStyle {
  final SettingController _settingsController = Get.find();

  final _themeService = ThemeService.instance;

  // 提取基础参数，避免重复访问 Rx 变量的 .value
  double get _baseSize => _settingsController.lrcFontSize.value.toDouble();
  FontWeight get _weight =>
      FontWeight.values[_settingsController.lrcFontWeight.value];
  Color get _primaryColor => _themeService.darkTheme.colorScheme.primary;
  Color get _onContainerColor =>
      _themeService.darkTheme.colorScheme.onSecondaryContainer;

  // StrutStyle 强制行高一致，防止跳动
  StrutStyle get strutStyle =>
      StrutStyle(fontSize: _baseSize.toDouble(), forceStrutHeight: true);

  // 核心样式生成
  TextStyle get lyricStyle => generalTextStyle(
    size: _baseSize,
    color: _onContainerColor.withValues(alpha: _notPlayedDarkAlpha),
    weight: _weight,
  );

  TextStyle get tsLyricStyle => lyricStyle.copyWith(fontSize: _baseSize - 4);

  TextStyle get romaLyricStyle => lyricStyle.copyWith(fontSize: _baseSize - 6);

  TextStyle get interludeLyricStyle =>
      lyricStyle.copyWith(fontFamily: 'Microsoft YaHei Light');

  Color get hoverColor => _themeService.darkTheme.colorScheme.onSurface
      .withValues(alpha: _notPlayedDarkAlpha);

  Color? get mixColor =>
      Color.lerp(_primaryColor, Colors.white, _notPlayedLightAlpha);
}

class _LrcLyricWidget extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool isCurrent;
  final TextAlign textAlign;
  final double highLightAlpha;
  const _LrcLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.textAlign,
    this.highLightAlpha = _highLightAlpha,
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
      child: Text(text, textAlign: textAlign, softWrap: true),
    );
  }
}

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  final double translateGradientScale;
  const _ScaledTranslateGradientTransform({
    required this.dx,
    required this.translateGradientScale,
  });
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // final double scale=entry.value.duration>=1.0 ? 3:2; 动态 scale 视觉效果更好
    // 先将x轴扩大scale倍，然后平移x轴

    final matrix = Matrix4.zero();
    final storage = matrix.storage;

    // xyz缩放
    storage[0] = translateGradientScale; // x
    storage[5] = 1.0; // y
    storage[10] = 1.0; // z
    storage[15] = 1.0; // w

    // x平移
    storage[12] = translateGradientScale * dx;
    return matrix;
  }
}

class _HighlightedWord extends StatefulWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;
  final List<Color> gradientColors;
  final double duartion;
  final double ripplesScaleMax;
  final double glowAlphaMax;
  final double translateGradientScale;

  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.style,
    required this.strutStyle,
    required this.gradientColors,
    required this.duartion,
    required this.ripplesScaleMax,
    required this.glowAlphaMax,
    required this.translateGradientScale,
  });

  @override
  State<_HighlightedWord> createState() => _HighlightedWordState();
}

class _HighlightedWordState extends State<_HighlightedWord> {
  // text 不变或 duration 未超过 _rippleThreshold 则不重算
  late List<String> _charList;
  late int _charCount;

  // 涟漪效果核心算法
  // 推进步长 stepRatio（0.0 ~ 1.0）：决定前后两个字的动画有多少交集。
  // 设为 0.1 意味着：当前一个字的动画跑到 10% 时，后一个字的动画就要开始了
  static const double _stepRatio = 0.1;

  // 动画时间比例
  static const double _animatedRatio = 0.6;

  // 计算出每个字的动画在总进度里占多少"时间窗口"(即动画持续时间)
  // 算法：
  // waveWidth + (charCount - 1) * stepRatio * waveWidth = 1
  // 第一个字占一个完整窗口 所以 +waveWidth
  // charCount - 1 推进次数(即字符之间有多少个间隔) 第一个字不推进所以-1
  // stepRatio * waveWidth 每次推进的宽度 即后一个字动画的开始时间
  // 提取后得到 waveWidth = 1.0 / (_stepRatio * (_charCount - 1) + 1.0)
  late double _waveWidth;

  // 每个字的 windowStart 只依赖 i / stepRatio / waveWidth，全部不变，预计算缓存
  late List<double> _windowStarts;

  // 正常显示文本的样式
  late final TextStyle _normalStyle = widget.style.copyWith(
    color: widget.style.color?.withValues(alpha: 1),
  );

  // 提取基础颜色以备 shadow 计算使用
  late final Color _baseColor = widget.style.color ?? Colors.white;

  @override
  void initState() {
    super.initState();
    _initCachedValues();
  }

  void _initCachedValues() {
    _charList = widget.text.split('');
    _charCount = _charList.length;
    _waveWidth = 1.0 / (_stepRatio * (_charCount - 1) + 1.0);
    _windowStarts = List.generate(
      _charCount,
      // 这个字动画开始的时间 依照 i 和 stepRatio 设置动画区间用于延时启动
      (i) => i * _stepRatio * _waveWidth,
    );
  }

  Widget _shaderMaskWrap(Widget child) {
    return ShaderMask(
      shaderCallback: (bounds) {
        // 颜色平均分三段：高亮区 过渡区 透明区
        // 在动画开始的时候，覆盖到 Text 上的应该是透明区，应该先把整个遮罩层应该向左移动
        // 但是因为遮罩层放大了3倍，所以应该用 -0.666 * bounds.width 得到透明区位置，负号为向左
        // 随着 progress 增大 遮罩会逐渐向右移动
        final double dx = (-0.666 * bounds.width) * (1 - widget.progress);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: widget.gradientColors,
          stops: _gradientStops,
          transform: _ScaledTranslateGradientTransform(
            dx: dx,
            translateGradientScale: widget.translateGradientScale,
          ),
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.duartion < _rippleThreshold) {
      // 小于阈值则不应用涟漪效果
      return _shaderMaskWrap(
        Text(
          widget.text,
          style: widget.style.copyWith(
            color: widget.style.color?.withValues(alpha: 1),
          ),
          strutStyle: widget.strutStyle,
        ),
      );
    }

    final List<InlineSpan> glowChildren = List<InlineSpan>.filled(
      _charCount,
      const TextSpan(),
      growable: false,
    );

    for (int i = 0; i < _charCount; i++) {
      final char = _charList[i];

      // 当 progress>=windowStart 时 这个字才会开始动画
      // 将 progress 进度分别映射到每个字的进度上
      final double charProgress =
          // 这个字动画持续的时间为 _waveWidth
          ((widget.progress - _windowStarts[i]) / _waveWidth).clamp(0.0, 1.0);

      // 使用非对称曲线，设置 animatedRatio 可控制放大与缩小所占的时间比例
      double animationCurve;
      if (charProgress < _animatedRatio) {
        // 前 animatedRatio 的时间用于放大的曲线
        // 使用 easeOut 曲线
        animationCurve = Curves.easeOut.transform(
          charProgress / _animatedRatio,
        );
      } else {
        // 后 1 - animatedRatio 的时间用于缩小的曲线
        // 使用 easeIn 曲线
        animationCurve =
            1.0 -
            Curves.easeIn.transform(
              (charProgress - _animatedRatio) / (1 - _animatedRatio),
            );
      }

      // 将 animationCurve 应用到缩放与辉光效果线性插值
      final double scale = ui.lerpDouble(
        1.0,
        widget.ripplesScaleMax,
        animationCurve,
      )!;
      final double glowAlpha = ui.lerpDouble(
        0.0,
        widget.glowAlphaMax,
        animationCurve,
      )!;

      // glow 层
      glowChildren[i] = WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.scale(
          alignment: Alignment.bottomCenter,
          scale: scale,
          filterQuality: FilterQuality.low,
          child: Text(
            char,
            style: _normalStyle.copyWith(
              shadows: [
                Shadow(
                  color: _baseColor.withValues(alpha: glowAlpha * 0.6),
                  blurRadius: 4,
                ),
                Shadow(
                  color: _baseColor.withValues(alpha: glowAlpha),
                  blurRadius: 8,
                ),
              ],
            ),
            strutStyle: widget.strutStyle,
          ),
        ),
      );
    }

    return _shaderMaskWrap(
      Text.rich(
        TextSpan(children: glowChildren),
        strutStyle: widget.strutStyle,
      ),
    );
  }
}

class _KaraOkLyricWidget extends StatelessWidget {
  final List<WordEntry> text;
  final TextStyle style;
  final bool isCurrent;
  final bool isPrevLine;
  final int lrcAlignmentIndex;
  final LyricController lyricController;
  final StrutStyle strutStyle;

  const _KaraOkLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.lrcAlignmentIndex,
    required this.lyricController,
    required this.strutStyle,
    required this.isPrevLine,
  });

  Widget _createTextRich() {
    return Text.rich(
      TextSpan(
        children: text.map((wordEntry) {
          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text(
              style: style,
              wordEntry.lyricWord,
              strutStyle: strutStyle,
            ),
          );
        }).toList(),
      ),
      textAlign: _lrcTextAlign[lrcAlignmentIndex],
      strutStyle: strutStyle,
      softWrap: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isCurrent && !isPrevLine) {
      return _createTextRich();
    }

    final gradientColors = <Color>[
      style.color!.withValues(alpha: _highLightAlpha),
      style.color!.withValues(alpha: _highLightAlpha),
      style.color!.withValues(alpha: _currentAlpha),
    ];

    final TextAlign textAlign = _lrcTextAlign[lrcAlignmentIndex];

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

              final bool isFloating = isCurrent && wordIndex <= currentIndex;
              final floatingDuration = dura * (1000 * 1.8) + 50;
              final floatingDelay = dura * (1000 * 0.2);

              Widget wordWidget;

              if (isCurrent && wordIndex == currentIndex) {
                gradientColors[2] = style.color!.withValues(
                  alpha: wordIndex == 0 ? _currentAlpha - 0.15 : _currentAlpha,
                ); // 视觉欺骗，防止颜色突变

                final translateGradientScale = dura >= 1.0
                    ? 3.0
                    : 2.0; // 动态改变渐变区宽度
                double ripplesScaleMax = _ripplesScaleMin;
                double glowAlphaMax = _glowAlphaMin;

                if (dura >= _rippleThreshold) {
                  // 将词的持续时间 dura 在 [_rippleThreshold, 3] 区间内归一化为 [0.0, 1.0] 的比例值
                  // 用于控制特效的最大值
                  final effectRatio =
                      (((dura - _rippleThreshold) /
                              (3 - _rippleThreshold))) // 最大观测长度 3s
                          .clamp(0.0, 1.0);
                  ripplesScaleMax += _ripplesScaleExtra * effectRatio;
                  glowAlphaMax += _glowAlphaExtra * effectRatio;
                }

                // 正在唱的字
                wordWidget = ValueListenableBuilder<double>(
                  valueListenable: lyricController.wordProgress,
                  builder: (context, progress, child) {
                    return _HighlightedWord(
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

                if (isCurrent) {
                  if (wordIndex < currentIndex) {
                    targetColor = style.color!.withValues(
                      alpha: _highLightAlpha,
                    );
                    beginColor = targetColor; // 已经唱过的字，保持高亮
                  } else {
                    targetColor = style.color!.withValues(alpha: _currentAlpha);
                    beginColor = style.color!.withValues(
                      alpha: _notPlayedDarkAlpha,
                    ); // 还没唱到的字，从暗色过渡到稍微高亮的颜色
                  }
                } else {
                  targetColor = style.color!;
                  beginColor = style.color!.withValues(
                    alpha: _highLightAlpha,
                  ); // 刚唱完的上一行，最终褪回普通颜色
                }

                wordWidget = TweenAnimationBuilder<Color?>(
                  key: ValueKey('word_$wordIndex'), // ???
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  tween: ColorTween(begin: beginColor, end: targetColor),
                  builder: (_, color, __) {
                    return Text(
                      word,
                      style: style.copyWith(color: color),
                      strutStyle: strutStyle,
                    );
                  },
                );
              }

              // return _SyllableFloatWidget(isFloating: isFloating,duration: isFloating ? floatingDuration : 600,delay: isFloating ? floatingDelay : 0,child: wordWidget,);

              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: wordWidget,
              );
              // .animate(target: isFloating ? 1.0 : 0.0)
              // .custom(
              //   duration: isFloating ? floatingDuration.ms : 600.ms,
              //   delay: isFloating ? floatingDelay.ms : 0.ms,
              //   curve: isFloating ? Curves.easeInOut : Curves.easeInCubic,
              //   builder: (context, value, child) {
              //     return Transform.translate(
              //       offset: Offset(
              //         0,
              //         ui.lerpDouble(0.0, _floatingY, value)!,
              //       ),
              //       filterQuality: FilterQuality.low,
              //       child: child,
              //     );
              //   },
              // );
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

// class _SyllableFloatWidget extends StatefulWidget {
//   final bool isFloating;
//   final double duration;
//   final double delay;
//   final Widget child;
//
//   const _SyllableFloatWidget({
//     required this.isFloating,
//     required this.duration,
//     required this.delay,
//     required this.child,
//   });
//
//   @override
//   State<_SyllableFloatWidget> createState() => _SyllableFloatWidgetState();
// }
//
// class _SyllableFloatWidgetState extends State<_SyllableFloatWidget>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;
//   Timer? _delayTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(vsync: this);
//     _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
//     _updateAnimation();
//   }
//
//   @override
//   void didUpdateWidget(_SyllableFloatWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.isFloating != widget.isFloating ||
//         oldWidget.duration != widget.duration ||
//         oldWidget.delay != widget.delay) {
//       _updateAnimation();
//     }
//   }
//
//   void _updateAnimation() {
//     _delayTimer?.cancel();
//     if (widget.isFloating) {
//       _controller.duration = Duration(milliseconds: widget.duration.round());
//       if (widget.delay > 0) {
//         _delayTimer = Timer(Duration(milliseconds: widget.delay.round()), () {
//           if (mounted) _controller.forward();
//         });
//       } else {
//         _controller.forward();
//       }
//     } else {
//       _controller.duration = const Duration(milliseconds: 600);
//       _controller.reverse();
//     }
//   }
//
//   @override
//   void dispose() {
//     _delayTimer?.cancel();
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         final double offset = ui.lerpDouble(0.0, _floatingY, _animation.value)!;
//         if (offset == 0.0) return child!;
//         return Transform.translate(
//           offset: Offset(0, offset),
//           filterQuality: FilterQuality.low,
//           child: child,
//         );
//       },
//       child: widget.child,
//     );
//   }
// }

class LyricsRender extends StatefulWidget {
  const LyricsRender({super.key});

  @override
  State<LyricsRender> createState() => _LyricsRenderState();
}

class _LyricsRenderState extends State<LyricsRender> {
  final AudioController _audioController = Get.find<AudioController>();
  final SettingController _settingController = Get.find<SettingController>();
  final LyricController _lyricController = Get.find<LyricController>();
  final _isHover = false.obs;
  final _LyricsStyle lrcStylePackage = _LyricsStyle();

  @override
  void initState() {
    super.initState();
    // 首次进入页面时，跳转到当前行
    _lyricController.lrcViewScrollController = ItemScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lyricController.scrollToCenter();
      }
    });
  }

  @override
  void dispose() {
    _lyricController.lrcViewScrollController = null;
    _isHover.close();
    _blurFilterCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color? mixColor = lrcStylePackage.mixColor;

    final dynamicPadding = context.width / 2 * (1 - 1 / _lrcScale);

    // 路由外部更改的值
    final useSpringscroll = _settingController.useSpringScroll.value;
    return MouseRegion(
      onEnter: (_) => _isHover.value = true,
      onExit: (_) => _isHover.value = false,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _lyricController.pointerScroll();
          }
        },
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: GetBuilder<AudioController>(
                id: GetBuilderId.lyricRender,
                builder: (c) {
                  // 将 style 定义在Obx内以接收样式更改信号
                  final lyricsStyle = lrcStylePackage.lyricStyle;
                  final tsLyricStyle = lrcStylePackage.tsLyricStyle;
                  final romaLyricStyle = lrcStylePackage.romaLyricStyle;
                  final strutStyle = lrcStylePackage.strutStyle;
                  final interludeLyricStyle =
                      lrcStylePackage.interludeLyricStyle;
                  final hoverColor = lrcStylePackage.hoverColor;
                  mixColor = lrcStylePackage.mixColor;

                  debugPrint("LyricRenderReBuild");
                  if (!c.showLyricRender) {
                    return Center(
                      child: Text(
                        "无歌词",
                        style: lyricsStyle.copyWith(
                          color: lyricsStyle.color?.withValues(
                            alpha: _highLightAlpha,
                          ),
                        ),
                      ),
                    );
                  }
                  final lrcAlignment = _settingController.lrcAlignment.value;
                  final showRoma = _settingController.showRoma.value;
                  final showTranslate = _settingController.showTranslate.value;

                  final lrcPadding = EdgeInsets.only(
                    top: 16,
                    bottom: 16,
                    left: lrcAlignment == 2
                        ? dynamicPadding
                        : lrcAlignment == 1
                        ? dynamicPadding / 2
                        : 16,
                    right: lrcAlignment == 0
                        ? dynamicPadding
                        : lrcAlignment == 1
                        ? dynamicPadding / 2
                        : 16,
                  );
                  final textAlign = lrcAlignment == 0
                      ? TextAlign.left
                      : lrcAlignment == 1
                      ? TextAlign.center
                      : TextAlign.right;

                  Widget creatLyricItem(int index) {
                    if ((c.currentlyricType == LyricFormat.lrc &&
                            c.lineTextList[index].isEmpty &&
                            c.translateList[index].isEmpty) ||
                        index == -1) {
                      return const SizedBox.shrink();
                    }
                    return _StaggeredLyricItem(
                      key: ValueKey(index),
                      index: index,
                      lyricController: _lyricController,
                      audioController: _audioController,
                      settingController: _settingController,
                      lrcType: c.currentlyricType,
                      lineText: c.lineTextList[index],
                      translateText: c.translateList[index],
                      romaText: c.romaList[index],
                      startTime: c.startTime[index],
                      lyricStyle: lyricsStyle,
                      tsLyricStyle: tsLyricStyle,
                      romaLyricStyle: romaLyricStyle,
                      interludeLyricStyle: interludeLyricStyle,
                      strutStyle: strutStyle,
                      hoverColor: hoverColor,
                      lrcAlignment: lrcAlignment,
                      lrcPadding: lrcPadding,
                      textAlign: textAlign,
                      showTranslate: showTranslate,
                      showRoma: showRoma,
                    );
                  }

                  return useSpringscroll
                      ? SpringListView(
                          lineDuration: c.lineDurationList,
                          length: c.lineTextList.length,
                          itemBuilder: (int index) {
                            return creatLyricItem(index);
                          },
                        )
                      : Focus(
                          canRequestFocus: false,
                          descendantsAreFocusable: false,
                          child: ScrollablePositionedList.builder(
                            itemCount: c.lineTextList.length,
                            initialScrollIndex: 0,
                            initialAlignment: 0.4,
                            itemScrollController:
                                _lyricController.lrcViewScrollController,
                            minCacheExtent: 48.0,
                            addAutomaticKeepAlives: false,
                            addSemanticIndexes: false,
                            addRepaintBoundaries: true,
                            padding: EdgeInsets.symmetric(
                              vertical:
                                  (context.height -
                                      _audioCtrlBarHeight -
                                      _controllerBarHeight) /
                                  2,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              return creatLyricItem(index);
                            },
                          ),
                        );
                },
              ),
            ),

            Positioned(
              bottom: 100,
              right: 0,
              child: Obx(
                () => AnimatedOpacity(
                  opacity: _isHover.value ? 1.0 : 0.0,
                  duration: 150.ms,
                  child: Column(
                    spacing: 4.0,
                    children: [
                      GenIconBtn(
                        tooltip: '翻译',
                        icon: _settingController.showTranslate.value
                            ? PhosphorIconsFill.translate
                            : PhosphorIconsLight.translate,
                        size: _ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          _settingController.setShowTranslate();
                          _audioController.update([GetBuilderId.lyricRender]);
                          if (Get.isRegistered<SpringListController>()) {
                            Get.find<SpringListController>()
                                    .cachedScreenHeight =
                                0.0; // 重置缓存
                          }
                        },
                      ),
                      GenIconBtn(
                        tooltip: '注音',
                        icon: _settingController.showRoma.value
                            ? PhosphorIconsFill.textAUnderline
                            : PhosphorIconsLight.textAUnderline,
                        size: _ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          _settingController.setShowRoma();
                          _audioController.update([GetBuilderId.lyricRender]);
                          if (Get.isRegistered<SpringListController>()) {
                            Get.find<SpringListController>()
                                    .cachedScreenHeight =
                                0.0; // 重置缓存
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 独立的歌词行组件
class _StaggeredLyricItem extends StatelessWidget {
  final int index;

  final LyricController lyricController;
  final AudioController audioController;
  final SettingController settingController;

  final String lrcType;
  final dynamic lineText;
  final String translateText;
  final String romaText;
  final double startTime;

  final int lrcAlignment;
  final TextAlign textAlign;
  final EdgeInsets lrcPadding;
  final bool showTranslate;
  final bool showRoma;

  final TextStyle lyricStyle;
  final TextStyle tsLyricStyle;
  final TextStyle romaLyricStyle;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final Color? hoverColor;

  const _StaggeredLyricItem({
    super.key,
    required this.index,
    required this.lyricController,
    required this.audioController,
    required this.settingController,
    required this.lrcType,
    required this.lineText,
    required this.translateText,
    required this.romaText,
    required this.startTime,
    required this.lyricStyle,
    required this.tsLyricStyle,
    required this.romaLyricStyle,
    required this.interludeLyricStyle,
    required this.strutStyle,
    required this.hoverColor,
    required this.lrcAlignment,
    required this.lrcPadding,
    required this.textAlign,
    required this.showTranslate,
    required this.showRoma,
  });

  Widget _createAnimatedScaleWidget({
    required Widget child,
    required bool isCurrent,
  }) {
    return AnimatedScale(
      scale: isCurrent ? _lrcScale : 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: _lrcScaleAlignment[lrcAlignment],
      child: child,
    );
  }

  Widget _createAnimatedSizeWidget({
    required Widget child,
    required bool show,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: _lrcScaleAlignment[lrcAlignment],
      child: show ? child : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useBlur = settingController.useBlur.value;
    final useSpring = settingController.useSpringScroll.value;

    return Obx(() {
      final int currentLineIndex = lyricController.currentLineIndex.value;
      final renderWidget =
          (index - currentLineIndex).abs() <= lyricController.visibleItemCount;

      final isPointerScrolling = lyricController.isPointerScroll.value;
      if (!renderWidget && useSpring && !isPointerScrolling) {
        return const SizedBox.shrink(); // ?
      }

      final isCurrent = index == currentLineIndex;
      final bool isPrevLine = (currentLineIndex - index == 1);

      final content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: _lrcCrossAlignment[lrcAlignment],
        children: [
          if (index == 0)
            _InterludeWidget(
              lyricController: lyricController,
              lrcAlignment: lrcAlignment,
              interludeLyricStyle: interludeLyricStyle,
              strutStyle: strutStyle,
              isCurrent: currentLineIndex < 0,
            ),
          if (lrcType == LyricFormat.lrc)
            _createAnimatedScaleWidget(
              child: _LrcLyricWidget(
                text: lineText as String,
                style: lyricStyle,
                isCurrent: isCurrent,
                textAlign: textAlign,
              ),
              isCurrent: isCurrent,
            )
          else
            _createAnimatedScaleWidget(
              child: _KaraOkLyricWidget(
                text: lineText as List<WordEntry>,
                style: lyricStyle,
                isCurrent: isCurrent,
                isPrevLine: isPrevLine,
                lrcAlignmentIndex: lrcAlignment,
                lyricController: lyricController,
                strutStyle: strutStyle,
              ),
              isCurrent: isCurrent,
            ),

          _createAnimatedSizeWidget(
            show: romaText.isNotEmpty && showRoma,
            child: _LrcLyricWidget(
              text: romaText,
              style: romaLyricStyle,
              isCurrent: isCurrent,
              textAlign: textAlign,
              highLightAlpha: _currentAlpha,
            ),
          ),

          _createAnimatedSizeWidget(
            show: translateText.isNotEmpty && showTranslate,
            child: _LrcLyricWidget(
              text: translateText,
              style: tsLyricStyle,
              isCurrent: isCurrent,
              textAlign: textAlign,
              highLightAlpha: _currentAlpha,
            ),
          ),

          _InterludeWidget(
            lyricController: lyricController,
            lrcAlignment: lrcAlignment,
            interludeLyricStyle: interludeLyricStyle,
            strutStyle: strutStyle,
            isCurrent: isCurrent,
          ),
        ],
      );

      final int diff = (currentLineIndex - index).abs(); // 视距

      // 是否需要挂载 ImageFiltered (当前行保持挂载防动画中断，其余行在视距内挂载)
      final bool applyFilter =
          useBlur && (isCurrent || diff <= lyricController.visibleItemCount);

      Widget finalContent = content;

      if (applyFilter) {
        // 首行和当前行模糊度为 0，其余行未滚动时根据距离取 1~4
        final double targetSigma =
            isCurrent ||
                (index <= 0 && currentLineIndex <= 0) ||
                isPointerScrolling
            ? 0.0
            : diff.clamp(0, 4).toDouble();

        finalContent = ImageFiltered(
          enabled: targetSigma > 0,
          imageFilter: _getBlurFilter(targetSigma), // 取缓存的ImageFilter
          child: content,
        );
      }

      return TextButton(
        onPressed: () {
          audioController.audioSetPositon(pos: startTime);
        }.throttle(ms: 500),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
          padding: lrcPadding,
          overlayColor: hoverColor,
        ),
        child: finalContent,
      );
    });
  }
}

// 将 ImageFilter 缓存下来，每次使用缓存的 ImageFilter 防止内存泄露
final Map<double, ui.ImageFilter> _blurFilterCache = {};

/// 获取缓存的 ImageFilter
ui.ImageFilter _getBlurFilter(double sigma) {
  return _blurFilterCache.putIfAbsent(
    sigma,
    () => ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: TileMode.decal,
    ),
  );
}

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

class _InterludeWidget extends StatelessWidget {
  final LyricController lyricController;
  final int lrcAlignment;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final bool isCurrent;

  const _InterludeWidget({
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
      baseColor.withValues(alpha: _highLightAlpha),
      baseColor.withValues(alpha: _highLightAlpha),
      baseColor,
    ];

    return Obx(() {
      final bool show = lyricController.showInterlude.value;
      final bool isVisible = isCurrent && show;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return _InterludeTransition(
            animation: animation,
            scaleAlignment: _lrcScaleAlignment[lrcAlignment],
            child: child,
          );
        },
        child: isVisible
            ? Row(
                key: const ValueKey('interlude_visible'),
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: _lrcMainAlignment[lrcAlignment],
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
    });
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
      end: _lrcScale,
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
          alignment: _lrcScaleAlignment[widget.lrcAlignment],
          scale: _scaleAnimation.value,
          filterQuality: FilterQuality.low, // 保持低质量抗锯齿，防止抖动
          child: child,
        );
      },
      child: ValueListenableBuilder(
        valueListenable: widget.lyricController.interludeProcess,
        builder: (context, progress, child) {
          return _HighlightedWord(
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
