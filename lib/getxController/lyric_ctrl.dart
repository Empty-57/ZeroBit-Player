import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:zerobit_player/components/spring_list_view.dart';
import 'package:zerobit_player/getxController/setting_ctrl.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'audio_ctrl.dart';

class LyricController extends GetxController {
  final currentMs20 = 0.0.obs;
  final lrcViewScrollController = ItemScrollController();
  final isPointerScroll = false.obs;
  final AudioController _audioController = Get.find<AudioController>();
  final SpringController _springConntroller = Get.find<SpringController>();
  final SettingController _settingController = Get.find<SettingController>();

  final currentLineIndex = (-1).obs;
  final currentWordIndex = (0).obs;

  final wordProgress = 0.0.obs;
  double _wordProgressIncrement = 0;

  final showInterlude = false.obs;

  final interludeProcess = 0.0.obs;

  double _interval = 0; // 歌词行间隔值

  int _wordsLen = 0; // 当前行长度

  static const double _showIntervalLowLimit =
      0.95; // 间奏进度下限, 最后一个词过渡到 95% 就开始显示间奏, 给出场动画稍微预留一些时间
  static const double _showIntervalHighLimit =
      0.95; // 间奏进度上限, 间奏完成到 95% 就开始退出间奏, 给下一句歌词入场一些预留时间
  static const int  _intervalThreshold = 4; // 间奏阈值, 超过此秒数则为间奏

  List<WordEntry>? _currentLine; // 当前行信息

  Timer? _debounceTimer; // 防抖计时器
  Timer? _delayTimer;

  late final Worker _msWorker;

  @override
  void onClose() {
    _msWorker.dispose();

    _debounceTimer?.cancel();
    _delayTimer?.cancel();
    _currentLine = null;
    super.onClose();
  }

  // 更新 _currentWord, _currentLine, _interval, _threshold
  void _updateLyricsInfo({required bool updateLineOnly}) {
    if ((_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) ==
        LyricFormat.lrc) {
      return;
    }

    if (updateLineOnly) {
      final lyrics = _audioController.currentLyrics.value?.parsedLrc;
      final lineIndex = currentLineIndex.value;
      if (lyrics == null || lineIndex < 0 || lineIndex >= lyrics.length) {
        return;
      }
      _currentLine = lyrics[lineIndex].lyricText;

      final rowCurrentLine = lyrics[lineIndex];
      final lastWord = _currentLine![_currentLine!.length - 1];
      if (_audioController.currentLyrics.value?.type == LyricFormat.byWordLrc) {
        _interval =
            rowCurrentLine.nextTime -
            lastWord.start; // byWordLrc 每一行最后一个词为空白符 代表本行的结束时间
      } else {
        _interval =
            rowCurrentLine.nextTime - (lastWord.start + lastWord.duration);
      }

      _wordsLen = _currentLine!.length;
    } else {
      final line = _currentLine;
      if (line == null) return;

      final wordIndex = currentWordIndex.value.clamp(0, line.length - 1);
      if (wordIndex >= line.length) return;

      final word = line[wordIndex];

      // 增量计算: loopTime/duration
      // 字持续时间: duration(s) 轮询周期: loopTime=0.02(s)
      final duration = word.duration;
      if (duration <= 0) {
        _wordProgressIncrement = 0;
        return;
      }

      final ms = currentMs20.value;

      final diffTime = ms - word.start;
      _wordProgressIncrement =
          diffTime >= 0.02
              ? 0.02 /
                  (duration - diffTime) // 校准分支 误差大于一个周期就校准
              : 0.02 / duration; // 正常分支
    }
  }

