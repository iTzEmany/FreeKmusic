# Fase 140 — Streaming per prima

## Obiettivo
Ogni nuova aggiunta in libreria (salva, import, playlist, Jam) crea brani in streaming, per tutti; i file già sul dispositivo restano locali e non si toccano; scaricare è sempre una scelta (singolo, selezione, playlist, album, «scarica anche» nell'import). La cartella dei download è fissa dentro quella scansionata; l'album mostra anche i brani non salvati; l'ospite di una Jam può salvare i brani; i brani in streaming funzionano in condivisione LAN, esportazione e Android Auto. Migrazione v22 (`browseId` dell'album). Fuori: download automatici, versione `lite` (resta `device`, senza streaming).

## Riferimenti
D-665, D-666, D-674, D-690, D-675, D-598 (superata in parte da D-665), D-662, D-699. Rilievi F-18..F-20, F-22, F-24 e punti 5, 6 delle contraddizioni in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); [`../refactor/grande-revisione/scansione-streaming.md`](../refactor/grande-revisione/scansione-streaming.md) e `scansione-dati.md` (punto 4); rete.md riga 140. Mockup: `mockup/collezione.html` (F-22). Aree: `../architettura/online.md`, `libreria-e-dati.md`, `sync-backup-jam.md`, `piattaforme.md`. **Area a rischio** (query su `tracks`, migrazione, Jam, import): review `/code-review high`. Schema oggi v21 (dopo la 136), in questa fase v22.

## Task
- [ ] 140.1 Test di caratterizzazione (rete.md, riga 140)
  - File: `test/providers/play_online_test.dart`, `test/services/stream/stream_promoter_test.dart`, `test/data/library_queries_test.dart`, `test/data/stream_rows_hidden_test.dart`, `test/ui/folders_onboarding_characterization_test.dart`.
  - Passi: 1) fissare il comportamento di oggi (modalità `device` di default, salvataggio, righe nascoste, onboarding delle cartelle); 2) verdi; 3) commit di soli test.
  - Comando mirato: `flutter test test/providers/play_online_test.dart test/services/stream/stream_promoter_test.dart test/data/library_queries_test.dart test/data/stream_rows_hidden_test.dart test/ui/folders_onboarding_characterization_test.dart`
  - Fatto quando: verdi senza modifiche a `lib/`; commit separato.
- [ ] 140.2 Migrazione v22: `browseId` dell'album (D-675; in un solo passo)
  - File: `lib/data/db/tables.dart` (colonna nullabile per il `browseId` dell'album sulle righe stream; scegliere guardando `track_kinds.dart` e `online_entries.dart`), `lib/data/db/app_database.dart` (`kSchemaVersion` 22), codice drift generato, `lib/data/repositories/track_repository.dart` (`saveStream` ~350), `lib/services/backup/user_data.dart` (campo opzionale), `test/data/migration_test.dart`.
  - Passi: 1) colonna nullabile, nessuna riga riscritta; 2) `dart run build_runner build --delete-conflicting-outputs`; 3) `saveStream` salva il `browseId` quando il brano arriva da una pagina album; 4) test v21 → v22 su un DB con brani locali (metrica: 0 righe modificate).
  - Comando mirato: `flutter test test/data/migration_test.dart test/data/library_queries_test.dart test/services/backup/`
  - Fatto quando: la migrazione non modifica nessuna riga; schema = 22.
