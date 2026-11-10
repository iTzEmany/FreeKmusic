# Anello fase 2.6, Il resto: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The screens the earlier sub-phases did not reach get the same language. Single-choice rows of up to 4 items become blocks with icons, longer ones become chips that wrap. The last «·» and «→» leave code and ARBs. Podcast, Memoria, Jam, Coda, the tag page and Pulizia get the new headers and empty states. A final check covers every theme at 150 % text.

**Architecture:**
- No new widgets. This phase only reuses what 2.1–2.4 produce:
  - `SegmentedBlocks<T>` / `BlockItem<T>` (2.2);
  - `CollectionScaffold(cover: null)`, `CollectionHeader`, `collectionMeta` (2.1, 2.4);
  - `EmptyState` (2.1).
- Two pinned tests close the phase:
  - the ARB test of 2.3 runs with `_separatorPending` deleted;
  - a source test forbids `' · '` string literals in `lib/ui`.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read «Le altre schermate», «Stati vuoti ed errori», Vincoli (themes, 150 %, accessibility), Decisione 11. The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.** Only `CcColors` via `context.cc`, `CcDims`, `Motion`/`CcMotion` and `ccDuration`.
- **ARB edits.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’.
  - Only one agent at a time touches the ARBs.
  - Placeholders and plural forms stay as they are; only the separators change.
- **Copy:** no «A · B», no «•», no «→», no «▾», no ALL CAPS. Separators become `, ` or a sentence.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** no new query or I/O; every screen keeps its providers.
- **Motion:** only opacity and transform. «Riduci animazioni» via `ccDuration` (already inside `SegmentedBlocks`).
- **Behaviour stays.** Filters, sort, selection, period navigation and playback do what they do today.
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files.
  - `flutter analyze` must be clean.
