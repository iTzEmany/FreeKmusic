# Fase 141 — Collezioni: intestazione, preferiti, scorrimento

## Obiettivo
Le 8 pagine di `CollectionScaffold` hanno la stessa testata a icone (Riproduci 56 px in accento; Casuale, Scarica e ⋮ a 48 px, con etichetta per il lettore di schermo e tooltip); album e playlist si possono mettere nei preferiti (migrazione v23, backup incluso); una barra di scorrimento laterale sottile compare sopra 100 elementi in libreria, preferiti, playlist, album, artisti e cronologia. Fuori: il tasto «Condividi» (lo aggiunge la 145, quando esiste il link esterno: D-677), sfondo opaco delle testate (già tolto nella 138).

## Riferimenti
D-676, D-677, D-688, D-694, D-687, D-675, D-662, D-699. Rilievi F-34, F-35, F-37 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); `scansione-ui.md` (punti 8, 9), `scansione-dati.md` (punto 6); rete.md riga 141. Mockup: `mockup/collezione.html` (testata a icone, scorrimento laterale), nella cartella `../refactor/grande-revisione/mockup/`. Aree: `../architettura/ui-e-design.md`, `libreria-e-dati.md`, `sync-backup-jam.md`. Backup e `backup_merge_tables.dart` sono area a rischio: review `/code-review high` sulle parti di dati. Schema oggi v22, in questa fase v23.

## Task
- [ ] 141.1 Migrazione v23: preferiti di album e playlist (F-37; D-675; in un solo passo) — review: `/code-review high`
  - File: `lib/data/db/tables.dart` (tabella `FavoriteCollections(kind, key)`), `lib/data/db/app_database.dart` (`kSchemaVersion` 23, `onUpgrade`), codice drift generato, `lib/data/repositories/favorite_collections_repository.dart` (nuovo), `test/data/migration_test.dart`, `test/data/favorite_collections_test.dart` (nuovo).
  - Passi: 1) tabella con chiave composta `(kind, key)` (kind album/playlist; chiavi stabili `artistKey` e simili, non id volatili); 2) `dart run build_runner build --delete-conflicting-outputs`; 3) repository: aggiungi/togli/osserva; 4) test v22 → v23 e repository.
  - Comando mirato: `flutter test test/data/migration_test.dart test/data/favorite_collections_test.dart`
  - Fatto quando: la migrazione non modifica righe esistenti; schema = 23.
- [ ] 141.2 Preferiti di collezioni: backup e sync (F-37) — review: `/code-review high`
  - File: `lib/data/repositories/backup_merge_tables.dart`, `lib/data/repositories/backup_merge.dart`, `lib/services/backup/user_data.dart`, `lib/services/backup/backup_service.dart`, `lib/data/repositories/playlist_sync_repository.dart` (solo se il sync delle playlist li deve portare: la sincronizzazione completa è della 146), `test/data/backup_merge_tables_test.dart`.
  - Passi: 1) i preferiti di collezione entrano nel backup (campo opzionale: formato retrocompatibile) e nel merge; 2) andata e ritorno nel test; 3) «Sostituisci» li riporta.
  - Comando mirato: `flutter test test/data/backup_merge_tables_test.dart test/data/backup_merge_test.dart test/services/backup/`
  - Fatto quando: un backup con 2 album e 1 playlist preferiti si ripristina e si fonde senza duplicati.
