# Fase 45 — Cache di streaming e motore

**Obiettivo:** un solo percorso per l'audio online di YouTube: il brano si scarica intero in una cache su disco
(`StreamCache`, LRU con limite in MB), poi il lettore lo suona come un file locale. Ogni brano in streaming ha una
**riga ombra** in `tracks` (`kind = 2`) che porta ascolti, cronologia e arricchimento. I suggeriti di Shuffle+
passano già di qui; il vecchio indirizzo diretto (`StreamAddressCache`) sparisce. In Impostazioni: cursore
«Spazio per lo streaming» e «Svuota». L'interfaccia della ricerca **non** cambia ancora (fase 46).

**Prerequisiti:** fase 44 chiusa. Fase 31 (`OnlineEntries`, `ShufflePlusController`, `PlayQueue.insertAt`),
fase 37 (`TrackMeta`), fase 42 (`track.kind`, test di architettura).

**Riferimenti:** `docs/feature-streaming.md` (requisiti R-03, R-05, R-07, R-08, R-09, R-11, R-12, R-14, R-15,
R-29, R-30; «Architettura», «Invarianti», «Rischi» K-01…K-08); decisioni D-63, D-66, D-67, D-68, D-69, D-75,
D-76, D-77, D-78, D-79, D-81.

**Intoccabili (D-76):** libreria e playlist (la cache non entra mai in scansione né nel backup; nessuna riga
`kind = 2` in una vista di libreria); i download di oggi (`DownloadQueue`, import di playlist: nessun codice
condiviso oltre `YoutubeService`, invariante 7); la fluidità (misure «Finale» della fase 44). **Nessun pacchetto
nuovo.** **Schema del DB invariato (D-77):** niente migrazioni, `kSchemaVersion` resta 14, la colonna `kind` c'è
già. Niente gapless/dissolvenza verso o da un brano in streaming (D-81, K-08: `NextWindow` riceve null come oggi).

**Radio:** le stazioni della Radio internet (`OnlineEntries.radioOf`, `PlayContextKind.radio`) sono flussi dal
vivo senza fine e restano su `loadUri` come oggi; l'invariante 2 («nessun `loadUri` per YouTube») riguarda solo
YouTube. La «Radio» di R-29/D-75 è la radio di YouTube Music (D-88) da cui Shuffle+ prende i suggeriti
(`YtmRadioService`): i brani suggeriti passano dalla cache (45.5).

## Task

### 45.1 — `StreamCache` e chiave
**File:** `lib/services/stream/stream_key.dart`, `lib/services/stream/stream_cache.dart`,
`test/services/stream/stream_cache_test.dart`
1. `stream_key.dart`: la chiave è `YtResult.indexKey` (`downloadIndexKey(source, id)`); `streamPathOf(key)` =
   `'stream:<key>'` e `keyOfStreamPath(path)` (null se il percorso non inizia con `stream:`); nome file sicuro
   (`:` → `_`).
2. `StreamCache(dir, {limitBytes, freeSpace})` in `<appSupportDir>/stream_cache/` (`appSupportDir()` di
   `lib/core/paths.dart`): `fileFor(key)` (null se manca), `put(key, File)` (rename dal `.part`), `touch(key)` (data
   di modifica = ultimo uso, nessun indice salvato), `pin(key)`/`unpin(key)` (contatore), `evict()` LRU finché
   `usedBytes ≤ limite` saltando i fissati, `clear({Set<String> keep})`, `usedBytes`. All'avvio (`open()`) cancella i
   `.part` e misura la cartella. Tutto I/O asincrono (RNF-02).
3. Limite effettivo = min(cursore, spazio libero − margine) con `DiskSpace` di `lib/services/memory/disk_space.dart`
   (K-05). Margine: **500 MB** (D-84).
4. Cancellazione che fallisce (Windows, file in uso): loggata con `AppLog.w`, riprovata al giro dopo; `usedBytes`
   ricalcolato dalla cartella dopo ogni `evict` (K-06).

R-08, R-11 (cartella), parte di R-09.
**Fatto quando:** `flutter test test/services/stream/stream_cache_test.dart` verde con: limite 10 MB, 4 file da
4 MB → sotto il limite, sparito il meno recente, mai quello fissato (R-08); `.part` cancellati all'avvio;
`clear(keep: {k})` lascia solo `k`; file non cancellabile → riprovato e loggato; la cartella della cache non è dentro
nessuna cartella di `folders` (test con cartelle temporanee, R-11). `flutter analyze` pulito.

