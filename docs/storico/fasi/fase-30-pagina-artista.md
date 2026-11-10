# Fase 30 — Pagina artista nella ricerca online

**Obiettivo:** cercando un artista online compare in cima ai risultati una **card con la sua foto**; toccandola si
apre una **pagina dell'artista** «come su Spotify»: i tuoi brani di quell'artista, i brani più ascoltati, album,
singoli ed EP, video, artisti simili e la biografia. Ogni brano ha «Ascolta» (streaming della fase 28.6) e
«Scarica»; ogni album apre una **pagina album** con «Scarica album».
**Prerequisiti:** fase 28.4 (client InnerTube con ripiego su yt-dlp, maschera dei campi), 28.5 (miniature
piccole, `NetThumbnail`), 28.6 («Ascolta», `listenProvider`, `ListenBar`), 15.12 (album:
`albumTracks`/`parseYtAlbumPage`, `PlaylistImportService.startFromResults`), 22.6 (playlist da risultati).
**Principio:** una richiesta diretta per pagina (≈ 0,4–0,5 s), letta in modo **strutturale** (tipo degli elementi,
non i titoli delle sezioni), con cache; la rete parte solo da un tocco dell'utente. Nessun pacchetto nuovo.
Tutto nascosto nella variante `lite` (`kEnableYoutube = false`).

> ⚠️ Come per la fase 5 parte B e la 22: ascoltare e scaricare da YouTube può violare i suoi Termini. Uso
> strettamente personale; l'avviso già mostrato una volta (`ytNoticeSeen`) vale anche qui.

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)
Richieste a `https://music.youtube.com/youtubei/v1/<endpoint>?prettyPrint=false` con lo stesso contesto dell'app
(`clientName WEB_REMIX`, `clientVersion 1.20250101.01.00`, `hl en`, `User-Agent` di `apiUserAgent`, nessuna regione).
Risposte grezze salvate fuori dal repository (cartella temporanea della sessione di pianificazione).

