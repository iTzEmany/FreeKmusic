# Anello fase 2.1, Raccolte e righe: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Album, playlist, Preferiti, playlist intelligenti e artista locale get one left-aligned header with word buttons. Track rows lose «·» and the animated bars, and the playing track gets the still accent dot. Empty and error states become quiet.

**Architecture:**
- `CollectionScaffold` (`lib/ui/widgets/collection_header.dart`) is rewritten in place: no `CoverBackdrop`, cover on the left, and a column layout when the text is large.
- Two pills, `PlayPill` and `ShufflePill`, replace `PlayCircleButton` and `ShuffleButton` in the header.
- `collectionMeta` replaces `tracksAndMinutes` and writes the meta line in words.
- `NowPlayingDot` (in `ring_progress.dart`) replaces `NowPlayingBars` everywhere, and that file is deleted.
- `EmptyState` and `ErrorState` keep their constructors but change their layout.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, drift, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read Obiettivi 1, 2, 3, 6, 9 and «Decisioni per schermata» (Intestazione, Righe, Stati vuoti). The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.**
  - Only `CcColors` via `context.cc`: `bg`, `surface1/2/3`, `accent`, `accentSoft`, `text`, `textMuted`, `textFaint`, `error`.
  - Only `CcDims` (`rList 4`, `rGrid 8`, `rCard 12`, `rSheet 16`, `margin 16`, `wideBreakpoint 840`), `Motion`/`CcMotion` and `ccDuration`.
  - Only the text theme in `lib/ui/theme/tokens.dart:159`.
- **New strings.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’ (`test/l10n/arb_test.dart`).
  - Only one agent at a time touches the ARBs.
- **Copy:** no «A · B», no «→», no ALL CAPS.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** no I/O, long DB work or network on it. Sums come from data that is already loaded or from SQL.
- **Motion.**
  - Animate only opacity and transform.
  - «Riduci animazioni» goes through `ccDuration`: with it on, nothing moves.
  - Nothing moves on its own. The dot is still.
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files: `flutter test <files>`.
  - `flutter analyze` must be clean after each task.
