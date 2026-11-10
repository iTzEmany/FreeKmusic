# Fase 69 — Fondamenta (feature «Jam a distanza»)

**Obiettivo:** prima i rilievi della prova 68.3 con la cassa vera (69.1 … 69.4): la Jam della cassa parte anche con la cassa già collegata all'avvio, l'offerta della cassa dell'ospite si vede sopra la schermata della Jam, l'aggiunta a una Jam piena non è più muta, l'host può continuare senza cassa (D-263). Poi la Jam in LAN riceve l'anti-spam (2 richieste al minuto, Sospendi, Blocca) senza cambiare altro, e i due pacchetti nuovi sono provati prima di costruirci sopra: la crittografia coi vettori noti, i broker veri con «Prova connessione». Sono le prove dei rischi K-JD-01, K-JD-03, K-JD-04 e K-JD-07 (D-260).

**Prerequisiti:** fasi 65–68 chiuse; i resti della 68.3 a mano sono la 69.4. Rilievi: esiti della 68.3 in `docs/fase-68-scoperta-e-chiusura-jam.md` §68.3, D-263, R-88 … R-95, R-119, R-121 (il ponte si accende con la Jam della cassa: la 69.1 serve anche alla Jam a distanza). Requisiti R-122, R-129, R-135, R-147 … R-150 (parte LAN), RNF-17; decisioni D-237 … D-239, D-244, D-247, D-251, D-252, D-255, D-258. Aree a rischio: protocollo Jam, primitive crittografiche, manifest e backup. Pacchetti nuovi: solo `sodium` e `mqtt_client` (§Stack di `docs/feature-jam-distanza.md`).

**Comando mirato:** `flutter test test/jam test/ui/speaker_sheets_test.dart test/ui/speaker_banner_test.dart test/ui/app_shell_test.dart test/ui/jam_screen_test.dart test/ui/settings_index_test.dart test/ui/now_playing_test.dart test/data/settings_store_test.dart test/services/backup`; build `flutter build apk --debug` e `flutter build linux --debug` quando entrano i pacchetti (con `sorveglia.sh --pesante`).

## Task

### 69.1 — La Jam della cassa con la cassa già collegata all'avvio (KO 3 della 68.3, R-121)
Con la cassa accesa prima dell'app, `SpeakerJam` chiama `openSpeakerJam` quando `ShareHub` non ha ancora la Jam (`_jam` si imposta dopo l'avvio della scoperta, `share_hub.dart` ~357). `openSpeakerJam` (`jam_providers.dart` ~366) esce in silenzio con `_host` null, ma `SpeakerJam._opened` resta vero e nessuno riprova finché la cassa non si stacca e riattacca. Correzione alla radice: `openSpeakerJam` dice se ha aperto davvero (o lancia), e `SpeakerJam` rimette `_opened` a falso e riprova quando l'hub è pronto. Niente timer di riprova a vuoto.

**Fatto quando:** test in `test/jam/speaker_jam_test.dart`: cassa collegata prima che l'hub sia pronto → la Jam della cassa si apre appena l'hub c'è, una volta sola; staccare e riattaccare la cassa si comporta come prima.

### 69.2 — L'offerta della cassa sopra la schermata della Jam (KO 4, R-119)
`showSpeakerOffer` (`speaker_sheets.dart:55`) usa il contesto della shell (`app_shell.dart:310`): con la schermata della Jam aperta, il foglio «Suonare sulla tua cassa?» resta sotto e si vede solo tornando alla Home. Va mostrato dal navigatore radice, così sta sopra qualunque schermata aperta. Restano gli stessi «mai due volte» e «chiudere con lo swipe vale No».

**Fatto quando:** test widget in `test/ui/speaker_sheets_test.dart` (o `app_shell_test.dart`): con la schermata della Jam aperta, l'offerta arriva e il foglio è visibile e tappabile; «Sì» e «No» come prima.

