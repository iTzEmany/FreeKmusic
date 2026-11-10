# Anello 2.7 — Memoria e rifiniture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Memoria come il mockup approvato, titoli che non si spezzano a metà parola, un solo stile di selezione (blocco bianco), Tutti i brani con un'intestazione coerente con le raccolte.

**Architecture:** Tre task su file disgiunti, ognuno nel suo branch/worktree. Solo il Task 1 tocca gli ARB. Il Task 2 è puro tema + widget condiviso; il Task 3 tocca solo `all_tracks_screen.dart`.

**Tech Stack:** Flutter 3.47, Riverpod 3, `intl` (già in pubspec), token `context.cc`, `CcDims`, `SegmentedBlocks`, `LibraryShortcuts`.

**Spec:** `docs/superpowers/specs/2026-10-22-identita-anello-memoria.html` (mockup approvato dall'utente) e `docs/superpowers/specs/2026-10-22-identita-anello-design.md`.

## Global Constraints

- Nessun pacchetto nuovo. Testi UI in italiano dagli ARB (it template + en, de, es, fr, pt), poi `flutter gen-l10n`; i file generati si committano.
- Niente separatori «·» o «•» nei testi: virgola (vedi `test/ui/no_separator_literals_test.dart`).
- Nessun `catch (_) {}` muto: `AppLog`. Nessun I/O nel thread UI (i calcoli restano nei provider esistenti).
- Test con `flutter test -j 1 <file>`; solo i file toccati. `flutter analyze` pulito.
- Non usare `dart format` su file interi: indenta a mano solo le righe toccate.
- Commit con percorsi espliciti e trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Mai `git add -A`, mai `.claude/`, mai `scripts/__pycache__/`.
- A 150 % di testo e 360 px di larghezza niente overflow (matrice in `test/ui/anello_text_scale_test.dart`).

## Review Focus

1. Windows/Linux senza `DiskSpace` (`musicDiskSpaceProvider` → null): l'anello non deve inventare «Altro»/«Libero».
2. Libreria vuota (0 brani, 0 playlist): niente righe «0 B», niente anello rotto, niente divisione per zero nelle barre.
3. Inglese/tedesco: «1.5 GB» con punto, italiano «1,5 GB» con virgola, anche nelle altre schermate che usano `formatBytes`.
4. Titolo di raccolta di una sola parola lunghissima a 360 px e 150 %: si rimpicciolisce, non va a capo dentro la parola.
5. Chip selezionato in tema chiaro e scuro: etichetta leggibile (bg su text).

---

### Task 1: Memoria come il mockup

**Files:**
- Modify: `lib/ui/screens/memory/memory_screen.dart`, `memory_widgets.dart`, `memory_app_data.dart`
- Create: `lib/ui/screens/memory/memory_ring.dart` (anello + frase sotto + legenda)
- Modify: `lib/ui/widgets/format_utils.dart` (`formatBytes`) e i suoi chiamanti in `lib/` (9 file)
- Modify: 6 ARB + gen-l10n
- Test: `test/ui/memory_screen_test.dart` (esistente, estendere), `test/ui/anello_text_scale_test.dart`

**Interfaces:**
- Consumes: `memoryBreakdownProvider`, `appDataUsageProvider`, `musicDiskSpaceProvider`, `memoryActionsProvider.clearCaches()`, `missingTracksProvider`, `neverPlayedTracksProvider`, `SegmentedBlocks<T>`/`BlockItem<T>`, `LibraryShortcuts`/`LibraryShortcut` (blocchi con icona a sinistra), `folderLabels`.
- Produces: `String formatBytes(int bytes, [String? locale])` — virgola o punto secondo `locale` via `NumberFormat` di `intl` (una cifra decimale per MB/GB, «KB» intero). Tutti i chiamanti in `lib/` passano `Localizations.localeOf(context).toString()`.

Contenuto (dal mockup, valori esatti):
- **Anello**: l'anello aperto del logo (spazio di 40° in alto a destra, puntino sulla punta dell'arco musica). Arco musica `cc.accent`, arco «Altro» `cc.textMuted` (tenue), lo spazio libero è la traccia vuota `cc.surface2`. Al centro «38,4 GB» con lo stile display (Unbounded) e sotto «di musica». Sotto l'anello: `memoryDeviceLine` («11,2 GB liberi su 128 GB») e la legenda Musica/Altro/Libero (riusa quella di `DeviceBar`, poi elimina `DeviceBar` se non serve più). Senza `DiskSpace`: solo la traccia e l'arco musica pieno, nessuna legenda Altro/Libero, frase = `memoryUnavailable`. Semantics: una sola etichetta con musica, libero e totale.
- **Blocchi** `SegmentedBlocks` Playlist / Formati / Cartelle: cambiano solo la lista sotto. Righe: copertina o icona, nome, riga meta («214 brani, 14 ore»; formato: «1.204 brani»; cartella: nome, poi «N brani» e il percorso in piccolo `cc.textFaint`), barra sottile spenta (colore `cc.surface3` su traccia trasparente, alta 3, frazione rispetto alla riga più grande), dimensione a destra. Formati in maiuscolo solo per sigle (FLAC, MP3, M4A); «Opus» com'è nei dati va bene maiuscolo, non serve eccezione. La nota `memoryPlaylistsNote` resta sotto la lista Playlist.
- **I più pesanti**: titolo + link «Mostra tutti» a destra + blocchi Brani/Album. Mostra i primi 5; «Mostra tutti» espande sul posto ciò che `memoryBreakdownProvider` ha già (niente schermata nuova); il link sparisce se ce ne sono ≤ 5.
- **Mai ascoltati**: blocco con icona a sinistra, «412 brani, 9,6 GB», chevron → `NeverPlayedScreen`. Nascosto se 0 brani.
- **Strumenti** (rinomina `memoryTools` da «Pulizia» a «Strumenti», e nelle altre lingue): Duplicati e Non trovati come `LibraryShortcuts` (icona a sinistra). Non trovati: «3 brani» da `missingTracksProvider`. Duplicati: numero di gruppi solo se un risultato è già disponibile senza avviare la ricerca (hash); altrimenti nessuna riga meta.
- **Dati dell'app**: righe Copertine («2.204 immagini» se il conteggio è già nel calcolo di `appDataUsage`, altrimenti `memoryCoversThumbs`), Cache (somma dei tipi che `clearCaches` svuota davvero; meta «Immagini, ricerche, Jam»), Libreria (ex «Database»; meta «Il database con brani e ascolti»), Backup dei tag (meta «Prima di ogni modifica ai file»); gli altri tipi (podcast, radio, catalogo, suggeriti, registro) con le loro etichette. Righe sotto 1 MB non si mostrano; se almeno una è nascosta, la nota «I dati sotto 1 MB non sono elencati.» (il mockup diceva «Log e altri…», ma il registro può superare 1 MB: frase generica). Pulsante pillola «Svuota cache» (una riga, mai a capo) e sotto «Libera {size}. Brani, copertine e ascolti restano.»; **nessuna conferma** (il testo dice cosa non tocca). Snackbar e gestione errori esistenti restano. Pulsante disattivato se la cache è 0.
- **Desktop** (`width >= CcDims.wideBreakpoint`): colonna sinistra 330 px con anello, Mai ascoltati, Strumenti; a destra blocchi + lista, poi I più pesanti, poi Dati dell'app.
- Mai una riga «0 B». Numeri con `formatBytes(.., locale)` e conteggi con i plurali ARB esistenti (`tracksCount`, che già formattano «1.204»).

