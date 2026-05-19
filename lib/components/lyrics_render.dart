import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/theme_manager.dart';
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
const BorderRadius _borderRadius = BorderRadius.all(Radius.circular(4));
const double _ctrlBtnMinSize = 40.0;
const double _floatingY = -1.5;
const double _rippleThreshold = 1.5;

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
const _gradientStops = <double>[0.0, 0.333, 0.666];
const double _lrcScale = 1.1;

double _translateGradientScale = 2;

class _LyricsStyle {
  final SettingController _settingController = Get.find<SettingController>();
  ThemeService get _themeService => Get.find<ThemeService>();

  TextStyle get lyricStyle => generalTextStyle(
    size: _settingController.lrcFontSize.value,
    color: _themeService.darkTheme.colorScheme.onSecondaryContainer.withValues(
      alpha: _notPlayedDarkAlpha,
    ),
    weight: FontWeight.values[_settingController.lrcFontWeight.value],
  );

  TextStyle get tsLyricStyle =>
      lyricStyle.copyWith(fontSize: lyricStyle.fontSize! - 4);

  TextStyle get romaLyricStyle =>
      tsLyricStyle.copyWith(fontSize: lyricStyle.fontSize! - 4);

  TextStyle get interludeLyricStyle =>
      lyricStyle.copyWith(fontFamily: 'Microsoft YaHei Light');

  StrutStyle get strutStyle => StrutStyle(
    fontSize: _settingController.lrcFontSize.value.toDouble(),
    forceStrutHeight: true,
  );

  Color get hoverColor => _themeService.darkTheme.colorScheme.onSurface
      .withValues(alpha: _notPlayedDarkAlpha);

  Color? get mixColor => Color.lerp(
    _themeService.darkTheme.colorScheme.primary,
    Colors.white,
    _notPlayedLightAlpha,
  );
}

class _HighlightedWord extends StatefulWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;
  final List<Color> gradientColors;
  final double duartion;
  final double ripplesMaxScale;

  const _HighlightedWord({
    required this.text,
    required this.progress,
    required this.style,
    required this.strutStyle,
    required this.gradientColors,
    required this.duartion,
    required this.ripplesMaxScale,
  });

  @override
  State<_HighlightedWord> createState() => _HighlightedWordState();
}

class _HighlightedWordState extends State<_HighlightedWord> {
  // 只依赖 text，text 不变则不重算
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

  @override
  void initState() {
    super.initState();
    _initCachedValues();
  }

