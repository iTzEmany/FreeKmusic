# Anello fase 2.2, Libreria: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Libreria shows one row of four blocks with icons («Tutto, Playlist, Album, Artisti»). Under them is a text row with the count and the sort, and the shortcuts become wrapping pills. With A–Z, letters act as headers.

**Architecture:**
- `SegmentedBlocks<T>` is a new reusable widget in `lib/ui/widgets/segmented_blocks.dart`. Phases 2.4 and 2.6 reuse it.
- `library_screen.dart` (622 lines, already over the limit) loses its two chip rows and the `_Pinned` rows. They move into two new files under `lib/ui/screens/library/`: the count and sort row, and the shortcut pills.
- The list view gets letter headers through `ListView.builder(itemExtentBuilder:)`, so the extents stay fixed.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, drift, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read Obiettivo 4, Obiettivo 11, Vincoli (blocks, 150 %, accessibility), «Libreria» under «Decisioni per schermata», and Decisioni 5, 6, 9 and 11. The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.**
  - Only `CcColors` via `context.cc`, `CcDims` and `Motion`/`CcMotion` with `ccDuration`.
  - The spec pins two radii: 16 for blocks (`CcDims.rSheet`) and 14 for pills (a literal, as in the spec).
- **New strings.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’.
  - Only one agent at a time touches the ARBs.
- **Copy:** no «A · B», no «→», no ALL CAPS.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** no heavy work on it. Counts come from providers the screen already watches (`library_screen.dart:88-104`).
- **Motion.**
  - Animate only opacity and transform.
  - The active fill slides in `Motion.enter` (180 ms) with `Motion.curve` (easeOutCubic), through `ccDuration`. With «Riduci animazioni» on it jumps.
  - The content changes with `TabFade`.
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files: `flutter test <files>`.
  - `flutter analyze` must be clean.
- **Goldens:** regenerate only `library` and `light_library` in `test/goldens/screens_golden_test.dart`.
- **Files:** about 300 lines at most, and `build` about 120 lines at most. Keep the fixed extents: entries 64, `trackRowExtent`.
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/`.
- **Last task:** device check plus the tick in `docs/PROGRESS.md`. The controller runs the devices.

## Decisions made while planning

1. **`SegmentedBlocks` covers both «nothing selected» and «Tutto».** «Tutto» is a real item with value `null`, so the type parameter is nullable (`SegmentedBlocks<LibraryKind?>`).
2. **Home's `_Shortcut` is private, and Home is off-limits.** The Libreria gets its own `LibraryShortcutPill`. It is not a copy of the Home card: the spec asks for a pill.
3. **Shortcuts with no ready count show only the name:**
   - Cronologia and Statistiche have no count today (`historySubtitle`, `statsSubtitle`);
   - Radio counts saved stations;
   - Da revisionare appears only when `reviewCount > 0`, as today;
   - Artisti seguiti keeps its condition at `library_screen.dart:174`.
4. **Letters only in the list view with A–Z.** The grid stays as it is: a letter row would break the grid's rhythm, and the spec only says «intestazione».
5. **The sort menu** is a `PopupMenuButton` disguised as a `TextButton`. It holds «Recenti, A–Z, Aggiunti di recente».
   - The value of `sortAlphabetical` («Alfabetico») stays for other uses.
   - A new key `sortAToZ` «A–Z» is added.

## Review Focus

1. **The four blocks at 150 % text on a 360 dp phone.** They become a 2×2 grid, never a horizontal scroll, and no label is cut mid-word. Test: Task 1, «falls back to 2×2 when the row does not fit».
2. **«Riduci animazioni» on.** The fill jumps to the new block with no tween frames, and the content does not slide. Test: Task 1, «reduced motion: no slide».
3. **An empty library or zero counts.**
   - The count row says «0 elementi», not a blank.
   - Only the Preferiti and Tutti i brani pills remain.
   - The permission-denied and no-folders states show the 2.1 empty state with «Aggiungi una cartella» as the only filled button.
   - Test: Task 3, «zero-count shortcuts disappear except Preferiti and Tutti i brani».
4. **A–Z with titles that start with digits, accents or emoji.** They fall under `leadingLetter`'s bucket (`#`, or the letter without its accent). Each header is shown once, and switching back to «Recenti» removes the headers. Test: Task 4, «A–Z headers follow leadingLetter».
5. **Keyboard on desktop.** Tab reaches every block and pill and shows a visible focus ring, and Enter selects. Test: Task 1, «blocks are focusable and announce selected».