- **Goldens:** regenerate only the ones for screens that change. Add no new ones.
- **Files:** about 300 lines at most, and `build` about 120 lines at most. Keep the fixed `itemExtent` and `trackRowExtent`. Check `mounted` after `await`.
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/` while another agent works there.
- **Last task:** the Mi A3 / Linux check plus the tick in `docs/PROGRESS.md`. The controller runs the devices; the task only lists what to check.

## Decisions made while planning

1. **Column threshold.** The header goes to a column when `width / textScale < 300` or `width < 360`, with `width` taken from the `LayoutBuilder`.
2. **Meta in words.**
   - New plurals: `minutesWords` («48 minuti») and `hoursWords` («5 ore»).
   - `hoursAndMinutes` gives «{hours} e {minutes}».
   - `noTracks` gives «Nessun brano».
   - Parts are joined with `', '`.
3. **«Casuale» in a collection still shuffles that collection**, as `ShuffleButton` does today.
   - It is accented when `shuffleModeProvider != off`.
   - It shows the «+» badge (`ValueKey('shuffle-plus-badge')`) with Shuffle+.
   - A long press opens `showShufflePlusSheet`, as `ShuffleModeButton` does.
4. **The dot speaks.** `NowPlayingDot` carries `Semantics(label: l.nowPlaying)`. Today `NowPlayingBars` says nothing, so this makes «In riproduzione» true for screen readers.
5. **`NowPlayingBars` is removed in this phase**, including `jam_screen.dart:225` and `online_queue_row.dart:79`. Then `now_playing_bars.dart` is deleted.
6. **Artist page rows show the album as subtitle**, with the new `TrackRow.albumAsSubtitle`.
7. **«Più ascoltati» on the local artist gets no «Tutti»**: no page exists for it, and the phase adds no functions.

## Review Focus

1. **A very long name at 150 % on a 360 dp phone.** The header goes to a column, the name ellipsizes at 3 lines, and the pills wrap instead of overflowing. Test: Task 2, «header stacks at 150 % on 360 dp».
2. **Empty playlist or Preferiti.** No «Riproduci»/«Casuale». The «⋯» menu is still there, so tracks can still be added, and the empty state sits under the header. Test: Task 3, «empty collection hides the pills, keeps the menu».
3. **Duration 0 or unknown, and over 1 hour.**
   - «0 minuti» is never shown.
   - Under one minute shows «1 minuto»; ms are rounded up when `> 0`.
   - 112 minutes show «1 ora e 52 minuti», and exact hours show «2 ore».
   - Test: Task 1, «collectionMeta in words».
4. **The playing track is not in the visible list, or is paused.** At most one dot per screen. A paused current track keeps the dot and the accent title. Test: Task 4, «dot only on the current row».
5. **Desktop wide rows.** The album column, hover and the selection bar keep working, and the dot replaces the bars in the number slot. Test: Task 4, «wide row shows dot and album column».

---

### Task 1: The meta line in words

**Files:**
- Modify: `lib/ui/screens/library/album_detail_screen.dart:28` (replace `tracksAndMinutes` and its callers in the same file, :60-70 and :94-)
- Modify: the callers of `tracksAndMinutes`:
  - `lib/ui/screens/playlists/playlist_detail_screen.dart:255`
  - `lib/ui/screens/library/favorites_screen.dart:64`
  - `lib/ui/screens/library/smart_playlist_screen.dart` (the `meta:` at :78-)
  - `lib/ui/screens/library/artist_screen.dart` (the `meta:` at :65-)
  - (`grep -rn tracksAndMinutes lib`)
- Modify: the 6 ARBs `lib/l10n/app_{it,en,de,es,fr,pt}.arb`
- Test: `test/ui/collection_pages_test.dart`

**Interfaces:**
- Produces `String collectionMeta(AppLocalizations l, {int? year, required int tracks, required int durationMs, int? albums})`.
  - It returns `'Nessun brano'` when `tracks == 0`.
  - Otherwise it joins with `', '`: `[if (albums != null) l.albumsCount(albums), if (year != null) '$year', l.tracksCount(tracks), durationWords(l, durationMs)]`.
- Produces `String durationWords(AppLocalizations l, int ms)` in the same file.
  - Minutes are `(ms / 60000).ceil()` when `ms > 0`.
  - Under 60 minutes it returns `minutesWords`.
  - Otherwise it returns `hoursWords(h)`, or `hoursAndMinutes(hoursWords(h), minutesWords(m))` when `m > 0`.
- New ARB keys, it values:
  - `minutesWords` «{n, plural, one{1 minuto} other{{n} minuti}}»
  - `hoursWords` «{n, plural, one{1 ora} other{{n} ore}}»
  - `hoursAndMinutes` «{hours} e {minutes}»
  - `noTracks` «Nessun brano»
  - en: «1 minute/{n} minutes», «1 hour/{n} hours», «{hours} {minutes}», «No tracks».
  - de/es/fr/pt: natural equivalents.

- [ ] **Step 1: Write the failing test.**

```dart
test('collectionMeta in words', () {
  final l = lookupAppLocalizations(const Locale('it'));
  expect(collectionMeta(l, year: 2004, tracks: 12, durationMs: 48 * 60000), '2004, 12 brani, 48 minuti');
  expect(collectionMeta(l, tracks: 32, durationMs: 112 * 60000), '32 brani, 1 ora e 52 minuti');
  expect(collectionMeta(l, albums: 6, tracks: 84, durationMs: 300 * 60000), '6 album, 84 brani, 5 ore');
  expect(collectionMeta(l, tracks: 1, durationMs: 20000), '1 brano, 1 minuto');
  expect(collectionMeta(l, tracks: 0, durationMs: 0), 'Nessun brano');
});
```

- [ ] **Step 2: Run `flutter test test/ui/collection_pages_test.dart`.** Expected: FAIL, because `collectionMeta` is not defined.
- [ ] **Step 3: Add the keys to the 6 ARBs, run `flutter gen-l10n`, and implement both functions. Switch every caller:**
  - **Album:** drop `l.kindAlbum ·`. Meta is `collectionMeta(l, year:, tracks:, durationMs:)`.
  - **Playlist and Preferiti:** drop `l.kindPlaylist ·`. Meta is `collectionMeta(l, tracks:, durationMs:)`.
  - **Smart playlist:** meta is `collectionMeta(l, tracks:, durationMs:)` in place of `l.smartSubtitle`. Leave the `smartSubtitle` key in place if it is used elsewhere (`grep`).
  - **Artist:** meta is `collectionMeta(l, albums:, tracks:, durationMs: <sum of the loaded tracks>)`.
    - `l.artistMeta` goes if unused.
    - If it is still used, change its value in all 6 ARBs to «{albums}, {tracks}».
- [ ] **Step 4: Run `flutter test test/ui/collection_pages_test.dart test/ui/smart_playlists_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS. The old `textContaining('2019')` assertion still holds.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): riga meta delle raccolte in parole`.

---

### Task 2: The new `CollectionScaffold` header

**Files:**
- Modify: `lib/ui/widgets/collection_header.dart:73-190`
  - Remove `CoverBackdrop` (:120-122) and its import.
  - Change the layout at :144-170 and the cover size at :78.
- Test: `test/ui/collection_pages_test.dart`

**Interfaces:**
- Changes the `CollectionScaffold` signature in one way: `cover` becomes nullable (`Widget Function(double size)?`). A null cover lays out the text only; the tag and genre pages use this in 2.4 and 2.6. Everything else stays.
- Layout (the outer `LayoutBuilder` gives `width`):
  - **wide** = `width >= CcDims.wideBreakpoint`. Cover 200, name `displaySmall`.
  - **stacked** = `width / textScale < 300 || width < 360`. Cover above the name, still at the left.
  - **otherwise** a `Row`: cover 128, a 16 gap, then the text.
- Texts:
  - name `headlineSmall` (`displaySmall` when wide), `maxLines: 3`, `TextOverflow.ellipsis`;
  - subtitle `bodyLarge` with `color: cc.textMuted`;
  - meta `bodyMedium`.
- Padding: everything starts at `CcDims.margin`. On wide screens the content sits in `ConstrainedBox(maxWidth: 960)`, aligned left.
- The `SliverAppBar` keeps the title that appears after an offset of 220 (:60-63). Its background is `cc.bg`, with no tint.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('header: cover left of the name, no backdrop', (t) async {
  // phone 400x800, album page as in the existing album test
  expect(find.byType(CoverBackdrop), findsNothing);
  final cover = t.getRect(find.byKey(const ValueKey('collection-cover')));
  final name = t.getRect(find.text('Album 0').first);
  expect(cover.left, CcDims.margin);
  expect(name.left, greaterThan(cover.right));
});
testWidgets('header stacks at 150 % on 360 dp', (t) async {
  // 360x780, MediaQuery textScaler 1.5, album title of 80 chars
  final cover = t.getRect(find.byKey(const ValueKey('collection-cover')));
  final name = t.getRect(find.byKey(const ValueKey('collection-name')));
  expect(name.top, greaterThan(cover.bottom));
  expect(t.takeException(), isNull);
});
```

