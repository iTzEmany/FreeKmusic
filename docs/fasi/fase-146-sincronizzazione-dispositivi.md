# Fase 146 — Sincronizzazione tra dispositivi

## Obiettivo
Fra i dispositivi che l'utente associa come «miei», playlist, preferiti, brani salvati, impostazioni non legate al dispositivo, testi, tag e ascolti si allineano in LAN, comprese le cancellazioni (tombstone, D-668); i file sul disco non si cancellano mai e verso dispositivi non «miei» non viaggia nessuna cancellazione. Migrazione v24 (tombstone). Fuori: sync automatico in background e MQTT fuori casa, a meno che l'utente li voglia in questa fase (vedi 146.9).

## Riferimenti
D-668 (eccezione all'invariante «mai cancellare righe dell'utente in automatico»), D-675, D-662, D-699. Rilievo F-41 e tensione n. 8 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); `scansione-dati.md` (punto 3); rete.md riga 146. Base esistente: `lib/services/share/` (`offer_node.dart`, `pairing.dart`, `trusted_devices.dart`, `request_signing.dart`, `sync_client.dart`, `sync_routes.dart`, `playlist_sync.dart` con `planSync`), `lib/data/repositories/playlist_sync_repository.dart`, `backup_merge.dart`, `lib/services/backup/track_resolver.dart`. Aree: `../architettura/sync-backup-jam.md`, `libreria-e-dati.md`. **Area a rischio** (backup/merge, scrittura sulle tabelle utente, protocollo): review `/code-review high`; la parte di protocollo e firma: review Opus. Schema oggi v23, in questa fase v24.

## Task
- [ ] 146.1 Test di caratterizzazione (rete.md, riga 146)
  - File: `test/data/playlist_sync_repository_test.dart`, `test/services/share/playlist_sync_test.dart`, `test/services/share/sync_transport_test.dart`, `test/data/backup_merge_test.dart`, `test/data/backup_merge_tables_test.dart`.
  - Passi: 1) fissare il comportamento di oggi (il sync non cancella mai, vince l'`updated_at` più recente, merge che non cancella); 2) verdi; 3) commit di soli test.
  - Comando mirato: `flutter test test/data/playlist_sync_repository_test.dart test/services/share/playlist_sync_test.dart test/services/share/sync_transport_test.dart test/data/backup_merge_test.dart`
  - Fatto quando: verdi senza modifiche a `lib/`; commit separato.
- [ ] 146.2 Migrazione v24: tombstone (D-675; in un solo passo) — review: `/code-review high`
  - File: `lib/data/db/tables.dart` (tabella `SyncTombstones(kind, key, deletedAt)` per playlist, preferiti, brani salvati), `lib/data/db/app_database.dart` (`kSchemaVersion` 24), codice drift generato, `lib/services/backup/user_data.dart` (campo opzionale), `test/data/migration_test.dart`.
  - Passi: 1) tabella nuova, nessuna riga esistente toccata; 2) `dart run build_runner build --delete-conflicting-outputs`; 3) test v23 → v24 su un DB con dati; 4) potatura dei tombstone vecchi (scadenza da scegliere guardando i costi: proporre il valore nel commit).
  - Comando mirato: `flutter test test/data/migration_test.dart test/services/backup/`
  - Fatto quando: la migrazione non modifica righe; schema = 24.
