# Feature «Jam: cassa e coda insieme»

Nella Jam in LAN l'host sceglie fra «Coda dell'host» e «Coda insieme», dove i brani si alternano a turno fra tutti. Un telefono Android con una cassa Bluetooth collegata apre e annuncia da sé la sua Jam in LAN, e suona solo lui. Si correggono anche i rilievi aperti delle prove 47.8 e 63.5.
Per chi: l'utente e gli amici che ascoltano insieme sulla stessa rete, a casa o con l'hotspot di un telefono. Perché ora: la Jam come player (fase 63) è chiusa, ma la prova del 28/10 ha lasciato dei rilievi aperti, e oggi la coda è solo dell'host.

Kickoff del 2026-10-28 (richiesta originale: `docs/prossimi-lavori.md` §2, «Cassa Bluetooth e modalità della coda»; rilievi in `docs/handoff.md`, «Jam: rilievi aperti»). Decisioni: D-177 … D-220 in `docs/decisioni.md`. Supera D-89 per le aggiunte degli ospiti (D-179).
Fasi: vedi `docs/PROGRESS.md` (65 e seguenti).

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. La Jam vale su Android, Linux e Windows; la cassa (riconoscimento, avvio e annuncio) solo su Android. Windows usa lo stesso codice di Linux ed è provato solo su Linux.

### Rilievi della Jam (47.8, 63.5)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-88 | In «Coda dell'host» l'aggiunta di un ospite va in fila: dopo il corrente e dopo le aggiunte già fatte, prima della coda ereditata dall'host (D-179) | I | Test del reducer (`applyCommand`): tre aggiunte di fila con coda ereditata finiscono nell'ordine di arrivo, subito dopo il corrente e prima del primo item `inherited` | 65 ✓ |
| R-89 | Un ospite in Jam che fa swipe «in coda» su una riga online della Ricerca accoda nella Jam, come ⋮ → «Aggiungi in coda»; lo stesso vale per «Aggiungi in coda» dal ⋮ del player su un brano online (D-180) | I | Test widget: con una Jam attiva da ospite, sia lo swipe sia le voci del ⋮ di `onlineResultActions` e `onlineTrackActions` arrivano a `JamController.addOnline` (prima un test che riproduce il difetto) | 65 ✓ |
| R-90 | «Esci dalla Jam» sull'ospite lo riporta alla coda che aveva prima di entrare, in pausa, sul brano e alla posizione di allora (D-178). In «Coda insieme» la coda ritrovata è la sua parte non ancora suonata (D-186) | I | Test: ospite con coda [A,B,C] su B a 1:00 entra, esce → coda [A,B,C], B, 1:00, in pausa; in «Coda insieme» con la parte [D,E] non suonata esce → coda [D,E] | 65 ✓ |
| R-91 | Se l'ospite esce, i suoi brani online non ancora suonati restano all'host, che li scarica da sé (R-21, D-93) | I | Test host+ospite in memoria già previsto da R-21 verde; prova a mano con due telefoni. Con un solo ospite la Jam resta aperta sull'host (D-221, 66.6) | 66 ✓ |
| R-92 | L'ospite vede le copertine dei brani degli altri: brani di libreria dalla rotta `/cover` che esiste già, brani `yt:` dalla miniatura di YouTube del video id (D-205) | I | Test widget di `JamCover`: item di un altro con `ref` numerico → immagine da `fetchCover`; item `yt:` → miniatura; nessuna nota se la copertina c'è | 65 ✓ |
| R-93 | «Scarica» sparisce dal ⋮ del player, anche a foglio aperto, appena il brano entra in libreria (D-181) | I | Test widget: foglio aperto su un brano online, il brano diventa di libreria → la voce «Scarica» sparisce senza chiudere il foglio | 65 ✓, Jam 74 ✓ |
| R-94 | Fra host e ospite l'audio è allineato entro 80 ms (obiettivo della fase 10) e la posizione mostrata entro 0,3 s (D-204) | I | Prima un test o una misura che riproduce i ~2 s; poi prova a mano sull'hotspot con la misura scritta nel documento di fase | 65 ✓ |
| R-95 | «Precedente» subito dopo «successivo» (meno di 3 s) torna al brano prima da 0:00, mai da una posizione vecchia (rilievo 63.5, 0:22) | I | Test del reducer e di `JamGuest`: successivo e precedente ravvicinati, con stato dell'host in ritardo → il brano parte da 0 | 65 ✓ |

