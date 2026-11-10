# Fase 17 — Riproduzione: velocità, segnalibri, anteprima, equalizzatore, controlli di sistema

**Obiettivo:** il lettore guadagna le funzioni «da tutti i giorni» che mancano: **velocità** 0,5×–2× senza effetto
paperino, **«riprendi da qui»** per le tracce lunghe, **anteprima di 20 s** tenendo premuta una copertina,
**equalizzatore** con preset, **controlli multimediali di sistema anche su desktop** (MPRIS su Linux, SMTC su
Windows) e i **controlli della Jam** nella notifica e nella schermata di blocco di Android.
**Prerequisiti:** Fasi 2 (handler, `AudioBackend`), 8–10 (Jam), 11 (Now Playing, `TrackRow`), 16 (build Windows in CI,
serve per provare SMTC).
**Principio:** tutto passa da `CodecoreAudioHandler` e dall'interfaccia `AudioBackend`; nessun widget parla con
`just_audio`. La Jam ha il suo backend (`jamBackendFactoryProvider`) e **non** eredita velocità, segnalibri ed
equalizzatore del lettore locale: la sincronia della fase 10 usa già `setSpeed` per correggere la deriva.

> Schema DB: questa fase porta a **v6** (dopo la v5 della fase 15). Se una fase precedente con schema non è stata
> fatta, usa la prossima versione libera e adatta il test di migrazione.

