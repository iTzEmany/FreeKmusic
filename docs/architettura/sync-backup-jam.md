# Sync, backup e Jam

## Scopo
Tutto ciò che parla con altri dispositivi o esce dal dispositivo: condivisione in LAN, abbinamento dei dispositivi fidati, sync delle playlist, backup/ripristino/export e le tre forme della Jam (locale, della cassa, a distanza). Questo documento dice dove sta il codice, quali regole non si rompono e quali stringhe di protocollo devono restare com'erano.

## Mappa del codice

### Condivisione in LAN e dispositivi fidati (`lib/services/share/`)
| File | Simbolo | Ruolo |
|---|---|---|
| `discovery.dart` | `LanDiscovery`, `Peer`, `discoveryMagic`, `discoveryPort` | Beacon UDP in broadcast, senza segreti. Solo mittenti di rete locale. |
| `net_prefix.dart` | | Prefisso reale della sottorete (broadcast diretto). Su Android lo legge `MainActivity` via canale `codecore/audio` (D-227). |
| `lan_server.dart` | `LanServer`, `LanGuard`, `ShareEntry`, `parseRange` | Condivisione con PIN: il client vede solo `id`, il `path` resta sul server. Supporta `Range`. |
| `lan_client.dart` | `LanClient`, `LanError`, `RemoteTrack` | Client della condivisione. Ha anche `secureGet`/`securePost` con impronta fissata. |
| `offers.dart` | `OfferService`, `IncomingOffer`, `OutgoingOffer`, `OfferStatus` | Offerte di brani («ti mando questi»), fino a `maxOfferItems`, scadenza `offerTtl`. |
| `offer_node.dart` | `OfferNode` | Unico endpoint del dispositivo: HTTP (`/hello`, `/offer`, `/jam`) e, con un'identità, HTTPS (`/pair`, `/sync`). Filtro `_localOnly` e `_signedCaller`. |
| `device_identity.dart` | `DeviceIdentity` | Certificato EC P-256 autofirmato, generato una volta. L'impronta SHA-256 è ciò che l'altro ricorda. |
| `pairing.dart` | `PairingServer`, `PairRequest`, `PairState` | Lato che mostra il PIN. Tre passi: `/pair/request`, `/pair/confirm`, `/pair/status`. |
| `pairing_client.dart` | `PairingClient`, `PairedPeer` | Lato che digita il PIN. |
| `request_signing.dart` | `signRequest` e `verifyRequest`, `kCertHeader`, `kTimeHeader`, `kSigHeader` | Firma di ogni richiesta fidata (`timestamp, metodo, percorso, SHA-256(corpo)`). |
| `trusted_devices.dart` | `TrustedDevices`, `TrustedDevice`, `formatFingerprint` | Elenco immutabile dei fidati, confronto di impronte normalizzate. |
| `sync_routes.dart` | `buildSyncRouter`, `TrackRequest` | Rotte `/sync/playlists` e `/sync/want`, solo HTTPS e solo per un firmatario fidato. |
| `sync_client.dart` | `SyncClient`, `SyncError` | Lato che avvia il sync. Sempre HTTPS, firmato, impronta fissata. |
| `playlist_sync.dart` | `planSync`, `SyncPlan`, `SyncAction` | Piano puro: decide per `uuid` cosa aggiungere o sostituire. |
| `share_link.dart` | `parseShareLink` | Legge il testo di un QR. Rifiuta tutto ciò che non è rete locale con PIN a 6 cifre. |
| `share_notifier.dart` | `ShareNotifier`, `AndroidShareNotifier` | Servizio in primo piano e notifiche (canale `codecore/share`). |

Stato e orchestrazione:
- `lib/providers/share_hub.dart`: `ShareHubNotifier` possiede nodo, scoperta, abbinamenti, offerte; monta `/pair` e `/sync` come `secureRoutes` (il metodo `_secureRoutes` di `share_hub.dart`). Tiene anche i conteggi `holdJam`/`releaseJam` del servizio in primo piano.
- `lib/providers/share_providers.dart`: `lanServerProvider`, `ShareController`, `TrustedDevicesNotifier`, `ownIdentityProvider`.
- Dati: `lib/data/repositories/playlist_sync_repository.dart` (`PlaylistSyncRepository`: `export`, `local`, `resolver`, `apply`).
- UI: `lib/ui/screens/share/` (`share_screen.dart`, `sync_flow.dart`, `sync_preview_dialog.dart`, `pairing_dialogs.dart`, `qr_scan_screen.dart`), `lib/ui/screens/devices/devices_sheet.dart`, `lib/ui/screens/settings/trusted_devices_tiles.dart`.

