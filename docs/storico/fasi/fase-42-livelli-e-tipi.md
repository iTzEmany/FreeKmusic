# Fase 42 — Livelli e tipi (refactor «ui-fluida»)

**Obiettivo:** rendere vera la regola dei livelli di `docs/02-architettura.md` (ui → providers → services/data → core) e
un test la fa rispettare; sostituire stringhe e biforcazioni con tipi. Percorso strangler come nella fase 41 (D-24).

**Prerequisiti:** fase 41 chiusa (`showMsg`, `promptName`, `CcAppBar`, `AsyncBody`). Test C della fase 38
(`architecture_test` con lista di eccezioni piena).

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

## Cambi di comportamento voluti
- Sparisce l'import dal vecchio DB Python (F-04, D-04). Il vecchio schema non c'è più sul PC né sui telefoni.
- Il flusso «aggiungi cartella» dall'onboarding avvia la scansione (D-12).
- Libreria: Podcast, Radio e Tag sempre visibili anche vuote; prima erano nascoste a zero e Podcast/Tag diventavano irraggiungibili (D-51). Indietro: togliere `keepWhenZero`.

## Comportamento invariato
Tutto il resto. Golden identici. `lib/data`: **solo aggiunte** (`setLyrics` già esiste, `pathsById`; nessun cambio di
tabella o di firma esistente). `kind` è un getter calcolato dall'id, lo schema non cambia. Servizi, Jam, l10n invariati
tranne le stringhe ARB dell'importer, che si tolgono (D-04).

## Test in locale
Solo i toccati. `integration_test` gira prima di 42.1 e dopo 42.11 (gruppo C della «Rete»), via `sorveglia.sh --pesante`.
`dart run build_runner build --delete-conflicting-outputs` solo se cambiano provider generati.

## Task

### 42.1 — F-02 + F-03: `TrackOps` e lista di eccezioni
1. a) `lib/providers/track_ops.dart`: provider con le azioni sui brani (in blocco, preferiti, tag, `setLyrics`); in più `FolderRepository.pathsById`. Test contro DB in memoria (azioni su più brani, preferiti, `setLyrics`, `pathsById`), scritti prima in 38.5 come caratterizzazione.
2. b) Migrare per gruppi di `screens/` i 58 file che importano `app_database.dart` per i repository e le query drift nei widget (`lyrics_view.dart:107-113`, `export_dialog.dart:113-124,148-150`, `now_playing_cards.dart:176`, `tag_backups_screen.dart:43`, `bulk_actions.dart:64,85,106`, `tags_sheet.dart:74`). I tipi drift (`Track`, …) restano importabili.
3. c) A ogni gruppo si toglie dalla lista di eccezioni di `test/ui/architecture_test.dart` ogni file migrato. A lista vuota il test fallisce se in `lib/ui` compare `databaseProvider` o `RepositoryProvider`.

**Fatto quando:** `flutter test test/ui/architecture_test.dart test/providers/track_ops_test.dart` verde con **lista di eccezioni vuota**; `grep -rnE "databaseProvider|RepositoryProvider" lib/ui | wc -l` = 0.

### 42.2 — F-08: selezione unica
`add_tracks_screen.dart:25`, `track_picker_screen.dart:22`, `receive_tab.dart:36`: da `Set<int>` locali a `selectionProvider`. «Seleziona tutto» si comporta come nelle altre.

**Fatto quando:** `flutter test test/ui/selection_characterization_test.dart test/ui/selection_test.dart` verde (aggiornato dove «seleziona tutto» diventa uguale ovunque, scritto nel commit); `grep -rn "Set<int> _selected" lib/ui` vuoto.

### 42.3 — F-10: `SelectionKey`
Le chiavi nude (`'online'`, `'hidden'`, `'review'`, …) diventano `enum SelectionKey`.

**Fatto quando:** `flutter test test/ui/selection_test.dart` verde; `grep -rnE "selectionProvider\(?'" lib/ui` vuoto; `flutter analyze` pulito.

### 42.4 — F-09: `OnlineSelectionScope`
Un solo cablaggio per `online_page_frame.dart:119-133`, `online_results.dart:191-193`, `online_results_sections.dart:165`.

**Fatto quando:** `flutter test test/ui/online_selection_test.dart` verde; le tre righe di cablaggio ripetuto sono sparite (`git diff --stat` in negativo sui tre file).