## Decisioni
| Tema | Scelta |
|---|---|
| Velocità | Valori fissi 0,5 · 0,75 · 1 · 1,25 · 1,5 · 1,75 · 2; **globale** in `AppSettings.playbackSpeed`, torna a 1× con un tocco; il tono resta quello originale (verifica 17.1) |
| Segnalibro | Solo brani ≥ **20 min** (`kResumeThreshold`); salvato in `tracks.resume_position_ms` a pausa, cambio brano, uscita e ogni 15 s di riproduzione; si azzera negli ultimi 30 s o a fine brano; ripartenza 5 s prima del punto salvato |
| Anteprima | Pressione prolungata **sulla copertina** di una riga brano o di una scheda album (la pressione sul resto della riga resta il menu `trackActions`); 20 s da un terzo del brano; secondo `AudioBackend` come la Jam; il lettore principale va in pausa e riprende al rilascio. Desktop: anche voce «Anteprima 20 s» nel menu |
| Equalizzatore | Android: `AndroidEqualizer` di `just_audio` (bande del dispositivo, spesso 5) in un `AudioPipeline`. Desktop: solo se `just_audio_media_kit` permette di impostare il filtro mpv (`af`) — oggi `MediaKitPlayer` non espone il `Player`: verificare in 17.1, altrimenti la voce non compare su desktop |
| Preset | Piatto · Bassi · Voce · Acuti · Personalizzato; guadagni in dB salvati in `AppSettings` |
| Profilo per uscita | Cuffie / altoparlante solo su Android e **senza pacchetti nuovi**: tipo di uscita da `AudioManager.getDevices` via `MethodChannel` esistente in `MainActivity.kt`. Desktop: un solo profilo |
| MPRIS / SMTC | Interfaccia nostra `SystemMediaControls` (attach agli stream `mediaItem`/`playbackState` dell'handler, comandi verso l'handler). Implementazioni scelte in 17.1 tra: pacchetto `audio_service_mpris` oppure MPRIS scritto da noi su D-Bus con `dbus` (puro Dart); Windows `smtc_windows` |
| Jam nella notifica | Durante una Jam l'handler mostra il brano della Jam e inoltra play/pausa/avanti al `JamController` (permessi di `applyCommand`: l'ospite non salta). «Termina Jam» come azione personalizzata se `audio_service` lo consente, altrimenti resta nella notifica del `ReceiveService` |
| Pacchetti nuovi | Candidati **(da approvare con l'utente prima del task 17.7)**: `audio_service_mpris` *oppure* `dbus` (Linux), `smtc_windows` (Windows, richiede Rust nel runner). Nessun pacchetto per velocità, segnalibri, anteprima, equalizzatore |

## Task

### 17.1 — Verifiche preliminari
1. **Velocità e tono.** Su Linux (mpv) e sul telefono (ExoPlayer) riproduci `test/fixtures/sample.mp3` a 1,5× e 0,75×
   con uno script di prova temporaneo (fuori da `lib/`) e ascolta: il tono resta uguale? Leggi
   `~/.pub-cache/hosted/pub.dev/just_audio_media_kit-2.1.0/lib/just_audio_media_kit.dart` (`pitch = true` usa
   `scaletempo` e spegne `audio-pitch-correction`) e decidi se servono `JustAudioMediaKit.pitch = false` o
   `setPitch(1.0)` esplicito. **Attenzione:** cambiare questa opzione tocca anche il backend della Jam: rilancia
   `test/jam/` e, se possibile, la misura acustica di 10.9.
2. **Equalizzatore.** In `just_audio-0.10.6/lib/just_audio.dart`: `AudioPipeline`, `AndroidEqualizer`,
   `AndroidEqualizerParameters` (bande, minimo/massimo in dB, `setGain`). In `just_audio_media_kit` cerca un modo di
   passare `af` a mpv (`setProperty` è su `NativePlayer` di `media_kit`, il `Player` è privato in `MediaKitPlayer`).
   Annota: desktop sì/no.
3. **MPRIS/SMTC.** Su pub.dev leggi pagina, licenza, ultima versione e piattaforme di `audio_service_mpris`, `dbus`,
   `smtc_windows`. Dopo l'approvazione dell'utente aggiungili e leggi il sorgente in `~/.pub-cache`. Annota se
   `audio_service_mpris` richiede `AudioService.init` anche su Linux (oggi `main.dart` lo chiama solo su Android, R4).
4. **Jam e `audio_service`.** In `audio_service-0.18.19` verifica `MediaControl.custom` / `customAction` e come la
   notifica si comporta se `playbackState.playing` è vero ma il player dell'handler è fermo (suona il backend Jam).
**Verifica:** note in PROGRESS con le scelte. Se il tono cambia con la velocità e non c'è modo di correggerlo,
**fermati e riporta**. Se nessun pacchetto MPRIS/SMTC è utilizzabile, 17.7–17.8 diventano «rimandati» (annota).

### 17.2 — Velocità di riproduzione
**File:** `settings_store.dart`, `codecore_audio_handler.dart`, `player_providers.dart`,
`lib/ui/screens/now_playing/now_playing_controls.dart`, `desktop_player_bar.dart`, ARB, test dell'handler
1. `AppSettings.playbackSpeed` (default 1.0, chiave `playbackSpeed`). `CodecoreAudioHandler.setSpeed(double)` lo
   applica al backend e lo riapplica dopo ogni `load` (alcuni backend lo azzerano).
2. `_publish` usa la velocità vera (oggi `speed: 1`): la notifica e MPRIS calcolano la posizione giusta.
3. UI: chip «1×» in Now Playing e nella barra desktop → foglio con i 7 valori; chip evidenziato se ≠ 1×.
4. Il timer di spegnimento (`sleep_timer_provider.dart`) conta tempo reale, non tempo di brano: nessuna modifica,
   ma annotalo nel testo dell'aiuto.
**Test:** `test/services/audio/codecore_audio_handler_test.dart` con `test/support/fake_backend.dart`: la velocità
sopravvive a un cambio brano; `playbackState.speed` aggiornato.

### 17.3 — Segnalibro «riprendi da qui» (schema v6)
**File:** `tables.dart` (+ `build_runner`), `app_database.dart`, `track_repository.dart`, `codecore_audio_handler.dart`,
`test/data/migration_test.dart`, test dell'handler, `docs/03-modello-dati.md`
1. Colonna `IntColumn resumePositionMs` nullable su `tracks`; `schemaVersion` 6, `if (from < 6) addColumn`.
2. `TrackRepository.setResumePosition(int id, int? ms)`.
3. Handler: per brani con `durationMs ≥ 20 min` salva su pausa, cambio brano, `stop` e ogni 15 s (throttle, mai a ogni
   tick di posizione); in `_loadCurrent` usa `resumePositionMs − 5 s` come `startAt` se non c'è già una posizione
   esplicita (la ripresa di `PlaybackPersistence` ha la precedenza). Negli ultimi 30 s o su `completed` → `null`.
4. Riga brano: piccolo indicatore «riprendi da 42:10» sotto il titolo per i brani con segnalibro; voce del menu
   «Ricomincia dall'inizio» (azzera e riparte).
**Test:** migrazione v5 → v6 con dati intatti; handler: salva dopo 15 s, riprende al riavvio, azzera a fine brano,
non salva per brani < 20 min.

### 17.4 — Anteprima di 20 secondi
**File:** `lib/services/audio/preview_player.dart`, `lib/providers/preview_providers.dart`, `track_row.dart`,
`album_card.dart`, `track_actions.dart`, test
1. `PreviewPlayer(AudioBackend Function() factory)`: `start(Track t)` carica il file, seek a `durata / 3`, volume 0 →
   1 in 300 ms, stop automatico a 20 s (rampa di uscita 300 ms); `stop()`; un'anteprima nuova chiude la precedente.
2. `previewProvider`: prima di partire mette in pausa il lettore principale **solo se suonava** e lo riprende alla fine;
   la coda (`PlayQueue`) e il conteggio ascolti non cambiano. Con una Jam attiva l'anteprima è disabilitata.
3. `TrackRow`: `GestureDetector` sulla copertina con `onLongPressStart`/`onLongPressEnd`; il resto della riga resta
   com'è. `AlbumCard`: anteprima del primo brano. Feedback: anello che si riempie sulla copertina in 20 s.
4. Desktop: voce «Anteprima 20 s» nel menu `trackActions` (si ferma con Esc o con un altro clic).
**Test:** `PreviewPlayer` con backend finto (seek a un terzo, stop a 20 s con fake async); provider: il lettore
principale riprende solo se suonava, la coda è identica prima e dopo.

### 17.5 — Equalizzatore: motore
**File:** `lib/services/audio/equalizer.dart`, `just_audio_backend.dart`, `audio_backend.dart`, `settings_store.dart`, test
1. Interfaccia `Equalizer` (`bands` con frequenza centrale e limiti, `setEnabled`, `setGains(List<double> dB)`);
   `AudioBackend.equalizer` restituisce `null` dove non è supportato (desktop salvo esito diverso di 17.1, backend finto).
2. `JustAudioBackend` su Android crea l'`AudioPlayer` con `AudioPipeline(androidAudioEffects: [eq])`. Il backend
   della Jam **non** riceve l'equalizzatore (costruttore con parametro, default spento).
3. Preset in logica pura: `List<double> presetGains(EqPreset p, List<double> centerHz)` (interpola i preset definiti
   su 10 bande verso le bande reali del dispositivo) con limiti clampati.
4. `AppSettings.eqEnabled`, `eqPreset`, `eqCustomGains` (lista di double, chiave per profilo — vedi 17.6).
**Test:** `presetGains` su 5 e 10 bande, clamp ai limiti, «Piatto» = tutti 0.

### 17.6 — Equalizzatore: interfaccia e profilo per uscita
**File:** `lib/ui/screens/settings/equalizer_screen.dart`, `settings_screen.dart`, `MainActivity.kt`,
`lib/core/platform.dart` (o `lib/services/audio/output_route.dart`), ARB
1. Schermata: interruttore, preset a chip, cursori verticali per banda (valore in dB), «Reimposta». Si apre da
   Impostazioni → Riproduzione e dal menu ⋯ di Now Playing. Su piattaforme senza equalizzatore la voce non c'è.
2. Android: metodo `outputRoute` sul canale esistente → `headphones` (cablate/Bluetooth/USB) o `speaker`, più un
   evento al cambio (`AudioDeviceCallback`). Due profili salvati; al cambio uscita si applica quello giusto.
3. Nessun lavoro nel thread UI oltre all'impostazione dei guadagni; scrittura impostazioni con il debounce esistente.
**Verifica:** widget test della schermata con un `Equalizer` finto (5 bande). **Tocca a te (Mi A3):** preset «Bassi»
udibile; staccando le cuffie si passa al profilo altoparlante.

### 17.7 — MPRIS su Linux
**File:** `lib/services/audio/system_media_controls.dart`, `lib/services/audio/mpris_controls.dart`, `main.dart`, test
1. `abstract class SystemMediaControls { Future<void> attach(CodecoreAudioHandler h); Future<void> dispose(); }`
   con implementazione nulla di default.
2. Linux: implementazione scelta in 17.1. Metadati (titolo, artista, album, durata, copertina come `file://`),
   stato, posizione (con la velocità), comandi Play/Pause/Next/Previous/Seek/SetPosition, volume.
3. Avvio da `main.dart` solo su Linux, dopo la creazione dell'handler; errori → `AppLog.w`, l'app parte lo stesso.
**Test:** la mappatura `PlaybackState`/`MediaItem` → proprietà MPRIS come funzione pura.
**Tocca a te (Linux):** `playerctl metadata` mostra il brano; tasti multimediali e widget di GNOME funzionano a finestra
non attiva.

### 17.8 — SMTC su Windows
**File:** `lib/services/audio/smtc_controls.dart`, `main.dart`, `.github/workflows/ci.yml` (Rust se serve)
1. Stessa interfaccia di 17.7 con `smtc_windows`: metadati, stato, timeline, pulsanti.
2. Se il pacchetto richiede Rust, aggiungi la toolchain al job `build-windows` della fase 16.
**Verifica:** la build Windows in CI è verde. **Tocca a te (PC Windows):** il riquadro multimediale del volume di
Windows mostra il brano; i tasti multimediali funzionano a finestra minimizzata.

### 17.9 — Controlli della Jam nella notifica e nella schermata di blocco (Android)
**File:** `codecore_audio_handler.dart`, `lib/providers/jam_providers.dart`, `ReceiveService.kt` /
`ShareNotifications.kt` (solo se serve), test
1. Handler: `attachRemote(RemoteTransport? t)` dove `RemoteTransport` espone stato (brano, posizione, in riproduzione,
   può saltare) e comandi. Con un trasporto attivo, `mediaItem`/`playbackState` vengono da lì e play/pausa/avanti/indietro/seek
   vanno al `JamController` (che manda `JamCommand`); la coda locale non si tocca.
2. `JamController` aggancia il trasporto all'avvio della Jam e lo stacca a `end()`/uscita; l'ospite vede «avanti»
   solo se `applyCommand` glielo permetterebbe (oggi no).
3. «Termina Jam» come `MediaControl` personalizzato se 17.1 lo conferma; altrimenti resta l'azione nella notifica
   del `ReceiveService` (evita due notifiche quasi uguali: annota la scelta).
**Test:** handler con trasporto finto: i comandi arrivano al trasporto e non al backend locale; staccato il trasporto
il lettore locale torna com'era. **Tocca a te (due telefoni):** Jam con schermo bloccato, pausa e avanti dalla
schermata di blocco dell'host, pausa dall'ospite.

### 17.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es per tutte le stringhe nuove (velocità, segnalibro, anteprima, equalizzatore, preset).
2. `docs/02-architettura.md`: `SystemMediaControls`, `PreviewPlayer`, equalizzatore; tabella «Differenze per
   piattaforma» (notifica/controlli di sistema su desktop). `docs/03-modello-dati.md`: schema v6 e nuove impostazioni.
3. `docs/99-rischi-e-fallback.md`: R37–R40 (sotto). README: funzioni nuove.
**Tocca a te:** velocità su un podcast/audiolibro lungo, segnalibro dopo riavvio dell'app, anteprima su telefono
e desktop, equalizzatore con cuffie, `playerctl` su Linux, SMTC su Windows, Jam dalla schermata di blocco.

## Fuori da questa fase
Gapless e crossfade (fase 18), velocità per singolo brano o per podcast (fase 23), equalizzatore per la Jam,
equalizzatore parametrico, Android Auto e widget (fase 25).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R37 | Cambiare l'opzione `pitch` di `just_audio_media_kit` altera la correzione di velocità della Jam | Rilanciare i test `test/jam/` e la misura acustica di 10.9 prima di chiudere 17.2 |
| R38 | `AndroidEqualizer` non disponibile o con bande strane su alcuni telefoni (sessione audio, produttore) | `equalizer == null` → voce nascosta; preset interpolati sulle bande reali; errori loggati, riproduzione invariata |
| R39 | Pacchetto MPRIS/SMTC abbandonato o incompatibile con `audio_service` | Dietro `SystemMediaControls`; Linux: MPRIS scritto da noi con `dbus`; Windows: funzione rimandata senza toccare il resto |
| R40 | Due notifiche (Jam e `audio_service`) o notifica che resta dopo la Jam | Un solo trasporto attivo, staccato in `end()`; prova con Jam terminata dall'ospite e dall'host |

## Definition of Done
- [ ] Velocità 0,5×–2× senza cambio di tono su Android e desktop; Jam invariata
- [ ] Segnalibro per brani ≥ 20 min, sopravvive al riavvio (schema v6 con migrazione testata)
- [ ] Anteprima di 20 s dalla copertina, coda e conteggi invariati
- [ ] Equalizzatore con preset su Android (desktop se possibile), profilo cuffie/altoparlante
- [ ] MPRIS su Linux e SMTC su Windows (o rimandati con motivo annotato)
- [ ] Controlli della Jam nella notifica e nella schermata di blocco
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
