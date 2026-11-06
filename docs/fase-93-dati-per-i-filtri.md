# Fase 93 — Dati nuovi per i filtri (refactor «superfici-e-ricerca»)

**Obiettivo:** raccogliere in background i dati che i filtri delle playlist intelligenti (fase 94) useranno: più generi per brano, nazionalità dell'artista, BPM ed etichetta. Nessuna UI nuova.

**Prerequisiti:** fase 92 chiusa. Nessun mockup (dati raccolti in background). Decisioni D-390, D-397, D-398. Rilievi F-94, F-95, F-96 (in parte: stelle e flag «scaricato» scartati). Aree a rischio: schema drift, backup (`lib/services/backup/restore_service.dart`, `lib/data/repositories/backup_merge.dart`), rete (rate limit).

**Comando mirato:** `flutter test test/services/tags test/data/migration_test.dart test/data/backup_merge_test.dart test/data/backup_queries_test.dart test/services/backup test/services/online/musicbrainz_genre_test.dart test/services/online/credits_test.dart` più i test nuovi di questa fase.

## Task

### 93.1 — Più generi per brano (F-95, D-390)
- Tabella brano-genere (`track_genres`: trackId, genere normalizzato, posizione) in `lib/data/db/tables.dart`; migrazione, poi `dart run build_runner build --delete-conflicting-outputs`. `tracks.genre` resta il primo genere (compatibilità con ciò che c'è oggi).
- `lib/services/tags/audio_metadata_tag_reader.dart:99` (oggi `genres.first`): restituisce tutti i generi (separatori `;`, `/`, tag multipli) e il repository li salva insieme al brano.
- Rilettura dei tag in background per la libreria esistente: a lotti, in un isolate/`compute`, con pausa se l'utente scorre o riproduce; riprendibile dopo un riavvio; progresso nel Registro attività. Nessun blocco della UI.
- Test nuovi: tag con 3 generi → 3 righe e `tracks.genre` = primo; rilettura idempotente; brano senza genere; rilettura interrotta e ripresa.

### 93.2 — Nazionalità dell'artista (F-94, D-390)
- Tabella `artist_countries` (chiave artista normalizzata, paese ISO 3166-1, fonte `musicbrainz`/`wikidata`, data del rilevamento; anche «non trovato» con data, per non richiedere di nuovo per 30 giorni).
- Riempita in background da MusicBrainz (`area`/`country`) con `lib/services/online/musicbrainz_client.dart` e il suo rate limit (1 richiesta/s), poi Wikidata (P27) se manca; solo su rete non a consumo e senza Jam attivo; ogni giro registrato nel Registro attività; si ferma da solo al primo errore di rate limit.
- Test nuovi (client finto, fixture JSON): area → ISO; ripiego su Wikidata; «non trovato» non riprovato prima di 30 giorni; rete a consumo → nessuna richiesta; artista con più nomi normalizza alla stessa chiave.

### 93.3 — BPM ed etichetta (F-96, D-390)
- Estratti da `track_enrich.details` (JSON, `TrackDetails` in `lib/services/online/credits.dart:147`) con `json_extract` in SQL o colonne derivate: scegliere in base ai conteggi sul DB reale (2 534 brani) e documentare la scelta qui. Solo brani arricchiti; per gli altri il valore è assente (il filtro della 94 li esclude).
- Test nuovi: query per BPM e per etichetta su `details` di esempio; brano non arricchito → assente; JSON con campo mancante o malformato non rompe la query.

### 93.4 — Controlli di fase
- Backup: le tabelle nuove entrano in backup e in `backup_merge` con test di ripristino; i backup vecchi (fixture della 87) si ripristinano e danno tabelle vuote (D-397); schema più nuovo rifiutato come oggi.
- `flutter analyze`; comando mirato; review del diff (code-review high su migrazione e backup); scheggia.
- Motorola edge 40 (ZY22HKD85K): nuova lettura dei tag su ~2 500 brani mentre si scorre Tutti i brani, senza scatti (`scripts/perf_device.py`, D-398). Mi A3 (0d7ae9df206e): stesso scenario, tolleranza più leggera; poi backup → ripristino su un profilo pulito.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti

### 93.3 — BPM ed etichetta
Scelta: `json_extract` su `track_enrich.details` (campi `bpm`, `label`), protetto da `json_valid`; niente colonne derivate e niente migrazione, quindi nessun dato duplicato. I filtri girano su pochi brani arricchiti. API in `lib/data/repositories/enrich_filter_queries.dart`: `bpmSql(e)`, `labelSql(e)`, `trackIdsByBpm`, `trackIdsByLabel` (confronto con `normalize` in Dart, perché SQLite non toglie gli accenti). Brani non arricchiti, JSON malformato o campo mancante danno NULL e sono esclusi.
