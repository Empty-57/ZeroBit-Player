import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../controller/audio_ctrl.dart';
import '../logger.dart';

class FFTFeed {
  FFTFeed._();
  static final FFTFeed instance = FFTFeed._();

  final _audioController = AudioController.instance;
  static const Duration _fetchInterval = Duration(
    milliseconds: 50,
  ); //拉取 FFT 的间隔时间
  Timer? _fetchTimer;
  int _ref = 0; //引用计数

  ValueNotifier<List<double>> get fft => _audioController.audioFFT;

  void attach() {
    if (_ref++ > 0) {
      return;
    }
    _ref++;
    LoggerUni.i('FFT数据流已连接 Ref: $_ref');
    _fetchTimer = Timer.periodic(_fetchInterval, (_) {
      _audioController.getAudioFFt();
    });
  }

  void detach() {
    if (--_ref > 0) {
      return;
    }
    LoggerUni.i('FFT数据流已释放 Ref: $_ref');
    _fetchTimer?.cancel();
    _fetchTimer = null;
  }
}
