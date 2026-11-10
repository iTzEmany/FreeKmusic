# Fase 71 — Coda dell'ospite remoto (feature «Jam a distanza»)

**Obiettivo:** l'ospite remoto mette in coda dalla sua libreria, dalla Ricerca online e da «Coda insieme»; all'host arriva solo il video id e il brano lo scarica o lo riproduce lui. L'ospite remoto vede copertine, scheda e testo senza chiedere niente all'host.

**Prerequisiti:** fase 70 chiusa. Requisiti R-151 … R-155; decisioni D-93, D-240, D-241, D-247. Aree a rischio: protocollo Jam, ordine della coda (`jam_part_feeder.dart`). Nessun pacchetto nuovo.

**Comando mirato:** `flutter test test/jam test/ui/jam_screen_test.dart test/ui/jam_parts_test.dart test/ui/jam_track_info_screen_test.dart` (più i test di `SeedResolver` se cambia).

## Rilievi dalla fase 70 (review di architettura, da fare dentro i task sotto)
- **71.1**: in 70 l'ospite remoto non avvia il feeder (`_part.start` saltato con `state.remote`) e «Aggiungi alla Jam» è nascosto: riaccenderli qui; il riduttore rifiuta già da un remoto gli item non `yt:`.
- **Ordine sparso**:
  - il segno «non raggiungibile» lo legge la UI da `shareHubProvider.notifier.jamHost?.unreachableIds()` in `jam_player.dart`: spostarlo in `JamUiState` (si aggiorna oggi solo col timer da 10 s);
  - la shell deve guardare `jamBridgeProvider` direttamente (oggi lo tiene vivo `speakerJamProvider`);
  - ciclo di import `share_hub` ↔ `jam_remote_providers` ↔ `jam_providers`: spostare `jamGateProvider` e `jamSecretStoreProvider` fuori da `jam_remote_providers.dart` (servono anche alla LAN);
  - `expire()` chiamata due volte (timer del controller ogni 10 s e `JamBridgeHost.tick` ogni secondo): ne basta una;
  - test che aspettano tempo reale (`jam_mixed_test.dart` ~1,5 s, `remote_jam_guest_test.dart` ~1,2 s, `graceOver` 700 ms): iniettare il timer dei tentativi di `JamBridge` e `stopGrace` nel provider.

## Task

### 71.1 — `JamRemoteItems` e aggiunte (R-151, R-152, D-240)
`lib/services/jam/remote/jam_remote_items.dart`: `Track` → item `yt:youtube:<vid>` (`selfFetchable`) con `SeedResolver.resolve` (download che ha fatto il file, poi indice, poi ricerca solo sicura); null → «Non trovato online, non si può aggiungere». Da ospite remoto `JamPart` usa `JamRemoteItems` invece di `jamItemOfTrack` e `addOnline` manda subito l'item `yt:` senza scaricare. «Aggiungi» torna visibile per l'ospite remoto.

**Fatto quando:** test con un resolver finto: brano con video id → item `yt:` senza ricerca; senza → ricerca, trovato → item, non trovato → messaggio e nessun comando inviato; simulazione host + ospite remoto: aggiunta dalla Ricerca online → item `yt:` nella coda dell'host e preparato dall'uscita, nessun messaggio oltre RNF-14.

### 71.2 — «Coda insieme» da remoto (R-153, D-247)
Il feeder della parte di un ospite remoto e i suoi suggeriti passano da `JamRemoteItems`; i brani non trovati si saltano senza fermare il turno.

**Fatto quando:** test del feeder con un resolver finto: non trovati saltati, gli altri entrano a turno come oggi.

### 71.3 — Copertine, scheda e testo (R-154, R-155, D-241)
`jamItemOfTrack` mette `vid` = `DownloadIndex.idForPath(path)` sui brani di libreria dell'host. `JamCover` per l'ospite remoto: video id → miniatura di YouTube, senza → la nota; in LAN resta la copertina del proprietario. Scheda, testo e curiosità dell'ospite remoto dal video id e dai metadati, come nella Jam come player (fase 63).

**Fatto quando:** test widget di `JamCover` da ospite remoto (miniatura, nota, nessuna richiesta a `/cover`); test che la scheda di un item `yt:` non chiama l'host; i test LAN delle copertine invariati.

### 71.4 — Controlli di fase
`flutter analyze`, comando mirato, `/code-review high` su 71.1 e 71.2, scheggia in modalità passo su 71.1, review Opus. Prova in autonomia: Linux host, Mi A3 ospite remoto col codice; aggiunte dalla libreria (con e senza video id) e dalla Ricerca, «Coda insieme» con un brano introvabile.

**Fatto quando:** tutto verde; esiti qui sotto; colonna Fase di R-151 … R-155 compilata.

## Esiti (2026-11-02)
- 71.1–71.3 fatti in una PR (ramo `feat/71-coda-remota`), più i rilievi «ordine sparso» della fase 70: ciclo `share_hub` ↔ `jam_remote_providers` rotto (`jam_gate_providers.dart`), la shell tiene vivo `jamBridgeProvider`, attese dei test iniettabili (`JamBridge.waits`, `jamStopGraceProvider`), «non raggiungibile» in `JamUiState`. Il doppio `expire()` resta voluto (D-335).
- Controlli: `flutter analyze` pulito, comando mirato verde, `/code-review high` (10 rilievi, tutti corretti), scheggia in modalità passo (4 bug riprodotti e corretti, mutanti scoperti coperti), review di architettura Opus (rilievi da fare corretti; tre rimandati in `fase-72-bluetooth-e-amici.md`).
- Scelte: D-335, D-336. Testo e curiosità dell'ospite remoto cercati sul suo telefono per titolo e artista, senza scrivere nel DB, in cache per la durata della Jam.
- Prova dal vivo del 3/11 su master 9c1217b (Linux host in xvfb, Mi A3 ospite remoto col codice, broker predefinito): tutto ok.
  - Ingresso: richiesta sull'host in 4–6 s, Jam sul Mi A3 3 s dopo «Accetta» (un primo «Entra» in timeout isolato verso broker.emqx.io, riuscito al secondo).
  - Dalla libreria: brano scaricato da YouTube in coda in ≤ 9 s e preparato dall'host (4,9 s); brano locale senza video id ma noto in ~10 s; brano introvabile → «Non trovato online, non si può aggiungere» in ~3 s, nulla in coda.
  - Dalla Ricerca online: in coda sull'host in ~6 s.
  - «Coda insieme»: i non trovati saltati (~0,5 s l'uno) senza fermare il turno, i trovati entrati a turno.
  - Ospite: copertine dalle miniature (prima la nota, poi la miniatura); scheda con testo e curiosità dove esistono; nessun errore verso l'host nel log.
  - «Esci»: il Mi A3 ritrova la sua parte, compresi i brani saltati (riparte dal brano corrente, come D-186); «Termina» chiude la Jam.
  - Da guardare: la vista dell'host mostra il nome generico «Telefono» per la Jam e un nome vuoto per l'ospite dopo l'uscita.
