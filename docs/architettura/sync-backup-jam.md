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
| `trusted_devices.dart` | `TrustedDevices`, `TrustedDevice`, `formatFingerprint` | Elenco immutabile dei fidati, confronto di impronte normalizzate. `TrustedDevice.mine`: relazione «dispositivo mio» (D-668), scelta dall'utente nelle Impostazioni, falsa per i dati salvati prima; `myDevicesProvider` li elenca. Le cancellazioni (tombstone) viaggiano solo verso e da questi. |
| `sync_routes.dart` | `buildSyncRouter`, `TrackRequest` | Rotte `GET /sync/playlists`, `GET /sync/collections` (favoriti, salvati e cuori, tombstone, impostazioni, ascolti, tag in una sola risposta), `POST /sync/texts` (`{after}`, a pagine di `kTextsPerPage`) e `POST /sync/want`, solo HTTPS e solo per un firmatario fidato (collections e testi solo a uno «mio»: agli altri liste vuote). Le sei rotte separate della prima bozza della 146 non sono mai uscite in una release (la 1.7.0 è la prima con la 146). |
| `sync_client.dart` | `SyncClient`, `SyncError` | Lato che avvia il sync. Sempre HTTPS, firmato, impronta fissata; `collections` legge tutto (preferiti, stream, tombstone, impostazioni, ascolti, tag) in una sola GET, solo da un dispositivo «mio», con decodifica fuori dal thread UI e timeout di ricezione di 2 minuti; i testi arrivano a pagine (`POST /sync/texts`). |
| `playlist_sync.dart` | `planSync`, `SyncPlan`, `SyncAction` | Piano puro: decide per `uuid` cosa aggiungere, sostituire o cancellare. |
| `collection_sync.dart` | `planCollections`, `CollectionPlan`, `SyncSide`, `StreamEntry`, `kMaxSyncItems` | Piano puro di preferiti di collezione, brani in streaming salvati o col cuore, tombstone, differenze delle impostazioni (`settings`) e tabelle da unire (`tables`). |
| `settings_sync.dart` | `syncedSettings`, `parseSyncedSettings`, `planSettings`, `applySettings`, `SettingChange` | Lista bianca delle impostazioni che viaggiano, validate per tipo e intervallo. |
| `tables_sync.dart` | `TablesBundle`, `TextEntry`, `PlayEntry`, `TagEntry`, `TaggedTrack` | Testi (testo, sincronizzato, curiosità), ascolti, tag e brani etichettati: voci validate con `tryParse`, limiti di lunghezza e di numero. |
| `share_link.dart` | `parseShareLink` | Legge il testo di un QR. Rifiuta tutto ciò che non è rete locale con PIN a 6 cifre. |
| `share_notifier.dart` | `ShareNotifier`, `AndroidShareNotifier` | Servizio in primo piano e notifiche (canale `codecore/share`). |

Stato e orchestrazione:
- `lib/providers/share_hub.dart`: `ShareHubNotifier` possiede nodo, scoperta, abbinamenti, offerte; monta `/pair` e `/sync` come `secureRoutes` (il metodo `_secureRoutes` di `share_hub.dart`). Tiene anche i conteggi `holdJam`/`releaseJam` del servizio in primo piano.
- `lib/providers/share_providers.dart`: `lanServerProvider`, `ShareController`, `TrustedDevicesNotifier`, `ownIdentityProvider`.
- Dati: `lib/data/repositories/playlist_sync_repository.dart` (`PlaylistSyncRepository`: `export`, `local`, `resolver`, `plan`, `apply`).
- UI: `lib/ui/screens/share/` (`share_screen.dart`, `sync_flow.dart`, `sync_preview_dialog.dart`, `pairing_dialogs.dart`, `qr_scan_screen.dart`), `lib/ui/screens/devices/devices_sheet.dart`, `lib/ui/screens/settings/trusted_devices_tiles.dart`.

