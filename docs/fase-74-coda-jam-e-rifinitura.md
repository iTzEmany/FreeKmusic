# Fase 74 — Coda della Jam e rifinitura della Jam a distanza

**Obiettivo:** chiudere i rinviati della coda della Jam (il «Suggerito» che ripropone brani già suonati, Shuffle+ con la sorgente cambiata, «Casuale+» perso dopo la Jam, la coda di prima della Jam) e rifinire la Jam a distanza con quanto visto nelle prove dal vivo delle fasi 71–73.

**Prerequisiti:** fasi 66 e 70–73 chiuse. Requisiti R-93, R-102; decisioni D-81, D-87, D-185, D-186, D-208, D-209, D-340 … D-343. Aree a rischio: ordine della coda (`jam_part_feeder.dart`, `shuffle_plus_controller.dart`), dati persistiti (`playback_persistence.dart`). Nessun pacchetto nuovo.

**Regola della fase:** ogni bug prima si riproduce con un test che fallisce sul `master` attuale, poi si corregge. Se il test non riesce a riprodurlo, il task chiude con la nota «non riprodotto» e il test resta come guardia.

**Comando mirato:** `flutter test test/jam test/providers test/services/shuffle_plus test/ui/jam_screen_test.dart test/ui/jam_parts_test.dart test/ui/shuffle_button_test.dart` (più `test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart` se si tocca `lib/ui`).

## Task

### 74.1 — Il «Suggerito» non ripropone i brani già suonati (KO R-102, D-340)
Visto il 30/10 (§69.4): a Jam piena il «Suggerito» ripropone brani già suonati nella Jam. `JamPart._suggestion` (`lib/providers/jam_part.dart`) ricava i già suonati da `s.items.take(s.currentIndex + 1)`: la Jam tiene al massimo `maxJamItems` (200) voci, quindi quando l'host toglie le più vecchie il loro ricordo sparisce. Sospetto da confermare col test. Correzione attesa: i già suonati si accumulano in `JamPart` (id dei propri brani e `suggestionKey` di tutti) per tutta la Jam, e si azzerano in `clear()`.

**Fatto quando:** un test di `JamPart` (o del feeder) con una Jam che ha superato 200 voci: il suggerito non è mai un brano suonato prima del taglio (seme fisso); i test di `jam_suggestion_test.dart` restano verdi.

### 74.2 — Shuffle+ con la sorgente cambiata
Segnalato dall'utente il 30/10: con Shuffle+ già acceso, avviare un album o una playlist arricchisce la nuova coda con suggeriti basati sulla coda di prima. Sospetto: `_syncSource` svuota pool e semi, ma un `_fill`/`_suggestOne` già in corso (`shuffle_plus_controller.dart`) finisce coi semi vecchi e inserisce lo stesso; il controllo dopo `prepare` non guarda se la sorgente è cambiata. Correzione attesa: una generazione della sorgente presa all'inizio di `_fill`/`_suggestOne` e confrontata prima di ogni inserimento.

**Fatto quando:** test con un suggeritore finto che si ferma a metà: si cambia sorgente, si sblocca, nessun suggerito della vecchia sorgente entra nella nuova coda; quelli calcolati dopo usano i semi nuovi.

