# Fase 70 — Ponte e protocollo (feature «Jam a distanza»)

**Obiettivo:** host e ospite su reti diverse fanno una Jam via broker MQTT, cifrata da capo a capo: l'ospite entra col codice o col QR (Bluetooth nella fase 72), comanda come un ospite LAN e regge cadute del broker, della rete e il sottofondo. Le aggiunte alla coda da ospite remoto arrivano nella fase 71: fino ad allora l'ospite remoto non ha «Aggiungi».

**Prerequisiti:** fasi 69, 69a e 69b chiuse. Requisiti R-120 … R-134, R-139, R-140, R-142, R-146, R-150 (parte remota), R-156 … R-158, RNF-14; decisioni D-229 … D-232, D-235, D-242 … D-247, D-250, D-257, D-259. Aree a rischio: protocollo Jam, protocollo di sicurezza (`lib/services/jam/remote/`), servizio in primo piano. Tutto il §Protocollo di sicurezza di `docs/feature-jam-distanza.md` vale alla lettera: un cambio di formula o di etichetta è una decisione nuova.

**Comando mirato:** `flutter test test/jam test/ui/jam_screen_test.dart test/ui/settings_index_test.dart`; build `flutter build apk --debug` quando si tocca il servizio (con `sorveglia.sh --pesante`).

## Rilievi dalla fase 69 (review di architettura, da fare dentro i task sotto)
- **70.1, primo passo**: in `JamCrypto` le chiavi sono tipi di `sodium` (`SecureKey`, `KeyPair`, `SessionKeys`). `JamProtocol` le prende così come sono e un cambio di libreria tocca anche l'interfaccia (D-272).
- **70.2**: `MqttLink.messages` è legato al singolo client, quindi va spostato su un controller broadcast del link. Serve anche un segnale di disconnessione (`onDisconnected` → stream), per passare a `retrying` e al broker di riserva. `testBroker` passa da `jam_broker_providers.dart` a `lib/services/jam/remote/`, così `JamBridge` lo riusa.
- **70.3/70.4**:
  - `admitRequest` restituisce una `Response` di shelf e vuole `port` e `token` della LAN. Va cambiata così: risultato tipizzato (accettata / full / busy / tooMany / bad) e parametri tipizzati (`id`, `name`, `port?`, `token?`, `remote`, `ttl`), con il router che converte il risultato in `Response`.
  - Sul ponte `gate.allow` va prima di full e busy: ogni «NO busy» costa una cifratura e una pubblicazione.
