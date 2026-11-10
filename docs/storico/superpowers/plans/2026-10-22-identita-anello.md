# Identità «Anello» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Codecore its own look on mobile. The current track sits in an open ring like the logo. Mini-player and tabs share one floating block with a dot marking the active tab. Search opens from the bar. The Home gets shorter, and the player grows out of the block.

**Architecture:** One reusable `RingProgress` (a `CustomPainter` that listens only to position) is used by the mini-player, the full player and the desktop player bar. `bottom_bar.dart` becomes `ShellDock`: one `surface2` block holding `MiniPlayer` and the tabs, or the search field when search is open. The search text, submit and online mode move out of `SearchScreen` into providers in `ui_providers.dart`, so the dock field and the page share them. The Home is rebuilt from data that already exists; there are no new tables.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, drift. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-design.md` (read it first; the HTML mock-up is next to it).

## Global Constraints

- No new packages, fonts or colours. Use only `CcColors` (`bg`, `surface1/2/3`, `accent`, `text`, `textMuted`), `CcDims`, `Motion`/`CcMotion`, `ccDuration`, and `buildTextTheme` (`displaySmall` = Unbounded 30/700).
- Must work with every theme and accent: Notte, OLED, Chiaro, custom themes × 8 accents.
- Animate only opacity, transforms and clips, inside a `RepaintBoundary`. Nothing that animates a size or a layout every frame.
- «Riduci animazioni» (`MediaQuery.disableAnimationsOf`, `ccDuration` → zero):
  - the dot jumps with no arc;
  - search appears without widening;
  - the player opens without growing;
  - the cover does not spin.
- Copy rules:
  - no ALL CAPS labels;
  - no «A · B» strings;
  - no «→» on buttons;
  - headings in normal case («Riprendi», «Aggiunti da poco»).
- New strings go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - French and Portuguese use the typographic apostrophe ’ (`test/l10n/arb_test.dart`).
  - Only one agent at a time may touch the ARB files.
- Accessibility:
  - tabs stay `Semantics(button, selected, label)`;
  - the search field has a label;
  - the ✕ is called «Chiudi la ricerca».
- No heavy work on the UI thread. Totals come from SQL (`memoryTotalsProvider`).
- After every task, both must pass:
  - `flutter analyze` is clean;
  - the touched tests are green.
- The full suite runs only at the end (Task 7) via `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante`.
- Commit with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`.

## Decisions made while planning (the user should check these)

1. **The ring does not speak.**
   - The spec asks the ring to expose «1:12 di 3:20» «come oggi la barra». Today's mini bar is deliberately `ExcludeSemantics`: `test/ui/app_shell_test.dart:205` pins that a value would lead the spoken label.
   - The player's seek `Slider` already speaks the position.
   - So the ring is excluded from semantics everywhere, and no new string is needed for it.
2. **Live radio and remote Jam show the arc full in the accent colour, with the gap kept (it is the logo) and no dot.**
3. **Back and ✕ do different things.**
   - **Back** closes the field but keeps the text and stays on Search; the page keeps its results. Tapping «Cerca» again reopens the field with the text.
   - **✕** clears the text and returns to the previous tab.
   - So the existing «keeps its query across tab switches» test still holds.
4. **Recent searches stay where they are.** They stay in `SearchScreen`'s empty state, which sits right above the dock, and enter with `RiseIn` when the field opens. They are not duplicated inside the dock.
5. **The dock loses the mini-player's cover tint.** `MiniPlayer` loses its own card (tint, radius, margin), and the dock's `surface2` is the only background, as the spec says.
6. **«Riprendi» progress bars.**
   - Session row: brano N of M.
   - Tracks with a saved position: position / duration.
   - Albums and playlists: no bar.
7. **The compact bottom rows reuse `showAll` («Mostra tutti») and open the same page the current shelf opens.** A shelf with no page gets no button.

## Review Focus

1. **Keyboard while search is open on the phone.** The field must sit fully above the keyboard; tabs and mini-player are hidden. Typing in a dialog inside a page must not lift the dock. Test: Task 3, «keyboard lifts only the search field».
2. **Back with search open.**
   - The first Back closes the field and does not leave the app or the tab.
   - With a page pushed in the Search tab, Back still pops that page first.
   - Test: Task 3, «Back closes the field before leaving Search».