- [ ] 140.3 Default «streaming per prima» (F-18; D-665)
  - File: `lib/data/settings/settings_store.dart` (`StorageMode`, ~34; default), `lib/ui/screens/onboarding/onboarding_pages.dart` (~255, oggi `device` salvo poco spazio), `lib/providers/library_add_providers.dart` (~26-62), `lib/providers/import_providers.dart` (~63-66), `lib/core/constants.dart` (`kEnableYoutube`).
  - Passi: 1) default `stream` per tutti quando YouTube è attivo (anche chi aggiorna: D-665, nessun download automatico, i file locali non si toccano); 2) `lite` (senza YouTube) resta `device`; 3) l'interruttore resta in Impostazioni; 4) aggiornare i test di 140.1 citando D-665 nel commit; 5) test: aggiunta da YouTube Music crea un brano salvato in streaming, non un file.
  - Comando mirato: `flutter test test/providers/play_online_test.dart test/data/settings_store_test.dart test/ui/folders_onboarding_characterization_test.dart test/providers/pending_playlist_adds_test.dart`
  - Fatto quando: un nuovo salvataggio crea un brano in streaming e la `lite` resta `device`; nessun file locale modificato.
- [ ] 140.4 Cartella unica (F-19; D-666)
  - File: `lib/ui/screens/onboarding/onboarding_pages.dart` (`FoldersPage`, ~147), `lib/core/platform.dart` (~64, default dei download), `lib/data/settings/settings_store.dart` (~73, `downloadLocation`), `lib/providers/youtube_providers.dart` (~128, `libraryFolderFor`), `lib/ui/screens/library/folders_sheet.dart`, `lib/ui/screens/settings/download_location_tile.dart`, ARB ×6.
  - Passi: 1) i download vanno sempre in `Music/FreeKmusic` (su desktop la cartella di oggi); 2) l'onboarding sceglie la cartella da scansionare e la cartella dei download sta dentro; 3) chi ha già una cartella diversa non viene spostato (nessun file toccato); 4) la tile dei download mostra la cartella fissa; 5) test.
  - Comando mirato: `flutter test test/ui/folders_onboarding_characterization_test.dart test/ui/download_location_tile_test.dart test/providers/default_folder_test.dart`
  - Fatto quando: la destinazione dei download non è più una scelta libera e sta dentro una cartella scansionata; golden `onboarding` rivisto.
- [ ] 140.5 Import: «scarica anche» (F-20; D-665)
  - File: `lib/services/import/import_options.dart` (`ImportOptions.downloadToo`), `lib/services/import/playlist_import_service.dart` (`_process` ~689, `_queueDownload` ~979, `_tagSaved` ~964), `lib/providers/import_providers.dart` (~63-66), `lib/ui/screens/import/import_preview_dialog.dart` (casella), ARB ×6.
  - Passi: 1) l'import salva sempre in streaming; con `downloadToo` accoda anche il download; 2) niente decisione dalla modalità globale; 3) casella nel dialogo (default spenta); 4) test: import senza e con `downloadToo`.
  - Comando mirato: `flutter test test/services/import/ test/providers/import_notification_test.dart test/ui/import_plan_test.dart`
  - Fatto quando: l'import senza `downloadToo` non scarica nessun file; con la casella scarica.
- [ ] 140.6 «Scarica» di massa (F-20; D-665)
  - File: `lib/providers/keep_offline_providers.dart`, `lib/ui/widgets/keep_offline_action.dart` (`keepOfflineFlow`, ~10), `lib/ui/screens/import/` (azione dopo l'import), ARB ×6.
  - Passi: 1) azione «Scarica» per l'import appena finito e per una selezione di brani salvati, che riusa `keepOfflineFlow` e scarica i brani già arricchiti; 2) conferma con la dimensione stimata su rete a consumo; 3) test.
  - Comando mirato: `flutter test test/providers/keep_offline_test.dart test/ui/architecture_test.dart`
  - Fatto quando: l'azione scarica solo i brani salvati non ancora scaricati (test con file finti).
