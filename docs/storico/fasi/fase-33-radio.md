# Fase 33 — Radio: stazioni locali, ricerca e «Le mie radio»

**Obiettivo:** una sezione **Radio** per ascoltare le radio in diretta, prima di tutto quelle **vicine** (paese e
regione scelti dall'utente), cercarle per nome o per genere e **salvarle** in «Le mie radio». Si ascoltano dal
**lettore principale**: notifica, cuffie, schermata di blocco, MPRIS/SMTC, Android Auto, timer; «avanti» e
«indietro» passano alla stazione successiva. Dove la stazione lo manda, si vede il brano **in onda**.
**Prerequisiti:** fase 31.2–31.6 (voci online nella coda: id negativi, `OnlineEntries`, brano sintetico, `loadUri`
nel lettore principale, salvataggio della coda senza voci online), 13 (backup), 25.5 (Android Auto,
`MediaBrowseTree`), 28.5 (`NetThumbnail`), 29.2 (Memoria, `CacheCleaner`), 31.12 (`networkKindProvider`).
**Principio:** dati da **Radio Browser** (API pubblica e aperta, senza chiave), una richiesta per azione
dell'utente, con cache; nessun permesso di posizione; la radio non tocca né cronologia né statistiche. Nessun
pacchetto nuovo. Presente anche nella variante `lite` (non è YouTube).

> Le stazioni sono trasmissioni pubbliche in streaming: si ascoltano, **non si registrano** né si scaricano.

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)
Richieste a Radio Browser con `User-Agent: Codecore/1.0 (uso personale)`; ascolto di prova con `mpv` (lo stesso
motore dell'app su desktop) con uscita nulla. Risposte grezze fuori dal repository (cartella temporanea della sessione
di pianificazione).

| Richiesta | Tempo | Peso | Cosa c'è |
|---|---|---|---|
| DNS `all.api.radio-browser.info` | — | — | **un solo** indirizzo (91.98.4.78 e IPv6) |
| `GET https://all.api.radio-browser.info/json/servers` | 0,61 s | 0,1 KB | **un solo server**: `de1.api.radio-browser.info` (negli anni scorsi erano 3–5). La scoperta resta, ma oggi non dà alternative |
| `/json/stats` | 0,47 s | 0,2 KB | 62.516 stazioni (7.056 «rotte»), 12.729 tag, 241 paesi, server 0.7.45 |
| `/json/countries?hidebroken=true` | 0,32 s | 15 KB | 249 paesi; Italia `IT` = 1.797 stazioni funzionanti |
| `/json/states/Italy/?hidebroken=true&order=stationcount&reverse=true` | 0,22 s | 4 KB | 74 voci **scritte a mano dalle stazioni**: Lombardia 188, Lazio 94, Veneto 71, Sicilia 41, Piemonte 35 … ma anche «Milano» 20, «Roma» 20, «Lombardy» 5, «Emilia Romagna» 6 accanto a «Emilia-Romagna» 33, «Toscana,Firenze,Florence» 4, «Brescia » con lo spazio. `/json/states?country=Italy` **non filtra** (1.000 voci di tutto il mondo) |
| `/json/stations/search?countrycode=IT&state=lombard&hidebroken=true` | 0,62 s | 219 KB | corrispondenza **parziale e senza maiuscole**: 194 stazioni (Lombardia 186, Lombardy 5, «lombardia » 2, «Lombardia/Italy» 1); «Milano» ne ha altre 21 a parte |
| `/json/stations/search?countrycode=IT&hidebroken=true&limit=5000` | 0,87 s | **2,0 MB** | tutto il paese: 1.797 stazioni; **il server non comprime** (anche chiedendo gzip). Solo 841 (47 %) hanno `state` (724 nomi di regione, 117 città o sigle), 223 (12 %) coordinate, 13 `iso_3166_2`. Codec: MP3 1.357 · AAC+ 256 · AAC 121 · OGG 32; 95 HLS; 933 in https; 935 con favicon. ≈ 1,1 KB per stazione |
| `…&geo_lat=45.46&geo_long=9.19&geo_distance=50000` | 0,39 s | 38 KB | 32 stazioni: solo quelle con coordinate (12 %), quindi la distanza da sola non basta |
| `/json/tags?order=stationcount&reverse=true&limit=100` | 0,26 s | 4 KB | «pop» 6.184, «music» 4.939, «news», «rock», «radio» 2.390, «entretenimiento», «méxico», «moi merino»…: tag troppo sporchi per farne l'elenco dei generi |
| `/json/stations/search?tag=jazz&countrycode=IT…` | 0,27 s | 35 KB | 30 stazioni: il filtro per tag è **parziale** (prende anche «smooth jazz», «nu-jazz», «free jazz»; 19 su 30 hanno il tag «jazz» esatto). Per i generi va bene così (`tagExact` resta spento) |
| `/json/url/<stationuuid>` | 0,32 s | 0,2 KB | `{ok, message, stationuuid, name, url}` e conta un **clic** (è la cortesia chiesta da Radio Browser: una chiamata per ascolto) |
| `/json/stations/byuuid?uuids=<a>,<b>` | 0,35 s | — | rilegge più stazioni salvate in una richiesta |
| Ascolto Icecast MP3 (Radio 105, Virgin Radio Classic Rock) | ~1–2 s al suono | 128 kbps | `icy-title` presente ma in un formato dell'editore con `~`: «HUGEL & DAVID GUETTA ft. …~SHINE~Twenty One~2026~…» e «Don't Let Me Down~The Beatles~~1969~…» (**ordine artista/titolo diverso** fra due stazioni dello stesso gruppo) |
| Ascolto Icecast AAC (R101) · Shoutcast `;` (Radio Maria) | — | 95 / 128 kbps | `icy-title` vuoto · uguale al nome della stazione |
| Ascolto HLS (Radio Deejay, Radio Italia) | — | 122 kbps | nessun `icy-title` |
| `just_audio` 0.10.6 (Android) | — | — | `icyMetadataStream` dagli `IcyInfo` di ExoPlayer |
| `just_audio_media_kit` 2.1.0 (desktop) | — | — | `icyMetadata: null` **sempre** (`mediakit_player.dart`, riga 219): su desktop niente «in onda» senza modificarlo. `media_kit` 1.2.6 ha `NativePlayer.observeProperty`; mpv espone `metadata/by-key/icy-title` |
| `AndroidManifest.xml` | — | — | `usesCleartextTraffic="true"` c'è già (Jam): gli stream `http://` si aprono |

