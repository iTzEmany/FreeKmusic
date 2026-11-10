# Fase 1 — Dati e scansione della libreria

**Obiettivo:** il DB esiste, l'app sa scansionare una cartella (desktop e Android), leggere i tag,
estrarre le copertine e mostrare l'elenco in una schermata di debug.
**Prerequisiti:** Fase 0 completata. Leggi `03-modello-dati.md`.

## Task

### 1.1 — Tabelle drift
**File:** `lib/data/db/tables.dart`, `lib/data/db/app_database.dart`
1. Definisci `Tracks`, `Folders`, `Playlists`, `PlaylistTracks` esattamente come in `03-modello-dati.md`
   (nomi colonna in camelCase, `BoolColumn` con default, indici con `@TableIndex`).
2. `AppDatabase extends _$AppDatabase`, `schemaVersion => 1`, costruttore con `QueryExecutor` (per i test in memoria).
   Produzione: `driftDatabase(name: 'codecore')` (da `drift_flutter`). Abilita `PRAGMA foreign_keys = ON` in `beforeOpen`.
3. `dart run build_runner build --delete-conflicting-outputs`.
**Verifica:** compila; test `test/data/app_database_test.dart` apre un DB in memoria (`NativeDatabase.memory()`) e inserisce/legge una riga.

### 1.2 — `TagReader` + implementazione
**File:** `lib/services/tags/tag_reader.dart`, `lib/services/tags/audio_metadata_tag_reader.dart`
1. Interfaccia:
```dart
class TagInfo {
  final String? title, artist, albumArtist, album, genre;
  final int? trackNumber, discNumber, year, durationMs, bitrateKbps, sampleRateHz, bitDepth, channels;
  final List<int>? coverBytes;      // prima immagine incorporata
  final String? coverMime;
}
abstract class TagReader { Future<TagInfo> read(String path, {bool withCover = true}); }
```
2. `AudioMetadataTagReader` usa `audio_metadata_reader` (`readMetadata(File, getImage: withCover)`).
   Controlla i nomi reali dei campi nel sorgente del pacchetto. Durata mancante → `null` (non 0).
