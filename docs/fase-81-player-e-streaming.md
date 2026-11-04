# Fase 81 — Player vuoto, schede in streaming e coda di Shuffle+ (refactor «ui-uso-quotidiano»)

**Obiettivo:** a coda finita il player resta utile; le schede dei brani in streaming hanno uno skeleton della loro forma invece di «Il brano è in arrivo…»; i suggeriti di Shuffle+ in arrivo si vedono in coda come righe skeleton.

**Prerequisiti:** fasi 77 (`Skeleton`) e 80 (stato «in preparazione») chiuse. Mockup `refactor/ui-uso-quotidiano/mockup/player-vuoto.html`, `refactor/ui-uso-quotidiano/mockup/streaming-skeleton.html`. Decisione D-364. Aree a rischio: `mini_player.dart`, `now_playing_screen.dart`, `queue_sheet.dart`.

**Comando mirato:** `flutter test test/ui/mini_player_test.dart test/ui/now_playing_test.dart test/ui/now_playing_stream_cards_test.dart test/ui/shuffle_plus_tiles_test.dart test/providers/shuffle_plus_test.dart`.

## Task

### 81.1 — Niente in riproduzione (F-47, F-48, U9, D-364)
- Mini player: con `track == null` fuori dalla Jam resta (niente `SizedBox.shrink`, `mini_player.dart:130`), con «Niente in riproduzione», sottotitolo «Ultima coda: …» e ▶ che la riprende; senza ultima coda, ▶ = Shuffle+ della libreria.
- Player aperto (`now_playing_screen.dart:286-299`): tre riquadri «Riprendi l'ultima coda» (accento pieno), «Shuffle+ della libreria», «Ultimi aggiunti» (3 mini copertine); liveRegion sul titolo. Barra desktop (`desktop_player_bar.dart:60,197`) con lo stesso testo e ▶.
- Test: coda finita → mini player visibile con ▶; ▶ riprende l'ultima coda; i tre riquadri nel player aperto. Golden `now_playing_empty`.

### 81.2 — Skeleton delle schede in streaming (F-49, F-50, F-52, U12)
- Al posto di `streamCardsSoon` (`now_playing_screen.dart:171-182`, `side_panel.dart:55-64`): tre schede `Skeleton` con la stessa forma e altezza delle vere (Testo 5 righe, Info due blocchi da 5 righe, Crediti 3 righe nome-ruolo; `now_playing_cards.dart:27-318`, `credits_card.dart:62-95`), quindi niente salto all'arrivo.
- Dopo 20 s senza riga ombra: «Non disponibile» con Riprova (F-52).
- Test: skeleton finché la riga manca; stesse altezze delle schede vere; dopo 20 s (orologio finto) «Non disponibile», Riprova riparte.

### 81.3 — Suggeriti in arrivo nella coda (F-54, F-55, U13)
- Foglio della coda (`queue_sheet.dart`): dopo i brani veri, tante righe `Skeleton` quanti i suggeriti in arrivo (stato della 80.2) con l'etichetta «Shuffle+ sta scegliendo N brani…»; un suggerito in arricchimento resta riconoscibile finché titolo e copertina non sono definitivi.
- `suggestions_screen.dart:80`: righe skeleton da 72 dp invece dello spinner.
- Test: N righe skeleton con N in arrivo; spariscono quando entrano; nessuna riga skeleton con Shuffle+ spento o in Jam.

### 81.4 — Controlli di fase
`flutter analyze`; comando mirato; golden; code-review high (player e coda); scheggia. Sul Mi A3: skip fino a fine coda; un brano in streaming dall'inizio (skeleton → schede senza salto); Casuale+ con suggeriti in arrivo nel foglio della coda.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Dalla review della fase 77
- `Skeleton.card`: blocco titolo opzionale e variante senza copertina (righe nome-ruolo dei Crediti), così le schede hanno l'altezza delle vere (81.2).
- `Skeleton`: `label` opzionale (es. «Shuffle+ sta scegliendo N brani…», 81.3) e margine orizzontale configurabile (oggi `CcDims.margin` fisso).