### Backup, ripristino, export
| File | Ruolo |
|---|---|
| `lib/services/backup/backup_service.dart` | `BackupService`, `kBackupFormat`, `kDeviceBoundKeys`. Scrive lo zip (compressione in un isolate). |
| `lib/services/backup/restore_service.dart` | `inspectBackup`, `stageFullRestore`, `applyPendingRestore`, `mergeBackup`. |
| `lib/services/backup/user_data.dart`, `track_resolver.dart` | Formato portabile e abbinamento dei brani. |
| `lib/data/repositories/backup_merge.dart`, `backup_queries.dart` | Unione dentro una transazione. |
| `lib/services/backup/backup_db_reader.dart` | Lettura in sola lettura del `codecore.sqlite` del backup (schemi vecchi tollerati). |
| `lib/data/repositories/backup_merge_tables.dart`, `backup_merge_helpers.dart` | Unione di ascolti, tag, copertine, playlist smart, podcast e puntate. |
| `lib/services/export/playlist_exporter.dart` | `toM3u8`, `toExportifyCsv`, `toPlaylistJson`, `renderPlaylist`. |
| `lib/services/export/save_file.dart` | Salvataggio verso l'utente (canale `codecore/save`, copia a flusso su Android). |
| `lib/providers/backup_providers.dart`, `backup_ops.dart` | Provider e operazioni (`backupLastAtProvider`, `androidBackupFolder`). |
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

