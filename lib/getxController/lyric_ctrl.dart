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

  final cancelScale = false.obs;

  final showInterlude = false.obs;

  final interludeProcess = 0.0.obs;

  double _interval = 0; // 歌词行间隔值

  int _threshold = _lowIntervalThreshold; // 间奏进度下限

  int _wordsLen = 0; // 当前行长度

  static const _lowIntervalThreshold = 90;

  WordEntry? _currentWord; // 当前词信息

  List<WordEntry>? _currentLine; // 当前行信息

  Timer? _debounceTimer; // 防抖计时器
  Timer? _delayTimer;

  late final Worker _lineWordWorker;
  late final Worker _progressWorker;
  late final Worker _wordIndexWorker;
  late final Worker _msWorker;
  late final Worker _lyricsWorker;

  @override
  void onClose() {
    _lineWordWorker.dispose();
    _progressWorker.dispose();
    _wordIndexWorker.dispose();
    _msWorker.dispose();
    _lyricsWorker.dispose();

    _debounceTimer?.cancel();
    _delayTimer?.cancel();
    _currentLine = null;
    _currentWord = null;
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();

    // 重置状态
    _lyricsWorker = ever(_audioController.currentLyrics, (_) {
      _resetLyricState();
    });

    // 更新 _currentWord, _currentLine, _interval, _threshold
    _lineWordWorker = everAll(
      [currentLineIndex, currentWordIndex],
      (_) {
        final lyrics = _audioController.currentLyrics.value?.parsedLrc;
        final lineIndex = currentLineIndex.value;
        int wordIndex = currentWordIndex.value;
        if (lyrics == null || lineIndex < 0 || lineIndex >= lyrics.length) {
          return;
        }
        _currentLine = lyrics[lineIndex].lyricText;
        if (wordIndex >= _currentLine!.length) return;
        if (wordIndex < 0) {
          wordIndex = 0;
        }
        _currentWord = _currentLine![wordIndex];

        final rowCurrentLine = lyrics[lineIndex];
        final lastWord = _currentLine![_currentLine!.length - 1];
        if (_audioController.currentLyrics.value?.type ==
            LyricFormat.byWordLrc) {
          _interval = rowCurrentLine.nextTime - (lastWord.start);
          _threshold = _interval >= 4 ? 2 : 150;
        } else {
          _interval =
              rowCurrentLine.nextTime - (lastWord.start + lastWord.duration);
          _threshold = _interval >= 4 ? _lowIntervalThreshold : 150;
        }

        _wordsLen = _currentLine!.length;
      },
      condition:
          () =>
              (_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) !=
              LyricFormat.lrc,
    );

    // 判断是否显示间奏
    _progressWorker = ever(wordProgress, (_) {
      final isNotLast = currentWordIndex.value != _wordsLen - 1;
      final isThresholdValid = wordProgress.value < _threshold;
      cancelScale.value = isNotLast || isThresholdValid;
      final int len =
          (_audioController.currentLyrics.value?.parsedLrc?.length ?? 0) - 1;
      int threshold = _lowIntervalThreshold;
      if (_audioController.currentLyrics.value?.type == LyricFormat.byWordLrc) {
        threshold = -8; // 我也忘了这里为什么是 -8 了
      }
      showInterlude.value =
          !isNotLast &&
          _interval >= 4 &&
          wordProgress.value >=
              (threshold + 10) && // >= (threshold + 10) 这个词过渡完才允许显示间奏
          interludeProcess.value <= 95 && // <= 95 是为了给动画退场一点时间
          currentLineIndex.value < len;
    });

    // 增量计算:  total/(duration/loopTime)
    // 百分比: total=100 字持续时间: duration(Ms) 轮询间隔: loopTime=20(Ms)
    _wordIndexWorker = ever(currentWordIndex, (_) {
      if (_currentWord == null || _currentWord!.duration <= 0) {
        _wordProgressIncrement = 0;
        return;
      }

      if (currentMs20.value - _currentWord!.start >= 0.02) {
        _wordProgressIncrement =
            2 /
            (_currentWord!.duration - currentMs20.value + _currentWord!.start);
      } else {
        _wordProgressIncrement = 2 / _currentWord!.duration;
      }
    });

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
      }

      int threshold = _lowIntervalThreshold;
      if (_audioController.currentLyrics.value?.type == LyricFormat.byWordLrc) {
        threshold = -8;
      }
      if (wordProgress.value >= threshold + 10 &&
          currentWordIndex.value == _wordsLen - 1) {
        interludeProcess.value += 2 / _interval;
      }

      wordProgress.value += _wordProgressIncrement;
    });
  }

  void _resetLyricState() {
    currentLineIndex.value = -1;
    currentWordIndex.value = 0;
    wordProgress.value = 0;
    interludeProcess.value = 0;
    showInterlude.value = false;
    cancelScale.value = false;

    _interval = 0;
    _threshold = _lowIntervalThreshold;
    _wordsLen = 0;

    _currentLine = null;
    _currentWord = null;
    _wordProgressIncrement = 0;
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
