# Anello fase 2.4, Cerca e artista online: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cerca loses its tiles and shelves: recent searches and genres as wrapping pills with an empty field, sections in a column with «Tutti» once there are results. The online artist page gets the collection header with a round photo, and its sections become rows.

**Architecture:**
- `search_screen.dart` changes in place.
  - The library/online switch becomes `SegmentedBlocks` (2.2).
  - The results drop the main card and the horizontal lists.
  - A new `SearchSectionScreen` shows the whole list of one kind.
- `searchLibrary` returns totals per kind and loses `main`.
- The header layout of `CollectionScaffold` (2.1) is pulled out as a public `CollectionHeader`, so `OnlinePageFrame` pages can use it without the scaffold.
- `ReleaseCarousel` and `ArtistCarousel` are replaced by row lists in `artist_page_sections.dart`.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read Obiettivo 5, 6 and 10, «Cerca (corpo della pagina)», «Artista (locale e online)», Anti‑obiettivi (no carousels in another form). The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.** Only `CcColors` via `context.cc`, `CcDims`, `Motion`/`CcMotion` and `ccDuration`.
- **ARB edits.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’.
  - Only one agent at a time touches the ARBs.
  - Every key this plan cleans of «·» leaves `_separatorPending` in `test/l10n/arb_test.dart` (2.3).
- **Copy:** no «A · B», no «•», no «→», no ALL CAPS. Separators become `, `.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** no heavy work on it. `searchLibrary` keeps running where it runs today; `SearchSectionScreen` calls it the same way.
- **Motion:** only opacity and transform. `AnimatedSize` in `AboutSection` goes. Rows enter with `EnterOnce` as today; the blocks slide as in 2.2.
- **No new functions, none removed** (Non obiettivi). The online artist has no «Riproduci»/«Casuale» today, so it gets none.
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files.
  - `flutter analyze` must be clean.
