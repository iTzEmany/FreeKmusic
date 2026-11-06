import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_info.dart';

/// What Wikimedia publishes as the request limits of its public APIs
/// (Action API and REST, enforced per client and per minute; see
/// https://www.mediawiki.org/wiki/Wikimedia_APIs/Rate_limits, 2026):
///   - a client with nothing but its IP address to identify it: **10 / min**;
///   - an unauthenticated bot with a compliant User-Agent (one that says how
///     to reach whoever runs it): **200 / min**;
///   - at most **3** requests in parallel;
///   - over the limit: HTTP 429 with `Retry-After` (503 when overloaded);
///     without the header, wait 5 s or more, with growing delays.
/// The budgets below keep a margin under those numbers.
const kWikimediaAnonymousPerMinute = 8;
const kWikimediaIdentifiedPerMinute = 150;

/// The «Artists» and «Albums» rows of the online search are two requests more
/// than the page needs; at most this many in any minute (about ten searches),
/// past it the rows are left out instead of waiting.
const kSearchRowsPerMinute = 20;

/// True when the User-Agent this app sends carries a way to reach its author
/// (`kApiContact`), which is what moves it from the 10 / min tier to 200 / min.
bool get apiIdentified => kApiContact.trim().isNotEmpty;

/// The `User-Agent` of every request: `Codecore/<version> (<contact>)` in the
/// form the Wikimedia policy asks for, or the plain one when no contact is set.
String get apiUserAgent => apiIdentified
    ? 'Codecore/$kAppVersion (${kApiContact.trim()})'
    : 'Codecore/1.0 (uso personale)';

/// Hosts that share Wikimedia's limit: it is global for all their sites.
bool isWikimediaHost(String host) =>
    host == 'wikipedia.org' ||
    host.endsWith('.wikipedia.org') ||
    host.endsWith('.wikimedia.org') ||
    host == 'wikidata.org' ||
    host.endsWith('.wikidata.org');

/// At most [perMinute] requests in any 60 seconds. [acquire] waits (it does not
/// fail) until a slot is free; callers are served one after the other, in the
/// order they asked.
class WindowLimiter {
  WindowLimiter({
    required this.perMinute,
    DateTime Function()? now,
    Future<void> Function(Duration)? pause,
  })  : assert(perMinute > 0),
        _now = now ?? DateTime.now,
        _pause = pause ?? Future<void>.delayed;

  final int perMinute;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _pause;
  final _stamps = <DateTime>[];
  Future<void> _tail = Future<void>.value();

  static const window = Duration(seconds: 60);

  /// When the last requests were let through (the latest 200), for tests.
  @visibleForTesting
  final granted = <DateTime>[];

  /// How many requests were let through in the last minute.
  int get recent {
    final cut = _now().subtract(window);
    return _stamps.where((s) => s.isAfter(cut)).length;
  }

  Future<void> acquire() {
    final turn = _tail.then((_) => _take());
    _tail = turn.catchError((Object _) {});
    return turn;
  }

  /// Takes [n] slots if they are all free right now, false (nothing taken)
  /// otherwise: for requests that only add to a page and are not worth a wait.
  bool tryAcquire([int n = 1]) {
    final now = _now();
    _stamps.removeWhere((s) => !s.isAfter(now.subtract(window)));
    if (_stamps.length + n > perMinute) return false;
    for (var i = 0; i < n; i++) {
      _stamps.add(now);
      granted.add(now);
    }
    while (granted.length > 200) {
      granted.removeAt(0);
    }
    return true;
  }

  Future<void> _take() async {
    while (true) {
      if (tryAcquire()) return;
      final now = _now();
      // The oldest one leaves the window at its stamp + 60 s.
      final wait = _stamps.first.add(window).difference(now);
      await _pause(wait > Duration.zero ? wait : const Duration(milliseconds: 50));
    }
  }
}

/// The limiter for Wikimedia hosts, sized for the tier the app is in.
WindowLimiter wikimediaLimiter({DateTime Function()? now, Future<void> Function(Duration)? pause}) =>
    WindowLimiter(
      perMinute: apiIdentified ? kWikimediaIdentifiedPerMinute : kWikimediaAnonymousPerMinute,
      now: now,
      pause: pause,
    );
