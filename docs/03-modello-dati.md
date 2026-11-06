# Modello dati (drift / SQLite)

Versione schema iniziale: **1**. Ogni modifica futura = `schemaVersion++` + migrazione scritta
in `onUpgrade` (mai distruttiva). Esporta lo schema con `drift_dev schema dump` se vuoi test di migrazione.

## Tabelle

### `tracks`
| Colonna | Tipo | Note |
|---|---|---|
| `id` | int PK autoincrement | identità interna |
| `path` | text UNIQUE | percorso assoluto sul dispositivo |
| `folderId` | int? | FK logica a `folders.id` (cartella radice di provenienza) |
| `title` | text | mai vuoto: fallback nome file senza estensione |
| `artist` | text? | null se ignoto |
| `albumArtist` | text? | |
| `album` | text? | null se ignoto |
| `albumKey` | text | vedi sotto; indicizzata |
| `trackNumber` | int? | |
| `discNumber` | int? | |
| `year` | int? | |
| `genre` | text? | |
| `durationMs` | int | 0 se ignota |
| `format` | text | estensione minuscola: `mp3`, `flac`, … |
| `sampleRateHz` | int? | |
| `bitDepth` | int? | |
| `bitrateKbps` | int? | |
| `channels` | int? | |
| `sizeBytes` | int | |
| `mtimeMs` | int | per scansione incrementale |
| `hasCover` | bool | default false |
| `coverKey` | text? | nome file della copertina in cache (senza estensione) |
| `isFavorite` | bool | default false |
| `lyricsPlain` | text? | |
| `lyricsSynced` | text? | testo LRC grezzo |
| `curiosities` | text? | curiosità **sul brano** (pagina Wikipedia del brano, mai quella dell'artista): testo, a capo, indirizzo della pagina |
| `enrichStatus` | int | 0 mai tentato, 1 trovato, 2 non trovato |
| `userEdited` | bool | default false: se true l'arricchimento **non** sovrascrive titolo/artista/album |
| `missing` | bool | default false: file non trovato all'ultima scansione |
| `ignored` | bool | default false (schema v8): doppione unito e **nascosto** dalla pulizia. Sparisce da brani, album, artisti, generi, ricerca, playlist, cronologia e abbinamenti. A differenza di `missing`, la scansione **non lo riattiva**: solo «Brani nascosti → Ripristina» |
| `kind` | int | default 0 (schema v9): **0 musica · 1 episodio di podcast scaricato**. Ogni vista musicale (brani, album, artisti, generi, ricerca, Home, playlist, abbinamenti) filtra `kind = 0`; gli episodi non compaiono mai in libreria. Indice `tracks_kind` |
| `sha256` | text? | calcolato solo su richiesta (fase 21): per i brani con la **stessa dimensione** di un altro, a flusso in un isolate; azzerato dalla scansione se dimensione o data del file cambiano |
| `addedAt` | int | epoch ms |
| `playCount` | int | default 0 |
| `lastPlayedAt` | int? | |
| `resumePositionMs` | int? | «riprendi da qui»: dove si è lasciato un brano ≥ 20 min (schema v6) |

Indici: `albumKey`, `artist`, `isFavorite`, `(missing)`, `title COLLATE NOCASE`.

### `folders`
`id` int PK · `path` text UNIQUE · `addedAt` int · `label` text?

### `playlists`
`id` int PK · `name` text · `createdAt` int · `coverKey` text? · `uuid` text (**schema v10**: identità della playlist tra dispositivi, v4 casuale, **indice unico** `playlists_uuid`; nullable solo perché la migrazione aggiunge la colonna prima di riempirla, ogni riga nuova ne riceve una) · `updatedAt` int (**schema v10**: epoch ms dell'ultima modifica di nome, copertina, brani o ordine; parte da `createdAt`; è quello che confronta «vince l'ultima modifica» nella sincronizzazione). Ogni scrittura di `PlaylistRepository` (e l'unione dei doppioni) lo aggiorna nella stessa transazione.

### `playlist_tracks`
`playlistId` int · `trackId` int · `position` int · PK(`playlistId`,`trackId`) ·
ON DELETE CASCADE su entrambe (drift: `references(..., onDelete: KeyAction.cascade)`).
Indice su `trackId`.

> Un brano non può comparire due volte nella stessa playlist (scelta voluta, come nella versione Python).

## Libreria intelligente (schema v7, fase 20)
La cronologia, le playlist intelligenti e le etichette sono **dati dell'utente**: nessuna funzione li cancella da sola.

### `plays`
`id` int PK · `trackId` int (CASCADE sul brano) · `playedAt` int (epoch ms) · `msPlayed` int default 0 (tempo **realmente suonato**: i salti di posizione non contano, a 2× conta metà) · `context` int? (`PlayContextKind.index`) · `contextName` text?
Indici: `plays_at(playedAt)` e `plays_track(trackId, playedAt, msPlayed)` — il secondo è **coprente**: un ricapitolo annuale raggruppa per brano leggendo solo l'indice. La cronologia parte vuota (`playCount`/`lastPlayedAt` restano per la Home). La Jam non scrive qui.

### `smart_playlists`
`id` int PK · `name` text · `rules` text (nel linguaggio di ricerca, salvato in forma canonica) · `sort` text? (nome di `SmartSort`; null = predefinito) · `limitCount` int? · `createdAt` int. Nessuna riga in `playlist_tracks`: l'elenco si calcola dal vivo.

### `user_tags` e `track_tags`
`user_tags`: `id` int PK · `name` text UNIQUE **COLLATE NOCASE** · `color` int? (indice di uno degli 8 accenti). `track_tags`: `trackId` + `tagId`, PK insieme, CASCADE su entrambi (togliere un brano o un'etichetta toglie solo i collegamenti).

## Pulizia della libreria (schema v8, fase 21)
Nessuna tabella nuova: una colonna, `tracks.ignored` (vedi sopra). Unire due doppioni (`DuplicateRepository.merge`, una transazione) sposta sul brano tenuto: preferito (se uno lo era), `playCount` (somma), `lastPlayedAt` (massimo), testi/curiosità/copertina/modifiche dell'utente (solo dove il tenuto non ha i suoi), la sua posizione nelle playlist (il primo del gruppo cede il posto, nessun doppione), `plays`, `track_tags` e `playlist_import_items.track_id`; poi nasconde gli altri. **Nessuna riga di `tracks` viene cancellata** dall'unione (servono a «Ripristina»); si cancellano solo, dopo doppia conferma, i file scelti dall'utente e le loro righe. Le coppie «Non sono duplicati» stanno in `SettingsStore` (`notDuplicates`, chiavi dei gruppi), non nel DB.

## Podcast (schema v9, fase 23)
Una colonna su `tracks` (`kind`, vedi sopra) e due tabelle; la migrazione non cancella nulla e ogni brano esistente resta musica (`kind = 0`).

### `podcasts`
`id` int PK · `feedUrl` text **UNIQUE** · `title` text · `author` text? · `imageUrl` text? (da dove viene la copertina) · `coverKey` text? (nome del file nella cartella delle copertine) · `language` text? · `lastCheckedAt` int? (epoch ms dell'ultimo aggiornamento riuscito; null = mai) · `autoDeleteDays` int? (cancella gli episodi ascoltati dopo N giorni; null = mai) · `addedAt` int.

### `podcast_episodes`
`id` int PK · `podcastId` int (**CASCADE**: togliere un podcast toglie i suoi episodi) · `guid` text (o l'`enclosure@url` se il feed non ne ha) · `title` text · `publishedAt` int? · `durationMs` int? · `audioUrl` text · `mimeType` text? · `sizeBytes` int? · `description` text? (testo semplice) · `trackId` int? (**SET NULL** verso `tracks`: se la riga del brano sparisce l'episodio resta in elenco come «non scaricato») · `played` bool default false · `playedAt` int?. **UNIQUE (`podcastId`, `guid`)**: un aggiornamento non duplica mai un episodio. Indice `(podcastId, publishedAt)` per l'elenco in ordine di data.
Un episodio **scaricato** ha una riga in `tracks` con `kind = 1`, `folderId = null` e il file in `<appSupportDir>/podcasts/<podcastId>/`, cartella che non è in `folders` e quindi la scansione non vede.

## Curiosità sull'artista (schema v11)
`artist_infos`: `artistKey` text **PK** (`matchKey` dell'artista principale: «Queen feat. X» e «queen» sono lo stesso) · `body` text · `sourceUrl` text · `lang` text · `fetchedAt` int (epoch ms). Una riga per artista, non per brano: tutti i brani dello stesso artista la mostrano senza altre richieste. È una cache: non entra nei dati utente portabili del backup (il file `.sqlite` del backup però la contiene).

## Radio (schema v12, fase 33)
Una tabella nuova, nessuna esistente toccata.

### `radio_stations`
`stationId` text **PK** (`stationuuid` di Radio Browser, oppure `manual:<uuid>` per un indirizzo scritto a mano) · `name` text · `streamUrl` text · `homepage`, `faviconUrl`, `countryCode`, `state` text default `''` · `tags` text (separati da virgola) · `codec` text · `bitrate` int · `hls` bool · `position` int (l'ordine scelto, 0 = prima) · `addedAt` int · `lastPlayedAt` int? · `lastOkAt` int? (l'ultima rilettura che l'ha trovata funzionante) · `unreachable` bool default false (l'ultima rilettura non l'ha trovata o la dà rotta: «non risponde» nella riga, **la riga non si cancella mai**). Le liste di stazioni di Radio Browser (paese, ricerche) **non** sono nel DB: file `<appSupport>/radio/country_<CC>.json`, una cache. Entra nei dati utente portabili del backup (`user_data.json`, campo `radios`).

## Nuove uscite (schema v13, fase 34)
Tre tabelle nuove, nessuna esistente toccata (il passaggio v12 → v13 è un `createTable` per ciascuna).

### `followed_artists`
`ytm_id` text **PK** (`UC…`, il `browseId` della pagina artista di YouTube Music) · `name` text · `thumb_url` text? · `origin` int (0 seguito a mano · 1 automatico, tra i più ascoltati) · `excluded` bool default false (un automatico che l'utente non segue più: la riga resta perché non torni) · `muted` bool default false (campanella: niente notifica, la novità compare in Home) · `followed_at` int · `last_checked_at` int? (nullo = primo controllo ancora da fare: segna tutto come già visto) · `last_error` text? · `checks_failed` int default 0 (giri di fila con «artista non trovato»; ≥ 3 = «Non trovato», non si controlla più finché non si tocca «Riprova»). Entra nei dati utente portabili del backup (`followedArtists`: id, nome, origine, esclusi, silenziati).

### `artist_releases`
`browse_id` text **PK** (`MPREb_…`) · `artist_id` text → `followed_artists` (cascade) · `title` text · `kind` int (0 album · 1 singolo/EP, dalla sezione) · `year` int? · `thumb_url` text? · `first_seen_at` int · `is_new` bool (finché l'utente non la apre) · `opened_at` int? · `group_key` text (titolo senza parentesi, senza ciò che segue «:» o «+», senza «Deluxe/Edition/Version»: le varianti dello stesso album hanno la stessa chiave). Le uscite **non** vanno nel backup portabile (dopo un'unione il primo giro le segna come viste).

### `artist_lookups`
`artist_key` text **PK** (`matchKey` dell'artista principale) · `name` text · `status` int (0 un solo artista uguale · 1 nessuno · 2 più d'uno, «Da confermare») · `ytm_id`, `ytm_name`, `thumb_url` text? · `checked_at` int. Memoria di 30 giorni delle ricerche dei più ascoltati, perché non si ripetano.

Impostazioni nuove in `SettingsStore` (fuori da `AppSettings`, quindi non nel backup): `releasesTopArtists` (bool, false) · `releasesNotify` (bool, true) · `releasesUnmeteredOnly` (bool, false) · `releasesTopCardSeen` (bool) · `releasesLastRunAt`, `releasesRetryAt`, `releasesLastNotifiedAt` (int? ms).

## Importazione da CSV (schema v4, fase 12)
| Tabella | Colonne | Note |
|---|---|---|
| `playlist_imports` | `id`, `playlist_id` → playlists (cascade), `source_name`, `created_at`, `status` | `status`: 0 in corso · 1 in pausa · 2 finita · 3 annullata |
| `playlist_import_items` | PK (`import_id` cascade, `row_index`), `title`, `artists` (separati da `;`), `album?`, `duration_ms?`, `isrc?`, `year?` (v14), `status`, `video_id?`, `candidates?` (JSON), `track_id?` → tracks (set null), `score?` | `status`: 0 da cercare · 1 in coda · 2 scaricato · 3 collegato · 4 da verificare · 5 non trovato · 6 errore · 7 saltato |
**Schema v5 (fase 15):** `playlist_imports` + `source_kind` (`exportify`|`tunemymusic`|`soundiiz`|`lastfm`|`csv`|`m3u`|`xspf`, default `exportify`), `folder_path?`, `number_files`, `link_only`, `plan_first`, `fetch_covers` (bool, default false); `playlist_import_items` + `note?`, `location?`; stati riga nuovi **8 pianificato** · **9 rimosso dalla sorgente**.
Allo avvio le importazioni «in corso» diventano «in pausa» e le righe «in coda» tornano «da cercare»:
niente rete senza un'azione dell'utente. Cancellare la playlist cancella l'importazione.

## `albumKey` (chiave di raggruppamento album)
Calcolata in `text_utils.dart`, **sempre** con questa funzione:
```
normalize(s) = stripDiacritics(s).toLowerCase().trim() con spazi multipli → uno
artistPart   = normalize(albumArtist ?? artist ?? '')
albumPart    = normalize(album ?? '')

se albumPart è vuoto oppure in {'album sconosciuto','unknown','unknown album'}:
    albumKey = 'unknown|' + normalize(directory del file)      // raggruppa per cartella
altrimenti:
    albumKey = artistPart + '|' + albumPart
```
Etichetta mostrata in UI: `album` + (`albumArtist ?? artist`). Compilation: se in un albumKey ci
sono più artisti diversi e nessun `albumArtist`, mostra "Artisti vari" (calcolato in query, non salvato).

## Copertine su disco
- Cartella: `<appSupportDir>/covers/`. File: `<coverKey>.jpg` (o `.png` se l'originale è PNG).
- `coverKey` = SHA-1 esadecimale (pacchetto `crypto`) di `albumKey`. Una copertina per album.
- Ordine di ricerca: immagine incorporata nel primo brano dell'album → file `cover.jpg|folder.jpg|front.jpg|cover.png`
  nella stessa cartella → nessuna (`hasCover = false`, non ritentare finché il file cambia).

## Scansione incrementale
Un file è "invariato" se `(path, sizeBytes, mtimeMs)` coincidono con la riga esistente → non rileggere i tag.
File scomparsi: `missing = true` **solo se la cartella radice è raggiungibile**; altrimenti non toccare nulla
(chiavetta scollegata ≠ brani cancellati). Se un file `missing` ricompare → `missing = false`.

## Query tipiche (da implementare nel repository)
- Tutti i brani non missing, ordinati per `sort` (title/artist/album/year/addedAt/duration), con filtro testo.
- Album: `SELECT albumKey, MIN(album), albumArtistLabel, COUNT(*), SUM(durationMs), MIN(coverKey) FROM tracks WHERE missing=0 GROUP BY albumKey`.
- Preferiti: `isFavorite = 1`.
- Ricerca: `LIKE ? ESCAPE '\'` su title, artist, album con `%`/`_` escapati.

**Schema v6 (fase 17):** `tracks.resume_position_ms` (int?, null = nessun segnalibro); migrazione da v5 testata.

## Impostazioni (shared_preferences, non nel DB)
| Chiave | Tipo | Default | Valori |
|---|---|---|---|
| `theme` | string | `notte` | `notte`, `oled`, `chiaro` (`light` = `chiaro`; i nomi ritirati `carbon`, `navy` → `notte`) |
| `accent` | string | `viola` | `viola`, `blu`, `acqua`, `verde`, `ambra`, `arancio`, `rosa`, `rosso` (fase 19; valore ignoto = `viola`) |
| `onboardingDone` | bool | false | la guida al primo avvio è finita o saltata (fase 19) |
| `trustedDevices` | string (JSON) | assente | dispositivi abbinati (fase 24): lista di `{id, name, fingerprint, pairedAt, autoAccept}`; un dato illeggibile dà una lista vuota, mai fiducia a caso |
| `notDuplicates` | list<string> | `[]` | gruppi di brani che l'utente ha detto «non sono duplicati» (fase 21) |
| `recordHistory` | bool | true | registra la cronologia di ascolto (`plays`), solo locale (fase 20) |
| `fontScale` | double | 1.0 | 0.9, 1.0, 1.15 |
| `compactMode` | bool | false | |
| `reducedMotion` | bool | false | |
| `language` | string | `it` | `it`, `en`, `de`, `es` |
| `musicFolders` | list<string> | `[]` | percorsi radice |
| `autoEnrich` | bool | **false** | arricchimento web automatico |
| `autoLyrics` | bool | **false** | testi LRCLIB automatici |
| `showUndoSnackbar` | bool | true | annulla rimozione preferito |
| `lastQueueIds` | list<string> | `[]` | ultima coda |
| `lastContextKind`, `lastContextName` | int, string | — | contesto dell'ultima coda (`PlayContextKind.index`: l'enum si allunga solo in fondo) |
| `lastIndex`, `lastPositionMs` | int | 0 | ripresa |
| `volume` | double | 1.0 | |
| `shuffle` | bool | false | |
| `repeat` | string | `off` | `off`, `all`, `one` |
| `downloadParallel` | int | 2 | 1–3 (fase 14) |
| `downloadRateLimitKBps` | int | 0 | 0 = nessun limite (fase 14) |
| `downloadFormat` | string | `m4a` | `original` (audio così com'è, di solito Opus), `m4a` (AAC di YouTube senza ricodifica), `mp3High` (320 kbps), `mp3Low` (192 kbps); sostituisce `downloadOriginal` della fase 14 (2026-10-20) |
| `playbackSpeed` | double | 1.0 | 0.5–2.0, globale (fase 17) |
| `radioCountry` | string | `''` | codice ISO del paese di «Vicino a te»; vuoto = quello del sistema, altrimenti Italia (fase 33) |
| `radioRegion` | string | `''` | regione scelta (per l'Italia un id della tabella, es. `lombardia`; altrove il nome come lo scrivono le stazioni); vuoto = da chiedere (fase 33) |
| `radioOnlyCountry` | bool | false | ricerca e generi solo nel paese scelto (fase 33) |
| `radioDataNoticeSeen`, `radioRefreshedAt` | bool, int | assenti | avviso «circa 1 MB al minuto» già mostrato; ultima rilettura delle radio salvate (ms). Fuori da `AppSettings`: non sono scelte dell'utente e non vanno nel backup (fase 33) |
| `eqEnabled` | bool | false | equalizzatore acceso (fase 17) |
| `eqPreset.speaker`, `eqPreset.headphones` | string | `flat` | nome del preset (`custom` = guadagni propri) |
| `eqGains.speaker`, `eqGains.headphones` | list<string> | `[]` | guadagni in dB, uno per banda, usati con `custom` |
| `transition` | string | `normal` | `normal`, `gapless`, `crossfade` (fase 18) |
| `crossfadeSeconds` | int | 6 | 2–12 |
| `crossfadePlainInAlbum` | bool | true | tra brani dello stesso album niente dissolvenza |
| `jamAside` | string (JSON) | assente | coda di prima della Jam (ids, indice, posizione, `shuffle`, `plus`; per l'host solo la modalità): scritta all'ingresso in Jam e quando cambia la parte non suonata, rimessa al posto della coda normale all'avvio dopo una chiusura a Jam in corso, cancellata dopo il ripristino (fase 74, D-341, D-342) |

Le vecchie impostazioni finte (crossfade, gapless, normalizzazione, "bit-perfect WASAPI", autoplay) **non** vengono portate.

## ISRC in libreria (schema v14, fase 36)
- `tracks.isrc` (testo, nullable, indice `tracks_isrc`) e `playlist_import_items.year` (intero, nullable).
- Migrazione v13 → v14: aggiunge colonne e indice, poi copia in `tracks.isrc` l'ISRC dell'ultima riga d'importazione
  collegata al brano (per `playlist_imports.created_at`), solo dove il brano non ne ha uno.
- Scritture: la scansione (tag TSRC mp3, commento ISRC flac/ogg; m4a non letto) e il collegamento di una riga
  d'importazione (`ImportRepository.setItem` con `trackId`) scrivono l'ISRC solo se quello del brano è vuoto: mai sovrascritto.
- I file già in libreria ricevono l'ISRC dai tag solo quando lo scanner li rilegge (dimensione/mtime cambiati): nessuna riscansione forzata, per evitare una rilettura completa sui telefoni; l'arricchimento Deezer ripiega sulla ricerca testuale.

## Crediti e dettagli (schema v15, fase 50-51)
- `track_credits` (`track_id` → `tracks` con cascade, `name`, `name_key` = `creditNameKey(name)`, `role`, `source`; chiave `(track_id, name_key, role)`, indice `track_credits_name_key`).
- `track_enrich` (`track_id` chiave; `details` JSON, `deezer_id`, `mbid`; `meta_none_at`, `lyrics_none_at`, `synced_none_at`, `curio_none_at`, `credits_none_at` = quando la ricerca non ha trovato niente, ritentata dopo 30 giorni; `lyrics_by_user`).
- `activity_log` (`id`, `at`, `kind`, `name`, `done`, `total`, `failed`, `detail`; indice su `at`): il «Registro» dei lavori in background. `detail` è JSON e dipende dal tipo: `import` ha `event` (`ImportEventKind`); `correction` ha `trackId`, `old`/`new` (`title`, `artist`; `old` anche `isrc`, `mbid`) e `src`, oppure, se il file non è stato aggiornato (`failed` = 1), solo `trackId` e `file` (un `TagWriteReason`); `enrichBackground` ha gli id dei brani, `sources` e `noAnswer` (`failed` = 1 ma mostrata come fermata); gli altri lavori `stopped` o `updated`/`notFound`. Il tempo `at` viene da `nowMs()` (in test `nowMsOverride`).
- `tracks.cover_source` (intero, di serie 0).

## Generi e nazionalità (schema v16, fasi 93, D-390)
- `track_genres`: `track_id` → `tracks` (cascade) · `genre` (testo, `NOCASE`) · `position`; chiave `(track_id, position)`, indice `track_genres_genre` su `genre`. Tutti i generi di un brano nell'ordine dei tag. `tracks.genre` resta il **primo** genere.
- `artist_countries`: `artist_key` **PK** (`ArtistInfoRepository.keyOf`) · `country` text? (ISO 3166-1 alpha-2; null = non trovato) · `source` text? (`musicbrainz`/`wikidata`) · `checked_at` int. Un `country` nullo con `checked_at` si ritenta dopo 30 giorni.
- Migrazione v15 → v16: due `createTable` e l'indice; nessuna colonna toccata.

## Alias degli artisti (schema v17, fase 95)
- `artist_aliases`: `alias_id` **PK** · `main_id` · `created_at`. Il profilo `alias_id` mostra la pagina di `main_id`; mai catene (`main_id` non è mai un alias).
- `artist_not_same`: `(a, b)` **PK** · `created_at`, con `CHECK (a < b)` sull'ordine UTF-8 delle stringhe: una coppia ha una riga sola. Sono i profili che l'utente ha detto essere artisti diversi (D-414): non si propongono più di unire.

## Podcast di YouTube Music (schema v18, fase 96)
- `podcasts.source` (int, di serie 0 = feed RSS; `kPodcastSourceYtm` = programma di YouTube Music) e `podcasts.source_id` (testo, nullable: l'id del programma sulla sua fonte, `MPSPP…` per YTM; null per RSS). Due `addColumn`; i podcast esistenti restano RSS.

## Backup portabile e nuovi dati (fasi 93–97)
- Nei dati utente del backup (`user_data.dart`) entrano `genres` (per brano), `artistCountries`, `artistAliases` e `artistNotSame`. Un backup più vecchio non li ha e si legge lo stesso (campi assenti = vuoti).
- `genreRereadAfter` e `genreRereadDone` (`SettingsStore`) sono legati al dispositivo: non viaggiano nel backup, perché gli id dei brani cambiano.
- Il ripristino cancella `playlistSorts` (la mappa id playlist → ordinamento, D-424): gli id delle playlist non coincidono più.

## Blocco `meta` dei brani condivisi (fase 37)
Oggetto JSON facoltativo nel manifesto di condivisione (`RemoteTrack.meta`, `TrackMeta.toJson`); solo i campi non nulli.
Il ricevente valida ogni campo da solo (`TrackMeta.tryParse`): un campo fuori regola diventa null.

| Campo | Tipo | Regola |
|---|---|---|
| `title`, `artist`, `albumArtist`, `album` | string | tagliati a 200 caratteri |
| `genre` | string | tagliato a 100 |
| `year` | int | 1000 – anno corrente + 1 |
| `trackNumber`, `discNumber` | int | 1 – 999 |
| `isrc` | string | maiuscolo, `^[A-Z]{2}[A-Z0-9]{3}\d{7}$` |
| `lyricsPlain` | string | ≤ 20 000 caratteri, altrimenti scartato |
| `lyricsSynced` | string | ≤ 40 000 e LRC leggibile (`parseLrc` non vuoto) |
| `enrichStatus` | int | 0 – 2; il ricevente non lo applica |
| `youtubeId` | string | 11 caratteri `[A-Za-z0-9_-]` (oggi sempre assente: nessuna colonna) |

La copertina non è nel blocco: si scarica a parte (`downloadCover`). Un'app senza la fase 37 ignora il campo.
