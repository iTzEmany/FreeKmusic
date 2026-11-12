import 'dart:math';

import 'youtube_service.dart';

/// When to try a failed download again. Only transient errors are retried:
/// a rate limit needs the user to wait, an unavailable video never comes back.
class RetryPolicy {
  RetryPolicy({
    this.delays = const [
      Duration(seconds: 5),
      Duration(seconds: 20),
      Duration(seconds: 60),
    ],
    this.jitter = 0.2,
    Random? random,
  }) : _random = random ?? Random();

  final List<Duration> delays;

  /// Delays are spread by ± this fraction so parallel retries do not collide.
  final double jitter;
  final Random _random;

  int get maxRetries => delays.length;

  static bool isTransient(YtErrorKind k) =>
      k == YtErrorKind.network || k == YtErrorKind.changed; // not internal

  /// Wait before retry number [retriesDone] + 1; null = give up.
  Duration? nextDelay(int retriesDone, YtErrorKind kind) {
    if (!isTransient(kind) || retriesDone >= delays.length) return null;
    final factor = 1 + (_random.nextDouble() * 2 - 1) * jitter;
    return Duration(
        milliseconds: (delays[retriesDone].inMilliseconds * factor).round());
  }
}