---

### Task 1: `SegmentedBlocks`

**Files:**
- Create: `lib/ui/widgets/segmented_blocks.dart`
- Test: `test/ui/widgets_test.dart` (a new `group('SegmentedBlocks')`)

**Interfaces:**
- Produces:
  ```dart
  class BlockItem<T> { const BlockItem({required this.value, required this.icon, required this.label}); final T value; final IconData icon; final String label; }
  class SegmentedBlocks<T> extends StatelessWidget {
    const SegmentedBlocks({super.key, required this.items, required this.selected, required this.onChanged});
    final List<BlockItem<T>> items; final T selected; final ValueChanged<T> onChanged;
  }
  ```
- Values from the spec:
  - each block is `Expanded`, radius 16 (`CcDims.rSheet`), minimum height 64;
  - inside are `Icon(size: 22)` and the label in `labelLarge`, `maxLines: 2`;
  - gap 8 between blocks;
  - **active:** fill `cc.text`, icon and label `cc.bg`;
  - **inactive:** `cc.surface1`, icon `cc.textMuted`, label `cc.text`.
- The fill is one layer under the row: an `AnimatedSlide` of a `FractionallySizedBox(widthFactor: 1/n)`, so only transform animates (no `AnimatedPositioned`). Duration is `ccDuration(context, Motion.enter)`, curve `Motion.curve`.
- **2×2 fallback:**
  - use a `LayoutBuilder`; if `constraints.maxWidth / items.length < 72 * textScale`, lay out as two `Row`s of two (not a `GridView`, so nothing scrolls);
  - in the 2×2 layout the fill does not slide: it is colour per block, with no animation;
  - with 2 items it never falls back.
- **Semantics:**
  - each block is `Semantics(button: true, selected: v == selected, label: item.label, excludeSemantics: true)`;
  - inside it is an `InkWell` with the default focus highlight and `borderRadius` 16, wrapped in `PressScale`.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('tapping a block selects it', (t) async {
  // 4 items, selected 0; tap 'Album' -> onChanged(2)
});
testWidgets('falls back to 2x2 when the row does not fit', (t) async {
  // 360x780, textScaler 1.5, labels 'Tutto','Playlist','Album','Artisti'
  final a = t.getRect(find.text('Tutto')); final c = t.getRect(find.text('Album'));
  expect(c.top, greaterThan(a.bottom));
  expect(find.byType(Scrollable), findsNothing);
  expect(t.takeException(), isNull);
});
testWidgets('reduced motion: no slide', (t) async {
  // MediaQuery(disableAnimations: true); change selected; pump(Duration(milliseconds: 1))
  // the fill's AnimatedSlide has duration Duration.zero
});
testWidgets('blocks are focusable and announce selected', (t) async {
  // sendKeyEvent(Tab) focuses the first block; semantics: isButton, isSelected on the active one, label 'Album'
});
```

- [ ] **Step 2: Run `flutter test test/ui/widgets_test.dart`.** Expected: FAIL, because `SegmentedBlocks` is not defined.
- [ ] **Step 3: Implement `SegmentedBlocks`.**
- [ ] **Step 4: Run `flutter test test/ui/widgets_test.dart test/ui/no_stray_colors_test.dart test/ui/motion_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): selettore a blocchi con icona`.

---

### Task 2: Blocks, count and sort in the Libreria

**Files:**
- Create: `lib/ui/screens/library/library_toolbar.dart` (the count and sort row)
- Modify: `lib/ui/screens/library/library_screen.dart`
  - remove `chip()` at :210-218 and the two `SizedBox(height: 48)` chip rows at :304-378;
  - keep the title row at :222-300 untouched.
- Modify: the 6 ARBs
- Test: `test/ui/library_screen_test.dart`

**Interfaces:**
- Consumes: `SegmentedBlocks`, `BlockItem` (Task 1).
- Blocks: `SegmentedBlocks<LibraryKind?>(items: [null → apps_rounded l.libraryAll, playlist → queue_music_rounded l.navPlaylists, album → album_rounded l.albums, artist → person_rounded l.artists], selected: _kind, onChanged: (k) => setState(() => _kind = k))`.
- Produces `class LibraryToolbar extends StatelessWidget`, with constructor `LibraryToolbar({required String countLabel, required LibrarySort sort, required bool grid, required ValueChanged<LibrarySort> onSort, required VoidCallback onToggleGrid})`.
  - Left: `countLabel` in `bodyMedium`.
  - Right: a `PopupMenuButton<LibrarySort>` whose child is the `TextButton`-styled label of the current sort, then the list/grid `IconButton` that is there today.
- Count label, by `_kind`:
  - `null`: `l.libraryItemsCount(entries.length)`;
  - `playlist`: `l.playlistsCount(n)`;
  - `album`: `l.albumsCount(n)`;
  - `artist`: `l.artistsCount(n)`.
- New ARB keys, it values. All plural placeholders use `"format": "decimalPattern"`, so the it locale shows «2.041».
  - `libraryAll` «Tutto»
  - `libraryItemsCount` «{count, plural, one{1 elemento} other{{count} elementi}}»
  - `playlistsCount` «… 1 playlist / {count} playlist»
  - `artistsCount` «1 artista / {count} artisti»
  - `sortAToZ` «A–Z»
  - Also add `"format": "decimalPattern"` to the existing `albumsCount`.

- [ ] **Step 1: Write the failing tests.** Update the existing chip tests in `library_screen_test.dart` so they tap blocks by label. Then add:

```dart
testWidgets('blocks filter the list and the count follows', (t) async {
  // Harness with 2 albums, 1 playlist, 3 artists
  expect(find.text('Tutto'), findsOneWidget);
  await t.tap(find.text('Album')); await t.pumpAndSettle();
  expect(find.text('2 album'), findsOneWidget);
  expect(find.byType(ChoiceChip), findsNothing);
});
testWidgets('sort menu switches to A–Z', (t) async {
  await t.tap(find.text('Recenti')); await t.pumpAndSettle();
  await t.tap(find.text('A–Z').last); await t.pumpAndSettle();
  expect(find.text('A–Z'), findsOneWidget); // the button now shows the new sort
});
```

- [ ] **Step 2: Run `flutter test test/ui/library_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the change.** Add the keys to the 6 ARBs and run `flutter gen-l10n`.
- [ ] **Step 4: Run `flutter test test/ui/library_screen_test.dart test/ui/large_text_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): blocchi e riga conteggio in Libreria`.

