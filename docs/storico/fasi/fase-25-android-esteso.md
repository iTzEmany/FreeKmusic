# Fase 25 — Android esteso: widget, tile rapida, Android Auto, Wear OS, modalità in auto

**Obiettivo:** controllare Codecore fuori dall'app su Android: un **widget** «in riproduzione» sulla home, una
**tile rapida** nelle impostazioni veloci, **Android Auto** con navigazione della libreria, controlli da **Wear OS**
e una **modalità in auto** dentro l'app (pulsanti grandi) per chi non ha Android Auto.
**Prerequisiti:** Fase 2 (`CodecoreAudioHandler` + `audio_service`), Fase 11 (Now Playing), Fase 17 (controlli della
Jam in notifica: stesso modello di comandi), Fase 16 (CI che compila l'APK).
**Principio:** tutto passa dalla **sessione media** che `audio_service` già pubblica: widget, tile, auto e orologio
mandano comandi all'handler, non toccano DB o file. Nessun lavoro in background aggiuntivo: il widget si aggiorna
solo quando cambia lo stato del player. Desktop e iOS non sono toccati.

## Decisioni
| Tema | Scelta |
|---|---|
| Widget | Un widget 4×1 (copertina, titolo, artista, ⏮ ⏯ ⏭) e uno 2×2 (copertina grande + ⏯). Layout `RemoteViews` in XML; pulsanti = `PendingIntent` verso `com.ryanheise.audioservice.MediaButtonReceiver` con il tasto multimediale (nessun motore Flutter da avviare per un tocco) |
| Dati del widget | Titolo, artista, percorso della copertina (già in cache in `<appSupportDir>/covers/`) e stato play/pausa, scritti dal lato Dart a ogni cambio di brano/stato; bitmap ridotta a 256 px lato Kotlin |
| Tile rapida | `TileService` in Kotlin (nessun pacchetto): un tocco = play/pausa via tasto multimediale; etichetta = titolo in riproduzione; stato attivo/inattivo |
| Android Auto | Albero di navigazione di `audio_service` (`getChildren`, `getMediaItem`, `playFromMediaId`, `search`): radice = Preferiti · Playlist · Album · Più ascoltati · Ultimi aggiunti. Liste limitate a 200 voci (regola delle app per auto) |
| Wear OS | Nessuna app per l'orologio: si usano i **controlli multimediali di sistema** che Wear OS mostra per la sessione del telefono. Si verifica e si documenta; un'app Wear dedicata è fuori scope |
| Modalità in auto | Schermata a pieno schermo dentro l'app: copertina, titolo, 3 pulsanti da ≥ 96 dp, Preferito, «Playlist» con al massimo 6 voci grandi. Si apre a mano (menu di Now Playing); nessuna attivazione automatica |
| Pacchetti nuovi | `home_widget` **(da approvare con l'utente prima del task 25.2)**. Se non approvato: canale `codecore/widget` scritto da noi (`MethodChannel` + `SharedPreferences` Android), stessa struttura |

## Task

### 25.1 — Verifiche preliminari
1. Leggi in `~/.pub-cache/hosted/pub.dev/audio_service-0.18.19/lib/audio_service.dart` le firme reali di
   `getChildren`, `getMediaItem`, `playFromMediaId`, `search`, `subscribeToChildren` e i campi di
   `AudioServiceConfig` per la navigazione (`androidBrowsableRootExtras`, ecc.). Annota in PROGRESS.
2. Con l'app **chiusa** (force-stop), invia `adb shell cmd media_session dispatch play-pause` e
   `input keyevent 85`: il servizio di `audio_service` riparte e suona l'ultimo brano? Annota: è la base per
   widget e tile «a freddo».
3. Installa **Desktop Head Unit** (DHU) dall'SDK Manager (Android Auto → modalità sviluppatore sul telefono →
   «Avvia server unità principale»). **Fermati e chiedi** se serve accettare licenze o installare software di sistema.
4. `home_widget`: controlla nel sorgente le API (`saveWidgetData`, `updateWidget`, nome del provider Android) e la
   compatibilità con `compileSdk = 37`.
**Verifica:** note in PROGRESS; se a freddo il tasto multimediale non riprende la riproduzione, i pulsanti del widget
aprono l'app (piano B, vedi R63).

### 25.2 — Ponte dati verso il widget (lato Dart)
**File:** `lib/services/android/widget_bridge.dart`, `lib/providers/player_providers.dart` (+ test)
1. `WidgetBridge.update(WidgetSnapshot s)` con `title`, `artist`, `coverPath`, `playing`; implementazione Android
   (`home_widget` o canale nostro), implementazione vuota su desktop.
2. Provider che ascolta `currentTrackStream` e lo stato di riproduzione dell'handler e chiama `update` **solo se lo
   snapshot cambia** (niente aggiornamenti a ogni tick di posizione).
**Test:** con bridge finto: un aggiornamento per brano/stato, nessuno per la posizione.

### 25.3 — Widget Android (lato Kotlin)
**File:** `android/app/src/main/kotlin/com/codecore/player/NowPlayingWidget.kt`,
`android/app/src/main/res/layout/widget_now_playing_4x1.xml`, `widget_now_playing_2x2.xml`,
`res/xml/widget_now_playing_*_info.xml`, `AndroidManifest.xml`, `res/values*/strings.xml`
1. `AppWidgetProvider` che legge lo snapshot e imposta i `RemoteViews`; copertina decodificata con
   `inSampleSize` a ≤ 256 px; segnaposto se assente.
2. Pulsanti → `PendingIntent` broadcast verso `MediaButtonReceiver` con `KEYCODE_MEDIA_PREVIOUS/PLAY_PAUSE/NEXT`
   (o apertura dell'app se 25.1 ha dato esito negativo); tocco sulla copertina → apre l'app.
3. Colori dai toni dell'app (sfondo nero/viola), testo bianco, angoli 16 dp.
**Verifica:** `flutter build apk --debug` riuscito. **Tocca a te:** aggiungere entrambi i widget sulla home del
telefono, cambio brano dall'app e dal widget, app chiusa → tocco su ⏯.

### 25.4 — Tile rapida
**File:** `android/app/src/main/kotlin/com/codecore/player/PlayTileService.kt`, `AndroidManifest.xml`
(`BIND_QUICK_SETTINGS_TILE`), icona vettoriale, stringhe
1. `onClick` → tasto multimediale play/pausa (come il widget).
2. `onStartListening` → stato e etichetta dai dati salvati in 25.2 (stessa fonte del widget).
3. Aggiornamento richiesto con `TileService.requestListeningState` quando cambia lo snapshot.
**Verifica:** build riuscita. **Tocca a te:** aggiungere la tile, play/pausa da app aperta e chiusa.

### 25.5 — Albero di navigazione (logica pura)
**File:** `lib/services/audio/media_browse_tree.dart`, `test/services/audio/media_browse_tree_test.dart`
1. `MediaBrowseTree` (separato dall'handler, che è già oltre le 300 righe): id stabili `root`, `fav`, `playlists`,
   `playlist:<id>`, `albums`, `album:<albumKey>`, `top`, `recent`, `track:<id>@<contesto>`.
2. `children(parentId)` → `List<MediaItem>` (cartelle `playable: false`, brani `playable: true`, `artUri` della
   copertina), al massimo 200; `resolve(mediaId)` → (`List<int>` coda, indice di partenza) secondo il contesto.
3. Usa solo i repository esistenti (`LibraryQueries`, `PlaylistRepository`, `TrackRepository`): niente query nuove
   se non servono.
**Test:** radice con 5 voci, playlist → brani in ordine, `resolve` di un brano di album → coda dell'album dall'indice
giusto, limite 200, id sconosciuto → lista vuota.

### 25.6 — Android Auto
**File:** `codecore_audio_handler.dart` (override che delegano a `MediaBrowseTree`), `main.dart`
(`AudioServiceConfig`), `android/app/src/main/res/xml/automotive_app_desc.xml`, `AndroidManifest.xml`
1. Override di `getChildren`, `getMediaItem`, `playFromMediaId` (→ `playQueue`), `search` (ricerca SQL esistente,
   max 50 risultati).
2. Manifest: `meta-data com.google.android.gms.car.application` → `automotive_app_desc` con `uses name="media"`;
   il servizio `AudioService` esporta già `MediaBrowserService`.
3. Icona monocromatica per l'auto.
**Verifica:** test di 25.5 verdi; build riuscita. **Tocca a te (DHU o auto reale):** navigare Preferiti/Playlist/
Album, avviare un brano, ricerca vocale/testo, comandi dal volante, copertine visibili.

### 25.7 — Wear OS (verifica, nessun codice nuovo previsto)
1. **Tocca a te:** orologio Wear OS abbinato al telefono → durante la riproduzione compaiono i controlli multimediali
   con titolo e copertina? Play/pausa, avanti, volume funzionano? Annota in PROGRESS.
2. Se i controlli non compaiono: verificare che la sessione abbia `MediaItem` con `artUri` e che le azioni siano
   pubblicate (`_publish` nell'handler); correggere solo lì.
**Verifica:** nota in PROGRESS con modello di orologio e esito.

### 25.8 — Modalità in auto nell'app
**File:** `lib/ui/screens/car/car_mode_screen.dart`, `now_playing_screen.dart` (voce di menu), ARB
1. Schermata con fondo `CoverBackdrop`, copertina, titolo/artista grandi, ⏮ ⏯ ⏭ ≥ 96 dp, ♥, «Playlist» (foglio con
   ≤ 6 voci grandi: Preferiti + le 5 playlist più recenti), uscita con un pulsante grande.
2. Schermo sempre acceso finché è aperta solo se l'utente lo attiva (canale Kotlin `FLAG_KEEP_SCREEN_ON`, nessun pacchetto).
3. Testo a 150 % senza overflow.
**Verifica:** widget test di fumo; scatti a 100 % e 150 %.

### 25.9 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es (e `strings.xml` Android per widget/tile: it/en/de/es).
2. `docs/02-architettura.md` (sessione media come unico punto di comando, `MediaBrowseTree`, widget/tile),
   `docs/99-rischi-e-fallback.md` (R63–R65), README («Widget, tile, Android Auto»).
**Tocca a te:** giro completo sul telefono: widget e tile con app aperta, in background e chiusa; DHU con 10 minuti
di riproduzione; Wear OS; modalità in auto in macchina (luce del giorno, tocchi con una mano).

## Fuori da questa fase
App Wear OS autonoma, Android Automotive OS (auto con Android integrato, richiede revisione Google), widget per
desktop, Jam controllata dall'auto, comandi vocali personalizzati.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R63 | Tasto multimediale a freddo non riavvia la riproduzione (motore Flutter non attivo) | Verifica in 25.1; piano B: i pulsanti del widget/tile aprono l'app |
| R64 | Android Auto rifiuta l'app o non la mostra (app installata fuori dal Play Store) | DHU in modalità sviluppatore + «Origini sconosciute» nelle impostazioni sviluppatore di Android Auto; documentare i passi |
| R65 | Widget non aggiornato o batteria consumata | Aggiornamento solo su cambio di snapshot, mai sulla posizione; nessun `updatePeriodMillis` |

## Definition of Done
- [ ] Widget 4×1 e 2×2 con copertina e controlli funzionanti
- [ ] Tile rapida play/pausa
- [ ] Android Auto: navigazione, avvio brano, ricerca, comandi dal volante (provato su DHU o auto)
- [ ] Wear OS verificato e documentato
- [ ] Modalità in auto nell'app
- [ ] Test: `MediaBrowseTree`, ponte del widget
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
