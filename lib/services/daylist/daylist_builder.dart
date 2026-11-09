// What the provider passes in [DaylistInputs]: the user's non-missing library
// tracks ([library]), every play with its time ([plays], from `plays` joined
// by track id), the slots and mood table from SettingsStore, the clock, and
// [suggest]: a closure over a RadioFill (already under SuggestionGate and
// RadioGate) that calls `fill.take(want, inQueue: .., accept: ..)` for the
// given seed tracks, or null when offline. Optional: [DaylistInputs.genresOf]
// (track id -> genres, from track_genres) replaces the tag in Track.genre.
// The builder does no I/O and asks for no suggestions when the slot is off.
import 'dart:isolate';
import 'dart:math';

import '../../core/app_log.dart';
import '../../core/artist_key.dart' show artistKey, matchKey;
import '../../data/db/app_database.dart' show Track;
import '../shuffle_plus/suggestion_pool.dart' show SuggestionCandidate, suggestionArtistKey;
import '../tags/tag_reader.dart' show splitGenres;
import 'daylist_slots.dart';
import 'mood_table.dart';

typedef DaylistPlay = ({int trackId, DateTime playedAt});

/// Suggestions of the radios of [seeds]: at most [want], each only if
/// [accept] says so (it is applied before a row counts, see RadioFill.take).
typedef DaylistSuggest = Stream<SuggestionCandidate> Function(
  List<Track> seeds,
  int want,
  bool Function(SuggestionCandidate c) accept,
  bool Function(String videoId) inQueue,
);

class DaylistInputs {
  DaylistInputs({
    required this.config,
    required this.moods,
    required this.now,
    required this.random,
    required this.library,
    required this.plays,
    this.suggest,
    this.genresOfSuggestion,
    this.genresOf,
  });

  final DaylistConfig config;
  final MoodTable moods;
  final DateTime Function() now;
  final Random random;
  final List<Track> library;
  final List<DaylistPlay> plays;
  final DaylistSuggest? suggest;

  /// Genres of a suggested song when the caller knows them; by default those
  /// of the library songs by the same artist (none if the artist is unknown).
  final Iterable<String> Function(SuggestionCandidate c)? genresOfSuggestion;

  /// Genres per library track id (track_genres); a track missing here or with
  /// an empty list uses its `genre` tag.
  final Map<int, List<String>>? genresOf;
}

/// One row of the daylist: a library track or a suggested song.
class DaylistItem {
  const DaylistItem.own(Track this.track) : suggestion = null;
  const DaylistItem.suggested(SuggestionCandidate this.suggestion) : track = null;

  final Track? track;
  final SuggestionCandidate? suggestion;
}

/// The daylist of a slot. [genres] (at most 3, most present first) and
/// [slotIndex] make the name: the UI joins the slot name and the genres.
/// [tooFew] (D-473): fewer than [DaylistBuilder.minTracks] songs, no daylist
/// ([items] is empty). [isShort]: created, but with fewer than 50 songs.
class DaylistResult {
  const DaylistResult({
    required this.slotIndex,
    required this.items,
    required this.genres,
    required this.tooFew,
    this.off = false,
  });

  final int slotIndex;
  final List<DaylistItem> items;
  final List<String> genres;
  final bool tooFew;

  /// The slot is switched off: nothing was built ([tooFew] is true too).
  final bool off;

  bool get isShort => !tooFew && items.length < DaylistBuilder.size;
}

/// What the pure part of the builder works out (ranking, seeds, candidates):
/// plain data, so it can be made in an isolate (see [DaylistBuilder.planInIsolate])
/// and finished on the main one, where the suggestions are asked.
class DaylistPlan {
  DaylistPlan._({
    required this.slotIndex,
    required this.slot,
    required this.moods,
    required this.off,
    this.seeds = const [],
    this.candidates = const [],
    this.extra = const [],
    this.genreOf = const {},
    this.artistGenres = const {},
    this.libraryKeys = const {},
    this.spelled = const {},
  });

  final int slotIndex;
  final DaylistSlot slot;
  final MoodTable moods;
  final bool off;
  final List<Track> seeds, candidates, extra;
  final Map<int, List<String>> genreOf;
  final Map<String, Set<String>> artistGenres;
  final Set<String> libraryKeys;
  final Map<String, String> spelled;

  Set<String> get avoid => {for (final g in slot.avoid) matchKey(g)};

  /// Avoided genre: out. Else the slot's taste: preferred genre or a mood of
  /// the slot (no taste set = everything). A genre-less song only passes then.
  bool passes(Iterable<String> genres) {
    if (genres.any(avoid.contains)) return false;
    final prefer = {for (final g in slot.prefer) matchKey(g)};
    if (prefer.isEmpty && slot.moods.isEmpty) return true;
    return genres.any(prefer.contains) || moods.moodsOfAll(genres).any(slot.moods.contains);
  }
}

