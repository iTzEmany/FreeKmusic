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

### 79.1 — Misura dopo (2026-11-04, commit 79.2 prima delle correzioni della review)
Linux (`integration_test/perf_test.dart`, xvfb, debug, 3000 brani; p50/p90/max ms):

| Scenario | Run | Frame | Build p50/p90/max | Raster p50/p90/max |
|---|---|---|---|---|
| Tutti i brani | 1 | 251 | 0,8 / 5,7 / 10,2 | 19,4 / 30,3 / 32,8 |
| Tutti i brani | 2 | 252 | 0,8 / 6,0 / 11,1 | 18,3 / 29,9 / 37,3 |
| Album | 1 | 260 | 1,7 / 8,6 / 14,8 | 9,7 / 23,8 / 28,3 |
| Album | 2 | 259 | 1,5 / 8,8 / 17,3 | 8,7 / 24,4 / 28,0 |
| **Libreria Tutto→Playlist→Album→Artisti** | 1 | 114 | 1,1 / 15,0 / 53,9 | 10,5 / 16,7 / 25,4 |
| **Libreria Tutto→Playlist→Album→Artisti** | 2 | 116 | 0,9 / 14,2 / 55,7 | 11,2 / 17,4 / 26,2 |
| Ricerca | 1 | 255 | 0,8 / 5,4 / 30,4 | 12,3 / 24,9 / 27,7 |
| Ricerca | 2 | 258 | 1,0 / 6,6 / 30,0 | 14,9 / 26,4 / 28,8 |

Mi A3 (`perf_device.py --label 79-dopo`, profile, 3000 brani; p50/p90/p99 ms):

| Scenario | Frame | build p50/p90/p99 | raster p50/p90/p99 | > 16,7 ms |
|---|---|---|---|---|
| Tutti i brani | 546 | 1,7 / 5,4 / 9,9 | 6,1 / 15,4 / 23,7 | 5,9 % |
| Album | 1181 | 1,9 / 5,6 / 8,0 | 5,3 / 7,3 / 12,7 | 0,7 % |
| **Libreria Tutto→Playlist→Album→Artisti** | 3944 | 2,9 / 6,8 / 10,9 | 5,9 / 9,7 / 19,4 | 4,4 % |

- **Telefono**: p90 build 6,8 ms, sotto la soglia di 16 ms (era 6,6: il ricalcolo di F-60 non si vedeva già nei percentili); p99 11,8 → 10,9 ms.
- **Linux**: p90 build 10,1 / 23,6 → 15,0 / 14,2 ms (media −14 %), max 53 / 103 → 54 / 56 ms (−46 % sul peggiore). **La soglia del −50 % non è raggiunta**: il rendering software dà ±100 % fra due run (77.1: 10,1 contro 23,6), quindi con due run il confronto non distingue. Il picco di ~55 ms resta alla prima visita di ogni scheda (ordinamento e primo layout); le visite successive riusano la lista. Da rimisurare nella 83.1 con run alternate A/B.
- `perf_test.dart` usciva rosso alla fine per un errore nel `dispose` di Tutti i brani (scrittura di un provider durante lo smontaggio): corretto dalla review.

### 79.4 — Controlli (2026-11-04)
- `flutter analyze` pulito; comando mirato verde; golden `all_tracks` nuovo (phone/desktop 100/150), `selection` rigenerato (intestazione di Tutti i brani cambiata); `library` e `home` invariati.
- Review di architettura della fase 78 portata qui: `favoriteCountProvider` e conteggi da `watchCount` (ora senza brani mancanti o nascosti, come le liste), ordinamenti della Home in provider derivati, `playLibrary`/`libraryIds` in `track_ops.dart`, «Mostra tutti» con `initialSort` senza scrivere nella query condivisa.
- Code review Opus (lag, scroll, query): 6 bug corretti (scrittura di un provider nel `dispose` di Tutti i brani, ✕ che non svuotava i risultati, barra che poteva restare nascosta su una lista corta, conteggi con mancanti/nascosti, Indietro con selezione attiva che chiudeva la ricerca, scroll perso aprendo la ricerca) e 3 miglioramenti (debounce e indice preparato nella ricerca della Libreria, conteggio della Home con `trackCountProvider`, animazione della barra non riavviata).
- Scheggia di passo: nessun bug; test rinforzati (ordinamento con simboli e accenti, ricerca con spazi, chiusura prima del debounce). Nota: titoli in cirillico, greco o CJK finiscono nel blocco «#» con cifre e simboli (`sortKeyOf` riconosce solo a–z), come prima.
- Scelta: in Tutti i brani titolo, ▶/Shuffle, campo e filtri si nascondono e tornano insieme (senza sliver il titolo non può scorrere con la lista senza toccare `AlphaScroller`).
- **Mi A3** (APK debug 134e91a, libreria del telefono, D-377): cambio scheda veloce ×3 senza lag visibile, ogni scheda col suo scroll; lente → barra con tastiera, risultati raggruppati, ✕ svuota poi chiude, lista ritrovata dov'era; Tutti i brani con barra che sparisce e torna a metà lista, A–Z, ▶; Preferiti «2» uguale in Home, Libreria e lista. Nessuna eccezione nel log.