### Sync fra dispositivi (playlist, preferiti, salvati, cancellazioni)
1. `SyncClient` legge `/sync/playlists` dell'altro e, solo se il dispositivo è «mio» (`TrustedDevice.mine`), anche `GET /sync/collections` (una richiesta: preferiti, salvati e cuori, tombstone, impostazioni, ascolti, tag; la rotta manda tutti i tombstone, senza `since`) e i testi a pagine con `POST /sync/texts` (la firma copre il percorso senza query). Un peer di una versione precedente (≤1.6.x, che ha solo `/sync/playlists` e `/sync/want`), che risponde 404 a `/sync/collections`, vale come un peer senza collezioni: si sincronizzano le sole playlist, con un avviso nel log; ogni altro stato diverso da 200 fa fallire il sync. Con un fidato non «mio» il client non chiede altro che le playlist e il server risponde con liste vuote: fra dispositivi non «miei» viaggiano solo le playlist. Una playlist malformata (uuid non valido, testi oltre 512, numeri non finiti, voci che non sono oggetti) fa fallire tutto il sync (`SyncError.failed`): scartarla, o scartarne un brano, farebbe sostituire una playlist locale con una più corta.
2. `planSync` (puro) confronta elemento per elemento, la data più recente vince: `updatedAt` per le playlist, `addedAt` per preferiti di collezione e brani salvati, `favorited_at` per il cuore di un brano in streaming; senza data = più vecchio di tutto, **a parità resta l'elemento, ovunque** (arrivo `>=`, cancellazione e controlli di `apply` e `ingestStream` con `<`/`>` stretti). Un tombstone più recente dell'elemento lo cancella, uno più vecchio o pari è scartato. `planCollections` non pianifica ciò che `apply` scarterebbe (preferito di una playlist che non ci sarà dopo il piano, cuori e salvati di chiavi che sono episodi o file qui), così il piano successivo è vuoto. Le chiavi degli album sono canoniche (`favoriteAlbumKey`: `stream|x` e `x` sono lo stesso preferito) già in `tryParse`. Un tombstone per qualcosa che qui non c'è si memorizza (`learned`), così l'elemento non rientra da un terzo dispositivo.
3. Cancellazioni e tombstone remoti valgono **solo** se il dispositivo remoto è «mio» e la richiesta è firmata. Verso e da un dispositivo non «mio» viaggiano solo aggiunte. Un'aggiunta coperta da un tombstone **locale** più recente non si applica per nessun dispositivo; `apply` toglie un tombstone solo se l'elemento che arriva è più recente.
4. Il piano lo costruisce solo `PlaylistSyncRepository.plan(remote, side, {resolver, settings, mine, history, hasFile})` (l'hub e la simulazione a due dispositivi chiamano lo stesso metodo: taglia le novità di testi, ascolti e tag solo per un dispositivo «mio», con `history` = `recordHistory` letto una volta). L'utente vede l'anteprima, poi `PlaylistSyncRepository.apply` scrive in una transazione (le playlist sempre; la parte «collezioni» solo con `applyCollections: true`, cioè dopo la conferma dell'utente; restituisce quante playlist ha scritto davvero): playlist, poi cancellazioni (ogni scrittura rilegge le date di adesso: il piano può essere più vecchio della conferma; il tombstone si registra solo se la cancellazione ha toccato qualcosa, un cuore locale più recente o pari non si sovrascrive), poi preferiti (dopo le playlist: un preferito di playlist il cui uuid non c'è si scarta), poi righe in streaming.
5. Le cancellazioni applicate tolgono **solo righe o flag**: playlist visibili (mai quelle nascoste di «Scarica album»), preferiti, `saved` e cuore di righe in streaming (kind 2; la riga resta, la pulizia delle ombre è quella di sempre). Mai file, mai righe locali (kind 0). Il tombstone si registra con la data della cancellazione remota. `hasFile` è uno solo, per piano e `apply` (`_noRow`): l'indice dei download o la chiave di un episodio (kind 1); un cuore su un file non viaggia, perché `streams()` esporta solo righe in streaming.
6. Le righe in streaming entrano da fuori da un solo punto, `TrackRepository.ingestStream` (sync, offerte LAN in `saveReceivedStreams`, unione del backup): non scrive nulla se il file c'è già (`hasFile` per chiave; nel sync viene dall'indice dei download) o se il tombstone locale è più recente dell'arrivo (data dell'elemento; un'offerta o l'unione di un backup sono gesti dell'utente, data = adesso, e quest'ultima data la riga con quella del backup tramite `date`). Un elemento scartato non crea nemmeno la riga ombra, e l'unione del backup non lo conta. `deleteUnplayedStreamRows` non toglie le righe con il cuore. Non coperto: Jam e import (azioni dirette dell'utente, usano `saveStream`).
7. **Impostazioni, testi, ascolti e tag (D-668, solo fra dispositivi «miei»)**. Le impostazioni non hanno data: niente «vince il più recente». Il piano (`CollectionPlan.settings`, lista di `SettingChange{key, local, remote}`) elenca ogni chiave in lista bianca il cui valore differisce; si applicano solo dopo la conferma dell'utente, scelte chiave per chiave (`ShareHub.applySettingsSync` passa dal notifier, mai dalle prefs). Lista bianca (`settings_sync.dart`): tema (solo i 3 predefiniti), accento, `fontScale` (solo i tre valori della UI: 0.9, 1.0, 1.15), `compactMode`, `reducedMotion`, `spinCover`, lingua, `autoEnrich`, `autoLyrics`, `deezerMeta`, `creditsDetails`, `romanization`, `autoCuriosities`, `showUndoSnackbar`, `normalizeVolume`, `librarySort`, `librarySortAscending`, formato e qualità di download, qualità dello stream, soglie d'importazione, `playbackSpeed`, `showKaraoke`, transizione, `crossfadeSeconds`, `crossfadePlainInAlbum`, `shufflePlus`, `shufflePlusEvery`. Restano sul dispositivo: `acoustId` (invia impronte audio a un servizio esterno: lo decide ogni dispositivo), cartelle e backup (percorsi), nome e identità, dispositivi fidati, Jam e segreti, `receiveFromLan`, `importDownloadToo.*`, tutto ciò che dipende dall'hardware (EQ, karaoke, latenza Jam, `pauseOnZeroVolume`, `blurredChrome`), rete e disco (cache, parallelismo, limite di banda, dati mobili), scrittura dei tag nei file, `iconFollow`, griglia, paese e regione della radio, `playlistSorts` (id locali), stato d'installazione e cronologia. Un test elenca ogni chiave che `SettingsStore.writeSettings` scrive e fallisce se non è decisa: una impostazione nuova va messa nella lista bianca o fra quelle che restano. Testi, ascolti e tag riusano le regole dell'unione del backup (`mergeTablesData`, `mergeUserData`: nessuna perdita, unione; ascolti per `(brano, playedAt)`, tag per nome senza maiuscole, un testo riempie solo un campo vuoto); `newTables` taglia il pacchetto a ciò che è nuovo, così anteprima e `isEmpty` sono veri e il sync successivo è vuoto. Soglie d'importazione: una coppia con «da rivedere» sopra «sicura» si scarta. Un tema personalizzato (`custom:…`) non si invia né si propone, e non viene sostituito. Con la cronologia spenta (`recordHistory`) gli ascolti non si esportano e il piano li scarta; gli ascolti che arrivano aggiornano `play_count` e `last_played_at` dei brani (mai al ribasso). Limiti: 20000 ascolti (i più recenti), testi di 100000 caratteri, 100 tag per brano e 20000 coppie (brano, tag) in tutto; i testi si leggono a pagine e si filtrano pagina per pagina (restano solo le novità), al massimo 20000 righe grezze, cioè **i primi 20000 brani con testo per id** (i successivi non viaggiano), e 20 milioni di caratteri tenuti; i testi di brani in streaming non viaggiano.
8. Chiavi non trasferibili: i preferiti con chiave `unknown|…` (percorso locale) non viaggiano. I brani si abbinano con `TrackResolver`, i mancanti si chiedono con `/sync/want`.
9. Le righe ombra (brani in streaming, D-524) non entrano nell'export delle playlist e in un `replace` restano in coda dopo i brani sincronizzati (D-537).