## Dalla review della fase 80
- **Un solo percorso «riproduci lista»** (81.1): `playMixed`, `playFromList` e `playOnlineList` (`player_providers.dart:116-303`) ripetono ciclo degli id, `onContext`/`setPlayContext`/permesso notifiche/`playQueue` e ramo Jam. Un `_start(ids, at, ctx, {leaveShufflePlus})` privato; `playFromList` e `playOnlineList` diventano mappature di `playMixed`. I tre riquadri del player vuoto usano quello (niente quarto percorso). Il pulsante Shuffle della pagina del genere usa la stessa lista mista di ▶ (oggi `shuffleIds` di soli brani, `genre_screen.dart:113`).
- **Suggeriti del genere riconoscibili in coda** (81.3): `playMixed` registra gli online del mix come Shuffle+ (`register(r, seedTitle:, suggested: true)` e riga nel `SuggestionLog`), così in coda hanno il badge «Suggerito» (`online_queue_row.dart:65`, `suggested_info.dart:32`) e le azioni «mai più»; `GenreMixState` tiene il `seedTitle`, `MixItem` lo porta. Test: la riga in coda ha il badge.
- **Una sola politica per la radio** (81.3): `genre_mix.dart:97-143` ricopia `_Seed`/`_fill` del controller con regole diverse (raffica di 4 richieste, 429 che non mette in pausa Shuffle+). Un piccolo `RadioGate { lastRadio, pausedUntil }` in `services/shuffle_plus/`, esposto da un provider e usato da `_fill` e dal mix (gap rispettato, `trip()` sul 429, `rateLimited` letto da lì).
- **Righe in arrivo** (81.3): `ShufflePlusPending.incoming` è il numero di slot liberi del piano, non una promessa; torna a 0 in pausa o dopo un errore: i test «N righe con N in arrivo» seguono questa semantica. Un solo `Skeleton.list(rows: N, label:)` (un nodo «Caricamento…» per TalkBack, D-381), in coda e nella pagina del genere (oggi 9 skeleton separati, `genre_screen.dart:148`). `onlineRowExtentOf` per le righe di `suggestions_screen.dart`.
- **Da riusare**: `CcTile` per i tre riquadri del player vuoto (81.1); `RowsLoading`/`AsyncBody(rowHeight)`.
- **Documento**: in `docs/02-architettura.md` la pagina del genere segue lo stato del mix (`GenreMixState`), non `shufflePlusPendingProvider` (:301); `AsyncBody` con skeleton e `rowHeight` (:395); «Mattoni condivisi» con `Skeleton`, `RowsLoading`, `CcTile`, `GenreGrid`, `CcSearchField.onQuery`; Cerca senza segmento Online (:318); politica della radio (:290-297).

## Esiti
- 2026-11-05 — `flutter analyze` pulito; comando mirato più golden del player e delle schermate: 514 test verdi.
- Golden nuovi: `now_playing_empty`, `now_playing_waiting`, `queue_incoming` (phone e desktop, 100 e 150 %), `mini_player_empty` (phone 100 e 150 %); rigenerati i golden di Libreria e `home_fan_open` (cambia il mini player vuoto).
- Code review Opus: 8 bug e 2 ritocchi, tutti applicati (Riprova rifà il download fallito e tiene il token del brano; registro dei suggeriti senza doppioni; Shuffle+ della libreria dopo una radio; ripresa di una coda di stazioni; ▶ coerente con l'etichetta; nessuna ripresa in Jam; attesa delle schede scorrevole nel pannello laterale; secondo tentativo del clip nella prima pagina del mix).
- Scheggia (effort high): 44 mutanti, 9 sopravvissuti, tutti coperti da test nuovi tranne uno equivalente (`(first || gate.canAsk)` nel ritentativo del clip: dopo il primo seme lo blocca già il budget). Bug bassi corretti: suggeriti nel registro solo a coda partita; errore di «Riprendi l'ultima coda» loggato; «Non disponibile» anche con download fermo (tetto di 60 s: il preparer non espone l'avanzamento, un download vivo ma lentissimo mostra «Non disponibile» e Riprova riarma l'attesa). Test instabile delle schede in streaming reso deterministico. Lasciato com'è: la prima pagina del mix di un genere ignora il minuto del `RadioGate` (azione dell'utente; la pausa di 15 min dopo un 429 resta).
- Mi A3: player vuoto a fine coda con «Riprendi l'ultima coda», «Shuffle+ della libreria» e «Ultimi aggiunti»; ▶ del mini player riprende la coda; brano in streaming dall'inizio con skeleton delle schede (titolo «Crediti e dettagli» già presente) e schede vere dopo ~35–40 s; Shuffle+ con il suggerito già in coda dopo ~1 s (le righe «in arrivo» durano meno di un secondo in Wi-Fi: le coprono i test e il golden `queue_incoming`); salto fino alla fine della coda senza errori. Nessuna eccezione nel log.
