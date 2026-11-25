import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/services/audio/audio_backend.dart' show TransitionMode;
import 'package:codecore/services/audio/equalizer.dart' show EqPreset;
import 'package:codecore/services/backup/backup_service.dart'
    show kDeviceBoundKeys;
import 'package:codecore/services/import/import_options.dart'
    show importDownloadTooPrefix;
import 'package:codecore/services/online/youtube_service.dart'
    show AudioQuality, DownloadFormat;
import 'package:codecore/services/share/settings_sync.dart';
import 'package:codecore/ui/theme/palette.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every setting different from the defaults, the ones that depend on the device included.
const _other = AppSettings(
  theme: 'oled',
  accent: 'rosso',
  fontScale: 1.15,
  compactMode: true,
  reducedMotion: true,
  spinCover: true,
  pauseOnZeroVolume: true,
  blurredChrome: true,
  language: 'de',
  autoEnrich: false,
  autoLyrics: false,
  deezerMeta: false,
  acoustId: false,
  creditsDetails: false,
  romanization: false,
  autoCuriosities: false,
  enrichOnMetered: true,
  showUndoSnackbar: false,
  deviceName: 'Other',
  jamLatencyMs: 300,
  normalizeVolume: true,
  receiveFromLan: true,
  librarySort: 'alpha',
  librarySortAscending: true,
  playlistSorts: {'1': 'alpha:asc'},
  libraryGrid: true,
  recentSearches: ['x'],
  ytNoticeSeen: true,
  onboardingDone: true,
  recordHistory: false,
  downloadParallel: 3,
  downloadRateLimitKBps: 500,
  downloadFormat: DownloadFormat.mp3Low,
  downloadQuality: AudioQuality.low,
  streamQuality: AudioQuality.low,
  streamCacheMb: 4096,
  downloadLocation: '/other',
  autoBackup: true,
  backupFolder: '/other/backup',
  storageMode: StorageMode.device,
  prefetchOnMobile: false,
  importSureThreshold: 0.9,
  importReviewThreshold: 0.7,
  playbackSpeed: 1.5,
  eqEnabled: true,
  karaokeOn: true,
  showKaraoke: false,
  karaokeLevel: 0.9,
  eqSpeaker: EqProfile(preset: EqPreset.bass),
  eqHeadphones: EqProfile(preset: EqPreset.voice),
  transition: TransitionMode.crossfade,
  crossfadeSeconds: 10,
  crossfadePlainInAlbum: false,
  writeTagsToFiles: true,
  tagsAlsoInFile: false,
  writeTagsAfterDownload: false,
  shufflePlus: true,
  shufflePlusEvery: 8,
  shufflePlusUnmeteredOnly: false,
  radioCountry: 'IT',
  radioRegion: 'Lazio',
  chartCountry: 'IT',
  radioOnlyCountry: true,
  iconFollow: IconFollow.on,
);

/// What `writeSettings` leaves in the preferences for [s].
Future<Map<String, Object?>> _stored(AppSettings s) async {
  SharedPreferences.setMockInitialValues({});
  await (await SettingsStore.open()).writeSettings(s);
  final prefs = await SharedPreferences.getInstance();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)};
}

