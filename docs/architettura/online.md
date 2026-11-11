# Online

## Scopo

Tutto ciò che esce in rete: ricerca e streaming da YouTube Music, download con yt-dlp, cache degli stream, limiti di richieste, ricerca intelligente, pagine da link (YouTube, Spotify, Deezer), condivisioni Shazam, riconoscimento e arricchimento dei metadati, testi, nuove uscite, radio.

Regola base: nessuna telemetria. Si va in rete solo da azioni dell'utente o da arricchimento opt-in; ogni richiesta ha timeout e User-Agent proprio (`apiUserAgent` = `FreeKmusic/<ver> (<kApiContact>)`).

## Mappa del codice

Tutti in `lib/services/` salvo diversa indicazione.

| Cosa | Dove |
|---|---|
| Servizio YouTube | `online/youtube_service.dart` (`YoutubeService`, `YtResult` con `indexKey`, `MediaSource {youtube, soundcloud}`), `createYtDlpService()`, `ytDlpServiceProvider`, `youtubeServiceProvider` (`DirectSearchService(ytDlp, InnerTubeClient, catalog: ytmCatalog)`), `CachedYoutubeService` |
| yt-dlp | `online/android_yt_dlp_service.dart` (canale `codecore/ytdlp`, `searchTimeout` 45 s), `YtDlpProcessService` (desktop), `yt_dlp_updater`, `yt_dlp_args`, `yt_dlp_version`, `update_checker` |
| Catalogo YTM | `InnerTubeClient`, `YtmCatalog`, `CatalogCache`, `SearchCache` |
| Limiti | `online/request_budget.dart` (`WindowLimiter`), `source_cooldown.dart` (`SourceCooldown`), `budgeted_call.dart` (`budgetedYtm`), `retry_policy`, `shuffle_plus/radio_gate.dart` (`RadioGate`) |
| Ricerca | `online/smart_search.dart` (`SmartSearch`, `SearchNotice`), `query_intent.dart` (`QueryKind {listing, video, album, text, external}`), `youtube_urls.dart`, `merge_results`, `query_match`, `query_cleaner` |
| Link | `online/external_links.dart` (`ExternalService {deezer, spotify}`, `parseExternalLink`, `isShortLink`), `short_link_resolver`, `external_collection.dart` (`ExternalCollection`, `ExternalTrack`, `ExternalReader`, `TrackMatch`), `spotify_embed_reader`, `deezer_client` (`DeezerCollectionReader`), `deezer_gw_client`, `collection_matcher.dart` (`CollectionMatcher`), `shared_text.dart` (`routeSharedText`) |
| Provider link/Shazam | `providers/online_collection_providers.dart` (`OnlineCollectionRef`, `onlineCollectionProvider`, `CollectionPage`), `providers/shazam_providers.dart` |
| Stream e cache | `stream/` (`stream_preparer`, `stream_promoter`, `stream_cache`, `stream_key`, `stream_enrich_trigger`), `online/download_index.dart` |
| Arricchimento | `online/enrich_parts`, `enrich_gather`, `enrich_engine`, `enrich_commit`, `enrich_runner`, `enrich_completer`, `enrich_writer`, `enrichment_service`, `quiet_enricher`, `metadata_resolver`, `cover_fetcher`, `second_opinion`, `credits_enricher`, `curiosity_service`, `curiosity_finder` |
| Client dati | `wikipedia_client`, `itunes_client`, `deezer_client`, `musicbrainz_client`, `discogs_client`, `acoustid_client` |
| Riconoscimento | `recognition/` (`TrackRecognizer`, `track_identity`, `channel_detector`, `cover_detector`, `video_id`) |
| Testi | `online/lyrics_chain.dart` (`LyricsChain`), `lyrics/` (`lrc_parser`, `lyrics_translator(_mlkit)`, `romanization_resolver`, `hangul_romanizer`, `pinyin_dictionary`, `cedict_download`) |
| Nuove uscite | `releases/` (`ReleaseCheckController`, `release_checker`, `check_schedule`, `auto_follow_service`, `release_diff`, `release_notification_text`) |
| Radio | `radio/` (`RadioBrowserClient`, `RadioCatalog`, `radio_prefs`, `near_you`, `icy_title`, `saved_refresh`), `data/repositories/radio_repository.dart` |
| Provider enrich | `providers/enrich_completer_providers`, `recognition_providers`, `second_opinion_providers` |
| Android | `android/app/src/{full,lite}/kotlin/com/codecore/player/YtDlpChannel.kt`, `full/.../NewPipeUrl.kt`, `main/.../IncomingBridge.kt` |

