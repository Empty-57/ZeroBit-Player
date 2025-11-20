import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import '../tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/lyric_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'audio_ctrl_btn.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const double _highLightAlpha = 0.85;
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
const _lrcScale = 1.1;

class _HighlightedWord extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;
  final double scale;

  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.style,
    required this.strutStyle,
    required this.scale,
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
          colors: [
            style.color!.withValues(alpha: _highLightAlpha),
            style.color!.withValues(alpha: _highLightAlpha),
            style.color!,
          ],
          stops: const [0.0, 0.333, 0.666],
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
  final int lrcAlignmentIndex;
  final TextAlign textAlign;

  const _LrcLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.lrcAlignmentIndex,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isCurrent ? _lrcScale : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutQuad,
      alignment: _lrcScaleAlignment[lrcAlignmentIndex],
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: style.copyWith(
          color:
              isCurrent
                  ? style.color?.withValues(alpha: _highLightAlpha)
                  : style.color,
        ),
        child: Text(text, textAlign: textAlign, softWrap: true),
      ),
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
  final bool cancelScale;

  const _KaraOkLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.index,
    required this.lrcAlignmentIndex,
    required this.lyricController,
    required this.strutStyle,
    required this.cancelScale,
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
                  return Obx(
                    () => _HighlightedWord(
                      text: word,
                      progress: lyricController.wordProgress.value / 100.0,
                      style: style,
                      strutStyle: strutStyle,
                      scale: scale,
                    ),
                  );
                } else if (wordIndex < currWordIndex) {
                  return Text(
                    word,
                    style: style.copyWith(
                      color: style.color?.withValues(alpha: _highLightAlpha),
                    ),
                    strutStyle: strutStyle,
                  );
                } else {
                  return Text(word, style: style, strutStyle: strutStyle);
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
            duration: const Duration(milliseconds: 300),
            builder: (_, color, __) {
              return _createTextWarp(color: color);
            },
          );
        }

        // 对于其他所有非当前行，直接使用基础样式构建 Wrap
        return _createTextWarp();
      });
    }

    return AnimatedScale(
      scale: isCurrent && cancelScale ? _lrcScale : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutQuad,
      alignment: _lrcScaleAlignment[lrcAlignmentIndex],
      child: content,
    );
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
        alpha: _settingController.themeMode.value == 'dark' ? 0.2 : 0.3,
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
    ).colorScheme.onSurface.withValues(alpha: 0.2);
    final dynamicPadding = context.width / 2 * (1 - 1 / _lrcScale);

    final mixColor = Color.lerp(
      Theme.of(context).colorScheme.primary,
      _settingController.themeMode.value == 'dark'
          ? Colors.white
          : Colors.black,
      0.3,
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
              // stack
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: Obx(() {
                final currentLyrics = _audioController.currentLyrics.value;
                final parsedLrc = currentLyrics?.parsedLrc;
                final lrcAlignment = _settingController.lrcAlignment.value;
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

                // 重要: 需要先缓存字段，否则可能造成内存泄漏
                // 可能 _KaraOkLyricWidget 仍有性能问题
                final List lineList =
                    parsedLrc.map((v) => v.lyricText).toList();
                final List<String> translateList =
                    parsedLrc.map((v) => v.translate).toList();
                final List<double> startTime =
                    parsedLrc.map((v) => v.start).toList();
                final List<String> romaList =
                    parsedLrc.map((v) => v.roma).toList();

                return ScrollablePositionedList.builder(
                  key: ValueKey(currentLyrics.hashCode),
                  itemCount: parsedLrc.length,
                  initialScrollIndex: 0,
                  initialAlignment: 0.4,
                  itemScrollController:
                      _lyricController.lrcViewScrollController,
                  minCacheExtent: 48.0,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  addRepaintBoundaries: false,
                  padding: EdgeInsets.symmetric(
                    vertical:
                        (context.height -
                            _audioCtrlBarHeight -
                            _controllerBarHeight) /
                        2,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    if ((lrcType == LyricFormat.lrc &&
                            lineList[index].isEmpty &&
                            translateList[index].isEmpty) ||
                        index == -1) {
                      return const SizedBox.shrink();
                    }

                    return Obx(() {
                      final isCurrent =
                          index == _lyricController.currentLineIndex.value;
                      final isPointerScrolling =
                          _lyricController.isPointerScroll.value;

                      final Widget content = Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: _lrcCrossAlignment[lrcAlignment],
                        children: [
                          if (lrcType == LyricFormat.lrc)
                            _LrcLyricWidget(
                              text: lineList[index] as String,
                              style: lyricStyle,
                              isCurrent: isCurrent,
                              lrcAlignmentIndex: lrcAlignment,
                              textAlign: textAlign,
                            )
                          else
                            _KaraOkLyricWidget(
                              text: lineList[index] as List<WordEntry>,
                              style: lyricStyle,
                              isCurrent: isCurrent,
                              index: index,
                              lrcAlignmentIndex: lrcAlignment,
                              lyricController: _lyricController,
                              strutStyle: strutStyle,
                              cancelScale: _lyricController.cancelScale.value,
                            ),
                          if (romaList[index].isNotEmpty &&
                              _settingController.showRoma.value)
                            Text(
                              romaList[index],
                              style: romaLyricStyle,
                              softWrap: true,
                              textAlign: textAlign,
                            ),
                          if (translateList[index].isNotEmpty &&
                              _settingController.showTranslate.value)
                            Text(
                              translateList[index],
                              style: tsLyricStyle,
                              softWrap: true,
                              textAlign: textAlign,
                            ),

                          Obx(() {
                            final show = _lyricController.showInterlude.value;
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (
                                Widget child,
                                Animation<double> animation,
                              ) {
                                final curvedAnimation = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                  reverseCurve: Curves.easeOutBack,
                                );
                                return SizeTransition(
                                  axis: Axis.vertical,
                                  axisAlignment: 0.0,
                                  sizeFactor: curvedAnimation, // 平滑地改变布局空间
                                  child: ScaleTransition(
                                    scale: curvedAnimation, // 同时进行缩放
                                    alignment: _lrcScaleAlignment[lrcAlignment],
                                    child: child,
                                  ),
                                );
                              },

                              child:
                                  (isCurrent && show)
                                      ? Obx(
                                        () => Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              _lrcMainAlignment[lrcAlignment],
                                          children: [
                                            _HighlightedWord(
                                                  text: "  ● ● ●  ",
                                                  progress:
                                                      _lyricController
                                                          .interludeProcess
                                                          .value /
                                                      100,
                                                  style: interludeLyricStyle,
                                                  strutStyle: strutStyle,
                                                  scale: 2,
                                                )
                                                .animate(
                                                  onPlay:
                                                      (controller) =>
                                                          controller.repeat(
                                                            reverse: true,
                                                          ),
                                                )
                                                .scaleXY(
                                                  end: _lrcScale,
                                                  duration: 1500.ms,
                                                  curve: Curves.easeInOut,
                                                  alignment:
                                                      _lrcScaleAlignment[lrcAlignment],
                                                ),
                                          ],
                                        ),
                                      )
                                      : const SizedBox.shrink(),
                            );
                          }),
                        ],
                      );

                      final Widget lyricLine = FractionallySizedBox(
                        widthFactor: 1,
                        child: content,
                      );

                      double sigma = 0;

                      if (!isPointerScrolling && !isCurrent) {
                        sigma =
                            (_lyricController.currentLineIndex.value - index)
                                .abs()
                                .clamp(0.0, 4.0)
                                .toDouble();
                      }

                      // double scrollDelay =
                      //     (_lyricController.currentLineIndex.value - index)
                      //         .abs()
                      //         .clamp(0.0, 10.0)
                      //         .toDouble();

                      return TextButton(
                        onPressed: () {
                          _audioController.audioSetPositon(
                            pos: startTime[index],
                          );
                        }.throttle(ms: 500),
                        style: TextButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: _borderRadius,
                          ),
                          padding: lrcPadding,
                          overlayColor: hoverColor,
                        ),

                        //此处 使用animate().blurXY() 可能会导致内存泄漏
                        child:
                            _settingController.useBlur.value
                                ? lyricLine.animate().blurXY(
                                  duration: 500.ms,
                                  begin: sigma - 1,
                                  end: sigma,
                                )
                                : lyricLine,

                        // .animate(
                        // key: ValueKey(_lyricController.currentLineIndex.value.hashCode),onComplete: (c)=>c.reverse())
                        // .moveY(
                        // duration: (300+50*((scrollDelay/10))).ms,
                        // curve: Curves.easeOut,
                        // delay: (20*scrollDelay).ms,
                        // begin: 0,
                        // end: -12+-8*((scrollDelay/10))),

                        // 以上动态改变宽度模拟弹簧效果
                      );
                    });
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
                          _lyricController.scrollToCenter();
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
                          _lyricController.scrollToCenter();
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