- **Goldens:** regenerate the ones that change (Task 6). Expected: `*_selection.png` (the sort of Tutti i brani) and `*_jam.png`.
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/`.
- **Last task:** device check plus the tick in `docs/PROGRESS.md`. The controller runs the devices.

## Decisions made while planning

1. **Which rows become blocks.** The rule is «single choice, at most 4 items».
   - Blocks:
     - Statistiche month/year (`stats_screen.dart:79`, today a `SegmentedButton`): `Icons.calendar_view_month_rounded` «Mese», `Icons.date_range_rounded` «Anno»;
     - Tutti i brani sort (`all_tracks_screen.dart:165-184`, 4 items): `Icons.format_list_numbered_rounded` default, `Icons.sort_by_alpha_rounded` title, `Icons.person_rounded` artist, `Icons.schedule_rounded` added. It is part of Libreria, which Decision 11 names.
   - Chips that wrap (`Wrap(spacing: 8, runSpacing: 8)` instead of a horizontal `ListView`):
     - Da revisionare (`review_screen.dart:165-180`, 5 items);
     - Nuove uscite artists (`new_releases_screen.dart:150-205`);
     - Radio genres (`radio_sections.dart:205-220`);
     - Import detail filter (`import_detail_screen.dart:130-145`, 4 items with counts: a tool flow, not in the spec's list). The label becomes `'$label ($n)'`.
   - Unchanged: the Radio «solo paese» `FilterChip` (a toggle), the Jam outputs (multi-choice), the equalizer/report/theme editor selectors (settings tools, not filters).
   - Radio has no single-choice row of ≤ 4 items, so it gets no blocks.
2. **Radio region:** `'${region.label} ▾'` becomes `region.label`; the `SectionHeader` action is already a button.
3. **Pushed list pages** (Podcast, Artisti seguiti, Tag, Playlist, Cronologia) keep their `AppBar` title. The «new header» applies to detail pages: the podcast detail and the tag page. Their empty states are already `EmptyState`, which 2.1 restyled.
4. **Podcast detail:** `_Header` (:155) becomes `CollectionHeader(cover: (s) => CoverImage(coverKey: podcast.coverKey, size: s, radius: CcDims.rGrid), name: podcast.title, subtitle: podcast.author, meta: …)`.
   - meta: «N episodi, aggiornato il …» from what `_Header` shows today.
   - No Riproduci/Casuale: there is no «play all episodes» today, and adding it would be a new function.
   - The auto-delete row stays under the header.
5. **Tag page:** `TagTracksScreen` becomes `CollectionScaffold(cover: null, name: name, meta: collectionMeta(l, tracks: …, durationMs: …), onPlay, onShuffle)` with the pills. `PlayCircleButton` leaves the tag page. It stays only in the player, the jam card and the desktop bar.
6. **Empty text in the middle of the page becomes `EmptyState`.**
   - Coda: `queue_sheet.dart:119` `l.emptyQueue`.
   - Jam: `jam_screen.dart:109` `l.jamWaitingEmpty` and :200 `l.jamEmpty`.
   - These empty states take no action.
7. **Pulizia:** the 56 intro icon of `duplicates_screen.dart:97-101` goes. The intro text stays, left aligned.
8. **Memoria** keeps its layout (title, cards, bars, sections). Only its texts change: `memory_screen.dart:143` `'$n · ${g.path}'` becomes `'$n, ${g.path}'`.
9. **Remaining ARB keys.** Task 2 rewrites every key still in `_separatorPending`, then deletes the set. At the time of writing these are expected to remain:
   - Jam: `jamSynced`, `jamPeople`;
   - activity: `activityScan`, `activityEnrich`, `activityDownload`, `activityTransfer`, `activityImport`, `activityImportPaused`, `activityDownloadRetry`;
   - import: `importNotificationPaused`, `csvImportSummary`, `csvImportBanner`, `csvImportBannerPaused`, `csvImportWanted`, `csvImportSyncCounts`;
   - others: `statsFirstValue`, `duplicatesSummary`, `tracksDeletedSome`, `suggestedSimilarTo`, `suggestionsRowNote`, `radioOfflineList`.

   Pattern (it): «Scansione: {done} di {total}», «Jam, {n} persone», «In pausa, {done} di {total}», «{title}, {date}». Keep `/` only where it is a count already written so elsewhere in the app; prefer «di».

## Review Focus

1. **Period switch.** Switching month/year on Statistiche still moves the period and keeps the arrows working, with «Riduci animazioni» on too. Test: Task 1, «stats blocks switch period».
2. **Da revisionare at 360 dp, 150 %.** The 5 chips wrap onto two lines with no horizontal scroll, and picking one still clears the selection. Test: Task 1, «review chips wrap and picking clears the selection».
3. **Rewritten plurals.** Every rewritten key keeps the same placeholders in all 6 languages, and gen-l10n output still formats. Test: Task 2, «placeholders unchanged» (in `arb_test.dart`).
4. **Podcast without author or cover.** The header shows only the name and the meta, with no empty line and no broken image. Test: Task 3, «podcast header without author or cover».
5. **Empty tag.** A tag whose tracks were all removed shows the header with the pills disabled and an `EmptyState`, with no exception. Test: Task 4, «empty tag page».

---

### Task 1: Blocks and wrapping chips

**Files:**
- Modify: `lib/ui/screens/stats/stats_screen.dart:70-90`
- Modify: `lib/ui/screens/library/all_tracks_screen.dart:160-185`
- Modify: `lib/ui/screens/library/review_screen.dart:165-180`
- Modify: `lib/ui/screens/releases/new_releases_screen.dart:150-205`
- Modify: `lib/ui/screens/radio/radio_sections.dart:161` (no «▾») and `:205-220` (genres wrap)
- Modify: `lib/ui/screens/import/import_detail_screen.dart:130-145`
- Test: `test/ui/stats_screen_test.dart`, `test/ui/review_screen_test.dart`, `test/ui/new_releases_screen_test.dart`, `test/ui/radio_screen_test.dart`, `test/ui/selection_lists_test.dart` (Tutti i brani sort), `test/ui/import_detail_screen_test.dart` if it exists

**Interfaces:**
- Consumes: `SegmentedBlocks<T>({required List<BlockItem<T>> items, required T selected, required ValueChanged<T> onChanged})` and `BlockItem<T>({required T value, required IconData icon, required String label})` from `lib/ui/widgets/segmented_blocks.dart` (2.2).
- Chip keys stay as they are (`genre-$tag`, …) so the old tests still find them.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('stats blocks switch period', (t) async {
  // reduced motion on (MediaQuery disableAnimations), StatsScreen
  expect(find.byType(SegmentedButton<bool>), findsNothing);
  await t.tap(find.text('Anno')); await t.pump();
  // the period label is the current year; tap «precedente»: previous year
});
testWidgets('review chips wrap and picking clears the selection', (t) async {
  // 360x780, textScaler 1.5, ReviewScreen with one selected row
  expect(find.ancestor(of: find.byType(ChoiceChip).first, matching: find.byType(Wrap)), findsOneWidget);
  final rows = {for (final e in find.byType(ChoiceChip).evaluate()) t.getTopLeft(find.byWidget(e.widget)).dy};
  expect(rows.length, greaterThan(1));
  // tap the second chip: selection is empty
});
testWidgets('all tracks sort is a block row', ...) // SegmentedBlocks<SortOption> with 4 items; tap «Artista»: query.sort == artist
testWidgets('new releases artists wrap', ...)     // no horizontal ListView around the artist chips
testWidgets('radio genres wrap, region without arrow', ...) // genre chips in a Wrap; find.textContaining('▾') finds nothing
```

