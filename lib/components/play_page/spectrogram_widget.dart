import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:signals/signals_flutter.dart';
import 'package:zerobit_player/components/play_page/play_page_constant.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';
import 'package:zerobit_player/logger.dart';

/// 共享数据源专用的极简 TickerProvider
/// 插值动画在数据稳定后会自己停下来，不需要 TickerMode 的静音管理
class _FeedTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// 频谱数据源：集中负责「拉取 FFT -> 帧间插值 -> 通知重绘」
///
/// 所有可视化组件共享同一个实例（引用计数），即使同时挂载柱状频谱和波形图，
/// 也只有一个拉取定时器、一份插值缓冲区，开销和单个组件一样
class _SpectrumFeed {
  _SpectrumFeed._();

  static final _SpectrumFeed instance = _SpectrumFeed._();

  /// 两帧数据之间的插值时长
  static const Duration _lerpDuration = Duration(milliseconds: 100);

  /// 定时从后端拉取 FFT 数据
  /// 视觉流畅度由插值保证，而非拉取频率
  static const Duration _fetchInterval = Duration(milliseconds: 50);

  final AudioController _audioController = AudioController.instance;
  final _FeedTickerProvider _tickerProvider = _FeedTickerProvider();

  /// 帧信号：每次插值完成后自增通知订阅者
  final Signal<double> frame = signal(0.0);

  /// 插值起点：上一帧实际渲染的值
  Float32List _current = Float32List(0);

  /// 插值终点：最新一帧从后端拉取的 FFT 数据
  Float32List _target = Float32List(0);

  /// 当前实际渲染的值：_current 到 _target 之间插值的结果
  Float32List _display = Float32List(0);

  /// 供 painter 读取的数据，原地复用，不要缓存这个引用
  Float32List get values => _display;

  AnimationController? _animController;
  Timer? _fetchTimer;
  int _ref = 0; //引用计数

  /// 挂载动画并启动拉取和插值
  void attach() {
    if (_ref > 0) {
      _ref++;
      return;
    }
    _ref++;
    LoggerUni.i('频谱图资源已挂载 Ref: $_ref');
    _animController = AnimationController(
      vsync: _tickerProvider,
      duration: _lerpDuration,
    )..addListener(_onAnimationTick);

    _audioController.audioFFT.addListener(_onFFTUpdated);

    _fetchTimer = Timer.periodic(_fetchInterval, (_) {
      _audioController.getAudioFFt();
    });
  }

  /// 卸载动画并释放全部资源
  void detach() {
    _ref--;
    if (_ref > 0) {
      return;
    }
    LoggerUni.i('频谱图资源已释放 Ref: $_ref');
    // 先取消监听，再 dispose controller
    // 顺序重要：防止 cancel 期间还有回调触发
    _audioController.audioFFT.removeListener(_onFFTUpdated);
    _fetchTimer?.cancel();
    _fetchTimer = null;
    _animController?.dispose();
    _animController = null;

    _current = Float32List(0);
    _target = Float32List(0);
    _display = Float32List(0);
  }

  void _onFFTUpdated() {
    final controller = _animController;
    if (controller == null) return;

    final newFFT = _audioController.audioFFT.value;
    final int len = newFFT.length;
    if (len == 0) return;

    if (_display.length != len) {
      // 长度变化（首帧或采样点数改变）直接对齐，不做插值
      _current = Float32List(len);
      _target = Float32List(len);
      _display = Float32List(len);
      for (int i = 0; i < len; i++) {
        final double v = newFFT[i];
        _current[i] = v;
        _target[i] = v;
        _display[i] = v;
      }
      frame.value++;
      return;
    }

    for (int i = 0; i < len; i++) {
      _current[i] = _display[i];
      _target[i] = newFFT[i];
    }

    controller.forward(from: 0);
  }

  void _onAnimationTick() {
    final controller = _animController;
    if (controller == null) return;

    final current = _current;
    final target = _target;
    final display = _display;
    final int len = display.length;
    if (len == 0) return;

    final double t = controller.value;
    final double oneMinusT = 1.0 - t;
    for (int i = 0; i < len; i++) {
      display[i] = current[i] * oneMinusT + target[i] * t;
    }

    // 驱动信号更新
    frame.value++;
  }
}

