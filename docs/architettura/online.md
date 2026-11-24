# Online

## Scopo

Tutto ciò che esce in rete: ricerca e streaming da YouTube Music, download con yt-dlp, cache degli stream, limiti di richieste, ricerca intelligente, pagine da link (YouTube, Spotify, Deezer), condivisioni Shazam, riconoscimento e arricchimento dei metadati, testi, nuove uscite, radio.

Regola base: nessuna telemetria. Si va in rete solo da azioni dell'utente o da arricchimento opt-in; ogni richiesta ha timeout e User-Agent proprio (`apiUserAgent` = `FreeKmusic/<ver> (<kApiContact>)`).

## Mappa del codice

Tutti in `lib/services/` salvo diversa indicazione.

| Cosa | Dove |
|---|---|
| Servizio YouTube | `online/youtube_service.dart` (`YoutubeService`, `YtResult` con `indexKey`, `MediaSource {youtube, soundcloud}`), `createYtDlpService()`, `ytDlpServiceProvider`, `youtubeServiceProvider` (`DirectSearchService(ytDlp, InnerTubeClient, catalog: ytmCatalog)`), `CachedYoutubeService` |
| yt-dlp | `online/android_yt_dlp_service.dart` (canale `codecore/ytdlp`, `searchTimeout` 45 s), `YtDlpProcessService` (desktop), `yt_dlp_updater`, `yt_dlp_args`, `yt_dlp_version`, `update_checker`; `videoUrl` (Android: `NewPipeUrl.videoUrl`, poi canale `ytdlpVideoUrl` con `videoOnlyFormat`; desktop: `buildVideoUrlArgs`) |
| Catalogo YTM | `InnerTubeClient`, `YtmCatalog`, `CatalogCache`, `SearchCache` |
| Limiti | `online/request_budget.dart` (`WindowLimiter`), `source_cooldown.dart` (`SourceCooldown`), `budgeted_call.dart` (`budgetedYtm`), `retry_policy`, `shuffle_plus/radio_gate.dart` (`RadioGate`) |
| Ricerca | `online/smart_search.dart` (`SmartSearch`, `SearchNotice`), `query_intent.dart` (`QueryKind {listing, video, album, text, external}`), `youtube_urls.dart`, `merge_results`, `query_match`, `query_cleaner`; `SmartSearch.run(videoOnly:)` |
| Link | `online/external_links.dart` (`ExternalService {deezer, spotify}`, `parseExternalLink`, `isShortLink`), `short_link_resolver`, `external_collection.dart` (`ExternalCollection`, `ExternalTrack`, `ExternalReader`, `TrackMatch`), `spotify_embed_reader`, `deezer_client` (`DeezerCollectionReader`), `deezer_gw_client`, `collection_matcher.dart` (`CollectionMatcher`), `shared_text.dart` (`routeSharedText`) |
| Provider link/Shazam | `providers/online_collection_providers.dart` (`OnlineCollectionRef`, `onlineCollectionProvider`, `CollectionPage`), `providers/shazam_providers.dart` |
| Stream e cache | `stream/` (`stream_preparer`, `stream_promoter`, `stream_cache`, `stream_key`, `stream_enrich_trigger`), `online/download_index.dart` |
| Arricchimento | `online/enrich_parts`, `enrich_gather`, `enrich_engine`, `enrich_commit`, `enrich_runner`, `enrich_completer`, `enrich_writer`, `enrichment_service`, `quiet_enricher`, `metadata_resolver`, `cover_fetcher`, `second_opinion`, `credits_enricher`, `curiosity_service`, `curiosity_finder` |
| Client dati | `wikipedia_client`, `itunes_client`, `deezer_client`, `musicbrainz_client`, `discogs_client`, `acoustid_client` |
| Riconoscimento | `recognition/` (`TrackRecognizer`, `track_identity`, `channel_detector`, `cover_detector`, `video_id`) |
| Testi | `online/lyrics_chain.dart` (`LyricsChain`), `lyrics/` (`lrc_parser`, `lyrics_translator(_mlkit)`, `romanization_resolver`, `hangul_romanizer`, `pinyin_dictionary`, `cedict_download`); `karaokeLyricsQuery`, `LyricsChain.find(ignoreDuration:)` |
| Video karaoke | `karaoke_video/` (`karaoke_video.dart`: `isKaraokeVideo`, `karaokeVideoId`; `karaoke_video_source.dart`: `KaraokeVideoStream`, `KaraokeVideoSource`; `karaoke_video_cache.dart`: `KaraokeVideoCache`), `online/karaoke_filter.dart` (`karaokeResults`), `online/karaoke_channels.dart` (`kKnownKaraokeChannels`), `providers/karaoke_video_cache_providers.dart` |
| Nuove uscite | `releases/` (`ReleaseCheckController`, `release_checker`, `check_schedule`, `auto_follow_service`, `release_diff`, `release_notification_text`) |
| Radio | `radio/` (`RadioBrowserClient`, `RadioCatalog`, `radio_prefs`, `near_you`, `icy_title`, `saved_refresh`), `data/repositories/radio_repository.dart` |
| Provider enrich | `providers/enrich_completer_providers`, `recognition_providers`, `second_opinion_providers` |
| Aggiornamento dall'app | `update/update_target.dart` (`detectUpdateTarget`, `pickUpdateAsset`, `selfInstalls`), `update/update_installer.dart`, `update/android_update.dart`, `update/desktop_update.dart`; `providers/update_providers.dart`; `online/update_checker.dart` (`UpdateInfo`, `UpdateAsset` con nome, URL, dimensione, `digest`) |
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
- **Streaming per prima** (fase 140, D-665, D-666): la modalità predefinita è `stream` (`kDefaultStorageMode`); chi aggiorna ci passa una sola volta all'avvio (`SettingsStore.migrateStorageModeD665`, flag `storageModeD665` legato al dispositivo, fuori dal backup; solo la preferenza cambia, nessun file toccato, nessun download); la `lite` è sempre `device` e non mostra la scelta. I file già sul dispositivo restano locali. Scaricare è sempre una scelta: singolo, selezione, playlist, album («Scarica» di massa con conferma su rete a consumo), import con «scarica anche» (scelta persistita in `importDownloadToo.<id>` finché l'import non viene annullato). La cartella dei download è fissa dentro una cartella scansionata (`<scelta>/FreeKmusic` su desktop, `Music/FreeKmusic` su Android). Gli id degli stream si validano dove entrano (`isStreamKey`: YouTube 11 caratteri `[A-Za-z0-9_-]`, SoundCloud numerico): link `watch?v=`, offerte in LAN, backup, import.
- **Stato del brano** (fase 139, D-695): `trackStateProvider(trackStateKey(track))` dice `online`, `savedStream` o `downloaded`. La chiave è `<source>:<id>` per i brani in streaming (anche il `Track` sintetico online, ricavata dal path `online:`), `#id` per le righe locali; si aggiorna da `downloadIndexProvider` (invalidato da download, «Libera spazio», «Elimina dal dispositivo»), `savedStreamKeysProvider` e la riga. È l'unica fonte per la UI (righe online, suggerimenti, generi, menu ⋮): niente `inLibraryOf`/`downloadIndex.contains` nei widget (`inLibraryOfProvider` resta ai servizi non-UI: `LibraryAdder`, `JamSaver`). L'indice dei download si legge dalla memoria (`pathFor`/`pathForKey`/`contains`, nessun I/O sul thread UI); l'esistenza del file si verifica con `await` dove serve aprirlo (`existingPathFor`/`existingPathForKey`: riproduzione, Jam, import) e prima di NON scaricare perché indicizzato si verifica il file (`containsOnDisk`: se manca, la voce si dimentica, `onForget` invalida `downloadIndexProvider` e il download parte); `pruneGone` toglie le voci sparite, ricontrollando il file prima di dimenticarle (una sola volta per processo alla prima creazione di `downloadIndexProvider`, non a ogni ricarica: un file invisibile per un permesso mancante non deve svuotare l'indice; e in «Libera spazio»; «Elimina dal dispositivo» usa `removeByPaths` (una sola scrittura) perché la guardia «cartella presente» non vedrebbe una cartella vuota rimossa); `signatureMatches*` è asincrono. Il menu ⋮ ascolta e legge dal container e, se la riga che l'ha aperto viene smontata, le azioni si riprendono, al tocco, da una ricostruzione con il contesto e il `ref` di un host nell'overlay radice, tenuto finché l'azione non finisce (altrimenti Elimina + conferma userebbe un `ref` smontato). Cancellando una riga a cui una voce online era legata (`trackId`), `removeTracks` slega la voce (`OnlineEntries.unbindRows`). Il player tiene l'id negativo anche a download finito: lo stato del brano corrente si legge dalla chiave, non dall'id. Scaricare salva (`LibraryAdder.download`: salva, poi scarica, in ogni modalità): non esiste un «scaricato non salvato». Nelle viste online il pulsante è «Aggiungi alla libreria»; «Scarica» (per un brano salvato in streaming, «Scarica sul dispositivo») e «Aggiungi alla playlist» stanno nel menu ⋮, anche per il brano che suona (id negativo, voci della riga incluse se legato).
- `StreamPreparer` avvia dall'URL e scarica in `StreamCache` in parallelo; riproduzione lato audio in `riproduzione-e-coda.md`.
- Il primo ascolto crea la riga ombra (`kind = 2`, `path = 'stream:<key>'`); il download la fonde in una riga reale (`mergeStreamRow`). Dettagli e pulizia in `libreria-e-dati.md`.
- Lo streaming funziona anche a consumo (D-68).
- `StreamCache.keepLonger` (preferiti) fa togliere i preferiti per ultimi dalla cache.
- `libraryAdder` è l'unico ingresso per aggiungere un brano online: `storageMode` decide tra salvare (streaming) e scaricare (dispositivo); Shazam e importazione passano da lì.