- [ ] **Step 1: test che falliscono** in `test/ui/memory_screen_test.dart`:
  - `formatBytes(1610612736, 'it') == '1,5 GB'` e `formatBytes(1610612736, 'en') == '1.5 GB'` (in `test/ui/format_utils_test.dart` se esiste, altrimenti nel file memoria).
  - ring hero: con DiskSpace finto (used 116,8 GB, free 11,2 GB, total 128 GB, musica 38,4 GB) si vede `'38,4 GB'` e `'11,2 GB liberi su 128 GB'`; con DiskSpace null si vede `memoryUnavailable` e nessun testo «Libero».
  - tocco sul blocco «Formati» → appare «FLAC», sparisce la riga della playlist.
  - righe app-data sotto 1 MB assenti, nota presente; nessun testo che finisce con `' 0 B'`.
  - «Svuota cache» chiama `clearCaches()` subito (nessun `AlertDialog`).
  - «Mostra tutti» con 7 brani pesanti: prima 5 righe, dopo il tocco 7.
- [ ] **Step 2:** `flutter test -j 1 test/ui/memory_screen_test.dart` → FAIL.
- [ ] **Step 3:** implementa; aggiungi Memoria (mobile 360 px, 150 %, dati finti con nomi lunghi) alla matrice di `anello_text_scale_test.dart`.
- [ ] **Step 4:** `flutter test -j 1 test/ui/memory_screen_test.dart test/ui/anello_text_scale_test.dart test/l10n/arb_test.dart test/ui/no_separator_literals_test.dart` e i test dei file che chiamano `formatBytes` (grep in `test/` per le schermate cleanup/online album) → PASS. `flutter analyze` pulito.
- [ ] **Step 5:** commit `feat(anello): Memoria come il mockup, byte con la virgola`.

