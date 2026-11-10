# Fase 57 — Coda e transizioni dello streaming

**Obiettivo:** il brano dopo in coda parte senza attesa: dal file se il prefetch l'ha già messo in cache (con gapless o
crossfade se accesi, anche se il brano in corso suona dall'URL), altrimenti dall'URL che il prefetch ha già stampato. Poi
la misura finale contro i traguardi e la rimisura delle soglie di frame della fase 38.

**Prerequisiti:** fase 56 chiusa (`StreamPreparer.start()`, URL nel job, ramo `loadUri` dell'handler).

**Riferimenti:** `docs/feature-streaming-veloce.md` (R-79, R-80, R-81, R-83, R-86, R-87; RNF-08, RNF-09, RNF-10;
componenti `_refreshWindow` e `CrossfadeEngine`; flusso 2; invarianti 3 e 5; rischi K-SV-02, K-SV-03, K-SV-06);
decisioni D-81, D-142, D-143, D-145, D-146; `docs/prossimi-lavori.md` §0; `docs/fase-38-rete-ui-fluida.md` (soglie di
arrivo).

**Intoccabili:** le transizioni fra brani in libreria (fase 18) e la regola «niente gapless nello stesso album» se
accesa; `setNext` resta solo per i file; prefetch del preparer (corrente + 2 dopo, 3 a consumo) senza cambi (R-81);
Jam. **Un solo pacchetto nuovo: NewPipeExtractor (D-164), nel flavor `full` di Android. Schema invariato.**

## Task

> Aggiunti il 28/10 su richiesta dell'utente (D-164, D-165), da fare **prima** di 57.1: 57.1 e la misura 57.4 partono
> dall'URL di NewPipe.

### 57.0a — URL del flusso da NewPipeExtractor (Android)
Prototipo sul ramo `proto/newpipe-url` (commit `a38c700`, pushato, mai fuso): da lì si parte, ripulendo.
Motorola, Wi-Fi di casa, 10 brani nuovi: URL in 1,4 s e suono in 3,1 s (mediana) contro 16,4 s e 18,2 s con yt-dlp.
Seek all'80 % sull'URL di NewPipe senza 403.

**File:** `android/app/build.gradle.kts` (`com.github.TeamNewPipe:NewPipeExtractor:v0.26.5`, solo `!lite`),
`android/build.gradle.kts` (JitPack), `android/app/src/full/kotlin/com/codecore/player/NewPipeUrl.kt` (downloader con
`HttpURLConnection`, init pigra, flusso audio `PROGRESSIVE_HTTP`, m4a prima, poi bitrate), `YtDlpChannel.kt` (metodo
`streamUrl`), `lib/services/online/android_yt_dlp_service.dart`, i suoi test.
1. Con `emitStreamUrl`, Android chiede l'URL a NewPipe e intanto avvia yt-dlp per il download: un solo evento
   `streamUrl` per download, il primo dei due; se NewPipe fallisce vince la riga di yt-dlp come nella 56.
2. Una riga `stream url source=<newpipe|ytdlp> key=… ms=… ok=… used=…` per fonte (già nel prototipo).
3. Togliere dal prototipo `youtube_explode_dart`, l'override di `xml` in `pubspec.yaml` e la scelta
   `CODECORE_URL_SOURCE`: non servono più.
4. Desktop invariato (yt-dlp dà già il suono in 4,8 s su Linux).
5. Test: l'evento è uno solo e vince il primo; NewPipe in errore → URL di yt-dlp; NewPipe dopo yt-dlp → ignorato.

**Fatto quando:** `flutter build apk --debug` ok anche con `CODECORE_LITE=1`; sul Motorola 10 brani nuovi con
`source=newpipe used=1` e suono ≤ 5 s (RNF-08).

### 57.0b — Brani vietati ai minori: ripiego su YouTube Music
YouTube chiede il login per i video vietati ai minori («Sign in to confirm your age»): falliscono sia NewPipe sia
yt-dlp, e oggi l'app salta al brano dopo (visto sul Motorola il 28/10 con `Z-GRlWPWRfE`). Il divieto riguarda quasi
sempre il video, non la traccia audio.

**File:** dove si decide l'errore del brano online (`StreamPreparer` o il gestore audio: scegli il punto più semplice),
`lib/services/online/youtube_service.dart` (riconoscere l'errore «età»), test.
1. Errore «età» (`Sign in to confirm your age` nello stderr o nell'eccezione di NewPipe) → ricerca su YouTube Music
   (`searchSongs`, già c'è) con titolo e artista puliti; si prende il primo risultato con durata entro ±10 s, si suona
   quello al posto dell'originale, con una riga `AppLog.i` (`age fallback <id vecchio> → <id nuovo>`).
2. Nessun risultato buono → come oggi (errore e brano dopo), ma con un messaggio chiaro all'utente («vietato ai minori,
   nessuna traccia audio trovata»), testo nei 4 ARB.
3. Niente login né cookie (D-165).

**Fatto quando:** test del ripiego (trovato, non trovato, durata fuori soglia); sul Motorola un video vietato ai minori
dalla ricerca suona dalla traccia di YouTube Music.

### 57.1 — Il brano dopo dall'URL anticipato
> Dalla review di fine fase 56: prima di 57.1 raccogli lo stato del brano da URL (`_fromUrl`, `_urlKey`, `_urlEntry`,
> `_urlResult`, `_recoveries`, `_recoveringToken`) in una piccola classe `UrlSession`, e fai restituire a `_loadStart` la
> sorgente (`from`) invece di ritoccare la riga dei tempi dopo. Il gestore è passato da 1484 a 1623 righe nella 56.

**File:** `lib/services/audio/codecore_audio_handler.dart`, `lib/services/stream/stream_preparer.dart` (se serve un
getter), `test/services/audio/online_playback_test.dart`
1. Al cambio verso un brano online non in cache, `start()` restituisce subito l'URL che il job del prefetch ha già (se
   non scaduto): `loadUri` senza nuovo avvio di yt-dlp. URL scaduto o job in pausa → come un tap (R-79, D-145).
2. La riga `stream timing` del cambio scrive `from=url` o `from=cache` e il tempo dalla fine del brano prima al primo
   suono (`gap=<ms>`).

R-79.
**Fatto quando:** `flutter test test/services/audio/online_playback_test.dart` verde: coda [A in corso, B non in cache con
URL nel job] → al cambio `loadUri(B)` e nessun nuovo `download`; URL di B scaduto → nuovo job; riga con `gap=`.

### 57.2 — Gapless e crossfade da URL verso file
**File:** `lib/services/audio/codecore_audio_handler.dart` (`_refreshWindow`), `lib/services/audio/crossfade_engine.dart`
(solo se serve), `test/services/audio/gapless_handler_test.dart`, `test/services/audio/crossfade_engine_test.dart`
1. La condizione `!isStreamTrack(current)` di `_refreshWindow` diventa: acceso se il brano dopo ha un file (libreria o
   cache), anche quando quello in corso suona dall'URL. Brano dopo senza file → spento, cambio normale (R-80, D-142).
2. Se il file del brano dopo arriva in cache mentre quello in corso suona, la finestra si aggiorna (il preparer avvisa
   con `phases`).
3. Il crossfade prepara il brano dopo dal file sull'altro player, con il brano in corso dall'URL sul primo.

R-80.
**Fatto quando:** `flutter test test/services/audio/gapless_handler_test.dart test/services/audio/crossfade_engine_test.dart`
verde, con i test nuovi: A da URL e B in cache → `setNext(B)` (gapless) e B preparato dal file (crossfade); A da URL e B
solo URL → nessun `setNext`; tutti i test esistenti della fase 18 invariati e verdi (K-SV-02).

### 57.3 — Jam e «Scarica» (regressioni)
**File:** test esistenti; codice solo se un test lo chiede
1. Test nuovo: un'entrata online nella Jam (host e uscita propria, `jamFetchByVideoId`) usa `ready()` e mai `loadUri`
   con un URL di YouTube (R-83, D-143).
2. `stream_promoter_test.dart` verde: «Scarica» durante l'ascolto dall'URL usa il file appena è in cache (R-86).

R-83, R-86.
**Fatto quando:** `flutter test test/jam/ test/providers/play_online_jam_test.dart test/services/stream/stream_promoter_test.dart` verde con il test
nuovo della Jam.

### 57.4 — Misura finale (RNF-08, RNF-09, RNF-10, R-81)
1. Linux, Mi A3 e Motorola (se collegato), Wi-Fi: 10 brani online mai ascoltati dalla ricerca (tap → suono) e 10 cambi di
   brano di fila in una coda online (`gap`). `scripts/stream_times.py`.
2. Tabella «Dopo» qui sotto, accanto a «Prima» (fase 55) e «Dopo 56». Confronto con RNF-08 (≤ 5 s Motorola, ≤ 3 s
   Linux, mediana) e RNF-09 (≤ 1 s). R-81: tutti i 10 cambi con `from=cache` o `from=url` senza nuovo avvio.
3. RNF-10: `play=` dei brani in libreria (`from=file`) non peggiora rispetto a «Prima».
4. Traguardo mancato (K-SV-03: avvio di yt-dlp su Android): si scrive in «Note» con i numeri e una riga in
   `docs/decisioni.md` con il traguardo rivisto (D-146); non si apre altro lavoro in questa fase.

**Fatto quando:** tabella «Dopo» scritta; RNF-08/09/10 segnati come raggiunti o con la riga di decisione.

### 57.5 — Rimisura delle soglie della fase 38 (R-87)
1. `scripts/perf_device.py` sul Mi A3 con `--playback` (comando del profilo, ~40 min).
2. Confronto con le soglie di arrivo di `docs/fase-38-rete-ui-fluida.md`; riga in `docs/decisioni.md` che le accetta con i
   numeri nuovi, oppure che apre il seguito sui picchi al cambio di brano (in `docs/prossimi-lavori.md`, senza farlo qui).
3. Se `docs/prossimi-lavori.md` c'è (oggi non è nel repo), aggiorna §0 (la voce delle soglie è chiusa) e §2c (fatta).

**Fatto quando:** riga in `decisioni.md` con i numeri; `prossimi-lavori.md` aggiornato.

### 57.6 — Controlli di fase (K-SV-02, K-SV-06)
`flutter analyze` pulito; test toccati verdi; test esistenti di `test/services/audio/`, `test/services/stream/` e della
Jam verdi. Spunta in `docs/PROGRESS.md`.

### 57.7 — Prove a mano
Su Linux e sul Mi A3 (Motorola se collegato): album online in ordine, con crossfade acceso → transizioni morbide dal
secondo brano; gapless acceso su un album dal vivo → nessun buco quando il brano dopo è in cache; coda di 5 brani
online appena cercati → ogni cambio entro 1 s; brani in libreria con gapless e crossfade → come prima (K-SV-02); su una
rete lenta (hotspot) nessun buffering ripetuto nei primi 10 s (K-SV-06).

## Tabella «Dopo»
Build di debug del ramo `feat/57-coda-e-transizioni`, 2026-10-28, Wi-Fi di casa. 10 brani online mai ascoltati dalla
ricerca (tap → suono) e una coda online con fine naturale dei brani; tempi in ms, mediana / massimo. Motorola misurato il 2026-10-28 su build di master badd8bb (5 brani da ricerca, vedi riga; gap non misurato).

| Dispositivo | fonte dell'URL | url | play (url) | Dopo 56: play (url) | gap al cambio (n) | play (file) |
|---|---|---|---|---|---|---|
| Linux (Xvfb) | yt-dlp | 3435 / 3755 | 3766 / 8604 | 4840 / 5130 | 142 / 199 (11, tutti `from=cache`) | 110–135 (5) |
| Mi A3 `0d7ae9df206e` | NewPipe 10/10 | 1798 / 2037 | 3902 / 4625 | 37540 / 40450 | 528 / 536 (4, `from=cache`) | ~169 (6) |
| Motorola edge 40 | NewPipe 5/5 | 1880 / 2955 | 4343 / 5823 (n = 5) | 18197 / 19125 | non misurato | non misurato |

- **RNF-08** (≤ 3 s Linux, ≤ 5 s Motorola): Linux 3,8 s, mancato di poco (−1,1 s rispetto alla 56); Motorola **raggiunto**: mediana 4,3 s
  (n = 5, max 5,8 s sul primo brano a freddo; 3,4–4,4 s gli altri). Un sesto brano ha avuto l'URL di NewPipe in 1,8 s ma il suono solo
  dalla cache a 19,3 s (`from=cache`, brano `NmeJbI1l2YA`, visto una volta): da indagare. Traguardo rivisto in D-174.
- **RNF-09** (≤ 1 s): raggiunto su Linux (142 ms) e sul Mi A3 (528 ms).
- **R-81**: nessun nuovo `attempt` al cambio su entrambi; ogni cambio misurato è `from=cache`.
- **RNF-10**: `play (file)` resta tra 57 e 370 ms, come «Prima» (114 ms, n = 1).

Linux: 23 brani in tutto, una 403 di yt-dlp ripresa dal secondo tentativo. Mi A3: Stand By Me, Space Oddity, Hurt, Come
Together, Wish You Were Here, Lithium, Enter Sandman, Sweet Home Alabama, Under the Bridge, Let It Be; coda: «Abbey Road
(Super Deluxe Edition)», 30 download `ok`, nessuno bloccato.

## Note
- Mi A3 (Android 11): NewPipe falliva sempre (`URLDecoder.decode(String, Charset)` esiste solo da API 33) → desugaring (D-173).
  Poi il file in cache non arrivava mai: l'evento dell'URL riarmava il watchdog a 30 s e yt-dlp sul Mi A3 dà il primo
  progresso a ~35 s (corretto in a6b561b, con test).
- Mi A3: dopo alcuni cambi riusciti il crossfade fallisce sempre (`AudioEffect: set/get parameter error`, «next track not
  ready: unplayable file»); il cambio ripiega sul caricamento normale dal file in cache (gap ~530 ms). Seguito in
  `docs/prossimi-lavori.md`.
- La riga `stream timing play=` esce solo sul percorso `loadUri`: i cambi fatti dal crossfade o dal gapless non hanno `gap=`.

## Seguito (dalla review di architettura della fase)
- Vietati ai minori su Android: riconoscere l'errore età già da NewPipe (`AgeRestrictedContentException` → codice `AGE`) invece di aspettare yt-dlp (16–37 s).
- Una sola scelta della sorgente (`_sourceOf`) per `_loadCurrent` e `_nextFile`; `StreamPreparer.cachedFile` senza scritture (oggi tocca la cache, la riga ombra e la fase).
- NewPipe solo per i job richiesti, non per il prefetch (due estrazioni per brano verso YouTube); stato per pid di `android_yt_dlp_service.dart` in un record; 429 di NewPipe → `cooldown`.
- Crossfade sul Mi A3: `AudioEffect: set/get parameter error` dopo alcuni cambi (vedi «Note»).
