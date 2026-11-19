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
| Video karaoke | `services/karaoke_video/` (`KaraokeVideoGate`, `KaraokeVideoController`, `syncStep`, `KaraokeVideoPort`/`MediaKitVideoPort`), `providers/karaoke_video_providers.dart` (`karaokeVideoProvider`); nel gestore `videoGate`, `_seekHold`, `_seekGen` |
| Karaoke | `providers/karaoke_providers.dart` (`karaokeProvider`, `karaokeBypassProvider`, `karaokeButtonVisibleProvider`, base e separazione), `services/karaoke/separation_service.dart`; UI in `ui/widgets/karaoke_sheet.dart` |

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
- `insertAt` non entra mai nel blocco: un indice dentro il blocco finisce subito dopo. `move` verso l'interno o subito dopo il blocco ci entra, altrove ne esce. Lo shuffle rimescola solo il resto: `_settle` rimette il blocco subito dopo il corrente. `previous` e `jumpTo` lasciano il blocco subito dopo il nuovo corrente (D-493, D-494). La scheda coda titola «Prossimi in coda» e «Poi» (D-495).
- `_settle` ripristina entrambe dopo ogni operazione; `invariantError` è controllato da un test a operazioni casuali.
- `playQueue` mantiene il blocco (D-488); `playStations` lo azzera (D-496). Un brano del blocco già suonato diventa normale (D-492). `enqueue` inserisce in `_pos+1+userAhead`: dopo il corrente e dietro le aggiunte precedenti, in ordine di arrivo (D-487).

### Shuffle e ripetizione

- `ShuffleMode {off, shuffle, plus}`; `cycleShuffle`, `cycleListShuffle` (D-534). `repeat` è `PlayQueue.repeat` (`PlayRepeat {off, all, one}`), salvato anche in `AppSettings.repeat`.
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

