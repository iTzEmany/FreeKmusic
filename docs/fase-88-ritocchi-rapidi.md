# Fase 88 — Ritocchi rapidi (refactor «superfici-e-ricerca»)

**Obiettivo:** correggere il confronto con la libreria dei suggeriti e sistemare piccoli difetti di Home, Tutti i brani, Ordina per e Cerca, senza toccare la struttura.

**Prerequisiti:** fase 87 chiusa (test di caratterizzazione e base di fluidità). Mockup `refactor/superfici-e-ricerca/mockup/home.html`, `tutti-i-brani.html`, `cerca.html`. Decisioni D-388, D-389, D-413 (solo la parte info/filtri; le etichette fonte sono fase 92), D-416. Area a rischio: `lib/services/import/track_matcher.dart` (usato da Shuffle+).

**Comando mirato:** `flutter test test/services/import/track_matcher_test.dart test/services/import/library_index_characterization_test.dart test/services/shuffle_plus/suggestion_pool_bayou_test.dart test/services/shuffle_plus/suggestion_pool_test.dart test/services/online/library_overlap_test.dart test/ui/home_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/search_screen_test.dart test/ui/online_results_test.dart test/ui/a11y_guidelines_test.dart` (percorsi di `suggestion_pool_test.dart` e `library_overlap_test.dart` da confermare con `ls`).

## Task

### 88.1 — Confronto con la libreria (F-88, D-389)
- `LibraryIndex.find` (`track_matcher.dart:114-127`, regex `:8-21`; `query_cleaner.dart:188`): a titolo e artista uguali il brano è **posseduto qualunque durata**; la durata (±5 s) conta solo nei confronti approssimati.
- Suffissi di edizione tagliati: anniversary, deluxe, expanded, version. «live» **no**: le versioni live restano distinte.
- Artista confrontato per insieme di parole normalizzate, non per il primo nome dello split.
- Ribaltare i test Bayou della 87 (ora trovato); riscrivere `suggestion_pool_test.dart` e `library_overlap_test.dart` sulla regola dei 5 s. Test nuovi: live distinto; «feat.» in ordine diverso; stesso titolo con artista diverso non posseduto.

### 88.2 — Home (F-79, F-101, D-388)
- Registro attività accanto a Impostazioni nell'intestazione (`home_screen.dart:43-56`, `activity_sheet.dart:83`): un tocco, non tre. Scorre con la Home.
- `ShuffleHero` (`home_blocks.dart:26-98`): titolo su due righe (via `FittedBox`), `maxLines` sul sottotitolo, 16 px (token di spaziatura) fra play e shuffle al posto di `SizedBox(width: 12)`.
- Il play fatto a mano (`home_blocks.dart:63-81`) diventa `PlayCircleButton` (`widgets/play_buttons.dart:8-43`). Test: Registro raggiungibile, etichette TalkBack, titolo a scala 2.0 senza overflow.

### 88.3 — Play tondo in Tutti i brani (F-99)
- `all_tracks_screen.dart:92-96`: `PlayCircleButton` al posto dell'`IconButton`. Test: il tocco riproduce l'elenco filtrato; bersaglio ≥ 48 dp.

### 88.4 — Nomi di «Ordina per» (F-80)
- ARB it/en/de/es (`app_it.arb:694,697`): «Ascoltati di recente» (ultimo ascolto) e «Aggiunti di recente» (data di aggiunta). Solo testi, `library_entries.dart:8` invariato. Test: le etichette del foglio.

### 88.5 — Cerca: info e filtri (F-84, F-85)
- Icona info accanto al titolo «Cerca» (`search_screen.dart:107-121`); via `_ActivityRowBar` (`online_results.dart:195,395-430`).
- `SourceFilterChips` (`online_results_sections.dart:23-61`, `segmented_blocks.dart:48`): solo testo, chip compatti, bersaglio ≥ 48 dp. Niente etichette fonte sui risultati (fase 92).
- Test: info apre la stessa spiegazione; filtri filtrano come prima; a11y e TalkBack.

### 88.5b — Debito dalla fase 87: database più nuovo nel ripristino
`RestoreService._checkStagedDatabase` apre il file con `AppDatabase`: drift esegue `onUpgrade` anche al ribasso e riscrive `user_version` a 15 prima del controllo, quindi un database in attesa con schema più nuovo **non** viene rifiutato (lo rifiuta solo il manifest, `inspectBackup`). Leggere `PRAGMA user_version` con sqlite3 prima di aprirlo con drift; ribaltare il test «GAP today» di `test/services/backup/legacy_backup_test.dart`. Area a rischio (backup e ripristino): `/code-review high`.

### 88.6 — Controlli di fase
`flutter analyze`; comando mirato; golden Home, Tutti i brani, Cerca rigenerati con `scripts/shots.sh`; review del diff, `code-review high` su 88.1; scheggia (input assurdi sui titoli: vuoti, solo suffissi, unicode); prova sul Motorola (ZY22HKD85K) e sul Mi A3 (0d7ae9df206e) via adb: Home, Tutti i brani, Cerca, un suggerito già posseduto non riproposto. Misure `perf_device.py` di Home e Tutti i brani confrontate con la base della 87 (soglie in `analisi.md` «Rete», D-398).

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
