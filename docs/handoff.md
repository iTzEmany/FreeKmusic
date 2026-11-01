# Handoff — 2026-10-31 (fasi 69a e 69b chiuse: un solo motore di arricchimento)

## Riconoscimento del brano (kickoff 2026-11-01, fasi 69c–69e)
Feature nuova, **prima della fase 70**: prima di arricchire, l'app riconosce il brano (ISRC/MBID → video id → testo → AcoustID → YouTube Music) e arricchisce dall'identità; le cover portano le curiosità dell'originale. Documento: `docs/feature-riconoscimento.md` (R-160…R-188, rischi K-RB-01…09); decisioni D-299…D-323; fasi `docs/fase-69c-*.md`, `fase-69d-*.md`, `fase-69e-*.md`.

**Fase 69c chiusa** (PR #77):
- impronta Chromaprint in Rust: 145/147 brani di Test.zip danno lo stesso primo recording di fpcalc, +1,2…2,2 MB per ABI, 0,7 s sul Mi A3;
- `read_ids` per MBID e ISRC, ripiego su lofty per le date strane;
- query più pulite, Deezer acceso di serie.

Esiti in `docs/fase-69c-fondamenta-riconoscimento.md`.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 69d
```
Poi `/obiettivo fase 69e`; solo dopo si torna alla 70. In 69d.4 si rimisura Test.zip: dopo il taglio dell'impronta a 120 s esatti non è stato rifatto.

Da sapere:
- **69c.1 blocca tutto:** se l'impronta di rusty-chromaprint non coincide con fpcalc, si applica D-316 (copia in `third_party/` e un passo di correzione), poi ci si ferma e si chiede.
- **Strumenti mancanti sul PC:** fpcalc (va scaricato nello scratchpad, solo per la prova) e `flutter_rust_bridge_codegen` 2.11.1 (c'è la 2.13.0).
- **Test.zip** (147 brani dell'amico) è in `~/Downloads/Test.zip`: serve alla prova di 69c.1, 69d.4 e 69e.4, non entra mai nel repo. La prova si fa su un DB separato, non sulla libreria dell'utente.
- **Chiavi AcoustID:** `Hsn5w6Tjwv` è la chiave dell'applicazione e va in `lib/core/app_info.dart`. La chiave utente non serve (si usa solo per inviare impronte, R-187 rimandato) e non entra mai nel repo né nei documenti.
- **Trappole dell'architettura:** `CreditsEnricher.save` sovrascrive tutto `track_enrich.details` (serve un solo punto di scrittura che unisce `rec`); `userEdited` vale per tutto il brano (una correzione automatica non lo segna, D-318).

## Prima di tutto (per la prossima chat)
Il refactor «arricchimento-unico» è chiuso: 69a (PR #72) e 69b (PR #73). Si torna alla fase 70, a partire dalla sezione «Rilievi dalla fase 69» di `docs/fase-70-ponte-jam-distanza.md`.

## Arricchimento (69a, 69b)
- **Motore unico** in `lib/services/online/enrich_*.dart`: `EnrichEngine` (gather/commit con gli id in volo), `EnrichRunner` (blocchi di 10, segnalibro o lista fissa), `EnrichWriter` (l'unico che scrive `enrich_status`), regola `isDue`/`AskMode`. Descritto in `docs/02-architettura.md` §«Arricchimento».
- Manuale e background usano lo stesso runner. In Impostazioni c'è un solo comando, «Arricchisci tutta la libreria», e nel pannello una sola barra.
- **Misura sul Motorola (31/10):** circa 1 brano al minuto, per il limite Wikimedia da anonima. La stima dei minuti ora conta 40 s a brano.
- **Rimandati** (elenco in `docs/fase-69b-arricchimento-unico.md`): `propose` fuori dal motore, cache del motore nel completer, `completeOne(AskMode)`, il conteggio in `retryNone` che arriva di rado a «Libreria completa».
- **Contatto nello User-Agent** (D-298): dal 31/10 è l'indirizzo del repo, e Wikimedia concede 150 richieste al minuto invece di 8. Il ritmo nuovo non è misurato: la stima ora usa 3 s a brano, la cifra di prima del 69b.4.
- **Scelta tua:** se «Libreria completa» debba contare in `due` invece che in `retryNone`.

## Fase 69 (chiusa, PR #67)
La fase 69 è nel codice (PR #67). Comprende i rilievi della prova 68.3 (69.1…69.3) e i mattoni della Jam a distanza:
- `JamGuestLink`;
- `JamGate` (2 richieste al minuto, Sospendi, Blocca), salvato in `JamSecretStore`;
- `jam_crypto` su `sodium`;
- broker MQTT con «Prova connessione».

Decisioni D-264…D-273 in `docs/decisioni.md`. Ora si passa alla fase 70 (`docs/fase-70-ponte-jam-distanza.md`): prima la sezione «Rilievi dalla fase 69», poi 70.1.

## Stato
- **69.1**: la Jam della cassa si riapre quando l'hub torna attivo.
- **69.2**: l'ospite che esce di sua volontà vede «Sei uscito dalla Jam» (D-266).
- **69.3**: 20 posti per le aggiunte a mano (D-264). «Jam piena» solo quando lo è davvero, altrimenti «Non aggiunto alla Jam».
- **69.5–69.9**: interfaccia dell'ospite, gate con le liste in «Rete e dispositivi» (D-271), cifratura, broker. Secondo archivio delle cose segrete: `jam_secrets.json` su desktop, DataStore su Android, fuori dai backup (D-269).
- **69.10**: prova in LAN sul Mi A3 con Linux riuscita (esiti nel documento di fase).
- Broker in diretta: `broker.emqx.io:8883` funziona; `test.mosquitto.org` 8883 è rifiutato per il certificato, come previsto, e 8886 chiude dopo il CONNECT.

## Tocca a te
- **69.4 finita in autonomia (D-274)**, esiti in §69.4. Restano solo:
  - «Scarica» che sparisce a foglio aperto, da provare con un brano lungo;
  - decidere se la schermata Jam debba avere il ⋮ con «Scarica».
- **Coda del Motorola**: dopo la prova del 30/10 i primi 6 brani della coda sono quelli di prima, il seguito no (D-186: l'ospite ritrova la sua parte non suonata). Il volume A2DP del Mi A3 è tornato a 7.
- **Mosquitto 8886 da decidere** (D-258): chiude ogni connessione dopo il CONNECT, in tre giri, con TLS valido. Puoi toglierlo dalla lista predefinita (`kDefaultJamBrokers`) o sostituirlo con un altro broker TLS pubblico.
- **Prova a mano del gate**: «Fino alla fine della Jam» durante una Jam vera (e che sparisca al riavvio); una sospensione di 15 minuti che scade.
- **Dalle fasi 66–68** (sezione «Tocca a te» del handoff precedente, nella storia di git):
  - fase 67 sul Motorola;
  - scoperta su /16;
  - fase 66 a mano;
  - pulizia del Mi A3 (Scheggia66, `com.codecore.player.perf`);
  - «La Jam è terminata» per l'ospite che esce: risolto da D-266, da riprovare in 69.4;
  - ascolto 57.7, APK di release con NewPipe, tag `v1.3.0`.

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

## Prompt di avvio della prossima sessione
```
/obiettivo fase 70 (ponte e protocollo della «Jam a distanza», docs/fase-70-ponte-jam-distanza.md: prima §Rilievi dalla fase 69)
```

## Prossimi obiettivi
1. **(Consigliato) Fase 70, ponte e protocollo**: si parte dai rilievi della fase 69 scritti in cima al documento di fase. La prima scelta è il tipo delle chiavi in `JamCrypto` (D-272).
2. **69.4 a mano**: chiude anche i `[~]` delle fasi 67 e 68.
3. **Unificare le due code delle domande sulla cassa**.
4. **Ricerca «notte», build p99** (D-176) e prove d'ascolto 57.7.