Confine di fiducia (tutto ciò che arriva è input non fidato): al massimo `kMaxSyncItems` (20000) voci per lista; chiavi e testi (nomi e titoli di playlist compresi) ≤ `kMaxKeyLength` (512); `StreamEntry.tryParse` richiede una chiave valida (`isStreamKey`) e un `albumBrowseId` valido; i tombstone con tipo ignoto, chiave non adatta al tipo o data ≤ 0 o oltre `kTombstoneMaxFuture` (10 minuti) si scartano; le date di elementi fuori intervallo diventano «senza data» (`sanePastDate`), così una data nel futuro non vince ogni confronto.

### Backup
Lo zip contiene `manifest.json`, `settings.json` (senza `kDeviceBoundKeys`), `user_data.json`, `codecore.sqlite` da `VACUUM INTO`, `covers/`, `theme/` (immagini di sfondo dei temi), `downloads.json`, `dislikes.json`. Il ripristino completo non scrive subito: `stageFullRestore` estrae in `<appSupport>/restore` (`restoreStagingDir`, `lib/core/paths.dart`) e `main.dart` chiama `applyPendingRestore` prima di aprire il DB. L'unione (`mergeBackup`) è una sola transazione, idempotente, e non cancella nulla. Porta:
- impostazioni, tranne `kDeviceBoundKeys` e `kMergeSkippedKeys` (chiavi legate agli id del DB o alle sessioni di questo dispositivo);
- temi personalizzati uniti per id (limite 20, gli scartati sono contati);
- ascolti (doppioni per trackId+playedAt; i non riconosciuti sono saltati e contati; quelli in streaming solo su righe ombra già presenti, D-546);
- brani salvati in streaming: `TrackUserData.saved/album/addedAt`; `collectUserData` prende `kind != 2 OR saved = 1`; il ripristino ricrea la riga con `saveStream`;
- preferiti di collezione (fase 141, `UserData.favoriteCollections`, campo opzionale `{kind, key, addedAt}`): unione per `(kind, key)` senza doppioni; un preferito di playlist entra solo se quell'uuid esiste qui (il merge delle playlist conserva l'uuid del backup quando è libero). «Sostituisci» li riporta con il `codecore.sqlite`. Un backup senza il campo si legge uguale, una voce malformata si scarta;
- copertine automatiche, tag, playlist smart, podcast e puntate, letti in sola lettura dal `codecore.sqlite` del backup.

Dopo l'unione i provider vengono ricaricati. Lo zip non porta `downloads.sig.json`.

