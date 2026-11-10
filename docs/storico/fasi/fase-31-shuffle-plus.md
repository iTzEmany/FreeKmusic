# Fase 31 — «Shuffle+»: brani che non hai, mescolati nella coda

**Obiettivo:** una riproduzione casuale «più»: mentre suona una playlist in casuale, **ogni N brani** (impostazione,
predefinito 1 ogni 4) entra in coda un brano che **non hai**, simile a quella playlist (in «Canzoni rock» un rock
che non hai, in «Blues» un blues…). Suona in **streaming**, è segnato «Suggerito» e si può **scaricare** o
**aggiungere a una playlist**. Senza rete (o, con l'opzione, fuori dal Wi‑Fi) resta la casuale normale.
**Prerequisiti:** fase 17/18 (`CodecoreAudioHandler`, `PlayQueue` con ordine di ascolto e chiavi per voce,
`NextWindow`, `GaplessCapable`, `CrossfadeEngine`), 20 (cronologia), 28.4 (InnerTube con maschera dei campi),
28.6 (indirizzo diretto con yt-dlp `-g`), 12/15 (abbinamento con la libreria: `LibraryIndex`, `scoreCandidate`,
`decide`), 8/10 (la Jam ha un backend suo e non tocca `PlayQueue`), 30.2 (aiuti JSON di InnerTube in
`innertube_json.dart`).
**Principio:** il lettore principale suona i suggeriti come qualunque brano (notifica, cuffie, MPRIS/SMTC,
equalizzatore, velocità, timer), ma **niente** del database li tocca: non sono righe di `tracks`, non entrano in
cronologia né in statistiche, non sopravvivono a un riavvio. Opzione **spenta di serie**; la rete parte solo con
l'opzione attiva e mentre si ascolta. Nessun pacchetto nuovo. Assente nella variante `lite`.

> ⚠️ Come per «Ascolta» (28.6): ascoltare e scaricare da YouTube può violare i suoi Termini. Uso strettamente personale.

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)
`POST https://music.youtube.com/youtubei/v1/next?prettyPrint=false`, contesto `WEB_REMIX 1.20250101.01.00`, `hl en`.

| Richiesta | Tempo | Peso gzip (testo) | Cosa c'è |
|---|---|---|---|
| Radio di un **brano**: `videoId o7MlC_Qrmmc` («Mother», id del brano di YouTube Music), `playlistId RDAMVMo7MlC_Qrmmc`, `params wAEB`, `isAudioOnly true`, `enablePersistentPlaylistPanel true` | 0,72 s | 37 KB (579 KB) · **11 KB con maschera** | `contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer.watchNextTabbedResultsRenderer.tabs[0].tabRenderer.content.musicQueueRenderer.content.playlistPanelRenderer.contents[].playlistPanelVideoRenderer`: `videoId`, `title`, `longBylineText` (artista • album • anno, con `browseId` `UC…`/`MPREb_…`), `lengthText`, miniature quadrate 60…544. **50 voci, tutte brani con album**; la prima è il seme (`selected: true`); poi Pink Floyd, Dire Straits, Bob Dylan, Beatles, Clapton, Sting, Stones, Led Zeppelin, Eagles, Neil Young, Radiohead, Nirvana… `continuations[0].nextRadioContinuationData.continuation` per altre voci |
| Continuazione (`{continuation}`) | 0,56 s | 34 KB | `continuationContents.playlistPanelContinuation`: 49 voci, **34 già viste** nella prima pagina |
| Radio di un **videoclip** (`K6qj09OHvjw`, «Wish You Were Here (Official Video)») | 0,63 s | 34 KB | **0 brani**: 47 videoclip di canali d'artista, 3 caricamenti di utenti. Il seme deve essere l'id del **brano**, non del video |
| «Chip» del sintonizzatore (`musicQueueRenderer.subHeaderChipCloud`: All, Popular, Discover, Deep cuts, Focus, Rock, Classic rock, 1970s, …; ognuno con `queueUpdateCommand.fetchContentsCommand.watchEndpoint {playlistId, params}`) | 0,60–0,67 s | 18–19 KB | 24 voci: «Discover» **9 brani su 24**, «Rock» **2 su 24**, il resto videoclip: i chip di genere non danno brani |
| Ripiego yt-dlp: `-J --flat-playlist --playlist-items 1-50 "https://music.youtube.com/watch?v=<id>&list=RDAMVM<id>"` | 4,6 s (19 s senza limite: 426 voci) | — | «Mix - Mother», 50 voci con titolo, canale, durata; niente album; 9 su 50 in comune con la radio diretta |
| `yt-dlp -g -f bestaudio[ext=m4a]/bestaudio/best` (2026.08.19) | **4,7 s** sul PC (Mi A3: 9,6 s, PROGRESS 28.6) | — | indirizzo `…googlevideo.com`, `mime=audio/mp4`, `expire` = adesso **+ 6,0 h**, legato all'IP (`ip=`), `dur=334.743` |
| Copertina nella notifica | — | — | `audio_service` 0.18.19 carica da solo un `artUri` `http(s)` (`AudioService.cacheManager`, `flutter_cache_manager` già fra le sue dipendenze) |

