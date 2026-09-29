import 'dart:async';

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
