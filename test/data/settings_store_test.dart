import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/audio/audio_backend.dart' show TransitionMode;
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/youtube_service.dart'
    show DownloadFormat;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('unsyncedLyrics ignores values that are not numbers and duplicates', () async {
    SharedPreferences.setMockInitialValues({'unsyncedLyrics': ['4', 'x', '4', '']});
    final store = await SettingsStore.open();
    expect(store.readUnsyncedLyrics(), {4});
  });
  test('unsyncedLyrics is empty when absent and read back as track ids', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readUnsyncedLyrics(), isEmpty);
    await store.writeUnsyncedLyrics({7, 3});
    store = await SettingsStore.open();
    expect(store.readUnsyncedLyrics(), {3, 7});
  });
  test('deezerMeta is on when absent and a saved false stays false', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().deezerMeta, true);
    SharedPreferences.setMockInitialValues({'deezerMeta': false});
    store = await SettingsStore.open();
    expect(store.readSettings().deezerMeta, false);
  });
  test('acoustId is on when absent and a saved false stays false', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().acoustId, true);
    SharedPreferences.setMockInitialValues({'acoustId': false});
    store = await SettingsStore.open();
    expect(store.readSettings().acoustId, false);
  });
  test('library sort direction: absent means the criterion default, a saved one is read back', () async {
    SharedPreferences.setMockInitialValues({'librarySort': 'plays'});
    var store = await SettingsStore.open();
    expect(store.readSettings().librarySort, 'plays');
    expect(store.readSettings().librarySortAscending, isNull);
    await store.writeSettings(store.readSettings().copyWith(librarySortAscending: true));
    store = await SettingsStore.open();
    expect(store.readSettings().librarySortAscending, true);
  });
  test('each playlist keeps its own order, separate from the others', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().playlistSorts, isEmpty);
    await store.writeSettings(store.readSettings().copyWith(
        playlistSorts: {'12': 'title:asc', '7': 'year:desc'}));
    store = await SettingsStore.open();
    expect(store.readSettings().playlistSorts, {'12': 'title:asc', '7': 'year:desc'});
    SharedPreferences.setMockInitialValues({'playlistSorts': '{broken'});
    store = await SettingsStore.open();
    expect(store.readSettings().playlistSorts, isEmpty);
  });
  test('sort keys of the wrong type (a tampered backup) read as the defaults, without throwing', () async {
    SharedPreferences.setMockInitialValues({'playlistSorts': 5, 'librarySortAscending': 'yes'});
    final store = await SettingsStore.open();
    expect(store.readSettings().playlistSorts, isEmpty);
    expect(store.readSettings().librarySortAscending, isNull);
  });
  streamCacheSettingTests();
  test('playback state round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readPlayback().queueIds, isEmpty);
    await store.writePlayback(const SavedPlayback(
      queueIds: [3, 1, 2],
      index: 2,
      positionMs: 4500,
      volume: 0.5,
      shuffle: true,
      repeat: PlayRepeat.all,
    ));
    final s = store.readPlayback();
    expect(s.queueIds, [3, 1, 2]);
    expect(s.index, 2);
    expect(s.positionMs, 4500);
    expect(s.volume, 0.5);
    expect(s.shuffle, true);
    expect(s.repeat, PlayRepeat.all);
  });

  test('import thresholds default to 0.80 / 0.55 and round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().importSureThreshold, 0.80);
    expect(store.readSettings().importReviewThreshold, 0.55);
    await store.writeSettings(const AppSettings(
        importSureThreshold: 0.9, importReviewThreshold: 0.6));
    expect(store.readSettings().importSureThreshold, 0.9);
    expect(store.readSettings().importReviewThreshold, 0.6);
  });

  test('creditsDetails is off by default and round trips', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().creditsDetails, isFalse);
    await store.writeSettings(const AppSettings(creditsDetails: true));
    expect(store.readSettings().creditsDetails, isTrue);
  });

  test('autoCuriosities is off by default and round trips', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().autoCuriosities, isFalse);
    await store.writeSettings(const AppSettings(autoCuriosities: true));
    expect(store.readSettings().autoCuriosities, isTrue);
  });

  test('playback speed defaults to 1× and is kept within 0.5–2', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().playbackSpeed, 1.0);
    await store.writeSettings(const AppSettings(playbackSpeed: 1.5));
    expect(store.readSettings().playbackSpeed, 1.5);
    SharedPreferences.setMockInitialValues({'playbackSpeed': 7.0});
    expect((await SettingsStore.open()).readSettings().playbackSpeed, 2.0);
  });

  test('the track transition defaults to normal, with a 6 s crossfade kept within 2–12', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    var s = store.readSettings();
    expect(s.transition, TransitionMode.normal);
    expect(s.crossfadeSeconds, 6);
    expect(s.crossfadePlainInAlbum, isTrue);
    await store.writeSettings(const AppSettings(
        transition: TransitionMode.crossfade,
        crossfadeSeconds: 9,
        crossfadePlainInAlbum: false));
    s = store.readSettings();
    expect(s.transition, TransitionMode.crossfade);
    expect(s.crossfadeSeconds, 9);
    expect(s.crossfadePlainInAlbum, isFalse);
    SharedPreferences.setMockInitialValues({'crossfadeSeconds': 99, 'transition': 'gapless'});
    s = (await SettingsStore.open()).readSettings();
    expect(s.crossfadeSeconds, 12);
    expect(s.transition, TransitionMode.gapless);
    SharedPreferences.setMockInitialValues({'transition': 'something-old'});
    expect((await SettingsStore.open()).readSettings().transition, TransitionMode.normal);
  });

  test('theme notte and accent violet by default; the light theme name is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().theme, 'notte');
    expect(store.readSettings().accent, 'viola');
    await store.writeSettings(const AppSettings(theme: 'chiaro', accent: 'rosa'));
    final s = store.readSettings();
    expect(s.theme, 'chiaro');
    expect(s.accent, 'rosa');
  });

  test('the blurred dock is off by default and the choice is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().blurredChrome, isFalse);
    await store.writeSettings(const AppSettings(blurredChrome: true));
    expect(store.readSettings().blurredChrome, isTrue);
  });

  test('the spinning cover is off by default and the choice is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().spinCover, isFalse);
    await store.writeSettings(const AppSettings(spinCover: true));
    expect(store.readSettings().spinCover, isTrue);
  });

  test('the listening history is on by default and the choice is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readSettings().recordHistory, isTrue);
    await store.writeSettings(const AppSettings(recordHistory: false));
    expect(store.readSettings().recordHistory, isFalse);
  });

  test('the old online-source and SoundCloud choices are ignored: nothing breaks, nothing is written back', () async {
    SharedPreferences.setMockInitialValues({'searchSource': 'soundcloud', 'importSoundCloud': true});
    final store = await SettingsStore.open();
    await store.writeSettings(store.readSettings().copyWith(recordHistory: false));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('searchSource'), 'soundcloud', reason: 'left as it was, never read');
    expect(store.readSettings().recordHistory, isFalse);
  });

  test('downloads are M4A by default, also for those who had the old MP3 default; a choice is remembered',
      () async {
    SharedPreferences.setMockInitialValues({'downloadOriginal': false});
    final store = await SettingsStore.open();
    expect(store.readSettings().downloadFormat, DownloadFormat.m4a);

    await store.writeSettings(
        store.readSettings().copyWith(downloadFormat: DownloadFormat.mp3High));
    expect(store.readSettings().downloadFormat, DownloadFormat.mp3High);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('downloadOriginal'), isFalse, reason: 'the old switch is gone');
  });

  test('the groups the user said are not duplicates are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    expect(store.readNotDuplicates(), isEmpty);
    await store.writeNotDuplicates({'3,4', '1,2'});
    expect(store.readNotDuplicates(), {'1,2', '3,4'});
  });

  test('Shuffle+ is off, one in 4, Wi‑Fi only by default; its choices are saved and kept within 3–10', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    var s = store.readSettings();
    expect(s.shufflePlus, isFalse);
    expect(s.shufflePlusEvery, 4);
    expect(s.shufflePlusUnmeteredOnly, isTrue);
    await store.writeSettings(
        s.copyWith(shufflePlus: true, shufflePlusEvery: 7, shufflePlusUnmeteredOnly: false));
    s = store.readSettings();
    expect(s.shufflePlus, isTrue);
    expect(s.shufflePlusEvery, 7);
    expect(s.shufflePlusUnmeteredOnly, isFalse);

    SharedPreferences.setMockInitialValues({'shufflePlusEvery': 99});
    expect((await SettingsStore.open()).readSettings().shufflePlusEvery, 10);
  });

  test('the radio choices default to «ask» and are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    var s = store.readSettings();
    expect((s.radioCountry, s.radioRegion, s.radioOnlyCountry), ('', '', false));
    await store.writeSettings(s.copyWith(radioCountry: 'DE', radioRegion: 'Bayern', radioOnlyCountry: true));
    s = store.readSettings();
    expect((s.radioCountry, s.radioRegion, s.radioOnlyCountry), ('DE', 'Bayern', true));
  });
}

void streamCacheSettingTests() {
  test('streamCacheMb: default 1024, saved, out-of-range clamped to 256-8192', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().streamCacheMb, 1024);
    await store.writeSettings(store.readSettings().copyWith(streamCacheMb: 2048));
    expect(store.readSettings().streamCacheMb, 2048);
    for (final (raw, want) in [(10, 256), (99999, 8192)]) {
      SharedPreferences.setMockInitialValues({'streamCacheMb': raw});
      store = await SettingsStore.open();
      expect(store.readSettings().streamCacheMb, want);
    }
  });
}
