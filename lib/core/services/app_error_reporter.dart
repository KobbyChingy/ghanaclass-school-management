import 'package:flutter/foundation.dart';

/// Centralized app error surface.
///
/// The UI overlay in `main.dart` listens to [unhandledErrorNotifier].
final ValueNotifier<String?> unhandledErrorNotifier = ValueNotifier<String?>(null);

void reportUnhandledError(Object error, StackTrace stack) {
  unhandledErrorNotifier.value = '$error\n$stack';
}

void clearUnhandledError() {
  unhandledErrorNotifier.value = null;
}