### 69.3 — Una Jam piena non tace e l'host continua senza cassa (KO 1, D-263)
- **Jam piena (KO 1):** in «Coda insieme» con `maxJamItems` raggiunto e il primo brano in riproduzione (`cur == 0`), il riduttore rifiuta l'aggiunta con `JamError.full` (`jam_state.dart` ~71). `_addTracks` (`jam_providers.dart` ~849) si ferma, ma la UI scrive comunque «Aggiunto in coda». Il riduttore resta com'è (D-194: «insieme» non toglie mai un brano non suonato). Le azioni di aggiunta che oggi mostrano «Aggiunto in coda» con una Jam attiva guardano l'esito: nulla aggiunto per `full` → «La Jam è piena» al posto della conferma, come fa `sendJamCommand` (`speaker_notices.dart`) per `noSpeaker`. Aggiunti solo in parte → il numero vero.
- **Posto per l'aggiunta a mano (KO 1):** il riempimento automatico della coda (feeder, seme dell'host) oggi prende ogni posto che si libera, quindi l'ospite non entra mai. Il feeder si ferma qualche posto prima di `maxJamItems` (costante nuova, ad esempio 10 posti): solo le aggiunte a mano possono arrivare al limite. D-194 resta: nessun brano non suonato viene tolto.
- **Continua sul telefono (D-263):** accanto a «Collega una cassa» (`SpeakerAwayNotice`, `speaker_notices.dart` ~95) l'host vede «Continua sul telefono». Un comando nuovo del riduttore, solo per l'host, toglie l'attesa (`speakerAwaySince`) e fa della Jam una Jam normale (`speaker` falso): l'uscita è il suo telefono, la fine dopo 10 minuti si annulla, i comandi bloccati in attesa ripartono. La cassa che torna dopo non riapre la Jam della cassa: questa Jam resta sul telefono (scelta di esecuzione, si scrive in `docs/decisioni.md`). L'ospite non ha il pulsante.
- Stringhe ARB it/en/de/es («La Jam è piena», «Continua sul telefono» e la sua etichetta di accessibilità).

**Fatto quando:** test del riduttore in `test/jam/jam_state_test.dart` (comando dell'host accettato, dell'ospite `forbidden`, fuori attesa `invalid`, dopo il comando `play` passa); test del feeder che lascia i posti liberi e dell'aggiunta a mano che li prende; test widget dell'avviso con il pulsante solo per l'host e del messaggio «La Jam è piena» su un'aggiunta rifiutata.

### 69.4 — Prova a mano dei rilievi e resti della 68.3 (utente, D-224)
Motorola host con le JBL, Mi A3 ospite, hotspot del Motorola. Da provare:
- le JBL accese prima di aprire l'app → la Jam della cassa parte da sola (69.1);
- l'offerta R-119 con la Jam aperta sull'ospite → il foglio compare subito sopra (69.2);
- una Jam piena in «Coda insieme» → «La Jam è piena» (69.3);
- cassa spenta, «Continua sul telefono» → suona dall'altoparlante del Motorola (D-263);
- i resti della 68.3: R-88 … R-95 e il brano suggerito.

Esiti qui sotto, uno per riga; KO nuovi → righe in `docs/action-plan.md`.

**Esiti (29/10, in autonomia per D-274: Motorola host sul suo hotspot, Mi A3 ospite, cuffie JBL Tune 720BT come cassa)**
- **69.1 OK**: con le cuffie già collegate al Motorola prima dell'avvio, la Jam della cassa si apre da sola, l'ospite la vede e ci entra, e suona sulle cuffie.
- **69.2 OK**: a ruoli scambiati, le cuffie staccate dal Mi A3 e passate al Motorola fanno comparire «Suonare la Jam sulla tua cassa?» sopra la schermata Jam. Con «Sì», «Collega una cassa» sparisce su entrambi. Non provato: il collegamento nell'istante in cui l'app è in primo piano.
- **69.3 Jam piena OK**: Jam di 200 brani in «Coda insieme».
  - L'aggiunta dell'ospite dice «La Jam è piena», mai un «Aggiunto in coda» falso.
  - Con 5 posti liberati dall'host, 2 aggiunte entrano e poi torna «piena».
- **69.3 «Continua sul telefono» OK**:
  - a cuffie scollegate l'host vede il pulsante, l'ospite solo «Collega una cassa»;
  - toccato il pulsante, la Jam riparte senza altre uscite collegate.