Dopo «Sostituisci» (fase 137, D-680) l'app si riavvia da sola: `BackupOps.restartAfterRestore` chiude il DB (timeout 2 s: gli stream in pausa bloccherebbero `close()`) e chiama `AppRestart.restart()` (`lib/services/restart/app_restart.dart`: Android con il canale `codecore/restart`, desktop rilanciando `$APPIMAGE` o `Platform.resolvedExecutable`; Flatpak o errore → false e il dialogo dice «chiudi e riapri», il cui pulsante chiama `AppRestart.quit()`; stesso ripiego se dopo 5 s il processo vive ancora; `$APPIMAGE` conta solo se `detectUpdateTarget` lo riconosce). `applyPendingRestore` sposta `-journal`, `-wal` e `-shm` accanto a `*.before-restore` invece di lasciarli al DB nuovo. Dopo «Unisci» `MergeReport.notFound` elenca i brani non trovati (`MissingTrack`: titolo e artista, dai brani con dati utente e dalle voci delle playlist, senza doppioni); il dialogo (`merge_report_dialog.dart`) offre «Cerca online» per riga e «Copia elenco»: il backup non porta un videoId per i brani locali (D-681). La sezione Backup dice cosa contiene lo zip e porta «Esporta playlist» / «Importa playlist» (gli stessi flussi della schermata Playlist).

Backup automatico (R-241): `runAutoBackupIfDue` scrive `freekmusic-auto-<data>.zip` come `.part` e lo rinomina a zip finito; ne tiene 3 (`kBackupsKept`), i backup manuali non si toccano mai. Dopo un errore riprova al prossimo avvio; non parte durante l'onboarding. Le chiavi `autoBackup`, `backupFolder`, `backupLastAt`, `streamCacheVolume` e `storageModeD665` (passaggio una tantum a «in streaming», D-665) sono in `kDeviceBoundKeys`; le chiavi `importDownloadToo.<id>` (prefisso) restano fuori da backup e ripristino. `isBackupDue` è in `backup_service.dart`.

### Jam
- Un solo dispositivo suona; l'altro è telecomando. Stato autoritativo sull'host (`JamState.version`), comandi validati da `applyCommand`.
- L'ospite salva (fase 140, D-690): dal menu della coda un brano online diventa un brano salvato in streaming; un brano locale dell'HOST già nella `JamCache` viene copiato (su `.part`, nome ≤ 200 byte) nella cartella dei download e scansionato. Tutto locale: nessun messaggio del protocollo cambia, l'host non vede nulla (`JamSaver`, `lib/providers/jam_save.dart`).
- Condivisione in LAN (fase 140, D-674): l'offerta porta un campo opzionale `streams` (chiave, titolo, artista, album, durata, crediti): il ricevente li salva come brani in streaming (`saveReceivedStreams`), senza file. Un ricevente vecchio ignora il campo; un'offerta di soli stream a un ricevente vecchio fallisce con errore di invio.
- Dalla fase 145 (D-677) il tasto «Condividi» apre il foglio di sistema (vedi `online.md`); la LAN sta nella voce «Invia a un dispositivo» del menu ⋮ di brano, album e playlist (la playlist la offre se ha almeno un brano che non sia in streaming).
- I brani restano sul proprietario e si leggono in streaming con `Range` e token di sessione, solo se sono in coda.
- La Jam usa un `AudioBackend` proprio: `PlayQueue` non si tocca e la riproduzione locale va in pausa.
- **Della cassa**: `JamState.speaker`, `speakerAwaySince`; comandi `speakerAway`, `speakerBack`, `offerSpeaker`. Senza cassa i comandi di riproduzione sono rifiutati (`noSpeaker`, HTTP 409). Senza ospiti la Jam è «in attesa»: solo annuncio in LAN, e nasce alla prima richiesta accettata (D-226).
- **A distanza**: l'host accende `JamBridge`, che pubblica su un broker MQTT messaggi cifrati; l'ospite remoto entra con un codice, un QR o per amicizia (`JamFriends`). Il `JamGate` filtra le richieste in LAN e sul ponte. Gli argomenti MQTT iniziano con `ccj1/` (lobby `l`, richiesta `r`, codice `c/`).