- **Goldens:** Cerca and the artist page are not in `test/goldens/screens_golden_test.dart`. Only the ones that show `l.showAll` change (Task 4).
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/` (Home picks up the new `showAll` value without edits).
- **Last task:** device check plus the tick in `docs/PROGRESS.md`. The controller runs the devices.

## Decisions made while planning

1. **Mode switch:** `SegmentedBlocks<bool>` with `false` → `Icons.library_music_rounded` «In libreria», `true` → `Icons.public_rounded` «Online», writing `searchOnlineProvider.notifier.set`. The Preferiti/Recenti `FilterChip`s stay chips (toggles, not segments), in a `Wrap` instead of a horizontal `ListView`. `SourceFilterChips` of the online results stay chips: they are more than 4.
2. **Genres:** a `Wrap` of `surface1` pills (`ActionChip`-like, radius `CcDims.rCard`), text only. `_GenreTile` and its `artistHue` colour go.
3. **Results:** `trackLimit: 5`, `sectionLimit: 3`. `LibrarySearchResults` gains `artistTotal`, `albumTotal`, `playlistTotal`, and loses `main`. «Tutti» shows only when the total is above what is shown.
   - Brani «Tutti» keeps opening `SearchTracksScreen`.
   - Artisti/Album/Playlist «Tutti» open `SearchSectionScreen(query, kind)`.
4. **Artist and album results become rows** with a 40 leading (`ArtistAvatar` round, `CoverImage` `rList`), the same `row()` helper the playlists already use.
5. **`l.searchMainResult` is deleted** from the 6 ARBs. `kindArtist`/`kindAlbum` stay: the library uses them.
6. **`GenreScreen`** becomes `CollectionScaffold(cover: null, …)` with `collectionMeta` and the pills; empty is `EmptyState`.
7. **`CollectionHeader`** is the 2.1 header layout as a public widget. `CollectionScaffold` builds it; nothing about its look changes.
8. **Online header:** `CollectionHeader(cover: (s) => NetThumbnail(circle: true, …), name, meta: audience, actions: [FollowButton])`. The audience is the string YouTube Music returns, as today (gap: it is not localized by the app).
9. **`FollowButton`** is always an `OutlinedButton.icon`. Following: icon and label in `cc.accent` («stato acceso» in accento, Decision 9 of the spec).
10. **Section lists, online:**
    - song shelves: as today (`OnlineSongTile`), the shelf title comes from YouTube Music;
    - release shelves: `ReleaseList`, up to 5 rows with a 56 cover, title, and the year/kind line; «Tutti» opens `DiscographyScreen` as `onMore` does today. The track count is not in `YtmRelease` (gap: reading it would mean a request per release, so the row shows year and kind only);
    - artist shelves: `ArtistList`, 3 rows with a 56 round avatar, no «Tutti» (there is no screen for it);
    - «Nella tua libreria» stays (no function removed), action «Tutti».
11. **`AboutSection`:** `maxLines: 4`, «Altro»/«Meno» toggles it; the height jumps (no `AnimatedSize`).
12. **«Tutti» everywhere (Obiettivo 10):** `showAll` becomes «Tutti» (en «All», de «Alle», es «Todos», fr «Tout», pt «Todos»). `ytmSeeAll` and `ytmShowAll` go; their uses switch to `showAll`.

## Review Focus

1. **A query with many matches of one kind and none of the others.** Only that section shows, with «Tutti»; empty sections do not leave a header. Test: Task 2, «empty sections vanish, Tutti only above the limit».
2. **«Tutti» on artists or albums with search operators** (`artist:…`, quick filter Preferiti on). The full list keeps the same filter as the preview. Test: Task 2, «SearchSectionScreen keeps operators and quick filter».
3. **An online artist with a very long name, no photo and no audience, at 150 % on 360 dp.** The header stacks, the placeholder is round, no empty meta line. Test: Task 3, «online header: no photo, no audience, long name».
4. **An artist page served from the offline copy, or that fails.** `OfflineNotice` and `CatalogErrorView` still show under the header. Test: Task 3, «stale page keeps the offline notice».
5. **Releases with an empty subtitle or one with «•».** The row shows no stray separator and no empty line. Test: Task 4, «release row line without bullets».

---

### Task 1: Cerca with an empty field, and the mode blocks

**Files:**
- Modify: `lib/ui/screens/search/search_screen.dart`
  - the `FilterChip` list :193-221 (horizontal `ListView` becomes `Wrap(spacing: 8, runSpacing: 8)`);
  - the library/online `ChoiceChip`s :222-250;
  - `_EmptyQuery` :258-326 and `_GenreTile` :328-360.
- Test: `test/ui/search_screen_test.dart`

**Interfaces:**
- Consumes: `SegmentedBlocks<T>`, `BlockItem<T>` from `lib/ui/widgets/segmented_blocks.dart` (2.2).
- Recents: one `ListTile` per search with `Icons.search_rounded` leading (today `history`) and the ✕ trailing, as today. Section title stays the existing recents key.
- Genres: a `SectionHeader` and a `Wrap` of pills. Each pill: `Material(color: cc.surface1, borderRadius: rCard)` + `InkWell` + `Text(genre, style: labelLarge)`, padding 16×10, inside `PressScale`. Tap opens `GenreScreen` as today.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('mode is a two-block selector', (t) async {
  expect(find.byType(SegmentedBlocks<bool>), findsOneWidget);
  await t.tap(find.text('Online')); await t.pump();
  // searchOnlineProvider is true
});
testWidgets('genres are wrapping text pills without hue', (t) async {
  // library with tracks in 'Rock', 'Jazz'
  expect(find.byType(GridView), findsNothing);
  final a = t.getRect(find.text('Rock')); final b = t.getRect(find.text('Jazz'));
  expect(a.height, lessThan(56)); // a pill, not a tile
});
```