/// 柱状频谱图
class SpectrogramWidget extends StatefulWidget {
  final LinearGradient gradient;
  final double lenth;
  final double barWidth;
  final double paddingWidth;
  const SpectrogramWidget({
    super.key,
    required this.gradient,
    required this.lenth,
    required this.barWidth,
    required this.paddingWidth,
  });

  @override
  State<SpectrogramWidget> createState() => SpectrogramWidgetState();
}

class SpectrogramWidgetState extends State<SpectrogramWidget> {
  final _SpectrumFeed _feed = _SpectrumFeed.instance;

  // 颜色缓存，颜色变化的时候更新 shader
  Color? _cachedColor;

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  ui.Shader? _cachedShader;
  Size _lastSize = Size.zero;

  /// 复用的端点缓冲区：存每根柱子的坐标 (x1, y1 , x2, y2)，一次 drawRawPoints 全部画完
  Float32List _points = Float32List(0);

  @override
  void initState() {
    super.initState();
    _feed.attach();
  }

  @override
  void dispose() {
    _cachedShader = null;
    _feed.detach();
    super.dispose();
  }

  ui.Shader _getShader(Size size) {
    if (_cachedShader == null ||
        _cachedColor == null ||
        size != _lastSize ||
        widget.gradient.colors[0] != _cachedColor) {
      _lastSize = size;
      _cachedColor = widget.gradient.colors[0];
      _cachedShader = widget.gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }
    return _cachedShader!;
  }

  Float32List _getPoints(int barCount) {
    final int need = barCount * 4;
    if (_points.length != need) {
      _points = Float32List(need);
    }
    return _points;
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(
      MediaQuery.sizeOf(context).width,
      PlayPageConstant.spectrogramHeight,
    );

    return RepaintBoundary(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: SignalCustomPaint(
          painter: _SpectrogramPainter(
            frame: _feed.frame,
            feed: _feed,
            points: _getPoints(widget.lenth.toInt()),
            shader: _getShader(size),
            length: widget.lenth.toInt(),
            barWidth: widget.barWidth,
            paddingWidth: widget.paddingWidth,
          ),
        ),
      ),
    );
  }
}

class _SpectrogramPainter extends SignalCustomPainter {
  final _SpectrumFeed feed;
  final Float32List points;
  final ui.Shader shader;
  final int length;
  final double barWidth;
  final double paddingWidth;

  _SpectrogramPainter({
    required Signal<double> frame,
    required this.feed,
    required this.points,
    required this.shader,
    required this.length,
    required this.barWidth,
    required this.paddingWidth,
  }) : super(signals: [frame]);

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    // 平头端点：高度为 0 的线段不会留下任何像素，省掉逐根的跳过判断
    ..strokeCap = StrokeCap.butt;

  @override
  void paint(Canvas canvas, Size size) {
    final fft = feed.values;
    if (fft.isEmpty) return;

    final int count = fft.length < length ? fft.length : length;
    if (count <= 0 || points.length < count * 4) return;

    final double height = size.height;

    // 设定柱子起始坐标
    for (int i = 0; i < count; i++) {
      final double x = i * barWidth + paddingWidth;
      final double h = fft[i] * height;
      final int o = i * 4;
      points[o] = x;
      points[o + 1] = height;
      points[o + 2] = x;
      points[o + 3] = h < 0.5 ? height : height - h;
    }

    _paint
      ..shader = shader
      ..strokeWidth = barWidth * 0.5;

    // 只取实际写入的那一段，避免 fft 变短时把上一帧残留的端点画出来
    canvas.drawRawPoints(
      ui.PointMode.lines,
      count * 4 == points.length
          ? points
          : Float32List.sublistView(points, 0, count * 4),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) =>
      old.shader != shader ||
      old.length != length ||
      old.barWidth != barWidth ||
      old.paddingWidth != paddingWidth;
}

/// 波形采样点数量：少于 FFT 的 256 个点，聚合之后曲线才够柔和
const int _wavePointCount = 56;

/// 波形占频谱高度的比例
const double _waveAmplitudeFactor = 1;

/// 辉光的模糊半径
const double _waveGlowSigma = 4.0;

/// 波形图
class WaveSpectrogramWidget extends StatefulWidget {
  final double lenth;
  final double width;
  final Color color;
  final bool isFill;