Maschera della radio: `contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer.watchNextTabbedResultsRenderer.tabs.tabRenderer.content.musicQueueRenderer(content.playlistPanelRenderer(contents.playlistPanelVideoRenderer(videoId,title,longBylineText,lengthText,thumbnail),continuations),subHeaderChipCloud.chipCloudRenderer.chips.chipCloudChipRenderer(text,navigationEndpoint))`

## Decisioni
| Tema | Scelta |
|---|---|
| Attivazione | Pulsante «casuale» a **tre stati** (spento → casuale → casuale+, icona con «+»), in «In riproduzione», barra desktop e modalità auto; pressione lunga → foglio con le impostazioni. Stato salvato (`AppSettings.shufflePlus`). Funziona solo se: casuale attiva, ascolto partito da una **lista** di ≥ 5 brani musicali (playlist, playlist intelligente, album, artista, genere, Preferiti, Tutti i brani), nessuna Jam, yt-dlp disponibile, rete consentita. Altrimenti si comporta da casuale normale (e lo dice il foglio). Notifica e MPRIS conoscono solo «casuale sì/no»: spegnere da lì spegne anche il «+» |
| Frequenza | «1 ogni N» con N da 3 a 10, predefinito **4** (3 brani tuoi, poi un suggerito). C'è **al più un** suggerito in attesa nella coda; il successivo si sceglie quando quello è passato |
| Semi (il «genere») | Il genere segue la lista: fino a **3 brani della lista in ascolto** fanno da semi, scelti a caso fra quelli del genere più presente (se ≥ 40 % dei brani ha lo stesso `genre`), altrimenti fra tutti; si cambiano ogni 8 suggeriti. I chip di genere della radio **non** si usano (misurato: quasi solo videoclip) |
| Dal brano al seme | `videoId` del brano di YouTube Music, in quest'ordine: (1) `downloads.json` al contrario (percorso → id, nessuna rete); (2) `seed_ids.json` (indice dei semi già trovati, anche «non trovato» per 30 giorni); (3) ricerca YouTube Music «brani» `«artista» «titolo»` (diretta, 0,5 s) con `scoreCandidate`/`decide` dell'importazione, solo `sure`. Se la radio del seme non ha il seme fra i brani (era un videoclip), si cerca il brano come al punto 3 e si usa quell'id |
| Radio | InnerTube `next` come in tabella, con maschera (intero se vuota); al bisogno una continuazione. Ripiego se `InnerTubeChanged`: il mix di yt-dlp (`listPlaylist` con `watch?v=<id>&list=RDAMVM<id>`, 50 voci) per 10 minuti, come la ricerca (R70) |
| Cosa si suggerisce | Solo **brani** (riga con un album). Videoclip di canali d'artista solo se mancano brani; mai caricamenti di utenti. Durata 60 s – 12 min. Mai: già in libreria (`DownloadIndex` per id, poi titolo + artista + durata ±5 s con `LibraryIndex`, come l'importazione), già suggerito negli ultimi 30 giorni, già in coda, «Non mi piace». Al più un brano dello stesso artista ogni 3 suggeriti |
| Voci online nella coda | `PlayQueue` resta `List<int>`: un suggerito ha un **id negativo** (−1, −2, …) e un registro in memoria `OnlineEntries` (id → `YtResult` + seme + ora). Per interfaccia, notifica e MPRIS c'è un `Track` **sintetico** (mai scritto nel DB: `id` negativo, `path 'online:youtube:<videoId>'`, `kind 0`, `coverKey null`). Ogni scrittura su DB guarda `isOnlineId(id)` e non parte |
| Riproduzione | Lo stesso `CodecoreAudioHandler`: per un id negativo `_loadCurrent` chiede l'indirizzo e fa `loadUri`. Indirizzo **in anticipo**: quando il suggerito diventa il prossimo (`peekNext`) si chiede a yt-dlp in background (`StreamAddressCache`), si riusa finché mancano > 10 min alla scadenza (`expire` dell'indirizzo); se il brano arriva prima che l'indirizzo sia pronto si aspetta con «Caricamento…» fino a 15 s. 403/indirizzo scaduto → una nuova richiesta; poi errore → messaggio e **salto** (contano nei 3 errori di fila di oggi). ReplayGain: nessuno (fattore 1) |
| Senza pause e dissolvenza | In questa fase verso e da un suggerito c'è il passaggio **normale** (come per i brani con segnalibro: `NextWindow` riceve null perché `getById` di un id negativo non trova nulla). Gapless/crossfade anche per i suggeriti: task facoltativo 31.14 |
| Cronologia e statistiche | I suggeriti **non contano**: niente `plays`, `play_count`, «più ascoltati», segnalibro, arricchimento, testi. L'esito (saltato, ascoltato fino in fondo, scaricato, «non mi piace») va nel **registro dei suggeriti** (`suggestions.json`, ultimi 500). Scaricato, diventa un brano normale da lì in poi |
| Dopo l'ascolto | Un suggerito passato **esce dalla coda** (con «ripeti tutto» non torna al giro dopo); «Indietro» va al brano della libreria prima. «Svuota» ricrea la coda dalla lista (fase 28): i suggeriti spariscono e il motore ne mette uno nuovo |
| Riavvio | Si salvano solo gli id della libreria (se l'attuale è un suggerito, si salva il brano della libreria che lo seguiva); con Shuffle+ ancora attivo il motore ne mette di nuovi |
| Rete | Opzione «Solo su Wi‑Fi» (predefinito **acceso**) = rete **non a consumo** (`ConnectivityManager.isActiveNetworkMetered()` su Android con un canale nuovo `codecore/net`; desktop: sempre consentito). Senza rete o su rete a consumo: niente richieste, il suggerito in attesa esce dalla coda, si riprova dopo 2 minuti |
| Limiti | Al più **1 richiesta radio al minuto**, ≤ 3 ricerche di semi per riempimento, un indirizzo alla volta; 429 → Shuffle+ in pausa per 15 minuti (avviso una volta). Niente richieste in pausa, a lettore fermo, durante una Jam o a opzione spenta |
| Dati consumati | ≈ 3–4 MB per suggerito (AAC 128 kbps, 4 min) + ≈ 11 KB per radio: con 1 ogni 4 e ~15 brani all'ora ≈ **15 MB/h** |
| Interfaccia | Riga della coda con miniatura, nuvola e «Suggerito»; in «In riproduzione» «Suggerito · simile a «<seme>»», copertina dalla miniatura (544 px); azioni **Scarica**, **Aggiungi a playlist** (scarica e aggiunge quando il file arriva), **Non mi piace** (salta e non lo propone più), Rimuovi dalla coda. Pagina «Suggeriti di recente» (dal menu della Coda) con Ascolta/Scarica |
| Jam | Shuffle+ sospeso durante una Jam (il pulsante lo dice); avviando una Jam dalla coda le voci online non entrano (`jamSeedTracks` legge solo righe del DB) |
| File condivisi con altri lavori | `lib/ui/shell/*` (barra desktop, messaggi d'errore in `app_shell.dart`) e `MainActivity.kt` sono stati toccati dalla fase 29.2 («Memoria», commit `3645d5e`): prima di modificarli controllare con `git status`/`git log` che nessun altro lavoro sia aperto su quei file; il codice Android nuovo sta in un file suo (`NetworkBridge.kt`, come `StorageBridge.kt`) |
| Pacchetti nuovi | Nessuno |

## Task

### 31.1 — Verifiche preliminari
Gli esiti dal PC sono nella tabella «Misure dal vivo». Restano:
1. Fixture ridotte (senza `trackingParams`, `clickTrackingParams`, `loggingContext`, `accessibility`):
   `test/fixtures/innertube/ytm_radio.json` («Mother», maschera, 15 voci), `ytm_radio_continuation.json` (15 voci),
   `ytm_radio_video_seed.json` (seme videoclip, 10 voci senza album), `ytm_radio_discover.json` (chip, voci miste),
   `test/fixtures/yt_mix_flat.json` (ripiego yt-dlp, 10 voci).
2. **Motorola edge 40 (LTE e Wi‑Fi)**: tempo di `-g` dal canale Android; un indirizzo chiesto 5 minuti prima suona con
   ExoPlayer; passando da Wi‑Fi a LTE l'indirizzo vecchio risponde 403 (sì/no); `isActiveNetworkMetered` vale `true` su
   LTE e `false` sul Wi‑Fi di casa. **Mi A3** (solo Wi‑Fi): tempo di `-g` (atteso ~10 s) e di una radio diretta.
3. Copertura dei semi: sul telefono dell'utente, quanti brani hanno un id in `downloads.json` e, di un campione di 20,
   quanti sono brani di YouTube Music (radio con il seme fra i brani) e quanti videoclip.
4. Notifica Android con `artUri` `https://lh3…=w544-h544…`: la copertina compare.
**Verifica:** fixture nel repository, note in PROGRESS. **Stop** se la radio con `wAEB` non dà più brani o se un
indirizzo chiesto in anticipo non suona su ExoPlayer: riportare.

### 31.2 — Coda: inserire e togliere voci in un punto
**File:** `lib/services/audio/play_queue.dart`, `test/services/audio/play_queue_test.dart`
1. `insertAt(int index, int id)`: nuova chiave; con l'ordine naturale salvato (`_natural`) la chiave va dopo quella
   della voce che la precede, così spegnendo la casuale l'ordine resta coerente; `index` oltre la fine = in coda.
2. `removeId(int id)` (prima occorrenza): come `removeAt`, restituisce se era la corrente.
**Verifica:** inserimento prima, dopo e alla posizione corrente (la corrente non cambia); spegnere la casuale dopo un
inserimento non perde la voce né la corrente; storia e «indietro» dopo `removeId` saltano la voce tolta; `revision` cresce.

### 31.3 — Voci online: registro e brano sintetico
**File:** `lib/services/audio/online_entries.dart`, `test/services/audio/online_entries_test.dart`
1. `bool isOnlineId(int id) => id < 0`; `OnlineEntry {id, result: YtResult, seedTitle, addedAt}`;
   `OnlineEntries.register(result, {seedTitle}) → int` (id negativi mai riusati nella sessione), `operator []`,
   `forget(id)`, `trackOf(id) → Track?` (campi in Decisioni: `durationMs` dalla durata del risultato, `album`,
   `artist` = artisti uniti, `addedAt` = ora).
**Verifica:** id negativi unici anche dopo `forget`; `trackOf` con titolo/artista/album/durata del risultato e
`path` `online:youtube:<id>`; id sconosciuto → null.

### 31.4 — Indirizzi dello streaming con scadenza
**File:** `lib/services/audio/stream_address_cache.dart`, `test/services/audio/stream_address_cache_test.dart`
1. `expiryOf(Uri)` dal parametro `expire` (secondi Unix), null se manca (vale «subito da rinnovare»).
2. `StreamAddressCache(resolve, {now, margin = 10 min, wait = 15 s})`: `address(YtResult)` con una sola richiesta in
   corso per brano, riuso finché `expire − now > margin`; `prefetch(r)` (senza attendere, errori solo nel log);
   `invalidate(r)` (dopo un 403); al più 20 indirizzi tenuti.
**Verifica:** riuso prima della scadenza e nuova richiesta dopo; due `address` contemporanei = una richiesta;
`invalidate` forza una nuova richiesta; errore del resolver propagato a chi aspetta.

### 31.5 — Il lettore suona le voci online
**File:** `lib/services/audio/codecore_audio_handler.dart`, `lib/main.dart` (cablaggio), `lib/ui/shell/app_shell.dart`
(solo il messaggio del nuovo motivo, nello `switch` dei `PlaybackFailureReason`: vedi «File condivisi»), ARB, `test/services/audio/online_playback_test.dart`
1. Costruttore: `OnlineEntries? online`, `StreamAddressCache? addresses`.
2. `_loadCurrent`: id negativo → voce del registro (assente → `notInLibrary` e salto come oggi) →
   `_enterTrack(sintetico)` → `loadUri(await addresses.address(r))`; `BackendException` con 403/indirizzo scaduto →
   `invalidate` e un secondo tentativo; poi `PlaybackFailureReason.onlineUnavailable` e salto.
3. Nessun `registerPlay`, `_beginListen`, segnalibro, ReplayGain per gli id negativi; `_toMediaItem`: `id`
   `online:<videoId>`, `artUri` della miniatura (`googleThumbAt(…, 544)` della 30.3), `extras {'online': true}`.
4. `_refreshWindow`: se `peekNext()` è negativo → `addresses.prefetch`. `insertAt(index, id)`/`removeQueueId(id)`
   pubblici (avvisano `queueChanges` e rinnovano la finestra); getter `sourceIds` (la lista di partenza `_source`).
**Verifica (backend e resolver finti):** una voce online suona con `loadUri` dell'indirizzo; prima voce online come
prossimo → `prefetch` chiamato una volta; 403 → seconda richiesta e poi suona; due errori → salto al brano seguente
con il motivo nuovo; ascoltata fino in fondo → nessuna riga in `plays` e `play_count` invariato (stesso test della
cronologia con DB in memoria); i brani della libreria come prima (test esistenti verdi).

### 31.6 — Coda a schermo, brano corrente, salvataggio e azioni
**File:** `lib/providers/player_providers.dart` (`queueProvider`, `liveCurrentTrackProvider`, provider del registro),
`lib/services/audio/playback_persistence.dart`, `lib/ui/widgets/track_actions.dart`, `lib/ui/widgets/bulk_actions.dart`,
`test/services/audio/playback_persistence_test.dart`, `test/providers/queue_provider_test.dart`,
`test/providers/jam_seed_test.dart`
1. `queueProvider`: una voce per **ogni** posizione della coda (oggi `getByIdsLight` scarta gli id che non trova e
   gli indici si spostano): libreria dal DB, online da `trackOf`.
2. `liveCurrentTrackProvider`: id negativo → il sintetico (oggi `watchById` darebbe null).
3. `savedQueue(ids, index)` (puro) in `playback_persistence.dart`: toglie gli id negativi, l'indice punta alla voce
   della libreria corrente o a quella che seguiva il suggerito.
4. Azioni sul brano e di gruppo: per un id negativo solo Scarica, Aggiungi a playlist, Non mi piace, Rimuovi dalla
   coda (31.11); nascoste Preferito, Modifica, Testi, Elimina, Invia, Etichette, Vai all'album/artista locale.
**Verifica:** coda con un suggerito in mezzo → 3 voci nelle posizioni giuste; `savedQueue` (suggerito corrente, in
mezzo, in fondo, solo suggeriti); `jamSeedTracks` con un id negativo in coda lo scarta; l'elenco delle azioni di un
brano online contiene solo le quattro previste.

### 31.7 — Semi: dal brano della libreria all'id di YouTube Music
**File:** `lib/services/shuffle_plus/seed_resolver.dart`, `lib/services/shuffle_plus/seed_index.dart`,
`lib/services/online/download_index.dart` (`idForPath`), `test/services/shuffle_plus/seed_resolver_test.dart`
1. `DownloadIndex.idForPath(path)`: ricerca inversa in memoria (nessun accesso al disco).
2. `SeedIndex`: `seed_ids.json` (chiave `matchTitleKey(titolo)|chiave artista` come `LibraryIndex`, valore id o
   `''` = non trovato, con data; «non trovato» scade dopo 30 giorni), scrittura con debounce come `SearchCache`.
3. `SeedResolver.resolve(Track)`: ordine delle Decisioni; la ricerca usa `ImportRow` dal brano (titolo, artisti,
   durata) e `decide` dell'importazione, solo `sure`. `chooseSeeds(List<Track> source, {random, count = 3})`:
   genere prevalente ≥ 40 % → solo quel genere, altrimenti tutti; brani con `missing` esclusi.
**Verifica:** id da `downloads.json` senza ricerca; seconda volta dall'indice senza ricerca; «non trovato» ricordato e
riprovato dopo 30 giorni; candidato `review` non usato; `chooseSeeds` con genere prevalente, con generi misti, con
meno di 3 brani.

### 31.8 — Radio di YouTube Music (client e parser)
**File:** `lib/services/online/innertube_client.dart` (`radio`), `lib/services/online/ytm_radio_parser.dart`,
`test/services/online/ytm_radio_parser_test.dart`
1. `InnerTubeClient.radio(videoId, {continuation, cancel})`: corpo e maschera della tabella; stessi errori e stessa
   richiesta intera se la maschera dà vuoto.
2. `parseRadio(Map) → RadioPage {items: List<RadioItem{result: YtResult, kind: song|artistVideo|upload,
   isSeed}>, continuation}`; `kind` dai `pageType` del `longBylineText` (`ALBUM` → brano, `ARTIST` → videoclip
   d'artista, `USER_CHANNEL` → caricamento); `parseRadioContinuation` per `continuationContents`.
3. Ripiego: `radioFallback(videoId)` = `ytDlp.listPlaylist('https://music.youtube.com/watch?v=<id>&list=RDAMVM<id>', limit: 50)`
   (voci senza album: `kind = artistVideo`).
**Verifica:** `ytm_radio.json` → 15 brani, il primo `isSeed`, artisti/album/durata letti, continuazione presente;
seme videoclip → nessun brano; continuazione letta; risposta sconosciuta → `InnerTubeChanged`.

### 31.9 — Bacino dei suggerimenti e registro (logica pura)
**File:** `lib/services/shuffle_plus/suggestion_pool.dart`, `lib/services/shuffle_plus/suggestion_log.dart`,
`test/services/shuffle_plus/suggestion_pool_test.dart`, `test/services/shuffle_plus/suggestion_log_test.dart`
1. `SuggestionLog`: `suggestions.json` (ultimi 500: videoId, titolo, artista, seme, ora, esito
   `queued|skipped|heard|downloaded|disliked`), `recentlySuggested(videoId, {days = 30})`, `disliked(videoId)`.
2. `SuggestionPool`: riceve le pagine di radio dei semi e le alterna (una voce per seme a turno); `take({inLibrary,
   inQueue, log, lastArtists})` → il prossimo candidato secondo le regole delle Decisioni (brani prima dei videoclip
   d'artista, durata 60 s–12 min, artista non fra gli ultimi 2 suggeriti), oppure null (= serve un'altra pagina).
**Verifica:** scarta già in libreria (per id e per titolo+artista+durata), già suggerito da 10 giorni (e non da 40),
«non mi piace», già in coda, troppo corto/lungo, caricamento di utente; videoclip d'artista solo a brani finiti;
alternanza fra semi; stesso artista non tre volte di fila; registro: tetto di 500 e rilettura.

### 31.10 — Motore Shuffle+
**File:** `lib/services/shuffle_plus/insertion_plan.dart` (puro), `lib/providers/shuffle_plus_providers.dart`
(`ShufflePlusController`), `test/services/shuffle_plus/insertion_plan_test.dart`,
`test/providers/shuffle_plus_test.dart`
> Nota (fase 48): `nextInsertion` è stata sostituita da `plusPlan` (D-94 in `docs/decisioni.md`); quanto segue descrive la versione originale.
1. `nextInsertion(items, currentIndex, playedSinceLast, every)` → indice in cui mettere il prossimo suggerito o null
   (ce n'è già uno in attesa dopo la corrente, oppure la coda finisce prima); `playedSinceLast` conta i brani della
   libreria passati (saltati compresi) dall'ultimo suggerito.
2. Controller: ascolta `queueChanges`/brano corrente/impostazioni/Jam/rete; condizioni delle Decisioni; riempie il
   bacino in background rispettando i limiti; inserisce con `insertAt`; toglie i suggeriti passati (`removeQueueId` +
   `forget`); scrive gli esiti nel registro (`heard` se arrivato a fine brano, `skipped` altrimenti); 429 → pausa di
   15 min; tre errori di riproduzione di fila su suggeriti → spento per la sessione con un avviso. Cambia la lista
   di partenza → semi nuovi, bacino svuotato.
**Verifica:** `nextInsertion` (con N = 4: su 12 brani i suggeriti cadono al 4°, 8°, 12° posto; «Riproduci dopo» non
ne crea due; coda che finisce prima → null); controller con servizi finti: nessuna richiesta con opzione spenta, in
Jam, su rete a consumo con «Solo su Wi‑Fi», senza casuale; con tutto acceso un suggerito ogni 4 brani; suggerito
passato tolto; 429 → nessuna richiesta per 15 minuti (orologio finto).

### 31.11 — Interfaccia dei suggeriti
**File:** `lib/ui/screens/now_playing/queue_sheet.dart`, `now_playing_cards.dart`, `now_playing_screen.dart`,
`lib/ui/widgets/online_queue_row.dart`, `lib/ui/widgets/track_art.dart` (copertina locale o miniatura online),
`lib/ui/widgets/mini_player.dart`, `lib/providers/pending_playlist_adds.dart`, ARB,
`test/providers/pending_playlist_adds_test.dart`, `test/ui/online_queue_row_test.dart`
1. `TrackArt(track)`: `CoverImage` per la libreria, `NetThumbnail` (miniatura del registro, `googleThumbAt`) per un id
   negativo; usato in mini-player, «In riproduzione», righe della coda.
2. `OnlineQueueRow` (miniatura, titolo, artista, nuvola + «Suggerito»; trascinabile e rimovibile come le altre righe;
   menu: Scarica, Aggiungi a playlist, Non mi piace, Rimuovi).
3. «In riproduzione»: riga «Suggerito · simile a «<seme>»», pulsanti Scarica e Aggiungi a playlist; nessun testo né
   curiosità.
4. «Aggiungi a playlist» = download con `tag: 'addto:<playlistId>'`; `PendingPlaylistAdds` ascolta
   `DownloadsNotifier.settled` e, a download riuscito, `PlaylistRepository.addTracks(playlistId, [id])` (id da
   `TrackRepository.idForPath`); il registro segna `downloaded`.
**Verifica:** `PendingPlaylistAdds`: download riuscito → brano nella playlist; fallito → niente; tag diverso → niente;
widget test: la riga online mostra «Suggerito» e il suo menu ha solo le quattro voci.
**Telefono:** riga e copertina corrette in coda, mini-player, «In riproduzione», notifica e schermata di blocco.

### 31.12 — Impostazioni, rete a consumo e pulsante a tre stati
**File:** `lib/data/settings/settings_store.dart` (`shufflePlus`, `shufflePlusEvery`, `shufflePlusUnmeteredOnly`),
`lib/ui/screens/settings/shuffle_plus_tiles.dart` (gruppo Riproduzione, accanto a `transition_settings_tiles.dart`), `lib/ui/widgets/shuffle_button.dart` (nuovo, usato da
`now_playing_screen.dart`, `lib/ui/shell/desktop_player_bar.dart`, `car_mode_screen.dart`),
`lib/ui/screens/now_playing/shuffle_plus_sheet.dart`, `android/app/src/main/kotlin/com/codecore/player/NetworkBridge.kt`
(+ una riga in `MainActivity.kt`), `lib/core/network_kind.dart`, `lib/providers/player_providers.dart`
(`cycleShuffle`), ARB, `test/data/settings_store_test.dart`, `test/ui/shuffle_button_test.dart`
1. Impostazioni salvate (e nel backup come le altre); `PlayerController.cycleShuffle()` spento → casuale →
   casuale+ → spento.
2. `NetworkBridge.kt`: canale `codecore/net`, metodo `isMetered` (`ConnectivityManager.isActiveNetworkMetered()`,
   `false` se nessuna rete è attiva insieme a `online: false`); `networkKindProvider` in Dart (desktop: sempre non a
   consumo).
3. Foglio: interruttore, «1 ogni N» (3–10), «Solo su Wi‑Fi», stato attuale («In pausa: rete a consumo», «Non attivo
   durante una Jam», «Serve una lista di almeno 5 brani», «yt-dlp non disponibile»), «Suggeriti di recente».
**Verifica:** impostazioni salvate e rilette; `cycleShuffle` nei tre passi; pulsante con l'icona giusta per stato.
**Telefono (Motorola):** su LTE con «Solo su Wi‑Fi» nessun suggerito (il foglio dice perché), sul Wi‑Fi sì.

### 31.13 — «Suggeriti di recente»
**File:** `lib/ui/screens/now_playing/suggestions_screen.dart`, `queue_sheet.dart` (voce nel menu della Coda),
`lib/services/memory/app_data.dart` (voce in Memoria con «Svuota», come la cache delle ricerche), ARB
1. Elenco dal registro (più recenti prima): titolo, artista, «simile a …», esito; righe con Ascolta (28.6) e Scarica
   (`OnlineSongRow` della 30.8); «Svuota registro» con conferma.
**Verifica:** `flutter analyze`; nessun test di sola interfaccia (la logica è nel registro, 31.9).

### 31.14 — (Facoltativo) Senza pause e dissolvenza anche per i suggeriti
**File:** `lib/services/audio/audio_backend.dart` (`GaplessCapable.setNext` con `Uri? uri`), `just_audio_backend.dart`
(`AudioSource.uri`), `crossfade_engine.dart` (`loadUri` sul secondo lettore), `next_window.dart`,
`test/services/audio/gapless_handler_test.dart`, `crossfade_engine_test.dart`
1. La finestra accetta un suggerito come prossimo **solo** se il suo indirizzo è già pronto e non scade entro 10 min.
2. Misura sul Mi A3 prima di decidere se tenerlo (buffering dell'HLS/m4a remoto a volume 0 durante la dissolvenza).
**Verifica:** test esistenti verdi; finestra con un suggerito pronto → `setNext(uri:)`; indirizzo non pronto →
passaggio normale. **Si salta** se 31.1 mostra che ExoPlayer non regge due flussi.

### 31.15 — Test dal vivo, documentazione e prova a mano
1. `test/live/ytm_radio_live_test.dart` (dietro `CODECORE_LIVE=1`, giro notturno): radio di «Mother» con ≥ 20 brani
   con album e il seme primo; continuazione non vuota; ripiego yt-dlp con ≥ 20 voci.
2. ARB it/en/de/es/fr/pt; `docs/02-architettura.md` (sezione «Shuffle+ (fase 31)»: id negativi e registro, brano
   sintetico, indirizzi in anticipo, cosa non tocca il DB), `docs/99-rischi-e-fallback.md` (R77–R81), guida utente.
**Tocca a te (Mi A3 e Motorola, almeno 1 ora ciascuno):** «Canzoni rock» e una playlist blues in casuale+, 1 ogni 4:
i suggeriti sono del genere giusto e non li hai; Scarica e Aggiungi a playlist da un suggerito; Non mi piace; schermo
spento 30 minuti (i suggeriti continuano); modalità aereo a metà (casuale normale, nessun blocco); LTE con «Solo su
Wi‑Fi»; riavvio dell'app (nessun suggerito vecchio in coda); Jam avviata e chiusa; consumo di dati dopo un'ora
(Impostazioni di Android) da confrontare con la stima di 15 MB/h.

## Fuori da questa fase
Suggeriti senza casuale o fuori da una lista (es. dalla ricerca), suggeriti nella Jam, **radio dell'artista** come
coda intera (stessa infrastruttura, dopo), download automatico dei suggeriti, «Mi piace»/«Non mi piace» inviati a
YouTube (nessun account), cache su disco dello streaming (R71), correzione del volume fra brani normalizzati e flussi
(R81: solo se l'ascolto lo chiede), suggeriti in Android Auto e nel widget (copertina), chip della radio per genere.

## Rischi (proposti per `99-rischi-e-fallback.md`, da copiare in 31.15)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R77 | Un id negativo arriva a codice che si aspetta una riga di `tracks` | Preferito/modifica/eliminazione che falliscono o toccano il brano sbagliato, coda a schermo sfasata, riavvio con «non in libreria» | Registro `OnlineEntries` + `isOnlineId` prima di ogni scrittura; azioni ridotte per i suggeriti; `queueProvider` allineato per posizione; salvataggio senza id negativi; test con un repository che fallisce sugli id negativi |
| R78 | Indirizzo dello streaming lento (Mi A3 ~10 s), scaduto (6 h) o legato all'IP (403 dopo un cambio di rete) | Silenzio o salto al suggerito | Indirizzo chiesto quando il suggerito diventa il prossimo; scadenza letta dall'indirizzo; una nuova richiesta su 403; attesa massima 15 s poi salto; tre errori di fila → Shuffle+ spento per la sessione |
| R79 | La radio dà videoclip, doppioni o brani che hai già | Suggeriti con introduzioni parlate, brani ripetuti o già in libreria | Semi solo da brani di YouTube Music (un seme videoclip si sostituisce, misurato: 0 brani), filtro sui brani con album, doppioni per id e per titolo+artista+durata, registro di 30 giorni, «Non mi piace» |
| R80 | Rete in background: dati mobili, YouTube che risponde 429 | Consumo inatteso, ricerche e download dell'utente bloccati | Opzione spenta di serie, «Solo su Wi‑Fi» acceso di serie (rete non a consumo), 1 radio al minuto, pausa di 15 min su 429, niente rete in pausa o in Jam; stima di 15 MB/h mostrata nel foglio |
| R81 | Volume diverso fra brani della libreria (ReplayGain) e flussi di YouTube | Suggerito più forte o più piano | Nessuna correzione in questa fase; se l'ascolto lo chiede, un guadagno fisso per i flussi con «Normalizza» attivo (da misurare) |
| R70 (esteso) | La radio (InnerTube `next`) cambia formato | Nessun suggerito, riga «direct radio unreadable» nel log | Ripiego sul mix di yt-dlp per 10 minuti (4,6 s, 50 voci), fixture e test notturno `ytm_radio_live_test.dart` |

## Domande aperte per l'utente
1. I suggeriti **non contano** in cronologia e statistiche (anche se ascoltati fino in fondo); contano da quando li
   scarichi. Va bene, o vuoi che un suggerito ascoltato per intero compaia nella cronologia (servirebbe una tabella nuova)?
2. Pulsante **casuale a tre stati** (spento → casuale → casuale+) o un interruttore separato in «In riproduzione»?
3. Valori predefiniti: **1 ogni 4** e **«Solo su Wi‑Fi» acceso**?
4. Un brano già suggerito non torna per **30 giorni**: va bene?
5. Shuffle+ solo con la **casuale** attiva (come il nome), o anche nell'ordine della playlist?

## Definition of Done
- [ ] Con casuale+ attiva, ogni N brani un brano che non hai, simile alla lista in ascolto, segnato «Suggerito»
- [ ] Suona dal lettore principale (notifica, cuffie, MPRIS/SMTC) con indirizzo chiesto in anticipo; errori → salto
- [ ] Scarica, Aggiungi a playlist, Non mi piace; «Suggeriti di recente»
- [ ] Niente DB per i suggeriti: né cronologia, né statistiche, né salvataggio della coda; nessun effetto con opzione spenta
- [ ] Rete solo con opzione attiva, «Solo su Wi‑Fi», limiti e pausa su 429; Jam e rete assente → casuale normale
- [ ] Test: coda (`insertAt`/`removeId`), registro e sintetico, indirizzi, lettore, coda a schermo e salvataggio, semi, radio, bacino e registro, piano d'inserimento e controller, aggiunte a playlist
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Risposte dell'utente (2026-10-22: «ok» alle proposte)
- I suggeriti restano fuori da cronologia e statistiche finché non vengono scaricati o aggiunti a una playlist.
- Pulsante casuale **a tre stati**: spento → casuale → Shuffle+ (quindi Shuffle+ solo con la casuale).
- Predefiniti: **1 suggerito ogni 4 brani**, **«Solo su Wi‑Fi» acceso**.
- Un brano già suggerito non torna per **30 giorni**.