### 42.5 — F-11: un enum per menu
I 10 `PopupMenuButton<String>` (9 coperti dai test C) e 23 `case '...'` passano a un enum per menu, come `TrackAction`.

**Fatto quando:** `flutter test test/ui/menus_characterization_test.dart` verde; `grep -rn "PopupMenuButton<String>" lib/ui | wc -l` = 0.

### 42.6 — F-16: `track.kind`
Getter `kind` (locale, online, radio, episodio…) calcolato dall'id, in `lib/ui` o in un'estensione senza toccare lo schema. Sostituisce `isOnlineId(track.id)` in `track_actions.dart:66,107,143`, `online_queue_row.dart:60,118`, `track_row.dart:486`, `memory_screen.dart:457`.

**Fatto quando:** `flutter test test/ui/track_kind_test.dart test/ui/track_actions_test.dart` verde (tabella id→kind come in 38.5); `grep -rn "isOnlineId(" lib/ui | wc -l` = 0.

### 42.7 — F-15: `curiosityProvider`
La logica di `now_playing_cards.dart:170-215` (pulizia della query, limite di richieste, scrittura nel DB) in un `AsyncNotifier`. Test del notifier senza widget; la card mostra solo lo stato.

**Fatto quando:** `flutter test test/providers/curiosity_provider_test.dart test/ui/now_playing_test.dart` verde; nessun `setState` per la curiosità in `now_playing_cards.dart`. `receive_tab` (13 setState), `search_screen` (9), `import_preview_dialog` (8) si alleggeriscono solo dove il passo li tocca già.

### 42.8 — F-05: build enormi
Widget privati per sezione (stesso file o `parts/`) per i 14 `build` oltre 150 righe, a partire da `library_screen.dart:86` (271), `desktop_sidebar.dart:26`, `app_shell.dart:98`, `playlist_detail_screen.dart:83`, `review_screen.dart:131`, `now_playing_screen.dart:226`, `jam_screen.dart:68`. Un file per commit.

**Fatto quando:** `python3 scripts/build_len.py lib/ui` mostra 0 `build` oltre 150 e nessuno oltre 120 (soglia della «Rete»); golden identici (`flutter test test/golden`).

### 42.9 — F-07 (D-12): `addFolderAndScan`
Flusso unico in un servizio, usato da `onboarding_pages.dart:93-103` e `folders_sheet.dart:22-33`. **L'onboarding ora avvia la scansione.**

**Fatto quando:** `flutter test test/ui/folders_onboarding_characterization_test.dart test/ui/onboarding_test.dart` verde (il test che fissava «niente scansione» è invertito nello stesso commit); `grep -rn "addFolder" lib/ui | wc -l` = 1 chiamata al servizio per schermata.

### 42.10 — F-04 (D-04): via l'importer Python
Si tolgono il pulsante in `settings_pages.dart:436`, `_importOld`, `lib/services/migration/python_db_importer.dart`, i suoi test e le stringhe ARB in it/en/de/es. `git revert` basta per tornare indietro.

**Fatto quando:** `grep -rniE "python_db_importer|_importOld" lib test` vuoto; `flutter gen-l10n` e `flutter analyze` puliti; `flutter test test/ui/settings_test.dart` verde.

### 42.11 — Chiusura della fase
`integration_test` e metriche.

**Fatto quando:** `flutter test integration_test -d linux` verde (via `sorveglia.sh`); `databaseProvider|RepositoryProvider` = 0, build ≤ 120 righe; `docs/refactor/ui-fluida/misure.md` aggiornato.

## Dalla review della fase 41 (D-50, punto 7)
Da fare dentro i task che toccano già quei file:
- **42.1:** un «crea playlist» e un «crea tag» unici (oggi 9 chiamate `promptName` + `create` in playlists_screen, playlist_dialogs, desktop_sidebar, playlist_picker, library_screen, tags_screen, tags_sheet); il log degli errori di caricamento dove nasce l'errore, non in `loadErrorState` dentro `build`.
- **42.5 / 42.8:** le scelte ancora in `SimpleDialog` passano a `showCcSheet` (lingua in settings_pages, playlist in exportify_sync_screen, colore in tags_sheet).
- **42.8:** se le schermate si spezzano, una variante sliver di `AsyncBody` per radio_sections e gli usi diretti di `loadErrorState` (album_detail, favorites, artist).