class DaylistBuilder {
  static const size = 50;
  static const minTracks = 15;
  static const _seedCount = 5;
  static const _minGenres = 3;
  static const _maxNameGenres = 3;

  /// Genres of a tag value like «Rock; Pop»: normalized with [matchKey].
  static List<String> genresOf(String? tag) => [
    for (final g in splitGenres([tag]))
      if (matchKey(g).isNotEmpty) matchKey(g),
  ];

  static String _key(String title, String artistKey) => '${matchKey(title)}|$artistKey';

  Future<DaylistResult> build(DaylistInputs inp) => finish(
    plan(
      config: inp.config,
      moods: inp.moods,
      now: inp.now(),
      random: inp.random,
      library: inp.library,
      plays: inp.plays,
      genresOf: inp.genresOf,
    ),
    suggest: inp.suggest,
    genresOfSuggestion: inp.genresOfSuggestion,
  );

  /// [plan] in a worker isolate: the sorting of a whole library stays off the
  /// UI thread. Only plain data goes in (the arguments are copied).
  static Future<DaylistPlan> planInIsolate({
    required DaylistConfig config,
    required MoodTable moods,
    required DateTime now,
    required int randomSeed,
    required List<Track> library,
    required List<DaylistPlay> plays,
    Map<int, List<String>>? genresOf,
  }) => Isolate.run(
    () => plan(
      config: config,
      moods: moods,
      now: now,
      random: Random(randomSeed),
      library: library,
      plays: plays,
      genresOf: genresOf,
    ),
  );

  /// The pure part: which songs may be in the slot's daylist and in what order.
  static DaylistPlan plan({
    required DaylistConfig config,
    required MoodTable moods,
    required DateTime now,
    required Random random,
    required List<Track> library,
    required List<DaylistPlay> plays,
    Map<int, List<String>>? genresOf,
  }) {
    final slotIndex = config.slotAt(now);
    final slot = config.slots[slotIndex];
    if (!slot.enabled) return DaylistPlan._(slotIndex: slotIndex, slot: slot, moods: moods, off: true);
    final pl = DaylistPlan._(slotIndex: slotIndex, slot: slot, moods: moods, off: false);

    final genreOf = {
      for (final t in library)
        t.id: switch (genresOf?[t.id]) {
          final l? when l.isNotEmpty => [for (final g in l) matchKey(g)],
          _ => DaylistBuilder.genresOf(t.genre),
        },
    };
    final artistGenres = <String, Set<String>>{};
    final libraryKeys = <String>{};
    final spelled = <String, String>{};
    for (final t in library) {
      artistGenres.putIfAbsent(artistKey(t.artist), () => {}).addAll(genreOf[t.id]!);
      libraryKeys.add(_key(t.title, artistKey(t.artist)));
      for (final g in splitGenres([t.genre])) {
        spelled.putIfAbsent(matchKey(g), () => g);
      }
    }
    final ok = [for (final t in library) if (pl.passes(genreOf[t.id]!)) t];

    // Plays in the slot's hours, per track.
    final inSlot = <int, int>{};
    for (final p in plays) {
      if (config.slotAt(p.playedAt) == slotIndex) inSlot[p.trackId] = (inSlot[p.trackId] ?? 0) + 1;
    }
    final noise = {for (final t in ok) t.id: random.nextDouble()};
    int rank(Track a, Track b, int Function(Track) score) {
      final c = score(b).compareTo(score(a));
      return c != 0 ? c : noise[a.id]!.compareTo(noise[b.id]!);
    }

    final played = [for (final t in ok) if ((inSlot[t.id] ?? 0) > 0) t]
      ..sort((a, b) => rank(a, b, (t) => inSlot[t.id]!));
    final hasHistory = played.isNotEmpty;
    final overall = [...ok]..sort((a, b) => rank(a, b, (t) => t.playCount));

    // Seeds: the most played here; without history, the most played anywhere.
    final seeds = (hasHistory ? played : overall).take(_seedCount).toList();

    // Own songs: played here, then the seeds' artists and genres; without
    // history, everything the slot's taste allows.
    final seedArtists = {for (final s in seeds) artistKey(s.artist)};
    final seedGenres = {for (final s in seeds) ...genreOf[s.id]!};
    final playedIds = {for (final t in played) t.id};
    final related = [
      for (final t in overall)
        if (!playedIds.contains(t.id) &&
            (seedArtists.contains(artistKey(t.artist)) || genreOf[t.id]!.any(seedGenres.contains)))
          t,
    ];
    return DaylistPlan._(
      slotIndex: slotIndex,
      slot: slot,
      moods: moods,
      off: false,
      seeds: seeds,
      candidates: _distinct(hasHistory ? [...played, ...related] : overall),
      extra: _distinct(overall),
      genreOf: genreOf,
      artistGenres: artistGenres,
      libraryKeys: libraryKeys,
      spelled: spelled,
    );
  }

