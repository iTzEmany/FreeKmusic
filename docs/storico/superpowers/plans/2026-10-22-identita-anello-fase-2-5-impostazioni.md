# Anello fase 2.5, Impostazioni: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The single endless settings page becomes an index of 7 entries, each with its current value under the name. On the phone every entry opens its page; on desktop the index sits on the left and the page on the right.

**Architecture:**
- `settings_screen.dart` (465 lines) is split by responsibility:
  - `settings_pages.dart` holds today's groups, moved without changes, one builder per page;
  - `settings_summaries.dart` holds the line under each index entry;
  - `settings_screen.dart` keeps `SettingsScreen` and the index/two-column layout, plus the dialogs it already has.
- `SettingsScreen({SettingsPage? initial})` keeps a no-argument form, so the Home entry (`home_screen.dart:52-57`) works without edits.
- Every option, its order and its group stay as today (Obiettivo 7).

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, gen-l10n. No new packages.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-fase-2-design.md`. Read Obiettivo 7, «Impostazioni (`settings_screen.dart`)» (the table of 7 entries), Vincoli (desktop 760, active entry `surface2` + bold, keyboard focus). The mockup `…-fase-2.html` is next to it.

## Global Constraints

- **Strict symmetry (user, 22/10).** Every row with content on both sides uses equal-width side slots (`Expanded` sides or the same fixed width), so its middle never moves when a side changes width. A test measures the centre (±1 px) wherever a row has a centred element. No HTML mockups: Jam, the import window / activity log and the Settings pages are redesigned directly in code under this rule.
- **No new packages, fonts or colours.** Only `CcColors` via `context.cc`, `CcDims`, `Motion`/`CcMotion` and `ccDuration`.
- **ARB edits.** They go in all 6 ARBs (it, en, de, es, fr, pt), then run `flutter gen-l10n`.
  - fr and pt use the typographic apostrophe ’.
  - Only one agent at a time touches the ARBs.
  - Every key this plan cleans of «→» leaves `_separatorPending` in `test/l10n/arb_test.dart` (2.3).
- **Copy:** no «A · B», no «→», no ALL CAPS. Summaries join parts with `, `.
- **Error handling:** no silent `catch (_) {}`. Log with `AppLog`.
- **UI thread:** summaries read providers that are already loaded; no new query, no file I/O to build them.
- **Motion:** only opacity and transform. The desktop page switches with `TabFade`; phone pages open with the usual route. «Riduci animazioni» via `ccDuration`.
- **No option added, removed or reordered.** Conditional groups stay conditional (`kEnableYoutube`, `equalizerProvider`, `lyricsTranslatorProvider`, trusted devices, missing tracks).
- **Tests.**
  - One test per behaviour.
  - Locally run only the touched files.
  - `flutter analyze` must be clean.
- **Goldens:** regenerate `*_settings.png` (Task 4).
- **Commits:** the controller commits, with explicit paths. Never commit `.claude/hooks/guard.sh` or `.claude/settings.json`. Do not touch `lib/ui/screens/home/`.
- **Last task:** device check plus the tick in `docs/PROGRESS.md`. The controller runs the devices.

## Decisions made while planning

1. **Pages and their groups** (today's order inside each page):

   | `SettingsPage` | Title (it) | Groups |
   |---|---|---|
   | `appearance` | Aspetto e lingua | Aspetto, Lingua |
   | `playback` | Riproduzione | Riproduzione |
   | `library` | Libreria | Libreria, Pulizia |
   | `online` | Online e download | Online, Nuove uscite, Download, Modelli di traduzione |
   | `network` | Rete e dispositivi | Rete locale, Dispositivi fidati |
   | `backup` | Backup | Backup |
   | `advanced` | Avanzate e info | Avanzate, Info |

   A page with one visible group shows no group title. The index always shows the 7 entries; a page never ends up empty, because each has at least one unconditional group.
2. **Summaries, from data that exists today:**
   - appearance: theme name (built-in label or the custom theme's name), `accentLabel`, language name from `_languages`; e.g. «Notte, viola, Italiano»;
   - playback: the transition label (the local `label(m)` of `transition_settings_tiles.dart` made a top-level `transitionLabel(l, m)`), `crossfadeSeconds` when the mode uses it, and «normalizzazione accesa» when `normalizeVolume`;
   - library: folders count and tracks count, «2 cartelle, 2.041 brani»;
   - online: `downloadFormatLabel` when YouTube is on, otherwise online on/off. Gap: there is no «solo Wi‑Fi» download setting, so the spec's example cannot be shown;
   - network: the trusted devices count, or the device name when there are none;
   - backup: a fixed hint «Esporta e ripristina la libreria». Gap: no last-backup time is stored, and adding it would be a new function;
   - advanced: `appVersion(kAppVersion)`.
3. **Phone** (`width < CcDims.wideBreakpoint`): the index is a `ListView` of one `surface1` card (`rCard`) with 7 `ListTile`s (title `titleSmall`, summary `bodySmall` `textMuted`, chevron). A tap does `ShellNav.open(Scaffold(appBar: AppBar(title: Text(title)), body: SettingsPageView(page)))`.
4. **Desktop** (≥ 840): `Row` with the index (width 280) and the page (`ConstrainedBox(maxWidth: 760)`), the selected entry in local state. Active entry: `tileColor: cc.surface2`, title `FontWeight.w700`, no dot. `initial` selects the entry; without it `appearance`.
5. **Shortcuts:** today nothing opens a precise point of the settings; only texts point there. So:
   - the texts lose «→» and name the new pages: `historyOff` «…attivala in Impostazioni, Riproduzione.»; `ytErrToolOutdated` «…(Impostazioni, Online e download, Aggiorna)…»; `writeTagsWarnBody` was done in 2.3;
   - the history-off empty state gets `EmptyState(actionLabel: l.openPlaybackSettings, onAction: …SettingsScreen(initial: SettingsPage.playback))`, the one place where a text sends the user to a page and a button fits (Obiettivo 9: at most one filled button). Ruling: navigation, not a new function.

## Review Focus

1. **YouTube disabled (`kEnableYoutube` false) or no translator.** «Online e download» still opens and shows only Online; no empty group title. Test: Task 1, «online page without YouTube shows one group, no title».
2. **No trusted devices.** «Rete e dispositivi» shows only Rete locale without a title, and the summary falls back to the device name. Test: Task 1, «network page without trusted devices».
3. **Window resized across 840 while a page is open.** The desktop selection survives going narrow and back; no exception. Test: Task 2, «resize across the breakpoint keeps the page».
4. **150 % text on 360 dp.** Long summaries (a custom theme name, German labels) ellipsize at 1 line; the chevron stays visible. Test: Task 1, «index at 150 % with long summary».
5. **Keyboard on desktop.** Tab reaches every index entry with a visible focus, and Enter selects it. Test: Task 2, «index entries take keyboard focus».

---

### Task 1: Index and pages on the phone

**Files:**
- Create: `lib/ui/screens/settings/settings_pages.dart` (move today's groups from `settings_screen.dart:69-290`, `_trustedGroup` :431, `_Group` :437 renamed `SettingsGroup`)
- Create: `lib/ui/screens/settings/settings_summaries.dart`
- Modify: `lib/ui/screens/settings/settings_screen.dart`
- Modify: `lib/ui/screens/settings/transition_settings_tiles.dart:17` (lift `label(m)` to `String transitionLabel(AppLocalizations l, TransitionMode m)`)
- Modify: the 6 ARBs (7 page titles, the summary templates)
- Test: `test/ui/settings_index_test.dart` (new); update `test/ui/settings_and_playlists_test.dart`, `test/ui/trusted_devices_settings_test.dart`, `test/ui/language_picker_test.dart`, `test/ui/large_text_test.dart`, `test/ui/update_check_test.dart` to pump `SettingsScreen(initial: …)` or tap the entry first

**Interfaces:**
- Produces:
  ```dart
  enum SettingsPage { appearance, playback, library, online, network, backup, advanced }
  String settingsPageTitle(AppLocalizations l, SettingsPage p);
  class SettingsScreen extends ConsumerWidget { const SettingsScreen({super.key, this.initial}); final SettingsPage? initial; }
  class SettingsPageView extends ConsumerWidget { const SettingsPageView(this.page, {super.key}); final SettingsPage page; }
  class SettingsGroup extends StatelessWidget { const SettingsGroup({super.key, this.title, required this.children}); final String? title; final List<Widget> children; }
  String settingsSummary(BuildContext context, WidgetRef ref, SettingsPage p); // in settings_summaries.dart
  ```
- `SettingsPageView` builds the page's groups into a `ListView` with `maxWidth: 760`; it drops `title` when only one group is visible.
- On the phone, `initial` != null opens straight on that page (`SettingsPageView` with no index).
- New ARB keys (it): `settingsPageAppearance` «Aspetto e lingua», `settingsPagePlayback` «Riproduzione», `settingsPageLibrary` «Libreria», `settingsPageOnline` «Online e download», `settingsPageNetwork` «Rete e dispositivi», `settingsPageBackup` «Backup», `settingsPageAdvanced` «Avanzate e info», `summaryLibrary` «{folders, plural, =1{1 cartella} other{{folders} cartelle}}, {tracks, plural, =1{1 brano} other{{tracks} brani}}», `summaryTrusted` «{count, plural, =1{1 dispositivo fidato} other{{count} dispositivi fidati}}», `summaryNormalizeOn` «normalizzazione accesa», `summaryBackup` «Esporta e ripristina la libreria», `summaryCrossfade` «{seconds} s». Reuse an existing key wherever the same word exists.

- [ ] **Step 1: Write the failing tests** in `settings_index_test.dart`.

```dart
testWidgets('phone index shows 7 entries with summaries', (t) async {
  // 400x800, SettingsScreen()
  for (final s in ['Aspetto e lingua', 'Riproduzione', 'Libreria', 'Online e download', 'Rete e dispositivi', 'Backup', 'Avanzate e info']) {
    expect(find.text(s), findsOneWidget);
  }
  expect(find.textContaining('Notte'), findsOneWidget);
  expect(find.text('Dissolvenza'), findsNothing); // tiles are on the pages, not the index
});
testWidgets('entry opens its page with the same tiles in order', ...) // tap «Riproduzione»: the tiles of today's group in the same order; no group title
testWidgets('online page without YouTube shows one group, no title', ...) // kEnableYoutube off or override: only Online tiles, no titleMedium header
testWidgets('network page without trusted devices', ...) // summary is the device name; one group, no title
testWidgets('index at 150 % with long summary', ...) // 360x780, textScaler 1.5, custom theme 'Un tema dal nome molto lungo…': no exception, summary maxLines 1
```

- [ ] **Step 2: Run `flutter test test/ui/settings_index_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Move the groups first (no behaviour change), then the index and summaries; edit the 6 ARBs and run `flutter gen-l10n`.
- [ ] **Step 4: Run `flutter test test/ui/settings_index_test.dart test/ui/settings_and_playlists_test.dart test/ui/trusted_devices_settings_test.dart test/ui/language_picker_test.dart test/ui/large_text_test.dart test/ui/update_check_test.dart test/ui/transition_settings_test.dart test/ui/advanced_settings_test.dart test/ui/release_settings_tiles_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): Impostazioni in un indice di 7 pagine`.