- [ ] **Step 2: Run the five test files.** Expected: FAIL.
- [ ] **Step 3: Implement** as in Decisions 1–2. Statistiche stats period and sort keep their existing setters (`_setYear`, `_query.update`).
- [ ] **Step 4: Run the test files of this task and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): blocchi e chip a capo nelle altre schermate`.

---

### Task 2: The last «·» and «→»

**Files:**
- Modify: the 6 ARBs (the keys of Decision 9, plus any other key still in `_separatorPending`), then `flutter gen-l10n`
- Modify: `test/l10n/arb_test.dart` (delete `_separatorPending`; the test now checks every key)
- Create: `test/ui/no_separator_literals_test.dart`
- Modify (code joins `' · '` → `', '`), whatever is still there after 2.1–2.5:
  - `stats/stats_screen.dart:225,262,272`
  - `settings/advanced_section.dart:31` (`'$title, ${…}%'`)
  - `settings/theme_editor_screen.dart:216`
  - `online/online_song_row.dart:163,270`, `online/album_card.dart:54`, `youtube/online_results_sections.dart:169`
  - `online/discography_screen.dart:35`, `online/artist_songs_screen.dart:36` (title `'${artist.name}, $title'`)
  - `releases/new_releases_screen.dart:217,229`
  - `share/send_tab.dart:191`
  - `import/import_review_screen.dart:141-142`, `import/import_plan_screen.dart:47-87`, `import/import_manual_search_sheet.dart:136`, `import/import_detail_screen.dart:112,226`
  - `podcast/podcasts_screen.dart:36,124,130`, `podcast/podcast_detail_screen.dart:304`
  - `jam/jam_screen.dart:245`, `memory/memory_screen.dart:143`
  - `search/search_screen.dart:416` if 2.4 left it
- Test: `test/l10n/arb_test.dart`, `test/ui/no_separator_literals_test.dart`, then the screen tests whose old assertions contain «·» (`grep -rln '·' test/ui`)

**Interfaces:**
- `no_separator_literals_test.dart`, pure Dart, no widgets:
  ```dart
  test('no separator dot in UI string literals', () {
    // every lib/**/*.dart file except lib/l10n/: on lines that are not comments (trimmed line starts with '//'),
    // no match of RegExp(r"""['"][^'"\n]*\s·\s[^'"\n]*['"]""")
  });
  ```
- `arb_test.dart` gains `test('placeholders unchanged', …)`: for each key of Decision 9, the set of `{name}` placeholders in each language equals the one in `app_it.arb`. If the file already has a placeholder-parity test, extend it instead of adding one.

- [ ] **Step 1: Write the failing tests** (the two above, plus the ARB test with the set deleted).
- [ ] **Step 2: Run `flutter test test/l10n/arb_test.dart test/ui/no_separator_literals_test.dart`.** Expected: FAIL, listing the keys and lines still to fix.
- [ ] **Step 3: Rewrite** the ARB values in the 6 languages and the code joins; run `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test test/l10n/arb_test.dart test/ui/no_separator_literals_test.dart` plus every test file that `grep -rln -E '·|→' test/ui` lists, and `flutter analyze`. Expected: PASS. Update old assertions that expected «·».
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): via gli ultimi punti e frecce dai testi`.