- [ ] **Step 2: Run `flutter test test/ui/collection_pages_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Rewrite the header layout.** Keep `coverKey` and `selectionBar` as they are. Add `ValueKey('collection-cover')` and `ValueKey('collection-name')`.
- [ ] **Step 4: Run `flutter test test/ui/collection_pages_test.dart test/ui/large_text_test.dart test/ui/font_scale_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): intestazione delle raccolte a sinistra`.

---

### Task 3: «Riproduci» and «Casuale» pills

**Files:**
- Modify: `lib/ui/widgets/play_buttons.dart` (add `PlayPill`; remove `ShuffleButton` :50-91 once nothing uses it)
- Modify: `lib/ui/widgets/shuffle_button.dart` (add `ShufflePill`)
- Modify: `lib/ui/widgets/collection_header.dart:106-115` (the actions row)
- Modify: `lib/ui/screens/library/artist_screen.dart` (`menu`: at most 2 icons next to «⋯»; the YTM follow and open icons stay as they are, keys unchanged)
- Modify: `lib/ui/screens/library/genre_screen.dart:44-49` and `lib/ui/screens/library/all_tracks_screen.dart:221-224`
  - They stop using `ShuffleButton` + `PlayCircleButton` and use the pills instead.
  - Keep `PlayCircleButton` where there is no room for words: `tags_screen.dart:93`, the player, the jam card, the desktop bar.
- Test: `test/ui/collection_pages_test.dart`, `test/ui/shuffle_button_test.dart`

**Interfaces:**
- `PlayPill({Key? key, required VoidCallback? onPressed})` is `FilledButton.icon(icon: Icon(Icons.play_arrow_rounded), label: Text(l.play))`, wrapped in `PressScale`.
- `ShufflePill({Key? key, required VoidCallback? onPressed})` is a `ConsumerWidget`, an `OutlinedButton.icon` with the label `l.shuffle`.
  - The icon and text use `cc.accent` when `shuffleModeProvider != ShuffleMode.off`, otherwise `cc.text`.
  - It shows the «+» badge `ValueKey('shuffle-plus-badge')` when the mode is `plus`. Reuse the badge code from `ShuffleModeButton`.
  - A long press calls `showShufflePlusSheet(context)`, wrapped in `PressScale`.
- `CollectionScaffold` actions are a `Wrap(spacing: 8, runSpacing: 8)` of `[if (onPlay != null) PlayPill, if (onShuffle != null) ShufflePill, ...barActions-free menu]`.
  - The «⋯» `menu` is always shown.
  - Both pills are hidden when `onPlay == null && onShuffle == null`, which is the empty collection.

- [ ] **Step 1: Write the failing tests.** In `collection_pages_test.dart`:
  - Replace `expect(find.byType(PlayCircleButton), findsOneWidget)` with `expect(find.widgetWithText(FilledButton, 'Riproduci'), findsOneWidget)` and `expect(find.widgetWithText(OutlinedButton, 'Casuale'), findsOneWidget)`.
  - Add the test below.

```dart
testWidgets('empty collection hides the pills, keeps the menu', (t) async {
  // favourites page with 0 favourites
  expect(find.text('Riproduci'), findsNothing);
  expect(find.text('Casuale'), findsNothing);
  expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget); // whatever icon the page menu uses today
});
```

  In `shuffle_button_test.dart`:

```dart
testWidgets('ShufflePill: accent when on, badge with Shuffle+, long press opens the sheet', ...)
```

- [ ] **Step 2: Run `flutter test test/ui/collection_pages_test.dart test/ui/shuffle_button_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the pills, wire them in, and delete `ShuffleButton`.** Run `grep -rn 'ShuffleButton(' lib test` and expect it to be empty.
- [ ] **Step 4: Run `flutter test test/ui/collection_pages_test.dart test/ui/shuffle_button_test.dart test/ui/smart_playlists_test.dart test/ui/tags_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): pillole Riproduci e Casuale`.

