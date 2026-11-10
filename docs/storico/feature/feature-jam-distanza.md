# Feature «Jam a distanza»

Oltre alla Jam in LAN, che resta, una Jam con host e ospiti su reti diverse, con ponte su un broker MQTT pubblico e cifratura end-to-end. Suona solo l'host; gli ospiti a distanza fanno da telecomando e mettono in coda (all'host arriva il video id e scarica da sé). Si entra solo da vicini via Bluetooth (Android) con un gettone che ruota, gli amici memorizzati si riconoscono, codice/QR di riserva. Anti-spam con 2 richieste al minuto, «Sospendi» e «Blocca», anche in LAN.
Per chi: l'utente e gli amici vicini ma non sulla stessa rete (un amico col 4G, l'host sul Wi-Fi di casa con la cassa). Perché ora: la Jam della cassa (fasi 66–68) è chiusa e senza ponte su internet la Jam vale solo sulla stessa rete.

Kickoff del 2026-10-29 (richiesta originale: `docs/prossimi-lavori.md` §2, «Jam a distanza»). Decisioni: D-228 … in `docs/decisioni.md`. Si appoggia su `docs/feature-jam-cassa.md` (R-88…R-119) senza cambiarne il comportamento in LAN, salvo l'anti-spam (R-147…R-150).
Fasi: vedi `docs/PROGRESS.md` (69 e seguenti).

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Ponte, codice e QR valgono su Android, Linux e Windows; Bluetooth (annuncio e scansione) solo su Android. Windows usa lo stesso codice di Linux ed è provato solo su Linux.
«Ospite remoto» = ospite entrato dal ponte; «ospite LAN» = ospite di oggi.

### Ponte (broker MQTT)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-120 | Jam mista: un solo host autorevole riceve richieste e comandi sia dalla LAN (HTTP di oggi) sia dal ponte; una sola coda e una sola `JamState.version`. Gli ospiti LAN suonano in sincronia come oggi, quelli remoti fanno solo da telecomando (D-231) | I | Test host in memoria con un ospite LAN e uno remoto (trasporto finto): entrambi aggiungono e vedono la stessa `version` e la stessa coda; le uscite restano quelle della LAN | 70 |
| R-121 | Il ponte (broker + annuncio Bluetooth) si accende da solo con la Jam della cassa, anche «in attesa» (D-226); altrimenti dal pulsante «Invita chi è vicino» nel foglio della Jam dell'host. Spento, l'app non si collega a nessun broker (D-232) | I | Test: Jam normale → nessuna connessione; pulsante → connessione e annuncio; Jam della cassa → automatico; fine della Jam → ponte spento | 70 |
| R-122 | Impostazioni «Jam a distanza»: lista dei broker (host, porta, TLS), predefinita `broker.emqx.io:8883` TLS (Mosquitto 8886 tolto, D-328); si aggiunge, toglie e riordina; «Prova connessione» e «Ripristina» (D-244, D-258) | I | Test della validazione (host non vuoto, porta 1–65535); test widget: aggiunta, riordino, ripristino; «Prova» con trasporto finto riuscito e fallito | 69 |
| R-123 | Broker di riserva: se il broker in uso non risponde, l'host passa da solo al successivo della lista; gli ospiti remoti seguono l'host sul nuovo broker senza fare niente (D-244) | I | Test con due broker finti: il primo cade → host e ospite si ritrovano sul secondo, la Jam continua con la stessa `version` | 70 |
| R-124 | L'ospite usa il broker (e la lista di riserva) dell'host senza configurare niente: arrivano con l'invito (Bluetooth o QR); con il codice digitato vale la lista dell'ospite (D-245) | I | Test: invito con un broker non predefinito → l'ospite si collega a quello; codice digitato → lista dell'ospite | 70 |
| R-125 | Broker irraggiungibile all'accensione (nessuno della lista risponde): «Broker irraggiungibile» con il collegamento alle impostazioni; la Jam in LAN e la musica continuano (D-246) | I | Test con trasporto finto che fallisce: messaggio, Jam LAN intatta | 70 |
| R-126 | Ponte interrotto durante la Jam: nuovi tentativi con attese crescenti fino a 30 s e nota «Ponte interrotto, riprovo…» sull'host; gli ospiti remoti vedono «Host non raggiungibile, riprovo…» e, dopo 10 minuti senza host, escono con «La Jam è terminata» e ritrovano la loro coda (R-90). Al ritorno l'ospite riparte dallo stato più recente (D-246) | I | Test con orologio finto: interruzione → tentativi a 1, 2, 4… ≤ 30 s; ritorno entro 10 min → stato ultimo; oltre 10 min → uscita con coda ripristinata | 70 |
| R-127 | Ospite remoto silenzioso (rete persa, app uccisa): dopo 60 s l'host vede «non raggiungibile» accanto al nome; se torna prosegue; dopo 10 minuti è tolto e i suoi brani online restano (D-93). L'ospite vede «Connessione persa, riprovo…» e si ricollega da solo. Nessun controllo sulla distanza: chi si allontana resta nella Jam (D-242, D-248) | I | Test con orologio finto: 60 s → segno; ritorno → segno tolto; 10 min → rimosso, item `yt:` non suonati presenti | 70 |
| R-128 | Host Android in sottofondo con il ponte acceso: servizio in primo piano con la notifica «Jam a distanza attiva · Termina», così Android non chiude la connessione anche in pausa (D-243) | I | Test del canale (avvio e arresto del servizio col ponte); prova a mano: host in pausa, schermo spento 10 min, l'ospite remoto rimette play | 70 |

### Sicurezza
Richiesta esplicita dell'utente (D-250): comunicazione sicura, con una cifratura sensata per un'app musicale fra amici su un broker pubblico. Il broker, chi conosce il nome di un canale e chi ascolta la rete non devono poter leggere, falsificare o ripetere i messaggi.
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-129 | Collegamento al broker sempre in TLS con verifica del certificato e del nome (niente «accetta tutto»); un broker senza TLS si può salvare solo con un avviso esplicito | I | Test: certificato non valido → connessione rifiutata; voce senza TLS → avviso nel foglio | 69, 70 |
| R-130 | Ogni messaggio sul ponte è cifrato e autenticato end-to-end (AEAD, chiavi a 256 bit) con chiavi effimere della sessione, una per ogni coppia host–ospite: chi viene tolto, bloccato o esce non legge più nulla di ciò che segue; finita la Jam le chiavi si buttano (segretezza in avanti) | I | Test: il trasporto finto non vede in chiaro titoli, nomi né id; un ospite tolto non decifra i messaggi successivi; chiave sbagliata → decifratura fallita | 70 |
| R-131 | L'ospite verifica che risponde il vero host e l'host che l'ospite è chi ha visto il gettone: lo scambio delle chiavi è legato al gettone ricevuto da vicino (Bluetooth, QR o codice). Chi controlla il broker non può mettersi in mezzo senza conoscere il gettone mentre è valido | I | Test: scambio con un intermediario che sostituisce le chiavi → entrambe le parti rifiutano; gettone scaduto → rifiutato | 70 |
| R-132 | Messaggi di estranei, ripetuti o vecchi (contatore per mittente o finestra temporale) sono scartati in silenzio, con un log limitato a una riga al minuto (`AppLog`) | I | Test: messaggi casuali, un messaggio valido ripetuto, uno cifrato con un'altra chiave → stato invariato, un solo log | 70 |
| R-133 | Metadati minimi: i nomi dei canali derivano dal segreto della Jam e cambiano a ogni Jam; sul broker non passano in chiaro nomi, brani né id dei dispositivi; l'annuncio Bluetooth non contiene un identificativo stabile del dispositivo | I | Test sul trasporto finto e sul pacchetto Bluetooth: due Jam dello stesso host → canali e annunci senza parti in comune | 70, 72 |
| R-134 | Ogni messaggio decifrato è validato (schema, dimensioni, limiti di `JamCommand`/`JamState`) prima di arrivare al reducer; un messaggio non valido è scartato come quelli di estranei | I | Test: messaggio decifrato ma malformato o oltre i limiti → scartato, nessuna eccezione | 70 |
| R-135 | Le primitive vengono da una libreria crittografica nota e mantenuta, nessuna inventata; le chiavi segrete (sessione, amici) non finiscono mai in log, backup o esportazioni | I | Test con vettori noti delle primitive usate; test che il backup non contiene le chiavi degli amici; grep dei log nei test | 69, 70 |