- [ ] 146.3 Relazione «dispositivi miei» (D-668)
  - File: `lib/services/share/trusted_devices.dart` (`TrustedDevice`: campo `mine`, retrocompatibile in `toJson`/`decode`), `lib/ui/screens/settings/trusted_devices_tiles.dart` (interruttore «Mio dispositivo»), `lib/providers/` (provider dei dispositivi miei), ARB ×6, `test/services/share/trusted_devices_test.dart`.
  - Passi: 1) campo opzionale, default falso per i dispositivi già associati; 2) interruttore con spiegazione (le cancellazioni viaggiano solo fra i miei); 3) test di serializzazione e dell'interruttore.
  - Comando mirato: `flutter test test/services/share/trusted_devices_test.dart test/ui/trusted_devices_settings_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: i dati salvati prima della fase si leggono ancora (con `mine` falso); l'interruttore persiste.
- [ ] 146.4 Tombstone alla cancellazione (D-668) — review: `/code-review high`
  - File: `lib/data/repositories/playlist_repository.dart`, `lib/data/repositories/track_repository.dart` (rimozione di un brano salvato, preferito tolto), `lib/data/repositories/favorite_collections_repository.dart` (141), `lib/data/repositories/playlist_sync_repository.dart`, `lib/data/repositories/sync_tombstone_repository.dart` (nuovo).
  - Passi: 1) cancellare una playlist, togliere un preferito o un brano salvato scrive un tombstone nella stessa transazione; 2) **mai** per i file sul disco né per righe locali (kind 0): solo righe in streaming salvate e metadati utente; 3) test.
  - Comando mirato: `flutter test test/data/playlist_sync_repository_test.dart test/data/sync_tombstone_test.dart test/data/migration_test.dart` (il secondo è il test nuovo)
  - Fatto quando: ogni cancellazione elencata lascia un tombstone; nessuna cancellazione di file.
- [ ] 146.5 Sync di preferiti, brani salvati e playlist con cancellazioni (F-41) — review Opus (protocollo)
  - File: `lib/services/share/sync_routes.dart` (~42-75, `/sync/playlists`, `/sync/want`: nuove rotte per preferiti e salvati e per i tombstone), `lib/services/share/sync_client.dart`, `lib/services/share/playlist_sync.dart` (`planSync`), `lib/services/backup/track_resolver.dart`, `lib/data/repositories/backup_merge.dart`.
  - Passi: 1) `planSync` estesa: vince l'`updated_at` più recente; un tombstone più recente dell'elemento lo cancella, uno più vecchio viene scartato; 2) i tombstone si applicano solo se il dispositivo remoto è «mio» (146.3) ed è firmato (`request_signing`); 3) verso dispositivi non miei: solo aggiunte, come oggi; 4) test a due DB: playlist, preferiti e salvati convergono.
  - Comando mirato: `flutter test test/services/share/playlist_sync_test.dart test/services/share/sync_transport_test.dart test/services/share/request_signing_test.dart test/data/playlist_sync_repository_test.dart`
  - Fatto quando: la simulazione a due DB produce gli stessi insiemi; nessun tombstone applicato da un dispositivo non «mio».
- [ ] 146.6 Impostazioni, testi, tag e ascolti (F-41)
  - File: `lib/services/share/sync_routes.dart`, `lib/services/share/sync_client.dart`, `lib/data/settings/settings_store.dart` (elenco delle impostazioni «non legate al dispositivo»: tema, lingua, soglie; escluse cartelle, permessi, nome del dispositivo, segreti), `lib/data/repositories/backup_merge_tables.dart` (testi, tag, ascolti), `test/services/share/`.
  - Passi: 1) elenco esplicito e testato delle impostazioni sincronizzabili (lista bianca); 2) testi, tag e ascolti fusi con le regole del merge del backup (nessuna perdita); 3) niente segreti (`JamSecretStore` fuori); 4) test a due DB.
  - Comando mirato: `flutter test test/services/share/ test/data/backup_merge_tables_test.dart test/data/settings_store_test.dart`
  - Fatto quando: un'impostazione in lista bianca si allinea e una fuori lista no (test).
- [ ] 146.7 Interfaccia e avvio del sync (F-41)
  - File: `lib/ui/screens/settings/trusted_devices_tiles.dart`, `lib/ui/screens/devices/devices_sheet.dart`, `lib/providers/share_providers.dart`, ARB ×6.
  - Passi: 1) «Sincronizza ora» per ogni dispositivo mio con riepilogo («3 aggiunte, 1 rimossa»); 2) conferma prima di applicare cancellazioni; 3) errori chiari; 4) test di widget.
  - Comando mirato: `flutter test test/ui/trusted_devices_settings_test.dart test/ui/share_screen_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: il riepilogo mostra aggiunte e rimozioni; senza dispositivi miei il pulsante non c'è.
- [ ] 146.8 Convergenza e sicurezza: simulazione completa (rete.md)
  - File: `test/services/share/sync_two_devices_test.dart` (nuovo; due DB in memoria con trasporto finto).
  - Passi: 1) scenario: modifiche e cancellazioni su entrambi i lati, ordine diverso, ripetizione del sync (idempotenza); 2) verifica: stessi insiemi, 0 file cancellati, nessun tombstone verso un non-mio.
  - Comando mirato: `flutter test test/services/share/sync_two_devices_test.dart`
  - Fatto quando: la simulazione converge in 2 giri e il terzo non cambia nulla.
