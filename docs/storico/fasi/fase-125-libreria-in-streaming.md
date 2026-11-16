# Fase 125 — Libreria in streaming (base)

## Obiettivo
Chi sceglie «Streaming con cache» aggiunge i brani alla libreria senza scaricarli: righe ombra salvate con la nuvola,
valide ovunque (Home, daylist, smart, statistiche, backup), filtro «Tutti · Sul dispositivo · In streaming», cache che
tiene i preferiti, pre-caricamento di al massimo 3 brani, salto dei brani non in cache senza rete. Chi aggiorna resta
«Sul dispositivo» e non vede cambiare niente (D-598). SD, qualità, «Libera spazio», backup automatico: fase 126.

## Riferimenti
D-574..D-578, D-596..D-598, D-607, D-609, D-610, D-612; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Architettura C (modello dati, elenco delle query K-02, smart cache, offline, `libraryAdder`), RNF-03, rischi F-2, F-3,
F-5. Documenti d'area: `../architettura/libreria-e-dati.md`, `../architettura/riproduzione-e-coda.md`, `../architettura/sync-backup-jam.md`.

## Mockup
```text
Onboarding: Dove tieni la musica?    Brani
+--------------------------------+   +--------------------------------+
| Dove tieni la musica?          |   | Brani                          |
| Puoi cambiarlo quando vuoi.    |   | [Tutti] Sul dispositivo        |
| (o) Streaming con cache [Cons.]|   |         In streaming           |
|     I brani restano online; i  |   | Instant Crush  Daft Punk   (n) |
|     piu ascoltati in 1 GB.     |   | Cosa mi manchi a fare Calcutta |
|     Ti restano 2,8 GB liberi.  |   | Midnight City  M83         (n) |
| ( ) Sul dispositivo            |   | Nightcall  Kavinsky            |
|     Ogni brano si scarica.     |   |   (n) = nuvola, in streaming   |
| [Indietro]          [Avanti]   |   | Home   Cerca   Libreria Impost.|
+--------------------------------+   +--------------------------------+
```

```text
Menu di un brano online              Coda senza rete
+--------------------------------+   +--------------------------------+
| One More Time  Daft Punk       |   | Coda                           |
|  Aggiungi alla libreria        |   | ! Senza rete: 14 brani disp.   |
|  Scarica sul dispositivo       |   | Nightcall · sul dispositivo    |
|  Aggiungi a una playlist       |   | Midnight City · non in cache,  |
|  Riproduci dopo                |   |   si salta (grigio)            |
+--------------------------------+   | Strobe · in cache              |
                                     +--------------------------------+
```

```text
Memoria e streaming (parte di questa fase)
+--------------------------------------------------+
| Dove tieni la musica          Streaming con cache |
| Cache dello streaming · 1,0 GB                    |
|   Usati 640 MB · preferiti tenuti finché c'è spazio|
| Pre-carica anche con i dati mobili (fino a 3) [on]|
+--------------------------------------------------+
```

## Task
- [x] 125.1 Schema v20 `tracks.saved` e repository (D-607, F-3, RNF-03) — `/code-review high`
  - File: `lib/data/db/tables.dart`, `lib/data/db/app_database.dart` (`kSchemaVersion = 20`, blocco `if (from < 20)` con
    controllo `PRAGMA table_info` come `from < 19`), `lib/data/repositories/track_kinds.dart` (`libraryRowSql`,
    `isLibraryRow`), `lib/data/repositories/track_repository.dart` (`setSaved`, `saveStream`, `albumKey` d'album,
    `deleteUnplayedStreamRows` con `saved = false`), `test/data/migration_test.dart`, `test/data/track_repository_test.dart`.
  - Passi: 1. test prima: DB v19 di 1.6.2 con download e righe ombra → v20, righe ombra `saved = false`, nessun file
    toccato; `saveStream` crea `kind = 2, saved = 1` con `albumKey` `stream|<artista album>|<album>`; una riga salvata
    senza ascolti non si cancella; 2. colonna e migrazione; 3. `dart run build_runner build --delete-conflicting-outputs`.
  - Comando mirato: `flutter test test/data/migration_test.dart test/data/track_repository_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; l'APK installato sopra la 1.6.2 sul Mi A3 apre la libreria con gli stessi brani.

- [x] 125.2 Query K-02 in un passo solo (R-232, D-597, F-2, D-610) — `/code-review high`
  - File: tutte le query dell'elenco § C «Query da cambiare» (schede e conteggi, Home, daylist, Shuffle+, smart,
    statistiche), `test/data/stream_rows_hidden_test.dart` (esteso).
  - Passi:
    1. **Prima** i test, verificati rossi per le righe salvate: riga ombra non salvata invisibile ovunque; riga salvata
       visibile in schede, conteggi, Home, daylist, Shuffle+, `watchByRules` e statistiche.
    2. Ogni query passa a `libraryRowSql`/`isLibraryRow`; quelle dell'elenco «Restano `kind = 0`» non si toccano.
    3. Elenco § C ricopiato nelle «Note di deviazione» con una spunta per riga.
  - Comando mirato: `flutter test test/data/stream_rows_hidden_test.dart test/data/library_queries_test.dart test/data/home_sections_test.dart test/data/stats_queries_test.dart test/services/library/rule_sql_test.dart test/services/daylist/daylist_store_test.dart test/data/track_repository_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi e tutte le righe dell'elenco spuntate.

