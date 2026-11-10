# Libreria e dati

## Scopo

Tutto ciò che sta su disco: database drift/SQLite, scansione delle cartelle, tag, import di playlist, playlist e smart playlist, impostazioni, backup/ripristino, cache e pulizia. Il DB è la fonte di verità.

## Mappa del codice

| Cosa | Dove |
|---|---|
| Tabelle (24) | `lib/data/db/tables.dart` |
| DB, `kSchemaVersion`, `onUpgrade` | `lib/data/db/app_database.dart` |
| Tipi di brano | `lib/data/repositories/track_kinds.dart` (`kMusicKind`, `kEpisodeKind`, `kStreamKind`, `listenKinds`, `isRemoteEpisodePath`, `isHttpAddress`) |
| Brani | `lib/data/repositories/track_repository.dart` (`upsertBatch`, `fileIndexForFolder`, `markMissing`, `settleMovedCover`, `watchByRules`, `upsertStreamRow`, `mergeStreamRow`, `deleteUnplayedStreamRows`) |
| Playlist | `playlist_repository.dart` (`watchAll`, `watchTracks`, `addTracks`, `addStreamTracks`, `idByUuid`, `uuidOf`, `nameTaken`), `playlist_sync_repository.dart`, `hidden_playlists.dart` |
| Smart playlist | `smart_playlist_repository`, regole in `lib/services/library/rules/` (`rule_ast`, `rule_parser`, `rule_sql`, `rule_rewrite`, `rule_country`) |
| Altri repository | `data/repositories/`: `folder_`, `import_`, `podcast_`, `radio_`, `release_`, `follow_`, `credits_`, `track_genre_`, `play_history_`, `activity_log_`, `duplicate_`, `artist_*`, `tag_`, e le query (`library_queries`, `library_search`, `smart_search`, `stats_queries`, `home_sections`, `filter_counts_`, `review_queries`, `memory_queries`) |
| Scanner | `lib/services/scanner/library_scanner.dart` |
| Tag | `lib/services/tags/`: `TagReader` (`audio_metadata_tag_reader`), `TagWriter` (`metadata_god_tag_writer`), `SafeTagWriter`, `TagBackupStore`, `fingerprinter`, `mp3_length(_fix)`, `genre_reread` |
| Import playlist | `lib/services/import/` (`playlist_import_service`, `exportify_reader`, `exportify_zip`, `csv_parser`, `csv_profiles`, `m3u_reader`, `xspf_reader`, `playlist_reader`, `row_search`, `track_matcher`, `import_chain`, `import_diff`) |
| Daylist | `lib/services/daylist/` (`daylist_builder`, `daylist_slots`, `daylist_store`, `mood_table`) |
| Impostazioni | `lib/data/settings/settings_store.dart`, `lib/providers/settings_providers.dart`, `jam_secret_store.dart` |
| Backup | `lib/services/backup/` (`backup_service`, `restore_service`, `track_resolver`), `data/repositories/backup_merge`, `backup_queries` |
| Cache | `lib/services/memory/app_data.dart`, `lib/services/stream/stream_cache.dart`, `lib/providers/stream_providers.dart`, `lib/services/podcast/podcast_cleanup.dart` |
| Percorsi | `lib/core/paths.dart` (`databaseFile()` = `<documenti>/codecore.sqlite`) |
| Provider | `lib/providers/library_providers.dart` (`tagReaderProvider`, `libraryScannerProvider`, `scanStateProvider`, `ScanNotifier`, `tracksProvider`, ...), `database_providers.dart` |

## Come funziona

### Schema e migrazioni

- `AppDatabase.production()` apre `driftDatabase(name: 'codecore')`. `beforeOpen` imposta `PRAGMA foreign_keys = ON`.
- Tabelle registrate: `Tracks, Folders, Playlists, PlaylistTracks, PlaylistImports, PlaylistImportItems, Plays, SmartPlaylists, UserTags, TrackTags, Podcasts, PodcastEpisodes, ArtistInfos, RadioStations, FollowedArtists, ArtistReleases, ArtistLookups, TrackCredits, TrackEnrich, ActivityLogRows, TrackGenres, ArtistCountries, ArtistAliases, ArtistNotSame`.
- `kSchemaVersion = 19`. `onUpgrade` ha un `if (from < N)` per ogni salto:

