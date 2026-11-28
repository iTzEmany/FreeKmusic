# Refactor «karaoke-casuale» — analisi

Tipo: `structure` (logica di coda e del pulsante del casuale; nessun cambio di aspetto). Data: 2026-11-28.

## Richiesta dell'utente
Due **cambi di comportamento** voluti (regola 1 di `/refactor`), da registrare nel file decisioni come tali:

1. **Karaoke**: dopo un video karaoke (YouTube in streaming con «karaoke» nel titolo, D-634/D-646) i brani aggiunti
   in automatico alla coda devono essere tutti karaoke: radio dei brani simili alla **canzone originale**, per ognuno la sua
   versione karaoke, **scartato se non c'è** (scelta già fatta dall'utente).
2. **«Casuale su tutto»** della Home (`ShuffleHero`): il pulsante del casuale passa solo tra Casuale e Casuale+, mai spento.
   Cambia D-72, D-137, D-369.

## Ambito
- Karaoke: `lib/providers/player_providers.dart` (`playFromSearch` :491-549, `_similarId` :553),
  `lib/services/shuffle_plus/similar_queue.dart` (`start` :67-80, `_take` :139-181), `radio_fill.dart`, `seed_resolver.dart`,
  `suggestion_pool.dart` (`RadioSeed.online` :45), `lib/providers/shuffle_plus_providers.dart` (`similarFill` :337-365),
  `lib/services/online/karaoke_filter.dart`, `query_cleaner.dart` (`karaokeLyricsQuery` :199),
  `lib/services/karaoke_video/karaoke_video.dart`, `lib/ui/**/online_results.dart` (:212, :241-250, :322).
- Casuale: `lib/ui/**/home_blocks.dart` (`ShuffleHero` :60-88), `lib/ui/**/shuffle_button.dart` (`_cycleWithNotice` :31-52,
  `ShufflePill` :160+), `player_providers.dart` (`isPlayingList` :158-163, `_start` :239-240, `toggleShuffle` :620,
  `cycleListShuffle` :629 → `_cycleList` :651-680, `cycleShuffle` :683 → `_cycleShuffle` :697-712, `plusAllowedNow` :742),
  `shuffle_plus_providers.dart` (`listShuffle` :440-446, shortcut :455-459), `playback_persistence.dart` (:64-69, :140-150),
  `lib/services/**/mpris_controls.dart` (:198), `codecore_audio_handler.dart` (`setShuffleMode` :2143).

Misure di base: non servono (nessun percorso caldo misurato; la latenza delle ricerche karaoke è una stima, vedi F-03).

### Fatti emersi dalla scansione
- **Dove nascono i brani aggiunti in automatico**: solo la sessione «brani simili» (`SimilarQueue`), che parte solo da
  `playFromSearch` (righe della Ricerca, del filtro Karaoke, link, Shazam). Shuffle+ non può seguire un video karaoke
  (`plusAllowed` blocca le code tutte online, `plus_allowed.dart:26-28`; i suoi semi sono brani della libreria);
  daylist e mix di genere costruiscono liste proprie; `_queueRadio` è la radio in diretta; non esiste un autoplay a fine coda.
  Un video karaoke avviato da cronologia, playlist o coda oggi **non aggiunge nulla**; in una Jam nessuna sessione (D-89).
- **Ricerca karaoke oggi**: ricerca intelligente con `videoOnly: true` e « karaoke» in coda alla query (`online_results.dart:241-250`):
  una chiamata yt-dlp `ytsearch10:` (10 righe), cache in memoria 10 min / 30 voci (`smart_search.dart:125-126, 285`), pausa di
  5 min della fonte dopo un 429 (`source_cooldown.dart`); fuori da `RadioGate`. `karaokeResults` (`karaoke_filter.dart:17`)
  tiene i titoli con «karaoke», scarta reaction/cover/live, mette prima i canali noti; **nessun confronto con titolo e artista**.
- **Canzone originale dal titolo karaoke**: `karaokeLyricsQuery(title, channel)` (`query_cleaner.dart:199`) già ricava
  titolo e artista («Sing King - Adele - Hello (Karaoke Version)» → Adele, Hello). Il seme della radio va poi risolto in un id
  YouTube Music (`SeedResolver.resolve` / `searchSongs` + `decide()`): 1 ricerca.
