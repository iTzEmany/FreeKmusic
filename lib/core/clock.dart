import 'package:flutter/foundation.dart' show visibleForTesting;

/// Replaces the clock in tests (golden shots need a fixed day); null in the app.
@visibleForTesting
int Function()? nowMsOverride;

/// The current time as epoch milliseconds (a named function so database
/// column defaults can point at it).
int nowMs() => nowMsOverride?.call() ?? DateTime.now().millisecondsSinceEpoch;
