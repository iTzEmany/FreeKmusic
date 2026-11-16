# Fase 124 — Cerca con le classifiche

## Obiettivo
Barra di ricerca fissa in cima a Cerca anche sul telefono (il dock perde il campo di testo); senza testo, ricerche
recenti e la griglia dei 12 macrogeneri che apre «Top 20 · <genere>» dalle classifiche Deezer/Apple; i generi della
libreria passano in Libreria. Fuori: classifiche da YouTube Music, Last.fm o Spotify (D-592).

## Riferimenti
D-590, D-591, D-592, D-593, D-601, D-614; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Architettura B (tabella dei macrogeneri, cache, abbinamento), RNF-02, RNF-04, rischio F-8. Documenti d'area:
`../architettura/online.md`, `../architettura/ui-e-design.md`.

## Mockup
```text
Cerca (vuota)                        Top 20 · Pop
+--------------------------------+   +--------------------------------+
| [ Brani, artisti, album, link ]|   | Top 20 · Pop                   |
| Recenti                        |   | Classifica Deezer · Italia ·   |
|  anyma  daft punk  calcutta    |   |   aggiornata oggi alle 9:12    |
| Top 20 per genere              |   | [Riproduci]  [Casuale]         |
| [Pop] [Rap e Hip-hop] [Rock]   |   | 1 Espresso                   : |
| [Dance ed Elettronica]         |   | 2 Birds of a Feather         : |
| [R&B e Soul] [Latina e Regg.]  |   | 3 Die With A Smile           : |
| [Italiana] [Indie e Altern.]   |   | 6 Brano senza corrispondenza   |
| [Jazz] [Classica] [Metal]      |   |   Non trovato su YouTube       |
| [Country]   (12, D-591)        |   |                                |
|                                |   |                                |
| Home   Cerca   Libreria Impost.|   | Home   Cerca   Libreria Impost.|
+--------------------------------+   +--------------------------------+
```

```text
Libreria
+--------------------------------+
| Libreria                       |
| [Preferiti] [Tutti i brani]    |
| [Cronologia] [Generi]          |
|   Generi -> Generi della tua   |
|   libreria (griglia) -> genere |
+--------------------------------+
```

## Task
- [ ] 124.1 Client delle classifiche e cache di 24 ore (R-249, RNF-02, F-8)
  - File: `lib/services/online/deezer_client.dart` (`chart(int genreId, {int limit = 20})`),
    `lib/services/online/apple_rss_client.dart` (nuovo, `mostPlayed(country)`), `lib/services/online/chart_genres.dart`
    (nuovo, solo costanti), `lib/services/online/catalog_cache.dart` (`CatalogKind.chart`, 24 h),
    `lib/data/settings/settings_store.dart` (`chartCountry`), fixture in `test/fixtures/deezer/` e `test/fixtures/`
    (salvate una volta dal vivo, mai rete nella suite), `test/services/online/apple_rss_client_test.dart` (nuovo).
  - Passi:
    1. Salvare le fixture (un genere Deezer, feed Apple `it` e uno di un altro paese); annotare se Deezer segue l'IP.
    2. `chart` con `_getPaged` (pausa di 5 s sul codice 4); `mostPlayed` con `WebClient.getJson`, filtro per `genres[].name`.
    3. `chart_genres.dart`: i 12 macrogeneri con ID Deezer (principale e ripiego) e generi Apple, come la tabella § B.
    4. Chiave di cache `chart:<genere>:<paese>`; la voce tiene i 20 brani e gli abbinamenti.
  - Comando mirato: `flutter test test/services/online/deezer_client_test.dart test/services/online/apple_rss_client_test.dart test/services/online/catalog_cache_test.dart` (più `flutter analyze`)
  - Fatto quando: i client leggono le fixture; con orologio finto la voce è fresca a 23 h e scaduta a 25 h, e da
    scaduta resta leggibile con la sua data.

