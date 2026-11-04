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

## Esiti