- **Video karaoke nella Jam (fase 148, D-710)**: con un item karaoke di YouTube ogni dispositivo mostra il video allineato alla posizione della Jam (dettagli in `online.md`, «Video karaoke»); il protocollo non cambia. Il karaoke col modello resta tolto (sotto).
- **Karaoke tolto dalla Jam (D-623, fase 130)**: `JamState` non ha più il campo `'kar'` e non esistono i comandi `karaoke` e `karaokeGuests`. Compatibilità: uno stato di una versione vecchia con `kar` si legge normalmente (la chiave è ignorata, come ogni chiave sconosciuta); un comando `karaoke`/`karaokeGuests` non è più un tipo noto, quindi `JamCommand.tryParse` dà `null` e il canale lo scarta senza errori (la LAN risponde 400, il ponte lo lascia cadere). Una versione vecchia che riceve stati nuovi non vede `kar` e suona senza filtro. Il microfono non compare durante una Jam. Nessuna modifica alla crittografia.

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
- Il sync cancella solo per D-668: righe e flag (playlist, preferiti, `saved`/cuore di righe in streaming) per tombstone di un dispositivo «mio»; mai file, mai righe locali. Anche impostazioni, testi, ascolti e tag viaggiano, ma solo fra dispositivi «miei» (146.6).
- I segreti della Jam (`JamSecretStore`, chiavi amici, gate) restano fuori da ogni backup. Aggiungere una chiave legata al dispositivo vuol dire aggiungerla a `kDeviceBoundKeys`.
- Su desktop i segreti stanno in `<appSupportDir>/jam_secrets.json` (D-269), non in `shared_preferences.json`.
- Nessun `catch (_) {}` muto: `AppLog`. Il ponte conta gli scarti con `JamDropLog` (un messaggio al minuto).

