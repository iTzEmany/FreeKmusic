# Feature «Streaming veloce»

Un brano online parte appena c'è l'indirizzo del flusso: il player legge l'URL diretto mentre il download in cache continua come oggi. Dal secondo ascolto si usa il file in cache, e il brano dopo in coda parte senza attesa.
Per chi: l'utente, sul Motorola e su Linux, quando ascolta dalla ricerca, da Shuffle+ o da un album online. Perché ora: oggi dal tap all'ascolto passano fino a 25 s, perché il player aspetta che `StreamPreparer.ready()` finisca l'intero download di yt-dlp (avvio, download, ffmpeg, spostamento in cache). Prima si misura ogni pezzo, poi si riduce.

Kickoff del 2026-10-27 (richiesta originale: `docs/prossimi-lavori.md` §2c). Decisioni: D-138 e seguenti in `docs/decisioni.md`. Supera in parte D-81 (niente gapless né crossfade con gli stream) e l'invariante 2 della fase 45 (i brani YouTube suonano solo da file).
Fasi: vedi `docs/PROGRESS.md` (55 e seguenti).

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Tutto vale per il flavor completo su Android e su Linux; Windows usa lo stesso codice di Linux ed è provato solo su Linux. Il flavor lite (senza yt-dlp) non cambia.

### Misura
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-68 | Per ogni brano preparato, una riga in `codecore.log` (AppLog) con i tempi in ms di: avvio di yt-dlp, URL pronto, download finito, post-elaborazione (ffmpeg), spostamento in cache, e per il brano in riproduzione anche tap → primo suono e da dove suona (`url`, `cache`, `file`) | I | Test: un preparer con yt-dlp finto e orologio finto scrive la riga con tutte le voci nell'ordine; una prova vera su Linux la mostra nel log | 55 |
| R-69 | Script in `scripts/` che legge il log (da Linux o dal telefono con `adb`) e stampa, per ogni voce, mediana e massimo sugli ultimi N brani | I | `python3 scripts/<nome>.py --self-test` verde; sul log di una prova stampa la tabella | 55 |
| R-70 | Misura di partenza prima di ogni modifica al percorso: 10 brani non in cache su Wi-Fi, sul Motorola e su Linux, con la tabella scritta nel documento di fase | I | La tabella «Prima» è nel documento della fase di misura, con data e dispositivo | 55 |

