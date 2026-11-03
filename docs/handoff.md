# Handoff — 2026-11-03 (fase 75 chiusa: testo, curiosità e crediti dei brani in streaming)

## Stato
**Fase 75 chiusa** (PR #95): i brani in streaming (ricerca online, Shuffle+, Radio) mostrano testo, curiosità e crediti della riga ombra, con un segnaposto «in arrivo» finché la riga non c'è; l'arricchimento parte appena il brano corrente ha la riga (file in cache), anche in pausa (D-351, al posto dei 5 s di D-345); i pre-caricati non si arricchiscono. Provato sul Mi A3. Esiti in `fase-75-arricchimento-stream.md`. **Fase 74 chiusa** (PR #93), esiti in `fase-74-coda-jam-e-rifinitura.md`.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 76
```
oppure uno dei «Prossimi obiettivi» qui sotto.

## Da riprovare o capire
- Jam in LAN della fase 74 non provata dal vivo (la rete UniBA isola i client): rifarla a casa.
- Il nuovo tentativo del primo «Entra» non è mai scattato dal vivo (il primo CONNECT è sempre riuscito il 3/11).
- Il «+» di Casuale+ si scrive ~400 ms dopo; una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).
- L'app di misura `com.codecore.player.perf` è stata disinstallata dal Mi A3 da `flutter drive` (73.1): `perf_device.py` la reinstalla.

## Tocca a te
- **Fase 75 a mano**: un suggerito online di Shuffle+ in coda (niente arricchimento finché non suona), il segnaposto «in arrivo» a vista, «Proposta di correzione» su un brano della libreria; l'APK debug della fase 75 è installato sul Mi A3.
- **Mi A3 dopo la prova 74.7**: è rimasto l'amico «emanuele-Aspire-A515-45» in «Jam a distanza» e lo shuffle su Casuale+ (prima era spento); la prova ha spento e poi rimesso la posizione (`location_mode` 3). Toglili a mano se non ti servono.
- **Resto della 73.2** (fatta il 3/11, esiti in `fase-73-chiusura-jam-distanza.md`): ingresso col QR (serve la fotocamera), Sospendi/Blocca da un ospite remoto, riserva fra broker con due voci nella lista.
- **Mosquitto 8886** (D-258): chiude ogni connessione dopo il CONNECT; toglierlo da `kDefaultJamBrokers` o sostituirlo.
- Prova a mano del gate (sospensione di 15 minuti che scade; «Fino alla fine della Jam»); 69.4: «Scarica» che sparisce a foglio aperto.
- Dalle fasi 66–68: fase 67 sul Motorola, scoperta su /16, fase 66 a mano, ascolto 57.7, APK di release con NewPipe, tag `v1.3.0`.

## Dispositivi
- **Motorola edge 40** `ZY22HKD85K`: libreria vera. Solo `install -r`; mai disinstallare né `pm clear`. 120 Hz.
- **Mi A3** `0d7ae9df206e`:
  - si disinstalla solo con `-k`; mai cancellare i file musicali;
  - le misure vanno sull'app `com.codecore.player.perf`;
  - volume della musica a 0;
  - a schermo spento si blocca col PIN.
- **JBL**: si spengono da sole dopo circa 20 minuti senza suono.
- Su entrambi i telefoni: mai toccare la rotazione o le impostazioni di sistema.
- **Misure**: `python3 scripts/perf_device.py <id> --label <l> [--no-build --no-push --apk <apk>] [--only "A,B"]`. Per un A/B: un worktree per commit e run alternati A, B, A, B.
- **APK**: si compila con `JAVA_HOME=~/.jdks/jbr-17.0.14` (`docs/gotchas.md`).

## Rinviato
- **Due code per le domande sulla cassa** (`SpeakerMonitor._pending` e la coda della UI): da unificare.
- 53.10 completamento intero sul Motorola: con il motore unico avanza, ma a circa 1 brano al minuto (vedi sopra).
- Il messaggio «perché niente Shuffle+» (D-87) su un album da 1 brano.
- Gli interruttori del completamento che fermano il giro manuale.
- Il debito dello streaming, in fondo a `docs/fase-47-jam-online.md`.

## Prossimi obiettivi
0. **(Consigliato) Fase 76**: i suggeriti online di Shuffle+ entrano in coda appena c'è l'indirizzo, non dopo il download completo, e ogni blocco di ~3 si arricchisce prima di suonare (D-352, D-353, `fase-76-suggeriti-veloci.md`).
1. **(Consigliato) Debito della fase 74** (dalla review di architettura): estrarre `JamLocalQueue` da `JamController` (`jam_providers.dart` è a ~1360 righe; `_saved`/`_mode`/copia `jamAside`, valori di dominio a `keepAside`, `_part.unplayed` calcolato una volta per stato); un solo helper «riprova subito sullo stesso broker» per `JamBridge` e `_lookupCode`; un solo limite della posizione oltre la durata; unire `jam_queue_owner_name_test.dart` a `jam_queue_sheet_test.dart`; nome dell'ospite uscito ricordato per tutta la Jam, non solo a foglio aperto.
2. Unificare le due code delle domande sulla cassa (`SpeakerMonitor._pending` e la coda della UI).
3. Ricerca «notte», build p99 (D-176); 53.10 completamento intero sul Motorola.