---

### Task 3: Shortcuts as pills, shown only in «Tutto»

**Files:**
- Create: `lib/ui/screens/library/library_shortcuts.dart`. It takes in the `_Pinned` list built at `library_screen.dart:148-203`.
- Modify: `lib/ui/screens/library/library_screen.dart`
  - `_LibraryList` :447 and `_LibraryGrid` :542 stop rendering pinned rows and cells;
  - delete `_Pinned` and `_pinnedCover` once nothing uses them;
  - empty states :111-140 use `EmptyState` from 2.1, with `actionLabel` «Aggiungi una cartella» as the only `FilledButton`.
- Test: `test/ui/library_screen_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class LibraryShortcut { const LibraryShortcut({required this.label, this.count, required this.onTap, this.keepWhenZero = false}); final String label; final int? count; final VoidCallback onTap; final bool keepWhenZero; }
  class LibraryShortcuts extends StatelessWidget { const LibraryShortcuts({super.key, required this.items}); final List<LibraryShortcut> items; }
  ```
- Pill rendering:
  - `Wrap(spacing: 8, runSpacing: 8)` of pills;
  - each pill is `Material(color: cc.surface1, borderRadius: 14)` with an `InkWell` inside, padding `h16 v10`;
  - the label is in `labelLarge`, then a 8 gap, then the count in `bodyMedium` `cc.textMuted`, when `count != null`;
  - it is wrapped in `PressScale`, with `Semantics(button: true)`.