- [ ] 124.2 Pagina «Top 20 · <genere>» (R-248, R-249, RNF-02)
  - File: `lib/providers/online_collection_providers.dart` (`ChartRef`, ramo in `onlineCollectionProvider` e
    `onlineMatchesProvider`, `refreshOnlineCollection`, `retryOnlineCollection`), `lib/ui/screens/online/online_playlist_screen.dart`
    (`_external` diventa `is! YoutubeListingRef`; riga «Classifica Deezer · <paese> · aggiornata …»), voce «Paese delle
    classifiche» nelle impostazioni Online, ARB, `test/goldens/screens_golden_test.dart`.
  - Passi:
    1. Test prima: cache fresca → nessuna chiamata ai client né ricerche YouTube (RNF-02); errore Deezer → Apple filtrato;
       senza rete → copia scaduta con la data; abbinamento per titolo + artista + durata scritto nella voce di cache.
    2. Ramo `ChartRef`; paese da `PlatformDispatcher.instance.locale.countryCode` o da `chartCountry`; «Italiana» sempre `it`.
    3. Riproduci, Casuale, coda e menu del brano come le playlist esterne; righe non trovate grigie.
  - Comando mirato: `flutter test test/providers/online_collection_providers_test.dart test/goldens/screens_golden_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test e golden della pagina verdi; su Linux il riquadro «Rock» apre 20 brani suonabili e riaprirlo
    nello stesso giorno non fa ricerche (log del budget).

- [ ] 124.3 Barra fissa, dock e griglia dei macrogeneri (R-247, R-248, RNF-04)
  - File: `lib/ui/screens/search/search_screen.dart` (`showField` sempre vero; `_EmptyQuery`: recenti, poi `GenreGrid` dei
    macrogeneri al posto dei generi locali), `lib/ui/shell/bottom_bar.dart` (via `_SearchField`), `lib/providers/ui_providers.dart`
    (via `searchBarProvider`), `lib/ui/shell/shell_nav.dart`, `lib/ui/shell/app_shell.dart`, ARB,
    `test/ui/search_screen_test.dart`, `test/ui/search_dock_test.dart`, golden di Cerca vuota.
  - Passi: 1. barra sempre in cima; 2. il tasto Cerca del dock apre la scheda e chiama `searchFocusProvider.requestFocus()`;
    3. 12 riquadri colorati con etichetta TalkBack; il tocco apre `OnlinePlaylistScreen(OnlineCollectionRef.chart(g))`.
  - Comando mirato: `flutter test test/ui/search_screen_test.dart test/ui/search_dock_test.dart test/goldens/screens_golden_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: scorrendo la griglia la barra resta visibile; il tasto del dock dà il fuoco al campo; i 12 riquadri
    hanno etichette semantiche (test); sul Mi A3 la tastiera si apre dal dock.

- [ ] 124.4 «Generi» in Libreria (R-250, RNF-04)
  - File: `lib/ui/screens/library/library_screen.dart` (nuova `LibraryShortcut` «Generi», elenco a `:399-446`),
    `lib/ui/screens/library/library_genres_screen.dart` (nuovo: `genresProvider` + `GenreGrid` → `GenreScreen`), ARB,
    `test/ui/library_screen_test.dart`.
  - Passi: 1. spostare il blocco dei generi locali tolto da `_EmptyQuery`; 2. voce in Libreria; Radio invariata.
  - Comando mirato: `flutter test test/ui/library_screen_test.dart test/ui/genre_grid_test.dart test/ui/radio_home_library_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: da Libreria «Generi» apre la griglia dei generi locali e un genere apre `GenreScreen` (test).

## Tocca a te
Niente.

## Note di deviazione

- 124.1: la classifica Deezer non ha parametro paese: `/chart/<id>/tracks` con `country=US` o con `X-Forwarded-For` ha dato gli stessi 20 id della richiesta semplice, quindi segue l'IP di chi chiama (verificato dal vivo il 16/11/2026, da qui in Italia). Il paese scelto in `chartCountry` vale quindi solo per il feed Apple; la pagina deve scrivere «Deezer · <paese dell'IP>» o evitare di promettere il paese scelto (da decidere in 124.2).
- 124.1: i nomi dei generi del feed Apple sono tradotti per paese (feed `it`: «Latina», «Alternativa», «Elettronica»; `us`: «Latin», «Alternative»), quindi il filtro usa `genres[].genreId` (stabile: 14 Pop, 18 Hip-Hop/Rap, 21 Rock, 17 Dance, 7 Electronic, 15 R&B/Soul, 12 Latin, 20 Alternative, 2 Jazz, 5 Classical, 1153 Metal, 1152 Hard Rock, 6 Country) e non il nome. `chartCountry` è una stringa vuota = segue il locale (come `radioCountry`), non null.