- **70.4**:
  - Estrarre `_attach(JamGuestLink)` da `JamController.request`, cioè la parte che collega `lost`, `states`, contatore e rilascio, perché `requestRemote` la riusi. `guestFactory` deve restituire `JamGuestLink`.
  - Il contatore delle richieste va condiviso con `requestRemote`.
  - In `JamGuestLink`, `sessionId`/`hostBase`/`fileToken` diventano un solo valore nullable («accesso ai file dell'host»), invece del `sessionId` null usato come interruttore. Si aggiunge lo stato del collegamento (`JamUiState.link`).
- **Ordine sparso, bassa priorità**:
  - la regola «coda piena» è scritta tre volte (`JamController.queueFull`, `jamAutoFillFull`, riduttore): serve un predicato unico accanto al riduttore;
  - `jamGateProvider` e `jamSecretStoreProvider` servono anche alla LAN ma stanno in `jam_remote_providers.dart`;
  - `pwhash` in un isolate non ha un test che ne controlli il risultato.

## Task

### 70.1 — `JamProtocol` (R-130 … R-134, R-139, R-140, RNF-14, K-JD-03, K-JD-08)
`lib/services/jam/remote/jam_protocol.dart`, puro: derivazioni, gettone e finestre, impronta, QR, codice (Argon2id in un isolate, D-257), lobby, richiesta, busta con contatore, padding, compressione, limiti, ordine di ricezione (dimensione → versione e tipo → AEAD → contatore → schema). Nessun I/O.

**Fatto quando:** test di §Test in memoria «Protocollo» con `SodiumJamCrypto` vera: vettore dell'intero scambio con casualità fissa, gettone dentro e fuori dai 60 s, intermediario che sostituisce `Hpk` o `Gpk` → rifiutato, busta ripetuta, contatore vecchio, chiave sbagliata e JSON malformato → scartati con un solo log al minuto, QR andata e ritorno, codice normalizzato, stato di 200 item con testi lunghi < 64 KB. Misura dell'Argon2id sul Mi A3 annotata qui sotto (oltre 2 s → parametri di K-JD-08). Review Opus del solo protocollo prima del passo dopo.

**Note 70.1 (fatte).**
- `JamCrypto` non espone più tipi di `sodium`: `JamKey` (byte, `dispose()` li azzera), `JamKeyPair`, `JamSessionKeys`. Dentro `SodiumJamCrypto` ogni chiave passa in memoria di libsodium solo per la durata della chiamata.
- `JamProtocol` (con `JamDropLog`, `JamChannel`, `JamHostSecrets`) sta in `jam_protocol.dart`. Scelte dove la specifica tace: `CODE` ≤ 2 048 B; `Gpk` segnato come visto solo dopo AEAD e schema validi; il log degli scarti scrive subito al primo scarto e poi al massimo una riga al minuto, senza timer; stato oltre 60 KB compressi: testi a 64 caratteri, poi via gli item già suonati.
- Il vettore dell'intero scambio (`kVector` nel test) è fissato dal codice stesso con casualità fissa: serve a vedere cambiamenti involontari, non è un vettore esterno.
- Dopo la review del commit 4997edd: `JamKey` dopo `dispose()` lancia `StateError` a ogni uso dei byte (anche `JamChannel.seal/open`, `token`, `openRequest`); `JamKey.adopt` prende possesso del buffer. Chi codifica limita i broker a `JamWire.maxBrokers` = 4 (QR, CODE, ACCEPT via `JamProtocol.brokersJson`); nel QR un host oltre 255 B UTF-8 è saltato, non troncato. `ACCEPT` espone `JamMessage.brokers` già validati. `parseLobby` richiede l'impronta di `Hpk` (`fpH`), `openCode` rifiuta un `exp` passato (`nowMs`), `fitState` dà null se lo stato non entra nemmeno ridotto.
- **Argon2id sul Mi A3: non misurato.** La build di prova (`integration_test`) è arrivata sul telefono ma lo schermo era bloccato e il test non è partito; sbloccare a mano e rilanciare, oppure misurare nella prova 70.6. Se sul Mi A3 supera 2 s si applicano i parametri di K-JD-08 (32 MiB, `opsLimit` 3).

### 70.2 — `JamBridge` e riserva (R-123, R-125, R-126, D-244, D-246)
`lib/services/jam/remote/jam_bridge.dart` su `MqttLink`: lista ordinata di `BrokerEntry`, tentativi del flusso 5 (subito lo stesso, poi i successivi in giro, attese 1, 2, 4, 8, 16, 30 s), iscrizioni rifatte, `status`. `FakeBroker` e `FakeMqttLink` in `test/jam/remote/fakes.dart` (più broker, `retain`, registro dei byte).

**Fatto quando:** test con orologio finto: attese ≤ 30 s, primo broker giù → secondo, nessuno → `unreachable` e tentativi che continuano, ritorno → iscrizioni rifatte.

### 70.3 — Ospiti remoti in `JamHost` (R-120, R-127, R-150, R-156, R-157, K-JD-02)
`JamParticipant.remote` (JSON `rem`), `addMember(..., remote: true)`, cancello in `apply` (`offerSpeaker` da un remoto, `setOutput`/`setOutputs` verso un remoto → `JamError.forbidden`), `dropStale` a 10 min per i remoti e `unreachableIds(60 s)`, `touch(id)`, `JamRequest.remote/.friend/.silent/.ttl` (60 s remoto). `jamSelfFetchTargets` include gli item dei partecipanti remoti.

**Fatto quando:** test del reducer e dell'host per ogni punto, con orologio finto per 60 s e 10 min; i test LAN di oggi invariati.

**Note 70.3:** `expire()` notifica quando una richiesta scade o sparisce e lo chiama anche il timer `_alive` da 10 s (R-150). `addMember` su un id già dentro con `remote` diverso lo sostituisce (token nuovo, flag giusto, ripubblica; K-JD-02). `ttl` di serie 60 s se remota, `jamRequestTtl` se LAN. `_tokenOk` rifiuta un token atteso vuoto (richieste remote). Il cancello `gate.allow` prima di full/busy vale anche in LAN: l'ospite LAN mappa 409 e 429 entrambi su busy.

### 70.4 — `JamBridgeHost` e `RemoteJamGuest` (R-120, R-124, R-126, R-127, R-130 … R-132, R-142, R-150, R-156, R-158)
`jam_bridge_host.dart`, `remote_jam_guest.dart` e `jam_invite.dart` come in §Componenti e nei flussi 3–7: lobby e codice `retain`, richieste (al massimo 10 decifrature al secondo, `Gpk` ripetuti scartati), `ACCEPT`/`NO`/`STATE`/`RESULT`/`PING`/`SYNC`/`BYE`/`LEAVE`, chiavi per coppia buttate a uscita, rimozione, blocco e fine. `JamJoinOutcome` con `codeInvalid`, `codeExpired`, `customBroker`, `tooSoon`.

**Fatto quando:** simulazione mista di §Test in memoria verde (host + ospite LAN + ospite remoto su `FakeBroker`: stessa coda e `version`, sesto `full`, uscita e rimozione con coda ripristinata, nessun nome, titolo o id in chiaro nel registro del broker, ospite tolto che non decifra più); broker che cade a metà → ospite che segue senza nuovo ingresso; richiesta senza risposta che sparisce a 60 s sui due lati; codice sbagliato e scaduto.

### 70.5 — Accensione, servizio e fogli (R-121, R-125, R-128, R-140, R-142, R-146, D-232, D-243, K-JD-05)
`lib/providers/jam_remote_providers.dart`: `jamBridgeProvider` (acceso ⇔ Jam della cassa, anche «in attesa», oppure «Invita chi è vicino»), `jamGateProvider`, `jamCryptoProvider`, `remoteJamGuestFactoryProvider`. `JamController.requestRemote`, `JamUiState.remote` e `link`. `ShareHubNotifier.holdJam(remote: true)` con «Jam a distanza attiva · Termina», avvio dall'app aperta, eccezione nativa catturata e loggata. UI: foglio «Invita chi è vicino» (stato del ponte, QR che ruota, codice `XXXX-XXXX` col tempo che resta), «Entra con un codice» (campo su tutte le piattaforme, scanner QR solo su Android con `mobile_scanner`), richiesta remota col foglio di 69.3 chiusa a 60 s, note «Ponte interrotto, riprovo…», «Host non raggiungibile, riprovo…», «Broker irraggiungibile», segno «non raggiungibile» nel roster. Stringhe ARB.

**Fatto quando:** test: Jam normale → nessuna connessione; pulsante → connessione; Jam della cassa → automatico; fine → ponte spento e chiavi buttate; test del canale del servizio (avvio e arresto col ponte); test widget del foglio dell'invito (desktop senza richieste Bluetooth), del campo con codice sbagliato e scaduto, delle note.

### 70.6 — Controlli di fase
`flutter analyze`, comando mirato, build di debug, `/code-review high` su 70.1, 70.3 e 70.4, scheggia in modalità passo su 70.1 (buste e richieste assurde) e 70.4, review di architettura Opus. Prova in autonomia sul broker predefinito: Linux host in `xvfb-run`, Mi A3 ospite col codice (D-91: solo fra i dispositivi di prova); host Mi A3 in pausa a schermo spento 10 min con Linux ospite che rimette play (R-128).

**Fatto quando:** tutto verde; esiti della prova qui sotto; colonna Fase di R-120 … R-134, R-139, R-140, R-142, R-146, R-150, R-156 … R-158 e RNF-14 compilata.