---

### Task 3: Podcast and Memoria

**Files:**
- Modify: `lib/ui/screens/podcast/podcast_detail_screen.dart:155-215` (`_Header` → `CollectionHeader`)
- Modify: `lib/ui/screens/podcast/podcasts_screen.dart:112-135` (`_PodcastTile`: cover `CoverImage` 56 radius `CcDims.rGrid`, title `titleSmall`, second line `bodySmall` `textMuted`, already without «·» after Task 2)
- Modify: `lib/ui/screens/memory/memory_screen.dart` only if Task 2 left something (Decision 8)
- Test: `test/ui/podcast_screens_test.dart`, `test/ui/memory_layout_test.dart`

**Interfaces:**
- Consumes: `CollectionHeader({Widget Function(double size)? cover, required String name, String? subtitle, String? meta, List<Widget> actions = const []})` (2.4), `collectionMeta` (2.1) where its parts fit; the podcast meta reuses the keys `_Header` shows today (episode count, the `when` line) joined with `', '`; no new key unless one is missing.
- `CoverImage` already draws the placeholder when `coverKey` is null.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('podcast detail uses the collection header', (t) async {
  expect(find.byKey(const ValueKey('collection-name')), findsOneWidget);
  expect(find.text(podcast.title), findsWidgets);
  // the auto-delete dropdown is still below the header
});
testWidgets('podcast header without author or cover', (t) async {
  // podcast with author null, coverKey null
  // no exception; no empty Text under the name; the cover placeholder is shown
});
```

- [ ] **Step 2: Run `flutter test test/ui/podcast_screens_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement** Decision 4 and the `_PodcastTile` rows.
- [ ] **Step 4: Run `flutter test test/ui/podcast_screens_test.dart test/ui/memory_layout_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): Podcast e Memoria con la nuova intestazione`.

---

### Task 4: Jam, Coda, tag page and Pulizia

**Files:**
- Modify: `lib/ui/screens/jam/jam_screen.dart:109,200` (`EmptyState`)
- Modify: `lib/ui/screens/now_playing/queue_sheet.dart:119` (`EmptyState`)
- Modify: `lib/ui/screens/tags/tags_screen.dart:67-130` (`TagTracksScreen` → `CollectionScaffold`)
- Modify: `lib/ui/screens/cleanup/duplicates_screen.dart:97-101` (intro icon removed)
- Test: `test/ui/jam_screen_test.dart`, `test/ui/queue_reorder_test.dart`, `test/ui/tags_test.dart`, `test/ui/duplicates_screen_test.dart`

