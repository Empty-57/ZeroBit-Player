import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:zerobit_player/components/lyric/lyric_arg_constants.dart';

class _ScaledTranslateGradientTransform extends GradientTransform {
  final double dx;
  final double translateGradientScale;
  const _ScaledTranslateGradientTransform({
    required this.dx,
    required this.translateGradientScale,
  });

  static final Matrix4 _sharedMatrix = Matrix4.zero();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // final double scale=entry.value.duration>=1.0 ? 3:2; 动态 scale 视觉效果更好
    // 先将x轴扩大scale倍，然后平移x轴

    final storage = _sharedMatrix.storage;

    // xyz缩放
    storage[0] = translateGradientScale; // x
    storage[5] = 1.0; // y
    storage[10] = 1.0; // z
    storage[15] = 1.0; // w

    // x平移
    storage[12] = translateGradientScale * dx;
    return _sharedMatrix;
  }
}

class HighlightedWord extends StatefulWidget {
  final String text;
  final double progress;
  final TextStyle style;
  final StrutStyle strutStyle;
  final List<Color> gradientColors;
  final double duartion;
  final double ripplesScaleMax;
  final double glowAlphaMax;
  final double translateGradientScale;

  const HighlightedWord({
    super.key,
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
  State<HighlightedWord> createState() => HighlightedWordState();
}

class HighlightedWordState extends State<HighlightedWord> {
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
  late TextStyle _normalStyle;

  // 提取基础颜色以备 shadow 计算使用
  late Color _baseColor;

  @override
  void initState() {
    super.initState();
    _initCachedValues();
    _initStyles();
  }

  @override
  void didUpdateWidget(HighlightedWord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _initCachedValues();
    }
    if (oldWidget.style != widget.style) {
      _initStyles();
    }
  }

  void _initStyles() {
    _normalStyle = widget.style.copyWith(
      color: widget.style.color?.withValues(alpha: 1),
    );
    _baseColor = widget.style.color ?? Colors.white;
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
          stops: LyricConstants.gradientStops,
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
    if (widget.duartion < LyricConstants.rippleThreshold) {
      // 小于阈值则不应用涟漪效果
      return _shaderMaskWrap(
        Text(widget.text, style: _normalStyle, strutStyle: widget.strutStyle),
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
