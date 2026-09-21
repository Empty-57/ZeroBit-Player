import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zerobit_player/components/play_page/play_page_constant.dart';
import 'package:zerobit_player/controller/audio_ctrl.dart';

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

class SpectrogramWidgetState extends State<SpectrogramWidget>
    with SingleTickerProviderStateMixin {
  final AudioController _audioController = AudioController.instance;

  // 颜色缓存，颜色变化的时候更新painter
  Color? _cachedColor;
  late final AnimationController _animController;

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  List<double> _currentFFT = const [];

  /// 插值终点：最新一帧从后端拉取的 FFT 数据
  List<double> _targetFFT = const [];

  /// 当前实际渲染的值：_currentFFT 到 _targetFFT 之间插值的结果
  List<double> _displayFFT = const [];

  /// 缓存的 Shader，尺寸不变时复用，避免每帧重建
  Shader? _cachedShader;
  Size _lastSize = Size.zero;

  /// 防止 dispose 后异步回调仍然执行的保护标志
  bool _isDisposed = false;

  /// 定时从后端拉取 FFT 数据
  /// 不用 Ticker（每帧触发）是因为音频数据不需要和屏幕刷新率同步
  /// 视觉流畅度由 _animController 的插值保证，而非拉取频率
  Timer? _fetchTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _animController.addListener(_onAnimationTick);

    _audioController.audioFFT.addListener(_onFFTUpdated);

    _fetchTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _audioController.getAudioFFt();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    // 先取消监听，再 dispose controller
    // 顺序重要：防止 cancel 期间还有回调触发
    _audioController.audioFFT.removeListener(_onFFTUpdated);
    _fetchTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onFFTUpdated() {
    if (_isDisposed || !mounted) return;
    final newFFT = _audioController.audioFFT.value;

    final int len = newFFT.length;

    if (_currentFFT.length != len) {
      _currentFFT = List<double>.filled(len, 0.0);
    }
    if (_targetFFT.length != len) {
      _targetFFT = List<double>.filled(len, 0.0);
    }

    if (_displayFFT.isEmpty || _displayFFT.length != len) {
      _displayFFT = List<double>.filled(len, 0.0);
      for (int i = 0; i < len; i++) {
        _currentFFT[i] = newFFT[i];
        _displayFFT[i] = newFFT[i];
        _targetFFT[i] = newFFT[i];
      }
    } else {
      for (int i = 0; i < len; i++) {
        _currentFFT[i] = _displayFFT[i];
        _targetFFT[i] = newFFT[i];
      }
    }

    _animController.forward(from: 0);
  }

  void _onAnimationTick() {
    if (_isDisposed || !mounted || _targetFFT.isEmpty) return;
    final double t = _animController.value;
    final int len = _currentFFT.length < _targetFFT.length
        ? _currentFFT.length
        : _targetFFT.length;

    if (_displayFFT.length != len) {
      _displayFFT = List<double>.filled(len, 0.0);
    }

    final double oneMinusT = 1.0 - t;
    for (int i = 0; i < len; i++) {
      _displayFFT[i] = _currentFFT[i] * oneMinusT + _targetFFT[i] * t;
    }
  }

  Shader _getShader(Size size) {
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (_, __) {
          if (_displayFFT.isEmpty) return const SizedBox.shrink();
          final size = Size(
            MediaQuery.of(context).size.width,
            PlayPageConstant.spectrogramHeight,
          );
          return CustomPaint(
            size: size,
            painter: _SpectrogramPainter(
              fft: _displayFFT,
              shader: _getShader(size),
              length: widget.lenth,
              barWidth: widget.barWidth,
              paddingWidth: widget.paddingWidth,
              version: _animController.value,
            ),
          );
        },
      ),
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  final List<double> fft;
  final Shader shader;
  final double length;
  final double barWidth;
  final double paddingWidth;
  final double version;

  _SpectrogramPainter({
    required this.fft,
    required this.shader,
    required this.length,
    required this.barWidth,
    required this.paddingWidth,
    required this.version,
  });

  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (fft.isEmpty) return;

    _paint.shader = shader;

    final int maxBars = length.toInt();
    final int count = fft.length < maxBars ? fft.length : maxBars;

    for (int i = 0; i < count; i++) {
      final double height = fft[i] * PlayPageConstant.spectrogramHeight;
      if (height < 0.5) continue;

      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth + paddingWidth,
          PlayPageConstant.spectrogramHeight - height,
          barWidth * 0.5,
          height,
        ),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) {
    return old.version != version || old.shader != shader;
  }
}