### Karaoke (fasi 128 e 130, D-618..D-624)
- Il filtro della voce in tempo reale è stato tolto (D-624, fase 130): niente `VoiceFilter`, `KaraokeController`, copie di `just_audio` in `third_party/` (tornano i pacchetti di pub.dev). Resta solo la separazione AI («Alta qualità», sotto), che c'è solo su Android; il microfono (`karaokeButtonVisibleProvider`) compare solo dove c'è il motore e mai in una Jam (D-623). Bypass su episodi, radio e video karaoke (`karaokeBypassProvider`): nessuna base (l'audio del video è già la base, D-639), compresi hook `karaokeSource` e precarico.
- **«Alta qualità» (fase 128, D-618..D-622, solo Android).** `services/karaoke/separation_service.dart`: modelli Spleeter 2-stem scaricati alla prima richiesta (Hugging Face, revisione fissa, sha256) in `models/spleeter-2stems-7001ba31/`; il lavoro va al canale `codecore/separation` (`SeparationBridge.kt`, `SpleeterDsp.kt`: decodifica MediaCodec, STFT, ONNX Runtime da Kotlin su un thread a priorità bassa, base WAV scritta a pezzi, limite 20 min). La base finisce in `StreamCache` con chiave `karaoke:<chiave stream>` o `karaoke:local:<id>:<mtime>`. Il gestore consulta l'hook `karaokeSource` in `_loadCurrent` e `_nextFile`; `karaokeChanged()` invalida la finestra gapless e ricarica il brano alla stessa posizione senza ricontare l'ascolto (`sameTrack`). Fase 130 (D-625..D-627): la separazione salva base e voce (`karaoke:base:…`, `karaoke:voice:…`; base + voce = originale); il cursore «Voce» al rilascio chiede `mixFor` (mix nativo `mix` = base + livello × voce, chiave `karaoke:mix:…:<passo di 5 %>`, 100 % = originale, 0 % = base) e il gestore ricarica alla stessa posizione. Le chiamate native passano da una sola coda in Dart (un mix aspetta la separazione); `MixResult` distingue originale, file, fallito, superato: un mix fallito lascia suonare ciò che c'è. File del karaoke fissati (pin) mentre suonano o si mescolano, e cancellati 15 minuti dopo l'ultimo uso (`StreamCache.expire`, controllo ogni 2 min). «Mostra il karaoke» (Impostazioni › Riproduzione) spento nasconde il microfono e spegne il karaoke; con rete a consumo il foglio avvisa del download del modello o del brano da scaricare per intero. **Avvio automatico (D-629):** accendere il karaoke separa subito il brano in ascolto e a ogni cambio brano riparte da solo (la riga «Alta qualità» non c'è più; in caso di errore il foglio dà un messaggio e «Riprova», senza ripetizioni automatiche). Con rete a consumo, se serve il modello o il brano intero, il foglio mostra il costo e «Avvia» (`karaokeConfirmedProvider`). `karaokeAutoProvider` (radice dell'app) poi separa uno alla volta, in ordine, i brani messi in coda a mano (`handler.userAhead` dopo `currentIndex`) che hanno già un file locale o in cache, e ne fissa base e voce finché restano in coda; spento, non parte altro ma il lavoro nativo in corso finisce. Tempi: Motorola edge 40 circa 50 s per 4:20 (con il primo download del modello); Redmi Note 9 Pro (Snapdragon 720G) circa 38 s di separazione per 4 min più ~20 s di preparazione, cambio di livello sotto 1 s.

### Video karaoke (fase 131, D-632, D-646, D-647)
- L'audio resta quello di sempre (coda, notifica, cuffie, Android Auto). Il video è un secondo player media_kit muto (`aid=no`), uno per caricamento, che segue l'audio, unico orologio (D-156): `syncStep` fa seek del video oltre 300 ms di scarto, al più uno ogni 2 s; un seek dell'utente passa sempre.
- Il gestore parla col video solo tramite `KaraokeVideoGate`, collegato da `karaokeVideoProvider` (letto in `main.dart` se `kEnableYoutube`).
- `beforePlay(track, start)` in `_loadCurrent`, prima di `play()`: se risponde un Future il gestore mostra `loading` (`_waitingStream`) e aspetta il primo fotogramma al massimo 10 s, poi suona comunque; pausa o ▶ nel frattempo cambiano solo il desiderio. Brano senza video: null, nessuna attesa.
- `afterSeek(pos)`: se suonava, pausa del backend, attesa del video al massimo 3 s e ripresa. Intanto `_seekHold` fa ignorare a `_onBackendState` pausa e play (stato mostrato «in riproduzione», nessun punto di ripresa salvato); `_seekGen` fa cedere l'attesa a un seek o a un caricamento più nuovo.
- Un brano karaoke non entra mai nella finestra gapless (`_nextFile`), anche con `karaokeSource`.
- In background il video si ferma e l'audio no; al ritorno si riallinea o chiede un indirizzo nuovo se `expire` è passato. Un errore: nuovo indirizzo; due errori di fila (contatore azzerato a `ready`): `failed`, suona solo l'audio con l'avviso.

### Streaming

- `StreamPreparer` (`setQueue`, `ready`, `start`, `restart`, `cachedFile`): scarica al massimo 2 file insieme (`maxParallel`), prefetch al massimo dei 3 brani dopo il corrente, per posizione in coda (`StreamItem.pos`), e su rete a consumo 0 se `prefetchOnMobile` è spento (D-609), 1 nuovo tentativo. Il gestore gli passa fino a 30 righe di libreria (`_lookupAhead`).
- Senza rete il gestore salta al primo brano con un file (`_skipOffline`, `preparer.isOnline` dalla sonda di rete); la coda ingrigisce le righe con `queueOfflineOutProvider` (D-577).
- Avvio rapido dall'URL (NewPipe su Android, riga yt-dlp altrove), il download in cache prosegue in parallelo, al replay si usa il file. Recupero da URL scaduto fino a 2 volte per brano (R-76), poi si aspetta il file.
- `StreamPromoter.promote` sposta dalla cache alla cartella download; la riga ombra diventa kind 0.
- In Jam non c'è streaming da URL: si aspetta il file in cache.
- Dettagli di rete e limiti in `online.md`.

### Notifica e controlli di sistema

- Android: `audio_service` (canale `com.freekmusic.player.audio`), Android Auto via `MediaBrowseTree`, widget 4x1 e tile (`WidgetSync` + `PrefsWidgetBridge`).
- Linux: `MprisControls().attach`. Windows: `SmtcControls().attach` (entrambi in `main.dart`).
- Jam: `attachRemote(RemoteTransport?)` instrada i tasti media al Jam (`hasRemote`).
- Tasti: `click(media)` (85, HEADSETHOOK, widget, tile) → `togglePlayPause()`; 126 e 127 arrivano come `play`/`pause` dalla copia di `audio_service` (`third_party/`). `pause()` senza brano caricato non pubblica nulla.
- Sessione viva in Jam: `_showRemote` non pubblica mai `idle`; `attachRemote(null)` ricalcola dal player locale (`idle` solo senza brano).
- `play()` a freddo (processo ucciso, tasto cuffie): senza coda ricorda `_playOnRestore`, e il `restore()` della coda salvata parte suonando; `pause()` lo annulla.
- Chiusura dopo 30 minuti (solo Android, `stopServiceWhenIdle`, R-228): in pausa senza Jam e senza stream in attesa `_idleTimer` (`idleParkAfter`) chiama `_park()`: salva la ripresa e pubblica `idle` (il servizio si ferma, la notifica sparisce) senza toccare coda, brano e posizione; `play()` o un Jam la riattivano (`_parked`).

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
- Il video non comanda mai l'audio, salvo l'attesa del gate, sempre con un limite di tempo. Ogni nuovo ingresso al karaoke AI deve saltare `isKaraokeVideo`.

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
- **Hook del karaoke in `_loadCurrent`**: va dopo la pubblicazione dello stato di caricamento, dentro il `try`; nessun `await` prima del ramo dello stream (`_waitingStream`), altrimenti `online_playback_test` si rompe (fase 128).
- Il `done` di `mqtt_client` può dare errore dentro `runZonedGuarded` (Jam).
- **`waitUntilFirstFrameRendered` di un `VideoController` si completa una volta sola per tutta la sua vita**: Player e VideoController nuovi a ogni caricamento.
- **`volume 0` e `muted` non bastano per il video: serve `aid=no`** (F-2).
- **Test del gestore con `karaokeSource` impostato**: la finestra gapless va provata con l'hook che risponde null (il caso reale di Android).
- **Test di cache e controller del video**: niente attese a tempo dove si può (`StreamCache.touch` usa l'orologio vero).

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
- D-632, D-646, D-647: video muto sincronizzato e attesa dell'audio.