- **Controlli del casuale**: tutti i `ShuffleModeButton` (Home, player intero, barra desktop, Tutti i brani) e le pillole delle
  intestazioni passano da `_cycleWithNotice` → `cycleShuffle`/`cycleListShuffle`. Notifica, Android Auto, widget, riquadro
  rapido e scorciatoie da tastiera **non hanno** un controllo del casuale; solo MPRIS (Linux) e client esterni via
  `setShuffleMode` del handler lo cambiano.
- **Riconoscere la coda «Casuale su tutto»**: `_listKey = libraryListKey` solo in memoria; il contesto `library` è condiviso con
  «Tutti i brani» e altri; dopo un riavvio `isPlayingList` è falso (shortcut dichiarato in `shuffle_plus_providers.dart:455-459`).

## Risultati (per priorità)

### Karaoke
F-04 · logica · Il seme di un video karaoke è il video stesso · `player_providers.dart:511-513` (`RadioSeed.online(online!.id,
online.title)`, nessun controllo `isKaraokeVideo`) · la radio di un video karaoke restituisce altri caricamenti del canale karaoke,
non brani simili alla canzone · impatto H · rischio M · costo M · riconoscere il karaoke, pulire con `karaokeLyricsQuery`, risolvere
l'originale in un id YTM, seme su quello.

