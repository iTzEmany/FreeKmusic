# Fase 96 — Podcast: Scopri e YouTube Music (refactor «superfici-e-ricerca»)

**Obiettivo:** la pagina Podcast diventa navigabile (generi, classifica italiana, ricerca unica Apple + YouTube Music) e i programmi YouTube Music si seguono come gli RSS.

**Prerequisiti:** fase 95 chiusa. Mockup `refactor/superfici-e-ricerca/mockup/podcast.html`. Decisioni D-387, D-397, D-403, D-404, D-415. Rilievi F-97, F-98, F-102. Aree a rischio: rete (rate limit, budget), download.

**Comando mirato:** `flutter test test/ui/podcast_screens_test.dart test/services/podcast test/services/online/innertube_client_test.dart test/services/online/request_budget_test.dart test/data/backup_merge_test.dart test/services/backup/restore_service_test.dart` più i test nuovi.

## Task

### 96.1 — Pagina dei generi di YouTube Music (F-102)
- Primo passo, a tempo (mezza giornata). `FEmusic_podcasts` e `FEmusic_non_music_audio` rispondono 404 con WEB_REMIX (2026-11-05): provare altri client/`hl`/regione e il browse partendo dalla home di YTM. Esito (trovata o no, con la richiesta) scritto in Esiti. Se non c'è: generi solo da Apple.

### 96.2 — Client Apple (F-97, F-98, D-403)
- In `lib/services/podcast/podcast_service.dart` (ricerca a `:183`, da estendere con `country` e `genreId`): generi (`itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?id=26`), classifica (`itunes.apple.com/it/rss/toppodcasts/limit=N/genre=ID/json`), `lookup?id=` per il feed. Solo endpoint `itunes.apple.com` (i `marketingtools` sono instabili); rete con `WebClient`/`RateLimiter`; cache di qualche ora; errore gentile con «Riprova».
- Test con fixture JSON in `test/fixtures/` (accanto a `itunes_podcast_search.json`): generi, classifica, lookup, ricerca con paese/genere; risposta 502 → errore gentile; cache valida → nessuna richiesta.

### 96.3 — Client YouTube Music (F-102, D-404)
- In `lib/services/online/` (accanto a `innertube_client.dart`): ricerca programmi col filtro podcast (params presi dal codice di riferimento in `~/.pub-cache` o dalla prova di rete, non a memoria), pagina programma `MPSPP…` con episodi (`MUSIC_VIDEO_TYPE_PODCAST_EPISODE`, `videoId`). Nel `request_budget.dart`. Fixture nuove in `test/fixtures/innertube/`.
- Iscrizione come per gli RSS (tabella `podcasts` con la fonte, migrazione + `dart run build_runner build --delete-conflicting-outputs`, backup e `backup_merge` con test di ripristino, D-397); episodi nuovi dalla pagina YTM; scaricamento solo audio con la via yt-dlp esistente (formati 139/249/250, verificati il 2026-11-05; il player WEB_REMIX dice `UNPLAYABLE`, quindi non si usa).
- Test: parser ricerca e pagina; iscrizione e aggiornamento episodi; download sceglie l'audio; backup vecchi ripristinabili.

### 96.4 — Pagina Podcast (F-97, D-403, D-415)
- Aperta dalla Libreria come oggi (`lib/ui/screens/podcast/podcasts_screen.dart`): «I tuoi podcast» in riga, «Scopri» con chip di generi solo testo e classifica, ricerca unica dalla lente che fonde Apple e YTM con l'origine su ogni riga, «Iscriviti» → «Iscritto». Caricamenti fuori dal thread UI con skeleton.
- Test (widget): iscritto/non iscritto; chip cambia classifica; ricerca fusa senza doppioni; errore di rete con Riprova; a11y e bersagli ≥ 48 dp. ARB it/en/de/es.

### 96.5 — Controlli di fase
`flutter analyze`; comando mirato; golden Podcast rigenerati (`scripts/shots.sh`); build lite (`--dart-define=CODECORE_YOUTUBE=false`): solo Apple, nessun accenno a YTM; review del diff (code-review high su rete e download); scheggia. Motorola edge 40 (ZY22HKD85K) e Mi A3 (0d7ae9df206e) via adb: Scopri, un programma YTM (iscrizione, episodio scaricato e riprodotto), RSS esistenti intatti.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
