import 'query_match.dart' show MediaKind;
import 'request_budget.dart' show WindowLimiter;
import 'source_cooldown.dart';
import 'youtube_service.dart' show YtErrorKind, YtException;

/// Runs [run] against YouTube Music with the shared budget (D-425): null, with
/// [run] not called, when the source is paused after a 429 or [cost] slots are not
/// free; a 429 from [run] pauses the source and is rethrown. Returns a [Future]
/// (not a `Future<T?>`) so a caller can tell «no budget» synchronously.
Future<T>? budgetedYtm<T>(
  SourceCooldown cooldown,
  WindowLimiter limiter,
  Future<T> Function() run, {
  int cost = 1,
}) {
  if (cooldown.isPaused(MediaKind.ytmSong) || !limiter.tryAcquire(cost)) {
    return null;
  }
  return _guard(cooldown, run);
}

Future<T> _guard<T>(SourceCooldown cooldown, Future<T> Function() run) async {
  try {
    return await run();
  } on YtException catch (e) {
    if (e.kind == YtErrorKind.rateLimited) cooldown.trip(MediaKind.ytmSong);
    rethrow;
  }
}