- [ ] 140.7 Album completo (F-22; mockup `collezione.html`)
  - File: `lib/ui/screens/library/album_detail_screen.dart` (~61), `lib/data/repositories/library_queries.dart` (~283, `watchAlbumTracks`), `lib/ui/screens/online/online_album_screen.dart` (~39, ~72), `lib/services/online/ytm_catalog.dart` (`searchAlbums` ~116, ripiego), ARB ×6.
  - Passi: 1) sotto i brani in libreria, sezione «Altri brani dell'album» con quelli mancanti presi dall'album online (via `browseId` salvato in 140.2); 2) ripiego: ricerca dell'album; 3) i brani mancanti si ascoltano e si salvano (`LibraryAdder`); 4) «Scarica album» in modalità stream scarica davvero (oggi solo salva, ~72); 5) test e golden `album`.
  - Comando mirato: `flutter test test/ui/collection_pages_test.dart test/data/library_queries_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: un album con 3 brani su 10 in libreria mostra 7 brani mancanti ascoltabili e salvabili; golden rivisto.
- [ ] 140.8 Jam: l'ospite salva (F-24; D-690) — review: `/code-review high` (protocollo Jam: nessuna modifica ai messaggi)
  - File: `lib/ui/screens/jam/jam_queue_sheet.dart` (nessuna azione oggi), `lib/services/jam/jam_cache.dart` (copia dalla cache da 300 MB), `lib/services/jam/jam_host.dart` (~680-739, solo lettura), `lib/providers/library_add_providers.dart`, ARB ×6.
  - Passi: 1) brano online (`videoId`) → flusso «aggiungi alla libreria» in streaming; 2) brano locale dell'host presente nella `JamCache` → copia più scan; altrimenti la voce non compare; 3) nessun nuovo messaggio di protocollo; l'host non può vietarlo; 4) test.
  - Comando mirato: `flutter test test/jam/jam_cache_test.dart test/jam/jam_host_test.dart test/ui/jam_queue_sheet_test.dart test/ui/online_jam_guest_test.dart test/providers/jam_media_test.dart test/ui/architecture_test.dart`
  - Fatto quando: l'ospite salva un brano online e un brano locale in cache; senza cache l'azione non c'è.
- [ ] 140.9 Brani in streaming in condivisione LAN (D-674)
  - File: `lib/providers/share_providers.dart` (~92, esclude le righe stream), `lib/services/share/` (`offers.dart`, `offer_node.dart`, `track_meta.dart`), `lib/services/library/track_file_sync.dart` (~60).
  - Passi: 1) il brano in streaming si offre come «salvato in streaming» (metadati e `videoId`, nessun file); 2) il ricevente lo crea come riga salvata; 3) i file locali restano come oggi; 4) test.
  - Comando mirato: `flutter test test/services/share/ test/services/share_notifier_test.dart test/ui/share_screen_test.dart`
  - Fatto quando: un brano in streaming offerto in LAN arriva come brano salvato in streaming.
- [ ] 140.10 Export playlist e Android Auto (D-674)
  - File: `lib/services/export/playlist_exporter.dart` (~17, filtro sui file), `lib/services/audio/media_browse_tree.dart` (~181, ~212), `lib/services/audio/codecore_audio_handler.dart` (solo se serve riprodurre da Auto), `test/services/audio/browse_handler_test.dart`.
  - Passi: 1) l'export include le righe stream con il link YouTube Music (m3u8, csv, json); 2) Android Auto mostra e riproduce i brani in streaming se c'è rete; 3) test.
  - Comando mirato: `flutter test test/services/export/ test/services/audio/browse_handler_test.dart`
  - Fatto quando: l'export di una playlist mista contiene tutte le righe; l'albero di Auto include gli stream.
- [ ] 140.11 Area e controllo di fine fase
  - Aggiorna `../architettura/online.md` (streaming per prima, cartella unica), `libreria-e-dati.md` (v22, `browseId`), `sync-backup-jam.md` (Jam: salvare; LAN con stream), `piattaforme.md` (Android Auto); «Trappole»: `lite` resta `device`. Annota in `../decisioni.md` solo deroghe nuove.

## Tocca a te
- Nessuna cosa in questa fase: la prova «aggiunte in streaming con i file locali intatti» sul Motorola è nella 147 (l'utente non deve fare nulla ora).

## Note di deviazione