F-01 · logica · Filtro, «già visto» e registro usano l'id originale, non quello sostituito · `similar_queue.dart:148-170`
(`_seen.add(c.result.id)`, `fill.filter.allows(c.result.id…)`, `onSuggested(c.result…)`) · con la sostituzione la stessa versione
karaoke può entrare due volte e il «non mi piace» punta al video sbagliato · impatto M · rischio M · costo S · sostituire prima e
far girare tutti i passi successivi sul risultato karaoke (l'originale solo per `pool.positionsOf`).

F-05 · logica · La prima riga karaoke vince senza confronto · `karaoke_filter.dart:17-31` (filtra e ordina, non confronta
titolo/artista) · per un brano suggerito può entrare il karaoke di un'altra canzone · impatto M · rischio M · costo S · confrontare
con `decide()` (o titolo/artista normalizzati) contro titolo e artista del suggerito; sotto soglia = scartato.

F-02 · rete · Le ricerche della sostituzione aggirano `RadioGate` · `radio_fill.dart:47, 70` (`maxRequests` conta solo radio e
risoluzioni) · un blocco di 10 suggeriti = 10+ ricerche yt-dlp di fila, rischio di 429 da YouTube · impatto M · rischio M · costo S ·
tetto di ricerche per blocco, cache di 10 min riusata, `SourceCooldown.trip` e `fill.gate.trip()` su 429.

F-03 · UX · Attesa lunga del primo blocco · `similar_queue.dart:67-80`, `player_providers.dart:539` (`start()` aspetta tutto
`_take(block)`) · con 10 ricerche in sequenza (stima 2-5 s l'una su desktop) «caricamento» per decine di secondi (i brani entrano
comunque in coda man mano) · impatto M · rischio L · costo S · primo blocco più piccolo per il karaoke, o fine del caricamento al
primo brano trovato.

F-08 · struttura · `SimilarQueue` non ha un punto per la sostituzione · `shuffle_plus_providers.dart:337-365`,
`player_providers.dart:522` · `accept` di `RadioFill.take` è sincrono (`suggestion_pool.dart:210`), non può cercare · impatto L ·
rischio L · costo S · parametro facoltativo `Future<YtResult?> Function(YtResult)? swap` iniettato in `SimilarQueue` (testabile).

F-07 · errori · Catch generico nella sessione · `similar_queue.dart:178-181` (`on Object`: log e attesa, nessuna pausa della fonte
per errori non `YtException`) · un 429 nel nuovo passo di ricerca verrebbe trattato come errore qualsiasi · impatto L · rischio M ·
costo S · far risalire tipizzati gli errori della sostituzione.

F-06 · struttura · La regola «è karaoke» scritta tre volte · `karaoke_video.dart:19, 27`, `karaoke_filter.dart:4` (regex) ·
deriva tra le tre regole · impatto L · rischio L · costo S · un solo predicato sul titolo condiviso.

### Casuale su tutto
F-14 · stato · La modalità della lista Home parte spenta · `shuffle_plus_providers.dart:440-446` · con «mai spento» ▶ suonerebbe
in ordine mentre il pulsante mostra Casuale (oggi `home_screen_test.dart:199` «Play starts the library in order») · impatto H ·
rischio M · costo S · predefinito Casuale per `libraryListKey`.

F-11 · stato · L'identità della coda «tutta la libreria» non sopravvive al riavvio · `shuffle_plus_providers.dart:455-459`,
`player_providers.dart:152-163`, `playback_persistence.dart:140-150` · dopo il ripristino `isPlayingList` è falso: il blocco
sparirebbe in silenzio · impatto H · rischio M · costo M · salvare `listKey` accanto a `lastContextKind` (prefs, nessun valore
nuovo nell'enum) e ripristinarlo.

F-09 · struttura · Due implementazioni del ciclo · `player_providers.dart:651-680` (`_cycleList`) e `:697-712` (`_cycleShuffle`),
più `toggleShuffle` :620-624 · il «mai spento» andrebbe scritto in tre punti · impatto M · rischio M · costo M · una funzione pura
«modo successivo» con il blocco come parametro, usata da entrambi.

F-13 · UX · L'avviso di Casuale+ bloccato appare una volta sola · `shuffle_button.dart:14-16, 43-51` (`_explained`) · con un
solo stato possibile (Jam, lista corta) i tocchi successivi sembrano morti · impatto M · rischio M · costo S · avviso a ogni tocco
bloccato (o pulsante con descrizione del motivo).

F-10 · logica · MPRIS spegne il casuale senza passare dal controller · `mpris_controls.dart:198` (`_h.setShuffleMode(none)`, non
toglie il flag Shuffle+ come `toggleShuffle`) · un client esterno lascia un Casuale+ «fantasma» e scavalca un eventuale blocco ·
impatto M · rischio M · costo S · passare da `PlayerController` e applicare la stessa regola.

F-12 · dati · Un nuovo `PlayContextKind` è sicuro ma pesante · `play_context_kind.dart:2-16` · le versioni vecchie lo leggono come
`library`, ma ogni switch dell'interfaccia vuole un caso · impatto L · rischio L · costo M · preferire F-11.

F-15 · documenti · D-137 e D-369 descrivono il ciclo spento → Casuale → Casuale+ · `decisioni.md:163, :395` · contraddiranno il
nuovo comportamento · impatto L · rischio L · costo S · nuova decisione che le supera; aggiornare `home_screen_test.dart:136-211` e
`shuffle_button_test.dart:313`.

## Riepilogo per area
- **Karaoke**: la regola tocca un solo punto d'ingresso (`playFromSearch`); il lavoro vero è un passo «sostituisci con la versione
  karaoke» nella sessione dei simili, con seme sulla canzone originale, confronto del titolo, tetto alle ricerche e 429 gestiti.
- **Casuale**: il comportamento sta in due cicli quasi uguali; il blocco richiede una modalità iniziale Casuale per la Home e,
  se deve valere dopo un riavvio, la chiave della lista salvata. Notifica, Auto e widget non hanno pulsante del casuale.
- **Test esistenti**: `test/providers/play_from_search_test.dart`, `test/services/shuffle_plus/*`,
  `test/services/online/karaoke_filter_test.dart`, `query_cleaner_test.dart`, `test/ui/shuffle_button_test.dart`,
  `test/providers/list_shuffle_test.dart`, `test/ui/home_screen_test.dart`. Nessuno copre karaoke nella sessione dei simili,
  ripristino della coda della libreria, MPRIS sulla coda della libreria.

## Scelte (giri 1-2)
Diagnosi confermata dall'utente. Tutti i risultati F-01..F-15 sono **scelti**; nessuno rinviato o scartato.

- **Karaoke** (F-04, F-01, F-05, F-02, F-03, F-07, F-08, F-06): solo dai punti d'ingresso di `playFromSearch` (Ricerca, filtro
  Karaoke, link, Shazam). Seme sulla canzone originale; ogni simile sostituito dalla sua versione karaoke **che corrisponde** per
  titolo e artista, scartato se non c'è; originale non trovato → suona solo il brano scelto. Primo gruppo da 3, tetto di ricerche
  pari al doppio dei brani del gruppo, 429 → pausa della fonte e fine della sessione.
- **Casuale su tutto** (F-14, F-11, F-09, F-13, F-10, F-12, F-15): Casuale ↔ Casuale+ e mai spento, per quella coda ovunque
  (Home, player intero, barra desktop, MPRIS) e dopo un riavvio (chiave della lista salvata nelle preferenze). ▶ parte su Casuale.
  Casuale+ impossibile → resta su Casuale con l'avviso a ogni tocco.
- **Intoccabili**: D-770. In breve: le altre liste, D-534, D-634/D-646,
  D-89, regole di Shuffle+, schema del DB, `PlayContextKind`, nessun pacchetto nuovo.
- **Obiettivo**: comportamento nuovo con il minimo di codice nuovo; il ciclo del casuale in un solo punto.
- **Audacia**: ritocchi per parti (nessuna riscrittura di modulo).

## Direzione (giro 3)
Nessun mockup: nessuna parte visiva cambia (D-771).

### Karaoke: prima → dopo
| Prima | Dopo |
|---|---|
| `playFromSearch` fa sempre `RadioSeed.online(pick.id, pick.title)` | se il brano scelto è karaoke (regola unica sul titolo), il seme viene da una funzione iniettata `karaokeOriginal(YtResult) → Future<RadioSeed?>` (pulizia `karaokeLyricsQuery` + ricerca YTM + `decide()`); null → nessuna sessione, ritorna `false` (avviso di oggi) |
| `SimilarQueue._take` registra `c.result` così com'è | parametro facoltativo `swap: Future<YtResult?> Function(YtResult)`: in `_take` la sostituzione avviene **prima** di `_seen`, filtro, `register` e `onSuggested`; null = brano scartato; `pool.positionsOf` usa ancora l'originale |
| un gruppo di 10, nessun conto delle ricerche fuori da `RadioGate` | con `swap`: primo gruppo da 3, tetto di ricerche = 2 × brani del gruppo; un `YtException` 429 nella sostituzione chiama `SourceCooldown.trip` e `fill.gate.trip()` e chiude la sessione come gli altri 429 |
| tre regole «è karaoke» (`karaoke_video.dart:19, 27`, `karaoke_filter.dart:4`) | un solo predicato sul titolo in `karaoke_filter.dart` (o `karaoke_video.dart`), usato da tutti e tre |
| — | implementazione di `swap` in `shuffle_plus_providers.dart` accanto a `similarFill`: ricerca intelligente `videoOnly` «artista titolo karaoke» (cache di 10 min), `karaokeResults`, primo risultato che `decide()` accetta contro titolo/artista del simile |

Percorso a piccoli passi: (1) regola unica «è karaoke», nessun cambio di comportamento; (2) `swap` facoltativo in `SimilarQueue`
con test a funzione finta, senza collegarlo (comportamento invariato); (3) `karaokeOriginal` e `swap` reali collegati in
`playFromSearch` solo per i karaoke.

### Casuale: prima → dopo
| Prima | Dopo |
|---|---|
| `_cycleList`, `_cycleShuffle` e il ramo di `toggleShuffle` decidono ognuno il modo successivo | una funzione pura `nextShuffleMode(current, {required bool plusAllowed, required bool neverOff})` (file proprio in `lib/services/shuffle_plus/`), usata da entrambi i percorsi |
| `_listKey` solo in memoria | `PlaybackPersistence` salva la chiave della lista quando è `libraryListKey` (preferenza stringa accanto a `lastContextKind`) e la ripristina; `isPlayingList(libraryListKey)` vero anche dopo un riavvio se la coda ripristinata è quella |
| `listShuffle(libraryListKey)` parte da spento | parte da Casuale; uno spento salvato si legge come Casuale |
| MPRIS chiama `_h.setShuffleMode` | MPRIS chiama `PlayerController` (`setShuffle`), che ignora lo spegnimento sulla coda bloccata e ripubblica lo stato |
| avviso di Casuale+ bloccato una volta per sessione | sul pulsante con blocco «mai spento» l'avviso esce a ogni tocco |

Percorso a piccoli passi: (1) funzione pura e sostituzione dei due cicli, comportamento invariato; (2) blocco «mai spento» sulla
Home e sulla sua coda (player, barra, avviso a ogni tocco, ▶ su Casuale); (3) MPRIS tramite il controller; (4) chiave della lista
salvata e ripristinata.

Documento d'architettura da aggiornare a fine lavoro: `docs/architettura/riproduzione-e-coda.md` (sessione dei simili karaoke,
blocco del casuale).