- [x] 125.3 Backup e ripristino delle righe salvate (R-232, F-5) — `/code-review high`
  - File: `lib/data/repositories/backup_queries.dart` (`kind != 2 OR saved = 1`), `TrackUserData` (`saved`),
    `lib/data/repositories/backup_merge.dart` (`ensureStreamRow` + segno), `lib/services/backup/backup_service.dart`
    (conteggio `:148`), `test/services/backup/stream_playlist_backup_test.dart`.
  - Passi: 1. test prima: backup → ripristino su DB vuoto con righe salvate, preferiti, playlist e ascolti uguali; backup
    vecchio senza il campo → come oggi; 2. modifica (solo campi facoltativi nel formato portabile).
  - Comando mirato: `flutter test test/services/backup/stream_playlist_backup_test.dart test/services/backup/user_data_test.dart test/services/backup/restore_service_test.dart test/data/backup_queries_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; «In streaming» ha lo stesso numero di brani prima e dopo il ripristino.

- [x] 125.4 «Dove tieni la musica»: impostazione, pagina «Memoria e streaming», onboarding (R-229, R-237, D-575)
  - File: `lib/data/settings/settings_store.dart` (`storageMode`, di serie «Sul dispositivo» se `onboardingDone`;
    `prefetchOnMobile`, di serie acceso), gruppo «Memoria e streaming» in `settings_pages.dart` (prende `StreamCacheTile`
    da `DownloadSettingsTiles`), `onboarding_pages.dart` + `onboarding_screen.dart` (pagina dopo `FoldersPage`, spazio da
    `diskSpaceOf`), ARB, `test/data/settings_store_test.dart`, `test/ui/onboarding_test.dart`.
  - Passi: 1. impostazione e pagina; 2. passo d'onboarding con due scelte, streaming preselezionato sotto i 4 GB (SD e
    backup automatico li aggiunge la fase 126).
  - Comando mirato: `flutter test test/data/settings_store_test.dart test/ui/onboarding_test.dart test/ui/stream_cache_tile_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: un'installazione con `onboardingDone` legge «Sul dispositivo»; con spazio finto < 4 GB il passo
    preseleziona lo streaming e la scelta finisce nelle impostazioni (test).

- [x] 125.5 `libraryAdder`: «Aggiungi alla libreria», Shazam e importazione (R-230, R-233, D-574, D-576)
  - File: `lib/providers/library_add_providers.dart` (nuovo), i chiamanti di § C «Dove si sceglie» (`shazam_providers.dart`,
    `import_providers.dart`, `pending_playlist_adds.dart`, `online_song_row.dart`, `online_results_sections.dart`,
    `track_actions.dart`, `genre_screen.dart`, `suggestion_actions.dart`), ARB, `test/providers/shazam_providers_test.dart`,
    `test/providers/pending_playlist_adds_test.dart`, `test/ui/online_song_row_test.dart`.
  - Passi: 1. test prima: in modo streaming nessun job in `DownloadQueue` e righe salvate create (Shazam, import, `addto:`);
    in modo dispositivo come oggi; 2. `add(r, {tag})`; import e `addto:` aggiungono la riga alla playlist subito
    (`addStreamTracks`); 3. etichetta «Aggiungi alla libreria», «Scarica sul dispositivo» resta come seconda voce.
  - Comando mirato: `flutter test test/providers/shazam_providers_test.dart test/providers/pending_playlist_adds_test.dart test/services/import/playlist_import_service_test.dart test/ui/online_song_row_test.dart test/ui/track_actions_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; su Linux in modo streaming un risultato aggiunto compare in Brani e suona.

- [x] 125.6 Nuvola e filtro della libreria (R-230, R-231, D-596, RNF-04)
  - File: righe dei brani e schede Brani/Album/Artisti in `lib/ui/screens/library/`, ARB, `test/ui/all_tracks_screen_test.dart`,
    `test/ui/library_screen_test.dart`, golden della scheda Brani.
  - Passi: 1. icona nuvola sulle righe salvate; 2. filtro in cima (di partenza «Tutti») che usa `kind = 0` o
    `kind = 2 AND saved = 1`; 3. etichette TalkBack di filtro e nuvola.
  - Comando mirato: `flutter test test/ui/all_tracks_screen_test.dart test/ui/library_screen_test.dart test/goldens/screens_golden_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: il filtro cambia l'elenco nelle tre schede (test); golden aggiornato; etichette semantiche presenti.

