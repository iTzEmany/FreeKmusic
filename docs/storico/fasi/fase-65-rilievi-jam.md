# Fase 65 — Rilievi della Jam (feature «Jam: cassa e coda insieme»)

**Obiettivo:** chiudere i rilievi aperti delle prove 47.8 e 63.5 senza cambiare l'aspetto della Jam: aggiunte in fila, swipe online dell'ospite, uscita con la coda ritrovata, copertine, «Scarica» che sparisce, «precedente» deciso dall'host, scarto fra i telefoni.

**Prerequisiti:** fase 64 chiusa. Requisiti R-88 … R-95 in `docs/feature-jam-cassa.md`; decisioni D-177 … D-181, D-195, D-204, D-205, D-209, D-215. Area a rischio: protocollo Jam (`/code-review high`, review di fine fase Opus).

**Comando mirato:** `flutter test test/jam test/ui/jam_screen_test.dart test/ui/jam_parts_test.dart test/ui/online_song_row_test.dart test/ui/track_actions_test.dart`; in più `flutter test test/services` quando si tocca `codecore_audio_handler.dart` o `player_providers.dart`.

## Task

### 65.1 — Caratterizzazione della coda della Jam (K-JC-01)
Test che fissano l'ordine di oggi del reducer (`applyCommand`) prima di ogni modifica: aggiunte con e senza coda ereditata, coda piena, `move` che adotta il flag del vicino, `remove` del corrente, `next`/`jump`/`trackEnded`. Nessun cambio a `lib/`.

