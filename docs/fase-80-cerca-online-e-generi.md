# Fase 80 — Cerca solo online e generi misti (refactor «ui-uso-quotidiano»)

**Obiettivo:** Cerca diventa solo online, con ricerche recenti e generi in griglia da 3; un genere apre una pagina mista con 2 brani della libreria e 1 suggerito online; nella build senza YouTube Cerca sparisce. Shuffle+ espone lo stato «in preparazione» che serve qui e nella fase 81.

**Prerequisiti:** fase 79 chiusa (la ricerca in libreria sta già in Libreria). Mockup `refactor/ui-uso-quotidiano/mockup/cerca.html`. Decisioni D-355, D-356, D-358, D-359, D-360. Area a rischio: `lib/services/shuffle_plus/shuffle_plus_controller.dart`.

**Comando mirato:** `flutter test test/ui/search_screen_test.dart test/ui/search_dock_test.dart test/ui/search_sources_test.dart test/ui/genre_screen_test.dart test/providers/shuffle_plus_test.dart test/services/shuffle_plus`.

## Task

### 80.1 — Cerca solo online (F-05…F-07, F-22, F-28, U4, U10, D-355, D-358, D-360)
- Via il segmento Libreria/Online (`search_screen.dart:274-297`), `_goOnlineIfNoLocal` (:138-155), i chip Preferiti/Recenti (:240-272) e i parametri di `SearchQuery` rimasti senza usi. Il prefill della Radio (`_applyPrefill` :71-81) continua a funzionare.
- Sotto la barra: Ricerche recenti (✕ con la query nell'etichetta, F-22) e Generi della libreria ordinati per numero di brani, in griglia uniforme da 3 colonne (6 su desktop), celle ≥ 56 dp, testo fino a 2 righe.
- Con `CODECORE_YOUTUBE=false` la scheda Cerca non c'è nel dock né nella barra laterale (D-358).
- Riscrivere i test dei risultati locali. Test nuovi: nessun risultato locale; generi ordinati; Cerca assente senza YouTube.

### 80.2 — Stato «in preparazione» di Shuffle+ (F-53)
- Provider osservabile (es. `shufflePlusPendingProvider`) con il numero di suggeriti in arrivo e gli id del blocco in arricchimento, alimentato da `_suggestOne` / `_block` / `_enriching` (`shuffle_plus_controller.dart:81-86,133-135,357,408-411`), senza cambiare l'ordine né il numero dei suggeriti.
- Test: lo stato riporta 3 in arrivo all'avvio, scende quando entrano, segue il blocco in arricchimento, torna a 0 con Shuffle+ spento.

### 80.3 — Pagina del genere mista (D-356, D-359)
- `GenreScreen`: brani della libreria del genere con un suggerito online ogni 2 (libreria, libreria, suggerito), seme dai brani locali del genere, motore di Shuffle+ (stessi limiti: rete a consumo, Jam, strumento assente → solo libreria con un avviso). Il suggerito ha l'etichetta «Suggerito» con icona online; quelli in arrivo sono righe `Skeleton` (stato della 80.2). Icone ▶ e Shuffle in alto.
- Test: rapporto 2:1; semi presi dai brani del genere; righe skeleton poi riempite; senza rete solo libreria.

### 80.4 — Controlli di fase
`flutter analyze`; comando mirato; golden `search` rigenerato e `genre` nuovo; build lite (`--dart-define=CODECORE_YOUTUBE=false`) che compila senza Cerca; code-review high (Shuffle+); scheggia. Sul Mi A3: Cerca, un genere con suggeriti che arrivano, Radio → Cerca con prefill.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Dalla review della fase 78
- Griglia dei generi: la regola 4/3/2 colonne di `GenresSection` (`radio_sections.dart:230-298`) va estratta in un widget comune (es. `lib/ui/widgets/genre_grid.dart`, uno sliver con `mainAxisExtent`, perché i generi della libreria sono in numero libero e `shrinkWrap` li costruirebbe tutti) e usata da Radio e Cerca (3 colonne, 6 su desktop); poi via `_GenrePill` (`search_screen.dart:348-395`). `ValueKey('genre-$tag')` resta (80.1).
- Riquadro `surface1` + `rCard` + `InkWell` + `Semantics` fatto a mano in `_Shortcut`, `HomeBlock`, celle dei generi: un componente `CcTile` (child, onTap, semanticsLabel, color, minHeight) nato con la griglia della 80.1 e riusato da 81.1 e 82.x; senza riscrivere le altre schede.

## Dalla review della fase 79
- Ciclo d'import fra `library/library_search.dart` (:23-24) e `search/search_screen.dart` (:30): `SearchTracksScreen`, `SearchSectionScreen`, `SearchResultRow`, `SearchSectionKind` servono solo alla ricerca in Libreria → in `lib/ui/screens/library/` (il file UI va rinominato, es. `library_results.dart`, per non confondersi con `data/repositories/library_search.dart`); `localResults(read)` diventa `libraryResultsProvider` (family autoDispose sul testo, `searchLibrary` con limiti) invece di ricalcolare a ogni build; via `SearchQuery.favorites/recent/quick`, `quickFilter` e `applyQuickFilters` rimasti senza usi; `searchPrefillProvider` da `radio_providers.dart:141` a `ui_providers.dart` (80.1).
- Ctrl+F (`app_shell.dart:84-89`) apre sempre Cerca: senza YouTube (D-358) porta a una scheda che non c'è, e la ricerca locale ora vive in Libreria. Un contatore `librarySearchRequestProvider` ascoltato da `LibraryScreen` (apre la lente); Ctrl+F lo usa senza YouTube o se la scheda corrente è Libreria, altrimenti Cerca. Un test per caso (80.1).
- Regressione della 79: digitare nella ricerca della Libreria e di Tutti i brani non chiama più `userActivityProvider.touch()` (prima lo faceva Cerca, `search_screen.dart:101-104`), e l'arricchimento in sottofondo non sa che l'utente sta scrivendo. Un `onQuery(String)` in `CcSearchField` con debounce, trim, confronto col precedente, timer annullato al dispose, subito su invio e `touch()`; usato da Libreria e Tutti i brani (80.1), poi dai campi migrati nella 83 (D-378).
- Skeleton a righe ricopiato in tre varianti (`async_body.dart:78-93` `_RowsLoading`, `all_tracks_screen.dart:336-344`, `library_screen.dart:180-184`): `AsyncBody`/`SliverAsyncBody` con `rowHeight` e una sola implementazione del ritaglio, prima dell'uso nella pagina del genere (80.3), poi 81.3 e 82.4.
- `docs/02-architettura.md` è rimasto indietro (:73 «3 schede», :228 chip Preferiti/Recenti, :300 «Due modi: In libreria e Online»): riscriverlo alla 80.4 con ricerca locale in Libreria, `libraryEntriesProvider`, `libraryResultsProvider`, Cerca solo online.

## Esiti
