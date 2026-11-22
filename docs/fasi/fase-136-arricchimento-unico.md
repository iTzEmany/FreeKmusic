# Fase 136 — Arricchimento unico e leggero

## Obiettivo
Un solo motore (`EnrichEngine`) per tutti i percorsi di arricchimento, con MusicBrainz che non viene più sommerso di richieste: coda unica, pausa dopo un 503, cache, meno chiamate per brano. Le righe in streaming non si rifanno a ogni ascolto. Nuova impostazione per la rete a consumo e nuovo flag «strumentale» (migrazione v21). Fuori: nuove fonti di dati, cambi ai testi delle schede.

## Riferimenti
D-280 (finalmente chiusa), D-662, D-663, D-683, D-684, D-675, D-699. Rilievi F-10..F-15 e prova L6 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); mappa dei percorsi e ordine dei fix in [`../refactor/grande-revisione/scansione-arricchimento.md`](../refactor/grande-revisione/scansione-arricchimento.md); rete in [`../refactor/grande-revisione/rete.md`](../refactor/grande-revisione/rete.md) (riga 136). Aree: `../architettura/online.md`, `libreria-e-dati.md`. **Area a rischio** (`EnrichEngine`, scrittori dei campi, migrazione): review `/code-review high`. Schema oggi v20, in questa fase v21.

## Task
- [ ] 136.1 Test di caratterizzazione (rete.md, riga 136)
  - File: `test/services/online/enrich_engine_test.dart`, `test/services/online/enrich_status_characterization_test.dart`, `test/services/stream/stream_enrich_row_provider_test.dart` (oggi: lo stream scrive tutti i campi, status solo se ha scritto), `test/providers/enrich_completer_providers_test.dart`.
  - Passi: 1) fissare il comportamento di oggi (campi scritti, segni «niente», status); 2) verdi su `master`; 3) commit di soli test.
  - Comando mirato: `flutter test test/services/online/enrich_engine_test.dart test/services/online/enrich_status_characterization_test.dart test/services/stream/stream_enrich_row_provider_test.dart test/providers/enrich_completer_providers_test.dart`
  - Fatto quando: verdi senza modifiche a `lib/`; commit separato.
- [ ] 136.2 Client MusicBrainz: coda, pausa, cache (F-10; D-683)
  - File: `lib/services/online/musicbrainz_client.dart` (~96-128), `lib/services/online/http_client.dart` (`RateLimiter.wait`, ~158, da riusare), `lib/services/online/source_cooldown.dart` (se adatto alla pausa), `test/services/online/musicbrainz_client_queue_test.dart` (nuovo).
  - Passi: 1) coda unica nel client: due chiamanti contemporanei partono uno dopo l'altro; 2) dopo un 503 pausa di 1, poi 5, poi 15 minuti (clock finto nei test; la pausa si azzera dopo un successo); 3) durante la pausa le richieste falliscono subito con `MusicBrainzUnavailable`, senza rete; 4) cache in memoria con scadenza, anche dei «non trovato»; 5) test: richieste serializzate, scala 1-5-15, cache negativa.
  - Comando mirato: `flutter test test/services/online/musicbrainz_client_queue_test.dart test/services/online/` + `flutter analyze`
  - Fatto quando: client finto: dopo un 503, 0 richieste fino a fine pausa; richieste identiche = 1 chiamata.
- [ ] 136.3 503 = «limitato»; paesi e completer (F-11, F-14; D-683)
  - File: `lib/services/online/credits_enricher.dart` (~63-80), `lib/services/online/enrich_runner.dart` (~395-402), `lib/services/online/artist_country_finder.dart` (~89), `lib/providers/artist_country_providers.dart` (~28-44), `lib/providers/startup_providers.dart` (~35-55), `lib/data/settings/settings_store.dart` (impostazione «rete a consumo»), `lib/providers/settings_providers.dart`, `lib/ui/screens/settings/enrich_library_tile.dart` (nuovo interruttore accanto agli switch), ARB ×6.
  - Passi: 1) `MusicBrainzUnavailable` si conta come `limited`: il runner si ferma; 2) il finder dei paesi legge la pausa del client; 3) il completer applica gli stessi controlli di `artistCountryAllowed` (rete a consumo e Jam), con l'impostazione nuova che permette la rete a consumo (default: no); 4) stringhe ARB con `scripts/arb_add.py`; 5) test.
  - Comando mirato: `flutter test test/services/online/ test/providers/enrich_completer_providers_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart`
  - Fatto quando: con 503 il runner non chiama più MB e il finder dei paesi non riparte; il completer non parte su rete a consumo con l'impostazione spenta né durante una Jam.
- [ ] 136.4 Meno richieste per brano (F-13)
  - File: `lib/services/recognition/track_recognizer.dart` (~258), `lib/services/online/credits_enricher.dart` (~108, ~158), `lib/services/online/curiosity_finder.dart` (~163), `lib/services/online/enrich_gather.dart`.
  - Passi: 1) il risultato di `recordingsByIsrc` si calcola una volta per brano e si passa a riconoscimento, crediti, curiosità e generi; 2) Deezer una sola volta in `propose`; 3) test con client finto che conta le richieste.
  - Comando mirato: `flutter test test/services/online/ test/services/recognition/`
  - Fatto quando: client finto: ≤ 1 richiesta MB per ISRC e per brano arricchito.
