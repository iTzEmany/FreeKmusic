# Anello fase 2.3, Fogli: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The track actions sheet gets a three-line header and groups separated by space, with deletion last in red. The other bottom sheets follow the same form. Dialogs and menus lose «·» and «→» from their texts.

**Architecture:**
- `_TrackActionsSheet` (`lib/ui/widgets/track_actions.dart:342-410`) changes in place.
- A small helper, `showCcSheet`, wraps `showModalBottomSheet` so every sheet opens in `CcMotion.sheet` (250 ms) and honours «Riduci animazioni».
- The 22 call sites move to `showCcSheet`, and their titles become `titleMedium`.
- A pinned ARB test forbids «·», «•» and «→» in values. It keeps a shrinking allowlist that later sub-phases empty.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read Obiettivo 8, Obiettivo 11 (foglio 250 ms), Non obiettivi (dialogs: texts only; desktop `showMenu` keeps its dividers), and «Fogli e finestre». The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.** Only `CcColors` via `context.cc`, `CcDims`, `Motion`/`CcMotion` and `ccDuration`.
- **ARB edits.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’.
  - Only one agent at a time touches the ARBs.
- **Copy:** no «A · B», no «→», no ALL CAPS. Separators become `, ` or a sentence.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** no heavy work on it.
- **Motion.**
  - The sheet opens in `ccDuration(context, CcMotion.sheet)`.
  - With «Riduci animazioni» on it opens with no animation.
  - Nothing else new moves.
- **Out of scope:**
  - the shape of dialogs (`surface1`, radius 16);
  - the desktop right-click `showMenu` and its `PopupMenuDivider`s (`track_actions.dart:315`, `selection_bar.dart:90`);
  - `car_playlists_sheet.dart`, because Modalità auto stays as it is.
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files.
  - `flutter analyze` must be clean.
- **Goldens:** none of the goldens shows a sheet, so none needs regenerating. Check with `grep -n showTrackActions test/goldens`.
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/`.
- **Last task:** device check plus the tick in `docs/PROGRESS.md`. The controller runs the devices.

## Decisions made while planning

1. **`TrackAction` gets `{bool destructive = false}`.** Only «Elimina dal dispositivo» (`track_actions.dart:277-283`) sets it.
   - In the sheet, a destructive action draws its icon and label in `cc.error`.
   - `bulk_actions.dart` sets it on its delete action too, if it has one.
   - The desktop `showMenu` keeps its look.
2. **Reduced motion for sheets** goes through one helper, not 22 hand edits of `sheetAnimationStyle`.
   - `showModalBottomSheet` in Flutter 3.47 takes `sheetAnimationStyle` (checked in the SDK, `bottom_sheet.dart:246`).
   - No sheet passes one today, so they open at the default 250 ms even with «Riduci animazioni» on.
3. **The ARB rule is a test with an allowlist.** This sub-phase removes the dialog and menu strings from it:
   - `exportFormatM3u8`, `exportFormatCsv`, `exportFormatJson`;
   - `restoreInfo`;
   - `writeTagsWarnBody`;
   - `ytmAlbumConfirmBody`;
   - `tracksDeletedSome`;
   - `csvImportSyncCounts`.

   2.4, 2.5 and 2.6 shrink the allowlist until it is empty.

## Review Focus

1. **A track with no artist and no album, or very long names.**
   - The header shows «Artista sconosciuto» and no empty album line.
   - Each line ellipsizes at 1 line (the title at 2) at 150 % text, with no overflow.
   - Test: Task 1, «header lines with missing album and long title».
2. **An online (streamed) track,** which has fewer actions.
   - The groups that remain still have 8 dp gaps.
   - There is no trailing gap and no red action when there is no delete.
   - Test: Task 1, «online track: no destructive row».
3. **«Riduci animazioni» on.** Every sheet opens with zero duration. Test: Task 2, «showCcSheet honours reduced motion».
4. **Tall sheets on a small phone** (the queue, playlist source, radio region).
   - `isScrollControlled` and the drag handle behave as today.
   - The new title does not push content off-screen.
   - Test: Task 2, «queue sheet still scrolls at 150 % on 360x640».
5. **Translations.**
   - A rewritten value keeps its placeholders in all 6 languages.
   - fr and pt keep the ’ apostrophe.
   - Test: Task 3, the existing `arb_test.dart` checks plus «no separator dots or arrows».

---

### Task 1: The track actions sheet

**Files:**
- Modify: `lib/ui/widgets/track_actions.dart`
  - `TrackAction` :45-51;
  - the delete action :277-283;
  - `_TrackActionsSheet` :342-410, including the `' · '` join at :356 and the `Divider` at :391.
- Modify: `lib/ui/widgets/bulk_actions.dart` (mark its delete action `destructive`, if it has one)
- Test: `test/ui/track_actions_test.dart`

**Interfaces:**
- Produces `TrackAction(IconData icon, String label, Future<void> Function() run, {bool destructive = false})`. The positional parameters do not change, so the callers do not change.
- Header layout: a `Row` with `TrackArt(size: 56)`, a 12 gap, then a `Column` of:
  - `track.title` in `titleSmall`, `maxLines: 2`;
  - `track.artist ?? l.unknownArtist` in `bodyMedium`, 1 line;
  - `track.album` in `bodySmall` with `cc.textFaint`, only when it is not null or empty, 1 line.
- Groups: `SizedBox(height: 8)` between groups, never before the first or after the last. No `Divider`.
- A destructive `ListTile` has `iconColor: cc.error` and `textColor: cc.error`. Deletion stays the last action.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('sheet header has title, artist, album on three lines', (t) async {
  // showTrackActions on a track 'T' / 'Daft Punk' / 'Discovery'
  expect(find.textContaining('·'), findsNothing);
  final a = t.getRect(find.text('Daft Punk')); final b = t.getRect(find.text('Discovery'));
  expect(b.top, greaterThanOrEqualTo(a.bottom));
  expect(find.byType(Divider), findsNothing);
});
testWidgets('delete is last and red', (t) async {
  final tiles = t.widgetList<ListTile>(find.byType(ListTile)).toList();
  expect((tiles.last.title as Text).data, 'Elimina dal dispositivo');
  expect(tiles.last.textColor, CcColors.notte(/* accent */).error); // or read cc from the tree
});
testWidgets('header lines with missing album and long title', ...) // album null, title 200 chars, textScaler 1.5, 360 wide: no exception, no album line
testWidgets('online track: no destructive row', ...) // streamed track: no ListTile with textColor == cc.error
```

