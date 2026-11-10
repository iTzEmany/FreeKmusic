# Riproduzione e coda

## Scopo

Lo stack audio, la coda (`PlayQueue`) con il blocco dell'utente, shuffle e ripetizione, riempimento «simili» e radio, gapless e crossfade, controlli di sistema (notifica, Android Auto, widget, tile, MPRIS, SMTC), timer di spegnimento, pausa a volume zero, riprese di posizione, podcast.

## Mappa del codice

| Cosa | Dove (`lib/`) |
|---|---|
| Interfaccia backend | `services/audio/audio_backend.dart` (`AudioBackend`, `BackendState`, `TransitionMode {normal, gapless, crossfade}`, `BackendException`, `GaplessCapable` con `setNext`/`park`) |
| Backend reale | `services/audio/just_audio_backend.dart` (`JustAudioBackend`; equalizzatore solo Android, `_AndroidEq`) |
| Crossfade | `services/audio/crossfade_engine.dart` (`CrossfadeEngine`, due backend, `MirrorEqualizer`) |
| Finestra del prossimo | `services/audio/next_window.dart` (`NextWindow`: `refresh`, `consume`, `invalidate`) |
| Coda | `services/audio/play_queue.dart` (`PlayQueue`) |
| Handler | `services/audio/codecore_audio_handler.dart` (`CodecoreAudioHandler extends BaseAudioHandler with SeekHandler`) |
| Persistenza | `services/audio/playback_persistence.dart` (`PlaybackPersistence`) |
| Riprese | `services/audio/resume_point.dart` |
| Voci online/radio | `services/audio/online_entries.dart` (`OnlineEntries`, `OnlineEntry`, `RadioEntry`) |
| Android Auto | `services/audio/media_browse_tree.dart` (`MediaBrowseTree`, `DbBrowseSource`, `BrowseLabels`) |
| Desktop | `mpris_controls`, `mpris_mapping` (Linux), `smtc_controls` (Windows), `system_media_controls` |
| Uscite audio | `speaker_monitor`, `bluetooth_outputs`, `output_route`, `equalizer` |
| Anteprima | `preview_player.dart` (`PreviewPlayer`, 20 s, backend separato) |
| Jam | `remote_transport.dart` (`RemoteTransport`, `RemoteStatus`) |
| Streaming | `services/stream/` (`stream_preparer`, `stream_promoter`, `stream_key`, `stream_cache`, `stream_enrich_trigger`) |
| Shuffle+ e simili | `services/shuffle_plus/` (`ShufflePlusController`, `RadioFill`, `RadioGate`, `SimilarQueue`, `SuggestionPool`, `SuggestionGate`, `SuggestionLog`, `DislikeStore`, `SeedIndex`, `SeedResolver`, `genre_mix`, `plus_allowed`, `insertion_plan`) |
| Provider | `providers/player_providers.dart`, `sleep_timer_provider.dart`, `volume_zero_pause_provider.dart`, `equalizer_providers.dart`, `speaker_providers.dart`, `shuffle_plus_providers.dart`, `stream_providers.dart` |
| Android nativo | `services/android/widget_sync.dart`, `widget_bridge.dart` (`PrefsWidgetBridge`); Kotlin `NowPlayingWidget`, `PlayTileService`, `WidgetStore`, `WidgetActionReceiver`, `VolumeBridge` |
| Podcast | `services/podcast/` |

Piattaforme: Android usa ExoPlayer via just_audio; Linux e Windows usano libmpv via `just_audio_media_kit` (inizializzato in `main.dart`).

## Come funziona

### Dalla lista alla coda

1. La UI chiama `PlayerController` (`playFromList`, `playAll`, `playMixed`, `playShufflePlus`, `playStations`, `playOnline`, `playFromSearch`, `enqueueOnline`, `playOnlineList`) con uno snapshot degli id.
2. `CodecoreAudioHandler.playQueue(ids, index)` riempie `PlayQueue` e chiama `_loadCurrent`.
3. `_loadCurrent` risolve l'id: negativo = voce online (`OnlineEntries`); se nel frattempo il brano è stato scaricato, suona il file di libreria, non lo stream (D-81).
4. Il backend carica; `NextWindow` tiene il prossimo brano allineato a `PlayQueue.peekNext()` e a `revision`.
5. A fine brano `_onCompleted` / `_onAdvanced` avanzano la coda.
6. Un errore di caricamento passa da `_failAndSkip`: salta al successivo, con un contatore di errori consecutivi (`maxConsecutiveErrors = 3`).

`PlayContextKind {album, artist, playlist, favorites, library, search, podcast, radio}` è solo in aggiunta: l'indice è salvato.

### `PlayQueue` e blocco utente