  const WaveSpectrogramWidget({
    super.key,
    required this.lenth,
    required this.width,
    this.isFill = false,
    required this.color,
  });

  @override
  State<WaveSpectrogramWidget> createState() => _WaveSpectrogramWidgetState();
}

class _WaveSpectrogramWidgetState extends State<WaveSpectrogramWidget> {
  final _SpectrumFeed _feed = _SpectrumFeed.instance;

  /// 复用的Path：通过 reset 复用底层缓冲区，避免每帧反复分配
  final Path _path = Path();

  /// 两套采样缓冲区：分别驱动主波形与辅波形
  final Float32List _amps1 = Float32List(_wavePointCount);
  final Float32List _amps2 = Float32List(_wavePointCount);

  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _waveGlowSigma);

  /// 主波形Shader 缓存
  ui.Shader? _fillShader1;
  ui.Shader? _lineShader1;
  ui.Shader? _glowShader1;

  /// 辅波形Shader 缓存
  ui.Shader? _fillShader2;
  ui.Shader? _lineShader2;
  ui.Shader? _glowShader2;

  Size _lastSize = Size.zero;
  Color? _cachedColor;

  @override
  void initState() {
    super.initState();
    _feed.attach();
  }

  @override
  void dispose() {
    _feed.detach();
    _fillShader1 = null;
    _lineShader1 = null;
    _glowShader1 = null;
    _fillShader2 = null;
    _lineShader2 = null;
    _glowShader2 = null;
    super.dispose();
  }

  /// 构建主波与辅波的双套着色器
  void _ensureShaders(Size size, double left, double width) {
    final Color color = widget.color;
    if (_fillShader1 != null && size == _lastSize && color == _cachedColor) {
      return;
    }
    _lastSize = size;
    _cachedColor = color;

    final Offset from = Offset(left, 0);
    final Offset to = Offset(left + width, 0);
    const stops = <double>[0.0, 0.2, 0.8, 1.0];

    ui.Shader buildShader(double alpha) {
      final solid = color.withValues(alpha: alpha);
      final clear = color.withValues(alpha: 0.0);
      return ui.Gradient.linear(from, to, [clear, solid, solid, clear], stops);
    }

    // 主波形着色器
    _fillShader1 = buildShader(0.3);
    _lineShader1 = buildShader(0.8);
    _glowShader1 = buildShader(0.4);

    // 辅波形着色器
    _fillShader2 = buildShader(0.15);
    _lineShader2 = buildShader(0.4);
    _glowShader2 = buildShader(0.2);
  }

  /// 分别对两组波形进行差异化频段采样与平滑计算
  void _sampleDualAmplitudes(Float32List fft, int usable) {
    final double binSize = usable / _wavePointCount;

    // 主波：线性映射中低频
    for (int j = 0; j < _wavePointCount; j++) {
      int start = (j * binSize).floor();
      int end = ((j + 1) * binSize).ceil();
      if (end > usable) end = usable;
      if (end <= start) end = start + 1 <= usable ? start + 1 : usable;

      double sum = 0.0;
      int count = 0;
      for (int k = start; k < end; k++) {
        sum += fft[k];
        count++;
      }
      double v = count == 0 ? 0.0 : sum / count;
      //v *= 1.0 + 0.8 * (j / (_wavePointCount - 1)); // 不需要再补偿高频部分，BASS端已经补偿过
      _amps1[j] = v > 1.0 ? 1.0 : v;
    }

    // 辅波：映射中高频
    for (int j = 0; j < _wavePointCount; j++) {
      final double ratio = j / (_wavePointCount - 1);
      // 使用指数拉伸让其峰值在空间分布上错开
      final double warped = math.pow(ratio, 0.4).toDouble();
      int start = (warped * usable * 0.95).floor();
      int end = start + binSize.ceil() + 1;
      if (end > usable) end = usable;
      if (start >= end) start = (end - 1 >= 0) ? end - 1 : 0;

      double sum = 0.0;
      int count = 0;
      for (int k = start; k < end; k++) {
        sum += fft[k];
        count++;
      }
      double v = count == 0 ? 0.0 : sum / count;
      //v *= 0.95 + 0.5 * ratio;
      _amps2[j] = v > 1.0 ? 1.0 : v;
    }

    // 主波进行平滑
    _smoothAmplitudes(_amps1, 0.25);

    // 辅波进行两轮平滑更柔和
    _smoothAmplitudes(_amps2, 0.35);
    _smoothAmplitudes(_amps2, 0.25);
  }

