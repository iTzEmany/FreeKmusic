# Fase 110 — Libreria e playlist

**Obiettivo:** via «Statistiche» dalla Libreria, al suo posto «Scaricati senza playlist»; ricerca nel dettaglio delle playlist (normali e intelligenti); la ricerca ignora gli accenti. **Cambi di comportamento voluti** (D-484, D-485, D-490, D-500).

**Prerequisiti:** fase 109 chiusa. Analisi F-136..F-143 e «Rete» righe E, F. Mockup approvati: `refactor/coda-e-libreria/mockup/libreria.html` (D-484, D-485), `refactor/coda-e-libreria/mockup/playlist-ricerca.html` (D-490) (D-498). Aree a rischio: query su `tracks` (righe ombra K-02, `/code-review high`), query delle liste e della ricerca. Schema DB e backup invariati (D-491).

**Comando mirato:** `flutter test test/core/text_utils_test.dart test/data/track_repository_test.dart test/data/library_search_test.dart test/data/performance_50k_test.dart test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/settings_index_test.dart test/ui/stats_screen_test.dart test/ui/home_screen_test.dart test/ui/collection_pages_test.dart test/ui/smart_playlists_test.dart test/ui/playlist_sort_test.dart test/ui/settings_and_playlists_test.dart test/goldens/screens_golden_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

## Task

### 110.1 — «Statistiche» fuori dalla Libreria, dentro Impostazioni (F-136, D-484)
- Togliere la scorciatoia `screens/library/library_screen.dart:440-443` e l'import `:48`. Voce fissa «Statistiche» in Impostazioni (indice delle impostazioni, vicino a «Memoria»; `StatsScreen` e query `stats_queries` invariate). Il blocco «Il tuo mese» in Home (`home/home_bottom_rows.dart:108`, ≥ 10 ascolti) resta com'è.
- Test: `settings_index_test.dart` (voce Statistiche); `library_screen_test.dart:659-690` (blocchi della griglia); `stats_screen_test.dart` e `home_screen_test.dart` verdi senza modifiche; golden di Libreria e Impostazioni (`screens_golden_test.dart:45`).
- Controllo: `grep -rn "StatsScreen" lib/ui/screens/library` = 0 righe.

### 110.2 — Stream «Scaricati senza playlist» (F-137, F-138, D-485)
- `TrackRepository`: stream nuovo con `kind = 0 AND missing = 0 AND ignored = 0 AND folder_id = <cartella download> AND NOT EXISTS (playlist_tracks …)` (cartella: `resolveDownloadFolder`, `folder_ops.dart:24`). Sempre `kind = 0` (K-02: righe ombra `kind = 2` ed episodi `kind = 1` esclusi). Playlist intelligenti (solo regole, `tables.dart:200`) e Preferiti (`tracks.is_favorite`) non contano come playlist.
- Test `track_repository_test.dart`: righe `kind=1`/`kind=2` escluse; preferito e playlist intelligente contano come «senza playlist»; playlist normale esclusa; fuori dalla cartella download escluso.

### 110.3 — Sorgente nuova in `AllTracksScreen` e voce in Libreria (F-139, D-485)
- `screens/library/all_tracks_screen.dart:110,182`: parametro facoltativo della sorgente (`trackQueryProvider`/`watchTracks`), così la lista ha ricerca, ordinamento e scorrimento A–Z come «Tutti i brani». Scorciatoia «Scaricati senza playlist» al posto di «Statistiche» nella griglia della Libreria, come in `libreria.html`.
- ARB (it, en, de, es, fr, pt; `scripts/arb_add.py`, `flutter gen-l10n`): titolo della lista, voce della Libreria e testo di lista vuota.
- Test: `all_tracks_screen_test.dart` (la sorgente nuova); `library_screen_test.dart`.

### 110.4 — Ricerca nel dettaglio playlist (F-140, F-141, D-490)
- `screens/playlists/playlist_detail_screen.dart:212-345`: `CcSearchField` (`widgets/cc_search_field.dart`) sopra la lista, filtro in Dart su titolo, artista, album, maiuscole e accenti ignorati con `normalize` (`lib/core/text_utils.dart:30`).
- Con una ricerca attiva: riordino e modifica spenti (`:250`, `ops.reorder(id, from, to)`); rimozione con l'indice **originale** nella lista intera (`:265-266`, `removeTrack(index:)`); toccando un risultato suona **tutta** la playlist da quel brano.
- Test (`collection_pages_test.dart` / `settings_and_playlists_test.dart`): tocco su un risultato suona la playlist intera da lì; riordino spento; rimozione con l'indice originale (il brano giusto sparisce); `playlist_sort_test.dart` verde.
- Filtro su testo in `test/core/text_utils_test.dart`: titolo/artista/album, maiuscole e accenti.

### 110.5 — Playlist intelligente e ricerca senza accenti nella Libreria (F-142, F-143, D-490, D-500)
- `screens/smart/smart_playlist_screen.dart:27`: stesso campo di ricerca e stesso filtro di 110.4 (test in `smart_playlists_test.dart`).
- Ricerca della Libreria senza accenti, **lato app** (D-500): filtro Dart sui brani già caricati con `normalize`/`stripDiacritics`, come la ricerca degli artisti (`lib/data/repositories/library_search.dart:42-49`); si lascia il `LIKE` di `track_repository.dart:490-497` solo dove non serve più. Il test di 107.3 («e» non trova «é») si rovescia: «e» trova «é»; test anche in `library_search_test.dart` e `library_screen_test.dart:472` se cambia il layout.
- **Soglie:** `flutter test test/data/performance_50k_test.dart` con la misura della lista nuova e della ricerca senza accenti, dentro le soglie già presenti; se non reggono, si riporta a D-500 (non si cambia strada senza chiedere).

### 110.6 — Controlli di fase
`flutter analyze`; comando mirato; `git diff origin/master -- lib/data/db/tables.dart lib/services/backup` vuoto e `schemaVersion` invariato; `/code-review high` sulla query nuova e sul filtro; prova sul Mi A3 con `~/Downloads/Liked_Songs.csv` importato come playlist (D-503) contro `libreria.html` e `playlist-ricerca.html`. Ripulire il telefono.

**Fatto quando:** la Libreria mostra «Scaricati senza playlist» e non «Statistiche» (raggiungibili da Impostazioni), le playlist si cercano senza accenti senza rompere riordino e rimozione, i test e `performance_50k_test.dart` sono verdi.

## Da decidere
(nessuno)
