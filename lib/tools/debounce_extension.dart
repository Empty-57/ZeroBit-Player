import 'dart:async';

extension FutureDebounceExtension on Function {
  void Function() debounce([int milliseconds = 500]) {
    Timer? _debounceTimer;
    return () async {
      if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(milliseconds: milliseconds), () async {
        await this();
      });
    };
  }
}