### yt-dlp e download

- Desktop: se `locateYtDlp` non trova yt-dlp, o la versione ha più di 90 giorni, `YtDlpUpdateNotifier` scarica da solo la copia gestita (avviso nelle attività, «Riprova» se la rete fallisce) (D-563).
- Gli errori del canale Android con radice di classe JVM (`| root: <classe>`) sono di tipo «interno»: niente ritentativi e niente «YouTube è cambiato». Gli stderr veri di yt-dlp restano come prima.
- Su Android da 11 il download passa da una cartella di lavoro e `MediaPublisher.publish` lo pubblica in `Music/FreeKmusic`, sul volume scelto (SD compresa; vedi `piattaforme.md`).
- Qualità: `AudioQuality` (alta, media, bassa) è in `DownloadOptions` e in `StreamPreparer.quality`; `capKbps` (135 e 64) è l'unico numero, usato da `yt_dlp_args` e passato a NewPipe (`streamUrl`, `capKbps`).
- Brani spariti da YouTube: `isVideoGone` riconosce l'errore, il player chiama `onStreamGone`, `VanishedTracks` cerca il sostituto (durata ±2 s) e lo scrive nel Registro; un solo tentativo per sessione.
- «Tieni offline» (playlist e album) scarica sempre tramite `downloadsProvider`, mai a parte.