### Scoperta e ingresso
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-136 | Con il ponte acceso l'host Android annuncia via Bluetooth la Jam: id corto della Jam e gettone che cambia ogni ~30 s, più ciò che serve agli amici per riconoscerlo (R-144); niente dati che identifichino il dispositivo fra una Jam e l'altra (R-133) | I | Test: il gettone dipende dal segreto e dalla finestra di 30 s (finestre diverse → gettoni diversi); pacchetto entro i limiti dell'annuncio; prova a mano | 72 |
| R-137 | L'ospite Android cerca le Jam vicine solo con l'app in primo piano, in modalità a basso consumo; una Jam trovata mostra il banner «Unisciti alla Jam di X» e la riga in «Dispositivi» come R-112; in sottofondo la ricerca si ferma (D-233) | I | Test widget con uno scanner finto: annuncio → banner e riga; app in sottofondo → scanner fermo | 72 |
| R-138 | Permessi: Android 12+ `BLUETOOTH_SCAN` (senza posizione) e `BLUETOOTH_ADVERTISE`, chiesti al primo uso con una riga di spiegazione; Android ≤ 11 la posizione, chiesta una volta con la spiegazione («Android la richiede per cercare via Bluetooth; l'app non legge dove sei»). Rifiuto o posizione spenta → solo codice/QR, riattivabile dalle impostazioni (D-234) | I | Test widget dei fogli di richiesta; prova a mano sul Mi A3 (Android 11): rifiuta, poi riattiva | 72 |
| R-139 | Una richiesta d'ingresso vale solo con un gettone recente (finestra corrente o precedente, ≤ 60 s; per il codice digitato 2 minuti) | I | Test con orologio finto: gettone di 61 s prima → scartata; dentro la finestra → accettata | 70 |
| R-140 | Codice/QR di riserva: il foglio della Jam dell'host mostra un QR che cambia col gettone (~30 s) e un codice di ~8 caratteri che vale 2 minuti; l'ospite inquadra il QR (Android) o digita il codice (tutte le piattaforme); sbagliato → «Codice non valido», scaduto → «Codice scaduto, chiedi quello nuovo» (D-235) | I | Test del formato e delle scadenze del codice; test widget del campo con codice sbagliato e scaduto | 70 |
| R-141 | Lettura del QR con la webcam su Linux e Windows. Rimandata: l'unica strada (`camera_desktop` 2.0.0 + `zxing2`) è giovane e porta le librerie GStreamer nella build Linux; sul PC si digita il codice (D-249, D-253) | R | Test widget dello schermo di scansione desktop con una sorgente finta | Dopo |
| R-142 | Ogni ingresso remoto lo accetta l'host come oggi (`JamHost.accept`), con lo stesso foglio Accetta/Rifiuta più «Sospendi» e «Blocca»; la richiesta mostra il nome e se è un amico | I | Test: richiesta remota → foglio con le quattro azioni; accetta → ospite remoto nel roster | 70 |
| R-143 | Amici della Jam: dopo il primo ingresso accettato host e ospite si salvano a vicenda (nome e segreto per riconoscersi), senza chiedere; lista «Amici della Jam» nelle impostazioni, con rimozione; separata dai dispositivi fidati della fase 24, che non cambiano (D-236) | I | Test: accetta → entrambi salvati; rimozione; `trustedDevices` invariato | 72 |
| R-144 | Amici riconosciuti solo da vicini: l'ospite vede la Jam di un amico col nome salvato e in cima al banner e alla lista; l'host vede la richiesta segnata «Amico» e in cima. Nessun canale personale sul broker: gli amici non vedono la Jam da lontano | I | Test: annuncio di un amico → riconosciuto con gettoni diversi; annuncio di un estraneo → non riconosciuto; un amico rimosso non è più riconosciuto | 72 |
| R-145 | Interruttore «Accetta gli amici senza chiedere», spento di serie (D-236) | U | Test: acceso → la richiesta di un amico entra senza foglio; spento → foglio | 72 |
| R-146 | Su Linux e Windows host e ospite a distanza col codice; il QR si mostra, niente Bluetooth (D-247) | I | Test widget desktop: «Invita» mostra QR e codice, nessuna richiesta di permessi Bluetooth; prova a mano Linux + telefono su 4G | 70 |

### Richieste ripetute (LAN e distanza)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-147 | Al massimo 2 richieste al minuto per dispositivo (id del mittente), in LAN e a distanza; in LAN resta anche il limite di 5 al minuto per indirizzo IP. Le richieste oltre il limite sono scartate in silenzio; l'app dell'ospite conta le sue e alla terza dice «Aspetta un momento prima di riprovare» (D-238, D-239) | I | Test con orologio finto: tre richieste dello stesso id in 60 s → la terza scartata; dopo 60 s di nuovo accettata; test widget dell'avviso sull'ospite | 69 ✓ |
| R-148 | «Sospendi» sulla richiesta: scelta fra 15, 30, 45, 60 minuti e «Fino alla fine della Jam», con l'aspetto del selettore del timer di spegnimento (estratto in un widget condiviso). Le richieste di quel dispositivo sono scartate in silenzio fino alla scadenza; la sospensione è salvata con la sua scadenza e sopravvive al riavvio; scaduta, le richieste tornano valide (D-237) | I | Test con orologio finto e riavvio simulato (preferenze): sospeso 15 min → scartate; a 15 min + 1 s → accettate; «fino alla fine» → finisce con la Jam | 69 ✓ |
| R-149 | «Blocca»: blocco permanente del dispositivo; lista «Dispositivi bloccati» nelle impostazioni con «Sblocca» (D-247) | I | Test: bloccato → richieste scartate anche dopo il riavvio; sblocca → accettate | 69 ✓ |
| R-150 | Sospeso o bloccato, l'ospite non riceve risposta: una richiesta remota senza risposta finisce dopo 60 s con «L'host non ha risposto»; in LAN resta la scadenza di oggi (`jamRequestTtl`). Lo stesso vale per la richiesta che l'host non tocca (D-238) | I | Test con orologio finto: richiesta remota senza risposta → 60 s → messaggio; sul foglio dell'host la richiesta sparisce allo stesso momento | 69, 70 |

### Coda dell'ospite remoto
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-151 | Un brano aggiunto dalla Ricerca online arriva all'host come video id (item `yt:`, `selfFetchable`, D-93) e l'host lo scarica o lo riproduce da sé; nessun file passa dal ponte | I | Test host + ospite remoto in memoria: aggiunta online → item `yt:` nella coda; nessun messaggio oltre il limite di RNF-14 | 71 |
| R-152 | Un brano della libreria dell'ospite con video id noto parte come video id; senza, il telefono dell'ospite lo cerca per titolo + artista (`SeedResolver`, solo corrispondenza sicura) prima di mandarlo; se non lo trova: «Non trovato online, non si può aggiungere» (D-240) | I | Test con un resolver finto: trovato → item `yt:`; non trovato → messaggio, nessun comando inviato | 71 |
| R-153 | In «Coda insieme» la parte e i suggeriti di un ospite remoto arrivano come video id, risolti come R-152; quelli non trovati si saltano (D-247) | I | Test del feeder con un resolver finto: brani non trovati saltati, gli altri entrano a turno | 71 |
| R-154 | Copertine per l'ospite remoto: item `yt:` e brani dell'host con video id noto → miniatura di YouTube; senza video id, la nota. Nessuna immagine passa dal ponte (D-241) | I | Test widget di `JamCover` da ospite remoto: item con video id → miniatura; senza → nota; nessuna richiesta a `/cover` | 71 |
| R-155 | Scheda del brano, testo e curiosità per l'ospite remoto si ricavano dal video id e dai metadati, come nella Jam come player (fase 63) (D-247) | I | Test: ospite remoto apre la scheda di un item `yt:` → dati dal video id, nessuna chiamata all'host | 71 |
| R-156 | Gli ospiti remoti hanno gli stessi comandi degli ospiti LAN (play/pausa, salti, seek, volume, coda); al massimo 5 partecipanti in tutto, LAN + remoti (D-247) | I | Test: comandi di un ospite remoto applicati come quelli LAN; sesto partecipante → `full` | 70 |
| R-157 | Un ospite remoto non suona mai e non può diventare l'uscita: `offerSpeaker` (R-119) vale solo in LAN (D-247) | I | Test del reducer: `offerSpeaker` da un ospite remoto → rifiutato; le uscite non includono mai ospiti remoti | 70 |
| R-158 | Quando l'host termina la Jam o l'ospite remoto esce, l'ospite ritrova la sua coda (R-90); l'host può togliere un ospite remoto come oggi (D-247) | I | Test host + ospite remoto in memoria: fine e rimozione → coda dell'ospite ripristinata | 70 |

### Prove a mano
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-159 | Prova con due telefoni, uno su 4G, sul broker predefinito: ingresso via Bluetooth, via QR e via codice da Linux; aggiunte dalla libreria e dalla Ricerca; Sospendi e Blocca; broker spento (voce sbagliata in testa alla lista → riserva); host in pausa in sottofondo 10 min; ospite in modalità aereo 1 min e 11 min | I | Esiti scritti in `docs/PROGRESS.md` sotto il passo di prova, uno per riga | 73 |

## Requisiti non funzionali
- **RNF-14** Ogni messaggio sul ponte, cifrato, sta sotto i 64 KB (stato con 200 item compreso); niente file né immagini sul ponte.
- **RNF-15** Cifratura e decifratura non bloccano la UI: misura sul Mi A3 di un messaggio da 64 KB; se supera 8 ms, si fanno fuori dal thread della UI.
- **RNF-16** Traffico e batteria: l'host pubblica solo a ogni nuova `version` più un segnale di vita ogni 30 s; la scansione Bluetooth gira solo in primo piano e l'annuncio solo col ponte acceso.
- **RNF-17** La Jam in LAN senza ponte non cambia velocità né comportamento (test di `test/jam/` verdi senza modifiche, salvo l'anti-spam). Fase 69 ✓: in `test/jam/` sono cambiati soltanto i test del gate e quelli dei rilievi 68.3 (20 posti per le aggiunte a mano, D-264, e la Jam della cassa), nessuno per il ponte.

## Vincoli
- Pacchetti nuovi: solo `mqtt_client` e `sodium` (§Stack). Bluetooth con un canale nativo, QR con `qr_flutter` e `mobile_scanner` che ci sono già (`mobile_scanner` solo Android).
- Broker pubblici gratuiti senza garanzie (EMQX: «prototype, learn, and test»; Mosquitto: «free for any application, don't rely on it»; HiveMQ pubblico vieta l'uso in app, escluso). Tutto ciò che vi passa è leggibile da chiunque: da qui R-129…R-135.
- Permessi nuovi nel manifest: `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`, `ACCESS_FINE_LOCATION` solo fino ad Android 11 (`maxSdkVersion 30`), servizio in primo piano per la Jam a distanza.
- L'annuncio Bluetooth classico ha 31 byte: id della Jam, gettone e riconoscimento degli amici devono starci (o nell'annuncio esteso, o nella risposta alla scansione).
- L'id del dispositivo lo dichiara il mittente: l'anti-spam regge per gli amici normali; serve comunque un gettone ottenuto da vicino.
- Bluetooth solo per dire «qui c'è una Jam»: annuncio dell'host col ponte acceso e scansione dell'ospite con l'app in primo piano. Nessun messaggio della Jam passa dal Bluetooth, nessuna connessione fra telefoni, nessun controllo continuo della distanza (batteria, D-248).
- Nessun backend nostro, nessun costo.

## Stack
Versioni verificate il 2026-10-29 su pub.dev (API), GitHub e developer.android.com.
| Componente | Scelta | Versione | Perché | Alternative scartate |
|---|---|---|---|---|
| Client MQTT | `mqtt_client` | ^10.14.0 (26/10/2026, BSD-3) | Android/Linux/Windows, TLS con `secure = true` su `SecurityContext.defaultContext` e certificato non valido rifiutato (`onBadCertificate` null), QoS 0–2, messaggi `retain`, manutenzione attiva. La riconnessione e il passaggio al broker di riserva li fa il nostro codice (`autoReconnect` riprova solo lo stesso broker) (D-251) | `mqtt5_client` (MQTT 5 non serve) |
| Crittografia | `sodium` | ^4.1.2 (27/10/2026, BSD-3) | libsodium 1.0.22, sorgenti inclusi nel pacchetto e compilati dai build hooks su ogni piattaforma (Dart ≥ 3.13: ce l'abbiamo). Usati: `crypto_kx` (X25519), `crypto_kdf_hkdf`, `crypto_aead_xchacha20poly1305_ietf`, `crypto_auth`, `randombytes`. `sodium_libs` non serve più (D-252) | `cryptography` 2.9.0 (fermo da 11 mesi; AES-GCM in Dart puro con difetto aperto che espone la chiave di autenticazione, emz-hanauer/dart-cryptography#12, segnalato in dint-dev/cryptography#224); `pointycastle` (basso livello, niente X25519 pronto) |
| Bluetooth LE | canale nativo Kotlin | — | `BluetoothLeAdvertiser` (annuncio non connettibile, 27 byte di service data su UUID a 16 bit, nome nella risposta alla scansione) e `BluetoothLeScanner` (`ScanFilter` sull'UUID, `SCAN_MODE_LOW_POWER`, un solo scan continuo: Android limita a 5 avvii in 30 s). Zero pacchetti, ~150–200 righe accanto a `codecore/audio` (D-254) | `flutter_blue_plus` (licenza non open source), `flutter_ble_peripheral` (solo annuncio), `bluetooth_low_energy` 6.2.1 (più pesante, meno controllo sul formato) |
| Segreti persistenti | `shared_preferences` | già nel progetto | Solo le chiavi per riconoscere gli amici; esclusi da backup ed esportazione. Le chiavi di sessione stanno solo in memoria (D-255) | `flutter_secure_storage` 11.2.0 (su Linux vuole libsecret e un portachiavi attivo; su Android perde le chiavi dopo un ripristino) |

Trappole:
- `sodium` compila libsodium alla prima build per ogni piattaforma: la prima build Android e la CI si allungano; la build Android da Windows vuole bash e make (Git for Windows).
- Che il Mi A3 sappia annunciare in BLE non è verificato: il test giusto è `bluetoothLeAdvertiser != null` più `onStartFailure`. Senza annuncio l'host usa codice/QR.
- Il limite reale dei messaggi lo decide il broker (non documentato per EMQX): RNF-14 tiene i messaggi sotto i 64 KB.

## Architettura
Si estende la Jam di oggi (`docs/feature-jam-cassa.md` §Architettura, `docs/02-architettura.md`): stesso `JamHost` autorevole, stesso reducer `applyCommand`, stessa `JamState.version`. Cambia solo il trasporto: accanto al router HTTP della LAN, che resta com'è, un ponte MQTT cifrato end-to-end (D-228, D-231, D-250). Pacchetti nuovi: `mqtt_client` e `sodium` (D-251, D-252). Nomi di API citati qui verificati sui sorgenti di `mqtt_client` 10.14.0 e `sodium` 4.1.2.

### Componenti
| Componente | Cosa fa / cosa cambia | File |
|---|---|---|
| `JamGuestLink` (nuovo, interfaccia) | Ciò che `JamController` usa dell'ospite: `states`, `lost`, `state`, `send`, `probeHostTime`, `invite`, `leave`, `cancelJoin`, `dispose`, `files: JamHostFiles?` (null per l'ospite remoto) e `link`/`links` (`JamLinkState`: ok, reconnecting, hostSilent). `JamGuest` la implementa senza spostare codice (RNF-17); in `JamController` `_guest` diventa `JamGuestLink?` | `lib/services/jam/jam_guest_link.dart`, `jam_guest.dart` |
| `RemoteJamGuest` (nuovo) | Ospite via ponte: `join(JamInvite)` (lobby, richiesta, attesa 60 s, R-150), stato da `STATE`, comandi `CMD` → `RESULT` (attesa 10 s, poi `JamError.notFound` come oggi un errore Dio), `PING` ogni 30 s, `SYNC` a ogni riconnessione, orologio con `TIME` per `JamClock`, `lost` dopo 10 min senza host (R-126); `invite` → false (un ospite remoto non inoltra richieste LAN). `JamJoinOutcome` aggiunge `codeInvalid`, `codeExpired`, `customBroker`, `tooSoon` | `lib/services/jam/remote/remote_jam_guest.dart`, `jam_guest.dart` |
| `JamHost` | (1) la validazione di `POST /request` passa in `admitRequest(...)`, chiamata dal router e dal ponte, col `JamGate`; (2) `addMember(..., remote: true)` e `JamParticipant.remote`; (3) cancello nel riduttore (`jam_state.dart`, non in `apply`): `offerSpeaker` da un remoto e `setOutput`/`setOutputs` verso un remoto → `JamError.forbidden` (R-157); (4) `dropStale(75 s, remote: 10 min)` e `unreachableIds(60 s)` per il segno «non raggiungibile» (R-127, D-242); (5) `touch(id)` per ogni messaggio valido di un remoto; (6) `JamRequest.remote`, `.friend`, `.silent`, `.ttl` (60 s remoto, `jamRequestTtl` LAN); `expire()` notifica quando cambia qualcosa | `lib/services/jam/jam_host.dart`, `jam_models.dart` |
| `JamGate` (nuovo, puro) | Anti-spam di LAN e ponte: 2 richieste al minuto per id (finestra scorrevole), «Sospendi» con scadenza o «fine Jam», «Blocca», liste per le impostazioni; orologio iniettato; salvato in `JamSecretStore`. In LAN il limite di 5/min per IP resta nel router. Oltre il limite per id → 429 come oggi per l'IP; sospeso o bloccato → richiesta `silent`: 202, mai mostrata, non conta per «busy», scade a `jamRequestTtl` in LAN e 60 s sul ponte, senza risposta (R-147…R-150, D-237, D-238, D-239) | `lib/services/jam/jam_gate.dart` |
| `JamCrypto` (nuovo, interfaccia) e `SodiumJamCrypto` | Solo queste primitive di `sodium`: `crypto.kx` (`keyPair`, `clientSessionKeys`, `serverSessionKeys`), `crypto.kdfHkdfSha256` (`extract`, `expand`), `crypto.aeadXChaCha20Poly1305IETF` (`encrypt`, `decrypt`), `crypto.auth` (`call`, `verify`), `crypto.genericHash`, `crypto.pwhash.callStr` (Argon2id), `randombytes.buf`, `pad`/`unpad`, `SecureKey.dispose`. Inizializzazione con `SodiumSumoInit.init()`: sulle piattaforme native è la stessa libreria di `SodiumInit` (README di `sodium`) e porta `pwhash`. Casualità iniettabile per i test (R-135) | `lib/services/jam/remote/jam_crypto.dart` |
| `JamProtocol` (nuovo, puro) | Derivazioni e formati di §Protocollo di sicurezza: gettone, etichetta amici, annuncio, QR, codice, lobby, richiesta, busta con contatore, compressione, limiti. Nessun I/O | `lib/services/jam/remote/jam_protocol.dart` |
| `MqttLink` (nuovo) e `MqttClientLink` | Interfaccia minima: `connect(BrokerEntry)`, `subscribe`, `unsubscribe`, `publish(topic, bytes, retain:)`, `messages`, `connected`, `disconnect`. Implementazione: `MqttServerClient.withPort(host, clientId, port)`, `secure = tls`, `securityContext = SecurityContext.defaultContext`, `onBadCertificate` lasciato null (R-129), `setProtocolV311()`, `keepAlivePeriod = 30`, `autoReconnect = false`, `connectionMessage = MqttConnectMessage().withClientIdentifier(id).startClean()`, `subscribe(topic, MqttQos.atLeastOnce)`, `publishMessage(topic, MqttQos.atLeastOnce, buffer, retain: r)`, `updates`, `onDisconnected`. `clientId` casuale (20 caratteri) a ogni connessione (R-133). Mai iscrizioni con `#` o `+` | `lib/services/jam/remote/mqtt_link.dart` |
| `JamBridge` (nuovo) | Connessione con riserva su una lista ordinata di `BrokerEntry` (host, porta, TLS): tentativi e attese del flusso 5, iscrizioni rifatte dopo ogni riconnessione, `status` (`connecting`, `up`, `retrying`, `unreachable`). Lo usano host e ospite (R-123, R-125, R-126, D-244, D-246) | `lib/services/jam/remote/jam_bridge.dart` |
| `JamBridgeHost` (nuovo) | Lato host: segreti dell'accensione, lobby, codice, richieste (al massimo 10 tentativi di decifratura al secondo, `Gpk` già visti scartati), una coppia di chiavi per ospite remoto. Ascolta `JamHost.changes`: richiesta accettata → `ACCEPT`, rifiutata → `NO`, nuova `version` → `STATE` a ogni remoto, membro sparito → `BYE` e chiavi buttate. `PING` ogni 30 s; `expire()` ogni secondo; allo spegnimento svuota i messaggi `retain` | `lib/services/jam/remote/jam_bridge_host.dart` |
| `JamInvite` (nuovo) | Ciò che serve per entrare, da annuncio, QR o codice; parser del QR, normalizzazione del codice | `lib/services/jam/remote/jam_invite.dart` |
| `JamFriends` (nuovo) | Lista «Amici della Jam» e chiave d'annuncio `AK` del dispositivo: riconoscimento dall'etichetta, prova dell'amico, salvataggio reciproco, rimozione con rotazione di `AK` (R-143…R-145, D-236) | `lib/services/jam/remote/jam_friends.dart` |
| `JamSecretStore` (nuovo) | Segreti persistenti su `SharedPreferencesAsync`: su Android vanno nel file DataStore `files/datastore/FlutterSharedPreferences.preferences_pb`, escluso dal backup di Android con `backup_rules.xml` e `data_extraction_rules.xml` (il resto del backup non cambia); il backup dell'app non li vede perché `settingsToJson` legge solo `SharedPreferences`. Dietro un'interfaccia chiave–valore: nei test una mappa (R-135, D-255) | `lib/data/settings/jam_secret_store.dart`, `android/app/src/main/res/xml/` |
| `JamBeacon` (nuovo) e lato nativo | Dart: `capabilities`, `permissions`/`requestPermissions`, `startAdvertising(bytes)`/`updateAdvertising`/`stopAdvertising`, `startScan`/`stopScan`, stream `found` (byte, RSSI). Kotlin in un file suo come gli altri bridge, canale `codecore/jam_beacon`: `BluetoothLeAdvertiser.startAdvertisingSet` (API 26+, `setLegacyMode(true)`, non connettibile, non scansionabile, solo service data su UUID16, `setIncludeDeviceName(false)`), `AdvertisingSet.setAdvertisingData` a ogni finestra (sotto l'API 26 stop e start); `BluetoothLeScanner.startScan` con `ScanFilter.Builder().setServiceData(uuid, [1], [0xFF])` e `SCAN_MODE_LOW_POWER`, uno scan solo. Su Android ≤ 11 dice anche se la posizione è spenta (D-233, D-234, D-254) | `lib/services/jam/remote/jam_beacon.dart`, `android/.../JamBeaconBridge.kt`, `MainActivity.kt` (registrazione e risultato dei permessi), `AndroidManifest.xml` |
| Scoperta LAN | Col ponte acceso il pacchetto della Jam porta anche `jam.rid` = jamId: l'ospite sulla stessa rete unisce l'annuncio Bluetooth alla riga LAN ed entra in LAN, in sincronia | `lib/services/share/discovery.dart` |
| `JamController` | `requestRemote(JamInvite)` col contatore locale (terza richiesta in 60 s → «Aspetta un momento prima di riprovare», R-147); `invite()` mette `inviting` in `JamUiState`; nuovi `JamUiState.remote` (questo dispositivo è ospite remoto) e `link` (`ok`, `reconnecting`, `hostSilent`); da ospite remoto `JamPart` crea gli item con `JamRemoteItems` invece di `jamItemOfTrack` e `addOnline` manda subito l'item `yt:` senza scaricare; `jamItemOfTrack` mette `vid` = `DownloadIndex.idForPath(path)` sui brani di libreria (R-154); «Termina» dalla notifica durante l'«attesa» chiude l'attesa e il ponte | `lib/providers/jam_providers.dart`, `lib/providers/jam_part.dart` |
| `JamRemoteItems` (nuovo) | `Track` → item `yt:youtube:<vid>` (`selfFetchable`, `ext` = `webm` convenzionale: chi scarica usa l'estensione del suo file) con `SeedResolver.resolve` (download che ha fatto il file, poi indice, poi ricerca solo sicura); null → «Non trovato online, non si può aggiungere» o, nel feeder, brano saltato (R-151…R-153, D-240) | `lib/services/jam/remote/jam_remote_items.dart` |
| `jamSelfFetchTargets` | Scarica da sé anche gli item di un partecipante remoto, non solo quelli di chi è uscito (una condizione in più) | `lib/services/jam/jam_online_adder.dart` |
| Provider | `jamBridgeProvider` (accende e spegne `JamBridgeHost` guardando `jamProvider`: acceso ⇔ Jam della cassa, anche «in attesa», oppure `inviting`; annuncio Bluetooth, servizio in primo piano, stato per la UI), `jamNearbyProvider` (scansione con `AppLifecycleListener`: solo in primo piano, senza Jam in corso, con permesso; voci tolte dopo 90 s senza pacchetti), `jamFriendsProvider`, `jamGateProvider`, `jamCryptoProvider`, `remoteJamGuestFactoryProvider` (sovrascritto nei test) | `lib/providers/jam_remote_providers.dart` |
| Servizio in primo piano | Lo stesso `ReceiveService` (specialUse) con «Jam a distanza attiva · Termina»: `ShareHubNotifier.holdJam(remote: true)` per l'host col ponte acceso (anche in attesa) e per l'ospite remoto, che come l'ospite LAN di oggi deve restare vivo con lo schermo spento (R-127, R-128, D-243) | `lib/providers/share_hub.dart` |
| UI | Foglio «Invita chi è vicino» (stato del ponte, QR che ruota, codice `XXXX-XXXX` col tempo che resta); «Entra con un codice» (campo; scanner QR solo su Android con `mobile_scanner`); richiesta con «Amico», Accetta, Rifiuta, Sospendi, Blocca, chiusa a 60 s; `showDurationChoiceSheet` estratto da `_showSleepSheet` e usato da timer e Sospendi; banner e riga «Dispositivi» per le Jam vicine (amici in cima col nome salvato); segno «non raggiungibile» nel roster; `JamCover`: per l'ospite remoto i brani di libreria con `vid` mostrano la miniatura, in LAN resta la copertina del proprietario; impostazioni «Jam a distanza» (broker con «Prova connessione» e «Ripristina», avviso per le voci senza TLS, amici, bloccati, sospesi, «Accetta gli amici senza chiedere», «Cerca Jam vicine» con i permessi) | `lib/ui/screens/jam/`, `lib/ui/widgets/duration_choice_sheet.dart`, `lib/ui/screens/settings/jam_remote_settings.dart`, `now_playing_controls.dart` |

### Protocollo di sicurezza
Obiettivo (D-250, R-129…R-135): il broker, chi conosce un canale e chi ascolta la rete non leggono, non falsificano e non ripetono nulla; l'ingresso è legato a qualcosa visto da vicino. Scelte motivate:
- **Una coppia di chiavi per ospite, niente chiave di gruppo.** Con ≤ 4 ospiti remoti (R-156) lo stato si cifra al massimo 4 volte per `version`. Una chiave di gruppo farebbe fingere l'host a ogni ospite verso gli altri (servirebbe una firma) e vorrebbe un rinnovo a ogni uscita. Per coppia, togliere un ospite è buttare le sue chiavi: nessun rinnovo (R-130).
- **Nessuna `retain` di stato.** Chi si ricollega manda `SYNC` e l'host risponde con lo stato: sul broker restano solo la lobby (chiave pubblica) e la lobby del codice (cifrata), cancellate allo spegnimento.
- **Codice digitato con Argon2id.** Un codice corto si forza offline se un broker intermediario ottiene un testo cifrato con esso; con Argon2id (memoria 64 MiB) 2⁴⁰ tentativi in 2 minuti sono fuori portata. Il gettone del Bluetooth (48 bit) non serve forzarlo: senza la chiave segreta di una delle due parti il broker non ha niente su cui provarlo offline, e online l'host limita i tentativi.

Notazione: `‖` concatenazione; `u64be` intero a 8 byte big endian; `b64u` base64url senza `=`; etichette in ASCII. Primitive: `KX` = `crypto.kx` (X25519 + BLAKE2b, già lega le due chiavi pubbliche); `EXTRACT`/`EXPAND` = `crypto.kdfHkdfSha256.extract(salt:, ikm:)` / `.expand(masterKey:, context:, outLen:)`; `AEAD` = `crypto.aeadXChaCha20Poly1305IETF` (chiave 32 B, nonce 24 B casuale da `randombytes.buf(24)`, tag 16 B); `MAC` = `crypto.auth` (HMAC-SHA-512-256, chiave e tag 32 B); `GH` = `crypto.genericHash` (BLAKE2b); `PAD` = `sodium.pad(x, 256)`.

#### Segreti
| Segreto | Chi | Vita | Dove |
|---|---|---|---|
| `S` (32 B casuali), `Hsk`/`Hpk` (`KX.keyPair()`) | host | un'accensione del ponte | memoria |
| `KC` del codice | host, ospite | 2 min | memoria |
| `Gsk`/`Gpk` (`KX.keyPair()`) | ospite | una richiesta | memoria; `Gsk` buttata dopo la derivazione |
| `K_g2h`, `K_h2g`, contatori | coppia host–ospite | finché l'ospite è nella Jam | memoria; `dispose()` a uscita, rimozione, blocco, fine |
| `AK` (chiave d'annuncio, 32 B) | ogni dispositivo | finché non si toglie un amico | `JamSecretStore` |
| `FKp` (chiave della coppia di amici, 32 B) | i due amici | finché l'amico è in lista | `JamSecretStore` |

#### Derivazioni
| Valore | Formula |
|---|---|
| `PRK_S` | `EXTRACT(salt: null, ikm: S)` |
| `jamId` (6 B) | `EXPAND(PRK_S, "ccj1 jam-id", 32)[0:6]` |
| `KT` | `EXPAND(PRK_S, "ccj1 token", 32)` |
| finestra `w` | `floor(oraHostMs / 30000)` come `u64be`; solo l'orologio dell'host conta |
| gettone `T_w` (6 B) | `MAC(KT, "ccj1-tok" ‖ w)[0:6]`; l'host accetta `T_w` e `T_(w−1)`, cioè ≤ 60 s (R-139) |
| impronta `fpH` (8 B) | `GH(Hpk, outLen: 16)[0:8]` |
| etichetta amici (4 B) | `MAC(AK, "ccj1-ft" ‖ w ‖ fpH)[0:4]`, legata alla Jam: l'etichetta copiata nell'annuncio di un'altra Jam non si riconosce. L'ospite ha `fpH` dall'annuncio (lobby verificata) o da `Hpk` nel QR e prova `w−1`, `w`, `w+1` del suo orologio per ogni amico salvato |
| scambio | ospite `(rx, tx) = KX.clientSessionKeys(Gpk, Gsk, Hpk)`, `ikm = tx ‖ rx`; host `(rx, tx) = KX.serverSessionKeys(Hpk, Hsk, Gpk)`, `ikm = rx ‖ tx` (stessi 64 B) |
| prova di vicinanza `P` | `T_w` (Bluetooth, QR) oppure `KC` (codice) |
| `PRK` | `EXTRACT(salt: P, ikm)` |
| chiavi della coppia | `K_req = EXPAND(PRK, "ccj1 req", 32)`, `K_g2h = EXPAND(PRK, "ccj1 g2h", 32)`, `K_h2g = EXPAND(PRK, "ccj1 h2g", 32)`, `FKp = EXPAND(PRK, "ccj1 friend", 32)`, `tp = EXPAND(PRK, "ccj1 topic", 32)[0:16]` |
| prova dell'amico | `MAC(FKp_salvata, "ccj1-fp" ‖ jamId ‖ Gpk)` (32 B) |
| codice (D-257) | `X = pwhash.callStr(outLen: 64, password: C, salt: "codecore-jam-c1!" (16 B), opsLimit: opsLimitInteractive, memLimit: memLimitInteractive, alg: argon2id13)` in un isolate; `codeTopicId = X[0:16]`, `KC = X[32:64]` |

#### Canali MQTT
| Canale | Nome | QoS / retain | Contenuto |
|---|---|---|---|
| lobby | `ccj1/<b64u(jamId)>/l` | 1 / sì | `LOBBY` |
| richieste | `ccj1/<b64u(jamId)>/r` | 1 / no | `REQUEST` |
| codice | `ccj1/c/<b64u(codeTopicId)>` | 1 / sì | `CODE` |
| host → ospite | `ccj1/<b64u(tp)>/h` | 1 / no | buste `h2g` |
| ospite → host | `ccj1/<b64u(tp)>/g` | 1 / no | buste `g2h` |

Il broker vede che esiste una Jam di FreeKmusic (prefisso `ccj1`) e i suoi partecipanti, non chi sono: tutti i nomi cambiano a ogni accensione (R-133).

#### Formati
| Messaggio | Byte |
|---|---|
| Annuncio Bluetooth (service data su UUID16 `0xC0DE`, 26 B; nessun nome: gli estranei vedono «Jam qui vicino», gli amici il nome salvato, D-256) | `0x01` ‖ `jamId`(6) ‖ `T_w`(6) ‖ `fpH`(8) ‖ etichetta amici(4) ‖ broker(1): indice del broker in uso in `kDefaultJamBrokers` (lista costante, si allunga solo in fondo), `0xFF` = broker personalizzato → serve il QR. Nessun nome, nessun id stabile |
| `LOBBY` (34 B) | `0x01` ‖ `0x01` ‖ `Hpk`(32). Payload vuoto = cancellata |
| `REQUEST` (≤ 2 KB) | `0x01` ‖ `0x02` ‖ `Gpk`(32) ‖ nonce(24) ‖ `AEAD(K_req, ad = "ccj1" ‖ 0x01 ‖ 0x02 ‖ jamId ‖ Gpk, m = PAD(json))`; json `{"id": ≤64, "name": ≤60, "fp"?: b64u(prova dell'amico)}`. La prova c'è solo se l'ospite ha riconosciuto l'host dall'etichetta |
| `CODE` | `0x01` ‖ `0x03` ‖ nonce(24) ‖ `AEAD(KC, ad = "ccj1" ‖ 0x01 ‖ 0x03, m = PAD(json))`; json `{"jam": b64u(jamId), "hpk": b64u(Hpk), "exp": ms, "brokers": [...], "gone": bool}` |
| QR | testo `CCJ1:` + `b64u(0x01 ‖ jamId(6) ‖ T_w(6) ‖ Hpk(32) ‖ etichetta(4) ‖ n(1) ‖ n × (tls(1) ‖ porta(u16be) ‖ lunghezza(1) ‖ host utf8))`, n ≤ 4, il primo è quello in uso; cambia a ogni finestra |
| Codice | 8 caratteri Crockford base32 (`0-9 A-Z` senza `I L O U`) = 40 bit casuali, mostrati `XXXX-XXXX`; in ingresso maiuscole, `O`→`0`, `I`/`L`→`1`, trattini e spazi tolti; lunghezza o caratteri sbagliati → «Codice non valido» senza rete |
| Busta di sessione (≤ 64 KB, RNF-14) | `0x01` ‖ tipo(1) ‖ ctr(`u64be`) ‖ nonce(24) ‖ `AEAD(K_dir, ad = "ccj1" ‖ 0x01 ‖ tipo ‖ ctr ‖ dir, m = PAD(flag(1) ‖ corpo))`; `dir` = `"h2g"` o `"g2h"`; `flag` bit 0 = corpo compresso con `zlib` di `dart:io`; corpo JSON |

Tipi `h2g`: `0x10 ACCEPT` `{host, name, state, brokers, ak, t}` · `0x11 STATE` `{state}` · `0x12 RESULT` `{req, v}` o `{req, err}` · `0x13 PING` `{v, t}` · `0x14 NO` `{why: busy|declined}` · `0x15 BYE` `{why: removed|ended}` · `0x16 TIME` `{t0, t}`. Tipi `g2h`: `0x20 CMD` `{req, cmd}` · `0x21 PING` `{}` · `0x22 SYNC` `{v}` · `0x23 LEAVE` `{}` · `0x24 FRIEND` `{ak}` · `0x25 TIME` `{t0}`. Il contatore parte da 1 per direzione e cresce di 1 a ogni busta; `ACCEPT` o `NO` è la prima `h2g`. Lo stato oltre i 60 KB compressi si manda con titoli, artisti e album tagliati a 64 caratteri, e se non basta senza gli item già suonati (`currentIndex` ricalcolato): l'ospite remoto non applica il reducer, mostra soltanto.

#### Ricezione (R-132, R-134)
Ogni messaggio passa questi controlli in ordine; al primo che fallisce è scartato in silenzio e contato in `JamDropLog` (una riga al minuto con i conteggi per motivo, `AppLog.w`):
1. Dimensione: busta ≤ 65 536 B, `REQUEST` ≤ 2 048 B, `LOBBY` = 34 B.
2. Versione `0x01` e tipo previsto per quel canale e quella direzione.
3. Decifratura AEAD (per `REQUEST` l'host prova `T_w`, `T_(w−1)` e il `KC` del codice valido: tre tentativi al massimo).
4. `ctr` maggiore dell'ultimo accettato (per `REQUEST`: `Gpk` mai visto in questa accensione).
5. `unpad`, decompressione fermata a 512 KB, `jsonDecode`, schema del tipo: `JamCommand.tryParse`, `JamState.tryParse`, interi nei limiti, stringhe ≤ 60/64/200, campi `b64u` della lunghezza giusta.
6. Solo ora: ultimo `ctr` aggiornato, `JamHost.touch`, poi `JamHost.apply(cmd, from: id della coppia)` o lo stato all'ospite (mai una `version` più vecchia).

L'id di un ospite remoto dentro la Jam è quello della coppia, non uno dichiarato nei comandi.

#### Amici
- Si salva `{id, name, ak, fkp, since}`: `ak` = `AK` dell'altro, `fkp` = `FKp` della coppia. L'host manda `AK` in `ACCEPT`, l'ospite in `FRIEND` subito dopo: nessuno dà la sua `AK` prima dell'«Accetta». Un amico già salvato si aggiorna (D-236) solo se l'altro è stato riconosciuto: l'host aggiorna la voce di `id` solo se la richiesta di quella sessione aveva la prova valida; l'ospite solo se l'etichetta ha riconosciuto l'amico con quello stesso `id`. Altrimenti la voce resta intatta (e si logga, senza segreti): un `id` dichiarato non sovrascrive un amico. Gli `id` nuovi si salvano come sempre.
- Riconoscimento: l'ospite calcola l'etichetta di ogni amico salvato e la confronta con l'annuncio o il QR (falso positivo 2⁻³² per amico). L'host segna «Amico» solo se la prova si verifica con la `fkp` dell'id dichiarato: per gli amici l'id è autenticato. La richiesta di un amico non resta dietro a quella di un estraneo: se lo slot unico è occupato da un estraneo, questa scade e l'amico entra (R-144). Se l'accettazione automatica non parte (nessun controller, errore, richiesta ancora in attesa) la richiesta arriva comunque all'utente.
- Rimozione: chi toglie un amico butta la voce e rigenera la sua `AK`, così l'amico tolto non la riconosce più (R-144). Gli altri amici la riconoscono di nuovo alla prossima Jam insieme, quando l'`AK` nuova arriva da sola. Dopo una rotazione di `AK` il recupero avviene alla prossima Jam a ruoli invertiti (chi ha ruotato ospita o entra, e l'altro lo riconosce o ne salva la voce nuova): conseguenza della regola sopra, per cui un `id` non riconosciuto non aggiorna una voce esistente.
- Col codice digitato la prova non c'è: la richiesta arriva senza «Amico».

#### Minacce
| Minaccia | Esito |
|---|---|
| Broker o chi conosce un canale legge | Coperta: tutto è AEAD tranne `Hpk`, intestazioni (versione, tipo, contatore, nonce) e nomi derivati; padding a 256 B |
| Broker modifica, inietta o ripete | Coperta: AEAD con `ad`, contatore, `Gpk` già visto, gettone ≤ 60 s, codice ≤ 2 min |
| Broker nel mezzo dell'ingresso (sostituisce `Hpk` o `Gpk`) | Coperta: `Hpk` controllata con `fpH` (Bluetooth) o intera (QR) o dentro `CODE` cifrato; la richiesta non si decifra senza `P` né la risposta senza `Hsk` (R-131) |
| Broker forza il codice offline | Coperta: Argon2id su 40 bit in 2 min |
| Ospite tolto, bloccato o uscito | Coperta: chiavi della sua coppia buttate, nessuna chiave comune (R-130) |
| Chiavi rubate dopo la Jam | Coperta: chiavi di sessione e `Hsk` solo in memoria, buttate a fine Jam |
| Tracciamento via Bluetooth o broker | Coperta: annuncio che cambia ogni 30 s e a ogni Jam, nessun nome, `clientId` casuale |
| Ogni ospite accettato riceve `AK` e può riconoscere l'host nelle Jam successive finché non è rimosso | Accettato: serve per riconoscersi fra amici; l'etichetta è legata a `fpH` e cambia ogni 30 s, e togliere l'amico rigenera `AK` (R-144) |
| Id di un amico dichiarato da un estraneo | Coperta: la voce si aggiorna solo con la prova dell'amico (host) o l'etichetta riconosciuta (ospite); senza, nessun «Amico», nessuna auto-accettazione, voce intatta |
| Richieste a raffica | Coperta: 10 decifrature/s per la lobby, 2/min per id, 5/min per IP in LAN |
| Telefono rootato o con malware (host o ospite) | Accettata |
| Antenna potente vicino all'host | Accettata: riceve il gettone come un vicino; decide l'«Accetta» dell'host |
| Id del dispositivo dichiarato | Accettata: Sospendi e Blocca si aggirano con un'app modificata; gli amici sono autenticati dalla prova |
| Il broker vede IP, orari, dimensioni arrotondate, numero di ospiti, e può fermare tutto | Accettata: riserva (R-123) |
| Un ospite accettato vede tutta la Jam e può passare il QR per 60 s | Accettata: vale come un vicino, l'host accetta |
| Telefono di un amico rubato con «Accetta gli amici senza chiedere» acceso | Accettata: serve essere vicini; interruttore spento di serie (R-145) |

### Flussi
1. **Accensione del ponte.** `jamBridgeProvider` vede la Jam della cassa (anche «in attesa», D-226) o «Invita chi è vicino» → servizio in primo piano → `JamBridgeHost`: `S`, `Hsk`, `jamId` → `JamBridge` si collega al primo broker che risponde → `LOBBY` retain, iscrizione a `/r` → su Android annuncio Bluetooth (se c'è `bluetoothLeAdvertiser` e il permesso), aggiornato a ogni finestra insieme al QR; il foglio dell'invito crea un codice ogni 2 minuti finché è aperto. Nessun broker risponde → «Broker irraggiungibile» con il collegamento alle impostazioni, e i tentativi continuano; LAN e musica intatte (R-121, R-125, D-232).
2. **Ingresso via Bluetooth.** Ospite in primo piano → `jamNearbyProvider` riceve l'annuncio → riconosce gli amici → banner e riga (se lo stesso `jamId` arriva dalla LAN, resta solo la riga LAN) → tocco → contatore locale → `RemoteJamGuest.join`: broker dall'indice (`0xFF` → «Inquadra il QR») → `LOBBY` entro 5 s, `fpH` controllata → richiesta col gettone più recente ricevuto → iscrizione a `/h` → l'host: decifra, `admitRequest` (gate, «busy» → `NO`) → foglio con «Amico» → «Accetta» → `JamHost.accept` (membro remoto) → `ACCEPT` → l'ospite salva la sua coda (R-90), `FRIEND`, amici salvati da entrambe le parti → `_begin(guest)` come oggi. Nessuna risposta in 60 s → «L'host non ha risposto» (R-150).
3. **Ingresso col codice o col QR.** Codice: Argon2id nell'isolate → la lista dell'ospite, un broker alla volta, 4 s per la `CODE` retain → nessuna: «Codice non valido»; `gone`: «Codice scaduto, chiedi quello nuovo»; altrimenti `Hpk`, `jamId` e broker dell'host → richiesta con `P = KC` come nel flusso 2 (R-140, D-245). QR: come il flusso 2 con `Hpk` intera e i broker dentro il QR, senza `LOBBY`.
4. **Comando dell'ospite remoto.** Tocco → `JamController.send` → `RemoteJamGuest.send` → `CMD{req}` → host: ricezione (§Ricezione) → `JamHost.apply` (il riduttore applica il cancello R-157) → `RESULT{req, v}`; se la `version` cresce, `STATE` a ogni ospite remoto e long-poll ai LAN come oggi (R-120, R-156). Un `add` remoto è sempre un item `yt:`; l'uscita lo scarica da sé (R-151).
5. **Broker che cade e riserva.** Host: connessione persa → un tentativo subito sullo stesso broker, poi uno per volta sui successivi della lista, in giro, con attese 1, 2, 4, 8, 16, 30, 30… s; resta sul primo che risponde, ripubblica `LOBBY`, `CODE`, iscrizioni e `STATE` a tutti, aggiorna l'indice nell'annuncio; nota «Ponte interrotto, riprovo…». Ospite: stessa lista (arrivata con `ACCEPT`) e stesse attese; collegato ma senza messaggi dall'host per 45 s → `SYNC`; nessuna risposta in 5 s → broker successivo. Stesse chiavi e stessi canali su ogni broker: nessun nuovo ingresso (R-123, R-126).
6. **Ospite che perde la rete.** Ospite: «Connessione persa, riprovo…», tentativi del flusso 5, al ritorno `SYNC` → stato più recente. Host: 60 s senza messaggi → «non raggiungibile» accanto al nome; un messaggio valido lo toglie; 10 min → `removeMember` (restano i suoi item `yt:` non suonati) → `BYE`. L'ospite che non sente l'host per 10 min esce con «La Jam è terminata» e ritrova la sua coda (R-126, R-127, R-158).
7. **Fine della Jam.** «Termina» → `endSession` → `STATE` con `ended` a ogni remoto → `jamBridgeProvider` spegne: `LOBBY` e `CODE` svuotate, annuncio fermo, disconnessione, `dispose()` di tutte le chiavi, servizio rilasciato. Un ospite remoto che esce manda `LEAVE` e ritrova la sua coda (R-121, R-158).

### Dati
- `JamParticipant.remote` (JSON `rem`, assente = false). Nessun campo nuovo in `JamItem`, `JamState`, `JamCommand`: i peer vecchi leggono tutto come oggi (R-106). `JamItem.videoId` ora anche sui brani di libreria dell'host col video id noto; `selfFetchable` non cambia.
- `JamRequest` (solo memoria): `remote`, `friend`, `silent`, `ttl`.
- shared_preferences (nel backup): `jamBrokers` (JSON `[{host, port, tls}]`, di serie `kDefaultJamBrokers`), `jamAutoAcceptFriends` (false), `jamNearbyScan` (true; false dopo un rifiuto, R-138), `jamBlePermAsked`.
- `JamSecretStore` (fuori dal backup): `jamAnnounceKey`, `jamFriends`, `jamBlocked` (`[{id, name, at}]`), `jamSuspended` (`[{id, name, until}]`, `until` null = fine Jam, tolte all'avvio e a fine Jam).
- `kDefaultJamBrokers`: `broker.emqx.io:8883` TLS; `test.mosquitto.org:8886` è stato tolto (D-328) prima che l'indice fosse usato dall'annuncio Bluetooth della fase 72. Sulla 8883 Mosquitto usa un certificato della sua CA, che `SecurityContext.defaultContext` rifiuta; la 8886 ha un certificato Let's Encrypt (verificato con `openssl s_client` il 29/10: 8886 ed EMQX 8883 «Verify return code: 0», Mosquitto 8883 «20»; D-258).
- Nessuna tabella drift.

### Invarianti
1. Senza ponte la Jam in LAN non cambia: nessuna connessione MQTT, nessun annuncio, nessun timer nuovo; in `POST /request` cambia solo l'anti-spam (RNF-17).
2. Un'autorità sola: ogni comando, da HTTP o dal ponte, passa da `JamHost.apply` e da `applyCommand`; il reducer non sa da dove arriva (R-120).
3. Un ospite remoto non è mai un'uscita e non possiede file: le uscite non lo contengono e i suoi item sono solo `yt:`: il riduttore rifiuta da un remoto gli item che non lo sono (R-157, D-229).
4. Sul broker non passano in chiaro nomi, titoli, id dei dispositivi né chiavi segrete (R-130, R-133).
5. Ogni messaggio del ponte arriva al reducer o alla UI solo dopo AEAD, contatore e schema; tutto il resto è scartato in silenzio (R-132, R-134).
6. Le chiavi di sessione vivono solo in memoria e si buttano a uscita, rimozione e fine; i segreti persistenti stanno solo in `JamSecretStore` (R-135, D-255).
7. Ponte acceso ⇔ Jam della cassa (anche «in attesa») oppure invito dell'host; una volta acceso durante una Jam da host, il ponte resta acceso fino alla fine della Jam; finita la Jam niente connessione né annuncio (R-121).
8. Si entra solo con una prova recente: gettone ≤ 60 s o codice ≤ 2 min (R-131, R-139).

### Test in memoria
- `FakeBroker` + `FakeMqttLink`: più broker che si accendono e si spengono, `retain`, QoS 1, registro di tutti i byte passati. `FakeJamBeacon` per l'annuncio e la scansione. Orologio iniettato (`DateTime Function() now`) e un `tick()` che nel codice vero chiama il `Timer`; i test spostano l'orologio e chiamano `tick()`, come `dropStale` oggi.
- Protocollo, con `SodiumJamCrypto` vera: vettori noti (RFC 5869 A.1 per HKDF-SHA-256, draft-irtf-cfrg-xchacha-03 A.3.1 per XChaCha20-Poly1305, quelli di libsodium per `kx` e `auth`) e un vettore nostro dell'intero scambio con casualità fissa; gettoni e finestre; annuncio di 26 B; QR andata e ritorno; codice normalizzato; intermediario che sostituisce `Hpk` o `Gpk` → rifiutato; busta ripetuta, contatore vecchio, chiave sbagliata, JSON malformato → scartati con un solo log; stato di 200 item con testi lunghi < 64 KB (R-129…R-136, R-139, R-140).
- Jam mista: `JamHost` + ospite LAN (router come in `jam_edge_test`) + `RemoteJamGuest` su `FakeBroker`: stessa coda e stessa `version`, sesto partecipante `full`, `offerSpeaker` e `setOutput` remoti rifiutati, uscita e rimozione con coda ripristinata, nessun titolo in chiaro nel registro del broker (R-120, R-130, R-151, R-156…R-158).
- `JamBridge`: attese 1, 2, 4… ≤ 30 s, riserva e ospite che segue senza nuovo ingresso, 10 min senza host → uscita (R-123, R-125, R-126); silenzio dell'ospite 60 s / 10 min (R-127).
- `JamGate`: 2/min, Sospendi con riavvio simulato (mappa del `JamSecretStore`), «fine Jam», Blocca e Sblocca; richiesta remota senza risposta che sparisce a 60 s su entrambi i lati (R-147…R-150). Backup senza chiavi degli amici (R-135).
- Widget: richiesta con quattro azioni e «Amico», foglio dell'invito (desktop senza richieste Bluetooth), campo del codice, impostazioni dei broker, banner con scanner finto e app in sottofondo (R-122, R-137, R-138, R-140, R-142, R-146, R-154).

### Dove va il codice nuovo
`lib/services/jam/remote/` per tutto il ponte (protocollo e crittografia puri, link MQTT, bridge, ospite remoto, invito, amici, annuncio, item remoti); `lib/services/jam/jam_gate.dart` e `jam_guest_link.dart` accanto alla Jam di oggi; `lib/data/settings/jam_secret_store.dart`; `lib/providers/jam_remote_providers.dart`; `JamBeaconBridge.kt` accanto agli altri bridge Kotlin. Il resto nei file che esistono già. I test in `test/jam/remote/` e `test/ui/`; `test/jam/` cambia nei test dell'anti-spam, di `admitRequest` tipizzato e degli ospiti remoti.

## Rischi
I rischi che preoccupano di più l'utente (D-260): K-JD-01, K-JD-03, K-JD-04, K-JD-05. Ciascuno ha una prova nei primi passi del piano.

| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale d'allarme |
|---|---|---|---|---|---|
| K-JD-01 | L'estrazione di `JamGuestLink`, `admitRequest` e il cancello nel riduttore rompono la Jam in LAN | M | A | `JamGuest` implementa l'interfaccia senza spostare codice; anti-spam tutto in `admitRequest`; prima i test LAN, poi il ponte (invariante 1) | Un test di `test/jam/` cambia fuori dall'anti-spam |
| K-JD-02 | Jam mista: un remoto con `host` vuoto preso per l'host, proposto come uscita, o item remoti che nessuna uscita scarica | M | A | `rem` nel partecipante, cancello R-157, `jamSelfFetchTargets` aggiornato, simulazione mista in memoria | Nella simulazione un item `yt:` remoto non suona o un remoto compare fra le uscite |
| K-JD-03 | Errore di protocollo: nonce, chiave riusata, contatore, etichetta HKDF | M | A | Un solo file puro, vettori noti e vettore dell'intero scambio, test dell'intermediario e della ripetizione, review Opus del protocollo | Il vettore dello scambio cambia senza che il passo lo dica |
| K-JD-04 | Broker pubblici: certificato non riconosciuto (Mosquitto 8883), limiti o blocchi non documentati, servizio giù | A | A | 8886 per Mosquitto, «Prova connessione» con i due broker veri nel primo passo, riserva, broker personalizzato | «Prova connessione» fallisce su un broker predefinito |
| K-JD-05 | Android in sottofondo: servizio in primo piano non avviabile da sottofondo (Android 12+, apertura della cassa ad app chiusa), Doze che taglia la rete | M | A | Servizio avviato dall'app aperta o mentre suona; eccezione nativa catturata e loggata; prova R-128 a mano | Host in pausa a schermo spento: l'ospite remoto vede «Host non raggiungibile» entro 10 min |
| K-JD-06 | Bluetooth: annuncio non supportato (Mi A3), `neverForLocation` che filtra, posizione spenta su Android ≤ 11, limiti di scansione | A | M | `capabilities` prima di tutto, una sola scansione, ripiego su codice e QR, messaggio sulla posizione | Nella prova a mano il banner non compare a 2 m |
| K-JD-07 | `sodium` compila libsodium con i build hooks: CI più lenta, build Android o Windows che falliscono, `flutter test` senza libreria | M | M | Primo passo: `flutter test`, `build apk` e `build linux` in CI con un solo test dei vettori | CI oltre il tempo o hook fallito |
| K-JD-08 | Argon2id troppo lento o troppa memoria sul Mi A3 | M | M | Isolate, misura nel passo; se supera 2 s, memoria a 32 MiB e `opsLimit` 3 (stessi parametri per host e ospite) | Ingresso col codice oltre 3 s sul Mi A3 |
| K-JD-09 | Stato oltre i 64 KB o cifratura oltre 8 ms sul Mi A3 | B | M | Compressione, taglio dei testi, item suonati tolti; misura RNF-15, isolate se serve | Test dei 200 item rosso o misura oltre 8 ms |

## Fuori perimetro
- Notifica «Unisciti alla Jam di X» con l'app chiusa (scansione in sottofondo) (D-248).
- Modalità «solo vicini» e qualsiasi controllo della distanza dopo l'ingresso: chi si allontana resta nella Jam (D-248).
- Entrare da lontano senza essere stati vicini (canali personali degli amici sul broker), scoperta per posizione GPS (`prossimi-lavori.md`).
- Audio sul ponte, ospiti remoti che suonano, sincronia fra uscite a distanza (fase 10 solo in LAN).
- Bluetooth su Linux e Windows.
- Lettura del QR dalla webcam del PC (R-141, rimandata, D-253).
- Un broker nostro (Worker Cloudflare): la lista dei broker lo permetterà senza cambiare l'app.