### Backup, ripristino, export
| File | Ruolo |
|---|---|
| `lib/services/backup/backup_service.dart` | `BackupService`, `kBackupFormat`, `kDeviceBoundKeys`. Scrive lo zip (compressione in un isolate). |
| `lib/services/backup/restore_service.dart` | `inspectBackup`, `stageFullRestore`, `applyPendingRestore`, `mergeBackup`. |
| `lib/services/backup/user_data.dart`, `track_resolver.dart` | Formato portabile e abbinamento dei brani. |
| `lib/data/repositories/backup_merge.dart`, `backup_queries.dart` | Unione dentro una transazione. |
| `lib/services/export/playlist_exporter.dart` | `toM3u8`, `toExportifyCsv`, `toPlaylistJson`, `renderPlaylist`. |
| `lib/services/export/save_file.dart` | Salvataggio verso l'utente (canale `codecore/save`, copia a flusso su Android). |
| `lib/providers/backup_providers.dart`, `backup_ops.dart` | Provider e operazioni. |
| `lib/ui/screens/settings/backup_section.dart`, `restore_dialog.dart` | UI. |

### Jam locale e della cassa (`lib/services/jam/`)
| File | Simbolo | Ruolo |
|---|---|---|
| `jam_models.dart` | `JamState`, `JamMode` (`host`, `together`) | Stato condiviso, con `version`, `participants`, `speaker`. |
| `jam_state.dart` | `applyCommand` | Riduttore puro con i permessi. |
| `jam_host.dart` | `JamHost`, `jamTokenHeader`, `jamFileHeader` | Rotte `/jam` montate da `OfferNode`; long polling. |
| `jam_guest.dart`, `jam_guest_link.dart` | `JamGuest`, `JamGuestLink` | Ospite in LAN; `JamGuestLink` è ciò che vede `JamController`. |
| `jam_output.dart`, `jam_sync.dart`, `jam_clock.dart` | `JamOutput`, `JamSyncController`, `JamClock` | Uscita su un `AudioBackend` proprio e sincronia fra uscite. |
| `jam_gate.dart` | `JamGate` | 2 richieste al minuto per id, Sospendi, Blocca. |
| `jam_turns.dart`, `jam_part_feeder.dart`, `jam_suggestion.dart` | `togetherOrder`, `JamPartFeeder`, `pickSuggestion` | Modalità «coda insieme». |
| `jam_cache.dart`, `jam_online_adder.dart`, `jam_transport.dart` | | Cache temporanea, brani online, trasporto. |
| `speaker_jam.dart` | `SpeakerJam`, `SpeakerJamPort` | Politica pura della Jam della cassa. |
| `lib/services/audio/speaker_monitor.dart` | `SpeakerMonitor` | Rileva la cassa Bluetooth. |
| `lib/providers/jam_providers.dart` | `JamController` | Orchestrazione. `openSpeakerJam()` apre la Jam in attesa. |
| `lib/providers/jam_media.dart`, `jam_local_queue.dart` | `JamMedia`, `JamLocalQueue` | File, metadati, copertine e coda locale messa da parte. |
| `lib/providers/speaker_providers.dart` | `speakerJamProvider`, `announcedJamProvider` | Cablaggio della cassa. |
| `lib/ui/screens/jam/` | `jam_screen.dart`, `jam_remote_sheets.dart`, `speaker_sheets.dart` | UI. |

