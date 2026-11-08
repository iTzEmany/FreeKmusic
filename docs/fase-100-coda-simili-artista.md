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
- Nota della fase 99 (review di architettura): le chiamate di `ytmCatalog` non hanno né budget né pausa (D-465 rimanda il blocco al fetch di `_cached`). Prima di scrivere `artistAllSongsProvider` scegliere: `ytmCatalog.songs` sotto `budgetedYtm` (null → «Top non disponibile», già previsto) oppure il blocco in `_cached` (cambio di comportamento, serve una decisione). Per «stessi `artistKey`» non c'è ancora un helper chiave → grafie: estrarlo da `countryArtistsOf` (`rule_country.dart`, usa `distinctArtists`).

### 100.4 — Controlli di fase
`flutter analyze`; comando mirato; review del diff (`/code-review high` sulla coda); scheggia passo e fase; prova sul Mi A3 via adb contro i mockup (Cerca → brano della libreria e brano online → coda di simili; artista → Play, Shuffle, senza rete). Ripulire il telefono.

**Fatto quando:** i due gesti di Cerca danno la stessa coda di simili, la pagina artista suona tutti i brani, i test sono verdi.

## Esiti