### 45.2 — Righe ombra, `listenKinds` e test «riga `kind = 2` in ogni vista» (K-02)
**File:** `lib/data/repositories/track_kinds.dart` (nuovo: `kMusicKind = 0`, `kEpisodeKind = 1`,
`kStreamKind = 2`, `listenKinds = [0, 2]`), `lib/data/repositories/track_repository.dart`
(`streamRow(key)`, `upsertStreamRow(key, YtResult) → int`), `play_history_repository.dart`, `stats_queries.dart`,
`lib/services/backup/backup_service.dart` (e la query di `user_data.json` in `backup_queries.dart`),
`lib/ui/widgets/track_kind.dart` (`kind == 2` → `TrackKind.online`),
`test/data/stream_rows_hidden_test.dart` (nuovo, **resta per tutte le fasi 45–49**), `test/data/play_history_test.dart`,
`test/data/stats_queries_test.dart`
1. Riga ombra: `kind = 2`, `folderId = null`, `path = 'stream:<chiave>'` (UNIQUE), titolo/artisti/album/durata dal
   risultato, `albumKey` calcolata come per i brani normali, `format` dall'estensione, `sizeBytes`/`mtimeMs` del file.
   Una riga per chiave (upsert per `path`).
2. Cronologia, statistiche (`watchHistory`, `period`, `topArtistsSince`…): dove oggi filtrano `kind = 0` passano a
   `kind IN listenKinds`. Le viste di libreria restano `kind = 0`.
3. Audit: `grep -rn "FROM tracks\|select(_db.tracks)\|_db.tracks" lib/data` e per ogni query su `tracks` senza filtro
   `kind` decidere: vista di libreria → `kind = 0`; cronologia/statistiche → `listenKinds`; per id → invariata.
   L'elenco delle query toccate va in una riga di nota in PROGRESS.
4. Backup: `user_data.json` esporta solo `kind = 0`; il `.sqlite` resta com'è (righe ombra innocue).
5. «Recenti» di R-12 = cronologia (D-83): le sezioni Home (`watchTopTracks`, «Da riscoprire», «Riprendi») restano
   `kind = 0`; lo streaming conta solo in cronologia e statistiche.

R-11 (backup), R-12 (query), K-02.
**Fatto quando:** `flutter test test/data/stream_rows_hidden_test.dart` verde: con una riga `kind = 2` (con ascolti e
`play_count > 0`) nel DB in memoria, la riga **non** compare in: brani (`watchTracks`), album, artisti, generi,
ricerca della libreria, Home (`watchTopTracks`, ripresa, aggiunti da poco), playlist, playlist intelligenti
(`rule_sql.dart`), doppioni, brani nascosti, brani mancanti, `liteEntries`, conteggi (`countAll`/`watchCount`),
Memoria, `user_data.json`; i file mancanti di una cartella (`missingPathsForFolder`) non la toccano.
`flutter test test/data/play_history_test.dart test/data/stats_queries_test.dart` verde con un caso nuovo: 2 ascolti
di una riga ombra → in cronologia e nelle statistiche con 2 ascolti (R-12). `flutter analyze` pulito.