Consumo: MP3 128 kbps ≈ **0,96 MB/min ≈ 58 MB/h**; AAC+ 64 kbps ≈ 29 MB/h; 320 kbps ≈ 144 MB/h.

## Decisioni
| Tema | Scelta |
|---|---|
| Dove sta | **Proposta:** voce fissa **«Radio»** nella Libreria (accanto a «Podcast», stessa forma) → `RadioScreen`; riga **«Le tue radio»** in Home (solo se ne hai salvate, tocco = ascolto); cartella **«Radio»** in Android Auto. Niente quinta scheda (la barra ne ha già quattro). L'utente decide (domande aperte) |
| Fonte | Radio Browser. Server: `GET https://all.api.radio-browser.info/json/servers`, uno a caso fra quelli elencati, ricordato per la sessione; su errore di rete o 5xx il successivo, poi `de1.api.radio-browser.info` fisso. `User-Agent` = `apiUserAgent`, timeout delle regole (8/15 s). `hidebroken=true` sempre |
| Cortesia (etiquette) | `/json/url/<uuid>` a ogni **avvio** dell'ascolto di una stazione di Radio Browser (non a ogni ripresa dopo pausa, non per le stazioni aggiunte a mano), senza aspettarne la risposta; niente voti automatici; richieste in serie, al più 1 al secondo; cache |
| «Vicino a te» | **Paese + regione scelti dall'utente** (nessuna posizione): paese predefinito dal locale del sistema (`it_IT` → IT), regione chiesta al primo ingresso con un foglio (si cambia dal chip in cima). Elenco del paese scaricato **una volta** (`countrycode=<CC>&hidebroken=true&order=clickcount&reverse=true&limit=3000`, ≈ 2 MB per l'Italia), tenuto 7 giorni in `<appSupport>/radio/country_<CC>.json` e filtrato in locale in un isolate. Regione = `state` che contiene (senza maiuscole, diacritici, spazi) il nome della regione in italiano o in inglese o di un suo **capoluogo di provincia** (tabella nostra: 20 regioni, 107 capoluoghi). Per gli altri paesi: le voci di `/json/states/<Paese>/` con ≥ 3 stazioni, così come sono. Sotto la regione, **«In tutta Italia»** (le più ascoltate del paese, comprese le 956 senza regione) |
| Doppioni | Stessa stazione registrata più volte (Radio Deejay compare 2 volte con indirizzi diversi): uno solo per `matchKey(nome)`, tenendo quello con `lastcheckok`, poi https, poi più clic |
| Ricerca | `stations/search?name=<q>&hidebroken=true&order=clickcount&reverse=true&limit=50`, interruttore «Solo <paese>» (spento di serie); almeno 2 caratteri, debounce 400 ms, risposte in memoria 10 minuti |
| Generi | **Elenco nostro** di 24 generi con il tag di Radio Browser (pop, rock, classic rock, jazz, blues, classical, dance, electronic, house, hip hop, lo-fi, chillout, 60s, 70s, 80s, 90s, oldies, metal, reggae, latin, soul, news, talk, sports) → `tag=<tag>`, con il paese se «Solo <paese>» è acceso; nomi tradotti dagli ARB |
| Le mie radio | Tabella nuova **`radio_stations`** (schema **v12**): `station_id` (pk: `stationuuid`, o `manual:<uuid>` per un indirizzo aggiunto a mano), `name`, `stream_url`, `homepage`, `favicon_url`, `country_code`, `state`, `tags`, `codec`, `bitrate`, `hls`, `position` (ordine scelto), `added_at`, `last_played_at`, `last_ok_at`. Riordino a trascinamento, rinomina, rimuovi. Rilette con `byuuid` al più una volta al giorno, all'apertura della pagina (indirizzo cambiato → aggiornato; stazione non più in Radio Browser o rotta → segno «non risponde», **mai cancellata**) |
| Backup | Ripristino completo: già incluso (copia del DB). Formato portabile `user_data.json`: campo nuovo `radios` (il `format` resta 1: i campi sconosciuti si ignorano già), unione per `station_id` (per le manuali, per indirizzo) |
| Riproduzione | **Lettore principale** con le voci online della fase 31: una stazione è una `OnlineEntry` di tipo `radio` (id negativo, `Track` sintetico con `path 'online:radio:<id>'`, `durationMs 0`). `PlayerController.playStations(list, index)`: la coda è l'elenco da cui si è partiti (Le mie radio, Vicino a te, un genere, i risultati), così «avanti/indietro» anche da cuffie, notifica e auto cambiano stazione. Durante la radio: niente casuale, ripeti, Shuffle+, senza pause/dissolvenza (passaggio normale), velocità (si torna a 1× e poi a quella di prima), segnalibro, ReplayGain, cronologia, statistiche, arricchimento. «In riproduzione da: Radio» (`PlayContextKind.radio`) |
| Diretta | `MediaItem.duration` nullo e niente `MediaAction.seek`: la notifica e la schermata di blocco non mostrano la barra; «In riproduzione» e il mini-player mostrano «In diretta» al posto del tempo. Pausa = pausa (alla ripresa si riparte dal vivo: `loadUri` di nuovo se la pausa è durata più di 30 s, perché lo stream nel frattempo si è chiuso) |
| «In onda» | Android: `icyMetadataStream` di just_audio. **Desktop: niente in questa fase** (just_audio_media_kit dà sempre null; task facoltativo 33.11). `AudioBackend.streamTitle` (stream, null dove non c'è). Pulizia (`cleanIcyTitle`, pura): vuoto o uguale al nome della stazione → nulla; con `~` → i primi due campi non vuoti uniti da « · » (l'ordine artista/titolo non si indovina); «Artista - Titolo» resta. In notifica: `title` = in onda (o il nome), `artist` = nome della stazione. Pulsante «Cerca questo brano» (apre Cerca → Online con il testo, fase 32) |
| Errori | Lo stream cade (errore del backend o fine inattesa): **3 nuovi tentativi** dopo 2, 5 e 15 s, poi «La radio non risponde» e stop (nessun salto automatico a un'altra stazione: sarebbe una sorpresa). Senza rete: messaggio e nessun tentativo finché la rete non torna |
| Dati | Ogni riga mostra codec e bitrate e, nel foglio della stazione, «≈ 58 MB all'ora»; la prima volta su rete a consumo (`networkKindProvider`, 31.12) un avviso «La radio usa circa 1 MB al minuto». Nessun limite automatico |
| Jam | Avviare una Jam ferma la radio (come oggi la musica locale); la radio non entra nella coda della Jam |
| Pacchetti nuovi | Nessuno. Solo il task facoltativo 33.11 usa una **copia locale** di `just_audio_media_kit` (come `metadata_god` in `third_party/`): da approvare |

## Task

### 33.1 — Verifiche preliminari e fixture
Gli esiti dal PC sono nella tabella «Misure dal vivo». Restano:
1. Fixture ridotte in `test/fixtures/radio/`: `servers.json`, `countries.json` (10 paesi), `states_italy.json`
   (le 74 voci vere: servono al filtro delle regioni), `stations_it.json` (60 stazioni italiane scelte per coprire:
   con e senza `state`, città al posto della regione, doppioni di Radio Deejay, HLS, https e http, senza favicon),
   `search_rtl.json`, `tag_jazz_it.json`, `byuuid.json` (2 stazioni), `url_click.json`.
2. **Motorola edge 40 (Wi‑Fi e LTE) e Mi A3:** con lo script di prova (fuori da `lib/`, non committato) far suonare
   con just_audio un MP3 `http://` (Radio 105), un HLS AAC `https://` (Radio Deejay) e un AAC+ Icecast (R101):
   tempo al primo suono; `icyMetadataStream` per Radio 105 e Virgin Rock Classics (arriva? ogni quanto?); cosa
   succede passando da Wi‑Fi a LTE a metà (errore? riprende da solo?).
3. Una stazione con favicon molto pesante: annotare il peso (le favicon arrivano da siti delle stazioni, non da un CDN).
**Verifica:** fixture nel repository, note in PROGRESS. **Stop** se ExoPlayer non apre gli stream `http://` o gli HLS
delle radio: riportare prima di scrivere codice.

### 33.2 — Modello e client di Radio Browser
**File:** `lib/services/radio/radio_station.dart`, `lib/services/radio/radio_browser_client.dart`,
`test/services/radio/radio_browser_client_test.dart`
1. `RadioStation` immutabile (`id`, `name`, `streamUrl`, `homepage`, `faviconUrl`, `countryCode`, `state`, `tags`
   (lista), `codec`, `bitrate`, `hls`, `clickCount`, `lastCheckOk`), `fromApi(Map)` (difensivo: campi mancanti →
   vuoti; senza `url_resolved` usa `url`; senza nessuno dei due → null), `toJson`/`fromJson` per la cache.
2. `RadioBrowserClient(Dio)`: `servers()`, `countries()`, `states(countryName)`, `byCountry(cc, {limit})`,
   `search({name, countryCode, tag, limit})`, `byUuids(ids)`, `click(id)`. Scelta del server e ripiego come in
   Decisioni; 429/503 → `RadioUnavailable(retryAfter)`; rete → `RadioOffline`; risposta non JSON → `RadioChanged`.
**Verifica (adattatore Dio finto come `innertube_client_test.dart`):** lettura delle fixture; server che non risponde
→ il successivo; `/json/servers` irraggiungibile → `de1` fisso; 429 → `RadioUnavailable`; `User-Agent` e
`hidebroken=true` in ogni richiesta; stazione senza indirizzo scartata.

### 33.3 — Regioni, doppioni e «Vicino a te» (logica pura)
**File:** `lib/services/radio/regions.dart` (tabella dell'Italia), `lib/services/radio/near_you.dart`,
`test/services/radio/near_you_test.dart`
1. `RadioRegion {id, names (it, en, varianti: «Emilia Romagna», «Trentino-Alto Adige/Südtirol», «Friuli-Venezia
   Giulia», «Valle d'Aosta»/«Aosta Valley»…), cities (capoluoghi)}` per le 20 regioni; `regionsFor(cc, states)`:
   tabella per `IT`, per gli altri paesi le `states` dell'API con ≥ 3 stazioni.
2. `matchesRegion(station, region)` (`matchKey` del campo `state`, contiene un nome o una città come parola);
   `dedupe(stations)` (regola in Decisioni); `nearYou(stations, region)` ordinate per clic.
**Verifica:** su `states_italy.json` e `stations_it.json`: «Lombardia» prende Lombardia, Lombardy, «lombardia »,
«Lombardia/Italy», Milano, «Milano (MI)», Brescia; «Emilia-Romagna» prende anche «Emilia Romagna» e Bologna; nessuna
stazione del Lazio in Lombardia; Radio Deejay una volta sola; paese estero → le sue voci con ≥ 3 stazioni.

### 33.4 — Elenco del paese, cache e voce in Memoria
**File:** `lib/services/radio/radio_catalog.dart`, `lib/providers/radio_providers.dart`,
`lib/services/memory/app_data.dart` (voce «Radio (elenco stazioni)» in `AppDataPaths` e `CacheCleaner`),
`lib/data/settings/settings_store.dart`, `test/services/radio/radio_catalog_test.dart`, `test/data/settings_store_test.dart`
1. `RadioCatalog(client, dir, {now})`: `country(cc)` → file `country_<CC>.json` fresco (7 giorni) o nuovo download;
   lettura e filtro in `Isolate.run`; errore di rete con copia vecchia → la copia con `stale: true`; ricerche e generi
   in memoria per 10 minuti (LRU 30).
2. Provider: `radioCatalogProvider`, `nearYouProvider` (paese+regione dalle impostazioni), `radioSearchProvider`,
   `radioGenreProvider` (`FutureProvider.autoDispose.family`, `retry: (_, _) => null`).
3. Impostazioni: `radioCountry`, `radioRegion` (null = da chiedere), `radioOnlyCountry`.
**Verifica:** seconda apertura senza rete dalla copia; copia scaduta + rete assente → `stale`; ricerca uguale entro
10 minuti senza richiesta; «Svuota cache» cancella solo la cartella `radio/` (non le stazioni salvate).

### 33.5 — Schema v12, «Le mie radio» e backup
**File:** `lib/data/db/tables.dart` (`RadioStations`), `app_database.dart` (v12), `lib/data/repositories/radio_repository.dart`,
`lib/services/backup/user_data.dart` (`radios`), `lib/data/repositories/backup_merge.dart`, `backup_queries.dart`,
`test/data/migration_test.dart`, `test/data/radio_repository_test.dart`, `test/data/backup_merge_test.dart`
1. Tabella e migrazione (`createTable`, nulla di esistente toccato); `dart run build_runner build`.
2. `RadioRepository`: `watchAll()` (per `position`), `save(station)` (in fondo), `remove(id)`, `reorder(ids)`,
   `rename(id, name)`, `touchPlayed(id)`, `applyRefresh(List<RadioStation>, missingIds)` (aggiorna indirizzo e campi,
   segna `last_ok_at`; mai cancellare).
3. Backup: `UserData.radios` (lista, assente nei backup vecchi = vuota), esportazione e unione senza doppioni.
**Verifica:** un DB v11 diventa v12 e tiene brani e playlist; salva/riordina/rinomina/rimuovi; `applyRefresh` cambia
l'indirizzo e non cancella una stazione sparita; backup → unione su un DB vuoto → stesse stazioni nello stesso ordine;
un `user_data.json` senza `radios` si legge ancora.

### 33.6 — La radio nel lettore principale
**File:** `lib/services/audio/online_entries.dart` (tipo `radio`), `lib/services/audio/codecore_audio_handler.dart`,
`lib/services/audio/audio_backend.dart` (`streamTitle`), `just_audio_backend.dart`, `crossfade_engine.dart`
(passante), `lib/services/radio/icy_title.dart` (puro), `lib/providers/player_providers.dart` (`playStations`,
`PlayContextKind.radio`), `lib/main.dart` (cablaggio del clic), `lib/ui/shell/app_shell.dart` (solo il messaggio del
nuovo motivo: vedi «File condivisi» della fase 31), ARB, `test/services/radio/icy_title_test.dart`,
`test/services/audio/radio_playback_test.dart`
1. `OnlineEntries.registerRadio(station) → int` e `trackOf` per le radio; `isRadioId(id)`.
2. Handler: `_loadCurrent` per una radio → `onRadioStart(station)` (il clic, senza attendere) → `loadUri(streamUrl)`;
   velocità a 1× finché suona una radio; `playbackState` senza `seek` e `MediaItem.duration` nullo; casuale e ripeti
   ignorati in una coda di sole radio; nuovi tentativi 2/5/15 s poi `PlaybackFailureReason.radioUnavailable` e stop;
   ripresa dopo una pausa di oltre 30 s = nuovo `loadUri`.
3. `AudioBackend.streamTitle` (`Stream<String?>`): `JustAudioBackend` da `icyMetadataStream` (`info?.title`),
   `CrossfadeEngine` da quello attivo, gli altri nulla. L'handler aggiorna `mediaItem` con `cleanIcyTitle`.
4. `cleanIcyTitle(raw, stationName)` (regole in Decisioni).
**Verifica (backend finto):** una radio suona con `loadUri` del suo indirizzo e chiama il clic una volta; «avanti»
passa alla stazione dopo; nessuna riga in `plays` né `play_count` cambiato; errore del backend → 3 tentativi alle
attese giuste (orologio finto) poi stop con il motivo; il titolo ICY aggiorna `mediaItem`; la velocità torna quella di
prima quando riparte un brano della libreria; `cleanIcyTitle` con i quattro casi misurati (`~` in due ordini, vuoto,
uguale al nome) e «Artista - Titolo».

### 33.7 — Pagina Radio
**File:** `lib/ui/screens/radio/radio_screen.dart`, `radio_sections.dart` (sezioni come widget piccoli),
`radio_station_row.dart`, `radio_region_sheet.dart`, `radio_station_sheet.dart` (dettagli: codec, bitrate,
≈ MB/h, sito, salva/rimuovi), `lib/ui/screens/library/library_screen.dart` (voce fissa «Radio»), ARB
1. In ordine: campo di ricerca; **Le mie radio** (riordinabili, nascosta se vuota); **Vicino a te** (chip «Lombardia ▾»
   → foglio della regione; al primo ingresso il foglio si apre da solo); **Generi** (chip); **In tutta Italia**.
   Elenchi con `ListView.builder`/`itemExtent`, favicon con `NetThumbnail` (segnaposto con l'iniziale se manca o non
   si carica). Tocco = ascolto con l'elenco della sezione come coda; stella = salva/rimuovi.
2. Stati: caricamento, «Non in linea · elenco del <data>» con la copia, errore con «Riprova», nessun risultato.
**Verifica:** `flutter analyze`; widget test minimo solo per la logica visibile (primo ingresso senza regione → foglio
aperto; con regione → sezione «Vicino a te»).
**Telefono (Mi A3):** apertura della pagina con l'elenco già in cache < 1 s, scorrimento fluido, favicon leggere.

### 33.8 — «In riproduzione», mini-player e notifica per la radio
**File:** `lib/ui/screens/now_playing/now_playing_screen.dart`, `now_playing_cards.dart`,
`lib/ui/widgets/mini_player.dart`, `lib/ui/widgets/track_art.dart` (della 31.11: favicon per le radio),
`lib/ui/shell/desktop_player_bar.dart` (vedi «File condivisi» della fase 31), ARB
1. Con una radio: copertina = favicon (grande, sfondo dal colore della favicon), titolo = in onda o nome, sotto il nome
   della stazione; al posto della barra «● In diretta»; niente testi, curiosità, casuale, ripeti, velocità; azioni:
   salva/rimuovi da «Le mie radio», «Cerca questo brano» (solo con un titolo in onda), sito della stazione.
2. Menu del brano per una radio: solo salva/rimuovi, Cerca questo brano, Rimuovi dalla coda.
**Verifica:** `flutter analyze`; widget test: con una radio niente barra di avanzamento e c'è «In diretta».
**Telefono (Motorola):** notifica e schermata di blocco con nome, titolo in onda (Radio 105) e senza barra; tasti
delle cuffie avanti/indietro cambiano stazione; timer «30 minuti» ferma la radio.

### 33.9 — Home e Android Auto
**File:** `lib/ui/screens/home/home_screen.dart` (riga «Le tue radio»), `lib/services/audio/media_browse_tree.dart`
(cartella `radio`, voci `radio:<id>`, `resolve` per una radio), `BrowseLabels` (nome della cartella nelle 6 lingue),
`test/services/audio/media_browse_tree_test.dart`
1. Home: scaffale orizzontale con le stazioni salvate (favicon tonda, nome), solo se ce ne sono.
2. Android Auto: in `root` la cartella «Radio» (solo con stazioni salvate), voci riproducibili; scegliendone una suona
   con le salvate come coda (`resolve` restituisce le stazioni, l'handler chiama `playStations`).
**Verifica:** albero con 0 stazioni → niente cartella; con 3 → cartella e 3 voci; `resolve('radio:<id>')` → le 3 nella
coda, partendo da quella scelta; gli id `track:` restano come prima.
**Telefono:** Android Auto (DHU sul PC o in auto): cartella Radio, ascolto, avanti/indietro.

### 33.10 — Aggiungere un indirizzo a mano
**File:** `lib/services/radio/stream_link.dart` (puro), `lib/ui/screens/radio/add_station_dialog.dart`,
`test/services/radio/stream_link_test.dart`
1. Dialogo «Aggiungi indirizzo» (nome + indirizzo); `parseStreamLink(text)`: http/https; per un `.pls` o `.m3u` si
   scarica il file (≤ 64 KB) e si prende il primo indirizzo http(s); altro → errore spiegato. Prova di 10 s prima di
   salvare (si sente o no).
**Verifica:** indirizzo diretto, `.pls` con `File1=`, `.m3u` con commenti, testo non valido, `.pls` senza voci.

### 33.11 — (Facoltativo, da approvare) «In onda» anche su desktop
**File:** `third_party/just_audio_media_kit/` (copia di 2.1.0 con una patch in `docs/patches/`), `pubspec.yaml`
(`path:`), `docs/patches/just_audio_media_kit-icy.patch`
1. In `MediaKitPlayer`: `observeProperty('metadata/by-key/icy-title')` del `NativePlayer` e il valore in
   `icyMetadata` dell'evento (oggi sempre null). Nessun altro cambiamento.
2. Prova su Linux con Radio 105 e Virgin Rock Classics (titolo che cambia a fine brano).
**Verifica:** test esistenti verdi; prova a mano su Linux. **Si salta** se l'utente non approva la copia locale: su
desktop resta il nome della stazione.

### 33.12 — Test dal vivo, documentazione e prova a mano
1. `test/live/radio_browser_live_test.dart` (dietro `CODECORE_LIVE=1`, giro notturno): `/json/servers` non vuoto;
   Italia con ≥ 500 stazioni; ricerca «rtl 102.5» con almeno un risultato; `byuuid` di una stazione nota.
2. ARB it/en/de/es/fr/pt (nomi dei generi compresi); `docs/02-architettura.md` (sezione «Radio (fase 33)»: fonte e
   server, elenco del paese e regioni, tabella v12, voce online di tipo radio, ICY), `docs/03-modello-dati.md`
   (tabella `radio_stations`), `docs/99-rischi-e-fallback.md` (R86–R90), guida utente.
**Tocca a te (Linux, Mi A3, Motorola):** scegliere la regione e trovare le radio locali che ascolti davvero (quali
mancano?); salvarne 3 e riordinarle; ascolto con schermo spento 30 minuti; avanti/indietro dalle cuffie; titolo in onda
su una radio del gruppo Mediaset (Radio 105, Virgin); modalità aereo a metà (messaggio, nessun blocco); Wi‑Fi → LTE;
Android Auto; consumo di dati dopo un'ora (Impostazioni di Android) da confrontare con ≈ 58 MB/h.

## Fuori da questa fase
Registrare la radio o scaricarne pezzi, sveglia con la radio, podcast delle radio (ci sono già i podcast), votare le
stazioni su Radio Browser, aggiungere stazioni a Radio Browser, posizione GPS, radio nella Jam, «in onda» dagli HLS
(metadati ID3 temporizzati), riconoscere il brano in onda dall'audio, cronologia delle radio ascoltate, radio nel
widget e nella tile oltre a quello che dà la sessione media.

## Rischi (proposti per `99-rischi-e-fallback.md`, da copiare in 33.12)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R86 | Radio Browser lento o fermo: oggi c'è **un solo server** (`de1`) | Pagina Radio vuota o «non in linea» | Copia del paese per 7 giorni e stazioni salvate nel DB (si ascoltano anche senza Radio Browser: l'indirizzo è salvato); `/json/servers` a ogni avvio della sessione, poi `de1` fisso; nessun nuovo tentativo a raffica; test notturno |
| R87 | Stream che non suonano su un motore (codec, HLS, certificati, `http`), o che cadono cambiando rete | Silenzio, «La radio non risponde» | `hidebroken=true`, 3 tentativi a 2/5/15 s, messaggio chiaro, stazione segnata «non risponde» solo nella riga (niente cancellazioni); verifiche 33.1 su ExoPlayer e mpv |
| R88 | Consumo di dati (≈ 58 MB/h a 128 kbps) | Bolletta o soglia del telefono raggiunte | Bitrate e MB/h visibili, avviso alla prima radio su rete a consumo; nessun ascolto che parte da solo |
| R89 | Le voci online di tipo radio finiscono in codice che si aspetta un brano (estende R77) | Preferito, cronologia, seek, Jam o salvataggio della coda che falliscono | Stesse protezioni della fase 31 (`isOnlineId`), azioni ridotte, `systemActions` senza seek, test sul lettore con un repository che fallisce sugli id negativi |
| R90 | Dati delle stazioni scritti a mano (regioni sporche, favicon pesanti o rotte, nomi doppi) | Radio della regione mancanti, immagini lente | Tabella delle regioni con varianti e capoluoghi, «In tutta Italia» sotto, doppioni tolti, favicon decodificate alla misura mostrata con segnaposto |

## Domande aperte per l'utente
1. **Dove** mettere la Radio: voce nella **Libreria** + riga in **Home** (proposta), oppure una **quinta scheda** in basso?
2. «Vicino a te»: va bene scegliere a mano **paese e regione** (niente permesso di posizione)? La regione basta o vuoi
   anche la **città** (tante stazioni non la indicano: il 53 % non ha neanche la regione)?
3. Tasti avanti/indietro con la radio: passano alla **stazione successiva** dell'elenco da cui sei partito (proposta)?
4. Su desktop il **titolo in onda** richiede una copia modificata di `just_audio_media_kit` (33.11): la facciamo?
5. Un avviso la prima volta che ascolti una radio su **rete mobile** (proposta) o nessun avviso?

## Definition of Done
- [ ] Pagina Radio con Le mie radio, Vicino a te (paese e regione scelti), generi, ricerca e «In tutta Italia»
- [ ] Stazioni salvate nel DB (v12), riordinabili, nel backup; ascolto anche senza Radio Browser
- [ ] Ascolto dal lettore principale: notifica senza barra, cuffie, Android Auto, timer; avanti/indietro = stazioni
- [ ] Titolo in onda su Android (e su desktop se approvato 33.11); nessuna riga in cronologia o statistiche
- [ ] Test: client e server di ripiego, regioni e doppioni, cache del paese, migrazione e repository, backup, lettore con la radio, ICY, albero di Android Auto, indirizzi a mano
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Decisioni prese in autonomia (notte del 2026-10-22, obiettivo notturno: l'utente dorme)
- Posizione: **voce in Libreria + riga in Home** (niente quinta scheda). «Vicino a te» per paese e **regione** (niente città). «Avanti/indietro» = stazione successiva/precedente dell'elenco da cui è partita. Avviso una tantum sulla rete mobile.
- **33.11 (copia modificata di `just_audio_media_kit` per «In onda» su desktop) non si fa**: richiede l'approvazione dell'utente → in «Tocca a te».