### Limiti, budget e pause

- `WindowLimiter(perMinute)`: `acquire` attende, `tryAcquire` risponde subito. Costanti: `kWikimediaAnonymousPerMinute = 8`, `kWikimediaIdentifiedPerMinute = 150`, `kSearchRowsPerMinute = 20`, `kLinkMatchPerMinute = 40`.
- `SourceCooldown`: 5 min di pausa dopo un 429, per `MediaKind`.
- `budgetedYtm(cooldown, limiter, run, cost)`: restituisce null se non c'è budget o la fonte è in pausa; un 429 fa scattare la pausa (D-425).
- Radio: `RadioGate` ha una politica sua. Podcast: `kPodcastRequestsPerMinute`.
- Deezer: al massimo 10 richieste al secondo e 5 s di pausa su «too many requests» (D-523). MusicBrainz (`MusicBrainzClient`, D-683): una sola coda per tutti i chiamanti, almeno 1,1 s tra le richieste; dopo un 503 pausa di 1, 5, poi 15 min (azzerata da un successo), durante la quale ogni richiesta lancia `MusicBrainzUnavailable` senza rete (`resting`, `restUntil`); cache in memoria di 6 h, anche dei «non trovato»; un giro forzato passa da `MusicBrainzClient.fresh` e salta la cache. AcoustID: al massimo 3 al secondo.
- La corrispondenza dei link ha una finestra propria da 40/min (D-526).

### Pagine da link

1. Un testo condiviso (Android: `IncomingBridge.kt`, `takeIncomingText`) passa da `routeSharedText` → `SharedLink | ShazamShare | SharedCollection | InvalidShareLink | PlainShare`. Shazam si controlla **prima** dei link e la pagina di condivisione prima di Shazam. Un link della pagina di condivisione (`https://itzemany.github.io/FreeKmusic/#…`, anche dentro un testo) dà `SharedCollection` (frammento decodificato da `decodeShareFragment`) o `InvalidShareLink`; `handleSharedPage` (`ui/shell/shared_collection_import.dart`) cerca ogni video per id e salva la playlist con `saveToLibrary`.
2. `parseExternalLink` riconosce `ExternalService` e tipo; `short_link_resolver` espande i link brevi.
3. `onlineCollectionProvider` (`OnlineCollectionRef` = `YoutubeListingRef | ExternalRef`) produce una `CollectionPage`.
4. Un `ExternalReader` legge la raccolta: Spotify con una sola GET della pagina embed, senza ritentativi (D-521); Deezer con `DeezerCollectionReader`.
5. `CollectionMatcher` abbina ogni traccia a un brano YTM o di libreria, passando da `budgetedYtm` con il limite dei link. Esiti (`TrackMatch`): `TrackPending`, `TrackReady(Online|Library)`, `TrackNotFound`; per la raccolta `CollectionNotFound`, `CollectionUnreadable`.

### Shazam

`ShazamShare` entra in `ShazamInbox.add`, che risponde `ShazamAdded`, `Duplicate`, `NotFound` o `Retry`. I brani vanno nella playlist «Da Shazam» (`kShazamPlaylistName`, uuid in `shazamPlaylistUuid`); `shazamAutoDownload` scarica in automatico (in modalità streaming salva senza scaricare, D-576). Le righe ombra possono stare in playlist (D-524).

### Riconoscimento e arricchimento

