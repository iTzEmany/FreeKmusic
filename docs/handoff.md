# Handoff — 2026-11-03 (fase 74 chiusa: coda della Jam e rifinitura)

## Stato
**Fase 74 chiusa** (PR #93): il «Suggerito» non ripropone i già suonati oltre le 200 voci, Shuffle+ non usa la sorgente di prima, Casuale+ e la coda di prima tornano intatti dopo la Jam anche dopo una chiusura dell'app (copia `jamAside`), «Scarica» nel ⋮ della Jam, posizione della Jam che non salta indietro, rifinitura della Jam a distanza (nome del telefono, primo «Entra», ricerca vicina, posizione spenta, brano `yt:` dell'ospite remoto suonato subito). Esiti in `fase-74-coda-jam-e-rifinitura.md`. Le fasi 71–73 sono chiuse.

Pianificata la **fase 75** (refactor «arricchimento-stream», 3/11): testo, curiosità e crediti anche per i brani in streaming, caricati ~5 s dopo l'avvio. Analisi in `docs/refactor/arricchimento-stream/analisi.md`, niente mockup.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 75
```
oppure uno dei «Prossimi obiettivi» qui sotto.

## Da riprovare o capire
- Jam in LAN della fase 74 non provata dal vivo (la rete UniBA isola i client): rifarla a casa.
- Il nuovo tentativo del primo «Entra» non è mai scattato dal vivo (il primo CONNECT è sempre riuscito il 3/11).
- Il «+» di Casuale+ si scrive ~400 ms dopo; una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).
- L'app di misura `com.codecore.player.perf` è stata disinstallata dal Mi A3 da `flutter drive` (73.1): `perf_device.py` la reinstalla.

## Tocca a te
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
1. **(Consigliato) Debito della fase 74** (dalla review di architettura): estrarre `JamLocalQueue` da `JamController` (`jam_providers.dart` è a ~1360 righe; `_saved`/`_mode`/copia `jamAside`, valori di dominio a `keepAside`, `_part.unplayed` calcolato una volta per stato); un solo helper «riprova subito sullo stesso broker» per `JamBridge` e `_lookupCode`; un solo limite della posizione oltre la durata; unire `jam_queue_owner_name_test.dart` a `jam_queue_sheet_test.dart`; nome dell'ospite uscito ricordato per tutta la Jam, non solo a foglio aperto.
2. Unificare le due code delle domande sulla cassa (`SpeakerMonitor._pending` e la coda della UI).
3. Ricerca «notte», build p99 (D-176); 53.10 completamento intero sul Motorola.
