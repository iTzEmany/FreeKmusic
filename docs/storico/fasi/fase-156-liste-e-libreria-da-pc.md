# Fase 156 — Liste e libreria da PC

## Obiettivo
Le liste di brani diventano una tabella unica con intestazioni ordinabili, la selezione con Ctrl/Maiusc funziona ovunque, la Libreria ha schede, chip e griglia sensati e ricordati, Cerca ha scaffali con frecce e rotella, le testate delle collezioni sono orizzontali.

## Riferimenti
D-717, D-720, D-721. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-104, F-105, F-108, F-109, F-110, F-114, F-117, F-118, F-120), [`scansione-desktop.md`](../refactor/desktop-e-coerenza/scansione-desktop.md). Mockup: [`desktop-brani.html`](../refactor/desktop-e-coerenza/mockup/desktop-brani.html), [`desktop-libreria.html`](../refactor/desktop-e-coerenza/mockup/desktop-libreria.html), [`desktop-cerca.html`](../refactor/desktop-e-coerenza/mockup/desktop-cerca.html), [`desktop-collezioni.html`](../refactor/desktop-e-coerenza/mockup/desktop-collezioni.html). Dopo 152 e 155. Architettura: `../architettura/libreria-e-dati.md`, `../architettura/ui-e-design.md`.
Codice: `lib/ui/screens/library/all_tracks_screen.dart`, `library_screen.dart`, `library_toolbar.dart`, `library_shortcuts.dart`, `library_results.dart`, `album_detail_screen.dart`, `artist_screen.dart`, `lib/ui/widgets/track_row.dart`, `track_row_selection.dart`, `track_drag.dart` (`:41`), `segmented_blocks.dart`, `activity_button.dart`, `lib/ui/screens/online/online_song_row.dart`, `lib/ui/screens/search/search_screen.dart`, `lib/ui/screens/daylist/` (liste), `lib/data/settings/settings_store.dart` (preferenze).

## Task
- [x] 156.1 Caratterizzazione di Libreria, Cerca e selezione
  - File: `test/ui/library_screen_test.dart`, `test/ui/search_screen_test.dart`, `test/ui/track_row_selection_test.dart`, `test/ui/all_tracks_screen_test.dart`.
  - Passi: fissare schede e chip di oggi, risultati di Cerca, Ctrl/Maiusc+clic dove c'è (`selection`), ordinamento di oggi da `segmented_blocks.dart`.
  - Comando mirato: `flutter test` sui quattro file + `flutter analyze`
  - Fatto quando: verdi sul codice di oggi.
- [x] 156.2 Tabella dei brani unica (F-104, F-105)
  - File: nuovo `lib/ui/widgets/track_table.dart`, `all_tracks_screen.dart`, `online_song_row.dart` (riga tabella online), liste di album, playlist, Daylist, artista; ARB (nomi delle colonne, 6 lingue via `scripts/arb_add.py`).
  - Passi: 1) colonne n., titolo, artista, album, durata, azioni; intestazioni cliccabili che ordinano (stato dell'ordinamento nel provider della lista; indicatore e `Semantics(sortKey)`); 2) righe locali e online uguali; 3) filtro in chip o menu al posto delle due barre da 130 px; 4) **suonando da una riga la coda è la lista visibile nell'ordine mostrato** (il test di 150.2 resta verde, ora anche con l'ordinamento scelto); 5) sotto 840 px e sul telefono: le righe di oggi.
  - Comando mirato: `flutter test test/ui/all_tracks_screen_test.dart test/ui/online_song_row_test.dart test/ui/collection_pages_test.dart test/ui/alpha_scroller_test.dart`
  - Fatto quando: test: clic su «Titolo» ordina, secondo clic inverte, la riga suonata ha l'indice nella lista ordinata.
- [x] 156.3 Selezione ovunque e bersaglio di trascinamento (F-120)
  - File: `track_row.dart` (`:650-662`), `track_row_selection.dart`, tabella di 156.2, `track_drag.dart` (`:41`), `desktop_sidebar.dart`.
  - Passi: 1) Ctrl/Maiusc+clic in ogni lista di brani (album, playlist, Cerca, Daylist, online); 2) durante il trascinamento di brani sulle playlist della barra laterale la playlist sotto il puntatore si evidenzia (bersaglio visibile); 3) selezione da pressione lunga sul telefono invariata.
  - Comando mirato: `flutter test test/ui/track_row_selection_test.dart test/ui/online_song_row_test.dart`
  - Fatto quando: test di Ctrl+clic e Maiusc+clic in una lista online e in una locale; test del bersaglio evidenziato.