  @override
  void didUpdateWidget(_HighlightedWord old) {
    super.didUpdateWidget(old);
    // 只有 text 变化时才重算
    if (old.text != widget.text) {
      _initCachedValues();
    }
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
          transform: _ScaledTranslateGradientTransform(dx: dx),
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  Widget _transformScaleWrap(Widget child, {required double scale}) {
    // scale == 1.0 时跳过 Transform，减少不必要的开销
    if (scale == 1.0) return child;
    return Transform.scale(
      alignment: Alignment.bottomCenter,
      scale: scale,
      filterQuality: FilterQuality.low,
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

    // 预计算每个字的 scale 和 glowAlpha
    // 同时构建两层的 children，避免遍历两次
    final glowChildren = <Widget>[];
    final mainChildren = <Widget>[];

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
      final double scale =
          ui.lerpDouble(1.0, widget.ripplesMaxScale, animationCurve)!;
      final double glowAlpha = ui.lerpDouble(0.0, 0.5, animationCurve)!;

      // glow 层：字符本身透明，只显示 shadow
      // glowAlpha 接近 0 时跳过 shadow 计算，用透明占位保持布局稳定
      glowChildren.add(
        glowAlpha > 0.01
            ? _transformScaleWrap(
              Text(
                char,
                style: widget.style.copyWith(
                  color: widget.style.color?.withValues(alpha: 0),
                  shadows: [
                    Shadow(
                      color: widget.style.color!.withValues(
                        alpha: glowAlpha * 0.6,
                      ),
                      blurRadius: 4,
                    ),
                    Shadow(
                      color: widget.style.color!.withValues(alpha: glowAlpha),
                      blurRadius: 8,
                    ),
                  ],
                ),
                strutStyle: widget.strutStyle,
              ),
              scale: scale,
            )
            : Text(
              char,
              style: widget.style.copyWith(color: const Color(0x00000000)),
              strutStyle: widget.strutStyle,
            ),
      );

      // 主层：显示涟漪效果
      mainChildren.add(
        _transformScaleWrap(
          Text(
            char,
            style: widget.style.copyWith(
              color: widget.style.color?.withValues(alpha: 1),
            ),
            strutStyle: widget.strutStyle,
          ),
          scale: scale,
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // glow 层：辉光动画在 ShaderMask 外，Shadow 不受 dstIn 裁切
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: glowChildren,
        ),

        // 主层：ShaderMask + 缩放动画
        _shaderMaskWrap(
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: mainChildren,
          ),
        ),
      ],
    );
  }
}

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  const _ScaledTranslateGradientTransform({required this.dx});
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // final double scale=entry.value.duration>=1.0 ? 3:2; 动态 scale 视觉效果更好
    // 先将x轴扩大scale倍，然后平移x轴
    return Matrix4.identity()
      ..scale(_translateGradientScale, 1.0, 1.0)
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

  /// 微动特效包装器
  Widget _createFloatingAnimatedText(
    Widget child, {
    required double duration,
    required double delay,
  }) {
    return child.animate().custom(
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, ui.lerpDouble(0.0, _floatingY, value)!),
          filterQuality: FilterQuality.low,
          child: child,
        );
      },
      curve: Curves.easeInOut,
      duration: duration.ms,
      delay: delay.ms,
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
                final dura = entry.value.duration;
                _translateGradientScale = dura >= 1.0 ? 3 : 2;
                final floatingDuration = dura * (1000 * 1.8) + 50; // 加50ms的最小时长
                final floatingDelay = dura * (1000 * 0.2);

                if (wordIndex == currWordIndex) {
                  final List<Color> gradientColors = [
                    style.color!.withValues(alpha: _highLightAlpha),
                    style.color!.withValues(alpha: _highLightAlpha),
                    style.color!.withValues(
                      alpha:
                          wordIndex == 0
                              ? _currentAlpha - 0.15
                              : _currentAlpha, // 欺骗视觉，防止第一个词出现亮度突变
                    ),
                  ];
                  double ripplesMaxScale = 1.1;

                  if (dura >= _rippleThreshold) {
                    ripplesMaxScale += (0.1 *
                            ((dura - _rippleThreshold) /
                                (3 - _rippleThreshold))) // 最大3s
                        .clamp(0.0, 0.1);
                  }

                  // 正在唱的单词
                  return _createFloatingAnimatedText(
                    Obx(
                      () => _HighlightedWord(
                        text: word,
                        progress: lyricController.wordProgress.value,
                        style: style,
                        strutStyle: strutStyle,
                        gradientColors: gradientColors,
                        duartion: dura,
                        ripplesMaxScale: ripplesMaxScale,
                      ),
                    ),
                    duration: floatingDuration,
                    delay: floatingDelay,
                  );
                } else if (wordIndex < currWordIndex) {
                  // 已经唱完的单词
                  return _createFloatingAnimatedText(
                    Text(
                      word,
                      style: style.copyWith(
                        color: style.color?.withValues(alpha: _highLightAlpha),
                      ),
                      strutStyle: strutStyle,
                    ),
                    duration: floatingDuration,
                    delay: floatingDelay,
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
            curve: Curves.easeInOut,
            duration: const Duration(milliseconds: 600),
            builder: (_, color, __) {
              return _createTextWarp(color: color);
            },
          ).animate().custom(
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, ui.lerpDouble(_floatingY, 0.0, value)!),
                filterQuality: FilterQuality.low,
                child: child,
              );
            },
            curve: Curves.easeInCubic,
            duration: 600.ms,
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
  final _lyricsStyle = _LyricsStyle();

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
    Theme.of(context).colorScheme.onSecondaryContainer; // 用来更新颜色的触发器
    // 要将样式定义在 build 内而不是定义成 getter 否则动画会不连贯
    final hoverColor = _lyricsStyle.hoverColor;
    final mixColor = _lyricsStyle.mixColor;

    final dynamicPadding = context.width / 2 * (1 - 1 / _lrcScale);
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
                //将字体style定义在obx内以接收字体属性更改信号
                final lyricsStyle = _lyricsStyle.lyricStyle;
                final tsLyricStyle = _lyricsStyle.tsLyricStyle;
                final romaLyricStyle = _lyricsStyle.romaLyricStyle;
                final interludeLyricStyle = _lyricsStyle.interludeLyricStyle;
                final strutStyle = _lyricsStyle.strutStyle;

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
                      style: lyricsStyle.copyWith(
                        color: lyricsStyle.color?.withValues(
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
                final List<double> lineDuration =
                    parsedLrc.map((v) => v.nextTime - v.start).toList();

                Widget creatLyricItem(index) {
                  if ((lrcType == LyricFormat.lrc &&
                          lineList[index].isEmpty &&
                          translateList[index].isEmpty) ||
                      index == -1) {
                    return const SizedBox.shrink();
                  }
                  return _StaggeredLyricItem(
                    key: ValueKey(index),
                    index: index,
                    lyricController: _lyricController,
                    audioController: _audioController,
                    settingController: _settingController,
                    lrcType: lrcType,
                    lineText: lineList[index],
                    translateText: translateList[index],
                    romaText: romaList[index],
                    startTime: startTime[index],
                    lyricStyle: lyricsStyle,
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
                      lineDuration: lineDuration,
                      length: parsedLrc.length,
                      itemBuilder: (BuildContext context, int index) {
                        return creatLyricItem(index);
                      },
                    )
                    : Focus(
                      canRequestFocus: false,
                      descendantsAreFocusable: false,
                      child: ScrollablePositionedList.builder(
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
                      ),
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
                          _settingController.setShowTranslate();
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
                          _settingController.setShowRoma();
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
    Key? key,
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
          if (index == 0)
            _InterludeWidget(
              lyricController: lyricController,
              lrcAlignment: lrcAlignment,
              interludeLyricStyle: interludeLyricStyle,
              strutStyle: strutStyle,
              isCurrent: lyricController.currentLineIndex.value < 0,
            ),
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
              child: RepaintBoundary(
                child: _KaraOkLyricWidget(
                  text: lineText as List<WordEntry>,
                  style: lyricStyle,
                  isCurrent: isCurrent,
                  index: index,
                  lrcAlignmentIndex: lrcAlignment,
                  lyricController: lyricController,
                  strutStyle: strutStyle,
                ),
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
          _InterludeWidget(
            lyricController: lyricController,
            lrcAlignment: lrcAlignment,
            interludeLyricStyle: interludeLyricStyle,
            strutStyle: strutStyle,
            isCurrent: isCurrent,
          ),
        ],
      );

      final bool useBlur = settingController.useBlur.value;
      final int diff =
          (lyricController.currentLineIndex.value - index).abs(); // 视距

      // 是否需要挂载 ImageFiltered (当前行保持挂载防动画中断，其余行在视距内且未滚动时挂载)
      final bool applyFilter =
          useBlur && (isCurrent || (!isPointerScrolling && diff <= 10));

      Widget finalContent = content;

      if (applyFilter) {
        // 当前行模糊度为 0，其余行根据距离取 1~4
        final double targetSigma =
            isCurrent ? 0.0 : diff.clamp(0, 4).toDouble();

        finalContent = ImageFiltered(
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
    return Obx(() {
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
                    RepaintBoundary(
                      child: Obx(() {
                            _translateGradientScale = 2;
                            return _HighlightedWord(
                              text: "  ● ● ●  ",
                              progress: lyricController.interludeProcess.value,
                              style: interludeLyricStyle,
                              strutStyle: strutStyle,
                              gradientColors: [
                                interludeLyricStyle.color!.withValues(
                                  alpha: _highLightAlpha,
                                ),
                                interludeLyricStyle.color!.withValues(
                                  alpha: _highLightAlpha,
                                ),
                                interludeLyricStyle.color!,
                              ],
                              duartion: 0,
                              ripplesMaxScale: 1.1,
                            );
                          })
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
                                  alignment: _lrcScaleAlignment[lrcAlignment],
                                  scale: ui.lerpDouble(1.0, _lrcScale, value)!,
                                  filterQuality:
                                      FilterQuality
                                          .low, // 使用 FilterQuality.low 质量就已足够
                                  child: child,
                                ),
                          ),
                    ),
                  ],
                )
                : const SizedBox.shrink(),
      );
    });
  }
}