- [x] 146.9 Proposta all'utente: sync automatico e fuori casa (MQTT) — **chiedere prima, non decidere**
  - File: nessuno da scrivere. Documenti letti: `analisi.md` (F-41: «poi MQTT fuori casa»), `lib/services/jam/remote/` (MQTT cifrato della Jam), `scansione-dati.md` punto 3.
  - Passi: 1) scrivere all'utente (testo nel terminale, opzioni numerate): (a) fermarsi al sync manuale in LAN (consigliato: la fase è già grande e l'area è a rischio); (b) sync automatico in LAN quando i dispositivi si vedono; (c) anche fuori casa via MQTT cifrato (nuova area a rischio: protocollo e crittografia della Jam a distanza, review Opus); 2) registrare la risposta in `../decisioni.md` come D-xxx; 3) se (b) o (c): aggiungere i task qui o in una fase 148 senza decidere da soli.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: la scelta è in `../decisioni.md`.
- [ ] 146.10 Area e controllo di fine fase
  - Aggiorna `../architettura/sync-backup-jam.md` (relazione «miei», tombstone, rotte nuove, lista bianca delle impostazioni), `libreria-e-dati.md` (v24); «Trappole»: i tombstone non cancellano mai file; D-668 è l'unica eccezione all'invariante.

- [ ] 146.11 Debounce delle impostazioni alla chiusura (review di architettura della fase 135, punto 7)
  - File: `lib/providers/settings_providers.dart`, `test/data/settings_store_test.dart`.
  - Passi: 1) quando l'app va in `paused`/`detached` il debounce si svuota subito per tutte le impostazioni; 2) tolto il caso speciale di `karaokeOn` (D-664 resta vera); 3) test: un `update` seguito dalla chiusura è scritto.
  - Comando mirato: `flutter test test/data/settings_store_test.dart test/providers/karaoke_providers_test.dart`
  - Fatto quando: nessun caso speciale per campo in `SettingsNotifier.update`; il test della chiusura passa.

## Tocca a te
- [x] Decidere la proposta di 146.9 (D-703: solo manuale in LAN).
- [ ] Per la prova reale (147) servono due dispositivi dell'utente accesi sulla stessa rete e associati come «miei»; i telefoni di test (Mi A3, Redmi) servono per le prove, non toccare i file del Motorola.

## Da riprendere (review fase 140)
- Un solo ingresso per salvare righe in streaming da fuori (backup, LAN, Jam, import): controllo del file già presente e del tombstone sempre uguale; `StreamOffer` con `albumBrowseId` e `addedAt`.
- La lista bianca delle impostazioni (146.6) non deve includere le chiavi `importDownloadToo.*` (restano sul dispositivo, come nel backup).

## Note di deviazione

## Da sapere sui preferiti di collezione (review di architettura della fase 141)
- Tombstone solo in `FavoriteCollectionsRepository.remove`/`toggle` e `PlaylistRepository.delete`; mai in `followAlbumKey` (le chiavi degli album dipendono dai tag di ciascun dispositivo).
- `followAlbumKey` usa `UPDATE OR IGNORE`: se entrambi gli album erano preferiti resta una riga orfana con la chiave vecchia; cancellarla dopo l'update.
- `_mergeFavoriteCollections` scarta i preferiti di playlist il cui uuid non c'è ancora: applicare prima le playlist, o tenere in attesa quei preferiti.
- Solo `addedAt`, niente `updatedAt`: «vince il più recente» va fatto confrontando `deletedAt` con `addedAt` (orologi diversi).
- Chiavi non trasferibili: `unknown|<cartella>` (percorso locale) e chiavi per brano; escluderle o sincronizzare la coppia (artista, album).
- Preferiti di album spariti restano nel DB (filtrati in lettura) ed escono nel backup: potarli o mostrarli.
- Confine di fiducia: `FavoriteCollectionData.tryParse` deve limitare la lunghezza della chiave e il numero di voci per la LAN.

## Da sapere su `PlayContextKind` (review di architettura della fase 142)
- È un formato salvato (coda, `Plays.context`) ma vive in `providers/`: spostarlo nel livello dati con `PlayContextKind.fromIndex(int?)` e una sola decodifica (oggi duplicata in `player_providers.dart` `playContextOf` e `resume_providers.dart`); `lastPerArea` riceva il tipo e non l'area già calcolata. Gli ascolti sincronizzati da versioni diverse arrivano con indici che questa versione può non conoscere (letti come `library`).

## Da sapere sul riallaccio dopo una fusione (review di architettura della fase 143)
- `demoteToStream`/`rekeyStream` chiamano l'audio tramite la callback `onMerged`: più semplice restituire un record (`moved`, `gone`) e far chiamare `onShadowMerged` ai servizi. `replaceQueueId` oggi ha due significati scelti dal segno dell'id (fusione di riga ombra con id positivo e `includeCurrent`; voce online diventata brano con id negativo): due metodi con nome esplicito. Tutti i nuovi percorsi di fusione o rimappatura degli id della sincronizzazione devono passare da lì.
