import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import '../tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/lyric_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'audio_ctrl_btn.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const double _highLightAlpha = 0.9;
const double _currentAlpha = 0.4;
const double _notPlayedLightAlpha = 0.25;
const double _notPlayedDarkAlpha = 0.15;
const _borderRadius = BorderRadius.all(Radius.circular(4));
const double _ctrlBtnMinSize = 40.0;

const _lrcCrossAlignment = [
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
];
const _lrcMainAlignment = [
  MainAxisAlignment.start,
  MainAxisAlignment.center,
  MainAxisAlignment.end,
];
const _lrcScaleAlignment = [
  Alignment.centerLeft,
  Alignment.center,
  Alignment.centerRight,
];
const _lrcWrapAlignment = [
  WrapAlignment.start,
  WrapAlignment.center,
  WrapAlignment.end,
];
const List<double> _gradientStops = [0.0, 0.333, 0.666];
const _lrcScale = 1.1;

class _HighlightedWord extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;
  final double scale;
  final List<Color> gradientColors;
  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.style,
    required this.strutStyle,
    required this.scale,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        /// 颜色平均分三段：高亮区 过渡区 透明区
        /// 在动画开始的时候，覆盖到 Text 上的应该是透明区，应该先把整个遮罩层应该向左移动
        /// 但是因为遮罩层放大了3倍，所以应该用 -0.666 * bounds.width 得到透明区位置，负号为向左
        /// 随着 progress 增大 遮罩会逐渐向右移动
        final double dx = (-0.666 * bounds.width) * (1 - progress);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: gradientColors,
          stops: _gradientStops,
          transform: _ScaledTranslateGradientTransform(dx: dx, scale: scale),
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Text(
        text,
        style: style.copyWith(color: style.color?.withValues(alpha: 1)),
        strutStyle: strutStyle,
      ),
    );
  }
}

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  final double scale;
  const _ScaledTranslateGradientTransform({
    required this.dx,
    required this.scale,
  });
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // final double scale=entry.value.duration>=1.0 ? 3:2; 动态 scale 视觉效果更好
    // 先将x轴扩大scale倍，然后平移x轴
    return Matrix4.identity()
      ..scale(scale, 1.0, 1.0)
      ..translate(dx, 0.0, 0.0);
  }
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
        color:
            isCurrent
                ? style.color?.withValues(alpha: highLightAlpha)
                : style.color,
      ),
      child: Text(text, textAlign: textAlign, softWrap: true),
    );
  }
}

class _KaraOkLyricWidget extends StatelessWidget {
  final List<WordEntry> text;
  final TextStyle style;
  final bool isCurrent;
  final int index;
  final int lrcAlignmentIndex;
  final LyricController lyricController;
  final StrutStyle strutStyle;