## Come funziona

### Flavor full e lite

- Android `full`: con yt-dlp (`src/full/.../YtDlpChannel.kt`, `NewPipeUrl.kt`). `lite`: senza (`CODECORE_LITE=1` e `--dart-define=CODECORE_YOUTUBE=false`, `src/lite/.../YtDlpChannel.kt`). L'interruttore Gradle è in `android/app/build.gradle.kts`.
- In Dart `kEnableYoutube` (`core/constants.dart`) spegne le funzioni YouTube nel lite.
- Desktop: `YtDlpProcessService` lancia il processo yt-dlp. Su Android yt-dlp si aggiorna in `ensureInit()` di `YtDlpChannel.kt`, cioè solo quando viene chiamato.
- Un solo `createYtDlpService()` per app (creato in `main.dart`).

### Ricerca

1. `SmartSearch` classifica la query (`QueryKind`) e sceglie: elenco, video, album, testo, link esterno.
2. `youtubeServiceProvider` cerca col catalogo YTM (`InnerTubeClient`); yt-dlp serve a stream e download.
3. `merge_results`, `query_match` e `query_cleaner` fondono e ripuliscono. `SearchCache` e `CatalogCache` evitano richieste ripetute.

### Streaming, cache e righe ombra

- Un brano online riceve un id negativo (`OnlineEntries`). Chiave: `downloadIndexKey(source, id)` (`<source>:<id>`).
- `StreamPreparer` avvia dall'URL e scarica in `StreamCache` in parallelo; riproduzione lato audio in `riproduzione-e-coda.md`.
- Il primo ascolto crea la riga ombra (`kind = 2`, `path = 'stream:<key>'`); il download la fonde in una riga reale (`mergeStreamRow`). Dettagli e pulizia in `libreria-e-dati.md`.
- Lo streaming funziona anche a consumo (D-68).

### yt-dlp e download

- Desktop: se `locateYtDlp` non trova yt-dlp, o la versione ha più di 90 giorni, `YtDlpUpdateNotifier` scarica da solo la copia gestita (avviso nelle attività, «Riprova» se la rete fallisce) (D-563).
- Gli errori del canale Android con radice di classe JVM (`| root: <classe>`) sono di tipo «interno»: niente ritentativi e niente «YouTube è cambiato». Gli stderr veri di yt-dlp restano come prima.
- Su Android da 11 il download passa da una cartella di lavoro e `MediaPublisher.publish` lo pubblica in `Music/FreeKmusic` (vedi `piattaforme.md`).

### Limiti, budget e pause

- `WindowLimiter(perMinute)`: `acquire` attende, `tryAcquire` risponde subito. Costanti: `kWikimediaAnonymousPerMinute = 8`, `kWikimediaIdentifiedPerMinute = 150`, `kSearchRowsPerMinute = 20`, `kLinkMatchPerMinute = 40`.
- `SourceCooldown`: 5 min di pausa dopo un 429, per `MediaKind`.
- `budgetedYtm(cooldown, limiter, run, cost)`: restituisce null se non c'è budget o la fonte è in pausa; un 429 fa scattare la pausa (D-425).
- Radio: `RadioGate` ha una politica sua. Podcast: `kPodcastRequestsPerMinute`.
- Deezer: al massimo 10 richieste al secondo e 5 s di pausa su «too many requests» (D-523). MusicBrainz: almeno 1,1 s tra le richieste. AcoustID: al massimo 3 al secondo.
- La corrispondenza dei link ha una finestra propria da 40/min (D-526).

### Pagine da link