3. Se la lettura lancia eccezione: **non** propagare; restituisci `TagInfo` vuoto e `AppLog.w(path, e)`.
**Verifica:** test con un piccolo MP3 e un FLAC di fixture in `test/fixtures/` (genera file brevi con `ffmpeg` o chiedi all'utente di copiarne due). Se non disponibili, test con `TagReader` finto e nota in PROGRESS.

### 1.3 — Repository
**File:** `lib/data/repositories/track_repository.dart`, `folder_repository.dart`
Metodi minimi di `TrackRepository`:
- `Future<void> upsertBatch(List<TracksCompanion> rows)` — in una sola transazione, `insertOnConflictUpdate` su `path`,
  **preservando** `isFavorite`, `lyrics*`, `curiosities`, `userEdited`, `playCount`, `addedAt` (usa `onConflict` con `DoUpdate` che aggiorna solo i campi "da file").
- `Future<Map<String, ({int size, int mtime})>> fileIndexForFolder(int folderId)` — per la scansione incrementale.
- `Future<void> markMissing(Set<String> paths, bool missing)`.
- `Stream<List<Track>> watchTracks({String query = '', SortOption sort, bool favoritesOnly = false})`.
- `Future<Track?> getById(int id)`, `Future<List<Track>> getByIds(List<int> ids)` (mantiene l'ordine richiesto).
- `Future<int> countAll()`.
`FolderRepository`: `add(path)`, `remove(id)`, `watchAll()`, `getAll()`.
**Verifica:** test su DB in memoria: upsert due volte lo stesso path non duplica e non azzera `isFavorite`; ricerca con `%` letterale non fa match errati.

### 1.4 — Scanner
**File:** `lib/services/scanner/library_scanner.dart`
1. `class LibraryScanner { LibraryScanner(this._tags, this._tracks, this._covers); Stream<ScanProgress> scan(Folder f) }`.
2. Algoritmo (vedi "Scansione incrementale" in `03`):
   a. Se la cartella radice non esiste/non è leggibile → emetti `ScanProgress.failed(...)` e **non** toccare il DB.
   b. Elenca ricorsivamente i file (`Directory.list(recursive: true, followLinks: false)`), salta cartelle che iniziano con `.`
      e file nascosti. Estensioni ammesse: `mp3 flac wav ogg oga opus m4a aac aiff aif wma`.
   c. Per ogni file ottieni `size` e `mtime`; confronta con `fileIndexForFolder`. Invariati → salta.
   d. Nuovi/modificati: leggi tag con `TagReader` **in un isolate** (`Isolate.run` o `compute` su gruppi di ~50 file; ogni isolate crea il proprio reader).
   e. Costruisci `TracksCompanion` (titolo fallback = nome file senza estensione; `albumKey` con `computeAlbumKey`).
   f. Salva a blocchi di 100 con `upsertBatch`; emetti `ScanProgress(done, total, currentPath)`.
   g. Alla fine: file nel DB per quella cartella ma non trovati sul disco → `markMissing(true)`; file `missing` ritrovati → `false`.
3. Gestione errori per singolo file: log e continua (un file corrotto non interrompe la scansione).
**Verifica:** test con cartella temporanea e `TagReader` finto: (1) prima scansione inserisce N brani; (2) seconda non rilegge i tag
(conta le chiamate al reader = 0); (3) cancellando un file diventa `missing`; (4) cartella radice inesistente non marca nulla missing.

### 1.5 — Copertine
**File:** `lib/services/covers/cover_store.dart`
1. `Future<String?> saveFromBytes(String albumKey, List<int> bytes, String? mime)` → scrive `<coversDir>/<sha1(albumKey)>.jpg|png` solo se non esiste; ritorna `coverKey`.
2. `Future<String?> findFolderCover(String dir)` → cerca `cover|folder|front|album` + `.jpg|.jpeg|.png` (case-insensitive).
3. `File? fileFor(String coverKey)`.
4. Integra nello scanner: per ogni `albumKey` nuovo, usa l'immagine incorporata del primo brano, altrimenti la cover di cartella; imposta `hasCover`/`coverKey` su **tutti** i brani di quell'album.
5. Limite: se i bytes > 4 MB scarta e logga (evita immagini enormi).
**Verifica:** test: stesso album con 3 brani → 1 solo file in cache; album senza cover → `hasCover=false`.

### 1.6 — Provider
**File:** `lib/providers/*.dart`
`databaseProvider`, `trackRepositoryProvider`, `folderRepositoryProvider`, `tagReaderProvider`, `coverStoreProvider`,
`libraryScannerProvider`, `scanStateProvider` (Notifier che avvia la scansione e espone `ScanProgress`),
`trackQueryProvider` (StateProvider con testo/ordinamento) e `tracksProvider` (StreamProvider che osserva il repository).
**Verifica:** `flutter analyze`.

### 1.7 — Permessi Android e cartella predefinita
**File:** `android/app/src/main/AndroidManifest.xml`, `lib/core/permissions.dart`
1. Manifest: `READ_MEDIA_AUDIO`; `READ_EXTERNAL_STORAGE` con `android:maxSdkVersion="32"`.
2. `Future<bool> ensureAudioPermission()`: su Android richiede `Permission.audio` e `Permission.storage` e
   considera concesso se **almeno uno** è `granted`; su desktop ritorna `true`.
3. Se negato in modo permanente: ritorna `false` e la UI mostrerà il pulsante "Apri impostazioni" (`openAppSettings()`).
**Verifica manuale (telefono):** al primo avvio compare la richiesta e dopo la concessione la scansione di `/storage/emulated/0/Music` trova i file.
Se l'elenco Android è vuoto pur con permesso concesso → vedi fallback in `99-rischi-e-fallback.md` (R2).

### 1.8 — Schermata di debug (temporanea)
**File:** `lib/ui/screens/debug_library_screen.dart`
Bottoni "Scegli cartella" (`file_picker.getDirectoryPath`) e "Scansiona"; barra di avanzamento; contatore brani;
lista semplice (`ListView.builder`) con titolo/artista e se `hasCover` una miniatura 48×48.
Sarà sostituita nella fase 3. Imposta come `home`.
**Verifica manuale (Linux):** scegli una cartella con ≥ 50 brani → vedi l'elenco; riavvia l'app → l'elenco appare subito e
una seconda scansione termina in pochi secondi.

## Definition of Done
- [ ] Test verdi: DB, repository, scanner (4 casi), cover store
- [ ] Scansione di 1000+ file non blocca la UI (verifica a occhio: la barra si muove)
- [ ] Nessun brano perso quando la cartella non è raggiungibile
- [ ] `docs/PROGRESS.md` aggiornato
