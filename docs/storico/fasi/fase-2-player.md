# Fase 2 — Motore audio, coda e notifica

**Obiettivo:** riprodurre brani in modo affidabile con coda, shuffle, repeat, seek, volume;
su Android con notifica/schermata di blocco/cuffie.
**Prerequisiti:** Fase 1. Regole chiave: coda **separata** dalla vista; repeat "off" **si ferma**; file mancante → errore gestito (mai riproduzione "finta").

## Task

### 2.1 — `PlayQueue` (logica pura)
**File:** `lib/services/audio/play_queue.dart`, `test/services/audio/play_queue_test.dart`
```dart
enum RepeatMode { off, all, one }
class PlayQueue {
  PlayQueue();
  void setItems(List<int> trackIds, {int startIndex = 0});   // azzera storia, rigenera ordine shuffle se attivo
  List<int> get items;               // ordine "naturale"
  int? get currentId;                // id brano corrente o null
  int get currentIndex;              // indice nell'ordine naturale (-1 se vuota)
  bool get shuffle;  set shuffle(bool v);   // attivarlo mantiene il brano corrente per primo
  RepeatMode repeat;
  int? next({bool auto = false});    // auto=true: fine brano naturale (rispetta repeat one)
  int? previous();                   // usa la storia; se vuota → brano precedente nell'ordine
  void jumpTo(int index);
  void removeAt(int index); void insertNext(int trackId); void append(int trackId);
}
```
Regole:
- `next(auto:true)` con `repeat == one` → stesso brano; con `off` all'ultimo → `null` (fine coda, **non** riparte); con `all` → primo.
- `next(auto:false)` (tasto "avanti") con `repeat == one` si comporta come `all`.
- Shuffle: ordine casuale calcolato **una volta** (Fisher–Yates) senza ripetizioni finché non si esauriscono; nessun `random` per brano.
- `previous()` torna al brano precedente realmente ascoltato (stack di storia, max 100).
**Verifica:** test: ≥ 12 casi (fine coda off/all/one, shuffle senza ripetizioni, previous con storia, removeAt del corrente, insertNext).

### 2.2 — Interfaccia `AudioBackend` (isola just_audio)
**File:** `lib/services/audio/audio_backend.dart`, `lib/services/audio/just_audio_backend.dart`
```dart
abstract class AudioBackend {
  Stream<Duration> get position;           // ~ 4 Hz
  Stream<Duration?> get duration;
  Stream<BackendState> get state;          // idle, loading, ready, playing, paused, completed, error
  Future<void> load(String filePath);      // lancia BackendException se il file non è riproducibile
  Future<void> play(); Future<void> pause(); Future<void> stop();
  Future<void> seek(Duration p); Future<void> setVolume(double v); // 0..1
  Future<void> dispose();
}
```
`JustAudioBackend` implementa con `AudioPlayer()`: `setFilePath`, mappa `processingState`/`playing` → `BackendState`,
`completed` solo quando `processingState == completed`. Verifica **prima** `File(path).exists()`; se no → `BackendException('file mancante')`.
**Verifica:** `flutter analyze`. (Il backend reale si prova a mano in 2.6.)

### 2.3 — `CodecoreAudioHandler`
**File:** `lib/services/audio/codecore_audio_handler.dart`
`class CodecoreAudioHandler extends BaseAudioHandler with SeekHandler` (da `audio_service`), costruito con
`AudioBackend`, `PlayQueue`, `TrackRepository`, e un callback `onError(String message)`.
Responsabilità:
1. `playQueue(List<int> ids, int index)` → `queue.setItems`, carica e riproduce il brano corrente.
2. Su `BackendState.completed` → `queue.next(auto: true)`; se `null` → `stop`, `playbackState` = idle/ended, `currentId = null`.
3. Su errore di caricamento → `onError(...)`, **salta al brano successivo** (massimo 3 salti consecutivi, poi stop).
4. Aggiorna `mediaItem` (titolo, artista, album, `artUri = Uri.file(coverPath)` se esiste, `duration`) e `playbackState`
   (controlli: previous, play/pause, next; `processingState`, `playing`, `updatePosition`, `speed: 1`).