- [x] 156.4 Libreria: schede, chip, griglia (F-108, F-109)
  - File: `library_screen.dart`, `library_toolbar.dart`, `library_shortcuts.dart`, `settings_store.dart`, ARB.
  - Passi: 1) schede larghe quanto il testo, allineate al margine; chip che vanno a capo senza troncare; 2) griglia predefinita su schermo largo, densità regolabile; 3) scelta lista/griglia e densità **ricordate** (preferenza, non solo di sessione); 4) preferenze di layout fuori dal backup (D-739: aggiungerle alle chiavi escluse). Il clic singolo continua a suonare (D-737).
  - Comando mirato: `flutter test test/ui/library_screen_test.dart test/ui/xl_layout_test.dart`
  - Fatto quando: test: griglia al primo avvio su 1440 px, la scelta sopravvive a un riavvio simulato.
- [x] 156.5 Cerca: scaffali con frecce e rotella (F-114)
  - File: `search_screen.dart`, nuovo `lib/ui/widgets/shelf_scroller.dart`, risultati in `lib/ui/screens/youtube/online_results_sections.dart`.
  - Passi: frecce ai bordi, rotella che scorre in orizzontale sopra lo scaffale, trascinamento col mouse; le frecce spariscono ai capi; tooltip e bersagli ≥ 32 px.
  - Comando mirato: `flutter test test/ui/search_screen_test.dart test/ui/shelf_scroller_test.dart`
  - Fatto quando: test: clic sulla freccia sposta lo scaffale, segnale di rotella orizzontale idem.
- [x] 156.6 Contrasto, attività, testate (F-117, F-118, F-110)
  - File: chip in `lib/ui/screens/radio/radio_screen.dart` e `search_screen.dart`, `lib/ui/widgets/activity_button.dart`, `album_detail_screen.dart`, `artist_screen.dart`, `collection_header.dart`.
  - Passi: 1) desktop: testo minimo 13 px nei sottotitoli e chip; contrasto ≥ 4,5:1 sui chip saturi (testo scelto per luminanza); 2) indicatore di attività in posto fisso nella barra in alto, con tooltip; 3) testata orizzontale per album e artista (copertina, genere, anno, etichetta, azioni accanto), righe uguali per locale e online.
  - Comando mirato: `flutter test test/ui/a11y_guidelines_test.dart test/ui/collection_header_test.dart test/ui/album_screen_test.dart`
  - Fatto quando: test di contrasto sui chip; `_known` non cresce.
- [x] 156.7 Goldens, guardie, documenti
  - Passi: `flutter test --update-goldens test/goldens` una volta (Linux), `scripts/guardie.sh`, `flutter analyze`; `ui-e-design.md`, `libreria-e-dati.md` (preferenze).
  - Comando mirato: `flutter test test/goldens`
  - Fatto quando: verdi.

## Tocca a te
Niente.

## Note di deviazione
- 156.2: `TrackTable` (`lib/ui/widgets/track_table.dart`) è uno sliver con intestazione fissa; decide la tabella con la larghezza vera del pannello (`trackRowWide`, ≥ 840 px e pannello ≥ 520 px). `TrackQuery.descending` inverte la lista dopo la ricerca, senza query nuove. In playlist l'ordine dalle intestazioni riusa l'ordine salvato (`_saveOrder`, come il foglio di ordinamento; non sincronizzato); il primo clic usa la direzione predefinita del criterio; «#» torna all'ordine personale. Daylist: righe proprie in tabella, i brani suggeriti online restano righe senza colonne. Album a più dischi: lista con le intestazioni dei dischi, non tabella.
- 156.3: il Maiusc+clic nelle righe online usa gli id visibili nell'ordine mostrato (`OnlineSelectionScope`), così filtri e sezioni chiuse non selezionano brani nascosti. Il bersaglio di trascinamento sulle playlist della barra laterale c'era già: aggiunta la chiave per il test.
- 156.4: `libraryGrid` letta solo se `libraryGridChosen` è scritta (il vecchio codice salvava sempre `false`): anche chi aveva già l'app vede la griglia predefinita sul PC. `libraryDensity` (S/M/L con etichette «piccola/media/grande»). Tutte fuori dal backup (D-739). Schede larghe quanto il testo solo sul desktop largo (sul telefono `SegmentedBlocks`); chip che vanno a capo.
- 156.5: `ShelfScroller` (frecce da 840 px, rotella che passa alla pagina ai capi, trascinamento col mouse) negli scaffali dei risultati online (`online_results_rows.dart`).
- 156.6: i chip saturi sono i riquadri di `GenreGrid` (testo bianco/nero per contrasto, token `readableOn` in `palette.dart`); la radio ha un solo `FilterChip` non saturo. L'indicatore di attività tiene un posto fisso di 64 px nelle intestazioni (non in una barra unica). Testata orizzontale di album e artista: senza etichetta discografica (il brano non ha la colonna), generi al massimo 2.
- 156.7: golden rigenerati sulla pila; su master non cambiano.