- Cascata di `TrackRecognizer`: 1) ISRC o MBID nei tag → MusicBrainz; 1b) id video YouTube → YTM; 2) ricerca testuale con tag affidabili; 3) AcoustID con impronta (`Fingerprinter`; non per Opus/WebM; punteggio ≥ 0,9 e durata ±10 s); 4) YTM `searchSongs`. Soglie D-300..D-311.
- Il risultato (`rec`, JSON in `track_enrich`, versione `kRecogVersion`) è una proposta. Le correzioni passano solo da `TrackCorrections` → `TrackEditor` → Registro (`activity_log`).
- Arricchimento: `enrich_parts` (`isDue`, `dueSql`, `eligibleSql`, `fillableFields`, `statusAfter`, `AskMode`) decide cosa fare; gather/engine/commit/runner/completer lo eseguono; `enrich_writer` è l'**unico** a scrivere `tracks.enrich_status`. Parte quando l'utente è inattivo e dopo `startupSettledProvider`.
- Motore unico (D-683, chiude D-280): completer, runner, righe in streaming (ascolto, Shuffle+, import: `streamEnrichRowProvider` → `EnrichEngine.completeOne`) e seconda opinione (`engine.commit`) scrivono tutti dal motore: solo campi vuoti, segni «niente», status, switch automatici. Titolo e artista di una riga stream non si sovrascrivono; un secondo ascolto non chiede nulla.
- Per brano: `withTrackMemo`/`memoPerTrack` (`enrich_gather`) fanno una sola richiesta `recordingsByIsrc` e una sola ricerca Deezer, condivise da riconoscimento, crediti e curiosità.
- `MusicBrainzUnavailable` (503 o pausa) vale `PartOutcome.limited`: il giro si ferma. Il finder dei paesi si ferma se il client è in pausa. Il completer non parte durante una Jam, senza rete o su rete a consumo, salvo l'impostazione `enrichOnMetered` (spenta di default).
- Segnali di stato nel backup: `recogPassAfter/Done`, `enrichMarkKey` sono legati al dispositivo.

### Testi

`LyricsChain`: LRCLIB, poi NetEase per i sincronizzati (`romalrc` per la romanizzazione), poi lyrics.ovh (D-111). Romanizzazione in `services/lyrics/` (hangul, pinyin con CC-CEDICT scaricato al primo uso dalla release `data-cedict-2026-11-08`). Traduzione con `google_mlkit_translation`. Brani strumentali (`track_enrich.instrumental`, da LRCLIB `instrumental: true` o dal titolo, D-684): niente ricerca dei testi né separazione karaoke, la vista mostra «Brano strumentale». `handWrittenLyrics` non equivale a `byUser` (D-482).

### Video karaoke (fase 131, D-631..D-639, D-646, D-649, D-651, D-661)
- **Cerca**: quarto filtro `SourceFilter.karaoke`, solo con `kEnableYoutube`. Fa una richiesta nuova (`SmartSearch.run(videoOnly:)`, «karaoke» aggiunto alla query, chiave di cache con `|v`); gli altri tre guardano le righe già presenti. `karaokeResults` tiene i titoli con «karaoke», toglie reaction e cover/live solo se sono un'etichetta e non una parola del titolo, e mette prima i canali noti (`kKnownKaraokeChannels` in `online/karaoke_channels.dart`). Un link incollato non si filtra.
- **Riconoscimento**: è un video karaoke un brano in streaming YouTube (`online:youtube:<id>` o riga ombra `stream:youtube:<id>`) con «karaoke» nel titolo (`isKaraokeVideo`, `karaokeVideoId`). YTM e video condividono `youtube:`: anche un «... karaoke» di YTM mostra il video (D-646). Scaricato o locale: niente video (D-636).
- **Indirizzo**: `videoUrl` dà solo il video, 360p e al massimo 480p, avc1 se c'è. Android: NewPipe (`NewPipeUrl.videoUrl`), poi yt-dlp `-g` dal canale `ytdlpVideoUrl` con `videoOnlyFormat`. Desktop: yt-dlp (`buildVideoUrlArgs`). `expires` viene dal parametro `expire`. Nel lite risponde `toolMissing`.
- **Cache**: `KaraokeVideoCache` scarica con `dio` in `StreamCache` con chiave `video:karaoke:youtube:<id>` (D-661). `pin` mentre suona o sta nella coda manuale; cancellato 15 minuti dopo l'ultimo uso su ogni piattaforma, controllo ogni 2 min. Precarico dei video dei brani in coda a mano, uno alla volta, con `prefetchOnMobile`.
- **Nella Jam (fase 148, D-710)**: `jamKaraokeVideoProvider` (autoDispose, in `karaoke_video_providers.dart`) crea un secondo `KaraokeVideoController` guidato dallo stato della Jam: id da `jamKaraokeVideoId(JamItem)` (solo item `selfFetchable` con «karaoke» nel titolo: un item di libreria o scaricato non ha video, D-636), posizione `positionAtTime(jamNowMs())` subito e poi ogni 250 ms, `playing` della Jam; stessa sorgente e cache del player, nessun cancello sull'audio della Jam. La schermata della Jam (`_JamPlayer`) lo guarda solo con un item karaoke e la Jam attiva, e mostra `KaraokeVideoView(provider:, cover:)` al posto dell'anello; schermo intero come nel player. Nessuna modifica al protocollo: ogni dispositivo apre il video da sé.
- **Testi**: `LyricsChain.find(ignoreDuration: true)`: query da `karaokeLyricsQuery`, LRCLIB solo `/search`, senza durata, con il titolo identico dopo la normalizzazione.

### Nuove uscite

