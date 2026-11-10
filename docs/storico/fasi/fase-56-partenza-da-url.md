# Fase 56 — Partenza dall'URL

**Obiettivo:** un brano online non in cache parte appena yt-dlp stampa l'URL del flusso, con `loadUri` e gli header che
dà yt-dlp, mentre lo stesso processo continua il download in cache come oggi. Se l'URL non funziona si torna ad
aspettare il file; se scade a metà (anche per un cambio di rete) si riprende dalla posizione. Vale per ricerca,
Shuffle+, album online e coda online; la Jam resta com'è.

**Prerequisiti:** fase 55 chiusa (cronometri, script, «Prova dell'URL» con il comando che funziona).

**Riferimenti:** `docs/feature-streaming-veloce.md` (R-71…R-78, R-82, R-84, R-85; componenti `yt_dlp_args.dart`,
`DownloadProgress`, `YtDlpProcessService`, `YtDlpChannel.kt`, `StreamPreparer`, `_loadCurrent`, errore a metà; flussi 1 e
3; invarianti 1–5; rischi K-SV-01, K-SV-04, K-SV-05, K-SV-07, K-SV-08); decisioni D-138…D-141, D-144, D-145.

**Intoccabili:** formato, selettore e post-elaborazione del download; `StreamCache` e i pin; righe ombra e arricchimento;
Jam (`jam_providers.dart`, `jam_online_adder.dart`: sempre `ready()`); flavor lite; i brani in libreria. Niente a
schermo di nuovo (R-78). Gapless e crossfade restano spenti per gli stream (si accendono nella fase 57). **Nessun
pacchetto nuovo. Schema invariato.**

## Task

### 56.1 — L'URL dalle righe di yt-dlp (desktop)
**File:** `lib/services/online/yt_dlp_args.dart`, `lib/services/online/youtube_service.dart` (`DownloadOptions`,
`DownloadProgress`), `lib/services/online/yt_dlp_process_service.dart`, `test/services/online/yt_dlp_args_test.dart`,
`test/services/online/yt_dlp_process_test.dart`
1. `DownloadOptions.emitStreamUrl` (di serie `false`): aggiunge a `buildDownloadArgs` le due righe `--print before_dl:`
   marcate (prefissi fissi, per esempio `CODECORE_URL ` e `CODECORE_HDR `) più ciò che la 55.4 ha mostrato servire per
   l'avanzamento.
2. `DownloadProgress` ha `streamUrl` e `headers` (nullable). `YtDlpProcessService.download` riconosce le righe marcate ed
   emette un evento con l'URL una volta sola; una riga mancante o rotta = nessun evento (K-SV-07). Un URL con più
   indirizzi (`urls` con `\n`): solo il primo, ed è un URL `https`.

R-71 (desktop).
**Fatto quando:** `flutter test test/services/online/yt_dlp_args_test.dart test/services/online/yt_dlp_process_test.dart`
verde: argomenti presenti solo con l'opzione; righe marcate → un evento con URL e header; riga marcata rotta → nessun
evento e download che finisce come oggi. Prova su Linux col vero yt-dlp: riga `CODECORE_URL` nel log prima della fine.

### 56.2 — L'URL dal canale Android
**File:** `android/app/src/full/kotlin/com/codecore/player/YtDlpChannel.kt`,
`lib/services/online/android_yt_dlp_service.dart`
1. Il lato Kotlin passa le stesse opzioni (`emitStreamUrl` nel dizionario del metodo `download`) e, nel callback di
   youtubedl-android, inoltra le righe marcate a Dart nel campo `line` dell'evento `progress` che esiste già (nessun
   metodo nuovo: decisione presa durante la fase, il probe 55 ha mostrato che le righe arrivano già così).
2. `AndroidYtDlpService` le trasforma nello stesso evento della 56.1. Lite: nessun cambio.

R-71 (Android).
**Fatto quando:** `flutter build apk --debug` riuscito; sul Mi A3 un brano dalla ricerca scrive nel log l'URL prima della
fine del download; `flutter analyze` pulito.

### 56.3 — `StreamPreparer.start()`
**File:** `lib/services/stream/stream_preparer.dart`, `test/services/stream/stream_preparer_test.dart`
1. I download del preparer usano `emitStreamUrl: true`. Il `_Job` tiene l'ultimo URL ricevuto con gli header, l'ora e
   la scadenza letta da `expire=` (se manca: ora + 5 h).