  const _KaraOkLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.index,
    required this.lrcAlignmentIndex,
    required this.lyricController,
    required this.strutStyle,
  });

  Widget _createTextWarp({Color? color}) {
    return Wrap(
      alignment: _lrcWrapAlignment[lrcAlignmentIndex],
      crossAxisAlignment: WrapCrossAlignment.end,
      children:
          text.map((wordEntry) {
            return Text(
              wordEntry.lyricWord,
              style: style.copyWith(color: color),
              strutStyle: strutStyle,
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isCurrent) {
      content = Obx(() {
        final currWordIndex = lyricController.currentWordIndex.value;
        return Wrap(
          alignment: _lrcWrapAlignment[lrcAlignmentIndex],
          crossAxisAlignment: WrapCrossAlignment.end,
          children:
              text.asMap().entries.map((entry) {
                final wordIndex = entry.key;
                final word = entry.value.lyricWord;
                final double scale = entry.value.duration >= 1.0 ? 3 : 2;

                if (wordIndex == currWordIndex) {
                  final List<Color> gradientColors = [
                    style.color!.withValues(alpha: _highLightAlpha),
                    style.color!.withValues(alpha: _highLightAlpha),
                    style.color!.withValues(alpha: _currentAlpha),
                  ];

                  // 正在唱的单词
                  return Obx(
                    () => _HighlightedWord(
                      text: word,
                      progress: lyricController.wordProgress.value / 100.0,
                      style: style,
                      strutStyle: strutStyle,
                      scale: scale,
                      gradientColors: gradientColors,
                    ),
                  );
                } else if (wordIndex < currWordIndex) {
                  // 已经唱完的单词
                  return Text(
                    word,
                    style: style.copyWith(
                      color: style.color?.withValues(alpha: _highLightAlpha),
                    ),
                    strutStyle: strutStyle,
                  );
                } else {
                  // 还没唱到的单词
                  return TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      begin: style.color,
                      end: style.color?.withValues(alpha: _currentAlpha),
                    ),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, color, __) {
                      return Text(
                        word,
                        style: style.copyWith(color: color),
                        strutStyle: strutStyle,
                      );
                    },
                  );
                }
              }).toList(),
        );
      });
    } else {
      content = Obx(() {
        final currentLineIndex = lyricController.currentLineIndex.value;

        // 检查是否是刚播放完的上一行
        if (currentLineIndex - index == 1) {
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: style.color?.withValues(alpha: _highLightAlpha),
              end: style.color,
            ),
            duration: const Duration(milliseconds: 600),
            builder: (_, color, __) {
              return _createTextWarp(color: color);
            },
          );
        }

        // 对于其他所有非当前行，直接使用基础样式构建 Wrap
        return _createTextWarp();
      });
    }

    return content;
  }
}

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

  @override
  void initState() {
    super.initState();
    // 首次进入页面时，跳转到当前行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lyricController.scrollToCenter();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricStyle = generalTextStyle(
      ctx: context,
      size: _settingController.lrcFontSize.value,
      color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(
        alpha:
            _settingController.themeMode.value == 'dark'
                ? _notPlayedDarkAlpha
                : _notPlayedLightAlpha,
      ),
      weight: FontWeight.values[_settingController.lrcFontWeight.value],
    );

    final tsLyricStyle = lyricStyle.copyWith(
      fontSize: lyricStyle.fontSize! - 4,
    );

    final romaLyricStyle = tsLyricStyle.copyWith(
      fontSize: lyricStyle.fontSize! - 4,
    );

    final interludeLyricStyle = lyricStyle.copyWith(
      fontFamily: 'Microsoft YaHei Light',
    );

    final strutStyle = StrutStyle(
      fontSize: _settingController.lrcFontSize.value.toDouble(),
      forceStrutHeight: true,
    );

    final hoverColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: _notPlayedDarkAlpha);
    final dynamicPadding = context.width / 2 * (1 - 1 / _lrcScale);

    final mixColor = Color.lerp(
      Theme.of(context).colorScheme.primary,
      _settingController.themeMode.value == 'dark'
          ? Colors.white
          : Colors.black,
      _notPlayedLightAlpha,
    );

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
              child: Obx(() {
                final useSpringscroll =
                    _settingController.useSpringScroll.value;
                final currentLyrics = _audioController.currentLyrics.value;
                final parsedLrc = currentLyrics?.parsedLrc;

                if (currentLyrics == null ||
                    parsedLrc is! List<LyricEntry> ||
                    parsedLrc.isEmpty) {
                  return Center(
                    child: Text(
                      "无歌词",
                      style: lyricStyle.copyWith(
                        color: lyricStyle.color?.withValues(
                          alpha: _highLightAlpha,
                        ),
                      ),
                    ),
                  );
                }

                final String lrcType = currentLyrics.type;
                final List lineList =
                    parsedLrc.map((v) => v.lyricText).toList();
                final List<String> translateList =
                    parsedLrc.map((v) => v.translate).toList();
                final List<double> startTime =
                    parsedLrc.map((v) => v.start).toList();
                final List<String> romaList =
                    parsedLrc.map((v) => v.roma).toList();

                Widget creatLyricItem(index) {
                  if ((lrcType == LyricFormat.lrc &&
                          lineList[index].isEmpty &&
                          translateList[index].isEmpty) ||
                      index == -1) {
                    return const SizedBox.shrink();
                  }
                  return _StaggeredLyricItem(
                    index: index,
                    lyricController: _lyricController,
                    audioController: _audioController,
                    settingController: _settingController,
                    lrcType: lrcType,
                    lineText: lineList[index],
                    translateText: translateList[index],
                    romaText: romaList[index],
                    startTime: startTime[index],
                    lyricStyle: lyricStyle,
                    tsLyricStyle: tsLyricStyle,
                    romaLyricStyle: romaLyricStyle,
                    interludeLyricStyle: interludeLyricStyle,
                    strutStyle: strutStyle,
                    hoverColor: hoverColor,
                    dynamicPadding: dynamicPadding,
                  );
                }

                return useSpringscroll
                    ? SpringListView(
                      length: parsedLrc.length,
                      itemBuilder: (BuildContext context, int index) {
                        return creatLyricItem(index);
                      },
                    )
                    : ScrollablePositionedList.builder(
                      key: ValueKey(currentLyrics.hashCode),
                      itemCount: parsedLrc.length,
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
                    );
              }),
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
                        icon:
                            _settingController.showTranslate.value
                                ? PhosphorIconsFill.translate
                                : PhosphorIconsLight.translate,
                        size: _ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          _settingController.setShowTranslate(
                            show: !_settingController.showTranslate.value,
                          );
                        },
                      ),
                      GenIconBtn(
                        tooltip: '注音',
                        icon:
                            _settingController.showRoma.value
                                ? PhosphorIconsFill.textAUnderline
                                : PhosphorIconsLight.textAUnderline,
                        size: _ctrlBtnMinSize,
                        color: mixColor,
                        fn: () {
                          _settingController.setShowRoma(
                            show: !_settingController.showRoma.value,
                          );
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

  final TextStyle lyricStyle;
  final TextStyle tsLyricStyle;
  final TextStyle romaLyricStyle;
  final TextStyle interludeLyricStyle;
  final StrutStyle strutStyle;
  final Color? hoverColor;
  final double dynamicPadding;

  const _StaggeredLyricItem({
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
    required this.dynamicPadding,
  });

  Widget _creatScaleWidget({
    required Widget child,
    required bool isCurrent,
    required int lrcAlignmentIndex,
  }) {
    return AnimatedScale(
      scale: isCurrent ? _lrcScale : 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: _lrcScaleAlignment[lrcAlignmentIndex],
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lrcAlignment = settingController.lrcAlignment.value;
      final isCurrent = index == lyricController.currentLineIndex.value;
      final isPointerScrolling = lyricController.isPointerScroll.value;

      final lrcPadding = EdgeInsets.only(
        top: 16,
        bottom: 16,
        left:
            lrcAlignment == 2
                ? dynamicPadding
                : lrcAlignment == 1
                ? dynamicPadding / 2
                : 16,
        right:
            lrcAlignment == 0
                ? dynamicPadding
                : lrcAlignment == 1
                ? dynamicPadding / 2
                : 16,
      );
      final textAlign =
          lrcAlignment == 0
              ? TextAlign.left
              : lrcAlignment == 1
              ? TextAlign.center
              : TextAlign.right;

      final content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: _lrcCrossAlignment[lrcAlignment],
        children: [
          if (lrcType == LyricFormat.lrc)
            _creatScaleWidget(
              child: _LrcLyricWidget(
                text: lineText as String,
                style: lyricStyle,
                isCurrent: isCurrent,
                textAlign: textAlign,
              ),
              isCurrent: isCurrent,
              lrcAlignmentIndex: lrcAlignment,
            )
          else
            _creatScaleWidget(
              child: _KaraOkLyricWidget(
                text: lineText as List<WordEntry>,
                style: lyricStyle,
                isCurrent: isCurrent,
                index: index,
                lrcAlignmentIndex: lrcAlignment,
                lyricController: lyricController,
                strutStyle: strutStyle,
              ),
              isCurrent: isCurrent,
              lrcAlignmentIndex: lrcAlignment,
            ),

          if (romaText.isNotEmpty && settingController.showRoma.value)
            _LrcLyricWidget(
              text: romaText,
              style: romaLyricStyle,
              isCurrent: isCurrent,
              textAlign: textAlign,
              highLightAlpha: _currentAlpha,
            ),

          if (translateText.isNotEmpty && settingController.showTranslate.value)
            _LrcLyricWidget(
              text: translateText,
              style: tsLyricStyle,
              isCurrent: isCurrent,
              textAlign: textAlign,
              highLightAlpha: _currentAlpha,
            ),

          Obx(() {
            final show = lyricController.showInterlude.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final sizeAnimation = CurvedAnimation(
                  //尺寸曲线
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );

                final scaleAnimation = CurvedAnimation(
                  //回弹曲线
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInBack,
                );

                final fadeAnimation = CurvedAnimation(
                  // 透明度曲线
                  parent: animation,
                  curve: Curves.easeOut,
                  reverseCurve: Curves.easeIn,
                );

                return SizeTransition(
                  axis: Axis.vertical,
                  axisAlignment: 0.0, // 从顶部开始撑开
                  sizeFactor: sizeAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      alignment: _lrcScaleAlignment[lrcAlignment],
                      child: child,
                    ),
                  ),
                );
              },
              child:
                  (isCurrent && show)
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: _lrcMainAlignment[lrcAlignment],
                        children: [
                          _HighlightedWord(
                                text: "  ● ● ●  ",
                                progress:
                                    lyricController.interludeProcess.value /
                                    100,
                                style: interludeLyricStyle,
                                strutStyle: strutStyle,
                                scale: 2,
                                gradientColors: [
                                  interludeLyricStyle.color!.withValues(
                                    alpha: _highLightAlpha,
                                  ),
                                  interludeLyricStyle.color!.withValues(
                                    alpha: _highLightAlpha,
                                  ),
                                  interludeLyricStyle.color!,
                                ],
                              )
                              .animate(
                                onPlay:
                                    (controller) =>
                                        controller.repeat(reverse: true),
                              )
                              .custom(
                                // 使用customEffect,并向Transform.scale添加filterQuality参数防止字体缩放抖动(像素对齐冲突)
                                duration: 1500.ms,
                                curve: Curves.easeInOut,
                                builder:
                                    (context, value, child) => Transform.scale(
                                      alignment:
                                          _lrcScaleAlignment[lrcAlignment],
                                      scale:
                                          ui.lerpDouble(1.0, _lrcScale, value)!,
                                      filterQuality:
                                          FilterQuality
                                              .low, // 使用 FilterQuality.low 质量就已足够
                                      child: child,
                                    ),
                              ),
                        ],
                      )
                      : const SizedBox.shrink(),
            );
          }),
        ],
      );

      double targetSigma = 0.0;
      if (!isPointerScrolling &&
          !isCurrent &&
          settingController.useBlur.value) {
        targetSigma =
            (lyricController.currentLineIndex.value - index)
                .abs()
                .clamp(0.0, 4.0)
                .toDouble();
      }

      final Widget lyricLine = FractionallySizedBox(
        widthFactor: 1,
        child: content,
      );

      return TextButton(
        onPressed: () {
          audioController.audioSetPositon(pos: startTime);
        }.throttle(ms: 500),
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
          padding: lrcPadding,
          overlayColor: hoverColor,
        ),
        child:
            settingController.useBlur.value
                ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: targetSigma),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, sigma, child) {
                    return ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: sigma,
                        sigmaY: sigma,
                      ),
                      child: child,
                    );
                  },
                  child: lyricLine,
                )
                : lyricLine,
      );
    });
  }
}