---

### Task 4: Rows without «·», with the dot

**Files:**
- Modify: `lib/ui/widgets/ring_progress.dart` (add `NowPlayingDot`)
- Modify: `lib/ui/widgets/track_row.dart`
  - `_subtitle` :99-120;
  - `_leading` :122-168;
  - the wide slot :371-374;
  - a new field next to :39-92.
- Modify: `lib/ui/screens/library/artist_screen.dart` (rows pass `albumAsSubtitle: true`)
- Modify: `lib/ui/screens/jam/jam_screen.dart:225`, `lib/ui/widgets/online_queue_row.dart:79` (bars become the dot)
- Delete: `lib/ui/widgets/now_playing_bars.dart`
- Test: `test/ui/widgets_test.dart`, `test/ui/ring_progress_test.dart`

**Interfaces:**
- `NowPlayingDot({Key? key, double size = 8})` is a `StatelessWidget`.
  - It draws a circle in `cc.accent` and never animates.
  - Its semantics are `Semantics(label: context.l10n.nowPlaying)`.
- `TrackRow.albumAsSubtitle` is a `bool` (default `false`). It is forwarded by `LiveTrackRow`.
- `_subtitle` rules:
  - standard: `artist`, or `album` when `albumAsSubtitle`;
  - album variant: the artist only when it differs from `albumArtist` (as today);
  - then `resumeFrom` and `subtitleSuffix`;
  - all joined with `', '`.