Il rilievo «Rimuovi non visibile nel ⋮ della coda dell'ospite» è voluto: l'ospite toglie solo i suoi brani (D-195).

### Modalità della coda
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-96 | Lo stato della Jam ha una modalità della coda, «Coda dell'host» di serie; la cambia solo l'host, anche mentre suona, da una riga in cima al foglio «Coda condivisa»; gli ospiti vedono la riga ma non la toccano (D-184, D-207) | I | Test: comando di cambio dall'host → `version` + 1 e modalità nuova; lo stesso comando da un ospite → rifiutato. Test widget: la riga c'è per tutti, attiva solo per l'host | 66 |
| R-97 | In «Coda insieme» i brani si alternano a giro fra tutti i partecipanti, nell'ordine di ingresso (host, ospite 1, ospite 2, …) (D-187) | I | Test a tabella della funzione d'ordine: 2 e 3 partecipanti con code di lunghezze diverse → mai due brani della stessa persona di fila finché ce ne sono di altri | 66 |
| R-98 | In «Coda insieme» un'aggiunta (swipe, «Aggiungi in coda» o «Riproduci dopo») va sempre in testa alla parte di chi aggiunge, quindi al suo prossimo turno: subito dopo il corrente se il corrente non è suo, altrimenti dopo il prossimo brano di un altro; il resto si rialterna (D-179, D-214) | I | Test a tabella: aggiunta dell'ospite con parte vuota e piena, mentre suona un brano dell'host e mentre suona un suo brano | 66 |
| R-99 | Al passaggio a «Coda insieme» entra nel giro la coda che ogni ospite aveva prima di entrare, più le sue aggiunte (D-192) | I | Test host+ospite in memoria: ospite con coda locale [X,Y] entra, l'host passa a «Coda insieme» → X e Y entrano nel giro | 66 ✓ |
| R-100 | La parte di un ospite è la sua coda: aggiunte, rimozioni e «Riproduci dopo» dell'ospite la cambiano, ed è quella che ritrova uscendo (D-186, R-90) | I | Test: rimozione e aggiunta dell'ospite cambiano la sua parte e la coda di uscita | 66 ✓ |
| R-101 | Con code lunghe la Jam tiene al massimo 200 brani (`maxJamItems`); gli altri entrano a turno man mano che si suona, senza perderne (D-194) | I | Test: due code da 300 → 200 item nella Jam; dopo ogni brano suonato ne entra uno nuovo, nell'ordine del giro | 66 ✓ |
| R-102 | In «Coda insieme», al turno di chi non ha più brani entra un suggerito locale: lo sceglie il suo telefono dalla sua libreria, a caso fra i brani con i generi della sua coda di prima (pesati per frequenza), mai uno già suonato nella Jam; senza generi, uno a caso. Arriva come sua aggiunta, segnato «Suggerito» (D-185, D-208) | I | Test della scelta (seme fisso): generi pesati, esclusione dei già suonati, ripiego a caso; test host+ospite: la parte vuota riceve un suggerito al suo turno | 66 ✓, 74 ✓ (oltre 200 voci) |
| R-103 | In «Coda insieme» la coda non si trascina, né dall'host né dagli ospiti (D-188) | I | Test widget: nel foglio della coda in «Coda insieme» niente maniglie; il comando di spostamento è rifiutato dall'host | 66 |
| R-104 | Tornando a «Coda dell'host» i brani degli ospiti restano dove sono; da lì le aggiunte vanno in fila come R-88 (D-193) | I | Test: cambio di modalità con coda alternata → ordine invariato | 66 |
| R-105 | Un ospite che entra durante «Coda insieme» entra nel giro dopo l'ultimo; uno che esce lascia il giro, i suoi brani di libreria si tolgono e quelli online restano al loro posto (D-93) | I | Test host + due ospiti in memoria: ingresso e uscita durante «Coda insieme» | 66 ✓ |
| R-106 | Un dispositivo con l'app di prima della feature non si rompe: uno stato senza modalità vale «Coda dell'host», un campo sconosciuto viene ignorato | U | Test di (de)serializzazione di `JamState` con e senza il campo nuovo | 66 |

