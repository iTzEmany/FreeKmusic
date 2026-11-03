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
- Decisione: la cifratura supera 8 ms, la decifratura no (resta sul thread della UI). Progetto dopo la review: `packState` (pura, anche per l'isolate) fa JSON, taglio e zlib **una volta sola** (il controllo del budget riusa i byte compressi) e dà lo stato già incorniciato; `JamChannel.sealPacked` fa solo l'AEAD, sincrono, con il contatore di sempre. `JamBridgeHost` consegna lo STATE con un solo pacchetto alla volta (`Isolate.run` dal 40° item in su, sotto in linea), sempre dell'ultima versione, condiviso da tutti i canali. Se nel frattempo arrivano altre versioni, il pacchetto finito non viene consegnato e ne parte uno solo, dell'ultima (nessun isolate per versione intermedia). `_delivered` è l'ultima versione davvero sigillata e pubblicata; ogni membro ha l'ultima versione che ha ricevuto (ACCEPT compreso), così SYNC o più cambi ravvicinati non producono consegne doppie. La consegna usa i canali catturati alla richiesta: un membro rientrato con un canale nuovo è saltato (log). RESULT di un comando che ha portato lo stato a v esce solo quando `_delivered >= v`; se il pacchetto fallisce, l'ultimo stato è impacchettato e sigillato in linea e poi i RESULT in attesa escono. PING, TIME, BYE, ACCEPT non vanno mai in coda: sincroni, con l'ora dell'invio. `stop()` non attende: se `_delivered` è indietro, impacchetta, sigilla e pubblica lo STATE finale in linea prima dello smontaggio (gli `ended` arrivano sempre), poi azzera lo stato di consegna (anche `start()`), così un pacchetto ancora in volo è ignorato. Ogni errore è un `AppLog.w`. Una sola codifica+zlib: `_fit` salta zlib se il JSON è ben sotto il budget (ACCEPT) e `_frame` è l'unica cornice (flag, soglia 256 B, compresso solo se più piccolo). In più, `aeadEncrypt` e `_finishSeal` copiano con `setAll` invece degli spread (da 4,3 a 1,2 ms per canale). ACCEPT resta in linea (una volta per ingresso).
- Dopo (stessa corsa, schermo sbloccato): pacchetto nell'isolate media 8,9 ms, massimo 18,2 ms; sigillo per canale sul thread della UI media 1,2 ms, massimo 7,2 ms; decifratura in linea media 4,8 ms, massimo 8,8 ms; blocco più lungo del ciclo degli eventi della UI nei 50 giri 17,6 ms (a riposo 25,9 ms: rumore del telefono). Prima, nella stessa corsa: cifratura tutta sulla UI media 15,0 ms, massimo 37,4 ms.
- Test: `jam_bridge_host_test.dart` (un solo pacchetto con 4 ospiti, raffica di 10 versioni con al più 2 pacchetti, RESULT dopo lo STATE anche se la versione è superata, TIME e PING non trattenuti e con l'ora corrente, BYE durante un pacchetto, fine della Jam durante un pacchetto, `stop()` e `start()` sulla stessa istanza, pacchetto che fallisce con STATE in linea, rientro con canale nuovo, SYNC con consegna in attesa) e `jam_protocol_test.dart` (stesso stato dall'isolate, stato troppo grande).

### 73.2 — Prova a mano con due telefoni (2026-11-03)
Fatta in autonomia via adb sull'APK di debug del master c5404d4 (D-337 superata: il Motorola c'era). Ruoli invertiti rispetto al piano: **Mi A3 host** sul Wi-Fi dell'università (UniBA-802.1x, segnale debole), **Motorola ospite su 4G** (Wi-Fi spento), sempre in «Coda dell'host» per proteggere la coda del Motorola. Broker predefinito.
- **Ingresso via Bluetooth: OK.** Banner sul Motorola in < 15 s, richiesta sull'host in < 3 s, Jam attiva sul Motorola 2 s dopo «Accetta». Per far partire l'annuncio sul Mi A3 (Android 11) sono serviti il permesso di posizione precisa (dato a mano con `pm grant`) e un riavvio del Bluetooth (stack saturo per un'altra app, «MAX client reached: 32»); sul Motorola la ricerca è ripartita solo spegnendo e riaccendendo «Cerca Jam vicine». Da guardare in 74.6.
- **Aggiunte dall'ospite: OK.** Un brano della libreria e uno dalla Ricerca sono entrati nella coda dell'host come «aggiunto da Ema» e sono stati suonati; il brano di libreria è partito solo dopo i 15 s di `jam: no lookup for …`.
- **Amici: OK in parte.** Dopo il primo ingresso i due si salvano a vicenda; con «Accetta gli amici senza chiedere» il Motorola rientra dal banner senza conferma in < 2 s. L'etichetta «Amico» sulla richiesta non è stata vista: il secondo ingresso è avvenuto col codice digitato (dove per spec non c'è) perché la ricerca Bluetooth non ripartiva (bug sotto).
- **Host in pausa a schermo spento: OK** (circa 10,5 min, con una riaccensione a metà). Jam viva, ospite ancora dentro, «Riproduci» dal Motorola ha fatto ripartire l'host.
- **Ospite in modalità aereo 1 min: OK.** «Connessione persa, riprovo…», rientro da solo 36 s dopo; l'host lo mostra «non raggiungibile» fino al rientro.
- **Ospite in modalità aereo 11 min: OK.** L'host lo toglie, il Motorola esce dalla Jam e ritrova la sua coda (brano 36 di 2311).
- **KO confermato:** Casuale+ torna Casuale all'uscita dalla Jam (due volte su due) → 74.3.
- **Bug nuovo:** se la Jam finisce mentre l'ospite non ha aperta la schermata Jam, la ricerca delle Jam vicine non riparte (fase `ended`, `_wanted()` in `jam_nearby_providers.dart`) → 74.6.
- **Rete:** buchi di 1–2 min sul Wi-Fi dell'università; la Jam si è sempre ripresa da sola. Sul Mi A3 il ponte andava spesso in timeout (4 s) mentre il PC sulla stessa rete chiudeva il TLS col broker in ~1 s → 74.6 (primo «Entra»).
- **Non provati:** ingresso col QR (serve la fotocamera), Sospendi/Blocca da remoto, riserva fra broker (lista con una sola voce).
- Pulizia: amici tolti da tutti e due, «Accetta gli amici senza chiedere» spento, ponte spento, Casuale+ rimesso sul Motorola, modalità aereo spenta, nessun brano scaricato sul Motorola.