- Hidden when `count == 0 && !keepWhenZero`.
- Order:
  1. Preferiti (`keepWhenZero`)
  2. Tutti i brani (`keepWhenZero`)
  3. Cronologia (no count)
  4. Podcast
  5. Radio
  6. Artisti seguiti (with today's condition)
  7. Tag
  8. Statistiche (no count)
  9. Da revisionare (only if `> 0`)
- The pills are the first child of the scroll view, only when `_kind == null`. In list mode they go in a `SliverToBoxAdapter` before the list, so the 64 extent of the entries holds.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('shortcuts only in Tutto, in spec order', (t) async {
  final fav = t.getRect(find.text('Preferiti')); final all = t.getRect(find.text('Tutti i brani'));
  expect(all.left > fav.left || all.top > fav.top, isTrue);
  await t.tap(find.text('Album')); await t.pumpAndSettle();
  expect(find.text('Preferiti'), findsNothing);
});
testWidgets('zero-count shortcuts disappear except Preferiti and Tutti i brani', (t) async {
  // Harness with 0 podcasts, 0 radios, 0 tags
  expect(find.text('Preferiti'), findsOneWidget);
  expect(find.text('Tutti i brani'), findsOneWidget);
  expect(find.text('Podcast'), findsNothing);
});
```

- [ ] **Step 2: Run `flutter test test/ui/library_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the change.** Update the old assertions that looked for pinned `ListTile`s.
- [ ] **Step 4: Run `flutter test test/ui/library_screen_test.dart test/ui/radio_home_library_test.dart test/ui/review_screen_test.dart test/ui/selection_lists_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): scorciatoie della Libreria come pillole`.

---

### Task 4: Letters with the A–Z sort

**Files:**
- Modify: `lib/ui/screens/library/library_screen.dart` (`_LibraryList` :447-540, `ListView.builder` at :496)
- Test: `test/ui/library_screen_test.dart`

**Interfaces:**
- Consumes: `leadingLetter(String)` from `lib/ui/widgets/alpha_scroller.dart`, used the same way as `all_tracks_screen.dart:109-113`.
- `_LibraryList` gets a `showLetters` flag, which is true when `sort == LibrarySort.alpha && !grid`.
  - It builds a flat `List<Object>` of `String` letters and `LibraryEntry` entries, one header per change of `leadingLetter(entry.title)`.
  - `itemExtentBuilder: (i, _) => rows[i] is String ? 40 * textScale : 64`, where `textScale = MediaQuery.textScalerOf(context).scale(1)`.
- The header is `Text(letter, style: titleSmall.copyWith(color: cc.accentSoft))`, padding `fromLTRB(margin, 16, margin, 4)`. It uses Figtree through `titleSmall`, never Unbounded.
- `AlphaScroller` is not wired to the Libreria today. Do not add it: the spec does not ask for it.

- [ ] **Step 1: Write the failing test.**

```dart
testWidgets('A–Z headers follow leadingLetter', (t) async {
  // albums 'Abba', 'Ägypten', '1999', 'Beta' with sort alpha, list view
  expect(find.text('A'), findsOneWidget);
  expect(find.text('B'), findsOneWidget);
  expect(find.text('#'), findsOneWidget);
  // no header with sort recent
});
```

- [ ] **Step 2: Run `flutter test test/ui/library_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the change.**
- [ ] **Step 4: Run `flutter test test/ui/library_screen_test.dart test/ui/alpha_scroller_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): lettere in Libreria con ordine A–Z`.

---

### Task 5: Desktop, goldens and device check

**Files:**
- Regenerate: the `library` and `light_library` goldens.
- Modify: `docs/PROGRESS.md` (the «Anello fase 2.2» tick)

- [ ] **Step 1: Desktop width.** Check that on screens 840 px and wider the blocks, the toolbar and the pills sit in `ConstrainedBox(maxWidth: 960)`, aligned left. If not, wrap them. Add an assertion in `library_screen_test.dart` at 1400 px: the block row is `<= 960` wide.
- [ ] **Step 2: Regenerate the goldens.** Run `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart`. Then open the changed PNGs and check:
  - the blocks look the same in each variant;
  - the active block is `text`, not accent;
  - at 150 % the blocks are 2×2.
- [ ] **Step 3: Device check (controller).**
  - **Mi A3** (debug APK, `adb -s 0d7ae9df206e install -r`; never turn the screen off). Check:
    - the four blocks;
    - the count with a thousands separator;
    - the sort menu;
    - A–Z letters;
    - shortcuts that are hidden at zero;
    - 150 % text;
    - Notte, OLED and Chiaro with viola, ambra and rosa;
    - «Riduci animazioni» on;
    - `dumpsys gfxinfo` while scrolling the Libreria, under 10 % janky frames.
  - **Linux (Xephyr):** Tab and Enter on the blocks, the 960 width, and the grid view.
- [ ] **Step 4: Tick 2.2 in `docs/PROGRESS.md` and commit** (controller). Message: `test(anello): golden fase 2.2`.
