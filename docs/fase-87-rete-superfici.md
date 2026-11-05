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

### Base di fluidità — Mi A3 (`0d7ae9df206e`, 5/11, `--label base --playback`, build profile, codice di `origin/master` e2b6a8c1)
- Scansione: 3000 brani in 14.5 s
- Avvio a freddo (`am start -W`, TotalTime): mediana 2697 ms su 5 (2899, 2830, 2697, 2611, 2695)
- Da `main` al primo frame: mediana 685 ms
- Memoria (PSS totale): 245 MB

| Scenario | Frame | build p50/p90/p99 ms | raster p50/p90/p99 ms | > 16,7 ms | > budget |
|---|---|---|---|---|---|
| Pallino schede | 1636 | 3.0/7.4/11.0 | 6.0/15.3/19.3 | 5.9 % | 5.9 % (16.7 ms) |
| Tutti i brani | 503 | 1.9/6.6/12.1 | 6.2/9.0/17.6 | 2.0 % | 2.0 % (16.7 ms) |
| Album | 1165 | 3.4/6.9/13.2 | 6.2/10.4/19.0 | 4.2 % | 4.2 % (16.7 ms) |
| Libreria Tutto→Playlist→Album→Artisti | 4428 | 3.8/8.5/12.9 | 6.1/11.7/20.7 | 4.9 % | 4.9 % (16.7 ms) |
| Ricerca «notte» | 907 | 1.4/5.4/8.1 | 3.8/5.7/10.8 | 0.2 % | 0.2 % (16.7 ms) |
| Scroll Libreria | 1293 | 3.8/7.8/10.0 | 6.3/11.3/20.2 | 4.7 % | 4.7 % (16.7 ms) |
| Lente Libreria | 2831 | 2.9/6.6/10.4 | 4.7/7.2/18.3 | 1.9 % | 1.9 % (16.7 ms) |
| Scroll Tutti i brani | 511 | 1.6/4.3/8.7 | 6.1/8.9/17.4 | 2.3 % | 2.3 % (16.7 ms) |
| Cambio scheda | 3316 | 3.4/8.1/13.9 | 5.8/13.1/21.2 | 5.5 % | 5.5 % (16.7 ms) |
| Apri album | 378 | 2.5/7.5/17.3 | 5.9/10.0/21.3 | 2.1 % | 2.1 % (16.7 ms) |
| In riproduzione | 419 | 3.3/8.1/17.2 | 6.1/7.9/12.0 | 1.7 % | 1.7 % (16.7 ms) |
| Lettore dal dock | 1020 | 2.4/7.7/15.8 | 5.9/8.1/13.4 | 1.1 % | 1.1 % (16.7 ms) |
| Swipe mini player | 439 | 1.5/6.2/15.0 | 5.9/8.0/13.4 | 1.6 % | 1.6 % (16.7 ms) |
| Fogli | 1426 | 4.2/12.4/24.7 | 5.5/7.9/13.1 | 4.1 % | 4.1 % (16.7 ms) |
| Apertura player | 437 | 2.7/7.9/19.3 | 5.9/9.2/15.2 | 2.3 % | 2.3 % (16.7 ms) |
| Anello | 268 | 5.7/13.0/16.4 | 5.1/6.4/10.2 | 0.7 % | 0.7 % (16.7 ms) |

- Motorola edge 40: base rinviata (D-419), da misurare con lo stesso comando prima della fase 97.
- `perf_device.py` era rotto su master in tre punti, corretti qui: le schede del dock oggi si chiamano solo «Libreria» (senza «\n…»), il foglio Dispositivi su un'installazione nuova mostra prima la scheda del permesso Bluetooth, il menu del player si chiama «Altre azioni».
- Scenari nuovi: Scroll Libreria, Lente Libreria, Scroll Tutti i brani, Cambio scheda. Sul Mi A3 «Pallino schede» (5,9 %) e «Cambio scheda» (5,5 %) sono vicini alla soglia del 6 %: un frame vale poco meno di 0,1 punti a questi conteggi, ma «Pallino schede» è bimodale (gotchas).
- Trovato con 87.1: un database in attesa con schema più nuovo non viene rifiutato dal ripristino (solo dal manifest) → 88.5b.
