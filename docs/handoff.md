# Handoff — 2026-11-04 (fase 77 chiusa: rete di sicurezza, Skeleton, CcSearchField)

## Stato
**Fase 77 chiusa** (PR #101): test di caratterizzazione di Home, Libreria, Tutti i brani, generi e recenti; scenario perf «Libreria Tutto→Playlist→Album→Artisti» con misura di partenza (Mi A3: build p90 6,6 ms, già sotto la soglia di 16 ms; Linux in «Esiti»); `Skeleton` al posto dello spinner di `AsyncBody`; `CcSearchField` con ✕ a tre stati nel dock e in Cerca desktop; Cerca dal dock senza tastiera (provato sul Mi A3). I limiti delle API dei due componenti emersi dalla review sono nelle sezioni «Dalla review della fase 77» dei doc 78, 79, 81, 83.

**Fase 76 chiusa**: i suggeriti online di Shuffle+ entrano in coda appena c'è l'indirizzo (4–6 s invece di ~40 s sul Mi A3, D-352) e si arricchiscono a blocchi di 3 prima di suonare (D-353). Esiti in `fase-76-suggeriti-veloci.md`. **Fase 75 chiusa** (PR #95): testo, curiosità e crediti dei brani in streaming, arricchiti appena il brano corrente è in cache (D-351).

**Refactor «ui-uso-quotidiano» pianificato** (4/11): fasi 77–83 dalle richieste dell'utente sull'uso di tutti i giorni (Home, Cerca solo online, Libreria senza lag e con ricerca, Radio, Statistiche, skeleton, player vuoto, Registro, «Accetta tutte»).

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 78
```

## Da sapere (refactor ui-uso-quotidiano)
- Analisi, scelte, arrivo, rete e metriche: `docs/refactor/ui-uso-quotidiano/analisi.md`; decisioni D-354…D-375.
- Mockup approvati (specifica visiva, le note numerate di ogni file contano): `docs/refactor/ui-uso-quotidiano/mockup/indice.html` e gli 11 file accanto (`home`, `cerca`, `libreria-ricerca`, `radio`, `statistiche`, `tutti-i-brani`, `player-vuoto`, `streaming-skeleton`, `registro`, `da-confermare`, `da-revisionare`). `img/phone_library.png` è in realtà la Home.
- Cambi di comportamento voluti: D-355, D-356, D-358, D-361, D-364, D-370. Intoccabili: D-367 (niente pacchetti nuovi, niente shimmer).

## Da riprovare o capire
- Jam in LAN della fase 74 non provata dal vivo (la rete UniBA isola i client): rifarla a casa.
- Il nuovo tentativo del primo «Entra» non è mai scattato dal vivo (il primo CONNECT è sempre riuscito il 3/11).
- Il «+» di Casuale+ si scrive ~400 ms dopo; una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).
- L'app di misura `com.codecore.player.perf` è stata disinstallata dal Mi A3 da `flutter drive` (73.1): `perf_device.py` la reinstalla.

## Tocca a te
- **Fase 76 a mano** (APK debug sul Mi A3 ora è quello della fase 77, con l'ultima correzione della 76): con Casuale+ controlla nel log `shuffle+ enrich of <id> row=` per tutti e 3 i suggeriti di un blocco e il quarto suggerito dopo il blocco.
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
0. **Fasi 77–83** (refactor «ui-uso-quotidiano», `/obiettivo fase 77`); la 78.1 verifica anche il «Casuale su tutto» della Home che nella prova 76 non ha avviato nulla.
1. **(Consigliato) Debito della fase 74** (dalla review di architettura): estrarre `JamLocalQueue` da `JamController` (`jam_providers.dart` è a ~1360 righe; `_saved`/`_mode`/copia `jamAside`, valori di dominio a `keepAside`, `_part.unplayed` calcolato una volta per stato); un solo helper «riprova subito sullo stesso broker» per `JamBridge` e `_lookupCode`; un solo limite della posizione oltre la durata; unire `jam_queue_owner_name_test.dart` a `jam_queue_sheet_test.dart`; nome dell'ospite uscito ricordato per tutta la Jam, non solo a foglio aperto.
2. Unificare le due code delle domande sulla cassa (`SpeakerMonitor._pending` e la coda della UI).
3. Ricerca «notte», build p99 (D-176); 53.10 completamento intero sul Motorola.
