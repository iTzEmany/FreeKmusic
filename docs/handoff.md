# Handoff — 2026-11-02 (fase 70 chiusa: ponte della Jam a distanza)

## Stato
**Fase 70 chiusa** (PR #86): ponte MQTT cifrato, ospiti remoti nell'host, «Invita chi è vicino», «Entra con un codice», servizio in primo piano «Jam a distanza attiva». Esiti della prova dal vivo (Linux host, Mi A3 ospite) in `docs/fase-70-ponte-jam-distanza.md` §«Esiti della prova 70.6».

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 71
```
Si comincia dai «Rilievi dalla fase 70» in `docs/fase-71-coda-remota.md` (feeder dell'ospite remoto, «Aggiungi alla Jam» nascosto, segno «non raggiungibile» da portare in `JamUiState`, ...).

## Da riprovare o capire
- Fase 70 provata dal vivo tre volte (stato iniziale dell'ospite, R-128, foglio dell'invito, ruoli invertiti): tutto chiuso, esiti nel documento di fase.
- Durata degli mp3 corretta alla radice (frame Info di LAME letto come bitrate): libreria corretta una volta all'avvio (`mp3DurationFix1`).
- Wi-Fi spento 30 s: l'ospite torna dopo circa 70 s; se è troppo, vedere le attese di `JamBridge`.

## Fasi chiuse da sapere
- **Riconoscimento (69c–69e, PR #77, #79, #84):** impronta Chromaprint in Rust, `TrackRecognizer`, `TrackCorrections`, cover e ripasso; Test.zip: 126/147 riconosciuti, 0 correzioni sbagliate. Documento `docs/feature-riconoscimento.md`, D-299…D-323, D-333; il resto in `docs/fase-69c-*`, `69d-*`, `69e-*`.
- **Arricchimento unico (69a, 69b):** motore in `lib/services/online/enrich_*.dart` (`docs/02-architettura.md` §«Arricchimento»); circa 1 brano al minuto dal Motorola; rimandati in `docs/fase-69b-arricchimento-unico.md`.
- **Fase 69 (PR #67):** `JamGuestLink`, `JamGate`, `JamSecretStore`, `jam_crypto` su `sodium`, broker MQTT con «Prova connessione» (D-264…D-273).
- Trappole: `CreditsEnricher.save` sovrascrive tutto `track_enrich.details`; `userEdited` vale per tutto il brano (D-318). Test.zip (`~/Downloads/Test.zip`) non entra mai nel repo.

## Tocca a te
- **Mosquitto 8886** (D-258): chiude ogni connessione dopo il CONNECT; toglierlo da `kDefaultJamBrokers` o sostituirlo con un altro broker TLS pubblico.
- Prova a mano del gate (sospensione di 15 minuti che scade; «Fino alla fine della Jam»); 69.4: «Scarica» che sparisce a foglio aperto.
- Dalle fasi 66–68: fase 67 sul Motorola, scoperta su /16, fase 66 a mano, pulizia del Mi A3 (`com.codecore.player.perf`), ascolto 57.7, APK di release con NewPipe, tag `v1.3.0`.

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
1. **(Consigliato) Fase 71, coda dell'ospite remoto** (`/obiettivo fase 71`).
2. (nessuna riprova aperta della fase 70)
3. Unificare le due code delle domande sulla cassa; ricerca «notte», build p99 (D-176).