- [ ] **Step 2: Run `flutter test test/ui/track_actions_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the change.**
- [ ] **Step 4: Run `flutter test test/ui/track_actions_test.dart test/ui/selection_bar_test.dart test/ui/no_stray_colors_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): foglio azioni del brano più leggero`.

---

### Task 2: `showCcSheet` and the other sheets

**Files:**
- Create: `lib/ui/widgets/cc_sheet.dart`
- Modify: every `showModalBottomSheet(` call (24 hits across 22 files; `grep -rn showModalBottomSheet lib`), except `lib/ui/screens/car/car_playlists_sheet.dart`.
  - Swap the call for `showCcSheet` with the same arguments.
  - Title styles go from `titleLarge` to `titleMedium`, left aligned:
    - `youtube/playlist_source_sheet.dart:96`
    - `import/import_intro_sheet.dart:131`
    - `radio/radio_region_sheet.dart:60`
    - `radio/radio_station_sheet.dart:107`
    - `podcast/podcast_subscribe_sheet.dart:107`
  - `' · '` joins inside sheets become `', '`:
    - `playlist_source_sheet.dart:214`
    - `radio_station_sheet.dart:90`
    - `podcast_subscribe_sheet.dart:180`
- Test: `test/ui/widgets_test.dart` (a new `group('showCcSheet')`), `test/ui/queue_reorder_test.dart`

**Interfaces:**
- Produces:
  ```dart
  Future<T?> showCcSheet<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false, bool useSafeArea = false, bool showDragHandle = true});
  ```
  - It calls `showModalBottomSheet<T>` with `sheetAnimationStyle: AnimationStyle(duration: ccDuration(context, CcMotion.sheet), reverseDuration: ccDuration(context, CcMotion.sheet))`.
  - Add the other named parameters only when a call site passes them. Run `grep -A4 showModalBottomSheet lib` to see which ones are used.
- The rule for every sheet:
  - no `Divider` between rows;
  - the title in `titleMedium`, on the left;
  - no big icon on top.

  The survey found no sheet with a divider or a big top icon apart from the track sheet. `radio_station_sheet.dart:104` shows the station's `RadioArt` 64 next to the name, as content, so it stays.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('showCcSheet honours reduced motion', (t) async {
  // MediaQuery(disableAnimations: true); showCcSheet(...) ; await t.pump();
  expect(find.text('body'), findsOneWidget); // visible after one frame, no settle needed
});
testWidgets('queue sheet still scrolls at 150 % on 360x640', ...) // showQueueSheet, drag the list, no exception
```

  Also add to `widgets_test.dart`: `test('no raw showModalBottomSheet outside cc_sheet and car mode', ...)`. It reads `lib/**.dart` and expects `showModalBottomSheet` only in `cc_sheet.dart` and `car_playlists_sheet.dart`.