---

### Task 2: Two columns on desktop

**Files:**
- Modify: `lib/ui/screens/settings/settings_screen.dart`
- Test: `test/ui/settings_index_test.dart`

**Interfaces:**
- Consumes: `SettingsPage`, `SettingsPageView`, `settingsSummary` (Task 1).
- `SettingsScreen` becomes a `ConsumerStatefulWidget` holding `SettingsPage _page = widget.initial ?? SettingsPage.appearance`.
- Wide layout: `Row(children: [SizedBox(width: 280, child: index), Expanded(child: Align(topLeft, child: TabFade(key: ValueKey(_page), child: SettingsPageView(_page))))])`.
- Index entry: `ListTile(selected: p == _page, selectedTileColor: cc.surface2, title: Text(..., style: w700 when selected), subtitle: summary, onTap: () => setState(...))`. `ListTile` already takes focus and shows it; keep `focusColor` from the theme.

- [ ] **Step 1: Write the failing tests.**

```dart
testWidgets('desktop shows index and page side by side', (t) async {
  // 1280x800: «Aspetto e lingua» selected, the theme tiles visible at the same time as the index
  final index = t.getRect(find.text('Backup').first); final tile = t.getRect(find.text('Tema'));
  expect(tile.left, greaterThanOrEqualTo(index.left + 280));
  await t.tap(find.text('Backup')); await t.pumpAndSettle();
  // the backup tiles are shown; the Backup ListTile has selected == true
});
testWidgets('resize across the breakpoint keeps the page', ...) // select Backup at 1280, resize to 400 then back to 1280: Backup still selected, no exception
testWidgets('index entries take keyboard focus', ...) // sendKeyEvent(tab) n times: a ListTile of the index has focus; enter selects it
```