- [ ] **Step 2: Run `flutter test test/ui/search_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Delete `_GenreTile`; drop the `artistHue` import if unused.
- [ ] **Step 4: Run `flutter test test/ui/search_screen_test.dart test/ui/search_sources_test.dart test/ui/no_stray_colors_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): Cerca a campo vuoto con pillole e blocchi`.

---

### Task 2: Results without shelves, `SearchSectionScreen`, `GenreScreen`

**Files:**
- Modify: `lib/data/repositories/library_search.dart` (totals; remove `main` :15, :26, :87, :118-131)
- Modify: `lib/ui/screens/search/search_screen.dart` `_LibraryResults` :362-~700 (main card :398-470, horizontal artists :553, albums :611)
- Create: `lib/ui/screens/search/search_section_screen.dart`
- Modify: `lib/ui/screens/search/genre_screen.dart`
- Modify: the 6 ARBs (delete `searchMainResult`)
- Test: `test/data/library_search_test.dart` (:54-55 assert `main`: replace), `test/ui/search_screen_test.dart`

**Interfaces:**
- `LibrarySearchResults` gains `final int artistTotal, albumTotal, playlistTotal;` (count before `sectionLimit`).
- `searchLibrary(...)` keeps its parameters; the screen passes `trackLimit: 5, sectionLimit: 3`.
- Produces:
  ```dart
  enum SearchSectionKind { artists, albums, playlists }
  class SearchSectionScreen extends ConsumerWidget {
    const SearchSectionScreen({super.key, required this.query, required this.kind, this.quickFilter = false});
  }
  ```
  It reads the same providers as `_LibraryResults`, calls `searchLibrary(..., sectionLimit: 1 << 30)`, and shows the rows of one kind under an `AppBar` titled `l.artists` / `l.albums` / `l.navPlaylists`.
- Section rows: one private `_ResultRow({leading, title, subtitle, onTap})` used by artists (subtitle `collectionMeta(l, albums:, tracks:, durationMs:)` or the existing count), albums (subtitle the artist) and playlists (`l.playlistCountLabel`).
- `GenreScreen`: `CollectionScaffold(cover: null, name: genre, meta: collectionMeta(l, tracks:, durationMs:), onPlay, onShuffle, …)`; empty: `EmptyState(icon: Icons.music_note_rounded, message: l.noResults)`. `ShuffleButton`/`PlayCircleButton` go from its `AppBar` (2.1 removed `ShuffleButton`; check nothing still imports it).

- [ ] **Step 1: Write the failing tests.**

```dart
test('totals count past the section limit', () {
  final r = searchLibrary(text: 'a', ..., sectionLimit: 3);
  expect(r.artists.length, 3); expect(r.artistTotal, greaterThan(3));
});
testWidgets('results are rows in a column, no main result', (t) async {
  expect(find.text('Risultato principale'), findsNothing);
  expect(find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal), findsNothing);
});
testWidgets('empty sections vanish, Tutti only above the limit', ...) // 1 artist, 0 albums: header «Artisti» with no «Tutti», no «Album» header
testWidgets('SearchSectionScreen keeps operators and quick filter', ...) // query 'artist:daft', Preferiti on: same first rows as the preview
testWidgets('genre page has the collection header without cover', ...) // no ValueKey('collection-cover'); «Riproduci» present
```

- [ ] **Step 2: Run `flutter test test/data/library_search_test.dart test/ui/search_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement** the totals, the rows, the new screen and the genre page; delete the ARB key and run `flutter gen-l10n`.
- [ ] **Step 4: Run `flutter test test/data/library_search_test.dart test/ui/search_screen_test.dart test/ui/search_operators_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): risultati di Cerca in colonna con «Tutti»`.

---

### Task 3: `CollectionHeader` and the online artist header

**Files:**
- Modify: `lib/ui/widgets/collection_header.dart` (extract the header built in 2.1 Task 2)
- Modify: `lib/ui/screens/online/artist_page_sections.dart` `ArtistHeader` :20-63
- Modify: `lib/ui/screens/releases/follow_button.dart:38-70`
- Test: `test/ui/collection_pages_test.dart`, `test/ui/artist_page_test.dart`, `test/ui/follow_button_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class CollectionHeader extends StatelessWidget {
    const CollectionHeader({super.key, this.cover, required this.name, this.subtitle, this.meta, this.actions = const []});
    final Widget Function(double size)? cover; final String name; final String? subtitle, meta; final List<Widget> actions;
  }
  ```
  Same layout rules as 2.1 (128/200, stacked when `width / textScale < 300 || width < 360`, max width 960, keys `collection-cover` and `collection-name`). `actions` go in the same `Wrap(spacing: 8, runSpacing: 8)`. `CollectionScaffold` uses it.
- `ArtistHeader({artist, audience, action})` keeps its signature and returns `CollectionHeader(cover: (s) => NetThumbnail(url: thumbAt(context, artist.thumbnailUrl, s.round()), width: s, height: s, icon: Icons.person_rounded, circle: true), name: artist.name, meta: audience ?? artist.audience, actions: [?action])`. No ring, no gap on the circle.
- `FollowButton`: both states `OutlinedButton.icon`; following sets `foregroundColor: cc.accent`. Labels and the stop-following dialog stay.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('online header: photo left, follow outlined', (t) async {
  final cover = t.getRect(find.byKey(const ValueKey('collection-cover')));
  expect(cover.left, CcDims.margin);
  expect(find.widgetWithText(OutlinedButton, 'Segui'), findsOneWidget);
});
testWidgets('online header: no photo, no audience, long name', ...) // 360x780, textScaler 1.5, name 80 chars, audience null: stacked, no exception, only the name Text in the header
testWidgets('stale page keeps the offline notice', ...) // stale cached page: OfflineNotice below the header
// follow_button_test: following state is OutlinedButton with accent foreground
```

- [ ] **Step 2: Run `flutter test test/ui/artist_page_test.dart test/ui/follow_button_test.dart test/ui/collection_pages_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the same tests plus `test/ui/online_pages_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): artista online con l'intestazione delle raccolte`.

---