2. `start(key, r)` restituisce un `StreamStart` (file oppure URL con header): il file se è in cache; altrimenti segna il
   job come richiesto (come `ready`) e restituisce il primo fra URL non scaduto e file. `ready()` resta com'è per i suoi
   chiamanti.
3. `restart(key)` per l'URL scaduto: file se pronto; altrimenti, se il job è ancora in corso, lo annulla e lo riavvia, e
   restituisce il nuovo URL (o il file, se arriva prima). Il cronometro della 55.1 aggiunge la voce `url`.

R-71, R-73, R-74, R-76 (parte del preparer).
**Fatto quando:** `flutter test test/services/stream/stream_preparer_test.dart` verde: cache presente → file senza
avviare yt-dlp; URL prima del file → URL; file prima dell'URL → file; URL scaduto → `restart` con file pronto → file;
senza file → nuovo job e nuovo URL; la riga di tempi ha `url=`.

### 56.4 — Il player parte dall'URL
**File:** `lib/services/audio/codecore_audio_handler.dart`, `test/services/audio/online_playback_test.dart`
1. Nel ramo stream di `_loadCurrent`: `start()`; URL → `loadUri(url, headers)` (R-72); file → `load(file)` come oggi.
   L'handler ricorda che il brano in corso suona dall'URL.
2. `loadUri` che fallisce (o URL che non arriva prima del file): si aspetta `ready()` e si carica il file, senza
   messaggio d'errore (R-75); riga `stream timing … fallback=<motivo>`.
3. Durata nel `MediaItem`: quella del backend, con la durata di `YtResult` come ripiego finché il flusso non la dà
   (K-SV-08).
4. La riga `play=` della 55.2 scrive `from=url`.

R-72, R-73, R-75, R-82, R-84, R-85 (parte del codice).
**Fatto quando:** `flutter test test/services/audio/online_playback_test.dart` verde: URL emesso → `loadUri` con URL e
header, nessun `load(file)`; `loadUri` che lancia → `load(file)` dopo `ready()`, nessun errore all'utente; rete a
consumo → stesso comportamento; Shuffle+ e album online passano dallo stesso ramo (un test per l'entrata Shuffle+).

### 56.5 — URL scaduto e cambio di rete
**File:** `lib/services/audio/codecore_audio_handler.dart`, `test/services/audio/stream_expired_test.dart`
1. Un errore di riproduzione sul brano che suona dall'URL, con `BackendException.expired` (o un errore di rete del
   flusso): posizione P salvata; `preparer.restart(key)`; file → `load(file)` + seek P; URL → `loadUri` + seek P (un solo
   tentativo); se fallisce ancora → `ready()`, `load(file)`, seek P (R-76, D-145).
2. In pausa non si fa niente finché non si preme play: il controllo avviene alla ripresa.

R-76.
**Fatto quando:** `flutter test test/services/audio/stream_expired_test.dart` verde con i tre casi del criterio di R-76.

### 56.6 — Controlli di fase (K-SV-01, K-SV-04, K-SV-05)
`flutter analyze` pulito; test toccati verdi; test esistenti verdi: `test/services/stream/`,
`test/services/audio/` (in particolare `gapless_handler_test.dart`, `crossfade_engine_test.dart`,
`radio_playback_test.dart`), test della Jam (`test/jam/`, `test/providers/play_online_jam_test.dart`, `test/providers/jam_seed_test.dart`) e
`stream_promoter_test.dart` (R-86). Revisione del diff: nessun `loadUri` con URL di YouTube nei file della Jam (R-83);
nessun widget nuovo (R-78). Tabella «Dopo 56» con `stream_times.py` su Linux e Mi A3 (Motorola se collegato): 10 brani
come nella 55.5. Spunta in `docs/PROGRESS.md`.

### 56.7 — Prove a mano
Su Linux e sul Mi A3 (Motorola se collegato): tap dalla ricerca → suono in pochi secondi; seek all'80 % appena partito →
riprende con il buffering (R-77); notifica con durata e seek (R-85); Wi-Fi spento a metà brano sul telefono → riprende
dalla posizione (R-76, K-SV-04); secondo ascolto dello stesso brano → `from=cache` nel log (R-73); «Scarica» durante
l'ascolto → il file arriva in libreria (R-86).

