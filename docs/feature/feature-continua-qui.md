# Feature «Continua qui» (I-09)

Un tocco su un tuo dispositivo fidato in LAN prende brano, coda e posizione da un altro tuo dispositivo e riparte da lì; l'altro si mette in pausa.
Per chi: l'utente, fra telefono e PC (e fra due telefoni). Perché ora: oggi «Invia a un dispositivo» passa un brano o una playlist, ma non il punto in cui eri.

Kickoff del 2026-11-28 (idea I-09 in `docs/ideas.md`). Decisioni: D-774…D-779 in `docs/decisioni.md`. Si appoggia su dispositivi fidati, abbinamento e scoperta in LAN di oggi (`docs/architettura/sync-backup-jam.md`) e su coda e persistenza (`docs/architettura/riproduzione-e-coda.md`) senza cambiarne il comportamento.
Fasi: 171 (manda e prendi) e 172 (brani mancanti via LAN e suggerimento) in `docs/fasi/`.

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Tutto vale su Android, Linux e Windows, in ogni direzione (telefono→PC, PC→telefono, telefono→telefono, PC→PC); Windows usa lo stesso codice di Linux.
«Partenza» = il dispositivo che stava suonando; «arrivo» = quello che continua. «Miei» = dispositivi fidati col segno `mine` (D-668).

### Avvio
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-278 | Manda: nel foglio «Dispositivi» della partenza, ogni dispositivo mio raggiungibile ha «Continua su <nome>»; il tocco fa ripartire l'arrivo da brano e posizione correnti | I | Test con due nodi in memoria: «Continua su B» da A → B suona lo stesso brano alla stessa posizione (±1 s), A in pausa | 171 |
| R-279 | Prendi: nel foglio «Dispositivi» dell'arrivo, un dispositivo mio che sta suonando mostra «Continua qui da <nome>» con il brano in corso; il tocco chiede lo stato alla partenza e riparte | I | Test con due nodi: «Continua qui da A» su B → stesso esito di R-278; A fermo o senza coda → la voce non compare | 171 |
| R-280 | Pulsante con l'icona dei dispositivi nel player (schermo del brano e mini player sul desktop) che apre il foglio «Dispositivi» con le voci di R-278 e R-279 | I | Test widget: il pulsante c'è, apre il foglio, le voci compaiono con due nodi finti | 171 |
| R-281 | Suggerimento: se un dispositivo mio sta suonando ora, un banner «Sul <nome> sta suonando <brano> · Continua qui» (tocco = R-279). Si chiude con una X e non ricompare per lo stesso brano; interruttore «Suggerisci di continuare qui» nelle impostazioni, acceso di base. In pausa, fermo o non raggiungibile → nessun banner | I | Test widget con scoperta finta: A suona → banner; X → sparisce e non torna per lo stesso brano, torna per il successivo; interruttore spento → mai; A in pausa → niente | 172 |

### Cosa passa
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-282 | Passano: brano corrente, posizione, tutta la coda con l'indice corrente e il blocco «in coda» dell'utente, casuale, ripeti, tipo e nome del contesto, volume dell'app in percentuale (non quello di sistema) | I | Test di andata e ritorno del messaggio; test con due nodi: coda di 30 brani con 3 «in coda», casuale acceso, ripeti uno, volume 40% → identici sull'arrivo | 171 |
| R-283 | Posizione: se la partenza suona, l'arrivo parte dalla posizione più il tempo del passaggio (scarto ≤ 1 s); se è in pausa, dalla posizione esatta, e l'arrivo parte comunque in riproduzione | I | Test con orologio finto: ritardo di 800 ms con partenza in riproduzione → posizione + 0,8 s; in pausa → posizione identica | 171 |
| R-284 | La partenza resta com'è finché l'arrivo non conferma di aver iniziato a suonare; solo allora va in pausa e tiene la sua coda | I | Test: arrivo che non conferma → partenza ancora in riproduzione; conferma → pausa, coda invariata | 171 |
| R-285 | La partenza in pausa mostra «In ascolto su <nome> · Riprendi qui» (player e mini player); «Riprendi qui» riprende dal punto in cui è ora l'altro (come R-279) se è raggiungibile, altrimenti dal proprio punto. La scritta sparisce se si suona altro qui o l'altro si ferma | I | Test con due nodi: dopo R-278 la scritta c'è su A; «Riprendi qui» → A parte dal punto attuale di B e B va in pausa; B irraggiungibile → A riprende dal suo punto; altro brano su A → scritta tolta | 171 |