- [x] 125.7 Smart cache, pre-caricamento e senza rete (R-234, R-235, D-577, D-609) — `/code-review high` sul gestore
  - File: `lib/services/stream/stream_cache.dart` (`keepLonger`), `lib/providers/stream_providers.dart`,
    `lib/services/stream/stream_preparer.dart` (al massimo 3 avanti; a consumo solo con `prefetchOnMobile`),
    `lib/services/audio/codecore_audio_handler.dart` (`_nextFile` nullo + niente rete → salto), riga grigia e avviso
    nella coda (`queue_sheet.dart`), test in `test/services/stream/` e `test/services/audio/online_playback_test.dart`.
  - Passi: 1. test prima: oltre il limite esce prima un non preferito; mai più di 3 avanti in Wi-Fi; a consumo 0 con
    l'opzione spenta e 3 accesa; voce non in cache senza rete → salto al prossimo disponibile; 2. modifiche; 3. «Senza
    rete: N brani disponibili» contato sulla coda.
  - Comando mirato: `flutter test test/services/stream/stream_cache_test.dart test/services/stream/stream_preparer_test.dart test/services/audio/online_playback_test.dart test/ui/online_queue_row_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; sul Mi A3 in modalità aereo la coda salta i brani non in cache e mostra l'avviso.

## Tocca a te
Niente di obbligatorio: a fase chiusa, se vuoi, prova sul tuo telefono «Aggiungi alla libreria» e l'ascolto senza rete.

## Note di deviazione

### 125.2: elenco § C «Query da cambiare» (passano a `libraryRowSql`/`isLibraryRow`)
- [x] track_repository: `watchTracks`, `musicLight`, `tracksOfArtist`, `tracksOfAlbums`, `liteEntries`, `countAll`, `watchCount`, `watchRecentlyAdded`
- [x] library_queries: `watchAlbums`, `watchArtistAlbums`, `watchArtists` (copertine e righe), `artistNamed`, `watchArtistTracks`, `watchGenres`, `watchGenreTracks`, `watchAlbumTracks`, `genreCounts`, `watchTopTracks`, `randomTracks`
- [x] filter_counts_repository: `_visible`
- [x] credits_repository: brani di un accreditato
- [x] artist_country_repository: artisti per paese
- [x] daylist_store: `load` (brano ancora in libreria; helper `isLibraryTrack` in `track_kinds.dart`)
- [x] seed_resolver: `chooseSeeds`
- [x] shuffle_plus_controller: conteggio `_eligible`
- [x] player_providers: `localCount` di `plusAllowed`
- [x] rule_sql: `toSql` (quindi `watchByRules` e i tag)
- [x] stats_queries: `listensSinceSql` e copertine degli artisti (`:433`/`:439` già `listenKinds`, invariati)
- Restano `kind = 0` di proposito (non toccati): `_downloadedNoPlaylist`, `mp3LengthRows`, `duplicate_repository`, `review_queries`, `track_genre_repository`, `memory_queries` (2), `track_deleter`, `bulk_actions`, `playlist_sync_repository`, `track_actions`.
- Prova a fine fase (16/11, Mi A3 con l'APK della fase installato sopra la 124): stessa libreria (15 brani) dopo la migrazione v20; «Sul dispositivo» per chi aggiorna (D-598); in modo streaming «Aggiungi alla libreria» crea 4 righe salvate senza download, con la nuvola; in modalità aereo la coda mostra «Senza rete: N brani disponibili», Avanti e Indietro saltano i brani non in cache, nessun crash. Linux (xvfb): pagina «Dove tieni la musica?» nell'onboarding, riga salvata `kind=2, saved=1` che compare in Brani; il suono vero non è verificato (audio dirottato). Corretti dopo la prova: avviso «Senza rete» che restava al ritorno della rete (il provider ora rilegge la sonda alla riapertura della coda), testo del filtro «In streaming» vuoto, Jam annunciata da un'altra app sullo stesso telefono (vecchio pacchetto 1.3.0) ignorata se arriva dal proprio indirizzo.
- Etichette: nelle impostazioni e nell'onboarding le scelte si chiamano «Sul dispositivo» e «In streaming» (non «Streaming con cache» e senza «Consigliato» come nel mockup).
- Non provati: l'installazione sopra la 1.6.2 rilasciata (provata sopra la build della 124, stesso schema v19); playlist con brani salvati sul telefono.

