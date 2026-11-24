import '../../data/repositories/library_entries.dart' show LibrarySort;
import '../../data/settings/settings_store.dart';
import '../audio/audio_backend.dart' show TransitionMode;
import '../online/youtube_service.dart' show AudioQuality, DownloadFormat;

/// One setting that may travel: how to read it, write it and tell a valid value from a hostile one.
class _Spec {
  const _Spec(this.read, this.write, this.valid);

  final Object? Function(AppSettings) read;
  final AppSettings Function(AppSettings, Object) write;
  final bool Function(Object) valid;
}

_Spec _flag(
  bool? Function(AppSettings) read,
  AppSettings Function(AppSettings, bool) write,
) => _Spec(read, (s, v) => write(s, v as bool), (v) => v is bool);

_Spec _choice(
  String Function(AppSettings) read,
  AppSettings Function(AppSettings, String) write,
  Iterable<String> names,
) {
  final ok = names.toSet();
  return _Spec(
    read,
    (s, v) => write(s, v as String),
    (v) => v is String && ok.contains(v),
  );
}

_Spec _real(
  double Function(AppSettings) read,
  AppSettings Function(AppSettings, double) write,
  double lo,
  double hi,
) => _Spec(
  read,
  (s, v) => write(s, (v as num).toDouble()),
  (v) => v is num && v.isFinite && v >= lo && v <= hi,
);

_Spec _whole(
  int Function(AppSettings) read,
  AppSettings Function(AppSettings, int) write,
  int lo,
  int hi,
) => _Spec(
  read,
  (s, v) => write(s, v as int),
  (v) => v is int && v >= lo && v <= hi,
);

/// The settings that do not depend on this device, by key (the key of `SettingsStore`): the only ones a sync
/// reads or writes. Left out on purpose (a test lists every key of the store and makes a new one decide):
/// folders and paths (`downloadLocation`, `backupFolder`, `autoBackup`), the device name and id, the trusted devices
/// and the Jam keys and secrets, `receiveFromLan`, `importDownloadToo.*`, hardware and network (`jamLatencyMs`,
/// `blurredChrome`, `pauseOnZeroVolume`, the equalizer, `karaokeOn`/`karaokeLevel`, `streamCacheMb`,
/// `downloadParallel`, `downloadRateLimitKBps`, `enrichOnMetered`, `prefetchOnMobile`, `shufflePlusUnmeteredOnly`),
/// the storage mode, the files written to (`writeTagsToFiles`, `tagsAlsoInFile`, `writeTagsAfterDownload`), the
/// launcher icon, the layout (`libraryGrid`), places (`radioCountry`, `radioRegion`, `chartCountry`, `radioOnlyCountry`),
/// ids of this library (`playlistSorts`) and the state of this install (`onboardingFinished`, `ytNoticeSeen`,
/// `recentSearches`, `recordHistory`), and `acoustId` (it sends audio fingerprints to an outside service: each device decides). A custom theme (`custom:…`) is not a valid `theme` value: its colours stay here.
final Map<String, _Spec> _synced = {
  'theme': _choice((s) => s.theme, (s, v) => s.copyWith(theme: v), const [
    'notte',
    'oled',
    'chiaro',
  ]),
  'accent': _choice((s) => s.accent, (s, v) => s.copyWith(accent: v), const [
    'viola',
    'blu',
    'acqua',
    'verde',
    'ambra',
    'arancio',
    'rosa',
    'rosso',
  ]),
  // The three sizes the settings page offers.
  'fontScale': _Spec(
    (s) => s.fontScale,
    (s, v) => s.copyWith(fontScale: (v as num).toDouble()),
    (v) => v is num && const [0.9, 1.0, 1.15].contains(v.toDouble()),
  ),
  'compactMode': _flag(
    (s) => s.compactMode,
    (s, v) => s.copyWith(compactMode: v),
  ),
  'reducedMotion': _flag(
    (s) => s.reducedMotion,
    (s, v) => s.copyWith(reducedMotion: v),
  ),
  'spinCover': _flag((s) => s.spinCover, (s, v) => s.copyWith(spinCover: v)),
  'language': _choice(
    (s) => s.language,
    (s, v) => s.copyWith(language: v),
    const ['de', 'en', 'es', 'fr', 'it', 'pt'],
  ),
  'autoEnrich': _flag((s) => s.autoEnrich, (s, v) => s.copyWith(autoEnrich: v)),
  'autoLyrics': _flag((s) => s.autoLyrics, (s, v) => s.copyWith(autoLyrics: v)),
  'deezerMeta': _flag((s) => s.deezerMeta, (s, v) => s.copyWith(deezerMeta: v)),
  'creditsDetails': _flag(
    (s) => s.creditsDetails,
    (s, v) => s.copyWith(creditsDetails: v),
  ),
  'romanization': _flag(
    (s) => s.romanization,
    (s, v) => s.copyWith(romanization: v),
  ),
  'autoCuriosities': _flag(
    (s) => s.autoCuriosities,
    (s, v) => s.copyWith(autoCuriosities: v),
  ),
  'showUndoSnackbar': _flag(
    (s) => s.showUndoSnackbar,
    (s, v) => s.copyWith(showUndoSnackbar: v),
  ),
  'normalizeVolume': _flag(
    (s) => s.normalizeVolume,
    (s, v) => s.copyWith(normalizeVolume: v),
  ),
  'librarySort': _choice(
    (s) => s.librarySort,
    (s, v) => s.copyWith(librarySort: v),
    [for (final v in LibrarySort.values) v.name],
  ),
  // Null here (the criterion's own direction) is not sent, so the other device keeps its choice.
  'librarySortAscending': _flag(
    (s) => s.librarySortAscending,
    (s, v) => s.copyWith(librarySortAscending: v),
  ),
  'downloadFormat': _choice(
    (s) => s.downloadFormat.name,
    (s, v) => s.copyWith(downloadFormat: DownloadFormat.values.byName(v)),
    [for (final v in DownloadFormat.values) v.name],
  ),
  'downloadQuality': _choice(
    (s) => s.downloadQuality.name,
    (s, v) => s.copyWith(downloadQuality: AudioQuality.values.byName(v)),
    [for (final v in AudioQuality.values) v.name],
  ),
  'streamQuality': _choice(
    (s) => s.streamQuality.name,
    (s, v) => s.copyWith(streamQuality: AudioQuality.values.byName(v)),
    [for (final v in AudioQuality.values) v.name],
  ),
  'importSureThreshold': _real(
    (s) => s.importSureThreshold,
    (s, v) => s.copyWith(importSureThreshold: v),
    0,
    1,
  ),
  'importReviewThreshold': _real(
    (s) => s.importReviewThreshold,
    (s, v) => s.copyWith(importReviewThreshold: v),
    0,
    1,
  ),
  'playbackSpeed': _real(
    (s) => s.playbackSpeed,
    (s, v) => s.copyWith(playbackSpeed: v),
    0.5,
    2,
  ),
  'showKaraoke': _flag(
    (s) => s.showKaraoke,
    (s, v) => s.copyWith(showKaraoke: v),
  ),
  'transition': _choice(
    (s) => s.transition.name,
    (s, v) => s.copyWith(transition: TransitionMode.values.byName(v)),
    [for (final v in TransitionMode.values) v.name],
  ),
  'crossfadeSeconds': _whole(
    (s) => s.crossfadeSeconds,
    (s, v) => s.copyWith(crossfadeSeconds: v),
    2,
    12,
  ),
  'crossfadePlainInAlbum': _flag(
    (s) => s.crossfadePlainInAlbum,
    (s, v) => s.copyWith(crossfadePlainInAlbum: v),
  ),
  'shufflePlus': _flag(
    (s) => s.shufflePlus,
    (s, v) => s.copyWith(shufflePlus: v),
  ),
  'shufflePlusEvery': _whole(
    (s) => s.shufflePlusEvery,
    (s, v) => s.copyWith(shufflePlusEvery: v),
    3,
    10,
  ),
};