### Brani
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-286 | Brano locale: l'arrivo lo cerca nella sua libreria (stesso brano, criterio deciso nell'architettura); se non c'è, lo suona in streaming dalla partenza via LAN | I | Test: brano presente in entrambe le librerie → suona il file dell'arrivo; brano solo sulla partenza → suona l'indirizzo LAN della partenza | 171, 172 |
| R-287 | Brano in streaming (online): l'arrivo lo risolve da sé come i suoi; senza rete, o se la sua versione dell'app non può (flavor senza yt-dlp), lo salta | I | Test con preparatore finto: online + rete → risolto sull'arrivo; senza rete → saltato e contato in R-289 | 171 |
| R-288 | Partenza sparita (fuori rete, spenta) mentre l'arrivo suona brani presi da lei via LAN: quei brani si saltano e finiscono nel riepilogo; gli altri continuano | I | Test: nodo A tolto a metà → i brani LAN successivi saltati, i locali e gli online suonano | 172 |
| R-289 | Brani non suonabili: un riepilogo «N brani saltati» sull'arrivo (al passaggio e quando si saltano dopo, R-288) | I | Test widget: 2 saltati → «2 brani saltati»; nessuno → nessun avviso | 171 |
| R-290 | Partenza Android in pausa che serve brani via LAN: servizio in primo piano con la notifica «Condivido brani con <nome>» finché l'arrivo ne ha bisogno, così Android non chiude l'app; si spegne quando la coda dell'arrivo non ha più brani da lei o lui si ferma | I | Test del canale (avvio e arresto del servizio); prova automatica a due telefoni (adb): partenza in pausa e schermo spento 10 min, l'arrivo suona ancora i brani LAN | 172 |

### Dispositivi, coda dell'arrivo, Jam
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-291 | Solo fra dispositivi miei: un fidato senza `mine` o un estraneo non compare e una sua richiesta è rifiutata | I | Test: richiesta da fidato non mio → rifiutata, stato invariato; foglio senza voci per lui | 171 |
| R-292 | La coda dell'arrivo viene sostituita senza chiedere; un avviso con «Annulla» per circa 10 s rimette coda, indice, posizione e stato di riproduzione di prima. La partenza resta in pausa | I | Test: arrivo con la sua coda → sostituita; «Annulla» entro 10 s → coda, indice e posizione di prima; dopo 10 s → avviso sparito | 171 |
| R-293 | Con una Jam attiva su uno dei due (host o ospite) le voci sono spente con la nota «Esci dalla Jam per continuare altrove»; una richiesta arrivata durante una Jam è rifiutata | I | Test: Jam attiva su A o su B → voce spenta con la nota, richiesta rifiutata | 171 |

### Errori e compatibilità
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-294 | Dispositivo che non risponde: in «Prendi» compare «non raggiungibile» e la voce è spenta; in «Manda» un errore con il motivo (non raggiungibile, rifiutato, scaduto) e nessun cambiamento su nessuno dei due | I | Test con trasporto finto che fallisce in ciascun modo → messaggio giusto, stato invariato su entrambi | 171 |
| R-295 | Compatibilità (D-07): protocollo aggiunto senza cambiare quello di oggi; un dispositivo con una versione senza «Continua» compare con «Aggiorna l'app per continuare qui» e non si rompe nulla | I | Test: nodo che non annuncia la capacità → voce spenta con la nota; vecchie richieste di oggi ancora accettate | 171 |

### Testi e accessibilità
| ID | Requisito | Priorità | Criterio di accettazione | Fase |
|---|---|---|---|---|
| R-296 | Nomi: «Continua su…» (manda) e «Continua qui da…» (prendi); «Continua sul telefono» della Jam della cassa (D-263) resta com'è. Testi nei sei ARB | I | Test: chiavi presenti in it/en/de/es/fr/pt; nessun testo nuovo uguale a quello di D-263 | 171 |
| R-297 | Accessibilità: etichette per TalkBack e lettori di schermo su pulsante, voci, banner e scritta di R-285; l'esito si annuncia («Continua su <nome>: fatto», o l'errore) | I | Test widget delle semantiche e dell'annuncio; verifica uiautomator dei nodi | 171 |

## Fuori perimetro
- Passaggio fuori dalla LAN (via internet o broker): solo LAN.
- Prendere da un dispositivo spento o con l'app chiusa usando l'ultimo stato sincronizzato.
- Controllo a distanza continuo dell'altro dispositivo (play, salta, volume da qui): è un passaggio, non un telecomando.
- Passaggio automatico senza tocco (vicinanza, Bluetooth).
- Dispositivi fidati non miei ed estranei.