`ReleaseCheckController` (tenuto vivo da `CodecoreApp`) controlla a giri di 24 h (`check_schedule`). `auto_follow_service` segue gli artisti più ascoltati negli ultimi 90 giorni, con memoria delle ricerche di 30 giorni. `release_diff` confronta, `release_notification_text` compone la notifica. Tabelle `followed_artists`, `artist_releases`, `artist_lookups`.

### Radio

`RadioBrowserClient.standard()` + `RadioCatalog` per il catalogo, `RadioRepository` per le stazioni salvate, `near_you` per le vicine, `icy_title` per il titolo in onda, `saved_refresh` per aggiornare le salvate. La pulizia cache non tocca le stazioni salvate.

### Classifiche (Top 20 per genere)

`chart_genres.dart` elenca i 12 macrogeneri (D-591) con ID Deezer (principale e ripiego) e `genreId` Apple. `ChartRef` in `online_collection_providers.dart` legge `CatalogCache` (`CatalogKind.chart`, 24 h): voce fresca = nessuna chiamata e nessuna ricerca YouTube (RNF-02). Altrimenti `DeezerClient.chart` → ripiego Deezer → `AppleRssClient.mostPlayed` filtrato per `genreId` → copia scaduta con la sua data. Gli abbinamenti `TrackReadyOnline` si scrivono nella voce (`put(keepDate:)`); i «non trovato» si richiedono a ogni rilettura. La pagina è `OnlinePlaylistScreen` come per i link Deezer/Spotify.

### Podcast

`lib/services/podcast/`: `feed_fetcher` (Dio a flusso, max 20 MB, solo http/https), `podcast_service` (`refreshIfStale` a 6 ore), `episode_downloader`, `apple_podcasts` (ricerca iTunes), `ytm_podcast_sync`, `rss_parser`, `podcast_cleanup`.

- La rete parte solo da un'azione dell'utente (iscriversi, «Aggiorna», aprire una pagina con ultimo controllo oltre 6 ore, «Scarica»), mai all'avvio.
- Gli episodi scaricati stanno in `<appSupportDir>/podcasts/<id>/`, fuori da `folders`: la scansione non li vede.
- Il gestore audio non scrive sui podcast: chiama `onEpisodeHeard`, che `main.dart` collega a `PodcastRepository.markPlayedByTrack`.

- **Tag dei download che sopravvivono a un riavvio**: `DownloadTagger.markPending` registra il file in `pending-tags.json` (`PendingTags`) appena il brano è pronto; il file esce dall'elenco quando la scrittura finisce (riuscita o rifiutata, così un errore non si ripete a ogni avvio). All'avvio `resumePending` (da `ImportEventListener`) rimette in coda i file ancora elencati; i download vecchi, mai elencati, non vengono toccati.

### Aggiornamento dall'app (fase 132, D-640..D-646, D-656)