/// The keys that may travel.
Set<String> get syncedSettingKeys => _synced.keys.toSet();

/// What `GET /sync/settings` sends: the allowed settings of [s] by key (JSON values: bool, number, string).
Map<String, Object> syncedSettings(AppSettings s) => {
  for (final e in _synced.entries)
    // A custom theme stays here: it is not sent, and [planSettings] reads its absence as «keep mine».
    if (e.value.read(s) case final Object v when !(e.key == 'theme' && _isCustom(v))) e.key: v,
};

bool _isCustom(Object theme) => theme is String && theme.startsWith('custom:');

const _sure = 'importSureThreshold', _review = 'importReviewThreshold';

/// The review threshold above the sure one makes no sense: the pair is dropped.
bool _incoherent(num? sure, num? review) => sure != null && review != null && review > sure;

/// What came from the other device, cut to the allowed keys with valid values: anything else is dropped.
Map<String, Object> parseSyncedSettings(Object? json) => {
  if (json is Map)
    for (final e in json.entries)
      if (e.key is String &&
          e.value != null &&
          (_synced[e.key]?.valid(e.value as Object) ?? false))
        e.key as String: e.value as Object,
};

/// A setting the other device has otherwise than this one.
class SettingChange {
  const SettingChange(this.key, this.local, this.remote);

  final String key;

  /// The value here (null when the setting has none, e.g. the sort direction), and the other device's.
  final Object? local;
  final Object remote;
}

/// Every allowed setting whose value differs. Settings have no date, so nothing wins: the user chooses which
/// changes to apply ([applySettings]).
List<SettingChange> planSettings(
  Map<String, Object> local,
  Map<String, Object> remote,
) {
  final skipThresholds = _incoherent(
    (remote[_sure] ?? local[_sure]) as num?,
    (remote[_review] ?? local[_review]) as num?,
  );
  return [
    for (final e in remote.entries)
      if (_synced[e.key]?.valid(e.value) ?? false)
        if (local[e.key] != e.value)
          if (!(skipThresholds && (e.key == _sure || e.key == _review)))
            if (!(e.key == 'theme' && !local.containsKey('theme')))
              SettingChange(e.key, local[e.key], e.value),
  ];
}

/// [base] with [changes] applied; a key out of the list, or a value that is not valid, is ignored.
AppSettings applySettings(AppSettings base, Iterable<SettingChange> changes) {
  var s = base;
  for (final c in changes) {
    final spec = _synced[c.key];
    if (c.key == 'theme' && _isCustom(base.theme)) continue;
    if (spec != null && spec.valid(c.remote)) s = spec.write(s, c.remote);
  }
  return _incoherent(s.importSureThreshold, s.importReviewThreshold)
      ? s.copyWith(
          importSureThreshold: base.importSureThreshold,
          importReviewThreshold: base.importReviewThreshold,
        )
      : s;
}
