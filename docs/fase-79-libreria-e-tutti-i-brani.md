# Fase 79 — Libreria e Tutti i brani (refactor «ui-uso-quotidiano»)

**Obiettivo:** cambio scheda in Libreria senza lag, ricerca nella libreria con la lente che diventa barra, Tutti i brani con icone ▶/Shuffle accanto al titolo e ricerca e filtri che si nascondono scorrendo.

**Prerequisiti:** fasi 77–78 chiuse (`Skeleton`, `CcSearchField`, misura di partenza). Mockup `refactor/ui-uso-quotidiano/mockup/libreria-ricerca.html`, `refactor/ui-uso-quotidiano/mockup/tutti-i-brani.html`. Decisione D-355 (la ricerca in libreria vive qui).

**Comando mirato:** `flutter test test/ui/library_screen_test.dart test/data/library_entries_test.dart test/data/library_queries_test.dart test/ui/all_tracks_screen_test.dart test/ui/selection_lists_test.dart test/ui/track_drag_test.dart test/ui/track_actions_test.dart`.

## Task

### 79.1 — Cambio scheda senza lag (F-60, F-61, F-63, F-73, U5)
- Ordinamento e chiavi di `buildLibraryEntries` calcolati una volta per (scheda, ordinamento) fuori dal `build` (provider derivato o chiavi precalcolate in `LibraryEntry`; `library_screen.dart:143`, `library_entries.dart:55-58`); stessa cosa per `resume_rows.dart:96`.
- `_LibraryList` con `ValueKey(_kind)` (scroll non ereditato); verificare `cacheWidth` in `CoverImage`.
- Primo caricamento con righe `Skeleton` invece dello spinner (`library_screen.dart:131`).
- Test: cambio scheda non ricalcola l'ordinamento (conteggio); ordine identico a quello fissato nella 77.1.
- Misura: scenario della 77.1 su Linux e Mi A3, confronto in «Esiti» (soglia: p90 build ≤ 16 ms sul telefono, −50 % su Linux).

### 79.2 — Ricerca nella Libreria (F-08, F-26, F-27, U10)
- Tocco sulla lente (`library_screen.dart:216-222`, oggi porta a Cerca): titolo e icone Attività / + / ⋮ escono, il contenuto sotto sfuma verso il basso, la lente scivola a sinistra e il `CcSearchField` si apre attorno a lei in alto; tastiera subito. Scrivendo: risultati della libreria raggruppati (Brani, Album, Artisti, Playlist) con la ricerca locale di oggi (`_LibraryResults` di Cerca spostata qui, D-355). ✕ a vuoto o Indietro chiude con l'animazione inversa. Durate dai token, zero con riduci movimento.
- Test: lente → barra con focus; risultati raggruppati; Indietro richiude; riduci movimento senza animazione.

### 79.3 — Tutti i brani (F-13…F-17, F-67, U14)
- Titolo «Tutti i brani» con a destra due `IconButton` 48 dp ▶ e Shuffle (stesse azioni dei pill di oggi, `all_tracks_screen.dart:82-92`); titolo e conteggio scorrono via con la lista.
- `CcSearchField` e filtri: spariscono scorrendo giù, ricompaiono subito scorrendo su, anche a metà lista (`NotificationListener` sulla direzione, `SizeTransition`); niente sliver, `AlphaScroller` resta su indice × altezza (F-13).
- Query propria o svuotata al `dispose` (F-17). Caricamento con righe `Skeleton` alte come le righe vere.
- Test: barra nascosta scorrendo giù e visibile scorrendo su; icone presenti con tooltip; `AlphaScroller` porta alla lettera giusta con la barra nascosta.

### 79.4 — Controlli di fase
`flutter analyze`; comando mirato; golden `all_tracks` e library rigenerati; code-review high (lag, scroll); scheggia; misura finale di 79.1. Sul Mi A3 con la libreria grande (o sul Motorola solo `install -r`): cambio scheda, lente, Tutti i brani che scorre.

**Fatto quando:** i controlli sopra sono fatti, la misura è scritta qui e rispetta la soglia.

## Dalla review della fase 77
- `CcSearchField` prima dell'adozione in Libreria e Tutti i brani: `focusNode` opzionale (nodo interno), `onChanged` (oggi `all_tracks_screen.dart:230` lo usa) e `autofocus` (79.2 vuole la tastiera subito).
- `Skeleton` a righe: `rowHeight` opzionale (oggi 64/72 fissi) per avere righe alte come `trackRowExtentOf` (dipende da `compact` e dalla scala del testo).

## Dalla review della fase 78
- `favoriteCountProvider` (su `watchCount(favoritesOnly: true)`, come `trackCountProvider` in `library_providers.dart:95`) al posto di `tracksProvider(true)` per contare i Preferiti in `home_blocks.dart:146`, `library_screen.dart:301`, `desktop_sidebar.dart:123`: oggi il numero segue la ricerca rimasta nella schermata Preferiti e carica tutta la lista per contarla (79.1).
- Ordinamenti nel `build` della Home oltre a `resume_rows.dart:96`: `home_bottom_rows.dart:38-41` (Riscopri) e `home_blocks.dart:234-237` (Aggiunti da poco, ordina tutta la libreria); provider derivati e test sul conteggio dei ricalcoli (79.1).
- «Mostra tutti» della Home scrive in `trackQueryProvider(false)` (`home_blocks.dart:244-248`): con la query propria di Tutti i brani (F-17) si rompe in silenzio; parametro `initialSort` in `AllTracksScreen` (79.3).
- «Riproduci tutta la libreria» vive in `ShuffleHero` (`home_blocks.dart:89-113`, legge `trackOpsProvider.all()` due volte): un'azione unica (es. `playLibrary()`/`libraryIds()` nelle azioni dei brani, con `AppLog`) usata da Home e dalle icone ▶/Shuffle di Tutti i brani, poi dalla 81.1 (79.3).

## Esiti
