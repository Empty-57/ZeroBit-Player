import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/tools/func_extension.dart';
import 'package:zerobit_player/tools/general_style.dart';

import '../getxController/audio_ctrl.dart';
import '../getxController/lyric_ctrl.dart';
import '../getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';

const double _audioCtrlBarHeight = 96;
const double _controllerBarHeight = 48;
const double _highLightAlpha = 0.8;
const _borderRadius = BorderRadius.all(Radius.circular(4));
final AudioController _audioController = Get.find<AudioController>();
final SettingController _settingController = Get.find<SettingController>();
final LyricController _lyricController = Get.find<LyricController>();

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

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  const _ScaledTranslateGradientTransform({required this.dx});
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // 先将x轴扩大2倍，然后平移x轴 其实应该是扩大3倍，但是2倍视觉效果更好
    return Matrix4.diagonal3Values(2.0, 1.0, 1.0)..translate(dx, 0.0, 0.0);
  }
}

class LyricsRender extends StatefulWidget {
  const LyricsRender({super.key});

  @override
  State<LyricsRender> createState() => _LyricsRenderState();
}

class _LyricsRenderState extends State<LyricsRender> {
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

  Widget lrcLyric<T>({
    required T text,
    required TextStyle style,
    required bool isCurrent,
  }) {
    final text_ = text as String;
    return Obx(
      () => Text(text_, style: style, softWrap: true)
          .animate(target: isCurrent ? 1 : 0)
          .custom(
            duration: 300.ms,
            builder: (_, value, _) {
              return Text(
                text_,
                style: style.copyWith(
                  color: Color.lerp(
                    style.color,
                    style.color?.withValues(alpha: _highLightAlpha),
                    value,
                  ),
                ),
                softWrap: true,
              );
            },
          )
          .scale(
            alignment:
                _lrcScaleAlignment[_settingController.lrcAlignment.value],
            begin: Offset(1.0, 1.0),
            end: Offset(_lrcScale, _lrcScale),
            duration: 300.ms,
            curve: Curves.easeInOutQuad,
          ),
    );
  }

  Widget karaOkLyric<T>({
    required T text,
    required TextStyle style,
    required bool isCurrent,
  }) {
    final text_ = text as List<WordEntry>;

    return Obx(
      () => Wrap(
            children:
                text_.asMap().entries.map((v) {
                  final entry = v.value;
                  final wordIndex = v.key;
                  final currWordIndex = _lyricController.currentWordIndex.value;

                  if (isCurrent && wordIndex < currWordIndex) {
                    return Text(
                      entry.lyricWord,
                      style: style.copyWith(
                        color: style.color?.withValues(alpha: _highLightAlpha),
                      ),
                      softWrap: true,
                    );
                  }

                  if ((isCurrent && currWordIndex == wordIndex)) {
                    return RepaintBoundary(
                      child: Obx(() {
                      final progress =
                          _lyricController.wordProgress.value / 100;
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          /// 颜色平均分三段：高亮区 过渡区 透明区
                          /// 在动画开始的时候，覆盖到 Text 上的应该是透明区，应该先把整个遮罩层应该向左移动
                          /// 但是因为遮罩层放大了3倍，所以应该用 -0.666 * bounds.width 得到透明区位置，负号为向左
                          /// 随着 progress 增大 遮罩会逐渐向右移动
                          final double dx =
                              (-0.666 * bounds.width) * (1 - progress);
                          final Gradient gradient = LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              style.color!.withValues(alpha: _highLightAlpha),
                              style.color!.withValues(alpha: _highLightAlpha),
                              style.color!,
                            ],
                            stops: const [0.0, 0.333, 0.666],
                            // 平移遮罩层
                            transform: _ScaledTranslateGradientTransform(
                              dx: dx,
                            ),
                          );
                          return gradient.createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Text(
                          entry.lyricWord,
                          style: style.copyWith(
                            color: style.color?.withValues(alpha: 1),
                          ),
                          softWrap: true,
                        ),
                      );
                    }),
                    );
                  }

                  return Text(
                    entry.lyricWord,
                    style: style.copyWith(color: style.color),
                    softWrap: true,
                  );
                }).toList(),
          )
          .animate(target: isCurrent ? 1 : 0)
          .scale(
            alignment:
                _lrcScaleAlignment[_settingController.lrcAlignment.value],
            begin: Offset(1.0, 1.0),
            end: Offset(_lrcScale, _lrcScale),
            duration: 300.ms,
            curve: Curves.easeInOutQuad,
          ),
    );
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

    final hoverColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.2);

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

          late final Widget Function<T>({
            required T text,
            required TextStyle style,
            required bool isCurrent,
          })
          lyricWidget;
          if (lrcType == LyricFormat.lrc) {
            lyricWidget = lrcLyric;
          } else {
            lyricWidget = karaOkLyric;
          }

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
            itemBuilder: (BuildContext context, int index) {
              final lrcEntry = parsedLrc[index];

              if ((lrcType == LyricFormat.lrc &&
                      lrcEntry.lyricText.isEmpty &&
                      lrcEntry.translate.isEmpty) ||
                  index == -1) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: () {
                  _audioController.audioSetPositon(pos: lrcEntry.start);
                }.throttle(ms: 500),
                style: TextButton.styleFrom(
                  shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  overlayColor: hoverColor,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: Obx(() {
                    final isCurrent =
                        index == _lyricController.currentLineIndex.value;
                    final isPointerScrolling =
                        _lyricController.isPointerScroll.value;

                    final Widget content = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment:
                          _lrcAlignment[_settingController.lrcAlignment.value],
                      children: [
                        lyricWidget(
                          text: lrcEntry.lyricText,
                          style: lyricStyle,
                          isCurrent: isCurrent,
                        ),
                        if (lrcEntry.translate.isNotEmpty)
                          Text(
                            lrcEntry.translate,
                            style: lyricStyle,
                            softWrap: true,
                          ),
                      ],
                    );

                    // 此处有个开关模糊功能 isBlurEnabled
                    // if ( isPointerScrolling || isCurrent) {
                    //   return content;
                    // }

                    double sigma =
                        (_lyricController.currentLineIndex.value - index)
                            .abs()
                            .clamp(0.0, 4.0)
                            .toDouble();
                    if (isPointerScrolling || isCurrent) {
                      sigma = 0;
                    }

                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: sigma,
                        sigmaY: sigma,
                      ),
                      child: RepaintBoundary(child: content),
                    );
                  }),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
