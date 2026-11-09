import '../../core/app_log.dart';
import '../../core/clock.dart';
import '../../data/repositories/artist_country_repository.dart';
import '../../data/repositories/artist_info_repository.dart'
    show ArtistInfoRepository;
import 'http_client.dart';
import 'musicbrainz_client.dart';
import '../../core/artist_key.dart';

/// The key of `artist_countries`: `matchKey` of the main artist's name, the one every artist table uses.
String artistCountryKey(String artist) => ArtistInfoRepository.keyOf(artist);

/// A "not found" is asked again only after this long.
const kArtistCountryRetry = Duration(days: 30);

/// Whether the web may be asked (D-421): some part of the enrichment is on (it is off by
/// default), no Jam is going, and the network is online and not metered.
Future<bool> artistCountryAllowed({
  required bool enrichmentOn,
  required bool jamActive,
  required Future<bool> Function() meteredOrOffline,
}) async => enrichmentOn && !jamActive && !await meteredOrOffline();

/// What one [ArtistCountryFinder.run] did.
class ArtistCountryReport {
  const ArtistCountryReport({
    this.checked = 0,
    this.found = 0,
    this.stopped = false,
  });

  /// Artists asked about, and those with a country.
  final int checked, found;

  /// It ended early: a rate limit or an unreachable service, or the app is closing.
  final bool stopped;
}

/// Fills `artist_countries` for the artists of the library (D-390, D-421): MusicBrainz first,
/// then Wikidata through the link MusicBrainz holds. Out of the way: batches while the user
/// leaves the app alone, and it stops on its own at the first refusal. The database says what
/// is left, so the next run carries on from the artists not yet checked.
class ArtistCountryFinder {
  ArtistCountryFinder({
    required this.repo,
    required this.mb,
    required this.wikidata,
    required this.allowed,
    required this.waitIdle,
    this.cancelled = _never,
    this.batch = 20,
    int Function()? now,
  }) : _now = now ?? nowMs;

  final ArtistCountryRepository repo;
  final MusicBrainzClient mb;
  final WikidataClient wikidata;

  /// Asked before every batch and every artist: the enrichment is on, the network is not metered, no Jam.
  final Future<bool> Function() allowed;

  /// Completes when the user leaves the app alone.
  final Future<void> Function() waitIdle;
  final bool Function() cancelled;
  final int batch;
  final int Function() _now;

  static bool _never() => false;

  Future<ArtistCountryReport> run() async {
    final due = await _due();
    var checked = 0, found = 0;
    for (var i = 0; i < due.length; i += batch) {
      await waitIdle();
      for (final e in due.skip(i).take(batch)) {
        if (cancelled() || !await allowed()) {
          return ArtistCountryReport(
            checked: checked,
            found: found,
            stopped: true,
          );
        }
        try {
          final country = await _lookup(e.key, e.value);
          checked++;
          if (country != null) found++;
        } on Object catch (err, st) {
          // 429/403, 503 or no network: do not hammer the service, nothing is recorded for this one.
          if (err is RateLimitedException ||
              err is MusicBrainzUnavailable ||
              err is WebUnavailableException) {
            AppLog.w('artist countries: service refused, stopping', err, st);
            return ArtistCountryReport(
              checked: checked,
              found: found,
              stopped: true,
            );
          }
          AppLog.w('artist countries: ${e.value} failed', err, st);
        }
      }
    }
    return ArtistCountryReport(checked: checked, found: found);
  }

  /// Key and name to ask for, most songs first: never checked, or not found 30 days ago or more.
  Future<List<MapEntry<String, String>>> _due() async {
    final byKey = <String, String>{};
    for (final n in await repo.libraryArtistNames()) {
      final key = artistCountryKey(n);
      if (key.isNotEmpty) byKey.putIfAbsent(key, () => extractPrimaryArtist(n));
    }
    final known = await repo.ofMany(byKey.keys);
    final cut = _now() - kArtistCountryRetry.inMilliseconds;
    bool due(String key) {
      final row = known[key];
      return row == null || (row.country == null && row.checkedAt <= cut);
    }

    return [
      for (final e in byKey.entries)
        if (due(e.key)) e,
    ];
  }

  Future<String?> _lookup(String key, String name) async {
    final origin = await mb.artistOrigin(name);
    var country = origin?.country;
    var source = 'musicbrainz';
    final q = origin?.wikidata;
    if (country == null && q != null) {
      country = await wikidata.countryOf(q);
      source = 'wikidata';
    }
    await repo.upsert(
      key,
      country: country,
      source: country == null ? null : source,
      checkedAtMs: _now(),
    );
    return country;
  }
}