  /// 平滑幅值，以免出现过多山脊
  void _smoothAmplitudes(Float32List amps, double factor) {
    double prev = amps[0];
    for (int j = 1; j < _wavePointCount - 1; j++) {
      final double cur = amps[j];
      amps[j] = (prev + cur * 2.0 + amps[j + 1]) * factor;
      prev = cur;
    }
  }

  /// 绘制一条波形
  void _renderSingleWave({
    required Canvas canvas,
    required Float32List amps,
    required double left,
    required double step,
    required double baseY,
    required double maxAmp,
    required ui.Shader? fillShader,
    required ui.Shader? lineShader,
    required ui.Shader? glowShader,
  }) {
    final path = _path..reset();

    double x(int j) => left + step * j;
    double y(int j) => baseY - amps[j] * maxAmp;

    void buildWaveRidge() {
      path.moveTo(x(0), y(0));
      for (int j = 1; j < _wavePointCount - 1; j++) {
        path.quadraticBezierTo(
          x(j),
          y(j),
          (x(j) + x(j + 1)) * 0.5,
          (y(j) + y(j + 1)) * 0.5,
        );
      }
      final int last = _wavePointCount - 1;
      path.lineTo(x(last), y(last));
    }

    if (widget.isFill && fillShader != null) {
      buildWaveRidge();
      final int last = _wavePointCount - 1;
      path.lineTo(x(last), baseY);
      path.lineTo(x(0), baseY);
      path.close();
      canvas.drawPath(path, _fillPaint..shader = fillShader);
    }

    path.reset();
    buildWaveRidge();

    if (glowShader != null && !widget.isFill) {
      canvas.drawPath(path, _glowPaint..shader = glowShader);
    }
    if (lineShader != null && !widget.isFill) {
      canvas.drawPath(path, _linePaint..shader = lineShader);
    }
  }

  void _paintWave(Canvas canvas, Size size, double _) {
    final fft = _feed.values;
    if (fft.isEmpty) return;

    final int limit = widget.lenth.toInt();
    final int usable = fft.length < limit ? fft.length : limit;
    if (usable < _wavePointCount) return;

    final double left = widget.width * 0.03;
    final double width = widget.width * (1 - 0.03 * 2);
    if (width <= 0) return;

    _ensureShaders(size, left, width);
    _sampleDualAmplitudes(fft, usable);

    final double step = width / (_wavePointCount - 1);
    final double baseY = size.height;
    final double maxAmp = size.height * _waveAmplitudeFactor;

    // 主波形
    _renderSingleWave(
      canvas: canvas,
      amps: _amps1,
      left: left,
      step: step,
      baseY: baseY,
      maxAmp: maxAmp,
      fillShader: _fillShader1,
      lineShader: _lineShader1,
      glowShader: _glowShader1,
    );

    // 辅波形
    _renderSingleWave(
      canvas: canvas,
      amps: _amps2,
      left: left,
      step: step,
      baseY: baseY,
      maxAmp: maxAmp,
      fillShader: _fillShader2,
      lineShader: _lineShader2,
      glowShader: _glowShader2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(
      MediaQuery.sizeOf(context).width,
      PlayPageConstant.spectrogramHeight,
    );

    return RepaintBoundary(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: SignalPainterWidget(progress: _feed.frame, painter: _paintWave),
      ),
    );
  }
}
