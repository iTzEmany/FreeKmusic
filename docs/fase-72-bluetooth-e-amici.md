# Fase 72 — Bluetooth e amici (feature «Jam a distanza»)

**Obiettivo:** su Android chi è vicino trova la Jam da solo via Bluetooth e ci entra con un tocco; gli amici si riconoscono col nome salvato. Il Bluetooth dice solo «qui c'è una Jam»: niente messaggi, connessioni o controlli della distanza (D-248).

**Prerequisiti:** fase 70 chiusa (la 71 non serve). Requisiti R-136 … R-138, R-143 … R-145, RNF-16; decisioni D-233, D-234, D-236, D-248, D-254, D-256, D-259. Aree a rischio: lato nativo Bluetooth e permessi del manifest, protocollo di sicurezza (annuncio, etichetta degli amici), `JamSecretStore`. Nessun pacchetto nuovo.

**Comando mirato:** `flutter test test/jam test/ui/app_shell_test.dart test/ui/jam_screen_test.dart test/ui/settings_index_test.dart test/services/share`; build `flutter build apk --debug` per il lato nativo (con `sorveglia.sh --pesante`).

## Rilievi dalla fase 71 (review di architettura, da fare dentro i task sotto o in un passo a parte)
- Host e ospiti LAN non vedono testo e curiosità dei brani di un ospite remoto (`_remoteUri` è null senza `owner.host`): in `fetchMeta`, con uri null usare `_remoteMeta` al posto del controllo `state.remote`.
- `JamController` cresce (lyrics chain, curiosity service, cache `_remoteMetas`): estrarre un `JamRemoteMeta` in `lib/services/jam/remote/` con le ricerche iniettate; il `Track` sintetico di `_remoteMeta` e `_syntheticTrack` di `stream_providers.dart` in un costruttore condiviso.
- Ciclo di import residuo `jam_providers` ↔ `jam_remote_providers` (`jamCryptoProvider`, `remoteJamGuestFactoryProvider`): spostarli in `jam_broker_providers.dart`.

## Task

### 72.1 — `JamBeaconBridge.kt` e permessi (R-136, R-138, D-234, D-254, K-JD-06)
Canale `codecore/jam_beacon` in un file suo come gli altri bridge, registrato in `MainActivity.kt`: `capabilities` (annuncio supportato, posizione spenta su Android ≤ 11), permessi e richiesta, annuncio come in §Componenti (`startAdvertisingSet`, legacy, non connettibile, solo service data su `0xC0DE`, niente nome; sotto l'API 26 stop e start), scansione con `ScanFilter` sull'UUID e `SCAN_MODE_LOW_POWER`, una sola. Manifest: `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_ADVERTISE`, `ACCESS_FINE_LOCATION` con `maxSdkVersion 30`. Senza permesso o supporto: risposte vuote, mai eccezioni.

**Fatto quando:** test del lato Dart con un finto `MethodChannel`; build di debug verde; sul Mi A3 `capabilities` letto e annotato qui sotto (se non annuncia, l'host Mi A3 vale solo per codice/QR).

### 72.2 — Annuncio dell'host e Jam vicine (R-136, R-137, RNF-16, D-233)
`lib/services/jam/remote/jam_beacon.dart` e il pacchetto di 26 B di `JamProtocol`, aggiornato a ogni finestra col QR. `jamNearbyProvider`: scansione solo in primo piano (`AppLifecycleListener`), senza Jam in corso e col permesso; voci tolte dopo 90 s senza pacchetti. Banner «Unisciti alla Jam di X» e riga in «Dispositivi» come R-112; indice `0xFF` → «Inquadra il QR». Col ponte acceso il pacchetto LAN porta `jam.rid` = jamId: sulla stessa rete resta solo la riga LAN e l'ospite entra in LAN. Fogli dei permessi con la riga di spiegazione; rifiuto → `jamNearbyScan` false e solo codice/QR, riattivabile dalle impostazioni («Cerca Jam vicine»).

**Fatto quando:** test con `FakeJamBeacon`: annuncio → banner e riga; app in sottofondo → scanner fermo; stesso jamId dalla LAN → una sola riga; due Jam dello stesso host → pacchetti senza parti in comune (R-133); test widget dei fogli dei permessi (Android 12+ e ≤ 11) e del rifiuto.

### 72.3 — Amici della Jam (R-143 … R-145, D-236, D-259)
`lib/services/jam/remote/jam_friends.dart` su `JamSecretStore` (`jamAnnounceKey`, `jamFriends`): dopo il primo ingresso accettato `FRIEND` e salvataggio reciproco; etichetta nell'annuncio e prova dell'amico nella richiesta (§Derivazioni); amici col nome salvato e in cima al banner, alla lista e alle richieste («Amico»); lista «Amici della Jam» con rimozione, che rigenera `AK`; interruttore «Accetta gli amici senza chiedere», spento di serie. `trustedDevices` non cambia.

**Fatto quando:** test: accetta → entrambi salvati; amico riconosciuto con gettoni diversi, estraneo no, amico rimosso no; interruttore acceso → richiesta dell'amico accettata senza foglio, spento → foglio; `trustedDevices` invariato; backup senza `jamFriends` né `jamAnnounceKey`.

### 72.4 — Controlli di fase
`flutter analyze`, comando mirato, build di debug, `/code-review high` sul lato nativo, sul manifest e su 72.3, scheggia in modalità passo su 72.2, review Opus. Prova sul Mi A3 (Android 11): permesso della posizione rifiutato e poi riattivato, posizione spenta → messaggio; `capabilities` del Mi A3. Linux non annuncia (R-146): l'ingresso via Bluetooth fra due telefoni si prova nella 73.2.

**Fatto quando:** tutto verde; esiti qui sotto; colonna Fase di R-136 … R-138, R-143 … R-145 e RNF-16 compilata.
