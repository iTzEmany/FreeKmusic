# Refactor «ascolto-quotidiano» — analisi

Avvio 2026-11-07. Tipo: **tutto** (funzioni chieste dall'utente + debito). Quasi tutte le voci sono
**cambi di comportamento scelti dall'utente** (vanno in `decisioni.md` come tali); il debito (F-116..F-122)
invece non cambia il comportamento.

## Perimetro
- Coda e suggeriti: pagina artista online, Cerca, Shuffle+/radio, «Non mi piace», player del suggerito.
- Daylist (funzione nuova).
- Testi: inserimento a mano, sincronia disattivabile.
- Podcast: episodi senza iscrizione, «Riprendi» in Home.
- Memoria: copertine delle playlist, cartella aperta nel file manager.
- Debito di `docs/prossimi-lavori.md` §6 «Media», `scripts/perf_device.py`, formattazione di 4 file.

## Misure di partenza
- `flutter analyze`: «No issues found» (2026-11-07).
- Test: 558 file `*_test.dart` in `test/`, 8 file in `integration_test/`.
- `dart format --output=none lib`: 499 file su 678 cambierebbero (nessun `formatter:` in
  `analysis_options.yaml`, quindi larghezza 80 e stile «tall» di Dart 3.13). I 4 file nominati:
  app_shell 13 righe di diff, library_island 222, library_toolbar 65, smart_playlist_editor 268.
- Le prestazioni non cambiano con queste voci; la daylist e la radio dopo una ricerca aggiungono rete
  (sotto il budget YTM esistente).

## Rilievi in ordine di priorità
Formato: `F-NN · area · titolo · dove · prova · danno · impatto · rischio · costo · proposta`.

- **F-103** · coda · Cerca tratta in modo diverso libreria e online · `online_results_sections.dart:97-101` contro `player_providers.dart:330-339` · libreria: `playFromList(tracks, i, context: search)` sostituisce la coda con i risultati «Nella tua libreria»; online: `playOnline` inserisce solo il brano dopo quello corrente · lo stesso gesto dà due risultati diversi · A · M · S · un'unica azione «suona dalla ricerca» per tutte e due le sezioni (vedi F-104).
- **F-104** · coda · Dopo un brano cercato non parte nessuna radio · `ytm_radio_service.dart:21-35`, `suggestion_pool.dart`, `genre_mix.dart:75-125` · la radio YTM e il pool esistono, ma li usano solo Shuffle+ e il mix di genere · dopo il brano cercato la coda finisce o resta quella vecchia · A · M · M · seme = brano suonato → `YtmRadioService.page` → `SuggestionPool.take` → `playMixed` (stesso giro di `genre_mix`); per un brano della libreria serve prima il suo videoId (`seed_resolver.dart`).
- **F-105** · coda · La pagina artista online non ha Play/Shuffle su tutti i brani · `artist_page_screen.dart:107-157` · ci sono solo intestazione, «Segui», 5 brani locali e gli scaffali · ascoltare l'artista vuol dire toccare un brano alla volta · A · B · S · pulsanti Play/Shuffle → `ytmCatalog.songs(shelf.allSongs)` (fino a 100, in ordine «Top songs» di YouTube) mescolati ai brani locali con `MixItem` + `playMixed` (`player_providers.dart:187-224`, che usa già l'id della libreria se il brano è scaricato).
- **F-106** · podcast · Gli episodi si vedono solo dopo l'iscrizione · `podcasts_screen.dart:108` (`onOpen` è null se `subs.idOf(item)` è null); `podcast_detail_screen.dart:29` vuole un `podcastId` del DB · non si può provare un podcast prima di seguirlo · A · M · M · `PodcastService._read` / `YtmPodcastSync._read` leggono già il feed in memoria: renderli pubblici (`peek`), schermata di anteprima con «Segui»; ostacolo: un episodio va riprodotto senza una riga `tracks` (o con una riga creata al play).
- **F-107** · podcast · «Riprendi» in Home esclude gli episodi · `track_repository.dart:700-710` (`kind.equals(0)`, limite 3) · `resumePositionMs` si salva già ogni 15 s ed è letto dal DB a ogni play (`codecore_audio_handler.dart:485,1219-1223`) · un episodio lasciato a metà sparisce dalla Home · A · B · S · accettare `kind` 0 e 1, sottotitolo con il nome del podcast.
- **F-110** · testi · Nessun modo di scrivere o incollare un testo · `lyrics_view.dart:122-170`; `trackOpsProvider.setLyrics` (`track_ops.dart:52`) è chiamato solo dalla ricerca · se la ricerca fallisce il testo resta vuoto per sempre · A · B · S · pulsante «Scrivi o incolla» accanto a «Cerca testo» e nel menu della schermata del testo; un testo incollato in formato LRC va in `synced` (`parseLrc` esiste), altrimenti in `plain`, sempre `byUser: true`.
- **F-111** · testi · La sincronia non si spegne per un brano · `lyrics_view.dart:141-170`; c'è solo `autoLyrics` globale (`settings_store.dart:41`) · un LRC sbagliato scorre fuori tempo e non si può tenere fermo · M · B · S · flag per brano «testo non sincronizzato» che mostra la versione semplice senza cancellare il synced.
- **F-112** · player · Il player di un suggerito sembra decentrato · `suggested_info.dart:29-77` sotto `_TitleRow` (`now_playing_screen.dart:333-335`) · riga «Suggerito · simile a …» allineata a sinistra e senza il margine `npEdge` del titolo, sopra un `Wrap` centrato · aspetto storto proprio sui brani nuovi · M · B · S · intestazione centrata con lo stesso margine del titolo; mockup nel giro 3 (causa vista solo nel codice).
- **F-113** · suggeriti · «Non mi piace» solo per brano, niente artista · `track_actions.dart:142-146` → `SuggestionActions.dislike` → `SuggestionLog` (`suggestions.json`, ultimi 500 record, `suggestion_log.dart:62-121`); il pool scarta per videoId (`suggestion_pool.dart:~130-138`) · non si può dire «questo artista no» · A · M · M · chiedere «Brano o artista?»; l'artista si salva per chiave (`SuggestionRecord.artist` esiste già) e il pool lo scarta sempre. Da verificare: se i «non mi piace» escono con il taglio a 500 record.
- **F-114** · suggeriti · Non esiste un punteggio di compatibilità · `suggestion_pool.dart:20-23,67-88`: solo filtri (durata, non upload, non in libreria, non lo stesso artista degli ultimi 2) e l'ordine della radio YTM · «riproponi un brano scartato solo se compatibilissimo» non ha niente da misurare · M · M · M · punteggio semplice: un brano scartato rientra solo se compare nelle radio di almeno 2 semi della coda attuale e nelle prime N posizioni (nessun modello, deterministico).
- **F-115** · daylist · Funzione assente · dati disponibili: `Plays` con `playedAt` (`tables.dart:182-198`), raggruppamento per ora già in `stats_queries.dart:321-337`, `TrackGenres`; **nessun** dato di umore, energia o BPM in `tables.dart` · la richiesta «energizzanti, rilassanti» non ha dati da cui partire · A · M · L · 8 fasce orarie; per fascia: generi e umore dalle impostazioni + brani più ascoltati in quella fascia + suggeriti dal giro di `genre_mix`; l'umore si ricava da un'associazione genere → umore modificabile (vedi domande).
- **F-108** · memoria · Le playlist non mostrano la copertina · `memory_screen.dart:237-241` passa `playlistCoverKeys(coverKey, const [])`; `SizeGroup` (`memory_queries.dart:24`) non porta copertine · mosaico automatico sempre vuoto · M · B · S · `autoCoverKey` in `SizeGroup` da `byPlaylist`, come `playlist_sheet.dart:203`.
- **F-109** · memoria · Toccare una cartella non fa niente · `memory_screen.dart:260-269` (nessun `onTap`) · M · M · M · Linux `xdg-open` (stile di `link_opener.dart:27`), Windows `explorer`, Android metodo `openFolder` sul canale `codecore/storage` (`StorageBridge.kt`) con `ACTION_VIEW` su URI `DocumentsContract` (`primary:<percorso>`); dipende dal file manager installato, quindi ripiego: percorso copiato con avviso.
- **F-116** · debito · «Budget + pausa dopo un 429» scritto tre volte · `artist_merge_providers.dart:114-124`, `artist_picker_sheet.dart:97-109`, `smart_search.dart:371` (+ `trip` a 416-424) · tre comportamenti diversi (null, eccezione, return; costo 1 o 2) · M · B · S · un helper `budgetedYtm(cooldown, limiter, run, cost:)` nei servizi online. Lo tocca F-104 (nuove chiamate radio), quindi conviene farlo prima.
- **F-117** · debito · Chiave artista ripetuta · `matchKey(extractPrimaryArtist(x))` in 11 punti (`suggestion_pool.dart:21`, `merge_results.dart:65`, `seed_index.dart:44`, `wikipedia_client.dart:44`, `library_overlap.dart:7`, `musicbrainz_client.dart:154,196`, `query_match.dart:109`, `track_resolver.dart:43`, `track_matcher.dart:88`, `duplicate_finder.dart:124`); più `artistNameKeys` (`ytm_artist_resolver.dart:34`) · una modifica alla chiave va fatta in 11 posti · M · B · S · `artistKey(String?)` di primo livello accanto a `matchKey`; `ArtistInfoRepository.keyOf` la usa. Serve a F-113 (blocco artista).
- **F-118** · debito · `mergeArtistShelves` e `groupShelvesProvider` in `lib/ui` · `artist_page_sections.dart:330,375`; usati da `artist_page_screen.dart:106`; test in `test/ui/artist_page_test.dart:625,644` · logica di dominio nella UI, chiave diversa da `release_diff` · M · B · S · spostarli in `lib/providers/artist_shelves_providers.dart` con i test. F-105 tocca la stessa pagina.
- **F-119** · debito · Paesi degli artisti ricalcolati a ogni scrittura su `tracks` · `track_repository.dart:519,531-553` (`_watchWithCountries`: `refresh()` a ogni `tableUpdates`, c'è già la guardia `gen`), `rule_country.dart:23`, `filter_counts_repository.dart:108` · lavoro ripetuto durante scansioni e arricchimento · M · B · S · debounce di 300 ms sull'ascolto + cache di `countryArtistsOf` per insieme di artisti (ascoltare solo `artist_countries` non basta: gli artisti nuovi arrivano da `tracks`).
- **F-120** · misure · «Album» si rompe senza «Tutti i brani» · `scripts/perf_device.py:322-332` (`open_album_tab` parte con un BACK che presuppone lo scenario precedente); stesso problema per «Libreria Tutto→Playlist» (335) · misura parziale fallisce · B · B · S · preparazione con `to_library_top` (Libreria → «Tutto» → in cima), poi `^Album$`.
- **F-121** · misure · Scenari ancora misurati «alla debug» · `perf_device.py`: `scenario()` misura tutta la finestra con 2,5 s di attesa e `time.sleep`, e `dev.tap` fa un dump uiautomator + 1,5 s dentro la misura (righe 66-103) in Tutti i brani, Libreria Tutto→…, Ricerca; «Anello» (485) è solo `sleep(6)` · numeri sporchi da tempi morti · B · B · S · convertirli a `gestures()`: posizioni trovate nella preparazione, `input tap` sulle coordinate dentro la misura.
- **F-122** · formattazione · Indentazione fuori di un livello in 4 file · `app_shell.dart`, `library_island.dart`, `library_toolbar.dart`, `smart_playlist_editor.dart` (vedi misure) · diff rumorosi a ogni modifica · B · B · S · `dart format` solo su quei 4, in un commit a parte, prima di toccarli. Gli altri 495 file restano come sono (un commit gigante rovinerebbe `git blame` e i rami aperti).

## Sintesi per area
- **Coda e suggeriti**: i mattoni ci sono già (`playMixed`, radio YTM, `SuggestionPool`, `ytmCatalog.songs`). Mancano l'innesco dopo una ricerca, i pulsanti dell'artista, il blocco per artista e un punteggio di compatibilità.
- **Daylist**: è l'unica funzione davvero nuova. Lo storico per ora e i generi ci sono; umore ed energia no, e vanno ricavati dalle impostazioni dell'utente.
- **Testi, podcast, memoria**: correzioni piccole e mirate; l'unico punto delicato è suonare un episodio senza iscrizione.
- **Debito**: 4 voci piccole, tre delle quali (F-116, F-117, F-118) stanno sulla strada di F-104, F-113 e F-105: si fanno all'inizio della fase che le tocca.

## Scelte (giro 2, 2026-11-07)
- **Affrontati**: tutti i rilievi F-103..F-122 (D-428). Nessuno rimandato o scartato.
- **Traguardo**: le funzioni chieste (D-429..D-441) più il debito che sta sulla loro strada.
- **Quanto osare**: ristrutturazione per parti; nessuna riscrittura di moduli.
- **Intoccabili** (D-442): Jam; formato del backup solo con aggiunte; nessun pacchetto nuovo; schema DB invariato salvo v19 (colonna «seguito» su `podcasts`, D-435); schermate esistenti invariate salvo quelle del piano.
- **Scelte per rilievo**: Cerca → coda brano + simili, coda vecchia scartata (D-429); artista → top 100 YTM + scaricati (D-430); podcast senza iscrizione con ripresa (D-431, D-435); testo non sincronizzato in `shared_preferences` (D-432); daylist a 8 fasce in Home (D-433, D-439, D-440); «non mi piace» brano o artista ovunque, conservato e nel backup (D-436..D-438); cartella con ripiego (D-441); formattazione di 4 file (D-434).

## Arrivo — struttura (giro 3, 2026-11-07)
Nessun livello nuovo: si usano quelli esistenti (UI → provider → servizi → repository). Prima il debito che sta sulla strada, poi le funzioni che lo usano.

| Oggi | Arrivo | Passi |
|---|---|---|
| Budget + 429 in 3 copie (F-116) | `lib/services/online/budgeted_call.dart`: `budgetedYtm(cooldown, limiter, run, cost:)` → `null` se in pausa o senza budget, `trip` sul 429 e rilancio; i 3 chiamanti mantengono il loro esito (null / eccezione / return) | estrai l'helper con test → sostituisci un chiamante alla volta |
| Chiave artista in 11 punti (F-117) | `artistKey(String?)` di primo livello accanto a `matchKey`; `ArtistInfoRepository.keyOf` la chiama | aggiungi la funzione con test → sostituisci i punti (nessun cambio di valore: stessa espressione) |
| Scaffali artista in `lib/ui` (F-118) | `lib/providers/artist_shelves_providers.dart` (+ test spostati in `test/providers/`); chiave allineata a `release_diff` solo dopo il confronto, pagine degli alias sotto il budget di F-116 | sposta così com'è → poi allinea la chiave |
| Paesi ricalcolati a ogni scrittura (F-119) | debounce di 300 ms in `_watchWithCountries` + cache di `countryArtistsOf` per insieme di artisti | test di caratterizzazione sul conteggio → debounce → cache |
| Coda da Cerca in due modi (F-103, F-104) | un'azione `playFromSearch(seed)` nel `PlayerController`: suona il seme, poi riempie la coda con `RadioFill` (nuovo servizio in `lib/services/shuffle_plus/`, stesso giro seme → `YtmRadioService.page` → `SuggestionPool.take` → `playMixed` di `genre_mix.dart`, estratto e condiviso dai due) | estrai il giro da `genre_mix` (comportamento uguale) → `playFromSearch` → collega le due sezioni di Cerca |
| Artista senza Play/Shuffle (F-105) | provider `artistAllSongsProvider` (top YTM via `ytmCatalog.songs` + locali dello stesso `artistKey`, doppioni uniti) → `playMixed(shuffle:)` | provider con test → pulsanti |
| «Non mi piace» per videoId nel log a 500 (F-113, F-114) | `DislikeStore` (file JSON a parte, senza taglio, nel backup come aggiunta): brani e artisti per `artistKey`; un unico filtro `SuggestionGate` usato da `SuggestionPool` e da ogni fonte di suggeriti (D-437) con la regola «≥ 2 semi, prime 10 posizioni» per i brani | store + migrazione dei dislike esistenti dal log → gate → foglio «brano o artista» → pagina Impostazioni |
| Daylist assente (F-115) | `lib/services/daylist/`: `DaylistSlots` (fasce e orari, D-443), `MoodTable` (genere → umore, di serie + modifiche in `shared_preferences`), `DaylistBuilder` (puro: semi = brani più ascoltati nella fascia da `Plays`; propri = ascoltati nella fascia + stesso artista o genere dei semi; suggeriti = radio dei semi via `RadioFill`/`SuggestionGate`, filtrati per generi e umori, D-452); provider con timer al cambio fascia; card in Home, schermata, Impostazioni | builder puro con test → provider → UI |
| Podcast solo se iscritti (F-106, F-107) | schema v19: `podcasts.followed` (di serie vero); `PodcastService.peek` pubblico; anteprima che salva il podcast come non seguito al primo play; `watchResumable` con `kind` 0 e 1 | migrazione v19 con test → peek → anteprima → Riprendi |
| Testi (F-110, F-111) | foglio editor che chiama `setLyrics(byUser: true)` (LRC riconosciuto con `parseLrc`); insieme `unsyncedLyrics` in `SettingsStore` (nel backup) | editor → interruttore |
| Memoria (F-108, F-109) | `autoCoverKey` in `SizeGroup`; `FolderOpener` (Linux/Windows `Process.start`, Android metodo `openFolder` su `codecore/storage`) con ripiego negli appunti | copertine → apertura cartelle |

Aree a rischio toccate (review Opus o `/code-review high`): migrazione v19, backup (`DislikeStore`, `unsyncedLyrics`), audio handler (episodi non seguiti, coda mista), query su `tracks` (F-119, `watchResumable`).

## Rete (giro 4, 2026-11-07)
**Comportamento invariato** vuol dire: dove il refactor sposta o unisce logica (F-116..F-119, giro estratto da `genre_mix`, `SuggestionLog` → `DislikeStore`) i test di caratterizzazione e quelli esistenti restano verdi **senza modifiche**; gli unici test che cambiano apposta sono quelli dei cambi di comportamento scelti (D-429..D-452), e la PR lo dice. `flutter analyze` pulito sempre.

### Caratterizzazione prima di toccare il codice (fase 98)
- F-116: `test/providers/artist_merge_providers_test.dart` (429 → null e pausa; in pausa → nessuna chiamata), `test/ui/artist_picker_sheet_test.dart` (429 → eccezione, costo 2); `smart_search_test.dart:199,299` e `genre_mix_test.dart:212` esistono già.
- F-117: `test/services/online/artist_key_test.dart`, tabella («feat.», «&», maiuscole, accenti, null, vuoto) scritta sulla vecchia espressione `matchKey(extractPrimaryArtist(x))`; oggi le occorrenze in `lib` sono 14.
- F-118: test di `groupShelvesProvider` («raggruppa come oggi»); i test di `mergeArtistShelves` (`artist_page_test.dart:616,631`) si spostano, non si duplicano.
- F-119: `test/data/watch_with_countries_test.dart` (raffica di scritture → ultimo valore corretto; artista nuovo in `tracks` → compare), con `fakeAsync`; `filter_counts_test.dart:42,100` esiste.
- Giro seme → radio → pool: `genre_mix_test.dart` (15+ test) è già la rete.
- `SuggestionLog`: `suggestion_log_test.dart:51,69,84` esiste.
- Backup: in `backup_service_test.dart` un caso «campi sconosciuti ignorati, vecchio formato ripristinato».

### Test del comportamento nuovo (nella fase che lo introduce)
Unità: `DaylistSlots` (confini D-443: 4:59, 5:00, 8:59, 9:00, 23:59→0:00, 3:00; passi di 1 h), `MoodTable`, `DaylistBuilder` (50 brani, quota 30%, ≥ 3 generi, evitati esclusi anche dai suggeriti, semi D-452, fascia senza storico, nessuna ripetizione; orologio e casuale iniettati), `SuggestionGate` (artista mai; brano con 1 seme no, 2 semi in posizione 11 no, 2 in posizione 10 sì), `budgetedYtm` (3 casi), `artistAllSongsProvider` (D-430, D-447), `RadioFill`/`playFromSearch` (D-429, senza rete), rilevamento LRC all'incolla, `DislikeStore` (migrazione dal log una volta sola, nessun taglio, nel backup), migrazione v18 → v19 (podcast esistenti `followed = true`, passo ripetibile, stile `migration_test.dart:774,796`), `unsyncedLyrics` nel backup, `FolderOpener` (percorso → `primary:<rel>`, ripiego negli appunti), anteprima podcast (salvato non seguito al primo play, «Segui già» → non seguito).
Widget (solo 3): foglio «brano o artista»; Annulla dopo «Non mi piace» (D-446); editor del testo. Niente widget test per card Home, pagina «Non mi piace», player del suggerito, Memoria: si confrontano con i mockup sul telefono (uiautomator).

### Metriche di arrivo
| Metrica | Comando | Soglia |
|---|---|---|
| Chiave artista unica | `grep -rn "matchKey(extractPrimaryArtist" lib \| wc -l` | 1 (dentro `artistKey`) |
| Logica 429 unica | `grep -rn "tryAcquire" lib/providers lib/ui lib/services/online` (contare prima: altri usi legittimi vanno elencati nella PR) | solo `budgeted_call.dart` + usi elencati |
| Scaffali fuori da `lib/ui` | `grep -rln "mergeArtistShelves\|groupShelvesProvider" lib/ui` | solo l'uso in `artist_page_screen.dart` |
| Giro estratto | `grep -c "YtmRadioService\|SuggestionPool" lib/services/shuffle_plus/genre_mix.dart` | ≤ 1 |
| Filtro dei «non mi piace» unico | `grep -rln "disliked(" lib` | `SuggestionGate`, `DislikeStore` |
| Schema | `grep -rn "kSchemaVersion =" lib` | 19 |
| Formato dei 4 file e dei file toccati | `dart format --set-exit-if-changed <i 4 file> $(git diff --name-only origin/master... -- lib test)` | 0 |
| Analisi | `flutter analyze` | «No issues found» |
| Script delle misure | `python3 scripts/perf_device.py <id> --only "Album"` sul Mi A3 | gira da solo, senza «Tutti i brani» |

### Comandi mirati
Elencati in ogni `docs/fase-N-*.md`. Suite completa in locale una sola volta, prima della PR della fase podcast (v19 su `podcasts`, `watchResumable` su `tracks`).