### Jam a distanza (`lib/services/jam/remote/`)
| File | Simbolo | Ruolo |
|---|---|---|
| `jam_protocol.dart` | `JamWire`, `JamMsg`, `JamProtocol`, `JamDropLog` | Protocollo puro, senza I/O. |
| `jam_crypto.dart` | `JamCrypto`, `SodiumJamCrypto`, `JamKey` | Cifratura: X25519, HKDF, XChaCha20-Poly1305 (`sodium`, D-252). |
| `mqtt_link.dart` | `MqttClientLink`, `connectWithQuickRetry` | Trasporto MQTT (`mqtt_client`, D-251). |
| `broker_entry.dart`, `broker_probe.dart` | `kDefaultJamBrokers`, `decodeBrokers` | Broker: emqx (indice 0), poi HiveMQ (D-383). |
| `jam_bridge.dart`, `jam_bridge_host.dart` | `JamBridge`, `JamBridgeHost` | Ponte lato host fra LAN e MQTT. |
| `remote_jam_guest.dart` | `RemoteJamGuest` | Ospite remoto (implementa `JamGuestLink`). |
| `jam_invite.dart`, `jam_friends.dart`, `jam_beacon.dart` | `JamFriends`, `JamBeacon` | Inviti, amici con chiavi, annuncio BLE (canale `codecore/jam_beacon`, ponte Kotlin `JamBeaconBridge`). |
| `jam_remote_items.dart`, `jam_remote_meta.dart` | | Brani e metadati portati sul ponte. |
| `lib/providers/jam_remote_providers.dart` | `JamBridgeNotifier`, `jamBridgeProvider` | Accende il ponte guardando `jamProvider`. |
| `lib/providers/jam_broker_providers.dart`, `jam_gate_providers.dart` | `JamBrokersNotifier` | Lista broker e gate. |
| `lib/data/settings/jam_secret_store.dart` | `JamSecretStore`, `FileJamSecretStore` | Archivio dei segreti della Jam. |

## Come funziona

### Un endpoint, due porte
`OfferNode` apre una porta HTTP e, se ha un'identità, una porta HTTPS. L'HTTP serve `/hello`, `/offer` e `/jam` (file e Jam: ExoPlayer e mpv non verificano un certificato autofirmato, R61). L'HTTPS serve `/pair` e `/sync`. `/hello` annuncia `tlsPort` e `fingerprint` (`v` vale 3 con identità, 2 senza). Ogni richiesta passa dal filtro «solo rete locale» (`isLocalNetworkAddress`).

### Abbinamento
Il dispositivo A mostra un PIN, B lo digita (o legge un QR). B calcola `HMAC-SHA256(PIN, impronta_iniziatore | impronta_risponditore)` sulle impronte che ha visto: un intermediario con un altro certificato non riesce a far tornare la prova. Limiti in `pairing.dart`: 2 minuti di vita, 5 tentativi, 3 richieste al minuto. A conferma l'utente tocca «Conferma» e i due si salvano in `TrustedDevices`.

### Richieste fidate
TLS autentica solo il server (un server Dart non prende un certificato client autofirmato). Il chiamante quindi firma la richiesta e manda certificato e firma negli header; `verifyRequest` mette l'impronta nel contesto (`kCallerKey`). Le rotte `/sync` rispondono solo se quell'impronta è fra i fidati. Finestra di validità: `kSignatureWindow`, 2 minuti.

### Sync delle playlist
1. `SyncClient` legge `/sync/playlists` dell'altro.
2. `planSync` confronta per `uuid`: vince `updated_at` più recente. Niente viene cancellato, e preferiti, testi e modifiche non viaggiano.
3. L'utente vede l'anteprima (`sync_preview_dialog.dart`), poi `PlaylistSyncRepository.apply` scrive in una transazione.
4. I brani si abbinano con `TrackResolver` (come nel ripristino). I mancanti si chiedono con `/sync/want`, che l'altro risolve con un'offerta nell'altro verso.
5. Le righe ombra (brani in streaming, D-524) non entrano nell'export e in un `replace` restano in coda dopo i brani sincronizzati (D-537).

### Backup
Lo zip contiene `manifest.json`, `settings.json` (senza `kDeviceBoundKeys`), `user_data.json`, `codecore.sqlite` da `VACUUM INTO`, `covers/`, `downloads.json`, `dislikes.json`. Il ripristino completo non scrive subito: `stageFullRestore` estrae in `<appSupport>/restore` (`restoreStagingDir`, `lib/core/paths.dart`) e `main.dart` chiama `applyPendingRestore` prima di aprire il DB. L'unione (`mergeBackup`) è una transazione e non cancella nulla.