### 45.3 — `StreamPreparer`
**File:** `lib/services/stream/stream_preparer.dart`, `lib/providers/stream_providers.dart` (provider di cache e
preparer), `test/services/stream/stream_preparer_test.dart`
1. Ingressi: la coda (`queueChanges` dell'handler, corrente + successivi online o righe `kind = 2`) e il tipo di rete
   (`NetworkProbe.current()` di `lib/core/network_kind.dart` via `networkProbeProvider`; desktop = non a consumo). Su rete non a consumo prepara tutta la coda,
   su rete a consumo solo i prossimi 3 (D-78); **max 2 download insieme**, nell'ordine della coda, priorità al
   corrente; un solo download per chiave (invariante 5) (R-14).
2. Download con `YoutubeService.download(r, dir)` (stesso yt-dlp dei download) in un `.part` dentro la cache, poi
   `StreamCache.put`. **Un** nuovo tentativo, poi errore (R-05). Pausa su 403/429 come `source_cooldown` di Shuffle+
   (K-04).
3. A file pronto: `upsertStreamRow` e arricchimento: `EnrichmentService.propose(Track sintetico)` parte insieme al
   download, `apply(proposta, trackId ombra)` quando la riga c'è; nessun tag scritto nel file (invariante 6).
4. API: `Future<File> ready(key)` (risolve appena il file c'è, errore dopo il secondo fallimento), stato per riga
   solo a cambio di fase (`queued | downloading | ready | failed`, mai i byte: K-03), `pin` del corrente e dei
   prossimi 2 online (invariante 3).
5. Rete a consumo: lo streaming funziona sempre; il blocco «solo Wi‑Fi» resta solo in `ShufflePlusController`
   (R-07).
6. K-01: leggere `android_yt_dlp_service.dart` / `MainActivity.kt` e verificare se il canale `codecore/ytdlp`
   serializza le chiamate. Se sì, lo streaming ha la priorità sui download della `DownloadQueue` senza toccarne il
   codice (una riga di nota in PROGRESS con l'esito).

R-03, R-05 (retry), R-07, R-14.
**Fatto quando:** `flutter test test/services/stream/stream_preparer_test.dart` verde con downloader finto: 4 brani in
coda → mai più di 2 download attivi, nell'ordine della coda; rete a consumo e 10 brani online → se ne preparano 3;
download che fallisce 2 volte → un solo retry poi `ready` dà errore; due richieste della stessa chiave → un download;
`ready` risolve prima della fine di un arricchimento lento e poi la riga ombra ha il testo (R-03); rete a consumo con
`shufflePlusUnmeteredOnly` acceso → il brano scelto dall'utente si prepara (R-07). `grep -rn "StreamPreparer"
lib/services/online/download_queue.dart` = 0 (invariante 7). `flutter analyze` pulito.

### 45.4 — Il lettore suona dal file in cache
**File:** `lib/services/audio/codecore_audio_handler.dart` (`_loadCurrent`, `_beginListen`, `registerPlay`,
`_refreshWindow`), `lib/services/audio/online_entries.dart` (`OnlineEntry.trackId?` = riga ombra),
`lib/main.dart` (cablaggio), `lib/providers/player_providers.dart` (`liveCurrentTrackProvider` rilegge la riga ombra),
`test/services/audio/online_playback_test.dart`, `test/services/audio/play_history_handler_test.dart`
1. `_loadCurrent`: entry online (id negativo) o riga `kind = 2` (id positivo, chiave da `keyOfStreamPath`) → resta in
   `loading` → `await preparer.ready(key)` → `_backend.load(file.path)`. Errore di `ready` o del backend →
   `_failAndSkip` con il contatore `maxConsecutiveErrors` di oggi (R-05). Le stazioni radio restano su `loadUri`.
2. Fine brano con il successivo non pronto: `_onCompleted` → `_loadCurrent(next)` resta `loading` finché `ready`
   risolve, poi parte da solo (R-15).
3. Ascolti: per l'online `_beginListen` e `registerPlay` usano `trackId` della riga ombra; `kind = 2` conta come
   `kind = 0` (R-12). Niente segnalibro né ReplayGain per lo streaming.
4. `liveCurrentTrackProvider`: con `trackId` ombra legge la riga (così testo e curiosità compaiono quando
   l'arricchimento finisce, R-03); prima della riga, il `Track` sintetico come oggi.
5. `NextWindow` riceve null verso e da un brano in streaming (K-08).

R-03, R-05, R-12, R-15.
**Fatto quando:** `flutter test test/services/audio/online_playback_test.dart test/services/audio/play_history_handler_test.dart`
verde con backend e preparer finti: voce online → stato `loading` poi `load(file)` (nessun `loadUri`); preparer che
fallisce → skip, e dopo `maxConsecutiveErrors` il lettore va in idle (R-05); brano B ancora in download a fine A →
`loading`, poi B parte da solo (R-15); 2 ascolti completi in streaming → 2 righe in `plays` sulla riga ombra e
`play_count = 2` (R-12); arricchimento finito dopo l'avvio → `liveCurrentTrackProvider` dà il testo (R-03); i test
esistenti dell'handler e della radio (`radio_playback_test.dart`) verdi. `flutter analyze` pulito.

### 45.5 — Suggeriti di Shuffle+ sulla cache; via `StreamAddressCache`
**File:** `lib/providers/shuffle_plus_providers.dart` (`prepare:` usa `preparer.ready` invece di
`handler.addresses`), `lib/services/shuffle_plus/shuffle_plus_controller.dart`, `lib/main.dart`,
`lib/services/audio/codecore_audio_handler.dart` (via `addresses`, `_loadStream`, prefetch in `_refreshWindow`),
cancellare `lib/services/audio/stream_address_cache.dart`, `test/services/audio/stream_address_cache_test.dart`,
`test/services/audio/stream_expired_test.dart` (se prova solo il percorso a indirizzo), `test/providers/shuffle_plus_test.dart`,
`test/providers/queue_provider_test.dart`
1. I suggeriti entrano in coda come oggi (id negativi, `OnlineEntries`) e si preparano come ogni brano online; il blocco
   «solo Wi‑Fi» e la pausa su 429 restano nel controller (R-07).
2. I suggeriti contano in cronologia e statistiche come ogni streaming (D-79, sostituisce la regola della fase 31
   «niente DB per i suggeriti»): tolto il ramo `isOnlineId` che saltava `registerPlay`.
3. `StreamSource.streamUrl`/`FastClientGate` restano finché li usa l'anteprima con le cuffie (si tolgono in 46.6).

R-29, R-07, R-12 (suggeriti).
**Fatto quando:** `grep -rn StreamAddressCache lib test` = 0; `grep -rn "_loadStream\|addresses" lib/services/audio/codecore_audio_handler.dart` = 0;
`flutter test test/providers/shuffle_plus_test.dart test/providers/queue_provider_test.dart` verde con un caso nuovo:
un suggerito passa dal preparer (downloader finto chiamato con il suo `YtResult`) e, ascoltato fino in fondo, scrive
una riga in `plays` sulla sua riga ombra. `flutter analyze` pulito.

### 45.6 — Impostazione `streamCacheMb`, cursore e «Svuota»
**File:** `lib/data/settings/settings_store.dart` (`streamCacheMb`, int, di serie 1024, 256–8192; nuova chiave,
nessun cambio alle chiavi esistenti), `lib/ui/screens/settings/stream_cache_tile.dart` (gruppo Download, accanto a
`download_settings_tiles.dart`), `lib/providers/stream_providers.dart` (uso della cache), ARB it/en/de/es (e le altre
lingue presenti) con `scripts/arb_add.py`, `test/data/settings_store_test.dart`, `test/ui/stream_cache_tile_test.dart`
1. Cursore «Spazio per lo streaming» 256 MB – 8 GB (passi che arrivano esattamente agli estremi), etichetta con lo spazio
   usato («320 MB su 1 GB»); al rilascio il nuovo limite va a `StreamCache` e parte `evict()` fuori dal thread UI.
2. «Svuota»: `clear(keep: {corrente})`; poi cancella le righe ombra senza ascolti e senza file (`kind = 2`, nessuna
   riga in `plays`): le righe con ascolti restano (D-81).
3. L'impostazione va nel backup come le altre impostazioni.

R-09.
**Fatto quando:** `flutter test test/data/settings_store_test.dart test/ui/stream_cache_tile_test.dart` verde:
impostazione salvata e riletta (valore fuori intervallo riportato in 256–8192); widget test del cursore (min, max,
di serie 1 GB) e dello spazio usato; «Svuota» → cache vuota tranne il brano in corso, righe ombra senza ascolti
cancellate, quelle con ascolti restano. `flutter analyze` pulito.

### 45.7 — Controlli di fase (K-01, K-02, K-03)
1. K-01: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde (RNF-03).
2. K-02: `flutter test test/data/stream_rows_hidden_test.dart` verde.
3. K-03 (D-19, solo app perf, build profile, `JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14`):
   `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 40m <scratchpad>/perf45.log -- python3 scripts/perf_device.py 0d7ae9df206e --label streaming-45 --playback`.
   Tabella «Dopo la fase 45» in `docs/refactor/ui-fluida/misure.md` accanto a «Finale», stesse righe. Tolleranza
   del confronto: **un frame per scenario** (D-85); uno scenario oltre la tolleranza → fermarsi e
   riportare (regole §1.6).
4. RNF-02: `grep -rn "readAsBytesSync\|writeAsBytesSync\|listSync\|statSync\|existsSync" lib/services/stream lib/ui/screens/settings/stream_cache_tile.dart` = 0.
5. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–5 sono verdi; `build/perf/streaming-45.md` esiste e la tabella in `misure.md`
copre ogni riga di «Finale».

### 45.8 — Prove a mano (utente) [~]
Materiale per l'utente (R-30, K-04). Build: `flutter build apk --debug --build-number=5000 --target-platform android-arm64`
per il Mi A3 (si può disinstallare con `-k`, mai cancellare i file musicali), `flutter run -d linux` sul PC.
Su **Linux e Mi A3**, stesse prove:
- Shuffle+ acceso su una playlist di ≥ 5 brani: il suggerito si mette in «Caricamento…», poi suona; dopo l'ascolto
  compare in Cronologia e Statistiche (R-12, R-29); testo e curiosità arrivano mentre suona (R-03).
- Modalità aereo a metà del download di un suggerito: un solo nuovo tentativo, poi messaggio e brano successivo (R-05).
- Impostazioni → «Spazio per lo streaming»: lo spazio usato cresce; «Svuota» lo azzera tranne il brano in corso e i 2 prossimi, che sono fissati (R-09).
- Il brano in streaming non compare in Brani, Album, Artisti, Home, ricerca della libreria (K-02).
- Log (Impostazioni → esporta log) senza 403/429 ripetuti dopo 30 minuti di Shuffle+ (K-04: la prova con un album di
  15 brani arriva con la fase 46, quando l'album online si può ascoltare).

**Fatto quando:** l'utente conferma le prove su Linux e Mi A3 (casella `[~]` → `[x]` in PROGRESS).
