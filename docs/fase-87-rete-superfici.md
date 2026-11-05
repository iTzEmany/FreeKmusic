# Fase 87 — Rete di sicurezza e misure di partenza (refactor «superfici-e-ricerca»)

**Obiettivo:** prima di toccare il codice, fissare con test di caratterizzazione, golden e misure di fluidità lo stato di `origin/master`, così le fasi 88–97 cambiano solo ciò che è stato scelto. **Nessun cambio di comportamento in questa fase.**

**Prerequisiti:** fase 86 chiusa. Mockup: nessuno (solo rete). Decisioni D-389, D-392, D-393, D-397, D-398, D-416, D-417. Aree a rischio: nessuna (solo test e script); le misure vanno su entrambi i telefoni.

**Comando mirato:** `flutter test test/services/library/rule_corpus_test.dart test/services/backup/legacy_backup_test.dart test/data/playlist_order_test.dart test/services/import/library_index_characterization_test.dart test/services/shuffle_plus/suggestion_pool_bayou_test.dart test/ui/shell_tabs_test.dart test/services/online/merge_results_characterization_test.dart test/data/library_sort_characterization_test.dart test/ui/alpha_scroller_offset_test.dart test/goldens/screens_golden_test.dart` (più i test esistenti elencati in `refactor/superfici-e-ricerca/analisi.md` «Rete»).

## Task

### 87.1 — Caratterizzazione 1–4 (D-389, D-393, D-397)
- `test/services/library/rule_corpus_test.dart`: ~25 regole reali su un DB fisso → stessi id; `formatRules(parseRules(s)) == s`; `artista:Queen` trova anche «Queens of the Stone Age».
- `test/services/backup/legacy_backup_test.dart` + fixture in `test/fixtures/backup/` (schema v14 e penultimo): playlist, regole, ordine manuale, artisti seguiti e impostazioni intatti; schema più nuovo rifiutato (come `restore_service_test.dart`).
- `test/data/playlist_order_test.dart`: l'ordine manuale (`playlist_tracks.position`) resta dopo riordino, rimozione, undo, ripristino.
- `test/services/import/library_index_characterization_test.dart` + `test/services/shuffle_plus/suggestion_pool_bayou_test.dart`: «Born On The Bayou» (315 222 / 231 000 ms, stesso titolo e artista) oggi **non** trovato da `LibraryIndex.find` (`track_matcher.dart:114-127`); l'asserzione si ribalta nella 88.1.

### 87.2 — Caratterizzazione 5–8 (F-100, F-86, F-87, F-78)
- `test/ui/shell_tabs_test.dart`: cambiando scheda restano pagine aperte, scroll, scheda della Libreria e testo di ricerca (si ribalta nella 89.4).
- `test/services/online/merge_results_characterization_test.dart`: `mergeResults` (`merge_results.dart:100-165`) non produce brani locali e dà una sola scheda artista/album (`cards.first`).
- `test/data/library_sort_characterization_test.dart`: ordine di `LibrarySort` (`library_entries.dart:127-148`) con pari merito e accenti.
- `test/ui/alpha_scroller_offset_test.dart`: salto = indice × altezza riga, con barra visibile e nascosta (`all_tracks_screen.dart:136-165`).

### 87.3 — Golden nuovi (rigenerati con `scripts/shots.sh`)
- In `test/goldens/screens_golden_test.dart`: Libreria nelle schede Playlist, Album, Artisti e con la lente aperta; Tutti i brani scrollato; Cerca con risultati; editor smart; Podcast; Home a scala 2.0. Servono a vedere cosa cambia nelle fasi dopo, non a bloccarlo.

### 87.4 — Scenari di fluidità e misura `base` (D-398)
- `scripts/perf_device.py` e `integration_test/perf_test.dart`: scenari nuovi: scroll della Libreria, lente aperta/chiusa, scroll di Tutti i brani, cambio scheda. Gli esistenti restano (Pallino schede, Tutti i brani, Album, Libreria Tutto→Playlist→Album→Artisti, Ricerca «notte»).
- Misura `base` su `origin/master` (build profile) con `python3 scripts/perf_device.py <id> --label base --playback --only "…"` su Motorola edge 40 (ZY22HKD85K) e Mi A3 (0d7ae9df206e), più avvio a freddo (oggi 2415–2575 ms). Numeri scritti in Esiti: sono la base di 88–97.

### 87.5 — Controlli di fase
`flutter analyze`; comando mirato verde; golden generati con `scripts/shots.sh`; review del diff; scheggia (i test di caratterizzazione devono fallire se si cambia il comportamento che fissano); prova sul Motorola e sul Mi A3 via adb che l'app parta e gli scenari nuovi girino. Dopo la misura, ripulire i telefoni.

**Fatto quando:** gli 8 test sono verdi su `master` senza modificare `lib/`, i golden sono committati, la base di fluidità di entrambi i telefoni è scritta qui.

## Esiti