«Aggiorna» (Impostazioni › Aggiornamenti e azione dello snackbar all'avvio, che apre lo stesso dialog) sostituisce il link da copiare. Dalla fase 137 (D-682) anche un tocco sul testo dello snackbar apre il dialog; il controllo all'avvio segna il giorno (`lastUpdateCheckDay`) solo se è riuscito (`newer` o `upToDate`), così un controllo fallito si ripete al prossimo avvio.

- **File giusto**: `detectUpdateTarget` dà `UpdateTarget(kind, abi)` (Android full/lite + ABI dal canale `codecore/update`; Windows; macOS; su Linux AppImage, Flatpak, `.deb` o zip). `pickUpdateAsset` sceglie l'asset per nome (i nomi di `release.yml`); `selfInstalls` dice se l'app si installa da sola (Android, Windows, AppImage) o se si apre il browser (`.deb`, Flatpak, zip, macOS, via `LinkOpener`).
- **Download**: `UpdateInstaller` con `dio` in `<cache>/updates/`, avanzamento a flusso, annullabile; SHA-256 (`crypto`, in un isolate) confrontato con il `digest` di GitHub, normalizzato (`sha256:` e maiuscole). File diverso: cancellato ed errore. Asset senza `digest`: non si installa, si apre il browser.
- **Rete a consumo** (`networkProbeProvider`): prima del download una conferma con la dimensione (D-656).
- **Android** (`AndroidUpdate`): prima `sameSigner` (firma dell'APK uguale a quella installata, altrimenti «Firma diversa» e nessun installer), poi `canInstall`; senza permesso si aprono le impostazioni (`openInstallSettings`, restituisce bool, non lancia) e al ritorno nell'app si riprova. Poi `install` con `FileProvider` + `ACTION_VIEW`.
- **Windows** (`DesktopUpdate.install`): setup in modalità silenziosa (`/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS`) staccato, poi l'app esce; la riga `[Run]` del `.iss` la riapre.
- **AppImage**: la nuova si copia accanto a `$APPIMAGE` (`.new`), `chmod 755`, rinomina sopra la vecchia, avvio staccato e uscita; cartella non scrivibile o errore → browser. Si riconosce solo se `$APPIMAGE` è impostata e l'eseguibile sta sotto `APPDIR` o in `/tmp/.mount_`.
- **Pulizia**: `updatesCleanupProvider` svuota `<cache>/updates/` all'avvio (dopo `startupSettledProvider`) solo se nessun aggiornamento è in corso.

### Segnalazioni anonime (D-669, D-691, D-701)

Servizi esterni nostri, eccezione a «nessun backend»: la pagina statica di condivisione su GitHub Pages (`docs/site/`, pubblicata da `pages.yml`, solo lettura del frammento nel browser) e il Worker in `tools/report-worker/` crea la issue GitHub (token solo nel Worker). L'app lo chiama con `IssueSender` (`lib/services/issue/issue_sender.dart`, POST JSON titolo, corpo, versione) all'indirizzo `kReportEndpoint` (`lib/core/constants.dart`, `https://freekmusic-report.itzemany.workers.dev/` dal 24/11; vuoto vorrebbe dire Worker assente, e allora la schermata offre solo «Copia testo» e la pagina GitHub). `buildIssue(fits: fitsReportService)` accorcia il log per stare nei limiti del Worker (titolo 120, corpo 20000, JSON 30000 byte). `send` torna un `IssueSendResult`: `sent` (201; senza URL valido il link generico delle issue, mai un secondo invio che farebbe un doppione), `rateLimited` (429), `rejected` (altro) e `unsure` (nessuna risposta o 504, il Worker non ha avuto risposta da GitHub: la issue potrebbe esistere, il messaggio dice di controllare su GitHub); in ogni caso resta «Copia testo». Il corpo inizia con «Tipo: Bug/Idea» e il link di risposta vale solo se è una issue del repository. Il titolo oltre 120 si taglia con «…» prima di tutto. La redazione (`redactLog`) copre anche access_token, sig, key, Authorization e i percorsi Android (anche /sdcard, /storage/<volume>, /data/data), i token nudi (`ghp_…`, `Bearer …`) e gli utenti sotto /media e /run/media. Il tetto giornaliero del Worker si conta solo sulle richieste valide, subito prima della chiamata a GitHub. Il servizio intermedio vede l'IP, GitHub no.

## Invarianti da non rompere

- Ogni chiamata YTM passa da `budgetedYtm`; un 429 deve far scattare il `SourceCooldown`.
- Timeout e User-Agent propri su ogni richiesta; contatto in `kApiContact` (D-298).
- Niente richieste web non richieste dall'utente o dall'arricchimento opt-in. Niente telemetria. L'invio di una segnalazione parte solo dal tasto «Invia», mai da solo.
- `enrich_writer` è l'unico scrittore di `tracks.enrich_status`.
- Le correzioni ai brani passano da `TrackEditor` e finiscono nel Registro.
- Spotify: una sola GET, nessun ritentativo (D-521).
- `artistKey` non cambia senza migrazione.
- Gli id negativi non finiscono nella coda salvata.
- Nel flavor lite le funzioni YouTube restano spente (`kEnableYoutube`).
- Il video karaoke sta solo in streaming e in `StreamCache` tramite `KaraokeVideoCache` (i download dei brani sono solo audio, D-636) e il flusso video non contiene mai audio. Nessun codice scrive in `StreamCache` file con prefisso `karaoke_` fuori da `SeparationService`.
- Un aggiornamento si installa solo con il `digest` verificato, e su Android solo con firma uguale (controllata prima del permesso). Niente installazione senza l'azione dell'utente.

## Come si estende

- **Nuovo servizio di link** (es. un'altra piattaforma): valore in `ExternalService`, riconoscimento in `parseExternalLink`, un `ExternalReader`, e il ramo in `onlineCollectionProvider`. L'abbinamento resta in `CollectionMatcher`.
- **Nuova fonte di metadati**: client dedicato (timeout, User-Agent, `WindowLimiter` o cooldown suoi), poi uso da `enrich_gather` / `metadata_resolver`.
- **Nuovo passo del riconoscimento**: in `TrackRecognizer`, con soglia esplicita e versione `kRecogVersion` aggiornata se cambia l'esito.
- **Nuovo limite**: costante in `request_budget.dart` e finestra condivisa; non creare timer a parte.
- **Nuova fonte di testi**: anello in `LyricsChain`, in ordine di priorità.
- **Nuova stringa di notifica o avviso**: ARB in 6 lingue.
- **Riscrivere un file scaricato**: chi lo fa chiama `DownloadIndex.refreshSignature` (altrimenti «Libera spazio» non lo offre più).
- **Nuovo `MediaSource`**: in `YtResult`/`downloadIndexKey`, con la chiave in `downloads.json`.

## Trappole
- **Il frammento del link di condivisione non arriva mai al server** (D-702): `https://itzemany.github.io/FreeKmusic/#<frammento>` lo legge solo la pagina nel browser (il `#` non viene inviato). Formato fisso, in `lib/services/share/share_fragment.dart` e nella pagina (`docs/site/fragment.js`), stesse regole in entrambi: `FK1\n<tipo t|a|p>\n<titolo>\n<id YouTube da 11 caratteri concatenati>`, oppure (D-713, quando c'è almeno una riga senza id) `FK2\n<tipo>\n<titolo>\n<riga>\n<riga>…` dove ogni riga è un id da 11 caratteri o `~<artista>\t<titolo>` (artista al massimo 60 caratteri e può essere vuoto, titolo non vuoto al massimo 80; l'encoder accorcia e toglie tab e a capo; righe vuote o fuori misura rifiutate); l'encoder scrive FK1 se tutte le righe sono id (i link restano leggibili dalle versioni vecchie), il decodificatore legge entrambe; gzip, base64url (solo `A-Za-z0-9_-`, padding opzionale ma canonico, ultimo carattere con i bit finali a zero, un `#` iniziale è tolto, niente trim né alfabeto standard); titolo non vuoto (né di soli spazi) e al massimo 120 caratteri, l'encoder Dart scrive «Senza titolo» se è vuoto; id controllati sull'intera stringa; max 64 KB decompressi, max `kMaxSharedTracks` = 50 brani (oltre: m3u8); il gzip deve essere intero: CRC32 e ISIZE finali coincidono con il testo (Dart li controlla a mano perché `dart:io` no; JS controlla ISIZE, il CRC lo verifica già `DecompressionStream`), quindi flusso troncato, byte in coda, zlib senza header gzip e più membri gzip sono rifiutati da entrambi; «solo spazi» include U+0085; ogni input cattivo è un `ShareFragmentError` (JS: `FragmentError`). "Apri in FreeKmusic" sulla pagina è un `intent://` solo su Android (fallback alla release), altrove è nascosto. I vettori condivisi con la pagina JS sono in `test/services/share/fragment_vectors.json`.
- **Condividi (145.4/145.5, D-677, D-702)**: `lib/services/share/external_share_text.dart` (puro) costruisce il testo di un brano, album o playlist (titolo, elenco breve di 10 righe, link YouTube Music `watch?v=<id>` o `browse/<albumBrowseId>`, link alla pagina col frammento); ogni brano è una riga del frammento: il suo id (colonna `tracks.video_id` tenuta al download, oppure l'indirizzo della riga in streaming) o, senza id, «artista + titolo» (`shareRowOf`); la pagina mostra una ricerca `music.youtube.com/search?q=` per le righe senza id e l'app le cerca col `CollectionMatcher` come l'import delle playlist, quelle non trovate restano «non trovato». Il link di un brano senza id ha solo la riga della pagina (nessun `watch?v=`). `ExternalShareActions` (`lib/providers/external_share_actions.dart`) sceglie: fino a `kMaxSharedTracks` (50) brani (contano tutti, anche i locali) e con il link non oltre 2000 caratteri il testo passa da `ExternalShare.shareText`; oltre uno dei due limiti (`exceedsShareLimit`), `share_m3u8.dart` scrive in `<temp>/freekmusic_share/` (cartella solo nostra) un m3u8 con le sole righe in streaming (la cartella si svuota prima di ogni nuova condivisione, il sistema pulisce la cache) e lo passa a `shareFile`. Il `Rect` dell'icona o della riga è l'ancora del foglio su iPad/desktop; un errore è registrato con `AppLog.w` e il testo (su Linux/Windows, oltre il limite, l'm3u8 come testo) va negli appunti: `share()` restituisce true e `shareTracks` (`lib/ui/widgets/share_collection.dart`) mostra «Testo copiato negli appunti». Una condivisione alla volta (`_busy`). Un id non da 11 caratteri validi vale come assente (riga di ricerca). `shareLinkFitsQr(link)`: il QR della scheda (D-712) solo se il link è lungo al massimo 666 caratteri (QR versione 20, livello M: leggibile da un telefono sulla scheda 1080 px), altrimenti scheda senza QR. «Condividi» c'è anche per una voce online non ancora salvata (link dal suo id).
- **La segnalazione si costruisce solo ai tasti**: `buildIssue` non gira a ogni lettera e nulla chiama `IssueSender` fuori da «Invia»; l'unica chiamata di rete della segnalazione è quella.
- **Il menu ⋮ non cattura il `Track`** (fase 139): `showTrackActions` ascolta lo stato e l'indice e ricarica la riga viva, ma per un brano online (id negativo) resta il menu online anche a download finito: con la riga locale «Elimina dal dispositivo» cancellerebbe il file che suona lasciandolo in coda.
- **`downloadIndexProvider` è mutato sul posto**: chi aggiunge o toglie file deve fare `ref.invalidate(downloadIndexProvider)`, altrimenti lo stato del brano resta vecchio.

- **`EnrichmentService` serve solo all'anteprima** (`propose` in sola lettura, `apply` dal suo «Accetta»): ogni altra scrittura passa da `EnrichEngine` (D-683).
- **Cache di MusicBrainz e «Aggiorna»**: un giro forzato deve stare dentro `MusicBrainzClient.fresh`, altrimenti riceve le risposte in cache.
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
- Classifica Deezer: niente parametro paese, segue l'IP di chi chiama; la chiave di cache ha il paese solo per Apple e per «Italiana». I nomi dei generi Apple sono tradotti per paese: filtrare per `genreId`.
- Non «correggere» un bug senza cercarlo in `decisioni.md` (es. D-155).
- **Formato yt-dlp del video: `bv[...]`, mai `bv*`** (`bv*` accetta anche formati con audio).
- **LRCLIB `/get` con la durata scarta i karaoke** (il video dura più della canzone): per i karaoke solo `/search` e titolo identico.
- **La scadenza della cache lavora per prefisso dello stem**: la chiave del video (`video:karaoke:...`) non comincia con `karaoke:` (quello della separazione) apposta, così le due scadenze non si toccano.
- **Aggiornamento, firma su Android 9–10**: `getPackageArchiveInfo` legge i certificati di un APK non installato solo con `GET_SIGNATURES`, anche se si chiede `GET_SIGNING_CERTIFICATES`; il canale usa entrambi i flag.
- **Aggiornamento, `$APPIMAGE` ereditato**: un'app lanciata da un'altra AppImage eredita la sua `$APPIMAGE`; per questo si sostituisce il file solo se l'eseguibile è sotto `APPDIR` o `/tmp/.mount_`.
- **Aggiornamento, SnackBar con azione**: senza `persist: false` non scade mai (Flutter 3.47); l'avviso all'avvio lo imposta.
- **Aggiornamento, `late final` di `AppLifecycleListener`**: non lo crea finché nessuno lo legge; va creato esplicitamente (il ritorno dalle impostazioni del permesso dipende da lui).

## Decisioni chiave

Link a `../decisioni.md`:

- D-631..D-639, D-646, D-649, D-651, D-661: filtro, riconoscimento, indirizzo e cache del video karaoke.
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

- **«Scarica anche» dell'import (D-665) sopravvive al riavvio**: `PlaylistImportService` tiene la scelta nelle preferenze, chiave `importDownloadToo.<id>`, tolta solo quando l'import viene annullato o la playlist (e con lei l'import) viene cancellata, non a fine import (il «scarica anche» in coda deve sopravvivere a un riavvio); la chiave non entra nel backup (nessuna colonna in `playlist_imports`). Una riga d'export con `stream:<chiave>` non trovata in libreria si salva direttamente, senza ricerca né rete.
- **Brani mancanti dell'album (D-706)**: `albumMissingTracksProvider` legge una volta (niente watch sulla libreria) e restituisce `YtmAlbumTrack`; in streaming la sezione si carica da sola, in modalità dispositivo una riga «Altri brani dell'album» li cerca al tocco, nella `lite` non c'è nulla.

## Catalogo dei modelli (D-673)

`lib/providers/model_catalog_providers.dart`: `modelCatalogProvider` (`AsyncNotifier` autoDispose) elenca come `ModelEntry` (`kind` traduzione/dizionario/karaoke, `id`, `name`, `estimatedBytes`, `installed`, `diskBytes`, `bytes`) le 20 lingue ML Kit (solo Android, `lyricsTranslatorProvider`), il dizionario CC-CEDICT e il modello karaoke Spleeter (solo Android, `separationServiceProvider`). `download(entry)` e `delete(entry)` riusano i metodi esistenti (`downloadModel`, `TranslationModelsNotifier.delete`, `ChineseDictionaryNotifier.downloadOnly/delete` (scarica il file senza caricarlo in memoria; `delete` lancia se il file resta), `SeparationService.downloadModels/deleteModels`) e rileggono l'elenco; durante l'operazione il notifier resta vivo anche se la pagina si chiude. Il catalogo osserva `translationModelsProvider`, il percorso e lo stato del dizionario, quindi un modello scaricato dal testo del brano compare da solo. In `SeparationService` download, delete e `ensureModels` passano da un'unica coda (`_exclusive`): un secondo `downloadModels` condivide il primo, `deleteModels` annulla il download e ferma la separazione in corso, e un errore di cancellazione è loggato e rilanciato. Dopo «Elimina» dei modelli karaoke (D-707) un file segnaposto `models/<cartella>.removed` (sopravvive al riavvio) fa sì che né il brano in ascolto né il prefetch della coda riscarichino i modelli da soli (`modelsRemovedByUser`); lo toglie solo un avvio esplicito (karaoke acceso dal foglio, «Avvia», «Riprova», `request(explicit: true)`) o «Scarica» della pagina (`allowModels`). Il catalogo ascolta anche il `SeparationService` (ignora i tick mentre c'è un lavoro), così segue modelli scaricati o cancellati altrove. `ModelQueueNotifier` (`modelQueueProvider`, non autoDispose) ha la coda di «Scarica selezionati» (`downloadAll`, una voce alla volta, tiene vivo il catalogo; `cancelQueued` toglie le voci non partite) e dice quale voce è in corso e quali in coda. `ChineseDictionaryNotifier.downloadOnly` è condiviso (`_onlyRun`) e `_run` lo aspetta, così non scrivono insieme lo stesso `.tmp`. `TranslationModelsNotifier.delete` rilancia l'errore dopo aver riletto l'elenco. La stima del karaoke viene da `kKaraokeModelMegabytes` (anche per il testo della scheda karaoke). `installedModelsBytes` somma le voci installate: dimensione su disco dove nota (dizionario, karaoke), altrimenti la stima (`kTranslationModelBytes` 30 MB, `kDictionaryEstimateBytes` 4 MB, `kKaraokeEstimateBytes` 78 MB).
