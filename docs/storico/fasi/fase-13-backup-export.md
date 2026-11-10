# Fase 13 — Backup, ripristino ed export

**Obiettivo:** playlist, preferiti, testi, modifiche e importazioni non vivono più **solo** nel DB del dispositivo.
L'utente crea un **backup** in un file `.zip` e lo ripristina sullo stesso dispositivo (dopo una reinstallazione)
o su un altro (telefono nuovo, PC). Le playlist si **esportano** in M3U8, CSV (colonne Exportify) e JSON.
In più: «Esporta log» per segnalare un problema senza dati personali.
**Prerequisiti:** Fasi 0–12 (schema v4, `downloads.json`, `PlaylistImports`).
**Principio:** nessuna rete. Nessun file musicale entra nel backup e nessun file dell'utente viene cancellato:
il ripristino **aggiunge e unisce**, non toglie (regola 6).

## Decisioni
| Tema | Scelta |
|---|---|
| Contenuto del backup | `manifest.json` · `codecore.sqlite` (copia coerente con `VACUUM INTO`) · `settings.json` (shared_preferences) · `covers/` · `downloads.json` · `user_data.json` (formato portabile) |
| Cosa resta fuori | File musicali, `codecore.log`, cache della Jam, `deviceId` e `deviceName` (identità del dispositivo) |
| Formato portabile | `user_data.json` (versione `format: 1`): dati utente con riferimenti ai brani **per percorso relativo alla cartella radice + titolo/artista/durata**, non per `id`. È lo stesso formato che userà la sincronizzazione della **fase 24** |
| Ripristino — stesso dispositivo | Manifest con le stesse cartelle radice raggiungibili → si sostituisce il DB **al riavvio** (file di staging), poi le migrazioni normali |
| Ripristino — altro dispositivo | Unione da `user_data.json`: brano riconosciuto per percorso relativo → poi titolo+artista (`matchKey`) e durata ±2 s; i non riconosciuti si elencano, non si inventano |
| Backup più nuovo dell'app | `schemaVersion` del manifest > `AppDatabase.schemaVersion` → rifiuto con messaggio «aggiorna l'app» |
| Export playlist | M3U8 (percorsi assoluti o relativi alla cartella del file), CSV con le intestazioni di Exportify (rientra con l'import di fase 12), JSON (stesso schema del formato portabile, solo playlist) |
| Dove si salva | Android: `FilePicker.saveFile(fileName:, bytes:)` (SAF; restituisce un `Uri`, file_picker 13.1). Desktop: `FilePicker.getDirectoryPath()` + scrittura a flusso (niente zip intero in memoria) |
| Pacchetti nuovi | `archive` (zip in puro Dart) **(da approvare con l'utente prima del task 13.1)** |
| Schema DB | Invariato (v4) |

## Task

### 13.1 — Verifiche preliminari
1. Chiedi all'utente l'approvazione di `archive`; poi `flutter pub add archive` e annota la versione in PROGRESS.
2. Percorso reale del DB: `driftDatabase(name: 'codecore')` (drift_flutter 0.3.1, `lib/src/native.dart`) usa
   `getApplicationDocumentsDirectory()` → annota il percorso del file su Linux e Android (`adb shell run-as`).
3. `VACUUM INTO '<tmp>/x.sqlite'` funziona con il `sqlite3` incluso (prova in un test con DB su file temporaneo).
4. Misura `covers/` sul Mi A3 e sul PC (MB). Se > 150 MB su Android, `saveFile` con tutti i byte in memoria è a
   rischio: annota e usa il piano B (zip scritto in `getExternalStorageDirectory()/Backup` + percorso mostrato).
5. Prova `FilePicker.saveFile` su Android con 20 MB di byte finti: il file compare nella cartella scelta?
**Verifica:** note in PROGRESS. Se `archive` non viene approvato o `VACUUM INTO` fallisce, **fermati e riporta**.

### 13.2 — Formato portabile `user_data.json` (logica pura)
**File:** `lib/services/backup/user_data.dart`, `test/services/backup/user_data_test.dart`
1. Classi immutabili con `toJson`/`fromJson`:
   ```dart
   class TrackRef { final String? folder; final String? relPath; final String title; final String? artist;
                    final int durationMs; final String? sha256; }
   class TrackUserData { final TrackRef ref; final bool favorite; final TrackEditData? edit; // solo se userEdited
                         final String? lyricsPlain, lyricsSynced, curiosities; final int playCount; final int? lastPlayedAt; }
   class PlaylistData { final String name; final int createdAt; final String? coverKey; final List<TrackRef> items; }
   class UserData { final int format; final int createdAt; final List<TrackUserData> tracks;
                    final List<PlaylistData> playlists; final List<ImportData> imports; }
   ```
2. Solo i brani con almeno un dato utente (preferito, modifica, testo, ascolti, in una playlist) finiscono in `tracks`.
3. `format` sconosciuto (> 1) → `FormatException`; campi sconosciuti ignorati (compatibilità in avanti).
**Test:** andata e ritorno JSON; brano senza dati utente escluso; `format: 2` rifiutato; campo extra ignorato.

### 13.3 — Estrazione dei dati utente dal DB
**File:** `lib/data/repositories/backup_queries.dart`, `test/data/backup_queries_test.dart`
1. `Future<UserData> collectUserData(AppDatabase db)`: legge `tracks`, `folders`, `playlists`/`playlist_tracks`
   (in ordine di `position`), `playlist_imports`/`playlist_import_items`. `relPath` = percorso relativo alla cartella
   di `folderId` (`p.relative`); brano fuori da ogni cartella → `relPath` null, resta il percorso assoluto in `folder`.
2. Una sola transazione di lettura; niente query per riga (join o mappe in memoria).
**Test:** DB in memoria con 2 cartelle, 3 playlist, un brano modificato, un testo, un'importazione: tutto presente,
ordine delle playlist conservato.

### 13.4 — Riconoscere i brani al ripristino (logica pura)
**File:** `lib/services/backup/track_resolver.dart`, `test/services/backup/track_resolver_test.dart`
1. `TrackResolver(List<LibraryEntryLite> lib, Map<int, String> relPathById)`; aggiungi `path` a `LibraryEntryLite`
   (`lib/core/import_row.dart`, `TrackRepository.liteEntries`) se serve.
2. `int? resolve(TrackRef r)`: (a) stesso `relPath` (confronto senza distinzione `/` `\` e maiuscole su Windows);
   (b) `matchKey` di titolo e artista principale (`track_matcher.dart`) e durata ±2 s; (c) `sha256` se entrambi noti.
   Più candidati in (b) → quello con durata più vicina; parità → nessuno (meglio «non trovato» che sbagliato).
**Test:** stesso percorso con cartella radice diversa; percorso Windows vs Linux; solo titolo/artista; due omonimi con
durate diverse; parità → null.

### 13.5 — Creare il backup
**File:** `lib/services/backup/backup_service.dart`, `test/services/backup/backup_service_test.dart`
1. `Future<BackupSummary> createBackup(BackupTarget target)`:
   `VACUUM INTO` in un file temporaneo → `settings.json` da `SharedPreferences.getKeys()` (tipi conservati; esclusi
   `deviceId`, `deviceName`) → `manifest.json` `{backupFormat: 1, schemaVersion, appVersion: kAppVersion, createdAt,
   platform, deviceId, folders: [...]}` → `user_data.json` (13.3) → zip con `covers/` e `downloads.json`.
2. Compressione in `Isolate.run` (copertine già compresse: `store` per `.jpg/.png`, deflate per il resto).
3. Nome: `codecore-backup-AAAA-MM-GG.zip`. Il file temporaneo si cancella sempre (`finally`), è nostro.
**Test:** backup di un DB su file temporaneo: lo zip contiene i 6 elementi, `settings.json` senza `deviceId`,
il DB copiato si apre con drift ed ha gli stessi conteggi.

### 13.6 — Ripristino sullo stesso dispositivo (sostituzione al riavvio)
**File:** `lib/services/backup/restore_service.dart`, `lib/main.dart`, `test/services/backup/restore_service_test.dart`
1. `RestorePlan inspect(File zip)`: legge il manifest; `sameDevice` = `deviceId` uguale **oppure** tutte le cartelle
   del manifest esistono. Rifiuta `backupFormat` sconosciuto e `schemaVersion` maggiore di quella dell'app.
2. `stageFullRestore(zip)`: estrae in `<appSupport>/restore/` (`codecore.sqlite`, `settings.json`, `covers/`).
3. In `main.dart`, **prima** di `AppDatabase.production()`: `applyPendingRestore()` rinomina il DB attuale in
   `codecore.sqlite.before-restore` (non lo cancella), sposta quello nuovo, scrive le impostazioni, unisce `covers/`
   (non sovrascrive file esistenti), poi rimuove la cartella di staging. Errore → log `AppLog.e` e DB originale intatto.
4. Dopo lo staging l'app chiede il riavvio: desktop «Chiudi l'app e riaprila», Android `SystemNavigator.pop()`.
**Test:** staging + `applyPendingRestore` su cartelle temporanee: DB sostituito, copia di sicurezza presente,
staging rimosso; zip con `schemaVersion` 99 → rifiutato; staging corrotto → DB originale invariato.

### 13.7 — Ripristino su un altro dispositivo (unione)
**File:** `restore_service.dart`, `lib/data/repositories/backup_queries.dart` (+ test)
1. `Future<MergeReport> merge(UserData d)` in una transazione: preferito = OR; modifica applicata solo se il brano
   locale non è già `userEdited`; testi/curiosità solo se vuoti in locale; `playCount` = massimo, `lastPlayedAt` = più recente.
2. Playlist: nome libero → creata; nome esistente → «<nome> (ripristinata)». Elementi non riconosciuti → saltati
   e contati. Le importazioni **non** si uniscono (dipendono dai download dell'altro dispositivo).
3. Copertine dello zip copiate in `covers/` senza sovrascrivere; `resetCovers` non serve.
4. `MergeReport`: brani riconosciuti / non trovati (elenco titoli), playlist create, preferiti aggiunti.
**Test:** unione su DB in memoria: preferito unito, modifica locale non sovrascritta, playlist omonima rinominata,
brano assente contato in «non trovati», nessuna riga cancellata.

### 13.8 — Interfaccia: sezione «Backup» nelle Impostazioni
**File:** `lib/ui/screens/settings/backup_section.dart` (nuovo: `settings_screen.dart` è già oltre 400 righe),
`lib/ui/screens/settings/restore_dialog.dart`, `lib/providers/backup_providers.dart`, ARB
1. Voci «Crea backup» e «Ripristina da backup»; avanzamento nel Centro Attività (`ActivityKind` nuovo `backup`).
2. Ripristino: `FilePicker.pickFiles` (zip; su Android filtro inaffidabile → controlla l'estensione dopo) → `inspect`
   → dialogo con data, versione, numero di brani/playlist e **due scelte esplicite**: «Sostituisci tutto (stesso
   dispositivo)» (solo se `sameDevice`, con conferma) e «Unisci a questa libreria».
3. Esito dell'unione in un foglio con l'elenco «non trovati» (copiabile).
**Verifica:** widget test del dialogo con piano finto (le due scelte, «Sostituisci» assente se `!sameDevice`).
**Tocca a te:** backup sul Mi A3 → disinstalla/reinstalla → ripristino «Sostituisci»: playlist, preferiti e testi
tornano; backup del telefono ripristinato sul PC con «Unisci».

### 13.9 — Esportazione delle playlist (logica pura)
**File:** `lib/services/export/playlist_exporter.dart`, `lib/services/import/csv_parser.dart` (aggiunta `writeCsv`),
`test/services/export/playlist_exporter_test.dart`
1. `String writeCsv(List<List<String>> rows)` (RFC 4180, `\r\n`, virgolette solo se servono).
2. `toM3u8(String name, List<Track> t, {String? relativeTo})`: `#EXTM3U`, `#PLAYLIST:`, `#EXTINF:<s>,<artista> - <titolo>`,
   percorso assoluto o relativo (`p.relative`, separatore `/`).
3. `toExportifyCsv(List<Track> t, Map<int, String> isrcByTrack)`: intestazioni `Track URI, Track Name, Album Name,
   Artist Name(s), Duration (ms), ISRC`; artisti separati da `;`; ISRC dalle righe d'importazione se note.
4. `toJson` = `PlaylistData` di 13.2.
**Test:** M3U8 relativo/assoluto; CSV con virgole e virgolette; **giro completo**: `toExportifyCsv` → `readExportify`
restituisce le stesse righe.

### 13.10 — Interfaccia di esportazione
**File:** `playlist_detail_screen.dart` (menu ⋮), `lib/ui/screens/playlists/export_dialog.dart`, `library_screen.dart`
(menu ⋮), ARB
1. Voce «Esporta…» nel menu della playlist → dialogo: formato (M3U8 / CSV / JSON), per M3U8 «percorsi relativi»,
   poi salvataggio (Android `saveFile`, desktop cartella scelta).
2. «Esporta tutte le playlist» nel menu della Libreria: uno zip con un file per playlist nel formato scelto.
**Verifica:** widget test del dialogo; scatti a 100 % e 150 %.

### 13.11 — «Esporta log»
**File:** `lib/core/log_export.dart`, `test/core/log_export_test.dart`, sezione «Informazioni» delle Impostazioni, ARB
1. `String redactLog(String text, {required String home, String? deviceName})`: percorso home → `~`, nome utente
   in `/home/<u>` o `C:\Users\<u>` → `<utente>`, IPv4/IPv6 → `<ip>`, `deviceName` → `<dispositivo>`, PIN e token
   (`pin=`, `token=`, `x-jam-file`) → `***`.
2. Unisce `codecore.log.1` + `codecore.log` (ordine cronologico), aggiunge in testa versione app e piattaforma, salva
   `codecore-log-AAAA-MM-GG.txt`. Nota: in debug `AppLog` non scrive su file → voce disabilitata con spiegazione.
**Test:** ogni regola di mascheramento con righe vere del log (copiate dalle note di PROGRESS).

### 13.12 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es completi.
2. `docs/02-architettura.md` (cartelle `services/backup`, `services/export`, flusso di ripristino al riavvio),
   `docs/99-rischi-e-fallback.md` (R24–R26), README («Backup e ripristino», «Esportare una playlist»).
3. Prestazioni: backup di una libreria sintetica di 20.000 brani e 2.000 copertine < 15 s su PC, UI fluida.
**Tocca a te:** Linux + Mi A3 — scenario di 13.8, export M3U8 aperto in VLC, CSV reimportato con l'import di fase 12,
«Esporta log» letto a mano (nessun percorso personale).

## Fuori da questa fase
Backup automatici pianificati, backup su cloud, cifratura del backup, sincronizzazione continua tra dispositivi (fase 24),
import M3U/XSPF (fase 15).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R24 | Ripristino che corrompe o perde il DB | Staging + sostituzione solo al riavvio; il DB precedente resta come `.before-restore`; migrazioni normali |
| R25 | Brani riconosciuti male su un altro dispositivo | Percorso relativo prima, poi titolo+artista+durata ±2 s; parità → «non trovato»; elenco mostrato all'utente |
| R26 | Backup troppo grande per `saveFile` su Android (tutto in memoria) | Misura in 13.1; piano B: zip scritto in una cartella dell'app con percorso mostrato |

## Definition of Done
- [ ] Backup zip creato da Impostazioni su Android e Linux; nessun file musicale dentro, nessun `deviceId`
- [ ] Ripristino «Sostituisci» sullo stesso dispositivo e «Unisci» su un altro, con elenco dei non riconosciuti
- [ ] Export di una playlist in M3U8, CSV (reimportabile con la fase 12) e JSON; export di tutte le playlist
- [ ] «Esporta log» senza percorsi personali, IP, PIN o token
- [ ] Test: formato portabile, estrazione, resolver, backup, staging/ripristino, unione, exporter (giro CSV), mascheramento log
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