- `_leading` rules:
  - album variant: when current, `NowPlayingDot()` replaces the number;
  - standard variant: when current, `Stack(clipBehavior: Clip.none)` with `Positioned(top: -3, right: -3, child: NowPlayingDot())` on the cover;
  - wide slot: `NowPlayingDot()`.
- The title stays `cc.accent` when current (:332-334).

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('standard subtitle is the artist only', (t) async {
  // TrackRow(track: artist 'Daft Punk', album 'Discovery')
  expect(find.text('Daft Punk'), findsOneWidget);
  expect(find.textContaining('·'), findsNothing);
  expect(find.textContaining('Discovery'), findsNothing);
});
testWidgets('dot only on the current row', (t) async {
  // 3 TrackRows, the second isCurrent: true, isPlaying: false
  expect(find.byType(NowPlayingDot), findsOneWidget);
  expect(find.bySemanticsLabel('In riproduzione'), findsOneWidget);
});
testWidgets('wide row shows dot and album column', (t) async {
  // 1000 px wide, isCurrent: true
  expect(find.byType(NowPlayingDot), findsOneWidget);
  expect(find.text('Discovery'), findsOneWidget);
});
```

- [ ] **Step 2: Run `flutter test test/ui/widgets_test.dart`.** Expected: FAIL, because `NowPlayingDot` is not defined.
- [ ] **Step 3: Implement the changes and delete `now_playing_bars.dart`.** Run `grep -rn NowPlayingBars lib test` and expect it to be empty.
- [ ] **Step 4: Run the tests and `flutter analyze`.** Expected: PASS. Files:
  - `test/ui/widgets_test.dart`
  - `test/ui/ring_progress_test.dart`
  - `test/ui/track_row_selection_test.dart`
  - `test/ui/collection_pages_test.dart`
  - `test/ui/jam_screen_test.dart`
  - `test/ui/online_queue_row_test.dart`
  - `test/ui/search_screen_test.dart`
  - `test/ui/motion_test.dart`

  Update the old assertions that expected «Artist · Album» in those files.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): righe senza punto e pallino del brano in ascolto`.

---

### Task 5: Quiet empty and error states

**Files:**
- Modify: `lib/ui/widgets/empty_state.dart` (layout, plus a new optional `help`)
- Modify: `lib/ui/widgets/error_state.dart` (same form, «Riprova» as `FilledButton`)
- Modify: `lib/ui/screens/library/favorites_screen.dart:88-104` (the inline empty `Column` becomes `EmptyState`)
- Modify: `lib/ui/screens/playlists/playlist_detail_screen.dart:143-162` (the inline empty `Column` with the 56 icon becomes `EmptyState(message: l.noTracksInPlaylist, actionLabel: l.addSongs, …)` inside the `SliverToBoxAdapter`)
- Modify: the 6 ARBs
- Test: `test/ui/widgets_test.dart`, `test/ui/collection_pages_test.dart`