3. **Live radio, remote Jam, or no track.** The ring has no dot and no division by a zero duration. With no track the dock holds only the tabs. Tests: Task 1 «unknown duration paints the full arc without dot»; Task 2 «no track: dock holds only the tabs».
4. **Library with no music, or with music but nothing ever played.**
   - No «Riprendi», no fan, no NaN or «0 ore» hero. With 0 tracks the empty state stays.
   - «Casuale su tutto» with podcasts only does nothing harmful.
   - Tests: Task 4, «nothing played: no Riprendi rows» and the existing empty-state test.
5. **Text scale 150 % and the light theme.** The dock grows in height instead of overflowing, and the labels stay visible. `surface2` and `surface3` stay distinct from `bg` on Chiaro. Tests: Task 7 goldens `phone_150_*` and `light_library`.

---

### Task 1: `RingProgress` and the mini-player ring

**Files:**
- Create: `lib/ui/widgets/ring_progress.dart`
- Modify: `lib/ui/widgets/mini_player.dart` (remove `_MiniProgress` at :312 and its `ExcludeSemantics` slot at :253; replace `TrackArt` at :168)
- Test: `test/ui/ring_progress_test.dart`

**Interfaces:**
- Produces:
  - `RingProgress({Key? key, required double size, required Widget child, bool live = false, double stroke = 3})`, a `ConsumerWidget`.
    - `child` is clipped to a circle of diameter `size - 2 * (stroke + 2)` and centred.
    - When not `live`, it watches `positionProvider` and `durationProvider` only inside the `Consumer` that builds the `CustomPaint`.
    - It is wrapped in `RepaintBoundary` and `ExcludeSemantics`.
  - `RingPainter({required double? progress, required Color arc, required Color rest, required double stroke})`, a `CustomPainter`.
    - `progress == null` means a full arc in `arc` with no dot.
    - `shouldRepaint` compares all fields.
  - `double? ringProgress(Duration position, Duration? duration)`, a top-level pure function. It returns `null` when `duration` is null or zero, otherwise `(position / duration).clamp(0, 1)`.

- [ ] **Step 1: Write the failing test** (`test/ui/ring_progress_test.dart`)

```dart
test('progress is clamped and null without a duration', () {
  expect(ringProgress(const Duration(seconds: 30), const Duration(seconds: 60)), 0.5);
  expect(ringProgress(const Duration(seconds: 90), const Duration(seconds: 60)), 1.0);
  expect(ringProgress(Duration.zero, null), isNull);
  expect(ringProgress(const Duration(seconds: 5), Duration.zero), isNull);
});
test('unknown duration paints the full arc without dot', () {
  final p = RingPainter(progress: null, arc: Colors.red, rest: Colors.grey, stroke: 3);
  expect(p.shouldRepaint(RingPainter(progress: 0.2, arc: Colors.red, rest: Colors.grey, stroke: 3)), isTrue);
});
testWidgets('the mini-player shows the ring and no linear bar', (t) async { /* Harness, play Song 1 as in app_shell_test:205 */
  expect(find.descendant(of: find.byType(MiniPlayer), matching: find.byType(RingProgress)), findsOneWidget);
  expect(find.descendant(of: find.byType(MiniPlayer), matching: find.byType(LinearProgressIndicator)), findsNothing);
});
```

- [ ] **Step 2: Run the test and check it fails.** Run `flutter test test/ui/ring_progress_test.dart`. Expected: compile error, because `ring_progress.dart` does not exist yet.
- [ ] **Step 3: Implement the ring.**
  - **Geometry:** the gap is 40° wide and centred at −45° (top right, Flutter angles). The arc runs clockwise from `-pi/4 + gap/2` over `2*pi - gap`.
    - The `rest` colour covers the whole arc.
    - The `arc` colour covers `progress × sweep`.
    - The dot has radius `stroke * 1.1` and sits at the tip, in `arc`.
    - All strokes use `StrokeCap.round`.
  - **Colours:** `arc = cc.accent`, `rest = cc.surface3`.
  - **In `MiniPlayer`:**
    - The cover becomes `RingProgress(size: 48, live: <radio or Jam>, child: TrackArt(track, size: 40, radius: 20, heroTag: kPlayerCoverHero))`.
    - Use the existing radio/Jam checks that hide `_MiniProgress` today.
    - The rounded `radius: 20` also covers the no-cover placeholder.
