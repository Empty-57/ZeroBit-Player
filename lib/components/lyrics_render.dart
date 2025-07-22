import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import '../tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/lyric_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const double _highLightAlpha = 0.8;
const _borderRadius = BorderRadius.all(Radius.circular(4));

const _lrcAlignment = [
  CrossAxisAlignment.start,
  CrossAxisAlignment.center,
  CrossAxisAlignment.end,
];
const _lrcScaleAlignment = [
  Alignment.centerLeft,
  Alignment.center,
  Alignment.centerRight,
];
const _lrcScale = 1.1;

class _HighlightedWord extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;

  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.style,
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
          transform: _ScaledTranslateGradientTransform(dx: dx),
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Text(
        text,
        style: style.copyWith(color: style.color?.withValues(alpha: 1)),
      ),
    );
  }
}

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  const _ScaledTranslateGradientTransform({required this.dx});
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // 先将x轴扩大2倍，然后平移x轴 其实应该是扩大3倍，但是2倍视觉效果更好
    return Matrix4.identity()
      ..scale(2.0, 1.0, 1.0)
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
    required this.textAlign
  });

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style, textAlign: textAlign,softWrap: true)
        .animate(target: isCurrent ? 1 : 0)
        .custom(
          duration: 300.ms,
          builder: (_, value, child) {
            return Text(
              text,
              style: style.copyWith(
                color: Color.lerp(
                  style.color,
                  style.color?.withValues(alpha: _highLightAlpha),
                  value,
                ),
              ),
              textAlign: textAlign,
              softWrap: true,
            );
          },
        )
        .scale(
          alignment: _lrcScaleAlignment[lrcAlignmentIndex],
          begin: const Offset(1.0, 1.0),
          end: const Offset(_lrcScale, _lrcScale),
          duration: 300.ms,
          curve: Curves.easeInOutQuad,
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
  final TextAlign textAlign;

  const _KaraOkLyricWidget({
    required this.text,
    required this.style,
    required this.isCurrent,
    required this.index,
    required this.lrcAlignmentIndex,
    required this.lyricController,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isCurrent) {
      content = Obx(() {
        final currWordIndex = lyricController.currentWordIndex.value;
        return Wrap(
          alignment: lrcAlignmentIndex==0? WrapAlignment.start:lrcAlignmentIndex==1? WrapAlignment.center:WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children:
              text.asMap().entries.map((entry) {
                final wordIndex = entry.key;
                final word = entry.value.lyricWord;

                if (wordIndex == currWordIndex) {
                  return Obx(
                    () => _HighlightedWord(
                      text: word,
                      progress: lyricController.wordProgress.value / 100.0,
                      style: style,
                    ),
                  );
                } else if (wordIndex < currWordIndex) {
                  return Text(
                    word,
                    style: style.copyWith(
                      color: style.color?.withValues(alpha: _highLightAlpha),
                    ),
                  );
                } else {
                  return Text(word, style: style);
                }
              }).toList(),
        );
      });
    } else {
      final plainText = text.map((e) => e.lyricWord).join();
      content = Obx(() {
        final currentLineIndex = lyricController.currentLineIndex.value;
        if (currentLineIndex - index == 1) {
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: style.color?.withValues(alpha: _highLightAlpha),
              end: style.color,
            ),
            duration: const Duration(milliseconds: 300),
            builder:
                (_, color, __) => Text(
                  plainText,
                  style: style.copyWith(color: color),
                  softWrap: true,
                  textAlign: textAlign
                ),
          );
        }
        return Text(plainText, style: style, softWrap: true,textAlign: textAlign,);
      });
    }

    return Animate(
      target: isCurrent ? 1 : 0,
      effects: [
        ScaleEffect(
          alignment: _lrcScaleAlignment[lrcAlignmentIndex],
          begin: const Offset(1.0, 1.0),
          end: const Offset(_lrcScale, _lrcScale),
          duration: 300.ms,
          curve: Curves.easeInOutQuad,
        ),
      ],
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
      size: 24,
      color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(
        alpha: _settingController.themeMode.value == 'dark' ? 0.2 : 0.2,
      ),
      weight: FontWeight.w600,
    );

    const strutStyle = StrutStyle(
      fontSize: 24,
      forceStrutHeight: true,
    );

    final hoverColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.2);
    final dynamicPadding = context.width / 2 * (1 - 1 / _lrcScale);

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _lyricController.pointerScroll();
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Obx(() {
          final currentLyrics = _audioController.currentLyrics.value;
          final parsedLrc = currentLyrics?.parsedLrc;
          final lrcPadding = EdgeInsets.only(
            top: 16,
            bottom: 16,
            left:
                _settingController.lrcAlignment.value == 2
                    ? dynamicPadding
                    : _settingController.lrcAlignment.value == 1
                    ? dynamicPadding / 2
                    : 16,
            right:
                _settingController.lrcAlignment.value == 0
                    ? dynamicPadding
                    : _settingController.lrcAlignment.value == 1
                    ? dynamicPadding / 2
                    : 16,
          );

          final textAlign= _settingController.lrcAlignment.value==0?TextAlign.left:_settingController.lrcAlignment.value==1?TextAlign.center:TextAlign.right;

          if (currentLyrics == null ||
              parsedLrc is! List<LyricEntry> ||
              parsedLrc.isEmpty) {
            return Center(
              child: Text(
                "无歌词",
                style: lyricStyle.copyWith(
                  color: lyricStyle.color?.withValues(alpha: _highLightAlpha),
                ),
              ),
            );
          }

          final String lrcType = currentLyrics.type;

          return ScrollablePositionedList.builder(
            initialScrollIndex: 0,
            initialAlignment: 0.5,
            itemCount: parsedLrc.length,
            itemScrollController: _lyricController.lrcViewScrollController,
            padding: EdgeInsets.symmetric(
              vertical:
                  (context.height -
                      _audioCtrlBarHeight -
                      _controllerBarHeight) /
                  2,
            ),
            minCacheExtent: 48.0,
            itemBuilder: (BuildContext context, int index) {
              final lrcEntry = parsedLrc[index];

              if ((lrcType == LyricFormat.lrc &&
                      lrcEntry.lyricText.isEmpty &&
                      lrcEntry.translate.isEmpty) ||
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
                  crossAxisAlignment:
                      _lrcAlignment[_settingController.lrcAlignment.value],
                  children: [
                    if (lrcType == LyricFormat.lrc)
                      _LrcLyricWidget(
                        text: lrcEntry.lyricText as String,
                        style: lyricStyle,
                        isCurrent: isCurrent,
                        lrcAlignmentIndex:
                            _settingController.lrcAlignment.value,
                        textAlign: textAlign,
                      )
                    else
                      _KaraOkLyricWidget(
                        text: lrcEntry.lyricText as List<WordEntry>,
                        style: lyricStyle,
                        isCurrent: isCurrent,
                        index: index,
                        lrcAlignmentIndex:
                            _settingController.lrcAlignment.value,
                        lyricController: _lyricController,
                        textAlign: textAlign,
                        strutStyle: strutStyle,
                      ),
                    if (lrcEntry.translate.isNotEmpty)
                      Text(
                        lrcEntry.translate,
                        style: lyricStyle,
                        softWrap: true,
                        textAlign: textAlign,
                      ),
                  ],
                );

                final Widget lyricLine = RepaintBoundary(
                  child: FractionallySizedBox(widthFactor: 1, child: content),
                );

                double sigma =
                    (_lyricController.currentLineIndex.value - index)
                        .abs()
                        .clamp(0.0, 4.0)
                        .toDouble();
                // 此有模糊开关
                if (isPointerScrolling || isCurrent) {
                  sigma = 0;
                }

                return TextButton(
                  onPressed: () {
                    _audioController.audioSetPositon(pos: lrcEntry.start);
                  }.throttle(ms: 500),
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: _borderRadius,
                    ),
                    padding: lrcPadding,
                    overlayColor: hoverColor,
                  ),

                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: lyricLine,
                  ),
                );
              });
            },
          );
        }),
      ),
    );
  }
}