## Tabella «Dopo 56»
Build di debug del ramo `feat/56-partenza-url`, 2026-10-27, Wi-Fi UniBA. 10 brani online mai ascoltati per dispositivo,
dalla ricerca; tempi in ms, mediana / massimo, da `python3 scripts/stream_times.py --last 10`. `spawn` ora coincide con
`url`: il primo evento del processo è la riga dell'URL.

| Dispositivo | yt-dlp | url | downloaded | play (url) | Prima: play (cache) | Guadagno |
|---|---|---|---|---|---|---|
| Linux (Xvfb) | 2026.08.19 | 4186 / 4661 | 4846 / 5725 | 4840 / 5130 | 6632 / 8028 | −1,8 s |
| Mi A3 `0d7ae9df206e` | 2026.10.26 | 35536 / 37413 | 37203 / 45222 | 37540 / 40450 | 38882 / 43197 | −1,3 s (fino a −11 s se il download è lento) |
| Motorola edge 40 `ZY22HKD85K` | 2026.10.26 | 16430 / 17039 | 17424 / 17845 | 18197 / 19125 | 23303 / 26626 | −5,1 s (ma «Prima» era su dati mobili, «Dopo» sul Wi-Fi di casa TIM) |

Linux: Imagine, Hey Jude, Rolling in the Deep, Seven Nation Army, Mr Brightside, Back in Black, Losing My Religion,
Under Pressure, Stayin' Alive, Clocks. Mi A3: Bitter Sweet Symphony, Heroes, Black Hole Sun, Ring of
Fire, Dreams, Gimme Shelter, Paint It Black, Karma Police, Fast Car, Sweet Dreams (Tainted Love e Sultans of Swing, i primi due, fuori da `--last 10`).
Motorola (build di `master` dopo la #42, 2026-10-27 23:19, Wi-Fi di casa TIM): Wonderwall, Creep, Africa, Zombie,
Every Breath You Take, Purple Rain, Livin' on a Prayer, Billie Jean, Smells Like Teen Spirit, Mr. Blue Sky.


## Note
- Mi A3: l'URL arriva a ~35 s perché QuickJS risolve le sfide JS di YouTube in ~25 s (vedi fase 55). Partire dall'URL
  serve poco quando il download dopo l'URL dura 1-2 s; serve molto quando il download è lento (Sultans of Swing:
  URL a 38,6 s, file a 56,3 s, suono a 45,3 s). Il vero collo di bottiglia su Android è prima dell'URL: da indagare
  `--cache-dir` (la cache di yt-dlp non esiste nella cartella dell'app, quindi le sfide si risolvono a ogni brano).
- Prove a mano, Linux (Xvfb): suono in ~4,8 s; seek all'80 % appena partito → riprende a 3:37 di 4:26, nessun errore;
  secondo ascolto `from=cache` (315 ms); «Scarica» durante l'ascolto → file in `~/Music`, ascolto non interrotto.
  Notifica: non applicabile.
- Prove a mano, Mi A3: suono in ~37 s; seek all'80 % (tap sull'anello) → 3:27 di 4:49 in riproduzione; secondo ascolto
  `from=cache` (620 ms); «Scarica» durante l'ascolto → promosso in Music (copia tra partizioni), ascolto non interrotto.
  Durata subito visibile nel player (dalla ricerca). Notifica: controlli presenti, barra senza tempi, uguale col brano
  dalla cache (comportamento di Android 11 sul Mi A3, non della 56).
- Prove a mano, Motorola: suono in ~18 s; seek all'80 % (tap sull'anello) → 3:36 di 5:03, avanza; secondo ascolto
  `from=cache` (293 ms); controlli nella scheda multimediale di Android. «Scarica» non provato per non aggiungere file
  alla libreria vera (provato su Linux e Mi A3). Anche qui l'URL arriva a ~16 s: QuickJS, come sul Mi A3.
- Non provato: Wi-Fi spento a metà brano (R-76, K-SV-04): è un'impostazione di sistema, la prova è dell'utente.
- Mi A3: rotazione automatica trovata accesa alle 18:54, prima dell'installazione; non toccata.
