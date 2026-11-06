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
- **96.1**: pagina dei generi di YouTube Music **non trovata**. `FEmusic_podcasts` e `FEmusic_non_music_audio` danno 404 con WEB_REMIX (due versioni), ANDROID_MUSIC e IOS_MUSIC, in it/IT ed en/US; `FEmusic_moods_and_genres` ha solo generi musicali; il chip «Podcasts» della home (`FEmusic_home` con params `ggNCSgQIDBAD…`) dà scaffali per categoria ma diversi a ogni richiesta, quindi non un elenco stabile. Generi solo da Apple. Ricerca podcast YTM: params `EgWKAQJQAWoMEA4QChADEAQQCRAF`.
- **96.2**: client Apple (`apple_podcasts.dart`, provider proprio): generi, classifica italiana per genere, lookup nel paese della classifica, ricerca con paese e genere; cache di 4 ore; risposte lette in modo tollerante; errori come `PodcastException(network)` con «Riprova».
- **96.3**: schema v18 (`podcasts.source`, `sourceId`; RSS esistenti invariati); ricerca e pagina programma YTM (`hl=en`, una continuation), iscrizione come per gli RSS, aggiornamento dalla pagina YTM, download solo audio con yt-dlp (`bestaudio[ext=m4a]/bestaudio`, mai video); errori di yt-dlp distinti dalla rete. I podcast non sono nel merge dei dati utente (non lo erano neanche gli RSS): viaggiano con il ripristino completo.
- **96.4**: pagina Podcast con «I tuoi podcast» in riga, «Scopri» (generi Apple localizzati, classifica italiana), ricerca dalla lente che fonde Apple e YTM con l'origine e senza doppioni, «Iscriviti» → «Iscritto»; se una fonte cade l'altra risponde. Build lite: solo Apple.
- **Code review high** (rete e download): 10 rilievi, tutti applicati.
- **Scheggia**: bug alto corretto (disiscrizione durante un download lasciava file e riga `tracks` orfani: ora il download si annulla, `_register` controlla l'episodio e una pulizia d'avvio toglie gli orfani); tag degli episodi mai letti sul telefono dalla fase 23 (closure nell'isolate con `this`): corretto; date, durate e fusione della ricerca più robuste; 7 mutanti coperti.
- **Mi A3** (app vera, `install -r`): migrazione v18 senza perdite; Scopri e chip ok; ricerca «storia» con righe Apple e YTM; programma YTM iscritto, episodio scaricato `.m4a` AAC 127 kb/s senza video, riprodotto; RSS dalla classifica iscritto e aggiornato; iscrizioni di prova tolte. Il residuo del bug (file da 35 MB e riga nascosta) è stato tolto dalla pulizia d'avvio dopo la reinstallazione. L'utente non aveva podcast RSS: «RSS esistenti intatti» coperto dai test.
- **Differenze dal mockup**: niente filtro per fonte nella ricerca (solo l'etichetta su ogni riga); niente conteggio delle iscrizioni; un programma YTM non ancora seguito si apre solo dopo l'iscrizione.
- **Motorola**: rinviato alla fase 97 (D-419, D-420).