- **R-88 OK**: le aggiunte dell'ospite vanno in fila dopo il corrente e dopo le aggiunte precedenti.
- **R-95 OK**: «Precedente» subito dopo «Successivo» torna al brano di prima.
- **R-90 OK**: l'ospite che esce ritrova la sua coda, in pausa.
- **KO D-266**: l'ospite che esce non vede «Sei uscito dalla Jam», nemmeno in due uscite.
  - Causa: l'host lo toglie su `/leave` e il long poll riceve 401 prima della fine di `leave()`, così vince «Jam persa».
  - Corretto in 8360dc2 (`end()` smette di ascoltare `lost` prima di `leave()`), con un test di regressione.
  - Riprovato sul Mi A3 con l'host Linux: «Sei uscito dalla Jam» in due uscite su due, e la Jam dell'host resta aperta.
- Il multipunto delle cuffie le fa passare da un telefono all'altro da sole. Al primo avvio il Mi A3 apriva anche una sua Jam della cassa.
- La scoperta sull'hotspot è lenta: da 20 a 100 s. Il foglio «Dispositivi» non si aggiorna da solo, va chiuso e riaperto.
- **Non provati, restano a mano**:
  - R-89 (swipe di un brano online);
  - R-91;
  - R-92 (copertine);
  - R-93 («Scarica»);
  - lo scarto;
  - il brano suggerito di «Coda insieme»;
  - l'aggiunta che entra nei 20 posti di una Jam nata corta.

**Esiti dei resti (30/10, in autonomia: Mi A3 host, Motorola ospite, hotspot del Motorola, cuffie JBL su entrambi)**
- **R-89 OK**: lo swipe «in coda» dell'ospite su una riga online della Ricerca porta il brano nella Jam dell'host.
- **R-92 OK**: l'ospite vede la miniatura dei brani online e la copertina di libreria (da `/cover`) dei brani dell'host.
- **R-93 OK nel player normale**: «Scarica» dal ⋮ su un brano online. Il brano entra in libreria e alla riapertura «Scarica» non c'è più.
  - La sparizione a foglio aperto non si è vista, perché il download è finito in meno di 1 s.
  - La schermata Jam non ha un ⋮ e non offre «Scarica». **Deciso dall'utente (30/10)**: il ⋮ con «Scarica» ci deve essere anche lì (da fare).
- **R-91 OK**: l'ospite aggiunge due brani online e poi esce. I brani restano nella Jam dell'host, che li suona da sé.
- **R-102 OK**: a parte finita, l'host riceve brani «Suggerito» dalla sua libreria.
- **Jam nata corta OK**: con 6 brani dell'host, le aggiunte a mano dell'ospite entrano finché c'è posto, poi compare «La Jam è piena», senza falsi «Aggiunto». Il tetto esatto di 180 non è stato contato.
- **KO R-102**: con la Jam piena, il «Suggerito» ripropone brani già suonati nella Jam (premuto «Successivo» 30–40 volte, sono tornati «Look At Me» e i brani Mi-1…Mi-6). Probabilmente i brani scartati dalla Jam piena escono dall'insieme degli esclusi (`jam_suggestion.dart`).
- **Da verificare**:
  - dopo l'uscita dalla Jam il Motorola è tornato da «Casuale+» a «Casuale» (l'utente chiede di verificarlo: con un test che lo riproduce, poi sul telefono);
  - un'aggiunta da una riga YouTube Music a Jam piena ha detto «Aggiunto in coda» ma non è rimasta (una volta, non riprodotta).
- **Nota**: l'ospite che esce da «Coda insieme» ritrova la sua parte non suonata (D-186), aggiunte comprese. La coda di prima della Jam è salvata solo in memoria.

**Fatto quando:** esiti scritti; 67.1, 67.2 e 68.3 in `docs/PROGRESS.md` da `[~]` a `[x]` se non ci sono KO.

### 69.5 — `JamGuestLink` senza spostare codice (RNF-17, K-JD-01)
`lib/services/jam/jam_guest_link.dart`: l'interfaccia di §Componenti (`states`, `lost`, `state`, `send`, `probeHostTime`, `invite`, `leave`, `cancelJoin`, `dispose`, `sessionId`/`hostBase`/`fileToken`). `JamGuest` la implementa; in `JamController` `_guest` diventa `JamGuestLink?`. Nessun comportamento cambia.

**Fatto quando:** `git diff origin/master -- test/jam` vuoto e comando mirato verde; `flutter analyze` pulito.