Campi: `_items`, `_keys` (chiavi mai riusate), `_natural` (ordine naturale per lo shuffle), `_history` (max 100), `_user` (blocco), `_currentFromUser`, `revision`.

Operazioni: `enqueue`, `next`, `previous`, `jumpTo`, `move`, `removeAt`/`removeId`, `putBack`, `insertAt`, `setItems(keepUser, userAhead, alreadyShuffled)`, `rebuildUpcoming`, `restoreState(QueueState)`, `peekNext`.

Regole del blocco:

- I1: le chiavi del blocco stanno in `_pos+1 .. _pos+userAhead`, nell'ordine di `_user`.
- I2: il brano corrente non è mai nel blocco.
- `_settle` ripristina entrambe dopo ogni operazione; `invariantError` è controllato da un test a operazioni casuali.
- `playQueue` mantiene il blocco (D-488); `playStations` lo azzera (D-496). Un brano del blocco già suonato diventa normale (D-492). `enqueue` aggiunge dopo il corrente (D-487).

### Shuffle e ripetizione

- `ShuffleMode {off, shuffle, plus}`; `cycleShuffle`, `cycleListShuffle` (D-534). `repeat` è un'impostazione.
- Shuffle+: `ShufflePlusController` inserisce brani secondo `insertion_plan`. Salta il blocco utente (`plusPlan(skip: userAhead)`).
- `plus_allowed` dice quando Shuffle+ è bloccato: `ShufflePlusBlock {jam, shortList, noTool, metered, stopped, online, radio}`.
- Skip = lasciare un brano prima degli ultimi 3 s (D-497).

### Simili e radio

- `SimilarQueue`: blocco da 10, riempie quando scende a 5, nuovo tentativo dopo 1 min. Il seme viene da Search (D-467).
- `RadioFill` passa da `RadioGate`: `minGap` 1 min, pausa 15 min dopo un 429.
- `SuggestionPool`, `SuggestionGate`, `SuggestionLog` e `DislikeStore` (`dislikes.json`) filtrano e ricordano i suggerimenti.

### Gapless e crossfade

- `transition`: `normal`, `gapless`, `crossfade` (`setTransition`). `crossfadeSeconds` 2-12 (default 6); `crossfadePlainInAlbum`.
- `CrossfadeEngine` usa due backend, rampa a potenza uguale in 20 passi, scambio a metà. Brani corti (< 2x la durata) e l'opzione «stesso album» ripiegano sulla finestra gapless.
- Un backend `GaplessCapable` riceve il prossimo con `setNext`; se la coda cambia, `NextWindow.invalidate`.
- Gapless da URL verso un brano in cache: D-142.

### Streaming

- `StreamPreparer` (`setQueue`, `ready`, `start`, `restart`, `cachedFile`): scarica al massimo 2 file insieme, prefetch di corrente + 2 successivi (3 su rete a consumo), 1 nuovo tentativo.
- Avvio rapido dall'URL (NewPipe su Android, riga yt-dlp altrove), il download in cache prosegue in parallelo, al replay si usa il file. Recupero da URL scaduto fino a 2 volte per brano (R-76), poi si aspetta il file.
- `StreamPromoter.promote` sposta dalla cache alla cartella download; la riga ombra diventa kind 0.
- In Jam non c'è streaming da URL: si aspetta il file in cache.
- Dettagli di rete e limiti in `online.md`.

### Notifica e controlli di sistema

- Android: `audio_service` (canale `com.freekmusic.player.audio`), Android Auto via `MediaBrowseTree`, widget 4x1 e tile (`WidgetSync` + `PrefsWidgetBridge`).
- Linux: `MprisControls().attach`. Windows: `SmtcControls().attach` (entrambi in `main.dart`).
- Jam: `attachRemote(RemoteTransport?)` instrada i tasti media al Jam (`hasRemote`).

### Timer di spegnimento

`SleepTimerNotifier` (`sleep_timer_provider.dart`): per minuti, con fade-out di 5 s in 25 passi via `setVolume` poi `pause`; oppure `startAtTrackEnd` → `handler.pauseAtTrackEnd`. Lo stream `pausedAtTrackEnd` lo azzera.

### Pausa a volume zero

`VolumeZeroPauseController` (impostazione `pauseOnZeroVolume`; D-504..D-509):

- Android legge il volume di sistema col canale `codecore/volume` (`VolumeBridge.kt`, ContentObserver); su desktop vale lo slider dell'app.
- Nessun effetto durante un Jam (`hasRemote`).
- La pausa decisa dall'app si dimentica al cambio uscita, a fine timer, a un play dell'utente o al cambio brano.

### Riprese e persistenza

