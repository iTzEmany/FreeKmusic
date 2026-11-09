import 'dart:math';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../import/track_matcher.dart' show LibraryIndex;
import '../online/download_index.dart';
import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import 'radio_fill.dart';
import 'radio_gate.dart';
import 'seed_resolver.dart';
import 'suggestion_gate.dart';
import 'suggestion_log.dart';
import 'suggestion_pool.dart';

/// Why a genre page shows the library only (D-380).
enum GenreMixOff { jam, metered, offline, noTool, rateLimited }

/// A suggested song and the library song it came from.
typedef MixSuggestion = ({YtResult result, String seedTitle});

/// The online songs of a genre mix: [suggested] are ready, [incoming] still
/// on their way (skeleton rows); [off] says why there are none.
class GenreMixState {
  const GenreMixState({this.suggested = const [], this.incoming = 0, this.off});

  static const none = GenreMixState();

  final List<MixSuggestion> suggested;
  final int incoming;
  final GenreMixOff? off;
}

/// A row of the mix: a library track, a suggested song, or the placeholder of
/// one still on its way (both null).
typedef MixRow<T> = ({T? track, MixSuggestion? suggestion});

/// The library [tracks] with one online slot after every [genreMixEvery]: the
/// suggestions that have arrived, then placeholders for those on their way.
List<MixRow<T>> interleave<T>(List<T> tracks, GenreMixState mix) {
  final slots = mix.suggested.length + mix.incoming;
  final rows = <MixRow<T>>[];
  var k = 0;
  for (var i = 0; i < tracks.length; i++) {
    rows.add((track: tracks[i], suggestion: null));
    if ((i + 1) % genreMixEvery == 0 && k < slots) {
      rows.add((
        track: null,
        suggestion: k < mix.suggested.length ? mix.suggested[k] : null,
      ));
      k++;
    }
  }
  return rows;
}

/// One online song every [genreMixEvery] library songs.
const genreMixEvery = 2;

/// Most suggestions of a page: the radio is asked a few times, not per row.
const genreMixMax = 9;

/// Radio and search requests at most; the [RadioGate] still allows one radio
/// request a minute and none while it is tripped.
const _maxRequests = 4;

/// Suggestions for the genre page, the way Shuffle+ makes them (seeds from
/// the genre's songs, their radios, the same pool rules) but outside the
/// queue: emits [GenreMixState.incoming] first, then each song as it is found.
/// A failure keeps what was found and stops (it goes to `AppLog`).
Stream<GenreMixState> genreMix({
  required List<Track> tracks,
  required Future<GenreMixOff?> Function() offReason,
  required SeedResolver resolver,
  required Future<RadioPage> Function(String videoId, {String? continuation})
  radioPage,
  required SuggestionLog log,
  required SuggestionGate filter,
  required RadioGate gate,
  required Future<bool Function(YtResult r)> Function() loadInLibrary,
  bool Function()? cancelled,
  Random? random,
  SuggestionPool? pool,
}) async* {
  final want = min(genreMixMax, tracks.length ~/ genreMixEvery);
  if (want == 0) return;
  final off = await offReason();
  if (off != null) {
    yield GenreMixState(off: off);
    return;
  }
  yield GenreMixState(incoming: want);
  final found = <MixSuggestion>[];
  GenreMixOff? stopped;
  try {
    await log.load();
    await filter.load();
    final fill = RadioFill(
      seeds: [
        for (final t in chooseSeeds(tracks, random: random)) RadioSeed(t),
      ],
      resolver: resolver,
      radioPage: radioPage,
      log: log,
      filter: filter,
      gate: gate,
      inLibrary: await loadInLibrary(),
      pool: pool,
    );
    await for (final c in fill.take(
      want,
      inQueue: (id) => found.any((s) => s.result.id == id),
      cancelled: cancelled,
      maxRequests: _maxRequests,
    )) {
      found.add((result: c.result, seedTitle: c.seedTitle));
      yield GenreMixState(
        suggested: List.of(found),
        incoming: want - found.length,
      );
    }
  } on YtException catch (e, st) {
    AppLog.w('genre mix stopped', e, st);
    if (e.kind == YtErrorKind.rateLimited) {
      gate.trip();
      stopped = GenreMixOff.rateLimited;
    }
  } on Object catch (e, st) {
    AppLog.w('genre mix stopped', e, st);
  }
  yield GenreMixState(suggested: List.of(found), off: stopped);
}

/// [genreMix] for a genre page, from what the providers hold: the library
/// songs of the genre, the downloads and the library index (read only once
/// the radio is going to be asked).
Stream<GenreMixState> genreMixOf({
  required Future<List<Track>> tracks,
  required Future<SeedResolver> resolver,
  required Future<DownloadIndex> downloads,
  required Future<RadioPage> Function(String videoId, {String? continuation})
  radioPage,
  required SuggestionLog log,
  required SuggestionGate filter,
  required RadioGate gate,
  required Future<GenreMixOff?> Function() offReason,
  required Future<LibraryIndex> Function() library,
  required bool Function() cancelled,
}) async* {
  final list = await tracks;
  if (list.length < genreMixEvery) return;
  final index = await downloads;
  yield* genreMix(
    tracks: list,
    resolver: await resolver,
    radioPage: radioPage,
    log: log,
    filter: filter,
    gate: gate,
    cancelled: cancelled,
    offReason: offReason,
    loadInLibrary: () async =>
        inLibraryTest(hasDownload: index.contains, library: await library()),
  );
}