5. Override `play`, `pause`, `stop`, `seek`, `skipToNext`, `skipToPrevious`, `skipToQueueItem`, `setShuffleMode`, `setRepeatMode`.
6. `togglePlayPause()` basato sullo **stato reale** del backend. Se la coda è vuota non fa nulla.
7. Incrementa `playCount` e `lastPlayedAt` quando si supera il 50% del brano o 30 s (una sola volta per riproduzione).
8. Nessun `Timer` di polling: tutto da stream.
**Verifica:** test con `AudioBackend` finto (stream controllabili): completamento → avanza; errore → salta; repeat off all'ultimo → idle.

### 2.4 — Inizializzazione per piattaforma
**File:** `lib/main.dart`, `lib/providers/player_providers.dart`, `android/app/src/main/AndroidManifest.xml`, `MainActivity.kt`
1. Android: `AudioService.init(builder: () => handler, config: AudioServiceConfig(androidNotificationChannelId: 'com.codecore.player.audio', androidNotificationChannelName: 'Riproduzione', androidNotificationOngoing: true, androidStopForegroundOnPause: true))`.
2. Desktop: **non** chiamare `AudioService.init`; istanzia il handler direttamente.
3. `audioHandlerProvider` restituisce il handler (override in `ProviderScope` dopo l'init in `main`).
4. Manifest (seguire il README di `audio_service` della versione installata): permessi `FOREGROUND_SERVICE`,
   `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`, `POST_NOTIFICATIONS`; `<service>` `com.ryanheise.audioservice.AudioService`
   con `foregroundServiceType="mediaPlayback"`; `<receiver>` `MediaButtonReceiver`; `MainActivity` estende `AudioServiceActivity`.
5. Android 13+: richiedi `Permission.notification` al primo avvio della riproduzione (non bloccare se negato).
**Verifica manuale (telefono):** avvia un brano, spegni lo schermo 5 min: continua; i tasti della notifica e delle cuffie funzionano.

### 2.5 — Provider di stato e controller
**File:** `lib/providers/player_providers.dart`
- `PlayerController` (wrapper sottile sul handler): `playFromList(List<Track> snapshot, int index)`, `togglePlayPause`, `next`, `previous`, `seek`, `setVolume`, `toggleShuffle`, `cycleRepeat`.
- `currentTrackProvider` (StreamProvider<Track?>), `isPlayingProvider`, `positionProvider` (stream a 4 Hz, **separato**),
  `durationProvider`, `queueProvider` (lista di `Track` della coda), `shuffleProvider`, `repeatProvider`.
- `playFromList` salva **solo gli id**; il player risolve i brani via repository (nessuna copia dell'intera lista in memoria UI).
**Verifica:** `flutter analyze`.

### 2.6 — Persistenza e prova manuale
**File:** `lib/services/audio/playback_persistence.dart`
1. Salva (debounce 2 s) `lastQueueIds`, `lastIndex`, `lastPositionMs`, `volume`, `shuffle`, `repeat`.
2. All'avvio ripristina la coda **in pausa** (non partire da soli) e posizionati sul punto salvato.
3. Aggiungi alla schermata di debug della fase 1 i bottoni Play/Pausa/Avanti/Indietro e uno slider (seek **solo** su `onChangeEnd`).
**Checklist manuale (tutta, su Linux e telefono):**
- [ ] MP3, FLAC, M4A, OGG/OPUS, WAV partono
- [ ] Seek preciso; nessuno scatto trascinando (seek solo a fine trascinamento)
- [ ] Fine brano → avanza; ultimo brano con repeat off → si ferma
- [ ] File cancellato a metà coda → messaggio d'errore e salta al successivo
- [ ] Shuffle: nessun brano ripetuto prima di averli sentiti tutti
- [ ] (Android) schermata di blocco, cuffie Bluetooth play/pausa, chiamata in arrivo mette in pausa

## Definition of Done
- [ ] Test `PlayQueue` (≥ 12) e handler (≥ 4) verdi
- [ ] Checklist manuale superata su Linux; su Android almeno schermo spento + notifica
- [ ] `docs/PROGRESS.md` aggiornato

> Nota: gapless, crossfade, normalizzazione e output esclusivo **non** sono in questa fase (vedi fase 7).