- `PlaybackPersistence`: debounce 2 s; `savedQueue` scarta gli id online; salva `lastQueueUser`; `restore(applyPlus)`. All'avvio `restore` poi `start` (dopo il primo frame).
- `resume_point.dart`: `kResumeThreshold` 20 min (sotto non si salva), `kResumeEdge` 30 s, `kResumeRewind` 5 s, `kResumeSaveEvery` 15 s, `kSeekConfirm`; funzioni `resumePointFor`, `resumeStartFor`, `isPastEnd`.
- Posizione in `tracks.resume_position_ms`. Un episodio con posizione salvata compare in «Riprendi».

### Podcast

Gli episodi sono `kind = 1`. Soglie: `kEpisodeEdge` 10 s, `kEpisodeHeardAt` 0.95 (ascoltato). Ripresa come sopra. Pulizia in `podcast_cleanup.dart`.

### Ascolti e radio

- Conteggio ascolti: `_beginListen`, `_tickPlayed`, `_endListen` scrivono in `plays`.
- Radio: `playStations`, ritentativi e riconnessione, titolo in onda da ICY. Le stazioni sono `RadioEntry` con id negativo.

## Invarianti da non rompere

- La coda di riproduzione è separata dalla lista mostrata.
- I1 e I2 del blocco: ogni operazione di `PlayQueue` finisce in `_settle`. Le chiavi in `_keys` non si riusano.
- `test/services/audio/play_queue_characterization_test.dart` non si tocca.
- La UI parla solo con `PlayerController` e i provider, mai col backend.
- Il prossimo brano nel backend deve coincidere con `peekNext()`: dopo ogni modifica alla coda ricalcolare la finestra (`revision`).
- `savedQueue` non contiene id online (negativi).
- Nessun lavoro pesante sul thread UI.
- Aggiungere campi a `PlayerController` richiede di aggiornare gli spy dei test (vedi trappole).

## Come si estende

- **Nuovo punto d'ingresso di riproduzione**: metodo in `PlayerController` che costruisce gli id e chiama `handler.playQueue`; scegliere un `PlayContextKind` nuovo solo in coda all'enum.
- **Nuova operazione sulla coda**: in `PlayQueue`, mantenendo `_settle`; aggiungere il caso al test a operazioni casuali.
- **Nuovo backend o piattaforma**: implementare `AudioBackend` (+ `GaplessCapable` se supporta il prossimo) e collegarlo in `main.dart`.
- **Nuovo controllo di sistema**: come `MprisControls`/`SmtcControls`, agganciato in `main.dart` dopo l'handler.
- **Nuova causa di blocco di Shuffle+**: valore in `ShufflePlusBlock` e regola in `plus_allowed`.
- **Nuova soglia o impostazione audio**: `AppSettings` + `SettingsStore` + ARB, poi `handler` o controller che la legge.
- **Nuovo servizio in background**: provider tenuto vivo da `CodecoreApp`.

## Trappole

Dalle vecchie trappole (archivio `../storico/gotchas.md`):

- Uno spy di `PlayerController` basato su `noSuchMethod` va aggiornato quando si aggiungono campi.
- `MarqueeText` e le snackbar con anello (D-541) fanno scadere `pumpAndSettle`.
- Un `StreamProvider<void>` non rinotifica: emettere un contatore `int`.
- `ref.listen` su un provider derivato può vedere il valore vecchio: leggere la fonte diretta.
- Pausa a volume zero in background su Android: limite di circa 2 s.
- I receiver Bluetooth vogliono `RECEIVER_EXPORTED`.
- `IndexedStack` non ferma i ticker: usare `TickerMode`.
- Un `TextScaler` custom deve avere `==` e `hashCode`.
- `Semantics(excludeSemantics: true)` toglie il tap.
- Movimento ridotto via adb: servono 3 impostazioni di scala.
- Test instabili noti: `online_playback_test`, `smart_playlists_test`, `daylist_provider_test`, `shuffle_plus_test`, `seek_characterization`.
- Il `done` di `mqtt_client` può dare errore dentro `runZonedGuarded` (Jam).

## Decisioni chiave

Link a `../decisioni.md`:

- D-68: lo streaming funziona anche a consumo.
- D-81 / D-142: cache e righe ombra; gapless da URL verso un brano in cache.
- D-138..D-145: streaming veloce.
- D-467: `SimilarQueue`.
- D-483..D-497: blocco in coda (D-487 dopo il corrente, D-488 `keepUser`, D-492 blocco suonato diventa normale, D-496 radio azzera, D-497 cos'è uno skip).
- D-504..D-509: pausa a volume zero.
- D-86 / D-94: Shuffle+.
- D-534: shuffle della lista.
- D-541: snackbar.