### 69.6 — `admitRequest` e `JamGate` (R-147 … R-150, D-238, D-239)
La validazione di `POST /request` passa in `JamHost.admitRequest(...)`, che il router chiama come oggi (il limite di 5/min per IP resta nel router). `lib/services/jam/jam_gate.dart`, puro con orologio iniettato: 2 richieste al minuto per id (finestra scorrevole, oltre → 429), Sospendi con scadenza o «fine Jam», Blocca e Sblocca. Sospeso o bloccato → richiesta `silent` (202, mai mostrata, non conta per «busy», scade a `jamRequestTtl`). `lib/data/settings/jam_secret_store.dart` (interfaccia chiave–valore su `SharedPreferencesAsync`, mappa nei test) con `jamBlocked` e `jamSuspended`; le sospensioni «fine Jam» si tolgono all'avvio e a fine Jam. Esclusione dal backup Android del file DataStore con `backup_rules.xml` e `data_extraction_rules.xml`.

**Fatto quando:** test con orologio finto di 2/min (terza scartata, dopo 60 s di nuovo accettata), Sospendi 15 min (scartate; a 15 min + 1 s accettate; riavvio simulato con la stessa mappa), «fine Jam», Blocca/Sblocca dopo il riavvio; test che `settingsToJson` non contiene le chiavi del `JamSecretStore`; gli altri test di `test/jam` invariati.

### 69.7 — Sospendi, Blocca e l'avviso dell'ospite (R-147 … R-149, D-237)
`lib/ui/widgets/duration_choice_sheet.dart`: `showDurationChoiceSheet` estratto da `_showSleepSheet` (`now_playing_controls.dart`), usato dal timer e da Sospendi (15, 30, 45, 60 min, «Fino alla fine della Jam»). `jam_request_dialog.dart`: Accetta, Rifiuta, Sospendi, Blocca. Impostazioni della Jam: «Dispositivi bloccati» con «Sblocca» e «Sospesi» con la scadenza. `JamController.request`: contatore locale, alla terza richiesta in 60 s «Aspetta un momento prima di riprovare» senza inviarla. Stringhe ARB it/en/de/es.

**Fatto quando:** test widget del foglio di durata nei due usi (il timer di spegnimento si comporta come prima), del dialogo con quattro azioni, delle liste nelle impostazioni e dell'avviso dell'ospite; `settings_index_test` aggiornato.

### 69.8 — `sodium` nella build e vettori noti (R-135, K-JD-03, K-JD-07)
`sodium` ^4.1.2 nel pubspec; `lib/services/jam/remote/jam_crypto.dart`: `JamCrypto` e `SodiumJamCrypto` con le sole primitive di §Componenti, inizializzate con `SodiumSumoInit.init()`, casualità iniettabile. Ancora nessun uso nell'app.

**Fatto quando:** `test/jam/remote/jam_crypto_test.dart` verde con i vettori di RFC 5869 A.1 (HKDF-SHA-256), draft-irtf-cfrg-xchacha-03 A.3.1 (XChaCha20-Poly1305), libsodium per `kx` e `auth`, più un andata e ritorno di `pad`/`unpad`; `flutter build apk --debug` e `flutter build linux --debug` verdi in locale; la CI della PR verde con i tempi annotati nel documento di fase (anche le build Windows e macOS, se girano sulla PR). Hook fallito o CI oltre il doppio dei tempi di oggi → fermati e scrivilo in «Tocca a te» (K-JD-07).