1. Un testo condiviso (Android: `IncomingBridge.kt`, `takeIncomingText`) passa da `routeSharedText` → `SharedLink | ShazamShare | PlainShare`. Shazam si controlla **prima** dei link.
2. `parseExternalLink` riconosce `ExternalService` e tipo; `short_link_resolver` espande i link brevi.
3. `onlineCollectionProvider` (`OnlineCollectionRef` = `YoutubeListingRef | ExternalRef`) produce una `CollectionPage`.
4. Un `ExternalReader` legge la raccolta: Spotify con una sola GET della pagina embed, senza ritentativi (D-521); Deezer con `DeezerCollectionReader`.
5. `CollectionMatcher` abbina ogni traccia a un brano YTM o di libreria, passando da `budgetedYtm` con il limite dei link. Esiti (`TrackMatch`): `TrackPending`, `TrackReady(Online|Library)`, `TrackNotFound`; per la raccolta `CollectionNotFound`, `CollectionUnreadable`.

### Shazam

`ShazamShare` entra in `ShazamInbox.add`, che risponde `ShazamAdded`, `Duplicate`, `NotFound` o `Retry`. I brani vanno nella playlist «Da Shazam» (`kShazamPlaylistName`, uuid in `shazamPlaylistUuid`); `shazamAutoDownload` scarica in automatico. Le righe ombra possono stare in playlist (D-524).

### Riconoscimento e arricchimento

- Cascata di `TrackRecognizer`: 1) ISRC o MBID nei tag → MusicBrainz; 1b) id video YouTube → YTM; 2) ricerca testuale con tag affidabili; 3) AcoustID con impronta (`Fingerprinter`; non per Opus/WebM; punteggio ≥ 0,9 e durata ±10 s); 4) YTM `searchSongs`. Soglie D-300..D-311.
- Il risultato (`rec`, JSON in `track_enrich`, versione `kRecogVersion`) è una proposta. Le correzioni passano solo da `TrackCorrections` → `TrackEditor` → Registro (`activity_log`).
- Arricchimento: `enrich_parts` (`isDue`, `dueSql`, `eligibleSql`, `fillableFields`, `statusAfter`, `AskMode`) decide cosa fare; gather/engine/commit/runner/completer lo eseguono; `enrich_writer` è l'**unico** a scrivere `tracks.enrich_status`. Parte quando l'utente è inattivo e dopo `startupSettledProvider`.
- Segnali di stato nel backup: `recogPassAfter/Done`, `enrichMarkKey` sono legati al dispositivo.

### Testi

`LyricsChain`: LRCLIB, poi NetEase per i sincronizzati (`romalrc` per la romanizzazione), poi lyrics.ovh (D-111). Romanizzazione in `services/lyrics/` (hangul, pinyin con CC-CEDICT scaricato al primo uso dalla release `data-cedict-2026-11-08`). Traduzione con `google_mlkit_translation`. `handWrittenLyrics` non equivale a `byUser` (D-482).

### Nuove uscite

`ReleaseCheckController` (tenuto vivo da `CodecoreApp`) controlla a giri di 24 h (`check_schedule`). `auto_follow_service` segue gli artisti più ascoltati negli ultimi 90 giorni, con memoria delle ricerche di 30 giorni. `release_diff` confronta, `release_notification_text` compone la notifica. Tabelle `followed_artists`, `artist_releases`, `artist_lookups`.

### Radio

`RadioBrowserClient.standard()` + `RadioCatalog` per il catalogo, `RadioRepository` per le stazioni salvate, `near_you` per le vicine, `icy_title` per il titolo in onda, `saved_refresh` per aggiornare le salvate. La pulizia cache non tocca le stazioni salvate.

### Podcast

`lib/services/podcast/`: `feed_fetcher` (Dio a flusso, max 20 MB, solo http/https), `podcast_service` (`refreshIfStale` a 6 ore), `episode_downloader`, `apple_podcasts` (ricerca iTunes), `ytm_podcast_sync`, `rss_parser`, `podcast_cleanup`.

