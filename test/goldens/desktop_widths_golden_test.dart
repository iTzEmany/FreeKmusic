// Baseline goldens of nine desktop screens at 1000, 1440 and 1920 px, plus a few
// phone screens at 360 dp. Linux only.
//   flutter test --update-goldens test/goldens/desktop_widths_golden_test.dart
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/settings/settings_store.dart' show StorageMode;
import 'package:codecore/providers/import_providers.dart' show searchCacheCountProvider;
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart' show albumMissingTracksProvider;
import 'package:codecore/services/online/ytm_artist.dart' show YtmAlbumTrack;
import 'package:codecore/ui/screens/home/home_screen.dart' show clockProvider;
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:codecore/data/repositories/library_entries.dart' show LibraryKind;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';
import '../support/fake_ytm.dart' show ytmSong;
import 'tolerant_comparator.dart';

class _LibraryTab extends NavIndexNotifier {
  @override
  int build() => NavTab.library.index;
}

/// Same colour for the same cover key, on every run.
Color _colourOf(String key) {
  var h = 0x811C9DC5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFF;
  }
  return Color(0xFF000000 | h | 0x303030);
}

final _clock = clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 14));

typedef _Screen = Future<void> Function(Shot s, WidgetTester tester, String file);

Future<void> _home(Shot s, WidgetTester tester, String file) async {
  await tester.runAsync(() async {
    for (final (i, id) in s.seed.trackIds.take(2).indexed) {
      await (s.h.db.update(s.h.db.tracks)..where((t) => t.id.equals(id)))
          .write(TracksCompanion(resumePositionMs: const Value(60000), lastPlayedAt: Value(1000 + i)));
    }
    await s.h.handler.playQueue(s.seed.trackIds.take(6).toList(), 2);
  });
  await s.show(const AppShell(), extra: [_clock]);
  await s.expectGolden(file);
}

Future<void> _libraryTab(Shot s, WidgetTester tester, String file, [String? label]) async {
  await s.show(const AppShell(), extra: [navIndexProvider.overrideWith(_LibraryTab.new)]);
  if (label != null) {
    await tester.tap(find.descendant(
        of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text(label)));
    await s.settle();
  }
  await s.expectGolden(file);
}

Future<void> _album(Shot s, WidgetTester tester, String file) async {
  final rows = await tester.runAsync(() => s.h.db.customSelect(
      "SELECT album_key FROM tracks WHERE album = 'The Wall' LIMIT 1").get());
  final key = rows!.first.read<String>('album_key');
  await s.h.store.writeSettings(s.h.store.readSettings().copyWith(storageMode: StorageMode.stream));
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
      extra: [
        albumMissingTracksProvider(key).overrideWith((ref) async => [
              YtmAlbumTrack(9, ytmSong('w1', 'Run Like Hell', seconds: 262)),
              YtmAlbumTrack(10, ytmSong('w2', 'Waiting for the Worms', seconds: 244)),
            ]),
      ]);
  await s.expectGolden(file);
}

Future<void> _stats(Shot s, WidgetTester tester, String file) async {
  await tester.runAsync(() async {
    final repo = PlayHistoryRepository(s.h.db);
    final ids = s.seed.trackIds;
    for (var d = 1; d <= 15; d++) {
      await repo.start(ids[d % ids.length], DateTime(2026, 10, d, 21).millisecondsSinceEpoch,
          msPlayed: (10 + (d * 37) % 90) * 60000);
    }
  });
  await s.show(StatsScreen(now: DateTime(2026, 10, 16, 9)));
  await s.expectGolden(file);
}

final _screens = <String, _Screen>{
  'home': _home,
  'library': (s, t, f) => _libraryTab(s, t, f),
  'all_tracks': (s, t, f) async {
    await s.show(const AllTracksScreen());
    await s.expectGolden(f);
  },
  'album': _album,
  'playlists': (s, t, f) => _libraryTab(s, t, f, 'Playlist'),
  'search': (s, t, f) async {
    await s.h.store.writeSettings(s.h.store.readSettings().copyWith(
        recentSearches: ['Franco Battiato', 'Daft Punk', 'Radiohead Kid A']));
    await s.show(const SearchScreen());
    await s.expectGolden(f);
  },
  'settings': (s, t, f) async {
    await s.show(const SettingsScreen(), extra: [
      ytDlpStatusProvider.overrideWith((_) async => const YtDlpStatus('2026.08.19')),
      searchCacheCountProvider.overrideWith((_) async => 0),
    ]);
    await s.expectGolden(f);
  },
  'player': (s, t, f) async {
    await t.runAsync(() => s.h.handler.playQueue(s.seed.trackIds, 12));
    await s.show(const NowPlayingScreen());
    await s.expectGolden(f);
  },
  'stats': _stats,
};

void main() {
  if (!Platform.isLinux) return;

  setUpAll(() {
    TolerantComparator.install();
    coverImageStub = (key) => ColoredBox(color: _colourOf(key));
  });
  tearDownAll(() => coverImageStub = null);

  for (final (w, size) in [
    (1000, ShotSize.desktop1000),
    (1440, ShotSize.desktop1440),
    (1920, ShotSize.desktop1920),
  ]) {
    for (final e in _screens.entries) {
      testWidgets('w$w ${e.key}', (tester) => withGoldenShot(tester, size,
          (s) => e.value(s, tester, 'desktop_w${w}_${e.key}.png')));
    }
  }

  for (final k in const ['home', 'library', 'album', 'player', 'search', 'all_tracks']) {
    testWidgets('phone360 $k', (tester) => withGoldenShot(tester, ShotSize.phone,
        (s) => _screens[k]!(s, tester, 'phone360_$k.png')));
  }
}
