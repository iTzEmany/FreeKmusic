# Fase 22 — Nuove fonti: SoundCloud, playlist e canali YouTube, traduzione dei testi

**Obiettivo:** tre aggiunte alle funzioni online: cercare e scaricare anche da **SoundCloud** (in Cerca e come
ripiego nell'importazione), incollare l'indirizzo di una **playlist o di un canale YouTube** e scaricarlo come
playlist, e **tradurre i testi** sul dispositivo (solo Android).
**Prerequisiti:** Fase 5 (yt-dlp, `DownloadQueue`, `downloads.json`), Fase 12 (motore di importazione,
`track_matcher.dart`), Fase 14 (download robusti: parallelo, ritento, formato).
**Principio:** la rete parte solo da un'azione dell'utente. Nessun endpoint non ufficiale: SoundCloud e YouTube
passano da yt-dlp, la traduzione gira **on-device** (nessun testo inviato a servizi esterni).

> ⚠️ Come per YouTube (Fase 5 parte B): scaricare da SoundCloud può violare i suoi Termini e i diritti degli
> autori. Uso strettamente personale; l'avviso legale già mostrato una volta (`ytNoticeSeen`) cita anche SoundCloud.

## Decisioni
| Tema | Scelta |
|---|---|
| Modello | `YtResult` guadagna `source` (`youtube` · `soundcloud`) e `webpageUrl`; il download usa `webpageUrl` (oggi Android costruisce `https://www.youtube.com/watch?v=$id` in `MainActivity.kt`) |
| Ricerca SoundCloud | `scsearch5:<query>` con yt-dlp (desktop e Android); metadati completi (non flat) come per YouTube Music |
| Anteprime da 30 s | Scartate: durata ≤ 31 s **oppure** campi yt-dlp che indicano anteprima (da verificare in 22.1) |
| Punteggio | `scoreCandidate` con profilo per fonte: SoundCloud senza bonus «- Topic»/VEVO; bonus se `uploader` = artista; penalità per «remix/edit/bootleg» come oggi |
| Cerca | Selettore di fonte nella sezione online: YouTube · YouTube Music · SoundCloud |
| Importazione | SoundCloud come ripiego **opzionale** (impostazione, default off) dopo YouTube Music e YouTube, solo per righe «non trovate» |
| Playlist/canali | URL incollato → `--flat-playlist` → elenco con «scegli» o «tutti» → nuova playlist tramite `PlaylistImportService` con candidati già noti (nessuna ricerca) |
| Traduzione | ML Kit on-device solo Android; modello di lingua scaricato **solo** su richiesta esplicita; su desktop la voce non c'è |
| Pacchetti nuovi | `google_mlkit_translation` (**da approvare con l'utente prima del task 22.7**) |

## Task

### 22.1 — Verifiche preliminari (prima di scrivere codice)
1. **Linux:** `yt-dlp -J --playlist-items 1-5 "scsearch5:daft punk one more time"` → annota campi (`id`,
   `title`, `uploader`, `duration`, `webpage_url`, `thumbnails`, eventuali indicatori di anteprima), tempo.
2. `yt-dlp -J --flat-playlist "<URL playlist YouTube pubblica>"` e lo stesso con un canale (`/@nome/videos`): campi
   per voce (`id`, `title`, `duration`?, `channel`?), numero di voci, tempo con 200+ video.
3. Download di prova da SoundCloud (`-f bestaudio`): formato ottenuto (spesso `opus`/`mp3` HLS), serve ffmpeg?
4. **Android (Mi A3):** stesse prove tramite il canale `codecore/ytdlp` con la libreria `youtubedl-android`
   (aggiungere temporaneamente un'opzione `rawTarget`).
5. Pacchetto `google_mlkit_translation`: dopo l'approvazione, leggere il sorgente in `~/.pub-cache` (API vere:
   creazione del traduttore, gestione modelli, `close`), `minSdk`, aumento dell'APK.
**Verifica:** note in PROGRESS con comandi e campi. **Stop:** se SoundCloud non restituisce brani interi senza
login o yt-dlp su Android non legge playlist, **fermati e riporta**; la parte che funziona si fa lo stesso.
Salvare le risposte in `test/fixtures/scsearch.json` e `test/fixtures/yt_playlist_flat.json`.

### 22.2 — Fonte nel modello e nel download
**File:** `lib/services/online/youtube_service.dart`, `yt_dlp_process_service.dart`, `android_yt_dlp_service.dart`,
`android/app/src/main/kotlin/com/codecore/player/MainActivity.kt`, `download_index.dart`, `test/services/online/…`
1. `enum MediaSource { youtube, soundcloud }`; `YtResult.source` (default `youtube`) e `webpageUrl` (fallback
   `https://www.youtube.com/watch?v=<id>` per YouTube).
2. `parseYtDlpJson`: legge `webpage_url`, `extractor_key`/`ie_key` → `source`; per SoundCloud `channel` da `uploader`.
3. Download: desktop passa `webpageUrl` a yt-dlp; Android: argomento `url` nel metodo `download` (con `id` come oggi
   per compatibilità).
4. `downloads.json`: chiave `<source>:<id>` per le voci nuove; le chiavi vecchie senza prefisso valgono come `youtube:`.
**Test:** `parseYtDlpJson` sulle fixture di 22.1; `DownloadIndex` legge il formato vecchio e il nuovo.

### 22.3 — Ricerca SoundCloud e filtro anteprime
**File:** `youtube_service.dart` (metodo `searchSoundCloud(String q, {int limit = 5})`), implementazioni desktop e
Android, `test/services/online/soundcloud_parse_test.dart`
1. `scsearch<N>:` con metadati completi; risultati con durata ≤ 31 s o marcati anteprima → scartati e loggati
   (`AppLog.d`, conteggio).
2. Stessi errori tipizzati (`ytExceptionFromStderr`); 429 → `rateLimited`.
**Test:** fixture con un'anteprima da 30 s → esclusa; brano intero → presente con `source == soundcloud`.

### 22.4 — Punteggio per fonte
**File:** `lib/services/import/track_matcher.dart`, `test/services/import/track_matcher_test.dart`
1. `_bonus`/`_artistScore` ricevono la fonte: per SoundCloud nessun bonus «- Topic»/VEVO, bonus se `uploader`
   normalizzato (`matchKey`) = artista principale o lo contiene («Daft Punk Official»).
2. Le soglie di `decide` (0,80 / 0,55) restano; i casi esistenti non cambiano (test di regressione).
**Test:** ≥ 6 casi nuovi SoundCloud (uploader = artista, repost di terzi, «bootleg», durata uguale ma titolo con «(Original Mix)»).

### 22.5 — Selettore di fonte in Cerca e ripiego nell'importazione
**File:** `lib/ui/screens/search/search_screen.dart`, `lib/ui/screens/youtube/youtube_results.dart`,
`lib/providers/youtube_providers.dart`, `playlist_import_service.dart`, `settings_store.dart`, `settings_screen.dart`, ARB
1. In Cerca, sezione online: segmenti **YouTube · YouTube Music · SoundCloud** (ricordato in `AppSettings`);
   le righe mostrano un'icona di fonte.
2. Impostazione «Cerca anche su SoundCloud se un brano non si trova» (default **off**). Nel ciclo di
   `PlaylistImportService._find`: dopo YouTube Music e YouTube, solo se ancora `notFound` e opzione attiva.
3. I candidati SoundCloud in «Rivedi» (Fase 12) mostrano la fonte.
**Test:** servizio di importazione con servizi finti: opzione spenta → nessuna chiamata SoundCloud; accesa → una sola
chiamata per riga non trovata.

### 22.6 — Playlist e canali YouTube come sorgente
**File:** `youtube_service.dart` (`listPlaylist(String url)`), implementazioni desktop/Android, `MainActivity.kt`
(argomento `flat` per URL), `lib/ui/screens/youtube/playlist_source_sheet.dart`, `playlist_import_service.dart`
(`startFromResults`), `search_screen.dart`, ARB
1. `isYoutubePlaylistUrl` / `isYoutubeChannelUrl` (logica pura + test): `list=` nell'URL, `/@nome`, `/channel/…`,
   `/playlist?…`. Oggi un URL viene sempre trattato con `--no-playlist`: con questi URL si usa `--flat-playlist`.
2. Incollare un URL di playlist/canale in Cerca apre un foglio: nome (dal titolo della playlist), numero di video,
   elenco con caselle (tutti selezionati), «Scarica in una playlist».
3. `PlaylistImportService.startFromResults(name, List<YtResult>)`: righe dell'import create dai risultati con
   `videoId` già noto e stato «in coda» → nessuna ricerca, stesso ordine, stessa pausa/ripresa/annulla, tag dal
   titolo del video ripulito con `query_cleaner.dart` (o da `artists`/`track` se presenti).
4. Canali con molti video: avviso oltre 200 voci con stima del tempo (come la stima della Fase 12).
**Test:** riconoscimento URL; `startFromResults` con coda finta: ordine rispettato, nessuna chiamata a `searchSongs`.
**Tocca a te:** una playlist pubblica di 15 video su Linux e telefono.

### 22.7 — Traduzione dei testi on-device (solo Android)
**Solo dopo l'approvazione del pacchetto in 22.1.**
**File:** `lib/services/online/lyrics_translator.dart` (interfaccia + `MlKitLyricsTranslator`),
`lib/providers/online_providers.dart`, `lib/ui/screens/lyrics/lyrics_view.dart`, `lyrics_screen.dart`,
`settings_screen.dart` (gestione modelli), ARB
1. `abstract class LyricsTranslator { Future<bool> isModelReady(String lang); Future<void> downloadModel(String lang);
   Future<List<String>> translateLines(List<String> lines, {required String from, required String to}); }` —
   lingua di destinazione = lingua dell'app; sorgente scelta dall'utente (identificazione automatica solo se il
   pacchetto la offre on-device, altrimenti menu).
2. Nella schermata testi: pulsante «Traduci» (solo `isAndroid`). Modello assente → dialogo «Scarica il modello
   <lingua> (~30 MB, solo Wi‑Fi consigliato)» → avanzamento nel Centro Attività.
3. Traduzione riga per riga (i tempi LRC restano quelli originali); vista affiancata o alternata; **non** salvata nel
   DB (si ricalcola, è veloce on-device); `close()` del traduttore all'uscita.
4. Impostazioni → «Modelli di traduzione»: elenco scaricati con «Elimina».
**Verifica:** widget test con traduttore finto (righe tradotte allineate ai tempi); su desktop il pulsante non c'è.
**Tocca a te:** telefono: scaricare il modello inglese, tradurre un testo sincronizzato, modalità aereo → funziona.

### 22.8 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es/fr/pt; avviso legale aggiornato con SoundCloud.
2. Test «live» opzionali in `test/live/` (`soundcloud_live_test.dart`, `yt_playlist_live_test.dart`) dietro
   `CODECORE_LIVE=1`, come `import_live_test.dart`.
3. `docs/02-architettura.md` (fonti, `MediaSource`, traduttore), `docs/99-rischi-e-fallback.md` (R53–R55), README.
**Tocca a te (Linux + Mi A3):** ricerca e download da SoundCloud; importazione CSV con ripiego SoundCloud attivo;
playlist YouTube incollata e scaricata in ordine; traduzione dei testi offline.

## Fuori da questa fase
Bandcamp e altre fonti (escluse), account/login SoundCloud, traduzione delle curiosità di Wikipedia, traduzione su
desktop (nessun motore on-device approvato), aggiornamento automatico delle playlist YouTube già scaricate.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R53 | SoundCloud restituisce solo anteprime da 30 s o richiede login per molti brani | Filtro sulla durata, ripiego opzionale e spento di default; stop in 22.1 se inutilizzabile |
| R54 | Playlist/canali enormi o con video privati/rimossi | `--flat-playlist`, avviso oltre 200 voci, voci non disponibili → «errore» per riga, il resto continua |
| R55 | ML Kit pesante (APK, modelli) o lingua non supportata | Pacchetto approvato a parte, modelli solo su richiesta, voce assente su desktop e per lingue non coperte |

## Definition of Done
- [ ] Ricerca e download da SoundCloud (anteprime scartate), fonte visibile in Cerca e in «Rivedi»
- [ ] Ripiego SoundCloud nell'importazione, spento di default
- [ ] Playlist/canale YouTube incollato → playlist scaricata nell'ordine, con pausa/ripresa/annulla
- [ ] (Se approvato) traduzione dei testi on-device su Android, nessun testo inviato in rete
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