  /// The suggestions and the final pick, on the isolate that holds [suggest].
  Future<DaylistResult> finish(
    DaylistPlan pl, {
    DaylistSuggest? suggest,
    Iterable<String> Function(SuggestionCandidate c)? genresOfSuggestion,
  }) async {
    if (pl.off) {
      return DaylistResult(slotIndex: pl.slotIndex, items: const [], genres: const [], tooFew: true, off: true);
    }
    final wantSuggested = (size * pl.slot.sharePercent / 100).round();
    final suggested = await _suggestions(pl, suggest, genresOfSuggestion, wantSuggested);
    final own = _pickOwn(pl.candidates, pl.extra, pl.genreOf, size - suggested.length);
    final items = _spread(own, suggested);
    if (items.length < minTracks) {
      return DaylistResult(slotIndex: pl.slotIndex, items: const [], genres: const [], tooFew: true);
    }
    return DaylistResult(
      slotIndex: pl.slotIndex,
      items: items,
      genres: _topGenres([
        for (final t in own) ...pl.genreOf[t.id]!,
        for (final c in suggested) ..._suggestionGenres(genresOfSuggestion, c, pl.artistGenres),
      ], pl.spelled),
      tooFew: false,
    );
  }

  /// [tracks] without a second copy of the same title and artist.
  static List<Track> _distinct(List<Track> tracks) {
    final seen = <String>{};
    return [for (final t in tracks) if (seen.add(_key(t.title, artistKey(t.artist)))) t];
  }

  /// Genres of a suggestion: the caller's, else those of the artist's songs
  /// in the library, else none.
  List<String> _suggestionGenres(
    Iterable<String> Function(SuggestionCandidate c)? own,
    SuggestionCandidate c,
    Map<String, Set<String>> artistGenres,
  ) {
    if (own != null) return [for (final g in own(c)) matchKey(g)];
    return [...?artistGenres[suggestionArtistKey(c.result)]];
  }

  Future<List<SuggestionCandidate>> _suggestions(
    DaylistPlan pl,
    DaylistSuggest? suggest,
    Iterable<String> Function(SuggestionCandidate c)? genresOfSuggestion,
    int want,
  ) async {
    if (suggest == null || want <= 0 || pl.seeds.isEmpty) return const [];
    final avoid = pl.avoid;
    final taken = <String>{};
    bool accept(SuggestionCandidate c) {
      if (pl.libraryKeys.contains(_key(c.result.title, suggestionArtistKey(c.result)))) return false;
      final g = _suggestionGenres(genresOfSuggestion, c, pl.artistGenres);
      final left = [for (final x in g) if (!avoid.contains(x)) x];
      if (g.isNotEmpty && left.isEmpty) return false; // only avoided genres
      // Unknown genres follow the rule of a song without genre: only a slot without taste.
      return pl.passes(left);
    }

    final out = <SuggestionCandidate>[];
    try {
      await for (final c in suggest(pl.seeds, want, accept, taken.contains)) {
        if (!taken.add(c.result.id)) continue;
        out.add(c);
        if (out.length >= want) break;
      }
    } on Object catch (e, st) {
      // Offline or the radio failed: the daylist is made of the user's songs.
      AppLog.w('daylist suggestions failed, own songs only', e, st);
    }
    return out;
  }

  /// [want] songs from [ranked], covering at least [_minGenres] genres when
  /// the candidates have them.
  List<Track> _pickOwn(List<Track> ranked, List<Track> extra, Map<int, List<String>> genreOf, int want) {
    final chosen = <Track>[];
    final used = <int>{};
    final genres = <String>{};
    // New genres first from the ranked songs, then from any song the slot allows.
    for (final t in [...ranked, ...extra]) {
      if (genres.length >= _minGenres || chosen.length >= want) break;
      if (used.contains(t.id)) continue;
      if (genreOf[t.id]!.any((g) => !genres.contains(g))) {
        chosen.add(t);
        used.add(t.id);
        genres.addAll(genreOf[t.id]!);
      }
    }
    for (final t in ranked) {
      if (chosen.length >= want) break;
      if (used.add(t.id)) chosen.add(t);
    }
    return chosen;
  }

  /// Suggestions evenly among the own songs.
  List<DaylistItem> _spread(List<Track> own, List<SuggestionCandidate> sug) {
    final total = own.length + sug.length;
    final items = <DaylistItem>[];
    var o = 0, s = 0;
    for (var i = 0; i < total; i++) {
      final wantSug = s < sug.length && (o >= own.length || (i + 1) * sug.length >= (s + 1) * total);
      items.add(wantSug ? DaylistItem.suggested(sug[s++]) : DaylistItem.own(own[o++]));
    }
    return items;
  }

  /// Up to 3 most present genres, spelled as in the library ([spelled]).
  List<String> _topGenres(List<String> all, Map<String, String> spelled) {
    final count = <String, int>{};
    for (final g in all) {
      count[g] = (count[g] ?? 0) + 1;
    }
    final top = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    return [for (final g in top.take(_maxNameGenres)) spelled[g] ?? g];
  }
}