- [ ] 141.3 Preferiti in UI: sezioni e cuore (F-37)
  - File: `lib/ui/screens/library/favorites_screen.dart`, `lib/ui/widgets/favorite_actions.dart`, `lib/providers/library_providers.dart` o un provider nuovo `favorite_collections_providers.dart`, ARB ×6.
  - Passi: 1) sezioni «Album» e «Playlist» in Preferiti; 2) il cuore nel menu ⋮ delle pagine album e playlist; 3) i provider sono l'unico accesso della UI (D-24); 4) test di widget.
  - Comando mirato: `flutter test test/ui/collection_pages_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: un album messo nei preferiti compare in Preferiti e sparisce togliendolo.
- [ ] 141.4 Testata a icone: componente (F-34; D-676; mockup `collezione.html`)
  - File: `lib/ui/widgets/collection_header.dart` (~82-89, `PlayPill`, `ShufflePill`, menu in un `Wrap`; `CollectionScaffold`), `test/ui/collection_header_test.dart`.
  - Passi: 1) varianti a sola icona: Riproduci 56 px in accento, Casuale, Scarica e ⋮ a 48 px; ognuna con `Semantics` e tooltip; 2) le icone senza senso in una pagina si nascondono (parametri per pagina); 3) il widget non ha sfondo proprio (D-687); 4) test sulla semantica delle icone per collezione.
  - Comando mirato: `flutter test test/ui/collection_header_test.dart test/ui/a11y_guidelines_test.dart test/ui/architecture_test.dart`
  - Fatto quando: il test verifica 48/56 dp, etichette e tooltip; i test di accessibilità restano verdi.
- [ ] 141.5 Testata a icone: album, playlist e preferiti (F-34; D-676)
  - File: `lib/ui/screens/library/album_detail_screen.dart` (~263, «Condividi» LAN: passa nel menu ⋮ come «Invia a un dispositivo», D-677), `lib/ui/screens/playlists/playlist_detail_screen.dart` (~115, ~235, «Esporta…»), `lib/ui/screens/library/favorites_screen.dart`, `lib/ui/widgets/keep_offline_action.dart` (`keepOfflineFlow`, per «Scarica»), ARB ×6.
  - Passi: 1) usare il componente di 141.4; 2) «Scarica» = `keepOfflineFlow`; 3) «Invia a un dispositivo» e «Esporta…» nel menu ⋮; 4) golden `album` e `playlist`.
  - Comando mirato: `flutter test test/ui/collection_pages_test.dart test/ui/collection_header_test.dart test/ui/architecture_test.dart`
  - Fatto quando: le tre pagine hanno una sola testata a icone; golden rivisti.
- [ ] 141.6 Testata a icone: artista, genere, etichette, smart playlist, podcast (F-34; D-676)
  - File: `lib/ui/screens/library/artist_screen.dart`, `lib/ui/screens/search/genre_screen.dart`, `lib/ui/screens/tags/tags_screen.dart`, `lib/ui/screens/smart/smart_playlist_screen.dart`, `lib/ui/screens/podcast/podcast_detail_screen.dart`.
  - Passi: 1) stesso componente; per ogni pagina decidere quali icone hanno senso (es. «Scarica» assente dove non c'è nulla da scaricare); 2) golden `genre`, `artist`, `podcast`.
  - Comando mirato: `flutter test test/ui/collection_pages_test.dart test/ui/collection_header_test.dart test/ui/architecture_test.dart`
  - Fatto quando: le 8 pagine hanno una sola testata (metrica di rete.md); golden rivisti.
- [ ] 141.7 Barra di scorrimento «per posizione» (F-35; D-688, D-694; mockup `collezione.html`)
  - File: `lib/ui/widgets/alpha_scroller.dart` (~20; oggi 28 dp su desktop), `test/ui/alpha_scroller_test.dart`, `test/ui/alpha_scroller_offset_test.dart`.
  - Passi: 1) modalità «per posizione» con fumetto (lettera o posizione); 2) sottile e quasi invisibile da ferma; compare mentre si scorre; al tocco o trascinamento si allarga (maniglia ≥ 48 dp) e resta larga finché la si usa; 3) assente sotto i 100 elementi; 4) test.
  - Comando mirato: `flutter test test/ui/alpha_scroller_test.dart test/ui/alpha_scroller_offset_test.dart test/ui/a11y_guidelines_test.dart`
  - Fatto quando: sopra 100 elementi la barra compare, sotto no; il tocco la allarga (test).
- [ ] 141.8 Barra di scorrimento nelle liste (F-35; D-688)
  - File: `lib/ui/screens/library/all_tracks_screen.dart` (~208, ~256), `lib/ui/screens/library/library_screen.dart` (album, artisti), `lib/ui/screens/library/favorites_screen.dart`, `lib/ui/screens/playlists/playlist_detail_screen.dart`, `lib/ui/screens/playlists/playlists_screen.dart`, `lib/ui/screens/history/history_screen.dart`.
  - Passi: 1) inserire la barra in ciascuna lista con la modalità giusta (alfabetica quando l'ordine è per titolo/artista, altrimenti per posizione); 2) test su almeno due liste (non una per schermata).
  - Comando mirato: `flutter test test/ui/all_tracks_screen_test.dart test/ui/library_screen_test.dart test/ui/history_screen_test.dart test/ui/collection_pages_test.dart`
  - Fatto quando: la barra compare nelle sei liste sopra 100 elementi; i test esistenti sono verdi.
- [ ] 141.9 Area e controllo di fine fase
  - Aggiorna `../architettura/ui-e-design.md` (testata a icone, scorrimento), `libreria-e-dati.md` (v23, `FavoriteCollections`), `sync-backup-jam.md` (backup con i preferiti di collezione); «Trappole»: «Condividi» arriva con la 145. `scripts/guardie.sh` (golden) prima del push.

## Da allineare (review di architettura della fase 138)
- Testate e `Scaffold` con `cc.bg` opaco che coprono l'immagine del tema (D-687), da decidere una per una: `online/online_page_frame.dart:51,83`, `lyrics/lyrics_screen.dart:50`, `lyrics/lyrics_editor.dart:109`, `lyrics/lyrics_romanization_editor.dart:89`, `onboarding/onboarding_screen.dart:72`, `shell/desktop_sidebar.dart:63`, `activity/activity_log_screen.dart:318` (solo senza backdrop); `car/car_mode_screen.dart:64` probabilmente voluto.
- `SectionHeader` fuori da una superficie: `releases/top_artists_card.dart` (bordi `cc.separator`), `stats_screen.dart:333`, `memory_screen.dart`, `podcasts_screen.dart:122,276`, `radio_sections.dart`, `artist_screen.dart`, `online_results*.dart`, `search_screen.dart:181,208`, `queue_sheet.dart`: liste di pagina (D-687, senza sfondo) o blocchi, da decidere caso per caso.
- Larghezza dei fogli: costante `CcDims.sheetMaxWidth` al posto dei quattro `560` (`cc_sheet.dart:31`, `app_theme.dart:151`, `onboarding_screen.dart:76`); `devices_sheet` usa il default di `showCcSheet` (oggi lo copia) e ha un test sulla larghezza.
- `ShrinkingHeader` dopo D-705 è quasi un `SliverToBoxAdapter` con un controller: togliere il `ClipRect` (commento inesatto) e il test che ne controlla solo la presenza, o rinominarlo.
- `LogEntryCard.onHow` diventa `required` (un solo chiamante; `onHow ?? onTap` riapre F-31).
- `autofocus: true` nei campi dei dialoghi (`prompt_name.dart:61`, `move_to_album_dialog.dart:98`, `jam_remote_sheets.dart:189` che è un foglio, `jam_remote_settings.dart:187`, `pairing_dialogs.dart:79`): decidere se D-667 vale anche lì (per il foglio della Jam sì).
- Focus alla ricerca col clic su «Cerca» nella barra laterale su desktop (tolto in 138.2 insieme al telefono): rimetterlo solo su desktop se serve.
- Test deboli: `create_flows_test.dart:~53` (flag `autofocus`, basta il focus effettivo); nessun test che il tasto Cerca della shell non dia focus.

## Da allineare (review fase 140)
- Dalla fase 139 (spostati qui): menu del brano che suona con la voce online legata a una riga salvata (`entry.trackId`; `TrackDeleter.removeFromQueue` toglie anche le voci online degli id cancellati); stato del brano calcolato in quattro modi (`inLibraryOfProvider`, `entryInLibrary`, `downloadIndex.contains`, ramo `#` di `trackStateProvider`) da ridurre a `trackStateProvider(key)`; I/O sincrono dell'indice dei download (`pathForKey` → `existsSync`, `signatureMatchesPath`, `pruneGone`) da spostare fuori dal thread UI; menu ⋮ che si blocca se il widget che l'ha aperto viene smontato (foglio come `Consumer` con il proprio `ref`, test).
- Stato unico del brano (punto 4 della review 140) e I/O sincrono dell'indice (punto 5): vedi sopra, si fanno insieme.
- `albumBrowseId` perso in `mergeStreamRow` e `demoteToStream`: conservarlo quando la riga viene fusa o declassata.
- Le preferenze iniettate in `PlaylistImportService` e il parametro `streaming` ormai morto (D-665: l'import salva sempre in streaming): toglierli.
- `OnlineSelectionScope` doppio nella pagina album (141.5): lasciarne uno solo.

## Tocca a te
- Nessuna cosa in questa fase.

## Note di deviazione
