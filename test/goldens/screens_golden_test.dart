// Golden tests of the main screens at 100 % and 150 % text, phone and desktop.
// Generated and compared on Linux only (fonts and rasterisation differ elsewhere).
//   flutter test --update-goldens test/goldens     # after an intended change
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/radio_repository.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/services/radio/radio_browser_client.dart';
import 'package:codecore/services/radio/radio_catalog.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show genreMixProvider;
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/shuffle_plus/genre_mix.dart' show GenreMixState;
import 'package:codecore/ui/screens/radio/radio_screen.dart';
import 'package:codecore/ui/screens/search/genre_screen.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/screens/stats/stats_charts.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/import_providers.dart' show searchCacheCountProvider;
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/home/home_screen.dart' show clockProvider;
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/onboarding/onboarding_screen.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';
import 'tolerant_comparator.dart';

class _LibraryTab extends NavIndexNotifier {
  @override
  int build() => NavTab.library.index;
}

class _FakeJam extends JamController {
  @override
  JamUiState build() => const JamUiState(
        phase: JamPhase.active,
        role: JamRole.host,
        peerName: 'Telefono di Anna',
        peerId: 'peer',
        jam: JamState(
          version: 3,
          items: [
            JamItem(id: 1, ownerDeviceId: 'host', title: 'Futura', ext: 'mp3',
                artist: 'Lucio Dalla', durationMs: 180000),
            JamItem(id: 2, ownerDeviceId: 'peer', title: 'Get Lucky', ext: 'mp3',
                artist: 'Daft Punk', durationMs: 248000),
          ],
          currentIndex: 0,
          // Paused at 30 %: the ring and the times are the same on every run.
          playing: false,
          positionMs: 54000,
          participants: [
            JamParticipant(id: 'host', name: 'Emanuele'),
            JamParticipant(id: 'peer', name: 'Anna'),
          ],
          hostDeviceId: 'host',
          outputDeviceId: 'host',
        ),
      );
}

/// Same colour for the same cover key, on every run.
Color _colourOf(String key) {
  var h = 0x811C9DC5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFF;
  }
  return Color(0xFF000000 | h | 0x303030);
}