void main() {
  const allowed = {
    'theme',
    'accent',
    'fontScale',
    'compactMode',
    'reducedMotion',
    'spinCover',
    'language',
    'autoEnrich',
    'autoLyrics',
    'deezerMeta',
    'creditsDetails',
    'romanization',
    'autoCuriosities',
    'showUndoSnackbar',
    'normalizeVolume',
    'librarySort',
    'librarySortAscending',
    'downloadFormat',
    'downloadQuality',
    'streamQuality',
    'importSureThreshold',
    'importReviewThreshold',
    'playbackSpeed',
    'showKaraoke',
    'transition',
    'crossfadeSeconds',
    'crossfadePlainInAlbum',
    'shufflePlus',
    'shufflePlusEvery',
  };
  // The keys the store writes that never travel, each one decided (a new key fails the test below until it is put here or above).
  const stays = {
    'deviceName',
    'acoustId', // sends audio fingerprints to an outside service: each device decides
    'pauseOnZeroVolume',
    'blurredChrome',
    'enrichOnMetered',
    'jamLatencyMs',
    'receiveFromLan',
    'playlistSorts',
    'libraryGrid',
    'libraryGridChosen',
    'libraryDensity',
    'recentSearches',
    'ytNoticeSeen',
    'onboardingFinished',
    'recordHistory',
    'downloadParallel',
    'downloadRateLimitKBps',
    'streamCacheMb',
    'downloadLocation',
    'autoBackup',
    'backupFolder',
    'storageMode',
    'prefetchOnMobile',
    'eqEnabled',
    'karaokeOn',
    'karaokeLevel',
    'eqPreset.speaker',
    'eqGains.speaker',
    'eqPreset.headphones',
    'eqGains.headphones',
    'writeTagsToFiles',
    'tagsAlsoInFile',
    'writeTagsAfterDownload',
    'shufflePlusUnmeteredOnly',
    'radioCountry',
    'radioRegion',
    'chartCountry',
    'radioOnlyCountry',
    'iconFollow',
  };

  test('the list of settings that travel is exactly this one: no folder, permission, device name, secret or hardware value', () {
    expect(syncedSettingKeys, allowed);
    expect(syncedSettingKeys.intersection(kDeviceBoundKeys), isEmpty);
    expect(
      syncedSettingKeys.where(
        (k) => k.startsWith(importDownloadTooPrefix) || k.startsWith('jam'),
      ),
      isEmpty,
    );
  });

  test('every setting the store writes is decided: it travels or it stays, none is left out by chance', () async {
    final written = (await _stored(_other)).keys.toSet();
    expect(
      written.difference({...allowed, ...stays}),
      isEmpty,
      reason: 'a new setting: decide if it depends on the device',
    );
    expect(
      allowed.difference(written),
      isEmpty,
      reason: 'a key that the store no longer writes',
    );
    expect(allowed.intersection(stays), isEmpty);
  });

  test('the closed lists match the app: themes, accents and languages', () {
    final sent = syncedSettings(const AppSettings());
    for (final t in AppThemeId.values) {
      expect(parseSyncedSettings({'theme': t.name}), {'theme': t.name});
    }
    for (final a in CcAccent.values) {
      expect(parseSyncedSettings({'accent': a.name}), {'accent': a.name});
    }
    for (final l in AppLocalizations.supportedLocales) {
      expect(parseSyncedSettings({'language': l.languageCode}), {
        'language': l.languageCode,
      });
    }
    expect(
      sent.keys.toSet(),
      allowed.difference({'librarySortAscending'}),
      reason: 'a null direction is not sent',
    );
  });

  test(
    'a sync aligns the settings that travel, once confirmed, and nothing else',
    () async {
      const mine = AppSettings(
        deviceName: 'Mine',
        downloadLocation: '/mine',
        backupFolder: '/mine/backup',
      );
      final plan = planSettings(syncedSettings(mine), syncedSettings(_other));
      expect(
        {for (final c in plan) c.key},
        allowed,
        reason: 'every setting that travels differs here',
      );
      final after = applySettings(mine, plan);
      final before = await _stored(mine), now = await _stored(after);
      final changed = {
        for (final k in {...before.keys, ...now.keys})
          if ('${before[k]}' != '${now[k]}') k,
      };
      expect(
        changed,
        allowed,
        reason:
            'only the allowed ones moved: folders, name and the rest stayed',
      );
      expect(
        (after.deviceName, after.downloadLocation, after.backupFolder),
        ('Mine', '/mine', '/mine/backup'),
      );
      expect(
        (
          after.theme,
          after.fontScale,
          after.crossfadeSeconds,
          after.downloadFormat,
          after.librarySortAscending,
        ),
        ('oled', 1.15, 10, DownloadFormat.mp3Low, true),
      );
      expect(
        planSettings(syncedSettings(after), syncedSettings(_other)),
        isEmpty,
        reason: 'a second run has nothing to show',
      );
    },
  );

  test('the user picks: only the chosen changes apply', () {
    final plan = planSettings(
      syncedSettings(const AppSettings()),
      syncedSettings(_other),
    );
    final after = applySettings(const AppSettings(), [
      for (final c in plan)
        if (c.key == 'theme') c,
    ]);
    expect(
      (after.theme, after.accent, after.fontScale),
      ('oled', 'viola', 1.0),
    );
  });

  test('values are checked by type and range; anything else is dropped', () {
    expect(
      parseSyncedSettings({
        'theme': 'custom:abc', // a custom theme stays on its device
        'accent': 'fucsia',
        'fontScale': 99,
        'language': 'xx',
        'crossfadeSeconds': 2.5,
        'shufflePlusEvery': 99,
        'playbackSpeed': '1.5',
        'importSureThreshold': double.nan,
        'compactMode': 1,
        'transition': 'teleport',
        'downloadLocation': '/etc',
        'deviceName': 'x',
        'trustedDevices': '[]',
        '${importDownloadTooPrefix}7': true,
        'jamFriends': 'x',
      }),
      isEmpty,
    );
    expect(parseSyncedSettings('x'), isEmpty);
    expect(parseSyncedSettings(null), isEmpty);
    expect(
      parseSyncedSettings({
        'fontScale': 1,
        'crossfadeSeconds': 2,
        'playbackSpeed': 2,
        'theme': 'chiaro',
        'compactMode': true,
      }),
      {
        'fontScale': 1,
        'crossfadeSeconds': 2,
        'playbackSpeed': 2,
        'theme': 'chiaro',
        'compactMode': true,
      },
    );
    // A hostile change that gets through to the apply step is ignored there too.
    final s = applySettings(const AppSettings(), const [
      SettingChange('deviceName', null, 'evil'),
      SettingChange('downloadLocation', null, '/etc'),
      SettingChange('crossfadeSeconds', 6, 99),
    ]);
    expect(
      (s.deviceName, s.downloadLocation, s.crossfadeSeconds),
      (null, '', 6),
    );
  });

  test('the limits of each range: the edge is valid, one step past it is not', () {
    bool ok(String k, Object v) => parseSyncedSettings({k: v}).isNotEmpty;
    expect([ok('playbackSpeed', 0.5), ok('playbackSpeed', 2.0), ok('playbackSpeed', 0.49), ok('playbackSpeed', 2.01)], [true, true, false, false]);
    expect([ok('crossfadeSeconds', 2), ok('crossfadeSeconds', 12), ok('crossfadeSeconds', 1), ok('crossfadeSeconds', 13)], [true, true, false, false]);
    expect([ok('importSureThreshold', 0.0), ok('importSureThreshold', 1.0), ok('importSureThreshold', -0.01), ok('importSureThreshold', 1.01)], [true, true, false, false]);
    // Only the three sizes the settings page offers.
    expect([for (final v in [0.9, 1.0, 1.15, 1]) ok('fontScale', v)], [true, true, true, true]);
    expect([for (final v in [0.8, 1.05, 1.3, 1.5]) ok('fontScale', v)], [false, false, false, false]);
  });

  test('a pair of thresholds with the review above the sure one is dropped, in the plan and in the apply', () {
    final local = syncedSettings(const AppSettings());
    expect(
      planSettings(local, {'importSureThreshold': 0.5, 'importReviewThreshold': 0.9}),
      isEmpty,
    );
    expect(
      planSettings(local, {'importReviewThreshold': 0.95}),
      isEmpty,
      reason: 'against the sure one here (0.80)',
    );
    expect(
      [for (final c in planSettings(local, {'importSureThreshold': 0.9, 'importReviewThreshold': 0.6})) c.key],
      ['importSureThreshold', 'importReviewThreshold'],
    );
    final s = applySettings(const AppSettings(), const [
      SettingChange('importSureThreshold', 0.8, 0.3),
    ]);
    expect((s.importSureThreshold, s.importReviewThreshold), (0.80, 0.55));
  });

  test('a custom theme stays: it is not sent, not proposed and not replaced', () {
    const custom = AppSettings(theme: 'custom:abc');
    expect(syncedSettings(custom).containsKey('theme'), isFalse);
    expect(planSettings(syncedSettings(custom), {'theme': 'oled', 'accent': 'rosso'}).map((c) => c.key), ['accent']);
    expect(applySettings(custom, const [SettingChange('theme', null, 'oled')]).theme, 'custom:abc');
  });
}