## Rete (giro 4)
### Test di caratterizzazione, prima di toccare `lib/` (verdi sul codice di oggi; solo ciò che non è già coperto)
- `test/providers/play_from_search_test.dart`: brano **non karaoke** → seme, gruppo, `_seen`, filtro «non mi piace» e registro
  dei suggeriti con gli id di oggi (sessione senza `swap`); 429 durante un riempimento → pausa della fonte e fine della sessione
  (se i test esistenti non fissano già entrambi gli effetti).
- `test/services/online/karaoke_filter_test.dart` e `test/services/karaoke_video/karaoke_video_test.dart`: tabella di titoli
  (maiuscole, «Karaoke Version», «karaokes», accenti, «(Instrumental)») con l'esito di oggi delle tre regole «è karaoke».
- `test/services/online/query_cleaner_test.dart`: `karaokeLyricsQuery` su titoli limite («Artista - Brano (Karaoke Version)»,
  senza artista, parentesi).
- `test/providers/list_shuffle_test.dart`: tabella del giro di oggi per una lista qualsiasi (spento → Casuale → Casuale+ →
  spento; Casuale+ bloccato → spento): è l'oracolo della funzione pura.
- `test/ui/shuffle_button_test.dart`: `toggleShuffle`/`cycleShuffle` su una coda non della libreria (player intero, barra desktop)
  con gli stessi avvisi; i test esistenti sugli avvisi (:199-329) restano intatti.