**Interfaces:**
- `EmptyState({required IconData icon, required String message, String? help, String? actionLabel, VoidCallback? onAction, String? secondaryLabel, VoidCallback? onSecondary})`.
  - `icon` stays but is not drawn. Its doc comment says: «kept for callers, not drawn; remove when unused».
  - Layout: `Align(topLeft)` with padding `fromLTRB(CcDims.margin, 24, CcDims.margin, 0)`. Inside are `message` in `titleSmall`, `help` in `bodyMedium`, then `FilledButton` and `TextButton`.
- `ErrorState({message, onRetry})` has the same form, with `FilledButton(l.retry)`. `loadErrorState` is unchanged; it still calls `AppLog.e`.
- New ARB keys, it values:
  - `favoritesEmptyTitle` «Nessun preferito, per ora»
  - `favoritesEmptyHelp` «Tocca il cuore su un brano e lo trovi qui.»
  - `openAllTracks` «Apri tutti i brani», which opens `AllTracksScreen` through `ShellNav.open`.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('EmptyState is left-aligned text with no icon', (t) async {
  // EmptyState(icon: Icons.star, message: 'M', help: 'H', actionLabel: 'A', onAction: () {}) in 400x800
  expect(find.byIcon(Icons.star), findsNothing);
  expect(t.getRect(find.text('M')).left, CcDims.margin);
  expect(find.widgetWithText(FilledButton, 'A'), findsOneWidget);
});
testWidgets('favourites page: empty state and Play', ...) // existing: now expects 'Nessun preferito, per ora', the help text and 'Apri tutti i brani'
```

- [ ] **Step 2: Run `flutter test test/ui/widgets_test.dart test/ui/collection_pages_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the change, add the 3 keys to the 6 ARBs, and run `flutter gen-l10n`.**
- [ ] **Step 4: Run the tests and `flutter analyze`.** Expected: PASS. Files:
  - `test/ui/widgets_test.dart`
  - `test/ui/collection_pages_test.dart`
  - `test/ui/library_screen_test.dart`
  - `test/ui/history_screen_test.dart`
  - `test/ui/review_screen_test.dart`
  - `test/l10n/arb_test.dart`

  These tests use `EmptyState`. Fix any icon finders in them.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): stati vuoti ed errori quieti`.

---

### Task 6: Goldens and device check

**Files:**
- Regenerate: `test/goldens/*_album.png` and `*_selection.png`, if the selection golden shows rows.
- Modify: `docs/PROGRESS.md` (an «Anello fase 2.1» line with a tick)

- [ ] **Step 1: Regenerate the goldens.** Run `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart`. Then open the changed PNGs and check:
  - no tint behind the album;
  - the cover at the left;
  - at 150 % the header is stacked and nothing overflows;
  - the pills are visible.
- [ ] **Step 2: Device check (controller).**
  - **Mi A3:** build `JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14 flutter build apk --debug`, then `adb -s 0d7ae9df206e install -r`. Never turn the screen off, uninstall or clear data. Check:
    - album, playlist, Preferiti (empty and full), a smart playlist and the artist page;
    - the dot on the playing track;
    - «Casuale» with a long press;
    - text at 150 %;
    - Notte, OLED and Chiaro, with viola, ambra and rosa;
    - `adb shell dumpsys gfxinfo com.codecore.player` while scrolling an album: janky frames under 10 %.
  - **Linux (Xephyr):** the album at 200 px cover with the album column and hover.
- [ ] **Step 3: Tick 2.1 in `docs/PROGRESS.md` and commit** (controller). Message: `test(anello): golden fase 2.1`.
