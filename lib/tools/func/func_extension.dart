import 'dart:async';

extension DebounceExtension on Function {
  void Function() debounce({int ms = 500}) {
    Timer? debounceTimer;
    return () {
      if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
      debounceTimer = Timer(Duration(milliseconds: ms), () {
        this();
      });
    };
  }
}

bool _throttleIsAllowed = true;

extension ThrottleExtension on Function {
  void Function() throttle({int ms = 500}) {
    Timer? throttleTimer;
    return () {
      if (!_throttleIsAllowed) return;
      _throttleIsAllowed = false;
      this();
      throttleTimer?.cancel();
      throttleTimer = Timer(Duration(milliseconds: ms), () {
        _throttleIsAllowed = true;
      });
    };
  }
}

extension ThrottleExtensionArgs<T> on void Function(T) {
  void Function(T) throttleArgs({int ms = 500}) {
    bool isAllowed = true;
    Timer? throttleTimer;
    return (T arg) {
      if (!isAllowed) return;
      isAllowed = false;
      this(arg);
      throttleTimer?.cancel();
      throttleTimer = Timer(Duration(milliseconds: ms), () {
        isAllowed = true;
      });
    };
  }
}
