import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../data/db/app_database.dart';
import '../data/repositories/radio_repository.dart';
import '../services/radio/radio_browser_client.dart';
import '../services/radio/radio_catalog.dart';
import '../services/radio/playlist_fetch.dart';
import '../services/radio/radio_prefs.dart';
import '../services/radio/saved_refresh.dart';
import '../services/radio/radio_station.dart';
import '../services/radio/regions.dart';
import 'database_providers.dart';
import 'player_providers.dart';
import 'settings_providers.dart';

final radioClientProvider = Provider<RadioBrowserClient>((ref) => RadioBrowserClient.standard());

/// Kept alive: it holds the searches of the last minutes.
final radioCatalogProvider = FutureProvider<RadioCatalog>(
  (ref) async => RadioCatalog(
    ref.watch(radioClientProvider),
    p.join(await appSupportDir(), 'radio'),
  ),
);

final radioRepositoryProvider = Provider<RadioRepository>(
  (ref) => RadioRepository(ref.watch(databaseProvider)),
);

/// «Le mie radio», in the order the user chose.
final savedRadiosProvider = StreamProvider.autoDispose<List<SavedRadio>>(
  (ref) => ref.watch(radioRepositoryProvider).watchAll(),
);

/// The country chosen in the settings, or the system's.
final radioCountryProvider = Provider<String>((ref) {
  final chosen = ref.watch(settingsProvider.select((s) => s.radioCountry));
  return chosen.isNotEmpty
      ? chosen.toUpperCase()
      : defaultRadioCountry(PlatformDispatcher.instance.locale.countryCode);
});

/// The stations of the chosen region, or null while no region is chosen.
final nearYouProvider = FutureProvider.autoDispose<RadioList?>((ref) async {
  final country = ref.watch(radioCountryProvider);
  final regionId = ref.watch(settingsProvider.select((s) => s.radioRegion));
  final region = regionById(country, regionId);
  if (region == null) return null;
  final catalog = await ref.watch(radioCatalogProvider.future);
  return catalog.country(country, region: region);
}, retry: (_, _) => null);

/// The whole country's stations, most listened first.
final radioCountryStationsProvider = FutureProvider.autoDispose<RadioList>((ref) async {
  final country = ref.watch(radioCountryProvider);
  final catalog = await ref.watch(radioCatalogProvider.future);
  return catalog.country(country);
}, retry: (_, _) => null);

/// The regions to choose from. Italy needs no request.
final radioRegionsProvider = FutureProvider.autoDispose<List<RadioRegion>>((ref) async {
  final country = ref.watch(radioCountryProvider);
  if (country == kItalyCode) return regionsFor(country, const []);
  final client = ref.watch(radioClientProvider);
  final countries = await client.countries();
  final name = countries.where((c) => c.code == country).map((c) => c.name).firstOrNull;
  if (name == null) return const [];
  return regionsFor(country, await client.states(name));
}, retry: (_, _) => null);

String? _onlyCountry(Ref ref) => ref.watch(settingsProvider.select((s) => s.radioOnlyCountry))
    ? ref.watch(radioCountryProvider)
    : null;

final radioSearchProvider =
    FutureProvider.autoDispose.family<List<RadioStation>, String>((ref, query) async {
  final only = _onlyCountry(ref);
  final catalog = await ref.watch(radioCatalogProvider.future);
  return catalog.search(query, countryCode: only);
}, retry: (_, _) => null);

final radioGenreProvider =
    FutureProvider.autoDispose.family<List<RadioStation>, String>((ref, tag) async {
  final only = _onlyCountry(ref);
  final catalog = await ref.watch(radioCatalogProvider.future);
  return catalog.byGenre(tag, countryCode: only);
}, retry: (_, _) => null);

final radioPrefsProvider = Provider<RadioPrefs>((ref) => RadioPrefs());

/// The ids of the saved stations (for the star of every row).
final savedRadioIdsProvider = Provider.autoDispose<Set<String>>(
  (ref) => {
    for (final r in ref.watch(savedRadiosProvider).value ?? const <SavedRadio>[]) r.stationId,
  },
);

/// What the station says is on air now (null: nothing, or not a radio).
final onAirProvider = StreamProvider<String?>((ref) async* {
  final h = ref.watch(audioHandlerProvider);
  yield h.onAir;
  yield* h.onAirStream;
});

/// The countries Radio Browser knows, to choose from.
final radioCountriesProvider = FutureProvider.autoDispose<List<RadioCountry>>(
  (ref) => ref.watch(radioClientProvider).countries(),
  retry: (_, _) => null,
);

/// True while the saved stations are checked on Radio Browser: it shows in the Activity centre.
class RadioChecking extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final radioCheckingProvider = NotifierProvider<RadioChecking, bool>(RadioChecking.new);

/// Reads the saved stations again (once a day at most); called by [RadioOps.refreshSaved].
final radioRefreshProvider = Provider<Future<bool> Function()>((ref) => () => refreshSavedRadios(
      repo: ref.read(radioRepositoryProvider),
      client: ref.read(radioClientProvider),
      prefs: ref.read(radioPrefsProvider),
      onRequest: () => ref.read(radioCheckingProvider.notifier).set(true),
    ));

/// How a typed `.pls` / `.m3u` address is downloaded (faked in tests).
final playlistFetchProvider =
    Provider<Future<String> Function(Uri)>((ref) => (url) => fetchPlaylistText(url));
