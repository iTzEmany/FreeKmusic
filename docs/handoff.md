# Handoff — 2026-11-03 (feature «Jam a distanza» chiusa: fasi 71–73)

## Stato
**Fasi 71–73 chiuse** (PR #87, #88, #89 e la PR della 73). L'ospite remoto mette in coda come video id e vede copertine, scheda e testo da sé (71). Su Android la Jam si annuncia via Bluetooth e gli amici si riconoscono col nome salvato (72). La cifratura dello STATE gira in un isolate: sul Mi A3 costava 16,4 ms medi (73.1). Esiti nei documenti di fase; scelte D-335…D-339.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo
```
oppure uno dei «Prossimi obiettivi» qui sotto.

## Da riprovare o capire
- Il primo «Entra» col codice dal Mi A3 va spesso in timeout verso broker.emqx.io (10–12 s, «Broker irraggiungibile»), poi riesce al secondo tentativo.
- Aprendo «Dispositivi» con la posizione spenta (Android ≤ 11) il messaggio non è comparso; dall'interruttore sì.
- Nella vista dell'host la Jam di un ospite Android si chiama «Telefono» (nome generico del dispositivo) e l'ospite uscito ha il nome vuoto.
- L'app di misura `com.codecore.player.perf` è stata disinstallata dal Mi A3 da `flutter drive` (73.1): `perf_device.py` la reinstalla.

## Tocca a te
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
- **KO R-102**: a Jam piena il «Suggerito» ripropone brani già suonati nella Jam (§69.4, 30/10). Da correggere con un test che lo riproduce, prima della fase 70 o dentro.
- **⋮ con «Scarica» nella schermata Jam** (R-93, deciso dall'utente il 30/10): oggi «Scarica» c'è solo nel player normale.
- **Da verificare: «Casuale+» torna «Casuale» dopo l'uscita dalla Jam** (visto sul Motorola il 30/10): prima un test che lo riproduce.
- **Bug Shuffle+ (segnalato dall'utente il 30/10)**: con Shuffle+ già acceso, avviare un album o una playlist arricchisce la nuova coda con suggeriti basati sui brani della coda precedente. Sospetto: `_syncSource` svuota pool e semi, ma un `_fill`/`_suggestOne` già in corso (`shuffle_plus_controller.dart`) finisce con i semi vecchi e inserisce lo stesso; il controllo dopo `prepare` non guarda se la sorgente è cambiata. Da riprodurre con un test prima di correggere.
- **Coda di prima della Jam solo in memoria** (`JamController._saved`): l'ospite in «Coda insieme» perde la sua coda originale. Da valutare se salvarla su disco o restituirla intera.
- **Due code per le domande sulla cassa** (`SpeakerMonitor._pending` e la coda della UI): da unificare.
- La posizione mostrata nella Jam salta indietro di circa 1,3 s a ogni avvio di brano (`jam ui: shown position moved`).
- 53.10 completamento intero sul Motorola: con il motore unico avanza, ma a circa 1 brano al minuto (vedi sopra).
- Il messaggio «perché niente Shuffle+» (D-87) su un album da 1 brano.
- Gli interruttori del completamento che fermano il giro manuale.
- Il debito dello streaming, in fondo a `docs/fase-47-jam-online.md`.

## Prossimi obiettivi
1. **(Consigliato) Fase 74** (`fase-74-coda-jam-e-rifinitura.md`, scelte D-340…D-343): rinviati della coda della Jam, «Scarica» e posizione nella Jam, rifinitura della Jam a distanza. Avvio: `/obiettivo fase 74`.
2. Unificare le due code delle domande sulla cassa; ricerca «notte», build p99 (D-176).
