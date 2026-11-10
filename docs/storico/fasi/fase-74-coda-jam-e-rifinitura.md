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

Confermato nella prova 73.2 (3/11): due uscite su due da ospite in «Coda dell'host» sono tornate a Casuale. Nella stessa prova, dopo l'uscita il Motorola mostrava il brano 36 a «3:10 / 3:10» con una posizione salvata di 4:07: capire se la posizione ripristinata può superare la durata del brano.

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

- **Ricerca delle Jam vicine che non riparte** (prova 73.2): se la Jam finisce mentre l'ospite non ha aperta la schermata Jam, la fase resta `ended` e `_wanted()` in `lib/providers/jam_nearby_providers.dart` tiene ferma la ricerca, anche spegnendo e riaccendendo «Cerca Jam vicine». Correzione: una Jam finita non blocca la ricerca.
- **Annuncio del Mi A3 (Android 11) senza posizione precisa** (prova 73.2): l'annuncio è partito solo dopo un `pm grant ACCESS_FINE_LOCATION` a mano. Verificare se il foglio dei permessi (`ble_permission.dart`) lo chiede su Android ≤ 11 e, se manca, chiederlo.
- **Brano di libreria dell'ospite remoto in ritardo** (prova 73.2): è partito sull'host solo dopo i 15 s di `jam: no lookup for …`. Capire cosa cerca l'host per un item `yt:` e se può saltare l'attesa.

**Fatto quando:** test della ricerca che riparte dopo una Jam finita a schermata chiusa; test del nome (generico → modello; ospite uscito → nome ricordato o «Ospite»); test di `JamBridge` con un broker finto che fallisce il primo CONNECT e riesce al secondo; test widget del messaggio all'apertura di «Dispositivi»; ARB it/en/de/es per le stringhe nuove.

### 74.7 — Controlli di fase
`flutter analyze`, comando mirato, `/code-review high` su 74.2 e 74.3 (concorrenza e dati persistiti), scheggia in modalità passo su 74.1–74.3, review di architettura Opus. Prova in autonomia: Linux host e Mi A3 ospite (LAN e col codice); «Coda insieme» oltre 200 voci, Casuale+ prima e dopo la Jam, chiusura forzata dell'app sul Mi A3 a Jam in corso, primo «Entra» col codice, «Dispositivi» con la posizione spenta.

**Fatto quando:** tutto verde; esiti qui sotto; colonna Fase di R-93 e R-102 aggiornata.

## Esiti
- **74.1** riprodotto (test rosso sul master): i già suonati si registrano in `JamPart.notePlayed` a ogni stato (`JamController._onState`), anche prima del primo suggerimento; azzerati in `start`/`clear`.
- **74.2** riprodotto: `_changedSince` confronta la sorgente presa all'inizio con `host.sourceIds` dopo ogni attesa (`loadLibrary`, `resolve`, `radio.page`, `prepare`) e chiede un nuovo giro. Niente contatore: `_syncSource` non gira mentre `_fill` è in volo.
- **74.3** riprodotto (6 test rossi su 10): causa di Casuale+ → Casuale: `attachRemote` pubblica uno stato senza `shuffleMode` e `ShufflePlusConfigNotifier` spegne il «+». Ora la modalità si salva con la coda e torna com'era; copia `jamAside` su disco (03-modello-dati) ripristinata all'avvio e cancellata dopo il ripristino. Posizione oltre la durata (4:07 su 3:10): limitata sia al salvataggio sia al ripristino.
- **74.4** «Scarica» nel ⋮ della Jam con l'helper unico `downloadOnline` di `track_actions.dart` (anche il player lo usa); sparisce a foglio aperto.
- **74.5** riprodotto: la posizione mostrata non scende sotto quella già mostrata se il passo indietro è entro `jamStartLeadMs + 500`; riavvio dello stesso brano e seek immediati.
- **74.6** nome: «Telefono» veniva da `Settings.Global.device_name` (e da un nome salvato uguale); i nomi generici ripiegano su `Build.MODEL`; ospite uscito → nome visto a foglio aperto, poi «Ospite». Primo «Entra»: il timeout era nella ricerca del codice (`_lookupCode`), non nel ponte; primo CONNECT e un nuovo tentativo a metà tempo ciascuno (stesso totale di oggi), mai dopo «Annulla». Posizione spenta: riga dentro «Dispositivi» a ogni apertura (lo snackbar finiva sotto il foglio). Ricerca vicina: una Jam `ended` non la blocca più. Posizione precisa sul Mi A3: non serve all'annuncio (`canAdvertise` = SDK<31 o `BLUETOOTH_ADVERTISE`), il `pm grant` era una coincidenza; nessuna modifica. Brano `yt:` dell'ospite remoto: i 15 s di `no lookup` sono la ricerca dei testi, non bloccano; l'attesa vera era il download intero (`ready`): ora in una Jam non sincronizzata l'host parte dall'indirizzo di stream (`StreamPreparer.start`) e scarica in background.
- **74.7** analyze pulito, comando mirato 1191 verdi; code-review high (Opus): 3 rilievi corretti; scheggia su 74.1–74.3: nessun bug, test rinforzati sui mutanti sopravvissuti; review di architettura Opus: «Scarica» unificato, `restore({applyPlus})`, il resto nel handoff. Prova dal vivo del 3/11 (Linux host in xvfb, Mi A3 ospite, Wi-Fi UniBA): primo «Entra» col codice riuscito 3 volte su 3 (richiesta sull'host in 5,1 s); Casuale+ intatto dopo «Esci» e dopo «Termina»; chiusura forzata a Jam in corso → stessa coda e Casuale+, nessuna copia rimasta; «Coda insieme» oltre 200 (tetto 200, host ok); «Dispositivi» a posizione spenta mostra il messaggio; host mostra «Mi A3». Non provati dal vivo: Jam in LAN (la rete UniBA isola i client), il nuovo tentativo (il primo CONNECT non è mai fallito).
- Residui noti: il «+» di Casuale+ si scrive ~400 ms dopo (una chiusura in quell'istante lo perde); una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).