### Task 2: titoli interi e un solo stile di selezione

**Files:**
- Modify: `lib/ui/widgets/collection_header.dart` (titolo)
- Modify: `lib/ui/theme/app_theme.dart` (`chipTheme`, più `segmentedButtonTheme` se manca)
- Test: `test/ui/collection_header_test.dart` (crea o estendi), `test/ui/theme_test.dart` o il file di test del tema esistente

**Interfaces:**
- Produces: nessuna API nuova. `CollectionHeader` mantiene costruttore e parametri.

- [ ] **Step 1: test che falliscono**
  - `long single word title shrinks instead of breaking`: `CollectionHeader(name: 'Supercalifragilistichespiralidoso', …)` a 360×800, `textScaler 1.0` e `1.5`: il `RenderParagraph` del titolo ha una sola riga (`computeLineMetrics().length == 1` o `didExceedMaxLines == false` con `maxLines: 1` per una parola) e il `fontSize` effettivo è minore di quello del tema.
  - `normal title keeps theme size`: «Corsa del sabato» → `fontSize` uguale a quello del tema.
  - `selected chip uses the white block`: `ChoiceChip(selected: true)` sotto `AppTheme` scuro e chiaro → colore di sfondo `cc.text`, colore etichetta `cc.bg`. Non selezionato: sfondo `cc.surface2`.
  - Se nell'app c'è un `SegmentedButton` (impostazioni, equalizzatore, editor del tema): selezionato `cc.text`/`cc.bg`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** titolo: misura con `TextPainter` la parola più lunga allo stile del tema; se non sta nella larghezza disponibile, scala il font fino a farla stare, minimo 0,7 del base; sotto il minimo `maxLines` invariato con ellissi (mai spezzare dentro la parola: `TextPainter` + `softWrap` sulle sole parole). Tema: `selectedColor: c.text`, `secondaryLabelStyle` con `c.bg`, `checkmarkColor: c.bg`; `segmentedButtonTheme` con selezionato `c.text`/`c.bg`, non selezionato `c.surface2`/`c.text`, senza bordo. Togli gli override locali che ora duplicano il tema (es. `settings_screen.dart:45` `selectedColor: cc.text`) solo se identici.
- [ ] **Step 4:** test sopra + `test/ui/anello_text_scale_test.dart` + i test delle schermate con chip (`grep -rln "ChoiceChip\|FilterChip" test/`) → PASS. I golden cambiano: NON rigenerarli, elenca nel report quali falliscono solo per pixel.
- [ ] **Step 5:** commit `fix(anello): titoli interi, chip selezionato come blocco bianco`.

### Task 3: Tutti i brani come una raccolta

**Files:**
- Modify: `lib/ui/screens/library/all_tracks_screen.dart`
- Test: `test/ui/all_tracks_screen_test.dart` (o il file che oggi la copre: `grep -rln AllTracksScreen test/`)

**Interfaces:**
- Consumes: lo stile del titolo di `CollectionHeader` (stesso `TextStyle`: `headlineSmall`, `displaySmall` da wide), `PlayPill`, `ShufflePill`, `SegmentedBlocks<SortOption>`.

L'intestazione resta **fuori** dalla lista scorrevole: `AlphaScroller` calcola gli offset come `index * itemExtent`, un header dentro la lista li sposterebbe.

- [ ] **Step 1: test che falliscono**: titolo «Tutti i brani» con lo stesso `TextStyle` del titolo di `CollectionHeader`; sotto, riga meta con `tracksAndDuration` (numero e durata totale dei brani filtrati); `PlayPill` e `ShufflePill` nello stesso `Wrap` sotto la meta; l'`AppBar` normale non ripete il titolo; in selezione `SelectableAppBar` invariata.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** ordine dall'alto: AppBar (solo indietro), titolo + meta allineati a sinistra con `CcDims.margin`, pillole Play/Casuale, campo di ricerca, blocchi d'ordinamento, lista. Il vecchio testo del conteggio sopra la lista sparisce (ora è la meta).
- [ ] **Step 4:** test del file + `test/ui/anello_text_scale_test.dart` + `test/ui/selection_lists_test.dart` → PASS.
- [ ] **Step 5:** commit `feat(anello): Tutti i brani con intestazione da raccolta`.