- [ ] **Step 2: Run `flutter test test/ui/widgets_test.dart test/ui/queue_reorder_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement the helper and switch the call sites.**
- [ ] **Step 4: Run the tests and `flutter analyze`.** Expected: PASS. Files:
  - `test/ui/widgets_test.dart`
  - `test/ui/queue_reorder_test.dart`
  - `test/ui/activity_test.dart`
  - `test/ui/speed_button_test.dart`
  - `test/ui/radio_screen_test.dart`
  - `test/ui/podcast_screens_test.dart`
  - `test/ui/playlist_source_test.dart`
  - `test/ui/artist_picker_sheet_test.dart`
  - `test/ui/tags_test.dart`
  - `test/ui/csv_import_test.dart`
  - `test/ui/library_screen_test.dart`
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): fogli con animazione ridotta e titoli uguali`.

---

### Task 3: Texts of dialogs and menus

**Files:**
- Modify: the 6 ARBs (the keys listed in Decision 3)
- Modify: `lib/ui/screens/import/sync_preview_dialog.dart:46,103` (the code joins `' · '` become `', '`)
- Test: `test/l10n/arb_test.dart`, `test/ui/sync_preview_dialog_test.dart`, `test/ui/restore_dialog_test.dart`, `test/ui/export_dialog_test.dart`

**Interfaces:**
- Add to `arb_test.dart`:
  ```dart
  /// Shrinks to empty by the end of fase 2.6.
  const _separatorPending = { /* every key still matching after this task */ };
  test('no separator dots or arrows', () { /* for each lang, each non-@ key not in _separatorPending: value has no ' · ', ' • ', '→' */ });
  ```
- New it values. Translate them in the other 5 ARBs the same way.
  - `exportFormatM3u8` «M3U8, per altri lettori». The same pattern applies to `exportFormatCsv` and `exportFormatJson`.
  - `restoreInfo` «Del {date}, app {version}, {tracks} brani, {playlists} playlist»
  - `ytmAlbumConfirmBody` «{tracks, plural, …}, {duration}, circa {size}»
  - `tracksDeletedSome` «{count, plural, …}, {failed} non eliminati»
  - `csvImportSyncCounts` «{added} nuovi, {removed} rimossi dalla playlist (i file restano)»
  - `writeTagsWarnBody`: the end becomes «…(Impostazioni, Backup).»

- [ ] **Step 1: Write the failing test.** Add the test above, with the allowlist built from `grep -nE '( · | • |→)' lib/l10n/app_it.arb` minus the keys of Decision 3.
- [ ] **Step 2: Run `flutter test test/l10n/arb_test.dart`.** Expected: FAIL on the 8 keys.
- [ ] **Step 3: Rewrite the 8 values in the 6 ARBs, fix the 2 code joins, and run `flutter gen-l10n`.**
- [ ] **Step 4: Run `flutter test test/l10n/arb_test.dart test/ui/sync_preview_dialog_test.dart test/ui/restore_dialog_test.dart test/ui/export_dialog_test.dart test/ui/tag_write_options_test.dart` and `flutter analyze`.** Expected: PASS. Update the old assertions that contain «·».
- [ ] **Step 5: Commit** (controller). Message: `fix(anello): testi di finestre e menu senza punto e freccia`.

---

### Task 4: Device check

**Files:**
- Modify: `docs/PROGRESS.md` (the «Anello fase 2.3» tick)

- [ ] **Step 1: Device check (controller).**
  - **Mi A3** (debug APK; never turn the screen off). Check:
    - the track sheet from a row, from the player and from an online result;
    - the delete row is red and last;
    - the queue sheet, the Shuffle+ sheet, the radio station sheet, playlist add and the tags sheet;
    - «Riduci animazioni» on: sheets appear at once;
    - 150 % text;
    - Notte, OLED and Chiaro with viola, ambra and rosa: `error` must be readable on `surface1` in every theme.
  - **Linux (Xephyr):** the right-click menu still has its dividers, and the dialogs export, restore and import preview.
- [ ] **Step 2: Tick 2.3 in `docs/PROGRESS.md` and commit** (controller). Message: `docs(anello): fase 2.3 provata`.