**Esiti (29/10):** `jam_crypto_test.dart` 6 test verdi in 5 s (22 s la prima volta, hook libsodium compreso); `flutter build apk --debug` 3m26s (compila libsodium); `flutter build linux --debug` 1m00s. Vettore HKDF: PRK di RFC 5869 A.1 (l'`info` 0xf0… non è una `String` valida: `expand` prende `context` come testo), OKM da A.3 (info vuota).

### 69.9 — Broker e «Prova connessione» (R-122, R-129, D-244, D-251, D-258, K-JD-04)
`mqtt_client` ^10.14.0. `lib/services/jam/remote/mqtt_link.dart`: `MqttLink` e `MqttClientLink` come in §Componenti (TLS con `SecurityContext.defaultContext`, `onBadCertificate` null, `autoReconnect` false, `clientId` casuale). `BrokerEntry` (host, porta, TLS) e `jamBrokers` in shared_preferences con `kDefaultJamBrokers`. `lib/ui/screens/settings/jam_remote_settings.dart`: lista dei broker (aggiungi, togli, riordina, «Ripristina»), avviso per una voce senza TLS, «Prova connessione» (connessione, iscrizione e pubblicazione su un canale casuale, ritorno del messaggio entro 5 s).

**Fatto quando:** test della validazione (host non vuoto, porta 1–65535), test widget di aggiunta, riordino, ripristino, avviso senza TLS e «Prova» con un `FakeMqttLink` riuscito e fallito; `test/live/jam_broker_live_test.dart` (si salta da sé senza `CODECORE_LIVE=1`, come gli altri di `test/live/`) eseguito una volta in locale: `broker.emqx.io:8883` e `test.mosquitto.org:8886` riusciti, `test.mosquitto.org:8883` rifiutato per il certificato (R-129); esiti con la data in questo documento.

Esiti (29/10): `broker.emqx.io:8883` riuscito (connessione, iscrizione, pubblicazione e ritorno del messaggio); `test.mosquitto.org:8883` rifiutato per il certificato (`CERTIFICATE_VERIFY_FAILED`, R-129); `test.mosquitto.org:8886` **fallito** in due giri: il TLS si stabilisce (`openssl` e `SecureSocket` ok) ma il server chiude la connessione subito dopo il CONNECT MQTT (verificato anche con un CONNECT scritto a mano in Python, con altri clientId), quindi nessun messaggio torna (K-JD-04). Terzo giro alle 18:02, dopo le correzioni della scheggia: emqx riuscito, mosquitto 8883 rifiutato come atteso, 8886 ancora chiuso dopo il CONNECT. La lista predefinita resta quella di D-258: decide l'utente se toglierlo.

### 69.10 — Controlli di fase
`flutter analyze`, comando mirato, build di debug, `/code-review high` su 69.3 (comando nuovo del protocollo Jam), 69.6 e 69.8, scheggia in modalità passo su 69.1 (apertura della Jam della cassa), 69.6 (gate) e 69.9 (validazione dei broker), review di architettura Opus di `JamGuestLink` e `admitRequest`. Prova sul Mi A3 col Linux in LAN (D-91): richieste ripetute, Sospendi 15 min, Blocca e Sblocca.

**Fatto quando:** tutto verde; esiti della prova qui sotto; colonna Fase di R-147 … R-149 e RNF-17 compilata.

**Esiti (29/10)**
- `flutter analyze` pulito; test mirati verdi; build apk e linux di debug riuscite.
- Review Opus fatte su 69.3, 69.6, 69.7, 69.8 e 69.9. Scheggia passo su 69.1, 69.6 e 69.9: 5 bug corretti.
- Review di architettura della fase: 3 correzioni subito (c3b86e3). Gli altri rilievi stanno in D-272, D-273 e in `docs/fase-70-ponte-jam-distanza.md` §Rilievi dalla fase 69.

Prova in LAN, con l'host sull'app Linux (schermo virtuale) e il Mi A3 come ospite:
- **Richieste ripetute**: OK. Alla terza richiesta in pochi secondi il telefono dice «Aspetta un momento prima di riprovare» e sull'host non compare nessun dialogo.
- **Sospendi 15 min**: OK.
  - La scelta è fra 15, 30, 45 e 60. «Fino alla fine della Jam» non c'è, perché nessuna Jam era attiva.
  - Il telefono riceve un rifiuto normale.
  - Le richieste successive non arrivano all'host. Il telefono resta in attesa fino alla scadenza (D-238).
  - In «Rete e dispositivi» compare «Sospesi».
- **Blocca e Sblocca**: OK.
  - Bloccato: nessuna richiesta arriva e compare «Dispositivi bloccati».
  - Sbloccato: la richiesta torna ad arrivare.
  - Anche Sblocca dalla lista dei sospesi funziona.
- La pagina «Jam a distanza» è stata vista senza premere «Prova connessione».
- La scoperta funziona solo finché sull'host è aperto il foglio dei dispositivi (visibilità temporanea, come prima).
- **Restano a mano**: «Fino alla fine della Jam» durante una Jam vera (e la sua scomparsa al riavvio), e la scadenza dei 15 minuti.
