# Handoff — 2026-11-05 (refactor «ui-uso-quotidiano» chiuso: fasi 77–83)

## Stato
**Refactor «ui-uso-quotidiano» chiuso** (fasi 77–83, PR #101, #103–#107 e la PR della fase 83). Stato finale dei rilievi e ciò che resta: `docs/refactor/ui-uso-quotidiano/analisi.md` «Stato finale»; misure e giro sul Mi A3: `docs/fase-83-chiusura-uso-quotidiano.md` «Esiti».
- **Fase 83**: animazioni dei mockup (dissolvenza fra pagine, copertina tonda nella chiusura del player, skeleton solo oltre 150 ms, lente della Libreria, D-382), campi di ricerca su `CcSearchField` (D-378), contesto del player che resta dopo un riavvio, Shuffle+ e mix ripuliti, Registro che segue la tabella, «Accetta tutte»/Annulla in una transazione, etichette e tocchi TalkBack controllati con `uiautomator dump` (D-381).
- **Misure**: Mi A3 p90 build Libreria 8,2 ms (soglia 16); Linux A/B p90 3,0 → 2,7 ms, il −50 % non è raggiunto (il p90 era già basso).

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo
```

## Da sapere
- Decisioni del refactor: D-354…D-382. Mockup approvati in `docs/refactor/ui-uso-quotidiano/mockup/`.
- TalkBack: supportato sempre nel codice, mai prove a orecchio (D-381). Etichette e tocchi: `test/ui/talkback_labels_test.dart` e `uiautomator dump` sul Mi A3. Trappola di `excludeSemantics` in `docs/gotchas.md`.
- Debito dichiarato: Cerca tiene il suo ritardo di battitura invece di quello di `CcSearchField`.

## Da riprovare o capire
- Jam in LAN della fase 74 non provata dal vivo (la rete UniBA isola i client): rifarla a casa.
- Il nuovo tentativo del primo «Entra» non è mai scattato dal vivo.
- Il «+» di Casuale+ si scrive ~400 ms dopo; una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).

## Tocca a te
- **Scelta**: il Registro (e da lì Da confermare) si apre solo dal foglio attività, che compare solo mentre qualcosa gira (così anche prima del refactor). Vuoi un ingresso fisso? Per esempio una voce nelle Impostazioni o nel ⋮ della Libreria.
- **A vista sul Mi A3** (APK debug della fase 83 installato): la copertina che resta tonda chiudendo il player, la dissolvenza fra le pagine, la lente della Libreria.
- **Fase 76 a mano**: con Casuale+ controlla nel log `shuffle+ enrich of <id> row=` per i 3 suggeriti di un blocco e il quarto dopo il blocco.
- **Fase 75 a mano**: un suggerito online in coda (niente arricchimento finché non suona), il segnaposto «in arrivo», «Proposta di correzione» su un brano della libreria.
- **Mi A3 dopo la prova 74.7**: l'amico «emanuele-Aspire-A515-45» in «Jam a distanza» e lo shuffle su Casuale+; toglili a mano se non ti servono.
- **Resto della 73.2**: ingresso col QR, Sospendi/Blocca da un ospite remoto, riserva fra broker con due voci.
- **Mosquitto 8886** (D-258): chiude ogni connessione dopo il CONNECT; toglierlo da `kDefaultJamBrokers` o sostituirlo.
- Prova a mano del gate (sospensione di 15 minuti che scade; «Fino alla fine della Jam»); 69.4: «Scarica» che sparisce a foglio aperto.
- Dalle fasi 66–68: fase 67 sul Motorola, scoperta su /16, fase 66 a mano, ascolto 57.7, APK di release con NewPipe, tag `v1.3.0`.

## Dispositivi
- **Motorola edge 40** `ZY22HKD85K`: libreria vera. Solo `install -r`; mai disinstallare né `pm clear`. 120 Hz.
- **Mi A3** `0d7ae9df206e`:
  - si disinstalla solo con `-k`; mai cancellare i file musicali;
  - l'app vera è `com.codecore.player` (69 brani veri, si apre con `am start -n com.codecore.player/.IconAmbraDark`); le misure vanno sull'app `com.codecore.player.perf` (3000 brani finti): non confonderle nei giri a mano;
  - volume della musica a 0; a schermo spento si blocca col PIN.
- **JBL**: si spengono da sole dopo circa 20 minuti senza suono.
- Su entrambi i telefoni: mai toccare la rotazione o le impostazioni di sistema.
- **Misure**: `python3 scripts/perf_device.py <id> --label <l> [--no-build --no-push --apk <apk>] [--only "A,B"]`. Per un A/B: un worktree per commit e run alternati A, B, A, B.
- **APK**: si compila con `JAVA_HOME=~/.jdks/jbr-17.0.14` (`docs/gotchas.md`).

## Rinviato
- **Due code per le domande sulla cassa** (`SpeakerMonitor._pending` e la coda della UI): da unificare.
- 53.10 completamento intero sul Motorola (circa 1 brano al minuto).
- Il messaggio «perché niente Shuffle+» (D-87) su un album da 1 brano.
- Gli interruttori del completamento che fermano il giro manuale.
- Il debito dello streaming, in fondo a `docs/fase-47-jam-online.md`.

## Prossimi obiettivi
1. **(Consigliato) Debito della fase 74**: estrarre `JamLocalQueue` da `JamController` (`jam_providers.dart` ~1360 righe); un solo helper «riprova subito sullo stesso broker» per `JamBridge` e `_lookupCode`; un solo limite della posizione oltre la durata; unire `jam_queue_owner_name_test.dart` a `jam_queue_sheet_test.dart`; nome dell'ospite uscito ricordato per tutta la Jam.
2. Unificare le due code delle domande sulla cassa.
3. Ricerca «notte», build p99 (D-176); 53.10 completamento intero sul Motorola.
4. Picco di ~54 ms alla prima visita di ogni scheda della Libreria (F-60, invariato dal refactor).