void main() {
  // Fonts and rasterisation are only reproducible on one platform.
  if (!Platform.isLinux) return;

  setUpAll(() {
    TolerantComparator.install();
    coverImageStub = (key) => ColoredBox(color: _colourOf(key));
  });
  tearDownAll(() => coverImageStub = null);

  for (final size in ShotSize.values) {
    for (final scale in const [1.0, 1.5]) {
      final tag = '${size.name}_${(scale * 100).round()}';
      group(tag, () {
        testWidgets('library', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const AppShell(),
                  textScale: scale,
                  extra: [navIndexProvider.overrideWith(_LibraryTab.new)]);
              await s.expectGolden('${tag}_library.png');
            }));

        if (size == ShotSize.phone && scale == 1.0) {
          testWidgets('home', (tester) => withGoldenShot(tester, size, (s) async {
                // Two half-played tracks fill «Riprendi»; a playing queue gives
                // the mini-player (ring around the cover).
                await tester.runAsync(() async {
                  for (final (i, id) in s.seed.trackIds.take(2).indexed) {
                    await (s.h.db.update(s.h.db.tracks)
                          ..where((t) => t.id.equals(id)))
                        .write(TracksCompanion(
                            resumePositionMs: const Value(60000),
                            lastPlayedAt: Value(1000 + i)));
                  }
                  await s.h.handler.playQueue(s.seed.trackIds.take(6).toList(), 2);
                });
                // Taller than the usual phone so the fan clears the dock.
                tester.view.physicalSize = const Size(360, 1150) * size.dpr;
                await s.show(const AppShell(),
                    extra: [clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 14))]);
                await s.expectGolden('${tag}_home.png');
              }));
        }

        testWidgets('album', (tester) => withGoldenShot(tester, size, (s) async {
              final rows = await tester.runAsync(() => s.h.db.customSelect(
                  "SELECT album_key FROM tracks WHERE album = 'The Wall' LIMIT 1").get());
              final key = rows!.first.read<String>('album_key');
              await s.show(
                  AlbumDetailScreen(
                      album: AlbumSummary(
                          albumKey: key,
                          title: 'The Wall',
                          artist: 'Pink Floyd',
                          variousArtists: false,
                          trackCount: 5,
                          durationMs: 1000000,
                          year: 1979,
                          coverKey: s.seed.coverKeys[key])),
                  textScale: scale);
              await s.expectGolden('${tag}_album.png');
            }));

        testWidgets('now_playing', (tester) => withGoldenShot(tester, size, (s) async {
              await tester.runAsync(() => s.h.handler.playQueue(s.seed.trackIds, 12));
              await s.show(const NowPlayingScreen(), textScale: scale);
              await s.expectGolden('${tag}_now_playing.png');
            }));

        testWidgets('settings', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const SettingsScreen(), textScale: scale, extra: [
                ytDlpStatusProvider
                    .overrideWith((_) async => const YtDlpStatus('2026.08.19')),
                searchCacheCountProvider.overrideWith((_) async => 0),
              ]);
              await s.expectGolden('${tag}_settings.png');
            }));

        testWidgets('all_tracks', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const AllTracksScreen(), textScale: scale);
              await s.expectGolden('${tag}_all_tracks.png');
            }));

        testWidgets('selection', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const AllTracksScreen(), textScale: scale);
              await tester.longPress(find.byType(TrackRow).at(1));
              await tester.tap(find.byType(TrackRow).at(3));
              await s.settle();
              await s.expectGolden('${tag}_selection.png');
            }));

        testWidgets('light_library', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const AppShell(),
                  textScale: scale,
                  theme: AppThemeId.chiaro,
                  accent: CcAccent.blu,
                  extra: [navIndexProvider.overrideWith(_LibraryTab.new)]);
              await s.expectGolden('${tag}_light_library.png');
            }));

        testWidgets('onboarding', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const OnboardingScreen(askAudioPermission: true),
                  textScale: scale);
              await tester.tap(find.text('Avanti'));
              await s.settle();
              await s.expectGolden('${tag}_onboarding.png');
            }));

        testWidgets('radio', (tester) => withGoldenShot(tester, size, (s) async {
              const near = [
                RadioStation(id: 'n1', name: 'Radio Vicina Uno', streamUrl: 'http://r.test/1', state: 'Lombardia', codec: 'MP3', bitrate: 128),
                RadioStation(id: 'n2', name: 'Radio Vicina Due', streamUrl: 'http://r.test/2', state: 'Lombardia', codec: 'AAC', bitrate: 96),
              ];
              await s.h.store.writeSettings(
                  s.h.store.readSettings().copyWith(radioCountry: 'IT', radioRegion: 'lombardia'));
              await tester.runAsync(() async {
                final repo = RadioRepository(s.h.db);
                for (final (i, n) in ['Radio Alfa', 'Radio Beta', 'Radio Gamma'].indexed) {
                  await repo.save(RadioStation(id: 's$i', name: n, streamUrl: 'http://r.test/s$i', codec: 'MP3', bitrate: 128));
                }
              });
              await s.show(const RadioScreen(), textScale: scale, extra: [
                radioRefreshProvider.overrideWithValue(() async => false),
                radioCountriesProvider.overrideWith((ref) async =>
                    [const RadioCountry(name: 'Italy', code: 'IT', stationCount: 1797)]),
                nearYouProvider.overrideWith((ref) async => RadioList(near, stale: false, fetchedAt: DateTime(2026, 10, 1))),
                radioCountryStationsProvider.overrideWith((ref) async => RadioList(near)),
              ]);
              await s.expectGolden('${tag}_radio.png');
            }));

        testWidgets('search', (tester) => withGoldenShot(tester, size, (s) async {
              await s.h.store.writeSettings(s.h.store.readSettings().copyWith(
                  recentSearches: ['Franco Battiato', 'Daft Punk', 'Radiohead Kid A']));
              await s.show(const SearchScreen(), textScale: scale);
              await s.expectGolden('${tag}_search.png');
            }));

          testWidgets('genre', (tester) => withGoldenShot(tester, size, (s) async {
                await s.show(const GenreScreen(genre: 'Pop'), textScale: scale, extra: [
                  genreMixProvider.overrideWith((ref, genre) => Stream.value(GenreMixState(
                      suggested: [
                        for (final (i, t) in ['Come Away With Me', 'Il cielo in una stanza'].indexed)
                          YtResult(id: 'g$i', title: t, channel: 'Chan', duration: const Duration(minutes: 3), artists: const ['Norah Jones']),
                      ],
                      incoming: 1))),
                ]);
                await s.expectGolden('${tag}_genre.png');
              }));

        testWidgets('stats', (tester) => withGoldenShot(tester, size, (s) async {
              await tester.runAsync(() async {
                final repo = PlayHistoryRepository(s.h.db);
                final ids = s.seed.trackIds;
                for (var d = 1; d <= 15; d++) {
                  await repo.start(ids[d % ids.length], DateTime(2026, 10, d, 21).millisecondsSinceEpoch,
                      msPlayed: (10 + (d * 37) % 90) * 60000);
                }
              });
              await s.show(StatsScreen(now: DateTime(2026, 10, 16, 9)), textScale: scale);
              // Touch the bar of day 9.
              final box = tester.getRect(find.byType(StatsBars));
              await tester.tapAt(Offset(box.left + box.width / 31 * 8.5, box.center.dy));
              await s.settle();
              await s.expectGolden('${tag}_stats.png');
            }));

        testWidgets('jam', (tester) => withGoldenShot(tester, size, (s) async {
              await s.show(const JamScreen(),
                  textScale: scale,
                  extra: [jamProvider.overrideWith(_FakeJam.new)]);
              await s.expectGolden('${tag}_jam.png');
            }));
      });
    }
  }
}
