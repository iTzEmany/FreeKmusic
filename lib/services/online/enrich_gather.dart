import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import 'cover_fetcher.dart';
import 'credits_enricher.dart';
import 'curiosity_service.dart';
import 'enrich_parts.dart';
import 'http_client.dart';
import 'metadata_resolver.dart';
import '../recognition/track_identity.dart';

/// How a [EnrichGather] went, for the runner's «nobody answers» count: the
/// sources [answered] (or refused: a source that says «too many requests» is
/// alive); they were asked and gave nothing ([silent], offline or broken); or nothing was asked (every part skipped or refused meanwhile):
/// neither a sign of offline nor of life.
enum GatherSignal { answered, silent, askedNothing }

/// What one track's commit came to: its outcomes, and whether its write was
/// [lost] (the parts then came out failed).
typedef CommitResult = ({int trackId, Map<EnrichPart, PartOutcome> out, bool lost});

/// What [EnrichEngine.gather] asked the sources for one track: kept until
/// [EnrichEngine.commit] writes it. The engine is its only user.
class EnrichGather {
  EnrichGather(this.trackId, this.out);

  final int trackId;

  /// What each part came to; final once [EnrichEngine.commit] has run.
  final Map<EnrichPart, PartOutcome> out;

  Track? track; // as read; null when the track is gone
  int now = 0;
  final marks = <EnrichPart, int?>{}; // now = searched with nothing, null = found
  ResolvedMeta? meta;
  bool metaAsked = false; // meta asked without failing; settled in commit
  AskMode mode = AskMode.due;
  String? plain, synced;
  CreditsPart? credits;
  CuriosityLookup? curio;
  Recognition? rec; // freshly recognized, to write; null when saved already or lost
  bool recAsked = false; // the recognizer answered (also «nothing»)
  CoverResult? cover; // the file fetched, for the album key [coverAlbum]
  String? coverAlbum;

  GatherSignal get signal => metaAsked || recAsked || out.values.any((o) => o.answered || o == PartOutcome.limited)
      ? GatherSignal.answered
      : out.values.any((o) => o != PartOutcome.skipped)
      ? GatherSignal.silent
      : GatherSignal.askedNothing;

  void settle(EnrichPart p, PartOutcome o, int now) {
    out[p] = o;
    if (o == PartOutcome.found) marks[p] = null;
    if (o == PartOutcome.none) marks[p] = now;
  }
}

/// One source of a gather: its answer, or `failed` (logged) when it threw,
/// timed out or was refused. A cancellation escapes.
Future<({T? value, bool failed, bool limited})> attemptSource<T>(
  String what,
  Future<T?> Function() ask, {
  bool timeout = true,
}) async {
  try {
    final f = ask();
    return (
      value: await (timeout ? f.timeout(const Duration(seconds: 25)) : f),
      failed: false,
      limited: false,
    );
  } on RateLimitedException catch (e) {
    AppLog.w('completion: $what refused', e);
    return (value: null, failed: true, limited: true);
  } on Object catch (e, st) {
    if (e is DioException && CancelToken.isCancel(e)) rethrow;
    if (e is Error) {
      AppLog.e('completion: $what failed', e, st);
    } else {
      AppLog.w('completion: $what failed', e, st);
    }
  }
  return (value: null, failed: true, limited: false);
}

/// A part that got no answer: refused (`limited`) or broken (`failed`).
PartOutcome lostOutcome(bool limited) =>
    limited ? PartOutcome.limited : PartOutcome.failed;

/// Rethrows a cancellation the way a cancelled request does.
void throwIfCancelled(CancelToken? cancel) {
  if (cancel != null && cancel.isCancelled) {
    throw cancel.cancelError ??
        DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: 'cancelled',
        );
  }
}