### 74.3 — Shuffle+ e coda di prima tornano intatti all'uscita dalla Jam (D-342, D-341)
Due problemi dello stesso punto (`JamController.saveLocalQueue` / `_restoreLocalQueue` in `lib/providers/jam_providers.dart`):
- **Casuale+ torna Casuale** (visto sul Motorola il 30/10): la modalità di casuale (`ShuffleMode` in `shuffle_plus_providers.dart`) va salvata con la coda e rimessa com'era all'uscita (D-342).
- **Coda di prima della Jam su disco** (D-341): oggi `_saved` e la parte di «Coda insieme» vivono in memoria; il disco resta fermo sulla coda di prima (`PlaybackPersistence.hold`), ma la parte non ancora suonata (D-209) e la modalità di casuale si perdono se l'app viene chiusa durante la Jam. Primo test: cosa ritrova davvero l'utente riaprendo l'app dopo una chiusura a Jam in corso. Poi salvare su disco quanto serve per ritrovare la coda che l'uscita normale avrebbe dato (coda, indice, posizione, modalità di casuale; la parte di «Coda insieme» al posto della coda quando c'è), con le preferenze già usate da `playback_persistence.dart`, e cancellarlo dopo il ripristino.

**Fatto quando:** test: Casuale+ prima della Jam → Casuale+ dopo «Esci» e dopo «Termina»; chiusura dell'app a Jam in corso e riapertura → la stessa coda (o la parte non suonata) e la stessa modalità che avrebbe dato l'uscita normale; nessun salvataggio rimasto dopo un ripristino riuscito.

### 74.4 — «Scarica» nel ⋮ della schermata Jam (R-93, D-343)
Deciso dall'utente il 30/10: nel ⋮ di un brano della Jam compare «Scarica» per i brani online non ancora in libreria, come nel player normale, e sparisce appena il brano entra in libreria anche a foglio aperto (D-181). Riusare l'azione del player, niente codice di download nuovo.

**Fatto quando:** test widget: brano online della Jam → «Scarica» c'è; brano di libreria → non c'è; il brano entra in libreria a foglio aperto → la voce sparisce.

### 74.5 — La posizione della Jam non salta indietro (D-343)
A ogni avvio di brano la posizione mostrata nella Jam salta indietro di circa 1,3 s (`jam ui: shown position moved` in `lib/ui/screens/jam/jam_player.dart`). Primo passo: un test che riproduce il salto (stato con `positionAt` nel futuro per `jamStartLeadMs`, o orologio stimato dell'ospite). Correzione attesa: finché il brano non è partito la posizione mostrata resta 0 e non scende mai sotto quella già mostrata per lo stesso brano, salvo un seek.

**Fatto quando:** test della posizione mostrata all'avvio di un brano: mai all'indietro senza un seek; il seek resta immediato.

### 74.6 — Rifinitura della Jam a distanza (dalle prove dal vivo del 3/11)
- **Nome del dispositivo nella vista dell'host:** la Jam di un ospite Android si chiama «Telefono» (su Android `Platform.localHostname` non dà il nome del telefono e `deviceNameProvider` in `lib/providers/share_providers.dart` ripiega su un nome generico: capire da dove arriva «Telefono») e l'ospite uscito ha il nome vuoto (`JamState.nameOf` restituisce "" per chi non è più fra i partecipanti). Correzione: il nome del modello del telefono quando non c'è un nome scelto; per chi è uscito il nome ricordato dalla sessione, o «Ospite» se non c'è.
- **Timeout del primo «Entra»:** il primo «Entra» col codice dal Mi A3 va spesso in timeout verso broker.emqx.io (10–12 s, «Broker irraggiungibile»), il secondo riesce. Prima capire dal log se è il DNS, il TLS o il CONNECT; correzione attesa: un nuovo tentativo automatico sullo stesso broker prima di passare al successivo o di mostrare l'errore, senza superare il tempo totale di oggi.
- **Messaggio a posizione spenta:** aprendo «Dispositivi» con la posizione spenta (Android ≤ 11) il messaggio `jamBleLocationOff` non compare; dall'interruttore sì (`lib/ui/screens/jam/ble_permission.dart`). Va mostrato anche all'apertura di «Dispositivi», una volta per apertura, se la ricerca delle Jam vicine è accesa.

**Fatto quando:** test del nome (generico → modello; ospite uscito → nome ricordato o «Ospite»); test di `JamBridge` con un broker finto che fallisce il primo CONNECT e riesce al secondo; test widget del messaggio all'apertura di «Dispositivi»; ARB it/en/de/es per le stringhe nuove.

### 74.7 — Controlli di fase
`flutter analyze`, comando mirato, `/code-review high` su 74.2 e 74.3 (concorrenza e dati persistiti), scheggia in modalità passo su 74.1–74.3, review di architettura Opus. Prova in autonomia: Linux host e Mi A3 ospite (LAN e col codice); «Coda insieme» oltre 200 voci, Casuale+ prima e dopo la Jam, chiusura forzata dell'app sul Mi A3 a Jam in corso, primo «Entra» col codice, «Dispositivi» con la posizione spenta.

**Fatto quando:** tutto verde; esiti qui sotto; colonna Fase di R-93 e R-102 aggiornata.

## Esiti
(da compilare)