### Task 4: Online sections in rows, and «Tutti»

**Files:**
- Modify: `lib/ui/screens/online/artist_page_sections.dart`
  - `OfflineNotice` :66 (text only, via the new `ytmOffline`);
  - `ReleaseCarousel` :142 and `ReleaseTile` :177 become `ReleaseList` and `ReleaseRow`;
  - `ArtistCarousel` :219 becomes `ArtistList`;
  - `AboutSection` :278.
- Modify: `lib/ui/screens/online/artist_page_screen.dart` (:143, :168 labels; the shelf switch uses the new lists)
- Modify: `lib/ui/screens/releases/release_labels.dart:18` (if it joins with «•» or «·»)
- Modify: the 6 ARBs: `showAll`, delete `ytmSeeAll`/`ytmShowAll`; rewrite `ytmArtistWithAudience` «Artista, {audience}», `ytmOffline` «Non in linea, dati del {date}», `releaseAlbumYear` «Album, {year}», `releaseSingleYear` «Singolo, {year}»
- Modify: `test/l10n/arb_test.dart` (remove those 4 keys from `_separatorPending`)
- Test: `test/ui/artist_page_test.dart`, `test/l10n/arb_test.dart`, `test/goldens/screens_golden_test.dart` (only if a golden shows «Mostra tutti»)

**Interfaces:**
- Produces:
  ```dart
  class ReleaseList extends StatelessWidget { const ReleaseList({super.key, required this.shelf, required this.onOpen, this.onMore}); } // ≤5 rows, SectionHeader(shelf.title, actionLabel: onMore == null ? null : l.showAll)
  class ArtistList extends StatelessWidget { const ArtistList({super.key, required this.shelf, required this.onOpen}); } // ≤3 rows
  ```
  - `ReleaseRow`: `NetThumbnail` 56 radius `CcDims.rGrid`, title `titleSmall` 1 line, second line `bodySmall` `textMuted` = `YtmRelease.subtitle` with `' • '` and `' · '` replaced by `', '`; no second line when empty. `PressScale` + `InkWell`.
  - Artist rows: `NetThumbnail` 56 `circle: true`, name, and `ytmArtistWithAudience` when there is an audience.
- They are `SliverToBoxAdapter` children of a `Column` (≤5 rows, no builder needed).
- `AboutSection`: `Text(maxLines: _open ? null : 4, overflow: ellipsis)` and a `TextButton(l.ytmMore / l.ytmLess)`; no `AnimatedSize`.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('no horizontal shelves on the artist page', (t) async {
  expect(find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal), findsNothing);
  expect(find.text('Tutti'), findsWidgets);
  expect(find.text('Mostra tutto'), findsNothing);
});
testWidgets('similar artists: three rows', ...) // shelf of 6 artists: 3 ArtistList rows
testWidgets('release row line without bullets', ...) // subtitle 'EP • 2025' shows 'EP, 2025'; subtitle '' shows only the title
testWidgets('about clamps to four lines', ...) // long text: Text.maxLines == 4, tap «Altro»: null
```

- [ ] **Step 2: Run `flutter test test/ui/artist_page_test.dart test/l10n/arb_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement**, edit the 6 ARBs, run `flutter gen-l10n`.
- [ ] **Step 4: Run `flutter test test/ui/artist_page_test.dart test/ui/online_pages_test.dart test/ui/youtube_results_artist_test.dart test/ui/online_results_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS. Then run `flutter test test/goldens/screens_golden_test.dart`: if only the «Tutti» label differs, regenerate with `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart` and look at the changed images.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): sezioni dell'artista online in righe, azione «Tutti»`.

---

### Task 5: Device check

**Files:**
- Modify: `docs/PROGRESS.md` (the «Anello fase 2.4» tick)

- [ ] **Step 1: Device check (controller).**
  - **Mi A3** (debug APK; never turn the screen off). Check:
    - Cerca empty: recents, genres wrap, blocks slide; «Riduci animazioni» on: they jump;
    - a query: Brani 5, Artisti/Album/Playlist 3, «Tutti» opens the full list; Preferiti on;
    - a genre page;
    - an online artist (with network): header, «Segui» both states, releases in rows, «Tutti» to the discography, similar artists, «Altro»;
    - airplane mode on a cached artist: the offline notice;
    - 150 % text; Notte, OLED and Chiaro with viola, ambra and rosa.
  - **Linux (Xephyr):** the same at 960 max width, keyboard focus on blocks and pills.
- [ ] **Step 2: Tick 2.4 in `docs/PROGRESS.md` and commit** (controller). Message: `docs(anello): fase 2.4 provata`.
