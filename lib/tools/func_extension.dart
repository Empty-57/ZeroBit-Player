import 'dart:async';

extension FutureDebounceExtension on Function {
  void Function() futureDebounce({int ms = 500}) {
    Timer? debounceTimer;
    return () async {
      if (debounceTimer?.isActive ?? false) debounceTimer?.cancel();
      debounceTimer = Timer(Duration(milliseconds: ms), () async {
        await this();
      });
    };
  }
}

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