### Jam
- Un solo dispositivo suona; l'altro è telecomando. Stato autoritativo sull'host (`JamState.version`), comandi validati da `applyCommand`.
- I brani restano sul proprietario e si leggono in streaming con `Range` e token di sessione, solo se sono in coda.
- La Jam usa un `AudioBackend` proprio: `PlayQueue` non si tocca e la riproduzione locale va in pausa.
- **Della cassa**: `JamState.speaker`, `speakerAwaySince`; comandi `speakerAway`, `speakerBack`, `offerSpeaker`. Senza cassa i comandi di riproduzione sono rifiutati (`noSpeaker`, HTTP 409). Senza ospiti la Jam è «in attesa»: solo annuncio in LAN, e nasce alla prima richiesta accettata (D-226).
- **A distanza**: l'host accende `JamBridge`, che pubblica su un broker MQTT messaggi cifrati; l'ospite remoto entra con un codice, un QR o per amicizia (`JamFriends`). Il `JamGate` filtra le richieste in LAN e sul ponte. Gli argomenti MQTT iniziano con `ccj1/` (lobby `l`, richiesta `r`, codice `c/`).

## Invarianti da non rompere
- **Stringhe di protocollo con `codecore`, per scelta** (D-539: il nome visibile è cambiato, il filo no). Non vanno rinominate senza una nuova decisione, perché romperebbero la compatibilità con le versioni già installate:
  | Stringa | Dove |
  |---|---|
  | `CODECORE/1`, porta `45671` | `discovery.dart` (`discoveryMagic`, `discoveryPort`) |
  | `'app': 'codecore'` in `/hello` e in `lan_server.dart`, controllato da `lan_client.dart` | `offer_node.dart`, `lan_server.dart`, `lan_client.dart` |
  | `x-codecore-cert`, `x-codecore-ts`, `x-codecore-sig` | `request_signing.dart` |
  | `codecore.caller` | `offer_node.dart` (interno) |
  | `x-jam-token`, `x-jam-file` | `jam_host.dart` |
  | `codecore-jam-c1!` (sale del codice) | `JamWire.codeSalt` |
  | `ccj1/…` e `'ccj1 $label'` (contesto HKDF) | `JamProtocol`, `jam_protocol.dart` |
  | Canali `codecore/share`, `codecore/jam_beacon`, `codecore/save`, `codecore/audio` | Dart e Kotlin devono restare allineati |
  | `codecore.sqlite` nel backup | `backup_service.dart`, `restore_service.dart` |
- Le formule, le etichette e le dimensioni del protocollo remoto seguono [`feature-jam-distanza.md`](../storico/feature/feature-jam-distanza.md) alla lettera. Un cambio è una nuova decisione (K-JD-03). `JamWire.version` vale 1.
- Il PIN non viaggia mai in chiaro: solo la prova HMAC. Confronti sui segreti con `constantTimeEquals`.
- Un'impronta mostrata durante l'abbinamento è quella salvata, non quella dichiarata (`PairedPeer.fingerprint`).
- Le rotte `/pair` e `/sync` esistono solo su HTTPS; `/jam` solo su HTTP.
- Il sync non cancella mai e non tocca preferiti, testi o modifiche.
- I segreti della Jam (`JamSecretStore`, chiavi amici, gate) restano fuori da ogni backup. Aggiungere una chiave legata al dispositivo vuol dire aggiungerla a `kDeviceBoundKeys`.
- Su desktop i segreti stanno in `<appSupportDir>/jam_secrets.json` (D-269), non in `shared_preferences.json`.
- Nessun `catch (_) {}` muto: `AppLog`. Il ponte conta gli scarti con `JamDropLog` (un messaggio al minuto).