### Cassa Bluetooth (Android)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-107 | Il lato nativo dice quali uscite Bluetooth A2DP sono collegate (nome, indirizzo, classe del dispositivo) e avvisa quando una si collega o si scollega | I | Test Dart del canale con un finto `MethodChannel`; prova a mano sul Motorola con una cassa e con le cuffie | 67 ✓ (a mano sul Motorola: Tocca a te) |
| R-108 | Alla prima uscita Bluetooth vista l'app chiede il permesso `BLUETOOTH_CONNECT` (Android 12+) con una riga che spiega a cosa serve; se rifiutato, niente Jam sulla cassa, riattivabile dalle impostazioni (D-201) | I | Test widget del foglio di richiesta; prova a mano sul Motorola: rifiuta, poi riattiva dalle impostazioni | 67 ✓ (a mano sul Motorola: Tocca a te) |
| R-109 | Un dispositivo nuovo ha una stima dalla classe (altoparlante, audio portatile e hi-fi = cassa; cuffie, auricolare, vivavoce, auto e nessuna classe = non cassa), poi alla prima connessione «È una cassa?» con Sì/No; se l'app era in sottofondo, alla prossima apertura, se è ancora collegato. La risposta resta legata all'indirizzo (D-190, D-202) | I | Test della stima per ogni classe; test: dispositivo nuovo → domanda una sola volta, risposta salvata e riletta al riavvio | 67 ✓ |
| R-110 | Interruttore «Jam sulla cassa» nelle impostazioni, acceso di serie, con la lista dei dispositivi segnati come cassa e la possibilità di cambiarli (D-203) | I | Test widget delle impostazioni: interruttore, lista, cambio di un dispositivo | 67 ✓ |
| R-111 | Con l'interruttore acceso, quando si collega una cassa il telefono apre da sé una Jam in attesa e la annuncia in LAN, partendo dalla coda che sta ascoltando; se nessuno entra, non cambia niente per l'utente. Se è già host di una Jam normale, quella diventa la Jam della cassa; se è ospite non si apre niente (salvo R-119) (D-196, D-191, D-218) | I | Test: evento «cassa collegata» → Jam aperta da host con campo «Jam» nel pacchetto di scoperta; interruttore spento → niente | 67 ✓ |
| R-112 | Gli altri vedono «Unisciti alla Jam di X» in un banner nell'app (si chiude con ✕) e in cima al foglio «Dispositivi»; il tocco manda la richiesta, che l'host accetta o rifiuta come oggi (D-197, D-198) | I | Test widget: annuncio ricevuto → banner e riga in «Dispositivi»; ✕ chiude il banner per quella Jam; tocco → `JamController.request` | 67 ✓ |
| R-113 | Nella Jam della cassa suona un solo dispositivo, quello con la cassa (di serie l'host); gli ospiti hanno i comandi di oggi e non suonano (D-200, D-219) | I | Test: Jam aperta dalla cassa → uscite = solo l'host; gli ospiti mandano comandi come oggi | 67 ✓ |
| R-114 | Se la cassa si scollega, la Jam va in pausa e resta aperta ma «inagibile»: play, seek e salti bloccati per tutti con «Collega una cassa», la coda si può cambiare; riprende quando torna una cassa; dopo 10 minuti senza cassa finisce per tutti con «La Jam è terminata» (D-199) | I | Test con orologio finto: scollegamento → comandi rifiutati con il motivo, aggiunte accettate; ricollegamento → sblocco; 10 min → fine | 67 ✓ |
| R-115 | Una Jam della cassa in cui non è entrato nessuno si chiude senza avvisi quando la cassa si scollega | I | Test: Jam in attesa senza ospiti + scollegamento → chiusa, nessun messaggio | 67 ✓ |
| R-119 | Con la Jam della cassa ferma per la cassa assente, un ospite che collega una sua cassa riceve «Suonare la Jam sulla tua cassa?»: sì → diventa l'unica uscita (`offerSpeaker`) e la Jam si sblocca; l'host resta chi coordina. Non vale mentre una cassa suona. Se poi torna la cassa dell'host l'uscita resta all'ospite; se la cassa dell'ospite sparisce o l'ospite esce, la Jam torna ferma (D-219, D-220) | I | Test: Jam ferma + ospite con cassa → domanda → uscita all'ospite e sblocco; con la cassa presente nessuna domanda; uscita dell'ospite-uscita → ferma | 67 ✓ |
| R-116 | Su Linux e Windows niente riconoscimento della cassa; vedono il banner e il foglio «Dispositivi» e possono unirsi alla Jam di una cassa | I | Test widget del banner sul desktop; prova a mano Linux + Motorola | 67 ✓ (a mano sul Motorola: Tocca a te) |

### Scoperta
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-117 | Il broadcast diretto della scoperta usa la maschera vera della rete (Android dal lato nativo, Linux da `ip`; su Windows nessun prefisso, quindi a.b.c.255 e a.b.255.255), non una /24 supposta; le reti che filtrano ogni broadcast restano escluse (D-206) | U | Test della funzione che calcola gli indirizzi (/24, /16, /22); prova a mano su UniBA o su una rete /16 | 68 ✓ (prova su /16 a mano: Tocca a te) |

### Prove a mano
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-118 | Prova con due telefoni sull'hotspot: rilievi R-88 … R-95, le due modalità, ingresso e uscita di un ospite, Jam della cassa con una cassa vera (collegamento, banner, scollegamento e ritorno) | I | Esiti scritti in `docs/PROGRESS.md` sotto il passo di prova, uno per riga | 68 |

## Requisiti non funzionali
- **RNF-11** L'ordine a turno si calcola nel reducer dell'host, è puro e costa O(n) sui 200 item: niente lavoro pesante sul thread della UI.
- **RNF-12** Il riconoscimento della cassa non aggiunge un servizio in sottofondo: ascolta gli eventi solo finché il processo dell'app è vivo (riproduzione o app aperta).
- **RNF-13** Le misure di fluidità della fase 38 non peggiorano per il foglio della coda e per il banner (stessi scenari di `perf_device.py`).

## Vincoli
- Nessun pacchetto nuovo: il canale nativo `codecore/audio` (`MainActivity.kt`) si estende; la scoperta resta il broadcast UDP di oggi (D-191).
- Permessi nuovi nel manifest: `BLUETOOTH` (solo fino ad Android 11, `maxSdkVersion 30`) e `BLUETOOTH_CONNECT` (Android 12+, a runtime).
- La classe Bluetooth è solo indicativa e può mancare: la domanda «È una cassa?» decide, la classe dà solo la stima.

## Fuori perimetro
- Jam a distanza: broker MQTT, annuncio BLE, gettone, amici memorizzati, anti-spam con Sospendi e Blocca (D-183): kickoff a parte.
- Notifica Android per «Unisciti alla Jam di X» (D-197).
- Riconoscimento della cassa su Linux e Windows; casse LE Audio.
- Riordino a mano in «Coda insieme» (D-188).
- Scritta «Ascolta con X» sulla scheda del dispositivo: resta «Jam» (D-177).
- «Rimuovi» per l'ospite sui brani degli altri (D-195).
- Interruttore «Comandi agli ospiti» (D-200).

## Architettura
Si estende la Jam di oggi (`docs/02-architettura.md`, fasi 8–10, 47, 63): stesso host autorevole, stesso protocollo HTTP con `JamState.version`, stessa scoperta UDP. Niente pacchetti nuovi.

### Componenti
| Componente | Cosa cambia | File |
|---|---|---|
| `JamState` / `JamItem` / `JamCommand` | campi nuovi `mode` (`host` di serie, `together`), `speaker` (Jam della cassa), `speakerAwaySince` (ms, null se la cassa c'è); `JamItem.suggested` e `JamItem.partKey`; comandi nuovi `setMode` (solo host), `previous` (lo decide l'host), `speakerAway` (dall'host, o dall'ospite che è l'unica uscita, D-220), `speakerBack` (solo host), `offerSpeaker` (da un ospite). Campi assenti = valori di serie (R-106) | `lib/services/jam/jam_models.dart` |
| Reducer | in `together`: le aggiunte del feeder (con `partKey` o `inherited`) vanno in fondo alla parte del mittente, le altre in testa, poi `togetherOrder` riordina gli item dopo il corrente; `add` idempotente su (owner, `partKey`); con la Jam piena si scarta il più vecchio già suonato e, se non ce ne sono, risponde `full`; `move` rifiutato; con `speakerAwaySince != null` rifiutati play, seek, next, jump, previous (`JamError.noSpeaker`, HTTP 409 con corpo `no speaker`, che l'ospite mappa su `noSpeaker`); `offerSpeaker` è accettato solo con `speaker && speakerAwaySince != null` e in un colpo solo mette uscite = [mittente] e `speakerAwaySince = null` (R-119). In `host` nulla cambia (R-88) | `lib/services/jam/jam_state.dart` |
| `togetherOrder` (nuovo, puro) | dato l'elenco, il corrente e l'ordine dei partecipanti, alterna a giro le sottosequenze di ciascuno, ognuna nel suo ordine, partendo da chi viene dopo il proprietario del corrente | `lib/services/jam/jam_turns.dart` |
| `JamPartFeeder` (nuovo) | su ogni dispositivo, da `_begin` a `_teardown` (in modalità `host` resta fermo): tiene la parte locale (la coda di prima della Jam; le aggiunte nuove vanno subito nella Jam come `add`), ne manda il prossimo brano quando nella Jam ne ha meno di `ceil(200 / partecipanti)` in arrivo, e un suggerito locale quando la parte è vuota e non ha brani in arrivo (R-101, R-102) | `lib/services/jam/jam_part_feeder.dart` |
| `pickSuggestion` / `suggestionKey` (nuovi, puri + query) | scelta pesata per genere sulla libreria, escludendo i già suonati (R-102) | `lib/services/jam/jam_suggestion.dart`, query in `LibraryQueries` |
| `JamController` | all'ingresso da ospite salva coda, indice e posizione del player (su disco con la persistenza della coda che c'è già) e li ripristina in pausa all'uscita (R-90); `openSpeakerJam()` da fermo non apre una Jam vera ma entra nello stato «in attesa» (D-226): esce solo l'annuncio (`LanDiscovery.speakerJamName`, campo `jam` del pacchetto), player, UI e servizio restano intatti, e la Jam vera nasce alla prima richiesta accettata, con la coda di quel momento; da host con Jam attiva chiama `JamHost.makeSpeaker()` (uscite = [host]); `JamHost.removeMember` su un membro che era l'unica uscita equivale a `speakerAway` (uscita di nuovo all'host); avvia e ferma `JamPartFeeder` col cambio di modalità | `lib/providers/jam_providers.dart` |
| `SpeakerMonitor` (nuovo) e una classe vicina | ascolta il canale nativo, stima dalla classe, decide «cassa sì/no» (risposta salvata per indirizzo in shared_preferences), espone «cassa collegata ora» e «domanda in sospeso». La politica (apertura, chiusura in silenzio, assenza, ritorno, fine dopo 10 minuti, offerta dell'ospite) sta in `SpeakerJam`, pura, che raggiunge il controller dalla porta `SpeakerJamPort` (`JamController.speakerPort`) e da `SpeakerJamView`; il collegamento è in `speakerJamProvider` | `lib/services/audio/speaker_monitor.dart`, `lib/services/jam/speaker_jam.dart`, `lib/providers/speaker_providers.dart` |
| Lato nativo | `codecore/audio` aggiunge `bluetoothOutputs` (nome, indirizzo, classe dei dispositivi A2DP collegati) e un evento a Dart a ogni collegamento o scollegamento; permessi `BLUETOOTH` (maxSdk 30) e `BLUETOOTH_CONNECT` nel manifest; `netPrefix` per la maschera di rete | `MainActivity.kt`, `AndroidManifest.xml` |
| Scoperta | il pacchetto porta `jam: {name}` quando c'è una Jam della cassa aperta; il broadcast diretto usa la maschera vera (R-117) | `lib/services/share/discovery.dart` |
| UI | riga della modalità in cima a «Coda condivisa»; niente maniglie in `together`; `JamCover` con `fetchCover` e miniatura YouTube; banner «Unisciti alla Jam di X» sopra il mini player e riga in cima a «Dispositivi»; foglio «È una cassa?»; foglio del permesso; impostazioni «Jam sulla cassa»; avviso «Collega una cassa»; «Scarica» che segue lo stato del brano | `lib/ui/screens/jam/`, `lib/ui/shell/`, `lib/ui/screens/settings/`, `lib/ui/widgets/track_actions.dart` |

### Flussi
1. **Coda insieme.** L'host tocca «Coda insieme» → `setMode(together)` → il reducer riordina con `togetherOrder` → ogni dispositivo vede `mode = together` e avvia `JamPartFeeder`, che manda i primi brani della sua parte (la coda di prima della Jam; le aggiunte nuove vanno subito nella Jam come `add`). A ogni brano suonato il feeder rimanda il successivo; con la parte vuota manda un suggerito locale. Tornando a `host` i feeder si fermano e gli item restano dove sono.
2. **Cassa.** Il nativo avvisa «A2DP collegato» → `SpeakerMonitor`: indirizzo noto come cassa (o stima «cassa» senza risposta) e interruttore acceso → `SpeakerJam` → `port.open` (`JamController.openSpeakerJam()`): stato «in attesa», solo l'annuncio `jam` in LAN (uscita = solo l'host) → gli altri mostrano il banner → tocco → `request` → alla prima richiesta accettata nasce la Jam vera, con la coda di quel momento. Scollegata → `speakerAway` (pausa, comandi bloccati, coda libera) → ricollegata `speakerBack`, oppure un ospite collega la sua cassa e `offerSpeaker` lo fa diventare l'unica uscita (R-119), oppure dopo 10 minuti `end`. Senza ospiti, lo scollegamento chiude la Jam in silenzio.
3. **Uscita dell'ospite.** «Esci dalla Jam» → `leave` come oggi → il player riprende la coda salvata (in `together` la parte non suonata) in pausa.

### Dati
- `JamState`: `mode`, `speaker` (`spk`), `speakerAwaySince` (`spkAway`, ms); `JamItem`: `suggested` (`sug`) e `partKey` (`pk`, ≤ 64 caratteri, forma `id` o `id~n`). Nessuna tabella drift nuova.
- shared_preferences: casse note (indirizzo → sì/no, nome), interruttore «Jam sulla cassa», permesso già chiesto, coda salvata dell'ospite durante la Jam (si cancella all'uscita).

