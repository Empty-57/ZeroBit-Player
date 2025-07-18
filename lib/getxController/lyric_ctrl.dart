import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'audio_ctrl.dart';

final AudioController _audioController = Get.find<AudioController>();

class LyricController extends GetxController {
  final currentMs20 = 0.0.obs;
  final lrcViewScrollController = ItemScrollController();
  final isPointerScroll = false.obs;

  final currentLineIndex = (-1).obs;
  final currentWordIndex = (0).obs;

  final wordProgress = 0.0.obs;
  double _wordProgressIncrement = 0;

  WordEntry? _currentWord;

  List<WordEntry>? _currentLine;

  Timer? _debounceTimer;
  Timer? _delayTimer;

  @override
  void onInit() {
    super.onInit();

    everAll(
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
      },
      condition:
          () =>
              (_audioController.currentLyrics.value?.type ?? LyricFormat.lrc) !=
              LyricFormat.lrc,
    );

    // 增量计算:  total/(duration/loopTime)
    // 百分比: total=100 字持续时间: duration(Ms) 轮询间隔: loopTime=20(Ms)
    ever(currentWordIndex, (_) {
      if (_currentWord == null && _currentWord!.duration <= 0) {
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

    ever(currentMs20, (_) {
      final newLineIndex = _findLrcPos(
        time: currentMs20.value,
        lyrics: _audioController.currentLyrics.value?.parsedLrc,
        hint: currentLineIndex.value,
      );
      if (newLineIndex != currentLineIndex.value) {
        wordProgress.value = 0;
        currentLineIndex.value = newLineIndex;
        if (!isPointerScroll.value) {
          scrollToCenter();
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
        wordProgress.value = 0;
        currentWordIndex.value = newWordIndex;
      }

      wordProgress.value += _wordProgressIncrement;
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

  void scrollToCenter() {
    if (!lrcViewScrollController.isAttached) {
      return;
    }

    lrcViewScrollController.scrollTo(
      index: currentLineIndex.value.clamp(
        0,
        (_audioController.currentLyrics.value?.parsedLrc?.length ?? 1) - 1,
      ),
      duration: Duration(milliseconds: 500),
      alignment: 0.5,
      curve: Curves.easeInOut,
    );
  }

  int _findLrcPos({required double time, required List<TimedEntry>? lyrics, required int hint,}) {
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