**Fatto quando:** i test nuovi in `test/jam/jam_state_test.dart` sono verdi sul codice di oggi; R-88 coperto (tre aggiunte di fila, nell'ordine, prima del primo `inherited`).

### 65.2 — Swipe e ⋮ online dell'ospite (R-89, D-180)
Prima un test widget che riproduce il difetto: ospite in Jam, swipe «in coda» su `OnlineSongRow` e ⋮ → «Aggiungi in coda» da `onlineTrackActions` (⋮ del player su un brano online). Sospetto: `onlineTrackActions` → `addToQueue` → `addLibraryIds`, che gestisce solo id di libreria e righe `stream:`. Correzione: lo stesso instradamento di `enqueueOnline` (`_onlineToJam` → `addOnline`).

**Fatto quando:** il test che riproduce fallisce prima e passa dopo; swipe, ⋮ della Ricerca e ⋮ del player arrivano a `JamController.addOnline`.

### 65.3 — Uscita dell'ospite con la coda ritrovata (R-90, R-91, D-178, D-209)
`JamController`: all'ingresso da ospite salva coda, indice, posizione e stato del player (su disco, con la persistenza della coda che c'è già: un'app che muore durante la Jam ritrova la coda al riavvio); in `_teardown` dopo «Esci dalla Jam», «Termina» dell'host o Jam persa ripristina tutto in pausa. Test di R-21 (host + ospite in memoria: l'ospite esce, i suoi `yt:` non suonati restano e l'host li prepara da sé) se non c'è già.

**Fatto quando:** test «coda [A,B,C] su B a 1:00 → esce → stessa coda, B, 1:00, in pausa» per uscita, fine e Jam persa; test di riavvio a metà Jam; test R-21 verde.

### 65.4 — Copertine dei brani degli altri (R-92, D-205)
`JamCover` (`jam_parts.dart`): per un item di un altro con `ref` numerico usa `jamTrackCoverProvider` (`fetchCover` → `GET /<sid>/cover/<n>`, oggi senza consumatori); per un item con `videoId` la miniatura di YouTube con lo stesso helper della Ricerca online; la nota resta solo se non c'è niente. Vale per il player della Jam e per la coda.

**Fatto quando:** test widget per i tre casi (proprio, di un altro, `yt:`); nessuna richiesta di copertina ripetuta a ogni rebuild (provider in cache per item).

### 65.5 — «Scarica» che segue lo stato del brano (R-93, D-181)
Il ⋮ del player su un brano online (`track_actions.dart`, voci a :110 e :254) legge lo stato del brano da un provider invece di una fotografia all'apertura: quando il brano entra in libreria la voce «Scarica» sparisce a foglio aperto.

**Fatto quando:** test widget: foglio aperto, il brano diventa di libreria, la voce sparisce senza chiudere il foglio.

### 65.6 — «Precedente» deciso dall'host (R-95, D-215)
Comando nuovo `JamCommandType.previous`: l'host applica la regola di `jamPreviousCommand` (D-160) sul suo stato al momento del comando. L'ospite manda `previous` invece di calcolare `seek(0)`/`jump` su uno stato che può essere vecchio. Un host senza `previous` (versione di prima) risponde `invalid`: l'ospite ripiega sul calcolo di oggi.

**Fatto quando:** test del reducer («successivo» poi «precedente» entro 3 s con stato dell'ospite in ritardo → brano prima da 0); test del ripiego verso un host vecchio; `remote_transport_test` aggiornato di proposito.

`remote_transport_test` non cambia perché usa un trasporto finto; il ripiego è provato da `jam_transport_test`, `jam_controller_previous_test` e dal test HTTP in `jam_integration_test` (comando sconosciuto → `JamError.invalid`).

### 65.7 — Scarto fra i telefoni (R-94, D-204, K-JC-05)
Prima la misura: log di `JamSyncController.decide` e di `onSyncError` sull'ospite e posizione mostrata nel player della Jam contro quella attesa (`JamState.positionAtTime(jamNowMs)`). Se lo scarto è nella posizione mostrata, si corregge la fonte della posizione della schermata (stessa `SmoothPosition` del player, fase 59); se è nell'audio, si corregge `jam_output.dart`. Risultato «Prima / Dopo» scritto in questo documento.

**Fatto quando:** test che riproduce lo scarto (orologi finti) verde dopo la correzione; con i due telefoni sull'hotspot audio ≤ 80 ms e posizione mostrata ≤ 0,3 s (passo `[~]` finché l'utente non fa la prova, D-169).

#### 65.7 — Prima / Dopo
**Prima.** `JamOutput` veniva creato in `JamController` senza `nowMs`, quindi in Jam con una sola uscita (caso normale, anche l'ospite) il bersaglio `positionAtTime(...)` usava l'orologio LOCALE del telefono mentre `positionAt` è nell'orologio dell'host: scarto = differenza fra gli orologi di sistema (secondi, plausibile i ~2 s di 63.5), tolleranza 1,5 s, nessuna correzione continua. In più `JamPlayerView._feed` leggeva `jamNowMs()` solo a ogni nuovo stato: se l'orologio della Jam si affinava dopo (sync iniziale, poi +5 s e ogni 30 s) la posizione mostrata restava con l'offset vecchio fino al prossimo stato. La posizione mostrata usa già `positionAtTime(jamNowMs())` + `SmoothPosition`; `JamSyncController.decide` (soglie 25/120 ms, seek, latenza) è corretto con orologi sfasati (già coperto da `jam_output_test` con `hostSkew`).
**Dopo.** `JamOutput` usa `clock.jamNowMs` come `nowMs` predefinito quando c'è un clock (test «single output with a Jam clock…», rosso prima); il player della Jam rilegge la posizione ogni 3 s (non mentre un seek dell'utente attende la risposta); con una sola uscita `_tick` ricontrolla il bersaglio sull'orologio della Jam e fa seek oltre `jamSingleOutputReseek` (500 ms, non nel primo secondo dopo l'avvio) al massimo una volta per ogni valore dell'offset del clock e solo sul brano caricato. Log nuovi: `jam sync: measured …ms, offset …ms, lat …ms -> JamSyncAction(...)` (solo quando la decisione non è vuota) e `jam ui: shown position moved …ms on refresh`; già esistente `jam sync: error …ms, clock offset … (rtt …)` ogni 10 tick.
**Misura sui telefoni (28/10, Mi A3 host, Motorola ospite, stessa rete, APK con 65.6).** `clock offset 2204 ms` (rtt 13–14 ms): gli orologi dei due telefoni differiscono di 2,2 s, la causa dei ~2 s di 63.5, ora compensata. Con due uscite `jam sync: error` su 26 campioni: mediana 2 ms, a regime ±2–5 ms (≤ 80 ms), picchi fino a 177 ms solo nei primi secondi dopo un cambio brano. Posizione mostrata: 12 coppie di screenshot simultanei con la stessa lettura al secondo (≤ 0,3 s). Resta da capire `jam ui: shown position moved` di −1,2…−1,4 s a ogni avvio di brano (la posizione mostrata salta indietro una volta): rimandato, vedi `docs/handoff.md`.

### 65.8 — Controlli di fase
`flutter analyze`, comando mirato, `/code-review high` sul protocollo, scheggia in modalità passo su 65.3 e 65.6, review di architettura Opus. Spunta R-88 … R-95 in `docs/feature-jam-cassa.md` (colonna Fase).

**Fatto quando:** tutto verde; i rilievi 1–5 di `docs/handoff.md` («Jam: rilievi aperti») marcati chiusi o rimandati con il motivo.