- La rete parte solo da un'azione dell'utente (iscriversi, «Aggiorna», aprire una pagina con ultimo controllo oltre 6 ore, «Scarica»), mai all'avvio.
- Gli episodi scaricati stanno in `<appSupportDir>/podcasts/<id>/`, fuori da `folders`: la scansione non li vede.
- Il gestore audio non scrive sui podcast: chiama `onEpisodeHeard`, che `main.dart` collega a `PodcastRepository.markPlayedByTrack`.

## Invarianti da non rompere

- Ogni chiamata YTM passa da `budgetedYtm`; un 429 deve far scattare il `SourceCooldown`.
- Timeout e User-Agent propri su ogni richiesta; contatto in `kApiContact` (D-298).
- Niente richieste web non richieste dall'utente o dall'arricchimento opt-in. Niente telemetria.
- `enrich_writer` è l'unico scrittore di `tracks.enrich_status`.
- Le correzioni ai brani passano da `TrackEditor` e finiscono nel Registro.
- Spotify: una sola GET, nessun ritentativo (D-521).
- `artistKey` non cambia senza migrazione.
- Gli id negativi non finiscono nella coda salvata.
- Nel flavor lite le funzioni YouTube restano spente (`kEnableYoutube`).

## Come si estende

- **Nuovo servizio di link** (es. un'altra piattaforma): valore in `ExternalService`, riconoscimento in `parseExternalLink`, un `ExternalReader`, e il ramo in `onlineCollectionProvider`. L'abbinamento resta in `CollectionMatcher`.
- **Nuova fonte di metadati**: client dedicato (timeout, User-Agent, `WindowLimiter` o cooldown suoi), poi uso da `enrich_gather` / `metadata_resolver`.
- **Nuovo passo del riconoscimento**: in `TrackRecognizer`, con soglia esplicita e versione `kRecogVersion` aggiornata se cambia l'esito.
- **Nuovo limite**: costante in `request_budget.dart` e finestra condivisa; non creare timer a parte.
- **Nuova fonte di testi**: anello in `LyricsChain`, in ordine di priorità.
- **Nuova stringa di notifica o avviso**: ARB in 6 lingue.
- **Nuovo `MediaSource`**: in `YtResult`/`downloadIndexKey`, con la chiave in `downloads.json`.

## Trappole

- Deezer gw (`gw-light.php`) vuole un corpo JSON `{}` anche per `deezer.getUserData`: senza risponde 400. Il `checkForm` vale con il cookie `sid` della stessa sessione.
Dalle vecchie trappole (archivio `../storico/gotchas.md`):

- `WebClient.getJson` dà null in caso di errore, a meno di `strict: true` (D-131).
- Deezer gw vuole un corpo JSON `{}`; `/search` non restituisce il BPM.
- AcoustID: `meta=recordings releases compress` con spazi.
- YTM `next` non contiene «Provided to YouTube by»: usare `musicVideoType` (ATV/OMV).
- AcoustID può accettare un altro brano con lo stesso titolo.
- Wikimedia anonimo: 8 richieste/min; serve `kApiContact` (D-298).
- Un `FutureProvider` di Riverpod 3 ritenta fino a 10 volte: impostare `retry: (_, _) => null`.
- Il debounce non deve ripartire a ogni evento (`debounce ??= Timer`).
- yt-dlp su Android si aggiorna solo quando viene chiamato (`ensureInit()`).
- Rete universitaria (UniBA): broadcast /16 che confonde le prove LAN.
- Non «correggere» un bug senza cercarlo in `decisioni.md` (es. D-155).

## Decisioni chiave

Link a `../decisioni.md`:

- D-111: catena dei testi (LRCLIB, NetEase, lyrics.ovh).
- D-131: `WebClient` con `strict`.
- D-298: `kApiContact`.
- D-300..D-311: soglie del riconoscimento.
- D-425: `budgetedYtm`; D-465 / D-466: alias e budget.
- D-435 / D-470: podcast `followed`.
- D-482: testi a mano diversi da `byUser`.
- D-510..D-514, D-527: pagine da link.
- D-515..D-526, D-530, D-537: Shazam, link, streaming nelle playlist (D-521 Spotify embed, D-523 limite Deezer, D-524 righe ombra, D-526 limite dei link).
- D-81 / D-138..D-145: cache e streaming veloce.
