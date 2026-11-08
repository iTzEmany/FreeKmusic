# Fase 99 — Debito: 429, chiave artista, scaffali, paesi (refactor «ascolto-quotidiano»)

**Obiettivo:** chiudere il debito di `prossimi-lavori.md` §6 «Media» che sta sulla strada delle fasi 100–104. **Nessun cambio di comportamento.**

**Prerequisiti:** fase 98 chiusa. Analisi: `refactor/ascolto-quotidiano/analisi.md` F-116..F-119 e «Arrivo — struttura». Decisioni D-442. Mockup: nessuno. Aree a rischio: query su `tracks` (99.4, `/code-review high`).

**Comando mirato:** `flutter test test/services/online/ test/providers/artist_merge_providers_test.dart test/ui/artist_picker_sheet_test.dart test/ui/artist_page_test.dart test/providers/artist_shelves_providers_test.dart test/data/filter_counts_test.dart test/data/watch_with_countries_test.dart test/services/shuffle_plus/`

## Task

### 99.1 — Un solo «budget + pausa dopo un 429» (F-116)
- `lib/services/online/budgeted_call.dart`: `Future<T?> budgetedYtm<T>(cooldown, limiter, Future<T> Function() run, {int cost = 1})` → `null` se in pausa o senza budget; sul 429 (`YtException` rateLimited) `trip` e rilancio. Nomi veri delle classi da `request_budget.dart` e dintorni.
- Test `test/services/online/budgeted_call_test.dart` (3 casi). Poi i tre chiamanti, uno per volta, mantenendo il loro esito: `artistMergeSearchProvider` (`null`/[]), `mergeArtistWith` (eccezione), `smart_search._lateRows` (return, costo 2). I test della 98.3 restano verdi senza modifiche.

### 99.2 — Una sola chiave artista (F-117)
- `artistKey(String?)` di primo livello nel modulo di `matchKey`/`extractPrimaryArtist`; `ArtistInfoRepository.keyOf` la chiama. Sostituire tutte le occorrenze di `matchKey(extractPrimaryArtist(` in `lib` (14 al 7/11: elenco in analisi F-117) e i wrapper `_artistKey` di `library_overlap.dart` e `track_matcher.dart`. `artistNameKeys` resta (insieme di due chiavi) ma usa `artistKey`. `_showKey` dei podcast non si tocca.
- `artist_key_test.dart` passa a `artistKey` con gli stessi valori attesi.

### 99.3 — Scaffali dell'artista fuori da `lib/ui` (F-118)
- `mergeArtistShelves` e `groupShelvesProvider` spostati così come sono in `lib/providers/artist_shelves_providers.dart`; test spostati in `test/providers/artist_shelves_providers_test.dart` (non duplicati).
- Poi confronto della loro chiave (`matchKey(title)|anno`) con quella di `release_diff`: se uguali nei casi reali si usa quella di `release_diff`; se diverse, si tiene la propria e si scrive il motivo in Esiti (nessun cambio di comportamento senza decisione). Le pagine degli alias passano da `budgetedYtm`.

### 99.4 — Paesi senza ricalcolo a ogni scrittura (F-119)
- `TrackRepository._watchWithCountries`: debounce di 300 ms sull'ascolto di `tableUpdates` (la guardia `gen` resta); cache di `countryArtistsOf` per insieme di artisti, invalidata dalle scritture su `artist_countries` e dall'arrivo di artisti nuovi.
- `watch_with_countries_test.dart` resta verde; nuovo caso «stesso insieme di artisti → una sola query».

### 99.5 — Controlli di fase
`flutter analyze`; comando mirato; metriche (analisi «Rete»): `grep -rn "matchKey(extractPrimaryArtist" lib | wc -l` = 1, logica 429 solo in `budgeted_call.dart`, scaffali fuori da `lib/ui`; `dart format --set-exit-if-changed` sui file toccati; review del diff (Sonnet; `/code-review high` sulla 99.4); scheggia passo.

**Fatto quando:** metriche rispettate, test di caratterizzazione verdi senza modifiche, `prossimi-lavori.md` §6 «Media» spuntato.

## Esiti
- 99.3: la chiave di `mergeArtistShelves` (`matchKey(title)|anno`) resta propria: `releaseGroupKey` di `release_diff` toglie parentesi, «Deluxe/Edition/Version» e quel che segue «:» o «+», quindi unirebbe edizioni che oggi restano due uscite (valori diversi nei casi reali).
