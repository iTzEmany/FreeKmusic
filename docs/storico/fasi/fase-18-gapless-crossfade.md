# Fase 18 — Gapless e crossfade

**Obiettivo:** gli album dal vivo, la classica e i concept album suonano **senza silenzio tra un brano e l'altro**
(gapless); in alternativa, per le playlist miste, una **dissolvenza incrociata** regolabile (crossfade). Tutto dietro
un'impostazione «Passaggio tra i brani: Normale · Senza pause · Dissolvenza», **default Normale**: con Normale
l'app si comporta esattamente come oggi.
**Prerequisiti:** Fase 2 (`PlayQueue`, `CodecoreAudioHandler`), Fase 7.3 (ReplayGain), Fase 7.7 (timer di spegnimento),
Fase 16 (CI e test d'integrazione), Fase 17 (velocità ed equalizzatore, che devono funzionare in tutte le modalità).
**Principio:** `PlayQueue` resta **l'unica autorità** sull'ordine (shuffle, repeat, cronologia). Il backend nativo
riceve solo una **finestra di due brani** (corrente + successivo) e avvisa quando passa al successivo; non decide
mai lui cosa suonare. La **Jam non cambia**: usa il suo backend (`jamBackendFactoryProvider`, `jam_output.dart`) e la
sincronia della fase 10 resta identica.

> Era il task 7.2, rimandato per rischio (vedi `docs/PROGRESS.md`, note Fase 7). Si lavora su un ramo git
> (`fase-18`) e si unisce a `master` solo con la Definition of Done completa.

## Decisioni
| Tema | Scelta |
|---|---|
| Impostazione | `AppSettings.transition`: `normal` (oggi) · `gapless` · `crossfade`; durata crossfade 2–12 s (default 6) in `crossfadeSeconds`. Le due modalità sono alternative, mai insieme |
| Gapless: meccanismo | `just_audio` con playlist di due sorgenti (`setAudioSources`, `addAudioSource`, `removeAudioSourceAt`, `currentIndexStream`: API viste in `just_audio-0.10.6`); su desktop `just_audio_media_kit` la traduce in playlist mpv (serve `JustAudioMediaKit.prefetchPlaylist = true`, oggi `false`) |
| Interfaccia backend | Nuova interfaccia `GaplessCapable` (implementata da `JustAudioBackend`): `setNext(String? path)`, `Stream<void> advanced`. Chi non la implementa (backend finto vecchio, Jam) resta in modalità normale |
| Crossfade: meccanismo | Due `AudioBackend` alternati (A/B) in un `CrossfadeEngine`; rampe di volume a 20 passi; il nuovo parte a `durata − crossfade` |
| Crossfade nello stesso album | Opzione «Non sfumare tra brani consecutivi dello stesso album» (default **sì**): lì si fa un passaggio normale |
| ReplayGain | Il guadagno del brano nuovo si applica **al momento del passaggio** (gapless) o sulla rampa del brano entrante (crossfade) |
| Velocità ed equalizzatore | Applicati a ogni backend creato (crossfade: entrambi); un cambio vale per tutti |
| Timer «fine brano» | Con `pauseAtTrackEnd` attivo si toglie il successivo dalla finestra (`setNext(null)`) / niente crossfade |
| Notifica e controlli | Il brano «corrente» cambia al passaggio (gapless) o a metà dissolvenza (crossfade) |
| Pacchetti nuovi | Nessuno |

## Task

### 18.1 — Verifiche preliminari
1. Leggi in `~/.pub-cache/hosted/pub.dev/just_audio-0.10.6/lib/just_audio.dart`: `setAudioSources`, `addAudioSource`,
   `insertAudioSource`, `removeAudioSourceAt`, `currentIndexStream`, comportamento di `processingState.completed` con
   più sorgenti, `LoopMode`. Annota se rimuovere la sorgente 0 **mentre suona la 1** provoca un'interruzione.
2. Leggi `just_audio_media_kit-2.1.0/lib/mediakit_player.dart` (righe con `Playlist`, `prefetch-playlist`,
   `concatenatingInsertAll`) e la doc di mpv su `gapless-audio` (default `weak`): con file di formato diverso
   (mp3 → flac) mpv riapre l'uscita e il gap torna. Annota.
3. Prepara i file di prova con ffmpeg in `test/fixtures/gapless/` (piccoli, ≤ 200 KB in tutto): un tono continuo
   di 9 s tagliato in 3 file mp3 e 3 flac, e una traccia di click ogni 500 ms tagliata **a metà tra due click**.
4. Prototipo fuori da `lib/` (script temporaneo, poi cancellato): Linux e Mi A3, i 3 mp3 in playlist just_audio.
   Ascolta e registra con il microfono del PC come in 10.9.
**Verifica:** note in PROGRESS: gap misurato (ms) per Android e Linux, mp3 e flac. Se su una piattaforma il gap non
scende sotto ~20 ms o il passaggio fa un «clic» forte, **fermati e riporta**: la modalità `gapless` resterà
disponibile solo dove funziona (`isGaplessSupported` per piattaforma).

### 18.2 — `PlayQueue.peekNext()` (logica pura)
**File:** `lib/services/audio/play_queue.dart`, `test/services/audio/play_queue_test.dart`
1. `int? peekNext({bool auto = true})`: il brano che `next(auto: true)` restituirebbe, **senza** modificare stato,
   cronologia o ordine di shuffle. Caso shuffle con `repeat all` a fine giro: oggi `next` rimescola; `peekNext` deve
   restituire lo stesso id che `next` darà davvero (fissa il nuovo ordine in anticipo, in un campo `_pendingOrder`).
2. `int get revision`: contatore che cresce a ogni modifica della coda (setItems, move, remove, add, playNext, shuffle,
   repeat, jumpTo). Serve all'handler per sapere quando ricalcolare la finestra.
**Test:** `peekNext() == next(auto: true)` su 200 sequenze casuali di operazioni (shuffle on/off, repeat off/all/one,
spostamenti, rimozioni); `peekNext` non cambia `currentIndex` né la cronologia di `previous`.

### 18.3 — Backend con finestra di due brani
**File:** `lib/services/audio/audio_backend.dart`, `just_audio_backend.dart`, `test/support/fake_backend.dart`, `main.dart`
1. `abstract class GaplessCapable { Future<void> setNext(String? path); Stream<void> get advanced; }`.
2. `JustAudioBackend` in modalità gapless: `load(path)` → `setAudioSources([path])`; `setNext(p)` sostituisce la
   sorgente in posizione 1 (o la toglie con `null`); al cambio di `currentIndexStream` 0 → 1 emette `advanced`, poi
   rimuove la 0 in modo che la finestra torni [corrente, —]. Fuori dalla modalità gapless il comportamento è identico
   a oggi (`setFilePath`).
3. `main.dart`: `JustAudioMediaKit.ensureInitialized(prefetchPlaylist: …)` o la proprietà statica, solo se 18.1 lo
   conferma; verifica che il backend della Jam non ne risenta (`test/jam/`).
4. `FakeBackend` implementa `GaplessCapable` per i test (un comando per simulare il passaggio).
**Test:** con il backend finto: `setNext` chiamato due volte tiene solo l'ultimo; `setNext(null)` dopo l'avvio del
passaggio non rompe nulla.

### 18.4 — Handler in modalità gapless
**File:** `lib/services/audio/codecore_audio_handler.dart`, `lib/services/audio/gapless_window.dart` (se l'handler
supera ~300 righe, estrai lì la logica), `test/services/audio/codecore_audio_handler_test.dart`
1. `setTransition(TransitionMode m)`; in `gapless` dopo ogni `_loadCurrent` riuscito e a ogni cambio di
   `PlayQueue.revision`: `setNext(path di peekNext())` (lettura del brano dal repository, fuori dal ciclo di posizione).
2. Su `advanced`: `_queue.next(auto: true)`, aggiorna `_current`, `mediaItem`, `_playCounted = false`, guadagno
   ReplayGain (`gainFactor`), segnalibro di fase 17, poi la finestra successiva. Non chiamare `_loadCurrent`.
3. Salto manuale, `previous`, `skipToQueueItem`, `playQueue`, rimozione del brano corrente → percorso di oggi
   (`_loadCurrent`), poi finestra.
4. `pauseAtTrackEnd` → `setNext(null)`; `repeat one` → successivo = stesso path; `completed` resta gestito come oggi
   (fine coda).
5. File mancante come successivo → finestra senza successivo; il salto ed eventuali errori seguono la logica di
   `_failAndSkip` di oggi al momento del passaggio.
**Test (almeno 10 casi):** passaggio automatico aggiorna brano, conteggio ascolti e guadagno; shuffle cambiato a metà
brano aggiorna il successivo; rimozione del successivo; `playNext`; repeat one; timer fine brano; fine coda; file
mancante; cambio modalità gapless → normale a metà brano; `PlaybackPersistence` salva l'indice giusto dopo un passaggio.

### 18.5 — Motore crossfade
**File:** `lib/services/audio/crossfade_engine.dart`, `test/services/audio/crossfade_engine_test.dart`
1. `CrossfadeEngine(AudioBackend Function() factory)`: due backend; espone gli stessi stream di un `AudioBackend`
   (posizione e durata di quello «principale»), così l'handler lo usa al posto del backend singolo.
2. `prepareNext(path, gain)`; quando la posizione del principale raggiunge `durata − crossfadeSeconds` (calcolata
   con la velocità corrente) parte l'altro a volume 0 e le rampe incrociate (curva a potenza costante, 20 passi);
   a metà rampa diventa principale ed emette `advanced`; alla fine il vecchio si ferma.
3. Pausa durante la dissolvenza mette in pausa entrambi; seek o salto la annullano (il vecchio si ferma subito).
4. Brani più corti di 2 × crossfade: nessuna dissolvenza.
**Test (fake async, backend finti):** inizio alla posizione giusta anche a 1,5×; volumi a metà rampa; pausa a metà;
salto a metà; brano corto; stesso album con l'opzione attiva → passaggio normale.

### 18.6 — Handler in modalità crossfade
**File:** `codecore_audio_handler.dart`, `main.dart`, test dell'handler
1. In `crossfade` l'handler usa `CrossfadeEngine` (stessa fabbrica di `JustAudioBackend`), con `peekNext` e
   `PlayQueue.revision` come in 18.4; `advanced` → stessa routine di 18.4.
2. Cambio modalità a caldo: si applica dal brano successivo (nessuna interruzione del brano in corso).
3. Velocità ed equalizzatore di fase 17 applicati a entrambi i backend del motore; volume utente × guadagno
   ReplayGain × rampa.
**Test:** handler con motore e backend finti: notifica aggiornata a metà dissolvenza, conteggio ascolti del brano
nuovo, nessuna dissolvenza con `pauseAtTrackEnd`.

### 18.7 — Impostazioni e interfaccia
**File:** `settings_store.dart`, `settings_providers.dart`, `settings_screen.dart`, ARB, test impostazioni
1. Impostazioni → Riproduzione: «Passaggio tra i brani» (Normale · Senza pause · Dissolvenza), cursore 2–12 s,
   «Non sfumare nello stesso album». «Senza pause» disabilitato con spiegazione dove 18.1 l'ha escluso.
2. Testo d'aiuto: «Senza pause funziona meglio con brani dello stesso formato (es. tutti FLAC)».
**Test:** `test/data/settings_store_test.dart` (lettura/scrittura e default `normal`); widget test della sezione.

### 18.8 — Non regressione della Jam e del lettore normale
**File:** `test/jam/` (solo test nuovi), `test/services/audio/codecore_audio_handler_test.dart`, `integration_test/`
1. Test: con `transition = gapless` o `crossfade` avviare una Jam mette in pausa il lettore locale come oggi e il
   `JamController` usa ancora `jamBackendFactoryProvider` (backend singolo, nessuna finestra).
2. Tutta la suite `test/jam/` invariata e verde; nessuna modifica a `jam_output.dart`, `jam_sync.dart`.
3. Test d'integrazione (fase 16): con i file di `test/fixtures/gapless/` in modalità gapless il passaggio avviene
   (indice cambia) senza stato `loading` intermedio.
**Verifica:** `flutter test` verde; `git diff master -- lib/services/jam` vuoto.

### 18.9 — Misura del gap e del crossfade
1. Con i file di click di 18.1: registrazione col microfono del PC come in 10.9, su Linux e Mi A3, mp3 e flac,
   modalità normale e gapless. Calcola lo scarto tra l'ultimo click di un file e il primo del successivo
   (atteso 500 ms). Annota media e massimo in PROGRESS.
2. Crossfade da 6 s tra due brani reali: ascolto, nessun salto di volume, notifica che cambia a metà.
**Verifica:** gapless entro ~20 ms dal valore atteso dove dichiarato supportato. **Tocca a te:** ascolto di un album
dal vivo vero sul telefono e sul PC, con lo schermo spento sul telefono.

### 18.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es.
2. `docs/02-architettura.md`: togliere «Niente gapless/crossfade nella v1», descrivere finestra a due brani,
   `GaplessCapable`, `CrossfadeEngine`. `docs/03-modello-dati.md`: nuove impostazioni (nessuno schema DB).
3. `docs/99-rischi-e-fallback.md`: R41–R43; aggiornare «Limiti accettati nella v1» (crossfade non più escluso).
4. README; nota nella fase 7 (task 7.2 fatto qui).
**Tocca a te:** una settimana d'uso con «Senza pause» attivo; segnalare passaggi saltati o brani ripetuti.

## Fuori da questa fase
Gapless nella Jam (cambierebbe la sincronia della fase 10), analisi automatica del silenzio iniziale/finale per il
crossfade «intelligente», crossfade tra brani di una Jam, MixRamp / dati di fine brano dai tag.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R41 | La finestra del backend si disallinea dalla coda (brano ripetuto o saltato) | `PlayQueue` unica autorità, `revision` per ricalcolare, test casuali di `peekNext`; impostazione default «Normale» |
| R42 | mpv o ExoPlayer non sono davvero gapless con formati misti o su certi telefoni | Misura in 18.1/18.9; modalità disabilitata per piattaforma dove non funziona; spiegazione nell'impostazione |
| R43 | Regressioni nella Jam o nel timer di spegnimento | Nessuna modifica ai file della Jam (verificata con `git diff`), test di non regressione 18.8, timer gestito con `setNext(null)` |

## Definition of Done
- [ ] «Senza pause» senza silenzio udibile tra brani dello stesso formato (misurato) su Android e Linux
- [ ] Dissolvenza 2–12 s, con eccezione per lo stesso album
- [ ] Shuffle, repeat, salti, rimozioni, timer e persistenza coerenti in tutte e tre le modalità
- [ ] ReplayGain, velocità ed equalizzatore funzionanti in tutte le modalità
- [ ] Jam invariata (codice e test); default «Normale» identico a oggi
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
