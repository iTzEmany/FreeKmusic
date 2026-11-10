# Fase 32 — Ricerca intelligente

**Obiettivo:** in Cerca restano **due modi** soltanto: **In libreria** e **Online**. Online non si sceglie più la
fonte prima di cercare: la stessa ricerca va **insieme** a YouTube Music e YouTube, ogni risultato riceve un
**punteggio di confidenza**, lo **stesso brano** trovato in più fonti diventa una riga sola (presa dalla fonte
migliore), i risultati sopra la soglia sono i **«Migliori risultati»** e gli altri finiscono in **«Altri risultati»**
(chiuso). Si riconosce cosa si cerca: un **artista** → la sua card (fase 30) per prima; «titolo artista» → brani; un
indirizzo → playlist/canale come oggi. I chip delle fonti restano, ma come **filtro facoltativo**. **SoundCloud**:
misurato, non aggiunge nulla → proposta di toglierlo dalla ricerca (32.8, dopo la risposta dell'utente).
**Prerequisiti:** fase 30 (card dell'artista, `artistIds`/`albumId`, `YtmCatalog`, `OnlineSongRow`, pagine artista e
album; **deve essere già unita**: tocca gli stessi file di Cerca), 28.4 (InnerTube con maschera e ripiego yt-dlp,
`DirectSearchService`), 28.6 («Ascolta»), 12/15/22.4 (`scoreCandidate`, `matchTitleKey`, `cleanSearchQuery`).
**Principio:** si riusa il punteggio dell'importazione (stesse parole, stesse penalità per le versioni) senza la
durata, che una ricerca libera non conosce; le richieste partono solo all'invio (Invio o freccia), in parallelo, con
cache; un blocco di risultati già mostrato non si riordina sotto il dito. Nessun pacchetto nuovo. In `lite` la
modalità Online resta nascosta come oggi.

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)
Script di prova fuori dal repository (copia di `HEAD` dei sorgenti dell'app: `InnerTubeClient.searchSongs` e
`searchVideos` diretti, `YtDlpProcessService.searchSoundCloud` con yt-dlp 2026.08.19, `decide`/`scoreCandidate`
dell'importazione con le soglie di serie 0,80/0,55). Campione: le **34 righe** di `test/fixtures/Just_a_mood.csv`
(con la durata vera di Spotify) più **20 ricerche scelte dove SoundCloud dovrebbe dare di più**: remix (Kaytranada
«If (Janet Jackson Remix)», Disclosure «You & Me (Flume Remix)», Chet Faker «No Diggity»), emergenti (Kaytranada «At
All»), DJ set (Fred again.. «Boiler Room London», Charlotte de Witte «Tomorrowland 2023», Four Tet «Essential
Mix»), rap nato su SoundCloud (Lil Peep «Star Shopping», XXXTentacion «Look At Me»), rap italiano (Sfera Ebbasta
«XDVR», Massimo Pericolo «7 miliardi», Dark Polo Gang «Cono Gelato»), indie italiano (Tutti Fenomeni «Valori
aggiunti», I Cani «Hipsteria», Coma_Cose «Post concerto»), lo-fi (Jinsang «Affection», idealism «controlla»),
lo-fi house (DJ Seinfeld «U», Ross From Friends «Talk to Me You'll Understand»), bootleg (Fleetwood Mac «Dreams
(Remix)»). Due giri: (1) come l'importazione (5 risultati, YouTube con «artista - titolo»), (2) come la ricerca
intelligente (stessa frase a tutte le fonti, 10 risultati).

| | YouTube Music | YouTube | SoundCloud |
|---|---|---|---|
| CSV, brano esatto (`sure` ≥ 0,80 con la durata) | **34/34** (100 %) | 30–31/34 (88–91 %) | 16–18/34 (47–53 %), di cui **solo 9** dall'account dell'artista (gli altri: ricaricamenti di utenti, «cardell», «Sureshaker Music»…) |
| 20 ricerche «da SoundCloud», primo risultato giusto fra i primi 5 (controllo a mano) | 15/20 (mancano i 3 DJ set, il remix di «If», il remix di «Dreams») | **18/20** | 12/20 (sbaglia flip, mashup, remix al posto dell'originale) |
| Trovati **solo** su SoundCloud | — | — | **0 su 54** (con 10 risultati: per «Dreams remix» YouTube elenca 7 remix/edit, SoundCloud 9 *diversi*: più varietà, nessun brano che manchi altrove) |
| Tempo (PC, 108 ricerche per fonte) mediana · p90 · massimo | **0,46 · 0,54 · 0,90 s** | 0,47 · 0,58 · 0,86 s | **5,4 · 8,3 · 14,5 s** |
| Mi A3 (fase 28) | 1,6–2,2 s | 1,6–2,2 s | **36 s** la ricerca; «Ascolta» SoundCloud **non suona** (R71) |
| Anteprime da 30 s scartate dal filtro | — | — | 110 su 810 risultati (14 %), in 38 ricerche su 54; uno spezzone da **36 s** («Singalong Junk [Taken From 'McCartney']», account ufficiale) passa il filtro ≤ 31 s |
| Stesso video in due fonti | il primo brano YouTube Music è anche fra i risultati YouTube in **18/34** ricerche (stesso `videoId`) | | |
| Card di YouTube Music (`search` senza filtro, maschera della card della 30.1, 0,5 s) | «pink floyd», «lucio dalla» → artista; «vasco» → artista **Vasco Rossi** (la frase è solo l'inizio del nome); «the wall» e «the wall pink floyd» → **album** («Album • Pink Floyd • 1979»); «mother pink floyd» → brano (`musicVideoType` `MUSIC_VIDEO_TYPE_ATV`, «Song»); «bohemian rhapsody» → **videoclip dal vivo** («Live At Wembley Stadium», `MUSIC_VIDEO_TYPE_OMV`, «Video») | | |

**Prototipo della confidenza** (giro 2, 680 candidati YouTube Music + YouTube delle righe CSV, confrontati con il
punteggio dell'importazione con la durata vera). Confidenza = `scoreCandidate` con la riga costruita dalla frase
cercata (artista riconosciuto se il nome che il risultato accredita compare nella frase) e **senza durata**, riportata
su 0–1 togliendo il termine neutro della durata: `(s − 0,225) / 0,55`.
- Soglia **0,55**: per riga in mediana 10,5 «Migliori» e 9,5 «Altri» su 20; il **brano esatto è fra i Migliori in
  34/34** righe; recall sui candidati esatti 0,97. A 0,65 il recall scende a 0,94.
- Primo risultato (confidenza, poi fonte YouTube Music → YouTube, poi posizione) = **brano esatto in 32/34**; gli
  altri due sono lo stesso brano in un'altra registrazione («Let It Be» 3:51 invece della versione dell'album 4:03;
  «Girl from the North Country» del 1963, 3:20, prima del duetto con Johnny Cash, 3:41, che è secondo). Primo risultato
  da YouTube Music in 34/34 righe CSV; nelle 20 ricerche extra da YouTube in 4 (i 3 DJ set e il remix di «If», che
  YouTube Music non ha) e da YouTube Music in 16; primo risultato giusto in **19/20** (sbaglia solo «Dreams remix»).
- Le **cover di altri artisti** prendevano 0,64 (per «bob dylan girl from the north country»: Neil Young, Wylie & The
  Wild West): la frase contiene un artista che il risultato non accredita. Con il ritocco (5) delle Decisioni (× 0,8)
  scendono a 0,51; alla soglia 0,55 la precisione sale da 0,47 a 0,56, il recall scende da 0,97 a 0,94, il brano
  esatto resta fra i Migliori in 34/34 righe (in mediana 9 Migliori su 20).
- Errori ancora visti, da correggere nelle regole: «fleetwood mac dreams remix» mette per primo l'**originale** (la
  parola di versione chiesta manca nel risultato e non pesa abbastanza); 14 risultati sotto i 60 s (anteprime,
  «.seven» 32 s) e 43 video YouTube oltre i 20 minuti (DJ set, raccolte) da tenere giù se la frase non chiede un set.

## Decisioni
| Tema | Scelta |
|---|---|
| Modi | Due chip: **In libreria** (com'è oggi, operatori compresi) · **Online** (al posto di «YouTube»). Il pulsante in fondo ai risultati della libreria diventa «Cerca online "<testo>"» |
| Fonti di serie | **YouTube Music** («brani», 10) e **YouTube** («video», 10) in parallelo, più la **card** della fase 30 (stessa richiesta mascherata, ora letta anche quando è un album o un brano). SoundCloud: **fuori dalla ricerca** se l'utente conferma (32.8, misura sopra) |
| Confidenza | `queryConfidence(frase, risultato)` (vedi prototipo) con cinque ritocchi: (1) parola di versione (live, remix, cover, acoustic, edit, slowed…) **chiesta e assente** nel risultato → × 0,7; (2) durata < 60 s → × 0,6; (3) durata > 20 min → × 0,6, ma solo se YouTube Music ha almeno un brano sopra la soglia (la frase cerca una canzone) e la frase non contiene «mix», «set», «live», «concerto», «full album» (per «charlotte de witte tomorrowland 2023» YouTube Music non ha brani giusti: i set restano su); (4) priorità di YouTube: il 1° brano di YouTube Music + 0,05, il 2° + 0,03; il brano della card + 0,10 **solo se è un brano** (`MUSIC_VIDEO_TYPE_ATV`): un videoclip in card («bohemian rhapsody» → il live di Wembley) non riceve nulla; (5) nessun artista del risultato compare nella frase **e** la frase ha parole che il titolo non contiene (probabilmente un altro artista: una cover) → × 0,8. Valori tagliati a 0–1 |
| Soglia | **0,55** = «Migliori risultati» (al più 15 righe); sotto = **«Altri risultati (N)»**, chiuso, un tocco per aprirlo. Se nessuno supera la soglia, i primi 5 si mostrano comunque sotto la scritta «Nessun risultato sicuro». Nessun numero a schermo (domanda aperta) |
| Stesso brano | Si uniscono: stesso `videoId`; oppure `matchTitleKey` del titolo pulito (`cleanSearchQuery`) + artista principale + durata entro 5 s (se entrambe note). La riga mostrata è quella della fonte migliore: brano YouTube Music (ha album e artisti) → video «- Topic» → video del canale dell'artista → altri caricamenti; la confidenza del gruppo è la più alta. Sulla riga: «anche come video» quando c'è anche il videoclip (azione nel menu: «Ascolta il video») |
| Intento | URL → come oggi (playlist/canale → `PlaylistSourceSheet`, video → risultato singolo). Testo → card di YouTube Music: **artista** e frase uguale al nome o al suo inizio a parole intere di almeno 4 lettere (`matchKey`, «the» iniziale ignorato: «vasco» → Vasco Rossi) → card grande in cima e «Brani di <artista>» (i Migliori con `artistIds` di quell'artista), poi gli altri; **artista** ma frase più lunga → card piccola come in fase 30 e brani prima; **album** → card dell'album (apre `OnlineAlbumScreen` della 30.9) sopra i brani; **brano** → quel brano primo (ritocco 4); nessuna card → solo brani |
| Arrivo dei risultati | **Ordine stabile con tetto**: il blocco dei Migliori compare quando hanno risposto entrambe le fonti oppure 1,5 s dopo la prima risposta (PC: entrambe in 0,48 s di mediana, 0,90 s al massimo). Ciò che arriva dopo non sposta le righe già mostrate: se è lo stesso brano si unisce alla sua riga, altrimenti va **in fondo** al blocco (o negli Altri). La card compare quando arriva, sopra, senza spingere giù una lista già toccata (posto riservato solo se arriva entro il tetto) |
| Filtri | Chip «Tutte · YouTube Music · YouTube» sotto il campo, **solo filtro sui risultati già arrivati** (nessuna richiesta nuova); non si ricordano: ogni ricerca nuova parte da «Tutte». L'impostazione `searchSource` sparisce (lettura ignorata) |
| Cache | In memoria, 10 minuti, ultime 30 frasi (`matchKey`): rifare la stessa ricerca, tornare indietro o cambiare filtro non chiede nulla. «Aggiorna» (trascinamento) la salta. La cache su disco (`search_cache.json`, 30 giorni) resta dell'importazione |
| Annullare | Una ricerca nuova annulla le richieste dirette in corso (`CancelToken`) e ignora le risposte vecchie (`_requestId`, come oggi); il ripiego yt-dlp non si può fermare: la sua risposta tardiva si scarta |
| Errori e 429 | Per fonte: 429 → quella fonte in pausa 5 minuti (le ricerche nuove non la chiedono) e una riga «YouTube chiede una pausa: risultati solo da YouTube Music»; rete assente → messaggio di oggi; risposta illeggibile → ripiego yt-dlp di `DirectSearchService` (YouTube Music via yt-dlp ≈ 14 s: arriva dopo il tetto e si unisce). Tutte le fonti in errore → il messaggio di oggi con «Riprova» |
| Righe | `OnlineSongRow` della fase 30.8 (Ascolta, Scarica, «Già in libreria», selezione) con una piccola etichetta di fonte («YouTube Music» / «Video»); nome dell'artista toccabile come in 30.7 |
| File condivisi | `search_screen.dart`, `youtube_results.dart` e `listen_bar.dart` sono di Cerca e li modifica la fase 30 (30.6, 30.7, 30.11): iniziare solo con la fase 30 unita (`git log`), senza altri lavori aperti su quei file |
| Pacchetti nuovi | Nessuno |

## SoundCloud: cosa dà oggi e cosa si toglie
**Dove si usa oggi:** (1) fonte della ricerca (22.5, `SearchSource.soundcloud`; sul PC dell'utente la scelta salvata è
`youtube`); (2) ripiego dell'importazione per le righe non trovate (`importSoundCloud`, **spento** di serie e spento
sul PC dell'utente); (3) «Ascolta» dei risultati SoundCloud (28.6: non suona sul Mi A3, R71); (4) download dei risultati
SoundCloud (chiavi `soundcloud:<id>` in `downloads.json`, `ImportCandidate.source`, `webpageUrl`).
**Misura:** zero brani trovati solo su SoundCloud in 54 ricerche (anche le 20 scelte a suo favore), metà dei suoi
«sicuri» sono ricaricamenti di utenti, 12 volte più lento sul PC e 36 s sul Mi A3, anteprime da filtrare (e una che
passa). **Raccomandazione: togliere SoundCloud dalla ricerca e dall'importazione** (non chiederlo né di serie né come
chip), tenendo la lettura dei dati vecchi. Facoltativo: incollare un **link** SoundCloud per ascoltare/scaricare quel
brano (yt-dlp lo sa già fare: 32.9), per i rari casi di un bootleg visto altrove.
**Cosa si semplifica:** `searchSoundCloud` nell'interfaccia e nei 4 servizi (`yt_dlp_process_service.dart` con
`scsearch`, `parseSoundCloudJson`, filtro delle anteprime; `android_yt_dlp_service.dart`; `direct_search_service.dart`;
`cached_youtube_service.dart` con le chiavi `sc|`), `soundCloudFetchCount`, `SearchSource` intero, il ripiego
`soundCloudFallback` di `PlaylistImportService._find`, l'impostazione `importSoundCloud` e la sua riga in Impostazioni,
il ramo SoundCloud di `scoreCandidate` (`_soundCloudVersions` e i bonus per l'uploader), 3 stringhe ARB × 6 lingue,
3 file di test e 2 fixture (585 righe: `soundcloud_parse_test`, `soundcloud_matcher_test`, `test/live/soundcloud_live_test`,
`scsearch*.json`) più i casi SoundCloud di 6 test, il rischio R71 per SoundCloud. **Resta:** `MediaSource.soundcloud`
(chiavi vecchie di `downloads.json`, candidati salvati nelle importazioni «da verificare», icona di fonte nella revisione),
`_sourceOf` di `parseYtDlpJson`, il download con `webpageUrl`.

## Task

### 32.1 — Verifiche preliminari e fixture
Gli esiti dal PC sono in «Misure dal vivo». Restano:
1. Fixture dei casi: `test/fixtures/smart_search/cases.json` con le frasi del campione (8 righe CSV, tra cui «the
   beatles let it be», «lucio corsi sigarette», «bob dylan blowin in the wind», «bob dylan girl from the north
   country»; 6 extra, tra cui «fred again boiler
   room london», «fleetwood mac dreams remix», «kaytranada if janet jackson remix») con i risultati **già letti**
   (`YtResult` in JSON, 10 per fonte: si rifanno con lo script di prova come nel giro 2) e il primo atteso, più quattro
   frasi nuove da catturare allo stesso modo: «pink floyd», «vasco», «the wall», «bohemian rhapsody». Card: oltre a
   `ytm_top_artist_card.json` e `ytm_top_song_card.json` della 30.1, `ytm_top_album_card.json` («the wall») e
   `ytm_top_video_card.json` («bohemian rhapsody», videoclip `OMV`).
2. **Mi A3 (Wi‑Fi) e Motorola (LTE)**: tempo di YouTube Music + YouTube + card **in parallelo** (tre richieste, due host)
   contro una sola; annotare se il parallelo rallenta la prima risposta (TLS lento sul Mi A3, fase 28.10).
**Verifica:** fixture nel repository, note in PROGRESS. **Stop** se sul Mi A3 il parallelo porta la prima risposta oltre
2,5 s: riportare (piano B: card dopo i brani).

### 32.2 — Card del risultato principale e intento (logica pura)
**File:** `lib/services/online/ytm_artist_parser.dart` (della 30.3: `parseTopCard` che restituisce anche album e brano;
`parseTopArtistCard` resta e la usa), `lib/services/online/ytm_catalog.dart` (`topCard(q, hl)` accanto a `topArtist`,
stessa richiesta), `lib/services/online/query_intent.dart`, `test/services/online/query_intent_test.dart`,
`test/services/online/ytm_artist_parser_test.dart`
1. `TopCard` sigillata: `TopArtist(YtmArtistRef)` · `TopAlbum(YtmRelease + artista)` · `TopSong(videoId, title)`
   (solo `MUSIC_VIDEO_TYPE_ATV`) · `TopVideo(videoId, title)` (gli altri `watchEndpoint`).
2. `classifyQuery(text)` → url di playlist/canale (`listingUrl`), url di video, testo. `intentOf(query, TopCard?)` →
   `artistPage` (frase = nome) · `artistAndSongs` · `album` · `song` · `songs` (regole in Decisioni).
**Verifica:** «pink floyd» + card artista → `artistPage`; «PINK FLOYD», «the pink floyd» e «vasco» (Vasco Rossi) idem;
«pink floyd mother» + card artista → `artistAndSongs`; «mother pink floyd» + card brano → `song`; «the wall» + card album
→ `album`; «bohemian rhapsody» + card video → `songs` senza ritocco; nessuna card → `songs`; indirizzo di una
playlist → url.

### 32.3 — Confidenza di una ricerca libera (logica pura)
**File:** `lib/services/online/query_match.dart`, `lib/services/import/track_matcher.dart` (rendere pubbliche, senza
cambiarle, la lista delle versioni `otherVersions` e `hasPhrase`), `test/services/online/query_match_test.dart`
1. `queryConfidence(String query, YtResult r, {int rank = 0, bool fromTopCard = false})`: artista riconosciuto fra
   `r.artists`, l'artista di `cleanSearchQuery(r.title, r.channel)` e il canale senza «- Topic»/VEVO/Official (il nome
   più lungo che compare nella frase); `ImportRow` con il resto della frase come titolo; `scoreCandidate` senza durata;
   `(s − 0,225) / 0,55`; i ritocchi (1), (2), (4) e (5) delle Decisioni.
2. `scoreAll(query, {songs, videos, TopCard? card}) → List<ScoredResult>`: chiama `queryConfidence` per ogni
   risultato e applica il ritocco (3), che dipende dall'insieme (ci sono brani di YouTube Music sopra la soglia?).
3. `kBestThreshold = 0.55`.
**Verifica:** sui casi di `cases.json`: il primo per confidenza è quello atteso in tutti; «dreams remix» mette un remix
prima dell'originale; le cover di Neil Young e Wylie & The Wild West per «bob dylan girl from the north country»
sotto la soglia, le due registrazioni di Bob Dylan sopra; aggiunti a un caso «titolo artista», un risultato da 32 s e un video di 70 minuti stanno sotto
la soglia, mentre per «fred again boiler room london» il set da 72 minuti resta primo e per «charlotte de witte
tomorrowland 2023» i set restano sopra la soglia (YouTube Music senza brani giusti); frase con il solo titolo
(«bohemian rhapsody») → l'originale in studio sopra la soglia e prima del live della card; i test di
`scoreCandidate` dell'importazione restano verdi (nessun cambio).

### 32.4 — Lo stesso brano da più fonti (logica pura)
**File:** `lib/services/online/merge_results.dart`, `test/services/online/merge_results_test.dart`
1. `SmartResult {primary: YtResult, sources: Set<MediaKind{ytmSong, ytVideo}>, alternatives: List<YtResult>,
   confidence, hasVideo}`; `mergeResults(List<ScoredResult>) → List<SmartResult>` (regole in Decisioni), ordine per
   confidenza, poi fonte, poi posizione.
2. `splitBest(list, threshold, {maxBest = 15})` → Migliori / Altri / `noneSure` (nessuno sopra la soglia: i primi 5
   fra i Migliori).
**Verifica:** stesso `videoId` in due fonti → una riga con due fonti; titolo con «(Official Video)» e brano YouTube Music
con durata entro 5 s → una riga, primaria quella di YouTube Music, `hasVideo`; stessa canzone ma live (durata diversa e
«live») → due righe; durata assente in uno dei due → si unisce solo per titolo + artista uguali; ordine stabile a pari
confidenza.

### 32.5 — Il motore della ricerca online
**File:** `lib/services/online/smart_search.dart`, `lib/services/online/source_cooldown.dart`,
`lib/providers/smart_search_providers.dart`, `test/services/online/smart_search_test.dart`
1. `SmartSearch(youtube: YoutubeService, catalog: YtmCatalog, {now, cap = 1,5 s})`: `run(query, hl) →
   Stream<SmartSearchState>`; in parallelo `searchSongs(q, limit: 10)`, `search(q)` (video), `topCard(q, hl)`;
   intento (32.2), confidenza (32.3), unione (32.4); regola del tetto e dei ritardatari (Decisioni); stato con
   `best`, `others`, `card`, `intent`, `pending` (fonti che mancano), `notices` (429/rete per fonte), `error`.
2. `SourceCooldown`: 429 → fonte in pausa 5 minuti (orologio iniettato).
3. Cache in memoria (10 min, 30 frasi); `refresh: true` la salta.
4. Provider: `smartSearchProvider` (`family` per richiesta), annullamento della precedente.
**Verifica (servizi finti, orologio finto):** YouTube Music a 0,4 s e YouTube a 0,6 s → un solo stato con le due fonti;
YouTube a 3 s → stato al tetto con YouTube Music, poi lo stesso blocco con i nuovi **in fondo** e gli uguali uniti
(le prime righe non cambiano posizione); 429 da YouTube → stato con avviso e la ricerca dopo non lo chiede per 5
minuti; tutte in errore → `error`; stessa frase entro 10 minuti → nessuna richiesta; una ricerca nuova scarta la
risposta tardiva della vecchia.

### 32.6 — Cerca: In libreria · Online
**File:** `lib/ui/screens/search/search_screen.dart`, `lib/ui/screens/youtube/youtube_results.dart` (diventa
`online_results.dart`, le parti in widget piccoli: `online_results_sections.dart`), `lib/ui/screens/online/artist_card.dart`
(variante grande), `lib/ui/screens/online/album_card.dart`, `lib/data/settings/settings_store.dart` (`searchSource`
non più letto), ARB, `test/ui/search_sources_test.dart` (riscritto: modi e filtri), `test/ui/online_results_test.dart`
1. Chip **In libreria / Online**; il suggerimento del campo e il pulsante «Cerca online» cambiano testo.
2. Risultati online: card (secondo l'intento) → «Migliori risultati» → chip «Altri risultati (N)» che apre l'elenco
   sotto (costruito solo quando si apre) → `ListenBar`. Riga con etichetta di fonte e «anche come video».
3. Filtri «Tutte · YouTube Music · YouTube» sui risultati arrivati; avvisi per fonte in una riga sopra l'elenco;
   indicatore sottile finché una fonte manca.
4. Selezione multipla e «Scarica» come oggi (chiave `online`), sulle righe unite.
**Verifica:** widget test con `SmartSearch` finto: Altri chiuso e aperto; filtro YouTube Music nasconde le righe solo
video; card grande con l'intento `artistPage`; righe già mostrate che non cambiano posto all'arrivo della seconda fonte.
**Telefono (Mi A3):** «pink floyd», «pink floyd mother», «the wall», «fred again boiler room london», un indirizzo di
playlist: prima riga in < 2,5 s, nessun salto delle righe, «Altri risultati» con le versioni live/cover.

### 32.7 — Rifinitura del punteggio con le ricerche vere
**File:** `test/fixtures/smart_search/cases.json` (casi nuovi), `lib/services/online/query_match.dart` (solo pesi)
1. Dalla prova a mano di 32.6 e da 20 ricerche dell'utente (annotate in PROGRESS: frase, cosa si aspettava, cosa è
   uscito primo) aggiungere i casi sbagliati alle fixture e correggere **solo** pesi e liste, mai casi speciali per una frase.
**Verifica:** tutti i casi di `cases.json` verdi, vecchi e nuovi.

### 32.8 — SoundCloud fuori dalla ricerca
**Stop finché l'utente non ha risposto alla domanda 1.** Variante **A (proposta: togliere)**:
**File:** quelli elencati in «Cosa si semplifica» (servizi, `playlist_import_service.dart`, `import_providers.dart`,
`settings_store.dart`, `download_settings_tiles.dart`, `track_matcher.dart`, `youtube_results.dart`/`online_results.dart`,
ARB, test e fixture), `.github/workflows/nightly.yml` (se elenca il test SoundCloud), `docs/02-architettura.md`
(sezione fase 22), `docs/99-rischi-e-fallback.md` (R71: resta solo YouTube)
1. Via il codice di ricerca e di ripiego; `importSoundCloud` ignorato alla lettura; nessun cambio ai dati salvati.
2. Compatibilità: `downloads.json` con chiavi `soundcloud:` si legge, un candidato SoundCloud salvato in un'importazione
   «da verificare» si mostra e si scarica ancora (`webpageUrl`).
**Verifica:** suite verde; test nuovi/aggiornati: `DownloadIndex` con una chiave `soundcloud:`; candidato SoundCloud
salvato che si scarica dal suo `webpageUrl`; importazione con il vecchio `importSoundCloud = true` nelle impostazioni →
nessuna ricerca SoundCloud.
Variante **B (tenerlo solo a richiesta)**: chip «SoundCloud» nei filtri che, toccato, fa una ricerca SoundCloud a parte
(non in «Tutte»), con le stesse regole di confidenza e unione; il resto della fase 22 resta.

### 32.9 — (Facoltativo) Link SoundCloud incollato
**File:** `lib/services/online/youtube_urls.dart` (`isSoundCloudTrackUrl`), `smart_search.dart` (intento url),
`yt_dlp_process_service.dart`/`android_yt_dlp_service.dart` (`resolveLink`: `-J --no-playlist <url>`),
`test/services/online/youtube_urls_test.dart`
1. Un indirizzo `soundcloud.com/<utente>/<brano>` incollato in Online → un risultato solo (titolo, utente, durata;
   anteprima da 30 s → messaggio «È solo un'anteprima»), con Ascolta e Scarica.
**Verifica:** classificazione degli indirizzi (brano, set, profilo, link corto `on.soundcloud.com`); risposta di
yt-dlp letta dalla fixture. Si fa solo con la variante A.

### 32.10 — Test dal vivo, documentazione e prova a mano
1. `test/live/smart_search_live_test.dart` (dietro `CODECORE_LIVE=1`, giro notturno): «pink floyd» → intento
   `artistPage`; «pink floyd mother» → primo «Mother» di Pink Floyd da YouTube Music; «fred again boiler room
   london» → primo un video di oltre 60 minuti; nessuna fonte in errore.
2. ARB it/en/de/es/fr/pt; `docs/02-architettura.md` (sezione «Ricerca intelligente (fase 32)»: confidenza, unione,
   intento, tetto, cache, filtri), `docs/99-rischi-e-fallback.md` (R82–R85), guida utente (due modi, «Altri
   risultati», filtri).
**Tocca a te (Mi A3, Motorola, Linux):** 20 ricerche tue di ogni giorno (artisti, «titolo artista», solo titolo, remix,
live, italiani): il primo risultato è quello che volevi? cosa è finito negli Altri per sbaglio? (annotare per 32.7);
modalità aereo; due ricerche di fila veloci (nessun risultato della prima nella seconda).

## Fuori da questa fase
Suggerimenti mentre si scrive (autocompletamento: una richiesta per tasto), ricerca mista libreria + online in un
elenco solo, risultati di playlist e podcast online nella ricerca, correzione automatica degli errori di battitura,
ricerca vocale, SoundCloud come fonte di serie, imparare dai tocchi dell'utente (personalizzazione del punteggio).

## Rischi (proposti per `99-rischi-e-fallback.md`, da copiare in 32.10)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R82 | Confidenza sbagliata: il brano giusto negli Altri, o prima una versione live/cover/remaster | «Non trova» un brano che c'è | Soglia calibrata (brano esatto fra i Migliori in 34/34), Altri a un tocco, regole di versione nei due sensi, fixture di regressione da ricerche vere (32.7), filtro per fonte per vedere l'elenco di una fonte sola |
| R83 | Due o tre richieste per ricerca: più 429 e più lentezza sui telefoni lenti | «YouTube chiede una pausa» più spesso, prima riga oltre 2 s sul Mi A3 | Richieste solo all'invio, cache di 10 minuti, pausa di 5 minuti per la fonte con 429, annullamento delle vecchie, card con maschera da 0,7 KB; misura 32.1 e piano B (card dopo i brani) |
| R84 | Righe che si spostano mentre arrivano le fonti | Tocco sulla riga sbagliata | Blocco stabile: ciò che è a schermo non cambia posto, i ritardatari si uniscono o vanno in fondo; tetto di 1,5 s |
| R85 | Togliere SoundCloud fa perdere contenuti rari o rompe dati vecchi | Un bootleg che si trovava solo lì; download o revisioni SoundCloud che non si aprono | Misura (0 trovati solo su SoundCloud in 54 ricerche), compatibilità di `MediaSource.soundcloud` e test sui dati vecchi, link SoundCloud incollato (32.9), variante B se l'utente preferisce |

## Domande aperte per l'utente
1. **SoundCloud** (misura sopra: 0 brani in più su 54, 12 volte più lento, 36 s sul Mi A3): lo **togliamo** dalla
   ricerca e dall'importazione (proposta, variante A, con il link incollato facoltativo) o lo teniamo **solo a
   richiesta** con un chip (variante B)?
2. La confidenza **non si mostra** come numero: basta la divisione Migliori / Altri (proposta) o vuoi un'indicazione
   sulla riga (es. «Molto probabile»)?
3. I risultati appaiono **tutti insieme** quando YouTube Music e YouTube hanno risposto (al più 1,5 s dopo il primo,
   proposta), invece di riempirsi un pezzo alla volta: va bene?
4. Chip delle fonti come **filtro** che si azzera a ogni ricerca (proposta) o che resta ricordato?
5. Con una ricerca come «pink floyd» la **card grande** dell'artista in cima e sotto i suoi brani (proposta)?

## Definition of Done
- [ ] Cerca con due modi; Online interroga YouTube Music e YouTube insieme, con la card dell'artista/album/brano
- [ ] Stesso brano in una riga; Migliori sopra la soglia, Altri chiusi; filtri per fonte sui risultati arrivati
- [ ] Intento: artista → card in cima; «titolo artista» → brani; indirizzo → come oggi
- [ ] Ordine stabile con tetto; cache di 10 minuti; 429 per fonte; annullamento delle ricerche vecchie
- [ ] SoundCloud secondo la risposta dell'utente (tolto con compatibilità dei dati, oppure solo a richiesta)
- [ ] Test: confidenza sui casi misurati, unione, card e intento, motore (tetto, ritardatari, 429, cache), interfaccia (Altri, filtri, card)
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Decisioni prese in autonomia (notte del 2026-10-22, obiettivo notturno: l'utente dorme)
- **SoundCloud esce dalla ricerca e dall'importazione (32.8, variante A).** L'utente aveva detto: «se nella ricerca non mi dà nulla di più di youtube music e youtube, si può anche eliminare»; la misura dà 0 brani trovati solo su SoundCloud su 54 e 5,4 s di mediana contro 0,5. I dati vecchi (`MediaSource.soundcloud`, download già fatti) restano leggibili. 32.9 (incollare un link SoundCloud) resta facoltativo: si fa solo se è piccolo.
- Confidenza **non** mostrata sulla riga; i risultati compaiono insieme (tetto 1,5 s), «Altri risultati» chiuso; il filtro della fonte **non** si ricorda; card grande per gli artisti come nella fase 30.