- [ ] **Step 4: Run the new test plus the existing mini-player tests.** Run `flutter test test/ui/ring_progress_test.dart test/ui/app_shell_test.dart test/ui/radio_player_ui_test.dart`. Expected: PASS. The test at `app_shell_test:205` («no progress value») must still pass.
- [ ] **Step 5: Commit.** `git add lib/ui/widgets/ring_progress.dart lib/ui/widgets/mini_player.dart test/ui/ring_progress_test.dart && git commit -m "feat(anello): anello di avanzamento nel mini-player"`

---

### Task 2: `ShellDock`, one block with the tab dot

**Files:**
- Modify: `lib/ui/shell/bottom_bar.dart` (rewrite; keep `BottomBarItem`)
- Modify: `lib/ui/shell/app_shell.dart:266-285` (the narrow `Scaffold`'s `bottomNavigationBar`)
- Modify: `lib/ui/widgets/mini_player.dart` (drop its own card: background, radius, outer margin)
- Modify: `lib/ui/theme/tokens.dart` (`CcDims.dockRadius = 28`, `CcDims.dockMargin = 10`)
- Modify: `lib/ui/widgets/motion.dart` (`Motion.dot = Duration(milliseconds: 420)`)
- Test: `test/ui/app_shell_test.dart` (the existing finder `_bar` uses `find.byType(BottomBar)`; rename it to `ShellDock`)

**Interfaces:**
- Consumes: `MiniPlayer` from Task 1.
- Produces:
  - `ShellDock({Key? key, required List<BottomBarItem> items, required int selected, required ValueChanged<int> onSelect, bool showPlayer = true})`.
    - It replaces `BottomBar`, whose class name disappears.
    - It is a `Container` with margin `CcDims.dockMargin` (plus bottom `MediaQuery.paddingOf.bottom`), `cc.surface2`, radius `CcDims.dockRadius`, and `clipBehavior: Clip.antiAlias`.
    - Inside is a `Column(mainAxisSize: min)` of `[if (showPlayer && current track != null) MiniPlayer(), tabs row]`.
  - `TabDot`, private to the file, is the accent dot (diameter 6). It sits at the active icon's top right and moves on a `RepaintBoundary`. Over `ccDuration(context, Motion.dot)`, x is lerped and y is lifted by `-sin(pi * t) * 10`.
  - The Scaffold body's background stays `cc.bg`.

- [ ] **Step 1: Write the failing tests** (in `test/ui/app_shell_test.dart`)

```dart
testWidgets('no track: dock holds only the tabs', (t) async {
  _phone(t); final h = await Harness.create(t, tracks: 2); await h.pump(t, const AppShell()); await _settle(t);
  expect(find.byType(ShellDock), findsOneWidget);
  expect(find.byType(MiniPlayer), findsNothing);
  expect(_bar('Home'), findsOneWidget);
  await h.dispose(t);
});
testWidgets('the selected tab is marked by the dot and in semantics', (t) async {
  // after tapping «Libreria»: Semantics(selected: true) on Libreria, the dot's centre is within 16 px of the Libreria icon's top-right corner
});
```

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/ui/app_shell_test.dart`. Expected: FAIL (`ShellDock` is not defined).
- [ ] **Step 3: Implement `ShellDock`.**
  - Labels stay always visible: icon 24, text 11 px w600, as today.
  - The tab row keeps `CcDims.bottomBarHeight` as its *minimum* height. With large text it may grow, but it must not overflow.
  - `app_shell.dart` uses `bottomNavigationBar: ShellDock(...)` in place of the `Column(MiniPlayer, BottomBar)`.
- [ ] **Step 4: Run the shell tests plus the large-text test.** Run `flutter test test/ui/app_shell_test.dart test/ui/large_text_test.dart test/ui/motion_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit.** `git add lib/ui/shell/bottom_bar.dart lib/ui/shell/app_shell.dart lib/ui/widgets/mini_player.dart lib/ui/theme/tokens.dart lib/ui/widgets/motion.dart test/ui/app_shell_test.dart && git commit -m "feat(anello): blocco unico in basso con il pallino della scheda"`

---

### Task 3: Search opens from the bar

**Files:**
- Modify: `lib/providers/ui_providers.dart` (new providers, below)
- Modify: `lib/ui/shell/bottom_bar.dart` (field mode)
- Modify: `lib/ui/shell/app_shell.dart` (`PopScope` at :287, Ctrl+F, tap on «Cerca»)
- Modify: `lib/ui/shell/shell_nav.dart:36` (`showSearch` also opens the field)
- Modify: `lib/ui/screens/search/search_screen.dart`
  - `_controller` at :46 and `_mode` at :49 move to the providers.
  - The `TextField` at :168 is hidden when the width is below `CcDims.wideBreakpoint`.
- Modify: the 6 ARBs (`closeSearch`: it «Chiudi la ricerca», en «Close search», de «Suche schließen», es «Cerrar la búsqueda», fr «Fermer la recherche», pt «Fechar a pesquisa»)
- Test: `test/ui/app_shell_test.dart`, `test/ui/search_screen_test.dart`

**Interfaces:**
- Consumes: `ShellDock` from Task 2.
- Produces (in `ui_providers.dart`):
  - `searchControllerProvider`, a `Provider<TextEditingController>` disposed with `ref.onDispose`.
  - `searchOnlineProvider`, a `NotifierProvider<SearchOnlineNotifier, bool>` with `set(bool)`. It replaces `_Mode`.
  - `searchSubmitProvider`, a `NotifierProvider<SearchSubmitNotifier, int>`. `submit()` increments it; `SearchScreen` does `ref.listen` and calls its `_submit(controller.text)`.
  - `searchBarProvider`, a `NotifierProvider<SearchBarNotifier, bool>` (open or closed).
    - `open()` remembers `navIndexProvider` (when it is not already search), sets the tab to search and sets `true`. The dock requests focus on `searchFocusProvider` after the frame.
    - `close()` sets `false` and keeps the text.
    - `dismiss()` clears the controller, sets `false` and restores the remembered tab.
- **Dock in field mode** (`searchBarProvider == true`, narrow only):
  - It shows only a `TextField` with these properties:
    - `controller`: `searchControllerProvider`;
    - `focusNode`: `searchFocusProvider`;
    - hint: `l.ytHint` when online, else `l.searchHint`;
    - `textInputAction: search`;
    - `onSubmitted`: `searchSubmitProvider.submit()`;
    - a trailing ✕ `IconButton`, tooltip `l.closeSearch`, which calls `dismiss()`.
  - No tabs and no mini-player; the dot is hidden.
  - The switch is a cross-fade + horizontal `scaleX` from the «Cerca» tab's position over `ccDuration(context, const Duration(milliseconds: 450))`.
  - The block is padded by `MediaQuery.viewInsetsOf(context).bottom` only in field mode.
- **Recent searches:** in `SearchScreen._EmptyQuery`, the recent searches enter with `RiseIn` (decision 4).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('tapping Cerca turns the bar into a focused field', (t) async {
  _phone(t); /* pump AppShell */ await t.tap(_bar('Cerca')); await _settle(t);
  expect(find.descendant(of: find.byType(ShellDock), matching: find.byType(TextField)), findsOneWidget);
  expect(_bar('Home'), findsNothing);
  expect(container.read(searchFocusProvider).hasFocus, isTrue);
});
testWidgets('✕ clears the field and returns to the previous tab', (t) async {
  // from Libreria: tap Cerca, enterText 'Song', tap tooltip 'Chiudi la ricerca'
  expect(container.read(navIndexProvider), NavTab.library.index);
  expect(container.read(searchControllerProvider).text, isEmpty);
});
testWidgets('Back closes the field before leaving Search', (t) async {
  // open, type 'Song 2', simulate system back (tester.binding.handlePopRoute())
  expect(container.read(searchBarProvider), isFalse);
  expect(container.read(navIndexProvider), NavTab.search.index);
  expect(find.text('Song 2'), findsWidgets); // results still shown
});
testWidgets('keyboard lifts only the search field', (t) async {
  // open field, then t.view.viewInsets = FakeViewPadding(bottom: 300): field's bottom <= 800 - 300; MiniPlayer and tab labels absent
});
testWidgets('submit in the dock field runs the page search', (t) async {
  // online mode on, enterText + testTextInput.receiveAction(TextInputAction.search): the online search request is made once (reuse search_screen_test's fake)
});
```

- **Update `phone: the Search tab keeps its query across tab switches` (`app_shell_test:343`) to the new flow:**
  1. Open the field.
  2. Type.
  3. Press Back.
  4. Tap Home.
  5. Tap Cerca.
  6. Expect the field text to be `'Song 2'`.
- Keep the desktop `Ctrl+F` test as it is. Add one assertion: `searchFocusProvider` has focus.

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/ui/app_shell_test.dart test/ui/search_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the providers, field mode, `PopScope` and `ShellNav.showSearch`.**
  - **`PopScope` order:**
    1. The search field is open → `close()`.
    2. The nested navigator can pop → pop.
    3. Otherwise → go Home, then exit.
  - **Tapping «Cerca» or calling `ShellNav.showSearch`:** calls `searchBarProvider.notifier.open()` on every width. Desktop ignores the flag, because the dock is not shown there.
  - **ARB:** add `closeSearch` to all 6 files, then run `flutter gen-l10n`.
- [ ] **Step 4: Run the tests and check they pass.** Run `flutter test test/ui/app_shell_test.dart test/ui/search_screen_test.dart test/ui/search_operators_test.dart test/ui/shell_keys_test.dart test/l10n/arb_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit.** `git add lib/providers/ui_providers.dart lib/ui/shell/ lib/ui/screens/search/search_screen.dart lib/l10n/ test/ui/app_shell_test.dart test/ui/search_screen_test.dart && git commit -m "feat(anello): la ricerca nasce dalla barra"`

---

### Task 4: The new Home

**Files:**
- Create: `lib/ui/screens/home/resume_rows.dart` (pure logic + `ResumeList` widget)
- Create: `lib/ui/screens/home/cover_fan.dart` (`CoverFan` widget)
- Modify: `lib/ui/screens/home/home_screen.dart`
  - Rebuild the body under the existing header and empty state.
  - Remove the «Riprendi» `Wrap`, the shelves and the ' · ' join of «Il tuo mese».
- Modify: `lib/data/repositories/track_repository.dart` (`watchResumable`)
- Modify: the 6 ARBs (keys below)
- Test: `test/ui/home_screen_test.dart`, `test/data/resume_rows_test.dart`

**Interfaces:**
- Consumes:
  - providers: `memoryTotalsProvider` (`SizeTotals.trackCount`, `durationMs`; music only), `tracksProvider(false)`, `playlistsProvider`, `savedRadiosProvider`, `albumsProvider`, `currentTrackProvider`, `queueProvider`, `playContextProvider`, `positionProvider`, `durationProvider`;
  - functions: `playContextName`, `recentlyPlayedAlbums`, `recentlyAddedAlbums`, `buildLibraryEntries`;
  - `PlayerController.setShuffle(true)` and then `playAll(tracks, context: PlayContext(PlayContextKind.library))`.
- Produces:
  - `Stream<List<Track>> TrackRepository.watchResumable({int limit = 3})`: rows with `resumePositionMs IS NOT NULL`, newest `lastPlayedAt` first.
  - `sealed class ResumeRow` with subclasses:
    - `QueueResume(Track track, int index, int length, PlayContext? source)`;
    - `TrackResume(Track track)`;
    - `EntryResume(LibraryEntry entry)`;
    - `ReleasesResume()`.
  - `List<ResumeRow> buildResumeRows({Track? current, List<Track> queue, PlayContext? source, List<Track> resumable, List<LibraryEntry> entries, bool hasNewReleases})`.
    - Order: releases, queue, resumable, then entries with `lastPlayedAt` (newest first).
    - The current track never appears twice.
    - At most 4 rows.
  - `CoverFan({required List<AlbumSummary> albums})` shows up to 5 albums.
    - Closed: overlapping covers, rotated −8°…+8°, scaled to fit the width.
    - The first tap (or hover on desktop) opens it into a row.
    - A tap on an open cover opens that album with `ShellNav.open`.
    - Animation: transforms only, `ccDuration(context, Motion.pulse)`.
- **New ARB keys (all 6 languages):**

  | Key | Italian text |
  |---|---|
  | `homeShuffleAll` | «Casuale su tutto» |
  | `homeShuffleAllSub` | «{tracks}, {hours}» (two `String` placeholders: `tracksCount(n)` and `hoursCount(h)`) |
  | `hoursCount` | «{count, plural, =0{meno di un'ora} one{1 ora} other{{count} ore}}» |
  | `homeAddedLately` | «Aggiunti da poco» |
  | `homeResumeQueue` | «Brano {n} di {m}» |
  | `homeResumeQueueFrom` | «{source}: brano {n} di {m}» |
  | `homeMinutesLeft` | «{count, plural, one{Manca 1 minuto} other{Mancano {count} minuti}}» |
  | `homeFanOpen` | «Mostra le copertine» |

- **Home order, top to bottom:**
  1. Header (unchanged).
  2. Hero: `homeShuffleAll` in `displaySmall` with `homeShuffleAllSub` under it, and a 56 px `cc.accent` disc with `Icons.shuffle`. It is one `InkWell` / `Semantics(button)`.
  3. Shortcuts row: `navFavorites`, `navPlaylists` and `radioTitle`, each with its count.
  4. «Riprendi» (`homeResume`): `ResumeList`, rows with a 2 px bar (decision 6).
  5. «Aggiunti da poco»: `CoverFan`, hidden when there are 0 albums. Its heading has `showAll`, which opens the page today's «Aggiunti di recente» shelf opens (the spec's «porta all'elenco completo»).
  6. At the bottom, compact 3-item rows with the same visibility conditions as today:
     - «Il tuo mese» (`monthPlaysProvider` ≥ 10);
     - top artists (`kEnableYoutube`);
     - top tracks;
     - rediscover.
     Each has `showAll` when today's shelf had a target page (decision 7).
  - Content width: `ConstrainedBox(maxWidth: 720)`, centred.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/resume_rows_test.dart
test('order is releases, queue, resumable, recent entries; max 4', () { /* 1 release + queue + 2 resumable + 3 entries → [Releases, Queue, Track, Track] */ });
test('the current track is not repeated as a resumable row', () {});
test('nothing played: no rows', () { expect(buildResumeRows(queue: const [], resumable: const [], entries: const [], hasNewReleases: false), isEmpty); });
```

```dart
// test/ui/home_screen_test.dart — replace the second test
testWidgets('home with music: shuffle hero, shortcuts, fan, no Riprendi', (t) async {
  // Harness tracks: 4 (never played)
  expect(find.text('Casuale su tutto'), findsOneWidget);
  expect(find.textContaining('4 brani'), findsOneWidget);
  expect(find.text('Preferiti'), findsOneWidget);
  expect(find.text('Aggiunti da poco'), findsOneWidget);
  expect(find.text('Riprendi'), findsNothing);
  expect(find.textContaining(' · '), findsNothing);
});
testWidgets('Casuale su tutto turns shuffle on and starts playing', (t) async {
  // tap hero: container.read(shuffleProvider).value is true (StreamProvider<bool>, player_providers.dart:214); backend received a queue of 4 ids
});
testWidgets('the fan opens on the first tap and opens the album on the second', (t) async {});
```

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/data/resume_rows_test.dart test/ui/home_screen_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the Home.**
  - **`watchResumable`:** a drift query in `TrackRepository`.
  - **`buildResumeRows`, pure:**
    - Queue `index` = `queue.indexWhere((t) => t.id == current.id)`.
    - Queue row tap: `togglePlayPause()` when paused.
    - Track row tap: `playFromList([track], 0)`.
    - Entry row tap: opens the album or playlist page that `library_entries` already opens.
    - Releases row tap: opens `NewReleasesScreen`.
  - **ARB:** add the keys above to the 6 files, then run `flutter gen-l10n`.
- [ ] **Step 4: Run the tests and check they pass.** Run `flutter test test/data/resume_rows_test.dart test/ui/home_screen_test.dart test/ui/new_releases_shelf_test.dart test/ui/radio_home_library_test.dart test/l10n/arb_test.dart`. Expected: PASS. Delete or adapt tests of shelves that no longer exist; do not keep dead widgets for them.
- [ ] **Step 5: Commit.** `git add lib/ui/screens/home/ lib/data/repositories/track_repository.dart lib/l10n/ test/data/resume_rows_test.dart test/ui/home_screen_test.dart && git commit -m "feat(anello): nuova Home con Casuale su tutto, Riprendi e ventaglio"`

---

### Task 5: The player grows out of the dock

**Files:**
- Create: `lib/ui/widgets/grow_route.dart`
- Modify: `lib/ui/widgets/mini_player.dart` (the `PageRouteBuilder` + `SlideTransition` push uses `growRoute`)
- Modify: `lib/ui/screens/now_playing/now_playing_screen.dart:~304` (cover in a big ring, round, spinning)
- Modify: `lib/ui/widgets/motion.dart` (`SpinWhilePlaying`)
- Test: `test/ui/now_playing_test.dart`, `test/ui/motion_test.dart`

**Interfaces:**
- Consumes: `RingProgress` from Task 1.
- Produces:
  - `Route<T> growRoute<T>({required Rect from, required WidgetBuilder builder})`, a `PageRouteBuilder`.
    - `transitionDuration` is 550 ms; the transition builder uses `ccDuration` (zero → instant).
    - The page is clipped by a `ClipRRect`-equivalent `CustomClipper<RRect>`. The clip lerps from `from` (the dock's global rect, taken from `MiniPlayer`'s ancestor `ShellDock` render box) with radius `CcDims.dockRadius` to the full screen with radius 0, over `Motion.curve`.
    - The page fades from 0 to 1 over the first 40 %.
  - `SpinWhilePlaying({required Object trackKey, required Widget child})`, in `motion.dart`.
    - One turn takes 30 s and runs only while `isPlayingProvider` is true.
    - It pauses at its current angle and resets to 0 when `trackKey` changes.
    - It returns `child` untouched when `MediaQuery.disableAnimationsOf`.
- **Now Playing cover:**
  - `RingProgress(size: s, stroke: 4, live: <radio/Jam>, child: SpinWhilePlaying(trackKey: track.id, child: TrackArt(..., radius: s/2, heroTag: kPlayerCoverHero)))`;
  - `s` = today's `shortestSide.clamp(80, 460)`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('reduce motion: the player opens without growing and the cover does not spin', (t) async {
  // MediaQuery(disableAnimations: true): tap mini-player, one pump(Duration.zero) → NowPlayingScreen fully visible; no AnimatedBuilder rotation inside SpinWhilePlaying
});
testWidgets('the cover spin restarts at 0 on a new track', (t) async {
  // playing, pump 5 s → angle > 0; change trackKey → angle == 0
});
testWidgets('the now playing cover sits in a ring', (t) async {
  expect(find.descendant(of: find.byType(NowPlayingScreen), matching: find.byType(RingProgress)), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests and check they fail.** Run `flutter test test/ui/now_playing_test.dart test/ui/motion_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `growRoute`, `SpinWhilePlaying` and the Now Playing cover.** The Jam route keeps its existing push; only `NowPlayingScreen` uses `growRoute`. Keep the `Hero`; Task 7 decides whether it stays.
- [ ] **Step 4: Run the tests and check they pass.** Run `flutter test test/ui/now_playing_test.dart test/ui/motion_test.dart test/ui/app_shell_test.dart test/ui/jam_screen_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit.** `git add lib/ui/widgets/grow_route.dart lib/ui/widgets/mini_player.dart lib/ui/widgets/motion.dart lib/ui/screens/now_playing/now_playing_screen.dart test/ui/now_playing_test.dart test/ui/motion_test.dart && git commit -m "feat(anello): il lettore cresce dal blocco, copertina nell'anello"`

---

### Task 6: Desktop touches

**Files:**
- Modify: `lib/ui/shell/desktop_sidebar.dart` (accent dot on the selected item)
- Modify: `lib/ui/shell/desktop_player_bar.dart:~114` (`_TrackInfo`: ring in place of the square `TrackArt`)
- Test: `test/ui/app_shell_test.dart`

**Interfaces:**
- Consumes: `RingProgress` from Task 1.
- The sidebar dot is a 6 px `cc.accent` circle at the top right of the selected item's icon. It is static: no jump between items, because a sidebar is a list, not a row of four.
- The player bar uses `RingProgress(size: 56, live: <radio/Jam>, child: TrackArt(..., size: 48, radius: 24))`.

- [ ] **Step 1: Write the failing test.** In `wide: sidebar and player bar, no rail, no mini-player`, add: `expect(find.descendant(of: find.byType(DesktopPlayerBar), matching: find.byType(RingProgress)), findsOneWidget);` plus a check that exactly one sidebar dot is present (find it by `Key('sidebar-dot')`).
- [ ] **Step 2: Run the test and check it fails.** Run `flutter test test/ui/app_shell_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement the sidebar dot and the player-bar ring.**
- [ ] **Step 4: Run the tests and check they pass.** Run `flutter test test/ui/app_shell_test.dart test/ui/xl_layout_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit.** `git add lib/ui/shell/desktop_sidebar.dart lib/ui/shell/desktop_player_bar.dart test/ui/app_shell_test.dart && git commit -m "feat(anello): pallino nella barra laterale e anello nella barra del lettore"`

---

### Task 7: Goldens, full suite, Mi A3

**Files:**
- Modify: `test/goldens/screens_golden_test.dart` (new `home` test that runs only for `ShotSize.phone` at scale 1.0, tag `phone_100`)
- Regenerate: `test/goldens/*.png`

- [ ] **Step 1: Add the Home golden.** It shows `AppShell` on Home with 6 tracks, 2 played (so «Riprendi» and the fan are visible) and a current track. It is saved as `phone_100_home.png`.
- [ ] **Step 2: Regenerate the goldens.** Run `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart`.
  - Then open each changed `phone_*` / `desktop_*` PNG and check four things:
    - the dock is visible;
    - at 150 % nothing overflows;
    - `light_library` has a dock distinct from the background;
    - the ring sits around the cover.
  - Show the user `phone_100_home.png` and `phone_100_library.png` locally with `xdg-open`, not as an artifact.
- [ ] **Step 3: Run the full suite.** Run `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 40 build/full_anello.log -- flutter test`. Expected: all green, same skipped count as before (40).
- [ ] **Step 4: Check on the Mi A3.**
  - Build `flutter build apk --debug` with `JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14`, then `adb -s 0d7ae9df206e install -r`.
  - Check, while music plays:
    - the dot jump;
    - opening and closing search;
    - Back with the field open;
    - the keyboard with the field;
    - the player growing (watch `adb shell dumpsys gfxinfo com.codecore.player`: janky frames under 10 % during the opening);
    - the cover spin;
    - «Riduci animazioni» from the app settings.
  - If the `Hero` or the spin stutters, remove it (spec decisions 8–9) and commit that separately.
  - Never turn the screen off, never uninstall, never clear data.
- [ ] **Step 5: Commit and update the docs.**
  - Mark the Anello block in `docs/PROGRESS.md` as done.
  - `git add test/goldens/ docs/PROGRESS.md && git commit -m "test(anello): golden rigenerati e Home"`
  - Push only after the suite is green, as a separate command: `git push -q origin master`.

## Parallelism

- Task 1 and Task 4 touch disjoint files (only Task 4 touches the ARBs), so they can run together.
- Tasks 2 → 3 → 5 are in sequence: they share `mini_player.dart` and `bottom_bar.dart`. Task 3 also needs the ARBs, so it starts only after Task 4 has committed.
- Task 6 may run alongside Task 5.
- Task 7 comes last.