## Come si estende
- **Nuova rotta fidata**: aggiungila in `buildSyncRouter` (`sync_routes.dart`), verifica `callerFingerprint(r)` contro `TrustedDevices`, aggiungi il metodo a `SyncClient` e un test con un `WebClient` finto. Non montarla su HTTP.
- **Nuovo dato nel sync delle playlist**: estendi `RemotePlaylist` e `planSync` (puro, testalo lì), poi `PlaylistSyncRepository.export` e `apply`. Se il brano può essere una riga ombra, decidi cosa succede in `replace` (D-537).
- **Nuovo comando di Jam**: aggiungilo a `JamState`/`applyCommand` con i permessi; se passa dal ponte, serve anche un tipo in `JamMsg` e il limite di dimensione in `JamWire`. Aggiorna [`feature-jam-distanza.md`](../storico/feature/feature-jam-distanza.md).
- **Nuovo broker predefinito**: in fondo a `kDefaultJamBrokers` (l'indice è scritto nei QR e nei codici, mai riordinare), certificato verificato col nome dell'host.
- **Nuova impostazione che non deve viaggiare**: aggiungi la chiave a `kDeviceBoundKeys` e un test sul backup.
- **Nuovo formato di export**: una funzione in `playlist_exporter.dart`, la voce in `ExportFormat`, `renderPlaylist` e `exportFileName`.
- **Nuovo file grande verso l'utente**: `saveFileAt`, mai `Uint8List` sul canale.

## Trappole
- **`SharedPreferencesAsync` su desktop** scrive nello stesso `shared_preferences.json` delle preferenze, che finisce nel backup: i segreti della Jam stanno in `jam_secrets.json` con `FileJamSecretStore` (D-269).
- **`mqtt_client` non ascolta l'errore `done` del socket**: `MqttClientLink.connect` gira in `runZonedGuarded` con un `Completer` esterno. `test.mosquitto.org:8886` chiude dopo il CONNECT.
- **Un `StreamProvider<void>` non notifica dopo il primo evento** (`AsyncData(null)` è uguale al precedente): per «ticchettare» emetti un contatore `int` (interruttore «Jam sulla cassa»).
- **Prefisso di rete su Android**: `java.net.NetworkInterface`, non i `LinkProperties` di `ConnectivityManager`, che non elencano l'interfaccia dell'hotspot (D-227).
- **Su UniBA (Wi-Fi /16) i telefoni non si scoprono**: broadcast filtrato. Per provare Jam e invii usa l'hotspot di un telefono.
- **Un ricevitore dinamico di broadcast di sistema va registrato `RECEIVER_EXPORTED`**: da Android 13 un `RECEIVER_NOT_EXPORTED` non riceve `BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED` (parte dal processo Bluetooth). Sul Mi A3 (Android 11) il difetto non si vede. Verifica con `adb shell dumpsys activity broadcasts history`.
- **File grandi su un MethodChannel**: mai come `Uint8List` (OutOfMemoryError sul Motorola). `FilePicker.saveFile` vuole `bytes`; per i grandi `saveFileAt` (`codecore/save`).
- **Selettore di file di Android sul Mi A3 via adb**: i tocchi non arrivano a DocumentsUI; si usa `input keyevent TAB TAB ENTER` con il file copiato per primo. Un `am start -a SEND` con `file://` dà `SecurityException` in `IncomingBridge`: non è un bug.
- **Riverpod: provider derivato letto dentro `ref.listen`** può dare ancora il valore del brano precedente (caso `currentShadowRowProvider`): nel listener leggi la fonte diretta.
- **Un `ref.listen` su uno stato che emette due valori di fila** vede solo l'ultimo: l'esito di un job va letto dal risultato finale.
- **«Test (Windows)» cancella un file ancora aperto** (`deleteSync` lancia): i `tearDown` che ripuliscono cartelle temporanee sono tolleranti. `jam_gate_test` «concurrent writes» è rosso su Windows (confronto di percorsi), ma non è il check obbligatorio.
- **Pausa a volume zero in secondo piano**: la ripresa col tasto volume funziona solo entro circa 2 s (limite di Android).

## Decisioni chiave
| ID | Significato |
|---|---|
| [D-221](../decisioni.md) | L'host resta in Jam anche da solo; «Termina» la chiude. |
| [D-226](../decisioni.md) | Jam della cassa senza ospiti: «in attesa», parte alla prima richiesta accettata. |
| [D-227](../decisioni.md) | Prefisso di rete su Android con `NetworkInterface`. |
| [D-251](../decisioni.md) | Trasporto MQTT con `mqtt_client`, dietro un'interfaccia. |
| [D-252](../decisioni.md) | Cifratura con `sodium` (X25519, HKDF, XChaCha20-Poly1305). |
| [D-269](../decisioni.md) | `jam_secrets.json` su desktop, DataStore su Android, fuori dal backup. |
| [D-272](../decisioni.md) | `JamCrypto` espone i tipi di `sodium`; il rollback cambia anche i chiamanti. |
| [D-383](../decisioni.md) | HiveMQ come broker di riserva, in fondo alla lista. |
| [D-537](../decisioni.md) | Sync playlist: le righe ombra restano in coda su un `replace`. |
| [D-539](../decisioni.md) | Nuovo nome FreeKmusic; pacchetto Dart e stringhe di protocollo restano `codecore`. |