- [ ] 136.5 Righe in streaming sul motore unico (F-12; D-683) — review: `/code-review high`
  - File: `lib/providers/stream_providers.dart` (~77-133, `streamEnrichRowProvider`), `lib/services/online/synthetic_track.dart` (~12-14), `lib/services/online/enrichment_service.dart` (~100, `id <= 0`), `lib/services/stream/stream_enrich_trigger.dart`, `lib/services/online/enrich_engine.dart` (`completeOne`).
  - Passi: 1) ascolto, Shuffle+ e import chiamano `engine.completeOne(row.id, autoParts)`: segni «niente», status, deduplica, solo campi vuoti, rispetto di `autoEnrich`/`autoLyrics`/`autoCuriosities`; 2) tolto `EnrichField.values` dallo stream; titolo e artista non si sovrascrivono; 3) tolta la logica `id <= 0` e i crediti a ogni ascolto; 4) test: secondo `completeOne` = 0 richieste; riga stream senza sovrascrivere titolo/artista.
  - Comando mirato: `flutter test test/services/stream/ test/providers/ test/services/online/enrich_engine_test.dart`
  - Fatto quando: i test di 136.1 aggiornati (citando D-683) e i nuovi sono verdi; un secondo ascolto non genera richieste.
- [ ] 136.6 Anteprima e seconda opinione sullo stesso gather; via `_mbRestUntil` (D-683)
  - File: `lib/ui/screens/enrich_preview_dialog.dart` (~51, ~130), `lib/services/online/second_opinion.dart` (~75, ~213, `_mbRestUntil`), `lib/services/online/enrichment_service.dart` (resta solo lettura per l'anteprima), `lib/services/online/enrich_gather.dart`.
  - Passi: 1) l'anteprima legge con `EnrichGather` (sola lettura, limitatore condiviso); 2) la seconda opinione scrive con `engine.commit`; 3) eliminato `_mbRestUntil` (la pausa è nel client); 4) «Accetta» nell'anteprima scrive come decisione dell'utente; 5) test degli esistenti aggiornati.
  - Comando mirato: `flutter test test/services/online/ test/providers/second_opinion_job_test.dart`
  - Fatto quando: `grep -rn "_mbRestUntil" lib` = 0; `EnrichmentService.apply` non ha più chiamanti fuori dall'anteprima.
- [ ] 136.7 Migrazione v21 «strumentale» (D-675; in un solo passo)
  - File: `lib/data/db/tables.dart` (colonna `instrumental` su `track_enrich` o tabella affine, scegliere guardando dove vivono gli altri segni), `lib/data/db/app_database.dart` (`kSchemaVersion` 21, `onUpgrade`), codice drift generato, `lib/services/backup/user_data.dart` (se la colonna deve entrare nel backup), `test/data/migration_test.dart`.
  - Passi: 1) colonna nullabile con default (nessuna riga riscritta); 2) `dart run build_runner build --delete-conflicting-outputs`; 3) test v20 → v21 con righe presenti; 4) backup: formato stabile, il campo nuovo è opzionale.
  - Comando mirato: `flutter test test/data/migration_test.dart test/services/backup/`
  - Fatto quando: la migrazione su un DB v20 con righe non ne modifica nessuna; schema = 21.
- [ ] 136.8 Brani strumentali: flag e salti (F-15; D-684) — review: `/code-review high`
  - File: `lib/services/online/lrclib_client.dart` (oggi scarta `instrumental: true`), `lib/services/online/lyrics_chain.dart` (`LyricsChain.find`, ~62), `lib/services/online/enrich_parts.dart` (~59-67), `lib/ui/screens/lyrics/lyrics_view.dart` (~137), `lib/providers/karaoke_providers.dart`, `lib/services/karaoke/separation_service.dart`, ARB ×6 («brano strumentale»).
  - Passi: 1) lrclib salva il flag; 2) euristica ripiego: titolo «(Instrumental)»/«Instrumental Version»; 3) per gli strumentali niente ricerca testi, niente curiosità sul testo, karaoke dice «brano strumentale»; 4) test per lrclib, titolo e salti.
  - Comando mirato: `flutter test test/services/online/ test/providers/karaoke_providers_test.dart`
  - Fatto quando: un brano segnato strumentale non genera richieste di testi e il karaoke mostra il messaggio.
- [ ] 136.9 Area e controllo di fine fase
  - Aggiorna `../architettura/online.md` (motore unico, coda e pausa MB, impostazione rete a consumo; «Trappole»: `EnrichmentService` ridotto a lettura), `libreria-e-dati.md` (v21), `../decisioni.md` solo per deroghe nuove.

## Tocca a te
- Nessuna cosa in questa fase: il controllo su un giorno di log del Motorola (pochi 503, nessun riarricchimento) è nella 147.

## Note di deviazione
