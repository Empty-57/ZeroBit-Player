import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

extension ThrottleExtension on void Function() {
  void Function() throttle({int ms = 500}) {
    DateTime? lastInvocation;
    return () {
      final now = DateTime.now();
      final last = lastInvocation;
      if (last != null && now.difference(last).inMilliseconds < ms) return;
      lastInvocation = now;
      this();
    };
  }
}

extension ThrottleExtensionArgs<T> on void Function(T) {
  void Function(T) throttleArgs({int ms = 500}) {
    DateTime? lastInvocation;
    return (T arg) {
      final now = DateTime.now();
      final last = lastInvocation;
      if (last != null && now.difference(last).inMilliseconds < ms) return;
      lastInvocation = now;
      this(arg);
    };
  }
}

extension DebounceExtension on void Function() {
  void Function() debounce({int ms = 500}) {
    Timer? timer;
    return () {
      timer?.cancel();
      timer = Timer(Duration(milliseconds: ms), () {
        timer = null;
        this();
      });
    };
  }
}

extension DebounceExtensionArgs<T> on void Function(T) {
  void Function(T) debounceArgs({int ms = 500}) {
    Timer? timer;
    return (T arg) {
      timer?.cancel();
      timer = Timer(Duration(milliseconds: ms), () {
        timer = null;
        this(arg);
      });
    };
  }
}

extension HashString on String {
  /// 获取此字符串的 Hash 值
  String get hashHex => md5.convert(utf8.encode(this)).toString();
}