### Partenza dall'URL
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-71 | Un solo avvio di yt-dlp per brano: stampa l'URL del flusso audio (con gli header e lo User-Agent da usare) appena lo conosce, poi continua il download in cache come oggi (stesso formato, stessa post-elaborazione). Su Android passa dal canale `codecore/ytdlp`, che inoltra l'URL prima della fine (dove l'URL viene da NewPipe, con User-Agent fisso, vedi D-164) | I | Test: yt-dlp finto che stampa l'URL e poi scrive il file → il preparer emette l'URL prima di completare il download, e il file arriva in cache come oggi; su Android, prova sul Mi A3 con l'URL nel log prima di «download finito» | 56 |
| R-72 | Brano non in cache: il player parte dall'URL appena c'è (`loadUri` con gli header), senza aspettare il download. Il download in cache continua in parallelo (due download: il player legge l'URL, yt-dlp scarica) | I | Test sull'audio handler con preparer finto: URL emesso, file non ancora pronto → `loadUri` chiamato con URL e header, `load(file)` no | 56 |
| R-73 | Brano già in cache: suona dal file come oggi, senza chiedere l'URL | I | Test: cache presente → `load(file)`, nessun avvio di yt-dlp | 56 |
| R-74 | Se il download in cache finisce mentre il brano suona dall'URL, il brano resta sull'URL fino alla fine; il file si usa dal prossimo ascolto | I | Test: download completato a metà → nessun nuovo `load`; al riascolto `load(file)` | 56 |
| R-75 | URL che non funziona (errore all'apertura, 403 subito, client rotto, URL che non arriva entro un tempo massimo): si torna al comportamento di oggi, il player resta in caricamento finché il file è pronto, senza errori in più | I | Test: `loadUri` fallisce → si aspetta `ready()` e si carica il file; nessun messaggio d'errore se il file arriva | 56 |
| R-76 | URL scaduto o rifiutato a metà brano (403/410, anche dopo una pausa lunga o un cambio di rete): se il file è già in cache si passa al file alla stessa posizione; altrimenti si chiede un URL nuovo una volta e si riparte da lì; se fallisce ancora, si aspetta il download e si riprende dalla posizione. Al massimo 2 recuperi per brano (un secondo cambio di rete più avanti nello stesso brano); dal terzo errore solo il file. Scatta su ogni errore del player sul brano da URL, non solo su `expired` (fase 56). Usa `BackendException.expired`, che oggi nessuno legge (D-141, D-145) | I | Test: errore `expired` a 42 s con il file in cache → `load(file)` e seek a 42 s; senza file → nuovo URL e seek a 42 s; secondo `expired` → attesa del file e seek a 42 s | 56 |
| R-77 | Seek mentre si scarica: funziona dall'URL (richieste a intervalli); oltre la parte caricata si vede l'indicatore di buffering come per la radio | I | Prova su Linux e sul Mi A3: seek all'80 % di un brano appena partito → riprende entro pochi secondi, la barra mostra il buffering | 56 |
| R-78 | Per l'utente non cambia niente a schermo: nessuna icona o barra in più; il caricamento è solo più breve | I | Revisione del diff: nessun widget nuovo nel player | 56 |

### Coda e transizioni
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-79 | Brano dopo in coda non ancora in cache al cambio: parte dall'URL con lo stesso percorso di R-72. L'URL anticipato è quello stampato dal prefetch, che scarica già i 2 brani dopo (D-145); se è scaduto rispetto a `expire=`, o il prefetch è in pausa, si parte come per un tap | I | Test: coda [A in riproduzione, B non in cache] → l'URL di B è pronto prima della fine di A; al cambio `loadUri(B)` senza nuovo avvio di yt-dlp | 57 |
| R-80 | Gapless e crossfade funzionano dal brano che suona dall'URL verso il brano dopo, se questo è già in cache. Verso un brano non in cache resta il cambio normale | I | Test: A da URL, B in cache, crossfade acceso → `CrossfadeEngine` prepara B dal file; A da URL, B solo URL → nessun `setNext`, cambio normale | 57 |
| R-81 | Il prefetch del preparer resta com'è (corrente + 2 dopo, 3 sulla rete a consumo); va verificato con la misura che basti perché il brano dopo sia in cache o almeno con l'URL pronto | I | Misura su 10 cambi di brano di fila sul Motorola: tutti con il brano dopo da `cache` o da URL anticipato | 57 |

### Convivenza con il resto
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-82 | Ricerca, Shuffle+, album online e coda online usano lo stesso percorso di R-72 | I | Test o prova: tap su un brano della ricerca, su un suggerito di Shuffle+ e play di un album online → riga `url` nel log | 56 |
| R-83 | Jam: come oggi. Host e ospiti aspettano il file in cache (l'URL è legato all'IP di chi l'ha chiesto e la sincronia conta più della partenza) | I | Test Jam esistenti verdi; nessuna chiamata a `loadUri` con URL di YouTube nei percorsi della Jam | 57 |
| R-84 | Rete a consumo: streaming anche lì, con il prefetch limitato a 3 brani come oggi | I | Test: rete a consumo → `loadUri` come su Wi-Fi; prefetch di 3 | 56 |
| R-85 | Notifica Android: durata, barra di avanzamento, seek e copertina remota come oggi anche quando il brano suona dall'URL | I | Prova sul Mi A3: brano dall'URL → la notifica mostra la durata e il seek dalla notifica funziona | 56 |
| R-86 | «Scarica» durante lo streaming: come oggi (`StreamPromoter` usa il file in cache appena è pronto) | I | Test esistenti di `StreamPromoter` verdi | 57 |
| R-87 | Dopo la feature si rimisurano le soglie di frame della fase 38 (`docs/prossimi-lavori.md` §0, che toccano il cambio di brano) e si chiude la scelta con una riga in `docs/decisioni.md` | I | `perf_device.py` sul Mi A3 a fine feature; riga in `decisioni.md` con i numeri | 57 |

## Requisiti non funzionali
| ID | Requisito | Misura |
|---|---|---|
| RNF-08 | Tap → primo suono, brano non in cache, Wi-Fi | mediana su 10 brani ≤ 5 s sul Motorola, ≤ 3 s su Linux (script di R-69) |
| RNF-09 | Cambio al brano dopo, in cache o con URL anticipato, fuori da gapless e crossfade | ≤ 1 s dalla fine del brano al primo suono del successivo |
| RNF-10 | Nessuna regressione per i brani in libreria e in cache | tempi di `load(file)` e soglie della fase 38 non peggiorano |

## Fuori perimetro
- Un download solo (proxy locale che passa i byte al player e li scrive in cache): due download anche sulla rete a consumo (D-139).
- Passaggio al file a metà brano quando la cache è pronta (D-140).
- Gapless e crossfade verso un brano che non è ancora in cache.
- Streaming dall'URL nella Jam, per host e ospiti (D-143).
- `youtube_explode_dart` o altri pacchetti per l'URL (D-138); yt-dlp «caldo» tenuto acceso su Android.
- Indicatori a schermo dello streaming (R-78).
- Flavor lite.

## Architettura
Si parte dal percorso di oggi (fasi 45–47): `StreamPreparer` scarica con yt-dlp in `StreamCache`, e `CodecoreAudioHandler._loadCurrent` aspetta `ready()` e carica il file. La feature aggiunge solo un'uscita anticipata (l'URL) allo stesso avvio di yt-dlp; il download, la cache, le righe ombra e l'arricchimento restano come sono.

### Componenti
| Componente | Oggi | Cambia |
|---|---|---|
| `yt_dlp_args.dart` (`buildDownloadArgs`) | `-f … -x --audio-format m4a` | in più, con un'opzione di `DownloadOptions`, `--print before_dl:` di una riga marcata con l'URL del formato scelto (`%(urls)s`) e una con gli header (`%(http_headers)j`). `--print` implica `--quiet`: si aggiunge `--progress` (o quello che serve) perché `parseProgressLine` continui a vedere l'avanzamento. Da provare col yt-dlp vero al passo di misura |
| `DownloadProgress` | `received`, `total`, `path` | un evento in più con `streamUrl` e `headers` (o un campo nuovo), emesso una volta prima della fine |
| `YtDlpProcessService.download` (Linux/Windows) | legge le righe di avanzamento | riconosce le due righe marcate ed emette l'evento dell'URL |
| `YtDlpChannel.kt` (full) e `AndroidYtDlpService.download` | inoltra l'avanzamento sul canale `codecore/ytdlp` | il callback di youtubedl-android riceve anche le righe di output: quelle marcate vanno a Dart con un metodo nuovo (`url`) per `processId`. Lite: nessun cambio |
| `StreamPreparer` | `_Job` con `done` (file) | `_Job` tiene anche l'URL (con l'ora e `expire=`) appena arriva. Metodo nuovo `start(key, r)`: il file se è in cache, altrimenti il primo fra URL valido e file (stesso job di `ready`, che resta per Jam, Shuffle+ e «Scarica»). Metodo per l'URL scaduto: file se pronto, altrimenti riavvio del job e attesa del nuovo URL. Cronometro per job e riga di tempi in `AppLog` (R-68) |
| `CodecoreAudioHandler._loadCurrent` (ramo stream) | `await ready()` → `load(file)` | `await start()` → `loadUri(url, headers)` oppure `load(file)`; se `loadUri` fallisce → `await ready()` e `load(file)` (R-75). Ricorda «suona da URL» per il brano in corso |
| errore di riproduzione a metà | ogni `BackendException` uguale | `expired` sul brano da URL → R-76 con la posizione salvata. Cambio di rete: lo stesso errore, lo stesso percorso |
| `_refreshWindow` e `CrossfadeEngine` | spenti se il brano in corso è uno stream (`!isStreamTrack(current)`) | accesi quando il brano dopo ha il file in cache, anche se quello in corso suona dall'URL; `setNext` resta solo per file (verso un URL: cambio normale) |
| Jam, `JamOnlineAdder`, Shuffle+ prefetch | `ready()` | invariati (R-83) |
| `scripts/stream_times.py` (nuovo) | — | legge `codecore.log` (file o `adb exec-out run-as …`), stampa mediana e massimo per voce, con `--self-test` |

### Flussi
1. **Tap su un brano online non in cache.** `_loadCurrent` → `preparer.start(key)` → job richiesto, yt-dlp parte → riga URL → `loadUri(url, headers)` → suono. yt-dlp continua: download, ffmpeg (remux), `cache.put`, riga ombra. Il brano finisce sull'URL (R-74).
2. **Cambio al brano dopo.** Il prefetch ha già un job per B: se B è in cache → file, con gapless o crossfade se accesi; altrimenti, se il job di B ha un URL non scaduto → `loadUri` subito; altrimenti come un tap.
3. **Errore a metà.** `expired` con posizione P → file in cache? `load(file)` + seek P; altrimenti nuovo URL (un tentativo) + seek P; altrimenti attesa di `ready()` + seek P.

### Dati
Nessuna tabella nuova, nessuna migrazione. L'URL vive solo in memoria nel job (scade, è legato all'IP). La riga di tempi è testo in `codecore.log`, formato fisso con prefisso `stream timing` e coppie `voce=ms`.

### Invarianti
1. Un solo avvio di yt-dlp per brano e per tentativo: il download in cache (D-138, D-145). Su Android l'URL viene invece da NewPipeExtractor, con una chiamata a parte; yt-dlp resta per il download (D-164).
2. La cache si riempie come oggi: stessa `StreamCache.put`, stessi pin e limiti; il brano in corso non cambia sorgente se va tutto bene (D-140).
3. Mai un URL di YouTube nella Jam (D-143).
4. Un errore dell'URL non diventa mai un errore per l'utente finché il download può ancora arrivare (R-75).
5. Brani in libreria e in cache: stesso codice di oggi (`load(file)`, gapless, crossfade).

### Dove va il codice nuovo
`lib/services/online/` (argomenti e lettura delle righe marcate), `android/app/src/full/kotlin/.../YtDlpChannel.kt`, `lib/services/stream/stream_preparer.dart` (`start`, URL nel job, cronometro), `lib/services/audio/codecore_audio_handler.dart` (ramo stream, `expired`, finestra), `scripts/stream_times.py`. Test accanto a quelli che ci sono: `test/services/stream/stream_preparer_test.dart`, `test/services/audio/`, `test/services/online/`.

## Rischi
| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale d'allarme |
|---|---|---|---|---|---|
| K-SV-01 | YouTube accetta l'URL ma lo rifiuta dopo i primi pezzi (client che vuole il PO token) o per un User-Agent diverso: lo streaming si ferma | M | A | header di yt-dlp passati a `loadUri` (NewPipe usa uno User-Agent fisso); ripiego sul file (R-75, R-76); nella fase di misura una prova di 30 s di ascolto dall'URL su Linux e sul Mi A3 prima di cambiare il player | righe `expired` o `url fallback` nel log su più del 10 % dei brani |
| K-SV-02 | Regressioni di gapless e crossfade per i brani in libreria (fase 18) toccando la finestra e `CrossfadeEngine` | M | A | il cambio tocca solo `NextWindow.resolve`, `_onAdvanced`, `_volumeFor`, la regola dell'album e `JustAudioBackend.loadUri`; test esistenti della fase 18 verdi prima e dopo; un test nuovo per URL → file | un test di `crossfade_engine` o `next_window` rosso; salti udibili fra brani dello stesso album |
| K-SV-03 | Su Android l'avvio di yt-dlp (Python + QuickJS) da solo supera i 5 s: RNF-08 non si raggiunge senza yt-dlp «caldo» (fuori perimetro) | M | M | la misura della fase 55 lo dice prima di scrivere il resto; anche sopra 4 s si prosegue (il guadagno su download e ffmpeg resta) e RNF-08 si rivede a fine fase 57 con i numeri (D-146) | voce `spawn` > 4 s nella tabella «Prima» |
| K-SV-04 | Cambio di rete (Wi-Fi → dati) a metà brano: l'URL è legato all'IP e viene rifiutato | A | M | R-76: file se pronto, altrimenti nuovo URL dalla posizione; prova a mano sul Mi A3 spegnendo il Wi-Fi a metà | il brano si ferma o riparte da 0 dopo il cambio di rete |
| K-SV-05 | `--print` implica `--quiet` e spegne l'avanzamento, o youtubedl-android non passa le righe di output al callback | M | M | prova col yt-dlp vero su Linux e sul Mi A3 nel primo passo della fase 56; `--progress` o `--newline` se serve | barra di download ferma a 0 nel centro Attività |
| K-SV-06 | Due download insieme sulla stessa rete lenta si rubano banda: l'avvio dall'URL va a scatti | B | M | prefetch invariato; misura anche su una rete lenta (hotspot) | buffering ripetuto nei primi 10 s |
| K-SV-07 | Un aggiornamento di yt-dlp (self-update STABLE su Android) cambia `urls` o `http_headers` | B | M | parsing tollerante: riga marcata mancante = nessun URL = comportamento di oggi | nessuna riga `url` nel log dopo un aggiornamento |
| K-SV-08 | Notifica Android senza durata o senza seek finché lo stream non dà la durata | B | B | durata di `YtResult` come ripiego nel `MediaItem`; prova R-85 | notifica senza barra con un brano dall'URL |

Rischi che preoccupano di più l'utente (2026-10-27): K-SV-01, K-SV-02, K-SV-03, K-SV-04.

**Controlli a ogni fase** (regressioni prima): test esistenti di player, crossfade, finestra del brano dopo, stream preparer, Jam e `StreamPromoter` verdi; a fine fase 56 e 57 prova a mano su Linux, sul Mi A3 e sul Motorola se collegato (tap dalla ricerca, cambio di brano, seek, Wi-Fi spento a metà).