| v | Cambio |
|---|---|
| 2 | `playlists.coverKey` |
| 3 | `replayGainDb` |
| 4-5 | tabelle import, `sourceKind`, `folderPath` |
| 6 | `resumePositionMs` |
| 8 | `ignored` |
| 9 | `kind` + podcast |
| 10 | playlist `uuid`, `updatedAt` |
| 11 | `artistInfos` |
| 12 | `radioStations` |
| 13 | tabelle uscite (`followedArtists`, `artistReleases`) |
| 14 | `isrc`, `year` negli item d'import |
| 15 | crediti, `trackEnrich`, registro, `coverSource` |
| 16 | `trackGenres`, `artistCountries` |
| 17 | `artistAliases`, `artistNotSame` |
| 18 | `podcasts.source`, `sourceId` |
| 19 | `podcasts.followed` |

- I passi 18 e 19 sono ripetibili: controllano `PRAGMA table_info('podcasts')` prima di `addColumn`.
- Dopo ogni modifica alle tabelle: `dart run build_runner build --delete-conflicting-outputs`.

### Tipi di brano (`tracks.kind`)

| kind | Costante | Significato |
|---|---|---|
| 0 | `kMusicKind` | Brano in libreria |
| 1 | `kEpisodeKind` | Episodio podcast (`path` = indirizzo http, forse con `#cc-ep=<id>`, o `stream:youtube:<guid>`) |
| 2 | `kStreamKind` | Riga ombra di un brano ascoltato in streaming |

- Ogni vista musicale filtra `kind = 0`.
- La riga ombra ha `path = 'stream:<key>'`, `folderId = null`, `sizeBytes = 0`, `mtimeMs = 0`.
- Storico e statistiche usano `listenKinds = [0, 2]`.
- Le playlist accettano 0 e 2 (D-524): `addStreamTracks` e `watchTracks` (`kind IN (0,2)` solo per le playlist).
- Ciclo di vita della riga ombra: `upsertStreamRow` la crea; dopo il download `mergeStreamRow` la fonde nella riga reale; `deleteUnplayedStreamRows` toglie quelle mai ascoltate.

### Album e copertine

- `albumKey` = `normalize(albumArtist ?? artist) + '|' + normalize(album)`; se l'album è vuoto o sconosciuto, `'unknown|' + normalize(dir)`.
- `coverKey` = SHA-1 di `albumKey`. Le copertine stanno in `<appSupportDir>/covers`. `CoverStore.saveFromBytes` salva sotto `sha1(key)`, quindi una copertina manuale non ha un prefisso `manual:` nel DB.
- `cover_source`: 0 automatica, 1 album a mano, 2 brano a mano.
- Ogni scrittura che cambia `album_key` passa da `settleMovedCover`.

### Scansione

`LibraryScanner(tags, tracks, covers, useIsolate: true)`:

- `scan(Folder)`: elenco ricorsivo, file nascosti saltati, solo `audioExtensions`.
- `scanFiles(folder, paths)`: scansione di file singoli, non marca mai `missing`.
- `_process` è incrementale: se `(path, size, mtime)` non cambia, non rilegge.
- Legge a gruppi di `_group = 50` con `Isolate.run`, scrive ogni `_flushAt = 100`.
- Marca `missing` solo se la radice è raggiungibile.

### Tag

- Lettura: `TagReader`. Scrittura: `TagWriter` dietro `SafeTagWriter`: copia, scrive, rilegge, confronta, salva il backup in `TagBackupStore`, rinomina in modo atomico. Le scritture sono in coda.
- Si scrive nei file solo se `fileWritesEnabled` = `writeTagsToFiles && tagsAlsoInFile` (`library_providers.dart`), via `TrackEditor.writeToFiles`.

### Import di playlist

- Sorgenti (`sourceKind`): exportify, tunemymusic, soundiiz, lastfm, csv, m3u, xspf. `PlaylistImportService`: `start`, `startFromResults`, `sync`, `pause`, `resume`, `cancel`, `retry`, `skip`, `download`, `startPlanned`.
- `track_matcher` decide il collegamento (`decide`, `scoreCandidate`, `MatchThresholds`, `LibraryIndex`, `matchTitleKey`).
- Stato dell'import in `playlist_imports`: 0 in corso, 1 in pausa, 2 finito, 3 annullato. Stato degli item: 0 da cercare, 1 in coda, 2 scaricato, 3 collegato, 4 da verificare, 8 pianificato.
- All'avvio gli import «in corso» diventano «in pausa» e gli item in coda tornano «da cercare».
- «Scarica album» crea una playlist nascosta (`visiblePlaylistSql`). `DownloadIndex` (`downloads.json`) mappa `<source>:<id>` al percorso.

