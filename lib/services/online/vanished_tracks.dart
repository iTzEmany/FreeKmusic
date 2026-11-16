import '../../core/app_log.dart';
import '../../core/artist_key.dart';
import '../../core/import_row.dart';
import '../../data/db/app_database.dart' show Track;
import '../../data/repositories/track_kinds.dart' show kStreamKind;
import '../../data/repositories/track_repository.dart';
import '../import/track_matcher.dart' show matchTitleKey;
import '../stream/stream_key.dart';
import 'youtube_service.dart';

/// A saved stream row whose video YouTube no longer has (R-242, D-588): searches the same song
/// again and, only when title, artist and duration (±[toleranceMs]) agree, moves the SAME row to
/// the new key. Otherwise it only logs. [search] runs under the shared YouTube Music budget.
class VanishedTracks {
  VanishedTracks({required this.tracks, required this.search, required this.log});

  static const toleranceMs = 2000;

  final TrackRepository tracks;

  /// The best candidate for [row], or null (the app wires `searchRow` under `budgetedYtm`).
  final Future<YtResult?> Function(ImportRow row) search;

  /// One Registro line: [to] is the replacement, null when none was accepted.
  final Future<void> Function(Track row, YtResult? to) log;

  final _busy = <int>{};

  /// True when the row moved. Never throws.
  Future<bool> handle(Track t) async {
    if (t.kind != kStreamKind || !t.saved || !_busy.add(t.id)) return false;
    try {
      final row = await tracks.getById(t.id);
      final oldKey = row == null || !row.saved ? null : keyOfStreamPath(row.path);
      if (row == null || oldKey == null || row.kind != kStreamKind) return false;
      final artist = row.artist ?? '';
      final want = ImportRow(
        index: 0,
        title: row.title,
        artists: [if (artist.isNotEmpty) artist.split(', ').first],
        durationMs: row.durationMs > 0 ? row.durationMs : null,
      );
      final found = await search(want);
      final ok = found != null && found.indexKey != oldKey && _same(row, found);
      final moved = ok && await tracks.rekeyStream(row.id, found.indexKey);
      await log(row, moved ? found : null);
      return moved;
    } on Object catch (e, st) {
      AppLog.w('vanished track ${t.id}: replacement failed', e, st);
      return false;
    } finally {
      _busy.remove(t.id);
    }
  }

  static bool _same(Track row, YtResult c) {
    if (row.durationMs <= 0 || c.duration == null) return false;
    final first = (row.artist ?? '').split(', ').first;
    final cand = c.artists.isEmpty ? c.channel : c.artists.first;
    return matchTitleKey(row.title) == matchTitleKey(c.title) &&
        matchKey(first) == matchKey(cand) &&
        (row.durationMs - c.duration!.inMilliseconds).abs() <= toleranceMs;
  }
}