- [ ] **Step 2: Run `flutter test test/ui/settings_index_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run `flutter test test/ui/settings_index_test.dart test/ui/large_text_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): Impostazioni su due colonne nel desktop`.

---

### Task 3: Shortcuts to the pages and texts

**Files:**
- Modify: `lib/ui/screens/history/history_screen.dart:117` (the `EmptyState` gets the action when history is off)
- Modify: the 6 ARBs: `historyOff`, `ytErrToolOutdated`; new `openPlaybackSettings` «Apri Riproduzione»
- Modify: `test/l10n/arb_test.dart` (remove `historyOff`, `ytErrToolOutdated` from `_separatorPending`)
- Test: `test/ui/history_screen_test.dart`, `test/l10n/arb_test.dart`

**Interfaces:**
- Consumes: `SettingsScreen({SettingsPage? initial})` (Task 1), `EmptyState(... actionLabel, onAction)` (2.1).
- The action opens `ShellNav.open(context, Scaffold(appBar: AppBar(title: Text(l.navSettings)), body: const SettingsScreen(initial: SettingsPage.playback)))`, the same frame the Home uses.

- [ ] **Step 1: Write the failing test.**

```dart
testWidgets('history off: button opens the playback page', (t) async {
  // recordHistory false
  await t.tap(find.widgetWithText(FilledButton, 'Apri Riproduzione')); await t.pumpAndSettle();
  expect(find.byType(SettingsPageView), findsOneWidget);
  // the record-history switch is visible
});
```

- [ ] **Step 2: Run `flutter test test/ui/history_screen_test.dart`.** Expected: FAIL.
- [ ] **Step 3: Implement**, rewrite the 2 values in the 6 ARBs, run `flutter gen-l10n`.
- [ ] **Step 4: Run `flutter test test/ui/history_screen_test.dart test/l10n/arb_test.dart` and `flutter analyze`.** Expected: PASS.
- [ ] **Step 5: Commit** (controller). Message: `feat(anello): le scorciatoie aprono la pagina giusta delle Impostazioni`.

---

### Task 4: Golden and device check

**Files:**
- Modify: `test/goldens/*_settings.png` (8 images: phone/desktop × 100/150 × dark/light as the test defines them)
- Modify: `docs/PROGRESS.md` (the «Anello fase 2.5» tick)

- [ ] **Step 1: Regenerate:** `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 15 build/goldens.log -- flutter test --update-goldens test/goldens/screens_golden_test.dart`. Look at every changed image: phone shows the index, desktop the index and «Aspetto e lingua». Only `*_settings.png` should change; any other diff is a regression to fix first.
- [ ] **Step 2: Device check (controller).**
  - **Mi A3** (debug APK; never turn the screen off): each of the 7 pages; the summaries change after changing theme, language, transition; history off button; 150 % text; Notte, OLED and Chiaro with viola, ambra and rosa.
  - **Linux (Xephyr):** two columns, keyboard Tab/Enter, resize across 840.
- [ ] **Step 3: Tick 2.5 in `docs/PROGRESS.md` and commit** (controller). Message: `docs(anello): fase 2.5 provata`.