### Playlist

- L'identità tra dispositivi è `uuid` (`idByUuid`, `uuidOf`). Il nome è unico (`nameTaken`).
- Smart playlist: `rules` salvate in forma canonica, `sort`, `limitCount`. La lista si calcola al volo con `watchByRules`. Il linguaggio delle regole è lo stesso della casella di ricerca.
- «Da Shazam»: `kShazamPlaylistName` in `providers/shazam_providers.dart`; `ShazamInbox.add(ShazamShare)` restituisce `ShazamAdded/Duplicate/NotFound/Retry`; impostazioni `shazamAutoDownload`, `shazamPlaylistUuid`.
- Daylist: `daylist_builder` compone per fasce (`daylist_slots`) e salva in `daylist.json` (`daylist_store`).

### Impostazioni

- `SettingsStore` avvolge `SharedPreferences`; `AppSettings` è immutabile con `copyWith`. `settingsProvider` scrive con debounce di 400 ms.
- Chiavi di sessione (`PlaybackPersistence`): `lastQueueIds`, `lastContextKind`, `lastContextName`, `lastQueueUser`, `lastIndex`, `lastPositionMs`. Altre: `volume`, `shuffle`, `repeat`, `transition`, `crossfadeSeconds`, `playbackSpeed`, `streamCacheMb`, `playlistSorts`, `trustedDevices`, `recordHistory`, ...
- Fuori da `AppSettings`: `releases*`, `radioDataNoticeSeen`, `radioRefreshedAt`, `genreRereadAfter/Done`.
- Segreti Jam: `PrefsJamSecretStore` (Android), `FileJamSecretStore` (desktop, `jam_secrets.json`), `MemoryJamSecretStore` (test).

### Backup e ripristino

`BackupService.createBackup` scrive `freekmusic-backup-YYYY-MM-DD.zip`:

| File | Contenuto |
|---|---|
| `manifest.json` | `backupFormat` (= `kBackupFormat` = 1), `schemaVersion`, `appVersion`, `createdAt`, `platform`, `deviceId`, `folders`, `trackCount` (senza kind 2), `playlistCount` |
| `settings.json` | voci tipate `{"t","v"}`, senza `kDeviceBoundKeys` |
| `user_data.json` | `UserData` (`collectUserData`): dati portabili, compresi generi, `artistCountries`, `artistAliases`, `artistNotSame`, romanizzazioni a mano, testi scritti a mano |
| `codecore.sqlite` | copia con `VACUUM INTO` |
| `downloads.json`, `dislikes.json`, `covers/*` | indici e copertine |

- Lo zip si crea in `Isolate.run`.
- `inspectBackup` rifiuta un `backupFormat` sconosciuto o un DB più nuovo.
- `stageFullRestore` estrae in `<appSupport>/restore` solo db, settings, dislikes, copertine; il marcatore `ready` è l'ultimo; protetto dal path traversal.
- `applyPendingRestore` gira all'avvio **prima** di aprire il DB: rinomina il DB attuale in `*.before-restore`, applica le impostazioni, fonde le copertine (i file esistenti vincono). Se fallisce, l'originale resta.
- `mergeBackup` («Unisci»): solo dati utente (`mergeUserData`). `TrackResolver` ritrova i brani per percorso relativo, poi metadati, poi sha256; se resta ambiguo dà null.
- «Sostituisci tutto» solo se `sameDevice`. I vecchi backup restano ripristinabili: i campi mancanti valgono vuoto. Il ripristino azzera `playlistSorts`.
- Legate al dispositivo (mai nel backup): `deviceId`, `deviceName`, `trustedDevices`, chiavi Jam, `enrichMarkKey`, `recogPassAfter/Done`, `genreRereadAfter/Done`.

### Cache e pulizia