**Interfaces:**
- Consumes: `CollectionScaffold({…, Widget Function(double)? cover, required String name, String? meta, VoidCallback? onPlay, VoidCallback? onShuffle, …})` with the arguments the favourites page passes (`favorites_screen.dart:57`), `EmptyState({required IconData icon, required String message, …})` (2.1).
- Tag page: `ctrl.playAll(tracks, context: ctx)` for Riproduci and the shuffle the other collections use for Casuale; `SelectableAppBar` behaviour (selection bar) via `CollectionScaffold.selectionBar`, as in Preferiti.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('tag page has the collection header and pills', (t) async {
  expect(find.byType(PlayCircleButton), findsNothing);
  expect(find.widgetWithText(FilledButton, 'Riproduci'), findsOneWidget);
  expect(find.byKey(const ValueKey('collection-cover')), findsNothing);
});
testWidgets('empty tag page', ...)          // tag with no tracks: Riproduci disabled (onPressed null), EmptyState shown, no exception
testWidgets('empty queue shows EmptyState', ...) // QueueSheet with no items: find.byType(EmptyState) findsOneWidget
testWidgets('jam without tracks shows EmptyState', ...)
testWidgets('duplicates intro has no big icon', ...) // no Icon with size 56 on the intro
```

- [ ] **Step 2: Run the four test files.** Expected: FAIL.
- [ ] **Step 3: Implement** Decisions 5–7. The empty tag page `EmptyState` uses `l.tagsEmpty` if it fits, otherwise an existing «nessun brano» key; no new key if one exists.
- [ ] **Step 4: Run the four test files and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): Jam, Coda, pagina del tag e Pulizia`.

---

### Task 5: Final theme check at 150 % text

**Files:**
- Create: `test/ui/anello_text_scale_test.dart`

**Interfaces:**
- Consumes: the overrides each screen's own test already uses (copy them; do not invent providers).
- Matrix: screens × themes × one size.
  - Screens: `StatsScreen`, `ReviewScreen`, `NewReleasesScreen`, `PodcastsScreen`, `PodcastDetailScreen`, `MemoryScreen`, `TagTracksScreen`, `QueueSheet`, `JamScreen`, `AllTracksScreen`, `SettingsScreen()`.
  - Themes: Notte + viola, OLED + ambra, Chiaro + rosa.
  - Size: 360×780, `TextScaler.linear(1.5)`.

- [ ] **Step 1: Write the test.**

```dart
for (final (theme, accent) in [('notte', 'viola'), ('oled', 'ambra'), ('chiaro', 'rosa')]) {
  for (final (name, screen, overrides) in _screens) {
    testWidgets('$name at 150 % in $theme/$accent', (t) async {
      // pump inside the app theme for (theme, accent), 360x780, textScaler 1.5
      expect(t.takeException(), isNull); // no RenderFlex overflow
      // every SegmentedBlocks on screen: each block's label is fully inside the screen width
    });
  }
}
```

- [ ] **Step 2: Run `flutter test test/ui/anello_text_scale_test.dart`.** Expected: PASS, or overflows listed.
- [ ] **Step 3: Fix every overflow** at its source (ellipsis, `Flexible`, the 2×2 fallback of `SegmentedBlocks`). Do not loosen the test.
- [ ] **Step 4: Run the test again, plus the test files of the screens you fixed, and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `test(anello): tutte le schermate a testo 150% nei tre temi`.

---

### Task 6: Goldens and device check

**Files:**
- Modify: the golden images that change (expected `*_selection.png`, `*_jam.png`)
- Modify: `docs/PROGRESS.md` (the «Anello fase 2.6» tick, and the fase 2 closed)

- [ ] **Step 1: Regenerate:** `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart`. Look at every changed image. Any change outside the expected screens is a regression to fix first.
- [ ] **Step 2: Device check (controller).**
  - **Mi A3** (debug APK; never turn the screen off):
    - Statistiche, Da revisionare, Nuove uscite, Radio, Tutti i brani;
    - Podcast and its detail, Memoria, Jam, Coda, a tag, Duplicati;
    - 150 % text, Notte/OLED/Chiaro with viola, ambra and rosa, «Riduci animazioni» on.
  - **Linux (Xephyr):** the same screens at 1280 and below 840, keyboard focus on blocks and chips.
- [ ] **Step 3: Tick 2.6 in `docs/PROGRESS.md` and commit** (controller). Message: `docs(anello): fase 2.6 provata, fase 2 chiusa`.
