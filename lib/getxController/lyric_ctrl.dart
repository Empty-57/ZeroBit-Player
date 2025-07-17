import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../tools/lrcTool/lyric_model.dart';
import 'audio_ctrl.dart';

final AudioController _audioController = Get.find<AudioController>();

class LyricController extends GetxController {
  final currentMs20 = 0.0.obs;
  final currentLineIndex = (-1).obs;
  final lrcViewScrollController = ItemScrollController();
  final isPointerScroll=false.obs;

  Timer? _debounceTimer;
  Timer? _delayTimer;

  @override
  void onInit() {
    super.onInit();

    ever(currentMs20, (_) {
      final newIndex = _findCurrentLine(
        time: currentMs20.value,
        lyrics: _audioController.currentLyrics.value?.parsedLrc,
        hint: currentLineIndex.value,
      );
      if (newIndex != currentLineIndex.value) {
        currentLineIndex.value = newIndex;

        if(!isPointerScroll.value){
          scrollToCenter();
        }
      }
    });

  }

  void pointerScroll(){
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
      index: currentLineIndex.value.clamp(0, (_audioController.currentLyrics.value?.parsedLrc?.length??1)-1),
      duration: Duration(milliseconds: 500),
      alignment: 0.5,
      curve: Curves.easeInOut,
    );
  }

  int _findCurrentLine({
    required double time,
    required List<LyricEntry>? lyrics,
    required int hint,
  }) {
    if (lyrics == null) {
      return -1;
    }
    final n = lyrics.length;
    if (n == 0) return -1;

    // 1. hint 优化：先判断 hint 自身或 hint+1 是否命中
    if (hint >= 0 && hint < n) {
      final seg = lyrics[hint];
      if (time >= seg.segmentStart && time < seg.nextTime) {
        return hint;
      }
      final nextIndex = hint + 1;
      if (nextIndex < n) {
        final segNext = lyrics[nextIndex];
        if (time >= segNext.segmentStart && time < segNext.nextTime) {
          return nextIndex;
        }
      }
    }

    // 2. 二分搜索
    int low = 0, high = n - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final segMid = lyrics[mid];
      if (time < segMid.segmentStart) {
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