| Richiesta | Tempo | Peso gzip (testo) | Cosa c'è |
|---|---|---|---|
| `search` «pink floyd», **senza filtro** | 0,61 s | 18 KB (242 KB) | `musicCardShelfRenderer` = risultato principale: titolo «PINK FLOYD» con `browseEndpoint.browseId` `UCO6LS_5W7vqG9mALDNzSFug` e `pageType MUSIC_PAGE_TYPE_ARTIST` (anche in `onTap`), sottotitolo «Artist • 25.9M monthly audience», foto tonda 60/120 px (`lh3.googleusercontent.com/…=w120-h120-p-l90-rj`). Il resto è una lista mista di `itemSectionRenderer` (brani, album, artisti, video, playlist, episodi), **non** più a scaffali |
| idem con maschera `…musicCardShelfRenderer(title,subtitle,thumbnail,onTap)` | 0,51 s | **0,7 KB** | solo la card |
| `search` «mother», stessa maschera | 0,51 s | 0,8 KB | la card è un **brano** (`onTap.watchEndpoint`): nessuna card artista. Così si comporta Spotify |
| `search` filtro **artisti** `EgWKAQIgAWoKEAMQBBAJEAoQBQ%3D%3D` | 0,45 s | 7 KB (2,4 KB con maschera) | `musicShelfRenderer` di artisti (`navigationEndpoint.browseEndpoint`, «25.9M monthly audience» o «114 subscribers»); omonimi e cover band in coda |
| `search` filtro **brani** (quello di oggi) | 0,50 s | 14 KB | ogni artista e album ha già il suo `browseId` (`UC…`, `MPREb_…`): `parseSongSearch` oggi li **scarta**. La fixture `ytm_songs.json` li contiene già |
| `browse` `UCO6LS_5W7vqG9mALDNzSFug` (artista) | 0,48 s | 42 KB (630 KB) · **14 KB con maschera** | `header.musicImmersiveHeaderRenderer`: `title`, `description`, `thumbnail` (solo larghe: 540×225 … 2880×1200), `monthlyListenerCount`, `startRadioButton.watchEndpoint` (`RDEM…`, `params wAEB`). `contents.singleColumnBrowseResultsRenderer.tabs[0]…sectionListRenderer.contents`: `musicShelfRenderer` «Top songs» (5 brani **senza durata**, con album; «mostra tutto» nel `title.runs[0].navigationEndpoint` = `VLOLAK5uy_…` + `params ggMCCAI%3D`), poi `musicCarouselShelfRenderer` «Albums» (10 `musicTwoRowItemRenderer` con `MPREb_…`, anno, copertine 226/544; «more» = `MPADUC…` + `params`), «Singles & EPs», «Videos» (`watchEndpoint`, miniature 400/800), «Latest episodes» (`musicMultiRowListItemRenderer`), «Podcasts», «Live performances», «Featured on», «Playlists by…» (playlist `VL…`), «Fans might also like» (10 artisti `UC…`), infine `musicDescriptionShelfRenderer` |
| `browse` artista con `hl: it` (Vasco Rossi `UCmUrlA_x25EXhvlsRHmC3bw`) | 0,48 s | 33 KB | **titoli già tradotti da YouTube** («Brani più ascoltati», «Album», «Singoli ed EP», «Video», «Ai fan potrebbe anche piacere»), biografia e «2,85 Mln ascoltatori mensili» in italiano: i titoli non servono a riconoscere le sezioni |
| artista con poche uscite (Gibran Alcocer) | 0,39 s | 19 KB | **niente «Albums»**: solo «Singles & EPs», «Videos», «Featured on», «Fans might also like» |
| `browse` con id inesistente | 0,26 s | 0,5 KB | **HTTP 200** senza `contents` né `header` (solo `microformat.noindex`): è «non trovato», non «formato cambiato» |
| `browse` `MPREb_tc3z4MYeOpY` (album «The Wall») | 0,42 s | 24 KB · **3 KB con maschera** | `contents.twoColumnBrowseResultsRenderer`: `tabs[0]…musicResponsiveHeaderRenderer` (titolo, «Album • 1979», artista con `browseId` in `straplineTextOne`, «26 songs • 1 hour, 21 minutes», copertina 60/120/226/544) e `secondaryContents…musicShelfRenderer`: 26 `musicResponsiveListItemRenderer` con `playlistItemData.videoId`, numero (`index`), durata (`fixedColumns`); la colonna artista è vuota (vale quello dell'album). La stessa pagina via yt-dlp (`albumTracks`, flat): **4,5 s** |
| `browse` «Top songs» `VLOLAK5uy_…` | 0,44 s | 71 KB | 100 brani **con** durata (`fixedColumns`), poi una continuazione |
| `browse` discografia `MPADUC…` | 0,38 s | 20 KB | 38 uscite (`musicTwoRowItemRenderer`) |

Maschere provate (stessa sintassi di `X-Goog-FieldMask` della fase 28):
- card: `contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents.musicCardShelfRenderer(title,subtitle,thumbnail,onTap)`
- artisti: `contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents.musicShelfRenderer.contents.musicResponsiveListItemRenderer(flexColumns,thumbnail,navigationEndpoint)`
- pagina artista: `header.musicImmersiveHeaderRenderer(title,thumbnail,description,startRadioButton,monthlyListenerCount),contents.singleColumnBrowseResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents(musicShelfRenderer(title,contents.musicResponsiveListItemRenderer(flexColumns,fixedColumns,playlistItemData,thumbnail),bottomEndpoint),musicCarouselShelfRenderer(header.musicCarouselShelfBasicHeaderRenderer(title,moreContentButton),contents.musicTwoRowItemRenderer(title,subtitle,navigationEndpoint,thumbnailRenderer)),musicDescriptionShelfRenderer(header,description))`
- pagina album: `contents.twoColumnBrowseResultsRenderer(tabs.tabRenderer.content.sectionListRenderer.contents.musicResponsiveHeaderRenderer(title,subtitle,straplineTextOne,secondSubtitle,thumbnail),secondaryContents.sectionListRenderer.contents.musicShelfRenderer.contents.musicResponsiveListItemRenderer(flexColumns,fixedColumns,playlistItemData,index))`

## Decisioni
| Tema | Scelta |
|---|---|
| Card artista | Una seconda richiesta **in parallelo** alla ricerca online (fonti YouTube e YouTube Music, non SoundCloud): `search` **senza filtro** con la maschera della card. Si mostra solo se la card di YouTube Music è un **artista** (`pageType` dell'`onTap`); se è un brano o la richiesta fallisce, niente card (riga nel log, nessun errore a schermo). Non ritarda i risultati: compare quando arriva |
| Nomi degli artisti | `YtResult` guadagna `artistIds` (allineati ad `artists`, `''` dove non c'è pagina) e `albumId`: nelle righe YouTube Music il nome dell'artista diventa toccabile e apre la sua pagina |
| Lettura delle pagine | **Strutturale**: scaffale di brani (`musicShelfRenderer` con `watch`) = brani più ascoltati; carosello di elementi `MUSIC_PAGE_TYPE_ALBUM` = uscite (album, singoli, EP: tutti con il titolo dato da YouTube); carosello di `watchEndpoint` = video (solo il **primo**); carosello di `MUSIC_PAGE_TYPE_ARTIST` = artisti simili; `musicDescriptionShelfRenderer` = informazioni. Episodi, podcast, playlist e «Featured on» si ignorano. Sezione mancante = sezione nascosta |
| Lingua | La pagina artista e la card si chiedono con `hl` = lingua dell'app (it/en/de/es/fr/pt): titoli delle sezioni, biografia e «ascoltatori mensili» arrivano già tradotti da YouTube. La ricerca di oggi resta `hl: en` |
| Pagina album | `browse` diretto con maschera (0,4 s); se non si legge (`InnerTubeChanged`) → `albumTracks` di yt-dlp (4,5 s) con lo stesso risultato. Anche `DirectSearchService.albumTracks` (usato dall'importazione 15.12) passa prima dal diretto per i link `https://music.youtube.com/browse/MPREb_…` |
| Cache | `CatalogCache`: in memoria (ultime 30 pagine) e su disco (`<appSupport>/catalog_cache.json`, ≤ 60 voci, meno usate fuori). Scadenza: artista 2 giorni, album e discografia 14 giorni, «tutti i brani» 2 giorni; chiave = id + lingua. **Fuori linea** (o errore di rete) si mostra l'ultima copia anche scaduta con l'avviso «Non in linea · dati del <data>»; «Aggiorna» (trascinamento verso il basso) la richiede di nuovo. Voce «Catalogo online» in Memoria (fase 29.2) con «Svuota» |
| «Non trovato» vs «cambiato» | Risposta 200 senza `contents`/`header` → «Artista non trovato»; contenitore sconosciuto → `InnerTubeChanged`: messaggio «La pagina dell'artista non si legge (YouTube ha cambiato qualcosa)» con «Cerca i brani di <artista>» (la ricerca normale, che ha il suo ripiego). Per la pagina artista **non esiste** un equivalente yt-dlp (R74) |
| Miniature (regole 28.5) | Le immagini `lh3`/`yt3.googleusercontent.com` accettano la misura nell'indirizzo (`=w120-h120…`): `googleThumbAt(url, px)` la riscrive alla misura mostrata × densità, arrotondata a 120 · 226 · 320 · 544 (così la cache delle immagini riusa). Foto dell'artista tonda dalla card/ricerca (quadrata), mai il banner largo (≥ 540×225, 100+ KB); video con `mqdefault` come oggi |
| Pagina artista | In ordine: intestazione (foto tonda, nome, ascoltatori mensili), **Nella tua libreria** (i tuoi brani di quell'artista, al più 5, «Vedi tutti» → `ArtistDetailScreen` locale; nascosta se non ne hai), **Brani più ascoltati** (5 + «Mostra tutti» → 100 brani), un carosello per ogni gruppo di **uscite** (titolo di YouTube, «Mostra tutto» → discografia), **Video** (primo carosello), **Artisti simili**, **Informazioni** (biografia ripiegabile). Ogni brano: «Ascolta», «Scarica», segno «Già in libreria» |
| «Già in libreria» | Come oggi `DownloadIndex.contains(videoId)`, **più** confronto con i brani locali dello stesso artista (titolo `matchTitleKey` uguale, durata entro 5 s se nota): copre i brani arrivati da file o da un altro video |
| Artista locale ↔ YouTube Music | Stesso artista se `matchKey(extractPrimaryArtist(nome))` coincide («PINK FLOYD» = «Pink Floyd», diacritici e maiuscole non contano). Dalla libreria («Su YouTube Music») si cerca con il filtro artisti: un solo risultato con nome uguale → si apre; più di uno o nessuno → foglio di scelta con i primi 3 (foto, nome, ascoltatori) |
| «Ascolta» | Il lettore della 28.6, condiviso fra le pagine online: l'ascolto **non** finisce aprendo la pagina artista dai risultati, finisce quando si chiude l'**ultima** pagina online (contatore `attach`/`detach` in `ListenNotifier`) |
| «Scarica» / selezione | «Scarica» di un brano = `downloadsProvider.add` come nei risultati; selezione multipla nelle liste di brani (chiave `ytm-artist:<id>`, `ytm-album:<id>`) con «Scarica» nella barra, nell'ordine dei tocchi (fase 27) |
| «Scarica album» | Riusa l'importazione: `PlaylistImportService.startFromResults('<Album> — <Artista>', brani, ImportOptions(folderPath: '<Artista> - <Album>', fetchCovers: true))`: ripresa, pausa, notifica in background (Android), dettaglio per riga, brani già in libreria **collegati** e non riscaricati, tag album/artista dalle righe e numero del brano (30.9). Conferma prima con numero di brani, durata e peso stimato (≈ 1 MB/min in M4A). Crea anche una **playlist** con il nome dell'album (oggi un'importazione ne richiede una: `playlist_imports.playlist_id` non è nullo) — vedi domande aperte |
| Navigazione | Pagine aperte con `ShellNav.open` nella scheda corrente (Cerca o Libreria); niente modifiche a `lib/ui/shell/*` |
| Pacchetti nuovi | Nessuno |

## Task

### 30.1 — Verifiche preliminari e fixture
Gli esiti dal PC sono nella tabella «Misure dal vivo». Restano:
1. Ripetere le richieste con lo script di prova (fuori da `lib/`, non committato) e salvare le **fixture ridotte**
   (senza `trackingParams`/`clickTrackingParams`/`loggingContext`/`accessibility`, caroselli a ≤ 4 elementi,
   tranne dove il test li conta):
   `test/fixtures/innertube/ytm_top_artist_card.json` («pink floyd», maschera card) ·
   `ytm_top_song_card.json` («mother», card = brano) · `ytm_artists.json` (filtro artisti, 5 voci) ·
   `ytm_artist_page.json` (Pink Floyd, `hl en`, maschera) · `ytm_artist_page_it.json` (Vasco Rossi, `hl it`) ·
   `ytm_artist_page_sparse.json` (Gibran Alcocer: niente album) · `ytm_artist_missing.json` (id inesistente) ·
   `ytm_album_page.json` («The Wall», 26 brani) · `ytm_artist_songs.json` («Top songs» `VLOLAK5uy_…`, 10 brani) ·
   `ytm_discography.json` (`MPADUC…`, 6 uscite).
2. Un artista italiano con diacritici (Fabrizio De André) e uno con nome comune (es. «Nirvana»): annotare se la card è
   l'artista giusto e cosa elenca il filtro artisti.
3. Provare `hl` de/es/fr/pt su una pagina artista: annotare che la struttura non cambia.
4. Verificare che il pulsante «more» degli album (`moreContentButton`) e il link «Top songs» abbiano sempre
   `browseId` + `params` (servono a 30.10); annotare i casi senza.
**Verifica:** fixture nel repository, note in PROGRESS (tempi, casi strani). **Stop** se la card o il `browse`
dell'artista non rispondono più come in tabella: riportare prima di scrivere codice.

### 30.2 — Aiuti JSON condivisi e risultati YouTube Music con id di artista e album
**File:** `lib/services/online/innertube_json.dart` (nuovo), `innertube_client.dart`, `youtube_service.dart`,
`search_cache.dart`, `test/services/online/innertube_client_test.dart`, `search_cache_test.dart`
1. Spostare in `innertube_json.dart`, pubblici e invariati, `_collect` → `collectRenderers`, `_text` → `runsText`,
   `_pageType` → `pageTypeOf` (+ `browseIdOf(run)`), `parseClock`: servono ai nuovi parser (oggi
   `innertube_client.dart` è già a 313 righe). Nessun cambio di comportamento.
2. `YtResult`: `artistIds` (`List<String>`, stessa lunghezza di `artists`, `''` se l'artista non ha pagina) e
   `albumId` (`String?`). `parseSongSearch` li riempie dai `browseId` dei run `ARTIST`/`ALBUM`.
3. `SearchCache`: chiavi `aids` e `alb` nel JSON (assenti nelle voci vecchie → vuoti).
**Verifica:** test su `ytm_songs.json`: «Mother» ha `artistIds == ['UCO6LS_5W7vqG9mALDNzSFug']` e
`albumId == 'MPREb_tc3z4MYeOpY'`; la cache rilegge i due campi e una voce vecchia senza. I test esistenti restano verdi.

### 30.3 — Parser della card, della ricerca artisti e della pagina artista (logica pura)
**File:** `lib/services/online/ytm_artist.dart` (modelli), `lib/services/online/ytm_artist_parser.dart`,
`lib/services/online/google_thumb.dart`, `test/services/online/ytm_artist_parser_test.dart`,
`test/services/online/google_thumb_test.dart`
1. Modelli immutabili: `YtmArtistRef {id, name, thumbnailUrl, audience}` · `YtmRelease {browseId, title, subtitle,
   thumbnailUrl}` · `YtmShelf` sigillato: `YtmSongShelf {title, songs: List<YtResult>, allSongs: YtmBrowseLink?}`,
   `YtmReleaseShelf {title, releases, more: YtmBrowseLink?}`, `YtmVideoShelf {title, videos: List<YtResult>}`,
   `YtmArtistShelf {title, artists}` · `YtmBrowseLink {browseId, params}` · `YtmArtistPage {ref, description,
   shelves, radio: YtmWatchLink?}`. JSON proprio (`toJson`/`fromJson`) per la cache di 30.5.
2. `parseTopArtistCard(Map)` → `YtmArtistRef?` (null se la card non è un artista o manca); `parseArtistSearch(Map)` →
   `List<YtmArtistRef>`; `parseArtistPage(Map, id)` → `YtmArtistPage`, lancia `ArtistNotFound` (risposta senza
   `contents` e `header`) o `InnerTubeChanged` (contenitore sconosciuto). Riconoscimento delle sezioni per **tipo**
   (vedi Decisioni), mai per titolo. Brani dei «Top songs» come `YtResult` con artisti, `artistIds`, album,
   `albumId`, miniatura quadrata; durata null se assente.
3. `googleThumbAt(String url, int px)`: riscrive `=w<N>-h<N>` di `lh3`/`yt3.googleusercontent.com` al gradino
   (120 · 226 · 320 · 544) ≥ `px`; altri indirizzi invariati.
**Verifica:** card artista → ref con id, nome, foto; card brano → null; pagina `en`: 5 brani, ≥ 2 caroselli di uscite,
1 di video, 10 artisti simili, descrizione; pagina `it`: stesse sezioni con titoli italiani; pagina sparsa: nessun
album, i singoli ci sono; id inesistente → `ArtistNotFound`; contenitore rinominato (fixture modificata nel test) →
`InnerTubeChanged`; `googleThumbAt` (gradino, indirizzo non Google invariato).

### 30.4 — Parser della pagina album, di «tutti i brani» e della discografia (logica pura)
**File:** `lib/services/online/ytm_album_parser.dart`, `ytm_artist.dart` (`YtmAlbum`, `YtmAlbumTrack`),
`test/services/online/ytm_album_parser_test.dart`
1. `YtmAlbum {browseId, title, artist: YtmArtistRef?, year, kindLabel ('Album'/'EP'/'Single' come scritto),
   coverUrl, tracks: List<YtmAlbumTrack{number, result}>}`; `parseAlbumPage(Map, browseId)`: artista dell'album
   dalla `straplineTextOne` messo in ogni brano senza artisti propri; `result.album` = titolo, `albumId` = id.
2. `parseSongList(Map)` per le pagine `VL…` (100 brani con durata; la continuazione si ignora in questa fase).
3. `parseDiscography(Map)` → `List<YtmRelease>`.
**Verifica:** «The Wall»: 26 brani in ordine, numeri 1…26, durata del primo 3:19, artista «Pink Floyd» con id, anno
1979; lista «Top songs»: 10 brani con durata; discografia: 6 uscite con id `MPREb_…`; risposta senza
`musicResponsiveHeaderRenderer` → `InnerTubeChanged`.

### 30.5 — Client, servizio del catalogo e cache
**File:** `innertube_client.dart` (`browseMusic`, `searchMusic`), `lib/services/online/ytm_catalog.dart`,
`lib/services/online/catalog_cache.dart`, `direct_search_service.dart`, `lib/providers/ytm_catalog_providers.dart`,
`test/services/online/ytm_catalog_test.dart`, `test/services/online/catalog_cache_test.dart`
1. `InnerTubeClient.browseMusic(browseId, {params, hl, mask, cancel})` e `searchMusic(query, {params, hl, mask})`:
   stessi timeout, errori (429 → `rateLimited`, rete → `network`) e stesso schema «con maschera, poi intero se vuoto
   o illeggibile» di `_masked`.
2. `YtmCatalog(client, ytDlp, cache, {now})`: `topArtist(query, hl)`, `searchArtists(query, hl)`, `artist(id, hl)`,
   `album(browseId, hl)` (ripiego `ytDlp.albumTracks('https://music.youtube.com/browse/<id>')` su
   `InnerTubeChanged`, risultato convertito in `YtmAlbum` senza numeri se mancano), `songs(link, hl)`,
   `discography(link, hl)`. Ogni risposta: `CatalogResult<T> {value, fetchedAt, stale}`.
3. `CatalogCache`: memoria + file JSON (debounce 2 s come `SearchCache`), TTL per tipo, LRU, `clear()`, `sizeBytes()`
   per Memoria. Errore di rete con copia in cache (anche scaduta) → `stale: true`; senza copia → l'errore.
4. `DirectSearchService.albumTracks`: link `music.youtube.com/browse/MPREb_…` → `YtmCatalog.album` diretto
   (risultato come `List<YtResult>` in ordine), altrimenti yt-dlp come oggi.
5. Provider: `ytmCatalogProvider`, `artistPageProvider` e `onlineAlbumProvider` (`FutureProvider.autoDispose.family`,
   `retry: (_, _) => null` come `playlistListingProvider`), lingua da `settingsProvider`.
**Verifica:** (adattatore finto come `innertube_client_test.dart`) maschera vuota → seconda richiesta intera;
`ArtistNotFound` non cade su yt-dlp; album illeggibile → yt-dlp chiamato una volta; seconda apertura dalla cache
senza richieste; rete assente con copia scaduta → `stale`; TTL e LRU della cache; l'importazione album (15.12) usa il
diretto per un link `MPREb_` (test di `DirectSearchService`).

### 30.6 — «Ascolta» condiviso fra le pagine online
**File:** `lib/providers/listen_providers.dart`, `lib/ui/screens/youtube/youtube_results.dart`,
`test/providers/listen_test.dart`
1. `ListenNotifier.attach()` / `detach()`: un contatore delle pagine online aperte; `detach` all'ultimo → `stop()`.
2. `YoutubeResults` usa `attach` in `initState` e `detach` in `dispose` al posto di `stop()` diretto.
**Verifica:** due pagine attaccate, si chiude la prima → l'ascolto continua; si chiude anche la seconda → finisce e la
musica di prima riparte (comportamento 28.6 invariato con una sola pagina).

### 30.7 — Card dell'artista e nomi toccabili nei risultati
**File:** `youtube_results.dart`, `lib/ui/screens/online/artist_card.dart`, `lib/ui/widgets/net_thumbnail.dart`
(variante tonda), ARB, `test/ui/youtube_results_artist_test.dart`
1. A ogni ricerca (fonti YouTube e YouTube Music) `topArtist(q, hl)` parte insieme alla ricerca, con lo stesso
   `_requestId`: una risposta vecchia non mostra la card della ricerca nuova.
2. `ArtistCard`: foto tonda 64 px (`googleThumbAt`, dissolvenza 28.5), nome, «Artista · <ascoltatori>», freccia;
   tocco → `ShellNav.open(ArtistPageScreen(ref))`. Sopra la lista, dentro lo stesso `ListView` (scorre con i
   risultati), con `EnterOnce`.
3. Righe YouTube Music: il nome dell'artista (primo con `artistIds` non vuoto) è un pulsante di testo che apre la sua
   pagina; il tocco sulla riga resta com'è (selezione).
**Verifica:** widget test con servizi finti: card mostrata quando `topArtist` dà un artista, assente quando dà null
o fallisce (i risultati ci sono comunque), risposta vecchia ignorata; tocco sul nome → pagina dell'artista giusto.
**Telefono (Mi A3, Wi‑Fi):** «pink floyd», «vasco rossi», «mother»: card solo nei primi due, nessun ritardo dei risultati.

### 30.8 — Pagina dell'artista
**File:** `lib/ui/screens/online/artist_page_screen.dart`, `artist_page_sections.dart` (sezioni come widget
piccoli), `lib/ui/screens/online/online_song_row.dart` (riga brano con Ascolta/Scarica/«Già in libreria», estratta
da `_ResultRow` di `youtube_results.dart` e riusata lì), `lib/services/online/library_overlap.dart` (puro), ARB,
`test/services/online/library_overlap_test.dart`, `test/ui/artist_page_test.dart`
1. `CustomScrollView` con sliver: intestazione, «Nella tua libreria», brani, un carosello orizzontale per ogni
   gruppo di uscite (`ListView.builder` con `itemExtent`), video, artisti simili (tondi), informazioni (3 righe +
   «Altro»). `ListenBar` in basso; `ActivityButton` nella barra.
2. `library_overlap.dart`: `localArtistFor(name, List<ArtistSummary>)` e `ownedIn(List<Track> artistTracks,
   YtResult r)` (regole in Decisioni). «Nella tua libreria» legge `artistTracksProvider(key)` (righe leggere).
3. Stati: caricamento (scheletro), «Non in linea · dati del <data>» se `stale`, errore con «Riprova» e, per
   `InnerTubeChanged`, «Cerca i brani di <artista>» (torna a Cerca con la query), «Artista non trovato».
   Trascinamento verso il basso = richiesta nuova.
4. Selezione multipla nei brani (`SelectionScope` con chiave `ytm-artist:<id>`), «Scarica» nella barra.
**Verifica:** `localArtistFor` (maiuscole, diacritici, «feat.»), `ownedIn` (stesso titolo e durata ±5 s, titolo
diverso, durata assente); widget test con catalogo finto: sezioni nell'ordine, sezione assente nascosta, «Nella tua
libreria» solo con brani locali, avviso con dati vecchi.
**Telefono (Mi A3):** Pink Floyd e un artista con soli singoli: tempo di apertura (obiettivo < 1 s su Wi‑Fi),
scorrimento fluido dei caroselli, «Ascolta» e «Scarica» da un brano, riapertura istantanea dalla cache, modalità aereo
→ copia con l'avviso.

### 30.9 — Pagina album online e «Scarica album»
**File:** `lib/ui/screens/online/online_album_screen.dart`, `lib/services/online/album_download_plan.dart` (puro),
`artist_page_sections.dart` (tocco sulle uscite), `lib/services/import/playlist_import_service.dart`
(`startFromResults(…, sourceKind:)` e numero del brano), ARB, `test/services/online/album_download_plan_test.dart`,
`test/services/import/playlist_import_service_test.dart`
1. Intestazione (copertina 226/544 secondo la misura, titolo, artista toccabile → sua pagina, «Album • 1979»,
   «26 brani • 81 min»), elenco numerato con `OnlineSongRow`, selezione multipla, `ListenBar`.
2. «Scarica album»: `albumDownloadPlan(album, owned)` → nome della playlist, cartella (`sanitizeFileName`), elenco
   in ordine, quanti già in libreria, durata e peso stimato; dialogo di conferma; poi `startFromResults` (vedi
   Decisioni) e snackbar «Importazione «…» avviata» con «Mostra» (dettaglio dell'importazione).
3. Ordine dei brani nella Libreria: le righe d'importazione non hanno il numero del brano (niente colonna, e
   aggiungerla cambierebbe lo schema); `startFromResults` riceve `sourceKind: 'ytm-album'` e, solo per quel tipo,
   quando applica i tag della riga mette `TrackEdit.trackNumber = rowIndex + 1` (la riga è nell'ordine dell'album).
**Verifica:** `albumDownloadPlan`: ordine dell'album, nome e cartella senza caratteri vietati, conteggio dei brani già
presenti, stima del peso; importazione `ytm-album` con download finto → numero del brano = posizione, un'importazione
`youtube` normale non lo tocca.
**Telefono (Motorola, LTE):** «Scarica album» di un album da 10+ brani con app in background: notifica di avanzamento,
cartella «Artista - Album», album unico in Libreria → Album con i numeri dei brani.

### 30.10 — «Tutti i brani» e discografia
**File:** `lib/ui/screens/online/artist_songs_screen.dart`, `lib/ui/screens/online/discography_screen.dart`, ARB
1. «Mostra tutti» (brani) → elenco di 100 brani (`ListView.builder`, `itemExtent` 72) con Ascolta/Scarica/selezione.
2. «Mostra tutto» (uscite) → griglia di copertine (`SliverGrid`, celle ≥ 140 px) → pagina album.
3. Se il link manca (30.1 punto 4) il pulsante non compare.
**Verifica:** `flutter analyze`; widget test minimo solo se c'è logica (il pulsante assente senza link).
**Telefono:** scorrimento dei 100 brani sul Mi A3 senza scatti.

### 30.11 — Ingressi dalla libreria
**File:** `lib/ui/screens/library/artist_screen.dart`, `lib/ui/screens/search/search_screen.dart` (card artista
locale), `lib/ui/widgets/track_actions.dart` («Artista su YouTube Music»), `lib/ui/screens/online/artist_picker_sheet.dart`,
`lib/services/online/ytm_artist_resolver.dart` (puro), ARB, `test/services/online/ytm_artist_resolver_test.dart`
1. `ArtistDetailScreen` locale: pulsante «Su YouTube Music»; la card artista della ricerca **locale** (già esistente)
   ha la stessa azione secondaria; nel menu del brano, sotto «Vai all'artista», «Artista su YouTube Music».
2. `pickYtmArtist(localName, List<YtmArtistRef>)` → esatto (uno solo con `matchKey` uguale) / da scegliere / nessuno;
   il foglio di scelta mostra i primi 3. Solo azioni dell'utente: nessuna ricerca in automatico aprendo la pagina locale.
**Verifica:** `pickYtmArtist`: un esatto, due omonimi, nessuno, maiuscole («PINK FLOYD»).
**Telefono:** dalla pagina locale di un artista importato da CSV → pagina YouTube Music giusta; «Nella tua libreria»
mostra gli stessi brani.

### 30.12 — Test dal vivo, documentazione e prova a mano
1. `test/live/ytm_catalog_live_test.dart` (dietro `CODECORE_LIVE=1`, nel giro notturno della CI): card «pink floyd»
   = artista `UCO6LS_5W7vqG9mALDNzSFug`, pagina con ≥ 1 scaffale di brani e ≥ 1 carosello di uscite, album
   «The Wall» con 26 brani, `hl it` con le stesse sezioni.
2. Voce «Catalogo online» in Memoria (`lib/services/memory/app_data.dart`: `AppDataPaths` e `CacheCleaner`, come la cache delle ricerche; fase 29.2, commit `3645d5e`).
3. ARB it/en/de/es/fr/pt; `docs/02-architettura.md` (sezione «Catalogo YouTube Music (fase 30)»),
   `docs/99-rischi-e-fallback.md` (R74–R76), guida utente (card, pagina artista, «Scarica album»).
**Tocca a te (Linux + Mi A3 + Motorola):** card per un artista e non per un brano; pagina di un artista famoso, di uno
italiano e di uno con soli singoli; «Ascolta» che continua passando da risultati ad artista ad album e finisce
uscendo; «Scarica album» completo in background; «Su YouTube Music» dalla libreria; modalità aereo con pagina già
vista.

## Fuori da questa fase
Accesso con account (iscriversi, «Mi piace»), «Featured on» e «Playlist di…» (si potrebbero aprire con
`PlaylistSourceSheet` della 22.6), podcast/episodi/esibizioni dal vivo, continuazione oltre i 100 brani, **radio
dell'artista** (`startRadioButton`: serve la coda con voci online della fase 31), pagine artista SoundCloud,
canali YouTube non musicali, scaricare l'intera discografia, testi dalla pagina online.

## Rischi (proposti per `99-rischi-e-fallback.md`, da copiare in 30.12)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R74 | La pagina artista (InnerTube `browse`, non documentata) cambia formato o risponde vuota; per lei **non c'è** un ripiego yt-dlp | «La pagina dell'artista non si legge» | Lettura per tipo di elemento (non per titoli); maschera con richiesta intera se vuota; copia in cache anche scaduta; «Cerca i brani di <artista>» (ricerca con il suo ripiego); album via yt-dlp; fixture in `test/fixtures/innertube/` e test notturno `ytm_catalog_live_test.dart` |
| R75 | Artista sbagliato: omonimi, cover band, nome del canale diverso da quello dei tag («PINK FLOYD») | «Nella tua libreria» con brani di un altro o vuota; «Su YouTube Music» apre l'artista sbagliato | Dai risultati si usa sempre il `browseId`; confronto con `matchKey` su artista principale; dalla libreria si apre da solo solo con un unico nome uguale, altrimenti scelta fra 3; nessuna scrittura automatica nel DB |
| R76 | «Scarica album» lancia molte richieste (429) o crea doppioni | Importazione in pausa «YouTube chiede una pausa», album diviso | È un'importazione (attese e ripresa della fase 15, una ricerca per riga evitata perché i `videoId` sono noti); i brani già in libreria si collegano; conferma con il numero di brani |

## Domande aperte per l'utente
1. «Scarica album» crea anche una **playlist** con il nome dell'album (come oggi le playlist YouTube incollate):
   va bene? L'alternativa senza playlist richiede di cambiare lo schema (`playlist_imports.playlist_id` nullo).
2. Titoli delle sezioni e biografia nella **lingua dell'app**, tradotti da YouTube (il resto dei testi resta dai nostri ARB): ok?
3. La card artista anche con la fonte **YouTube** (non solo YouTube Music)? Proposta: sì.
4. Sezione **Video** (l'audio dei videoclip, a volte con introduzioni): tenerla in fondo alla pagina? Proposta: sì, solo il primo carosello.

## Definition of Done
- [ ] Card dell'artista nei risultati online solo quando il risultato principale è un artista; nomi degli artisti toccabili
- [ ] Pagina artista con i tuoi brani, brani più ascoltati, uscite, video, simili, informazioni; Ascolta e Scarica su ogni brano
- [ ] Pagina album con «Scarica album» tramite l'importazione; album diretto anche per l'importazione 15.12
- [ ] Cache con copia fuori linea; errori distinti (non trovato, formato cambiato, rete)
- [ ] Test: parser (card, artisti, artista en/it/sparsa/assente, album, liste), catalogo e cache, ascolto condiviso, sovrapposizione con la libreria, scelta dell'artista, piano dell'album
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Risposte dell'utente (2026-10-22: «ok» alle proposte)
- «Scarica album» **non** crea una playlist (l'album compare in Libreria → Album; niente cambio di schema).
- Titoli delle sezioni e biografia nella lingua dell'app, come li dà YouTube.
- La card artista compare anche con la fonte YouTube (richiesta separata a YouTube Music).
- **Niente sezione «Video»** nella pagina artista: solo musica.
