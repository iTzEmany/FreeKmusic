# Fase 73 — Misure e prova a mano (feature «Jam a distanza»)

**Obiettivo:** la cifratura non pesa sulla UI del telefono più lento e la feature è provata a mano con due telefoni, uno su 4G, sul broker predefinito.

**Prerequisiti:** fasi 69–72 chiuse. Requisiti R-159, RNF-15; decisioni D-248, D-260; rischi K-JD-05, K-JD-06, K-JD-09.

**Comando mirato:** `flutter test test/jam`; misure sul Mi A3 con l'app `com.codecore.player.perf` (`python3 scripts/perf_device.py 0d7ae9df206e --label fase73 --only "<scenari>"` o un integration test dedicato).

## Task

### 73.1 — Costo della cifratura (RNF-15, K-JD-09)
Sul Mi A3: cifratura e decifratura di uno stato da 64 KB (200 item), media e massimo su 50 giri. Oltre 8 ms → `seal`/`open` delle buste grandi in un isolate (`compute`), con un test che lo stato arriva uguale.

**Fatto quando:** misura con data e dispositivo in questo documento; se serve l'isolate, test verde e misura ripetuta.

### 73.2 — Prova a mano con due telefoni (R-159) [utente]
Motorola host, Mi A3 ospite su 4G (hotspot di un terzo telefono o SIM), broker predefinito. Da provare: ingresso via Bluetooth (banner a 2 m, K-JD-06), via QR, via codice da Linux; un amico riconosciuto alla seconda Jam; aggiunte dalla libreria e dalla Ricerca; Sospendi 15 min e Blocca; voce sbagliata in testa alla lista dei broker → riserva; host in pausa in sottofondo 10 min a schermo spento (K-JD-05); ospite in modalità aereo 1 min (rientra) e 11 min (esce con la coda ritrovata).

**Fatto quando:** esiti scritti qui sotto e in `docs/PROGRESS.md`, uno per riga; i KO diventano passi nuovi o vanno in «Rinviato» con il motivo.

### 73.3 — Chiusura
`docs/handoff.md` aggiornato, colonna Fase di R-159 e RNF-15 compilata, `docs/prossimi-lavori.md` §2 lo segna l'utente (non tracciato), pulizia del disco (`pulizia.sh`).

**Fatto quando:** documenti aggiornati, nessun file temporaneo rimasto.

## Esiti

### 73.1 — Costo della cifratura (2026-11-03)
- Dispositivo: Mi A3 `0d7ae9df206e`, schermo acceso e sbloccato (a schermo bloccato i tempi raddoppiano). Modalità: **profile** (`flutter drive --profile`, app di misura `.perf`), `integration_test/jam_crypto_bench_test.dart`: 200 item, 5 giri di riscaldamento, 50 giri.
- Stato reale: 59 692 B di JSON, 26 187 B dopo zlib, busta cifrata e riempita 26 418 B.
- Prima (tutto sul thread della UI, come faceva il ponte: `fitState` + `seal`): cifratura media 16,4 ms, massimo 28,9 ms; decifratura media 4,6 ms, massimo 7,8 ms (in una corsa precedente 4,3 / 4,8). La cifratura AEAD è trascurabile: il costo è JSON + zlib, ripetuti da `fitState` e da `seal`.
- Decisione: la cifratura supera 8 ms, la decifratura no. `seal` dello STATE (`JamChannel.sealStateAsync`, usata da `_sendState` del ponte) calcola JSON, taglio e zlib in un isolate (`Isolate.run`) quando gli item sono almeno 40; sotto resta in linea. `JamChannel` serializza i sigilli asincroni, così contatori e ordine di pubblicazione restano uguali, e `_send` si accoda se uno STATE è in corso (lo STATE esce prima del RESULT). La decifratura resta sul thread della UI. ACCEPT, che porta anche lo stato, resta in linea (una volta per ingresso).
- Dopo: cifratura in tempo reale 20,0 ms in media, 38,6 ms al massimo (l'isolate costa, ma non è sul thread della UI); blocco più lungo del ciclo degli eventi della UI durante i 50 sigilli 17,8 ms, sotto il rumore del telefono a riposo (40 ms nella stessa corsa). Test unitario: stato uguale e ordine rispettato (`jam_protocol_test.dart`).