- `AppDataKind`: covers, database, imageMemory, jamCache, searchCache, catalogCache, suggestions, blurCopies, tagBackups, log, podcasts, radio.
- `clearableKinds` = `imageMemory, jamCache, searchCache, catalogCache, suggestions, blurCopies, radio`. Copertine, DB e backup dei tag non si cancellano mai.
- `CacheCleaner.clear()` salta la cache Jam se un Jam è attivo; le radio salvate restano.
- `StreamCache`: cartella `<appSupportDir>/stream_cache`, LRU per mtime. Il costruttore ha 500 MB di default, ma l'impostazione `streamCacheMb` parte da 1024 (256-8192); margine libero 500 MB. `open()` toglie i `.part` e le cartelle `.dl-*`. Le pin proteggono brano corrente e successivo.
- `clearStreamCache` = `cache.clear(keep)` + `tracks.deleteUnplayedStreamRows(keepKeys)`: le righe con ascolti restano.
- Podcast: `podcast_cleanup.dart` (`autoDeleteDays`).
- Cache e cartella stream non si scansionano e non finiscono nel backup.

## Invarianti da non rompere

- Il DB è la fonte di verità; i file si toccano solo col doppio consenso dei tag.
- Mai cancellare righe utente in automatico: `missing = true`.
- Migrazioni mai distruttive; `kSchemaVersion` e `onUpgrade` si cambiano insieme; rigenerare con build_runner.
- Ogni vista musicale filtra `kind = 0`; storico e statistiche usano `listenKinds`.
- Ogni scrittura che cambia `album_key` passa da `settleMovedCover`.
- `artistKey` è un formato salvato (`artist_infos`, `artist_lookups`, `artist_countries`, `dislikes.json`, backup). Lo protegge `test/services/online/artist_key_test.dart`: cambiarlo richiede una migrazione.
- I valori di `PlayContextKind` sono solo in aggiunta (l'indice è salvato).
- La scansione non marca `missing` se la radice non è raggiungibile.
- Il ripristino si applica prima di aprire il DB. Un errore lascia l'originale.
- Lavoro pesante (tag, zip, miniature) in `Isolate.run`.

## Come si estende

- **Nuova colonna o tabella**: `tables.dart`, registrare in `@DriftDatabase`, alzare `kSchemaVersion`, aggiungere `if (from < N)` (controllare l'esistenza della colonna se il passo può ripetersi), build_runner, test di migrazione in `test/data`.
- **Nuovo dato nel backup**: aggiungerlo a `UserData` (`collectUserData`, `mergeUserData`), trattare l'assenza come vuoto, e se è legato al dispositivo aggiungere la chiave a `kDeviceBoundKeys`.
- **Nuova impostazione**: campo in `AppSettings` (`copyWith`), lettura/scrittura in `SettingsStore`, stringhe ARB nelle 6 lingue.
- **Nuovo campo di regola smart**: `RuleField` in `rule_ast.dart`, `rule_parser.dart`, `rule_sql.dart`; la ricerca lo eredita.
- **Nuova sorgente d'import**: reader in `services/import/` che produce righe `ImportRow`, profilo in `csv_profiles` se è CSV.
- **Nuovo tipo di dato ripulibile**: valore in `AppDataKind`, poi decidere se entra in `clearableKinds`.

## Trappole

Dalle vecchie trappole (archivio `../storico/gotchas.md`):

- `lower()` di SQLite è solo ASCII, quello di Dart no: confrontare con `lower(trim(?))` su entrambi i lati.
- Gli artisti della libreria sono raggruppati per credito completo (`creditedArtists`, D-95).
- `CoverStore.saveFromBytes` salva sotto `sha1(key)`: non aspettarsi `manual:` nel DB.
- Mai passare file grandi come `Uint8List` su un MethodChannel: usare `saveFileAt` (canale `codecore/save`).
- I segreti Jam stanno in `jam_secrets.json` su desktop.
- Test su Windows: `deleteSync` di un file aperto lancia.

## Decisioni chiave

Link a `../decisioni.md`:

- D-24: la UI non tocca il DB.
- D-79 / D-83: lo streaming conta nello storico ma non nei blocchi Home.
- D-81: cache degli stream e righe ombra.
- D-95: artisti raggruppati per credito completo.
- D-435 / D-470: `followed` dei podcast.
- D-524: le playlist accettano righe ombra (kind 2).
- D-539: rinomina; i nomi interni `codecore` restano.