- `test/services/audio/playback_persistence_test.dart`: andata e ritorno di `lastContextKind` e delle altre preferenze salvate.

### Test nuovi per cambio
- Karaoke: `test/services/shuffle_plus/similar_queue_swap_test.dart` (sostituzione, scarto, id sostituito per `_seen`/filtro/
  registro, gruppo da 3, tetto 2×, 429 → pausa e fine, `swap == null` identico a oggi); test del predicato unico; in
  `play_from_search_test.dart` brano karaoke (seme = originale, coda = karaoke corrispondenti), originale non trovato → `false`,
  brano non karaoke → `swap` mai chiamato.
- Casuale: test a tabella della funzione pura; in `list_shuffle_test.dart` predefinito Casuale per `libraryListKey` (spento salvato
  → Casuale), blocco sulla coda della Home per `toggleShuffle`, `cycleShuffle` e il setter usato da MPRIS, coda di un'altra lista
  libera, nuova coda che toglie il blocco; persistenza della chiave e blocco dopo il ripristino; pulsante del player sulla coda
  bloccata e avviso a ogni tocco; Home Casuale ↔ Casuale+.
- MPRIS: `test/services/audio/mpris_controls_test.dart` salta senza bus D-Bus: il blocco si prova a livello di `PlayerController`.

### Test da aggiornare apposta (cambio di comportamento)
`test/ui/home_screen_test.dart` :114-146 (il tocco con Casuale+ bloccato resta su Casuale invece di spegnere), :148-170 (D-137,
secondo tocco), :199-206 (▶ ora parte in casuale), :211-223 (premessa «accendi il casuale» diventa il predefinito);
`test/providers/list_shuffle_test.dart` :176-278 solo i casi con `libraryListKey` che si aspettano spento;
`test/providers/play_from_search_test.dart` :113-120 (`sessionFor` con `swap` facoltativo).

### «Comportamento invariato» qui vuol dire
I test di caratterizzazione sopra restano verdi senza modifiche, tranne quelli elencati come aggiornati apposta; un brano non
karaoke dalla Ricerca riempie la coda come oggi; le altre liste girano spento → Casuale → Casuale+ come oggi.

### Metriche
Nessuna misura di prestazioni (nessun percorso caldo). Criteri: `flutter analyze` pulito; comandi mirati verdi; una sola funzione
decide il modo successivo del casuale (`grep -n "ShuffleMode\." lib/providers/player_providers.dart` senza transizioni fuori da
`nextShuffleMode`); una sola regola «karaoke» sul titolo (`grep -rn "contains('karaoke')" lib/` → un risultato).
Comandi mirati (widget sotto `~/.claude/scripts/isolate.sh`), 1-2 min l'uno:
- rete: `flutter test test/providers/play_from_search_test.dart test/providers/list_shuffle_test.dart test/services/online/query_cleaner_test.dart test/services/online/karaoke_filter_test.dart test/services/karaoke_video/karaoke_video_test.dart test/ui/shuffle_button_test.dart test/services/audio/playback_persistence_test.dart`
- karaoke: `flutter test test/services/shuffle_plus test/providers/play_from_search_test.dart test/services/online test/services/karaoke_video`
- casuale: `flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/ui/home_screen_test.dart test/ui/talkback_labels_test.dart test/services/audio/playback_persistence_test.dart test/services/audio/mpris_controls_test.dart`
