# Fase 100 — Coda di simili da Cerca e Play/Shuffle dell'artista

**Obiettivo:** dopo un brano scelto da Cerca (libreria o online) la coda diventa brano + simili; la pagina artista online ha Play e Shuffle su tutti i brani. **Cambi di comportamento voluti** (D-429, D-430, D-447, D-448).

**Prerequisiti:** fase 99 chiusa. Analisi F-103, F-104, F-105 e «Arrivo». Mockup approvati: `refactor/ascolto-quotidiano/mockup/coda-da-cerca.html`, `refactor/ascolto-quotidiano/mockup/artista.html`. Aree a rischio: audio handler (coda mista, `/code-review high`).

**Comando mirato:** `flutter test test/services/shuffle_plus/ test/providers/genre_mix_provider_test.dart test/providers/list_shuffle_test.dart test/services/online/smart_search_test.dart test/providers/artist_all_songs_provider_test.dart test/providers/play_from_search_test.dart`

## Task

### 100.1 — `RadioFill` estratto da `genre_mix` (nessun cambio)
- `lib/services/shuffle_plus/radio_fill.dart`: il giro seme → `YtmRadioService.page` → `SuggestionPool.take` → elementi per `playMixed` (oggi `genre_mix.dart:75-125`), con le chiamate di rete sotto `RadioGate` come oggi (nota della fase 99: la radio ha la sua politica, 1 richiesta/min e 15 min di pausa dopo un 429, `02-architettura.md`; `budgetedYtm` è per il budget delle righe di ricerca e cambierebbe il comportamento). `genre_mix` lo usa. `genre_mix_test.dart` verde **senza modifiche**.

### 100.2 — `playFromSearch` (F-103, F-104, D-429, D-448)
- Un'azione nel `PlayerController`: suona il brano scelto, poi sostituisce il resto della coda con i simili da `RadioFill` (seme = quel brano; per un brano della libreria il videoId si trova con `seed_resolver`); brani della libreria e online mescolati (`playMixed`, che usa l'id locale se il brano è scaricato). La coda vecchia si scarta.
- Sia «Nella tua libreria» (`online_results_sections.dart:97-101`) sia i risultati online (`online_song_row.dart` → `playOnline`) chiamano `playFromSearch`. `playOnline` resta per gli altri punti che lo usano.
- Avvisi (ARB it/en/de/es): «Cerco brani simili…», poi «Coda: «<brano>» e brani simili» con «Vedi coda»; senza rete «Nessun brano simile: suono solo «<brano>»»; nel foglio della coda l'intestazione «Simili a «<brano>»» (mockup).
- I «non mi piace» di oggi (`SuggestionLog`) valgono già perché passano da `SuggestionPool`; la 101 li estende.
- Test `test/providers/play_from_search_test.dart`: coda = brano + simili, la vecchia sparisce; senza rete solo il brano.

### 100.3 — Tutti i brani dell'artista (F-105, D-430, D-447)
- `artistAllSongsProvider` (`lib/providers/`): top YouTube Music via `ytmCatalog.songs(shelf.allSongs)` (fino a 100) + brani della libreria con lo stesso `artistKey`; doppioni uniti (il brano scaricato prende il posto di quello online); ordine di Play = ordine della top, scaricati fuori dalla top in fondo; senza rete solo gli scaricati con l'avviso «Top non disponibile».
- Pulsanti Play e Shuffle nella pagina artista come nel mockup (coppia come l'album, `online_album_screen.dart:99`), stato «occupato» durante il caricamento; Shuffle = ordine casuale. Etichette TalkBack.
- Test `test/providers/artist_all_songs_provider_test.dart` (ordine, doppioni, fuori top, senza rete).
- Budget e caricamento (D-466): `ytmCatalog.songs` senza budget come le altre pagine del catalogo, una sola richiesta (cache di 2 giorni). L'audio si prepara solo per il brano in corso e il prossimo (lo stesso `StreamAddressCache`/`peekNext` di oggi); con salti più veloci del caricamento il player resta in «Caricamento…» come nello streaming. Errore o niente rete → «Top non disponibile» (D-447). Test: errore del catalogo → solo scaricati con l'avviso. Per «stessi `artistKey`» non c'è ancora un helper chiave → grafie: estrarlo da `countryArtistsOf` (`rule_country.dart`, usa `distinctArtists`).

### 100.4 — Controlli di fase
`flutter analyze`; comando mirato; review del diff (`/code-review high` sulla coda); scheggia passo e fase; prova sul Mi A3 via adb contro i mockup (Cerca → brano della libreria e brano online → coda di simili; artista → Play, Shuffle, senza rete). Ripulire il telefono.

**Fatto quando:** i due gesti di Cerca danno la stessa coda di simili, la pagina artista suona tutti i brani, i test sono verdi.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-467** (100.2): primo blocco di simili e poi rabbocco automatico quando ne restano pochi, all'infinito, sotto `RadioGate`.
- **D-468** (100.3): Play/Shuffle di un artista bloccato suonano i suoi brani scaricati; icona di blocco nell'intestazione della pagina e nei risultati online.

## Esiti
- 100.1 (2026-11-08): `RadioFill` (`lib/services/shuffle_plus/radio_fill.dart`) con lo stato che resta fra una chiamata e l'altra; la prima richiesta della sessione aspetta solo la pausa del 429, le altre anche il minuto di `RadioGate`; `RadioSeed.online` per un seme con id già noto. `genre_mix_test` invariato.
- 100.2: `PlayerController.playFromSearch({track, online})` → `bool?` (null: scelta superata). Il seme suona da solo, poi blocchi di 10 simili (libreria e online, id locale anche per i brani della libreria non scaricati dall'app) da `SimilarQueue` (`lib/services/shuffle_plus/similar_queue.dart`), rabbocco sotto 5 rimasti, 1 min di attesa dopo un errore. La sessione si ferma con un'altra coda, «Svuota», Jam, coda cambiata da fuori (Android Auto) o quando nessuno dei suoi brani resta in coda. Foglio della coda: «Simili a «brano»», tag «radio YouTube Music», conteggio, «Cerco i brani simili…» con righe scheletro. Scelte in autonomia: D-477 (avvisi in basso; Annulla dopo Svuota e riavvio non riaprono il rabbocco). Senza simili resta solo il brano (D-429), non la coda di prima come scrive il mockup.
- 100.3: `artistAllSongsProvider` (top da `artistSongsProvider` + scaricati di tutte le grafie, `TrackRepository.tracksOfArtist`, `spellingsOf` estratto da `countryArtistsOf`); Play/Shuffle (indice casuale) nella pagina artista, anche con la pagina non leggibile (solo scaricati, «Top non disponibile»). Scelte in autonomia: D-478.
- Review: Sonnet su 100.1 e 100.3, Opus su 100.2; scheggia di passo: 3 bug medi riprodotti e corretti con i loro test (seme scaricato, Jam durante un caricamento, avviso di una scelta superata).
- 100.4: `flutter analyze` pulito, 510 test mirati verdi, CI verde dopo una correzione (spy di `PlayerController` nei test, vedi `gotchas.md`). Review di architettura di fase: 8 rilievi, il doppione di libreria in `SimilarQueue` corretto subito, il resto in `prossimi-lavori.md` e nelle note di 101 e 104. Prova sul Mi A3 (scheggia di fase): i 7 flussi funzionano; corretti la virgola iniziale delle righe online in coda, la spunta «in libreria» nella coda di simili e lo stato di caricamento di Play/Shuffle nella pagina artista. Telefono ripulito (rete riattivata).