  // 判断是否显示间奏/前奏
  void _updateInterludeState() {
    final lyrics = _audioController.currentLyrics.value;
    final parsedLrc = lyrics?.parsedLrc;
    if (parsedLrc == null || parsedLrc.isEmpty) {
      showInterlude.value = false;
      return;
    }
    final lineIndex = currentLineIndex.value;

    // 前奏
    if (lineIndex < 0) {
      _interval = parsedLrc[0].start;
      final show =
          _interval > _intervalThreshold &&
          interludeProcess.value <= _showIntervalHighLimit - 0.1 &&
          _interval < 60; // 超过1分钟认为歌词时间轴有误
      showInterlude.value = show;
      if (show) interludeProcess.value += 0.02 / _interval;
      return;
    }

    // 间奏
    if (currentWordIndex.value != _wordsLen - 1) {
      showInterlude.value = false;
      return;
    }

    final interlude = interludeProcess.value;
    final double threshold =
        lyrics!.type == LyricFormat.byWordLrc
            ? 0 // byWordLrc 每一行最后一个词为空白符 代表本行的结束时间 不需要预设下限 本行的结束时间就是间奏开始时间
            : _showIntervalLowLimit;

    final show =
        _interval >= _intervalThreshold &&
        wordProgress.value >= threshold && // 这个词过渡完才允许显示间
        interlude <=
            _showIntervalHighLimit && //<= _showIntervalHighLimit 是为了给动画退场一点时间
        lineIndex < parsedLrc.length - 1;

    showInterlude.value = show;
    if (show) interludeProcess.value += 0.02 / _interval; // 算法同词增量计算
  }

  @override
  void onInit() {
    super.onInit();
    // 更新词进度
    _msWorker = ever(currentMs20, (_) {
      final newLineIndex = _findLrcPos(
        time: currentMs20.value,
        lyrics: _audioController.currentLyrics.value?.parsedLrc,
        hint: currentLineIndex.value,
      );
      if (newLineIndex != currentLineIndex.value) {
        _interval = 0;
        wordProgress.value = 0;
        currentLineIndex.value = newLineIndex;
        _updateLyricsInfo(updateLineOnly: true);
        if (!isPointerScroll.value) {
          if (_settingController.useSpringScroll.value) {
            springScrollToCenter();
          } else {
            scrollToCenter();
          }
        }
      }

      if ((_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) ==
              LyricFormat.lrc ||
          currentLineIndex.value < 0 ||
          _currentLine == null) {
        _updateInterludeState();
        return;
      }
      final newWordIndex = _findLrcPos(
        time: currentMs20.value,
        lyrics: _currentLine,
        hint: currentWordIndex.value,
      );

      if (newWordIndex != currentWordIndex.value) {
        interludeProcess.value = 0;
        wordProgress.value = 0;
        currentWordIndex.value = newWordIndex;
        _updateLyricsInfo(updateLineOnly: false);
      }

      wordProgress.value += _wordProgressIncrement;
      _updateInterludeState();
    });
  }

  void pointerScroll() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      isPointerScroll.value = true;

      _delayTimer?.cancel();
      _delayTimer = Timer(const Duration(seconds: 3), () {
        isPointerScroll.value = false;
        scrollToCenter();
      });
    });
  }

  void springScrollToCenter() {
    _springConntroller.nextLyric();
    _springConntroller.currentIndex.value = currentLineIndex.value;
  }

  void scrollToCenter() {
    if (_settingController.useSpringScroll.value) {
      _springConntroller.currentIndex.value = currentLineIndex.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_springConntroller.scrollController.hasClients) {
          _springConntroller.scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      if (!lrcViewScrollController.isAttached) {
        return;
      }
      try {
        lrcViewScrollController.scrollTo(
          index: currentLineIndex.value.clamp(
            0,
            (_audioController.currentLyrics.value?.parsedLrc?.length ?? 1) - 1,
          ),
          duration: Duration(milliseconds: 500),
          alignment: 0.4,
          curve: Curves.easeInOut,
        );
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  int _findLrcPos({
    required double time,
    required List<TimedEntry>? lyrics,
    required int hint,
  }) {
    if (lyrics == null) {
      return -1;
    }
    final n = lyrics.length;
    if (n == 0) return -1;

    // 1. 先判断 hint 自身或 hint+1 是否命中
    if (hint >= 0 && hint < n) {
      final seg = lyrics[hint];
      if (time >= seg.start && time < seg.nextTime) {
        return hint;
      }
      final nextIndex = hint + 1;
      if (nextIndex < n) {
        final segNext = lyrics[nextIndex];
        if (time >= segNext.start && time < segNext.nextTime) {
          return nextIndex;
        }
      }
    }

    // 2. 二分搜索
    int low = 0, high = n - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final segMid = lyrics[mid];
      if (time < segMid.start) {
        high = mid - 1;
      } else if (time >= segMid.nextTime) {
        low = mid + 1;
      } else {
        return mid;
      }
    }

    return -1;
  }
}