### Invarianti
1. In «Coda dell'host» l'ordine della coda si comporta come prima della feature (test di caratterizzazione verdi senza modifiche).
2. In «Coda insieme», dopo il corrente, due brani della stessa persona sono di fila solo se gli altri non ne hanno più.
3. Nessun brano di una parte si perde né si doppia: ogni item mandato dal feeder ha una chiave di parte e il feeder non rimanda una chiave già nella Jam o già suonata; il reducer scarta un `add` con lo stesso (owner, `partKey`).
4. La Jam della cassa ha una sola uscita: il dispositivo con la cassa (di serie l'host, un ospite solo con R-119).
5. Con la cassa assente nessun comando fa suonare la Jam.
6. L'ospite che esce ritrova sempre una coda: quella salvata o la sua parte; mai una coda vuota se prima non lo era.

### Dove va il codice nuovo
`lib/services/jam/` per turni, feeder e suggeriti (puri e testabili con `JamHost` in memoria come i test di oggi); `lib/services/audio/` per `SpeakerMonitor`; il resto nei file che esistono già. I test seguono `test/jam/` e `test/ui/`.

## Rischi
| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale d'allarme |
|---|---|---|---|---|---|
| K-JC-01 | Il riordino a turno nel reducer rompe la Jam di oggi («Coda dell'host») | M | A | Prima i test di caratterizzazione del reducer e della coda; `togetherOrder` agisce solo con `mode = together` (invariante 1) | Un test di `test/jam/` cambia senza che il passo lo dica |
| K-JC-02 | Code che si perdono: doppioni o brani persi fra più feeder e la finestra di 200, coda dell'ospite persa se l'app muore durante la Jam | M | A | Chiave di parte per item (invariante 3), coda salvata su disco all'ingresso, simulazione con host e due ospiti in memoria (`jam_multi_sim_test`) | Nella simulazione il numero di brani suonati + in coda + in parte cambia |
| K-JC-03 | Cassa riconosciuta male: classe assente o sbagliata, permesso rifiutato, eventi persi con l'app chiusa | A | M | Domanda «È una cassa?» che decide, controllo delle uscite collegate a ogni apertura, lista modificabile nelle impostazioni | Nella prova a mano la cassa vera non apre la Jam, o le cuffie la aprono |
| K-JC-04 | Jam fantasma della cassa: aperta quando non serve o che resta aperta | M | M | Interruttore acceso di serie ma spegnibile, chiusura silenziosa senza ospiti, fine dopo 10 minuti con la cassa assente; nessun cambio visibile finché nessuno entra | Banner che resta dopo lo scollegamento; Jam aperta sul telefono senza cassa |
| K-JC-05 | Lo scarto di ~2 s non viene dal codice (latenza dell'uscita sul Mi A3, misura a occhio) | M | M | Prima riprodurlo con i log di `JamSyncController` (`onSyncError`) e con la posizione mostrata; separare audio e schermo (R-94) | I log dicono errore < 80 ms ma la prova a mano sente lo scarto |
| K-JC-06 | Le prove a mano vogliono due telefoni, l'hotspot e una cassa vera: la chiusura resta in «Tocca a te» | A | B | Tutto il resto coperto da test in memoria; prova a mano in un solo passo finale (R-118) | Fase chiusa con `[~]` sulla prova |
| K-JC-07 | La maschera letta da `ip` cambia fra le distribuzioni; su Windows il broadcast /16 fa traffico in più | B | B | Parser con test sulle uscite reali; ripiego sulla /24 di oggi se la lettura fallisce | Scoperta che smette di funzionare sull'hotspot dopo R-117 |