## Come si estende
- **Nuova rotta fidata**: aggiungila in `buildSyncRouter` (`sync_routes.dart`), verifica `callerFingerprint(r)` contro `TrustedDevices`, aggiungi il metodo a `SyncClient` e un test con un `WebClient` finto. Non montarla su HTTP.
- **Nuovo dato nel sync**: estendi `RemotePlaylist` e `planSync` o `planCollections` (puri, testali lì), poi `PlaylistSyncRepository.export` e `apply`; una rotta nuova ha il suo limite di voci e un parser che scarta. Se il brano può essere una riga ombra, decidi cosa succede in `replace` (D-537).
- **Nuovo comando di Jam**: aggiungilo a `JamState`/`applyCommand` con i permessi; se passa dal ponte, serve anche un tipo in `JamMsg` e il limite di dimensione in `JamWire`. Aggiorna [`feature-jam-distanza.md`](../storico/feature/feature-jam-distanza.md).
- **Nuovo broker predefinito**: in fondo a `kDefaultJamBrokers` (l'indice è scritto nei QR e nei codici, mai riordinare), certificato verificato col nome dell'host.
- **Nuova impostazione che non deve viaggiare**: aggiungi la chiave a `kDeviceBoundKeys` e un test sul backup.
- **Nuova impostazione con id del DB o stato di sessione del dispositivo**: va in `kMergeSkippedKeys` o `kDeviceBoundKeys`, con un test.
- **Nuovo formato di export**: una funzione in `playlist_exporter.dart`, la voce in `ExportFormat`, `renderPlaylist` e `exportFileName`.
- **Nuovo file grande verso l'utente**: `saveFileAt`, mai `Uint8List` sul canale.

## Trappole
- **Un orologio avanti di oltre 10 minuti (`kTombstoneMaxFuture`)**: le sue date (tombstone, `addedAt`, `favorited_at`, `updatedAt`) sono scartate o diventano «senza data» da chi le riceve, quindi le sue cancellazioni non viaggiano e le sue aggiunte valgono come le più vecchie. Entro 10 minuti la data si crede e può vincere sul dispositivo giusto (limite accettato). Il fuzz con orologi sfasati (`SKEW`) converge.
- **L'«Unisci» di un backup rimette il cuore** anche dopo un `favoriteStream` più recente (caso accettato, S3): è un gesto dell'utente e `setFavoriteMany` toglie il tombstone. Vale anche per i salvati (data = adesso).
- **Tombstone** (146.4): nascono solo nei repository (vedi `libreria-e-dati.md`), mai per file né per righe locali (kind 0); l'unica eccezione all'invariante «il sync non cancella» è D-668, e solo fra dispositivi «miei». `backup_merge` toglie il tombstone di ciò che rimette: playlist ricreate con il loro uuid, cuori di collezione (`add`) e cuori dei brani (`setFavoriteMany`: data `favorited_at` e tombstone `favoriteStream`). Il confronto con le date lo fa `planSync` (146.5); la riga in streaming che arriva da fuori passa da `ingestStream`. Una playlist nascosta di «Scarica album» non lascia tombstone.
- **«Sincronizza ora»** (146.7): compare solo per i dispositivi «miei» (`syncFlow` → `showSyncPreview(mine: true)`). L'anteprima elenca aggiunte e rimozioni per tipo, le impostazioni diverse con una casella ciascuna (nessuna spuntata di default) e, con rimozioni, il pulsante dice «Applica e togli N elementi»: nulla si scrive prima. Poi `applyPlaylistSync(plan, collections: true)` e `applySettingsSync(plan, spuntate)`. Se arrivano solo playlist una riga suggerisce di marcare il dispositivo «mio» anche sull'altro (non si distingue da «niente altro da sincronizzare»). I nomi e i valori delle impostazioni sono tradotti e riusano le etichette delle Impostazioni.
- **Un cuore messo per sbaglio e annullato lascia un tombstone `favoriteStream` datato adesso** (caso accettato, 146.5): se un altro dispositivo «mio» aveva un cuore più vecchio sullo stesso brano, al prossimo sync lo perde. Non c'è un annullamento che ripristini lo stato precedente.
- **Un dispositivo «mio» spento per oltre 180 giorni rimanda ciò che era stato cancellato**: nel frattempo i tombstone sono potati (`kTombstoneKeep`) e il suo elemento torna come un'aggiunta. Limite accettato.
- **Un tombstone non è mai riletto con l'ora di adesso**: `apply` registra quello remoto con la sua data (`record(at:)`), mai `setSaved`/`remove` dei repository (scriverebbero un tombstone nuovo e più recente, che cancellerebbe anche la copia che un altro ha cambiato dopo).
- **La firma copre il percorso senza query**: una rotta con parametri li riceve in un corpo POST (come il corpo di `/sync/texts`).
- **Le chiavi degli stream ricevute in LAN sono input non fidato** (fase 140): `StreamOffer.tryParse` le valida con `isStreamKey` prima che finiscano nell'URL di yt-dlp o nel nome di un file.
- **`SystemNavigator.pop()` non chiude il processo** su Android (chiude solo l'Activity): un ripristino preparato non si applica finché il processo vive. Per ripartire davvero c'è `AppRestart` (fase 137).
- **Ucciso a metà scrittura, SQLite lascia un `-journal` caldo** (il DB è in `journal_mode` DELETE): se resta accanto a un DB diverso, al prossimo avvio viene applicato a quello. Va spostato insieme al file a cui appartiene.
- **`JamUiState.remote` è solo l'ospite remoto**: l'host che invita ha `inviting`, e un'uscita in LAN di una Jam mista vede i remoti solo nel roster. Dove serve «Jam con ospiti remoti» (karaoke, microfono, nota dell'host) usa `JamUiState.remoteJam` (`remote || inviting || roster con un remoto`), mai `remote` da solo.
- **Riverpod: `ref` in `State.dispose()` lancia `StateError`** (il contesto è già smontato): leggi in `initState` il notifier o il container e invia da quelli (foglio del karaoke, `flush` dello throttle). In un test il `dispose` con invio pendente si prova con `pumpWidget(const SizedBox())`, non con un pop animato (il timer da 250 ms scatta prima).
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
| [D-668](../decisioni.md) | Cancellazioni fra i miei dispositivi (tombstone), unica eccezione all'invariante. |
| [D-537](../decisioni.md) | Sync playlist: le righe ombra restano in coda su un `replace`. |
| [D-545](../decisioni.md) | Unione: impostazioni e temi, con esclusioni per chiavi legate a id o dispositivo. |
| [D-546](../decisioni.md) | «Unisci»: ascolti di brani non riconosciuti saltati e contati, nessuna riga ombra creata apposta. |
| [D-554](../decisioni.md) | Unione dal sqlite del backup in sola lettura, in una transazione. |
| [D-539](../decisioni.md) | Nuovo nome FreeKmusic; pacchetto Dart e stringhe di protocollo restano `codecore`. |
