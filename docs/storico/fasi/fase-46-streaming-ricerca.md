# Fase 46 — Streaming dalla ricerca

**Obiettivo:** tutto ciò che si trova online si ascolta in streaming. Tap su una riga online = suona subito dopo il
brano in corso, con il player aperto in caricamento; swipe = in coda; menu ⋮ completo come i brani locali. L'album
online ha Play e Shuffle e un menu ⋮ nuovo. «Scarica» e «Aggiungi a playlist» su un brano in cache spostano il file in
libreria senza riscaricarlo. L'anteprima con le cuffie sparisce.

**Prerequisiti:** fase 45 chiusa (`StreamCache`, `StreamPreparer`, righe ombra, lettore dal file).
Fase 30 (`OnlineSongRow`, pagine online), fase 31.11 (`PendingPlaylistAdds`), fase 37 (`DownloadTagger`).

**Riferimenti:** `docs/feature-streaming.md` (R-01, R-02, R-04, R-06, R-10, R-13, R-16, R-17, R-18, R-19, R-30;
«Flussi» (a) e (d); K-01…K-04); decisioni D-59, D-62, D-64, D-65, D-67, D-70, D-76, D-77, D-81.

**Intoccabili (D-76):** libreria e playlist (le playlist restano di soli brani locali, D-65); i download di oggi
(`DownloadQueue`, «Scarica album» con l'import, import di playlist: `StreamPromoter` si mette **davanti** e, senza
file in cache, si va per il percorso di oggi, RNF-03); la fluidità («Finale» della fase 44). **Nessun pacchetto
nuovo.** **Schema del DB invariato (D-77).** L'anteprima di 20 s dei brani di libreria (`PreviewPlayer`,
`preview_providers.dart`) non fa parte di R-04 e resta.

## Task

### 46.1 — `PlayerController`: suonare e accodare brani online
**File:** `lib/providers/player_providers.dart` (`playOnline`, `enqueueOnline`, `playOnlineNext`,
`playOnlineList`), `lib/services/audio/codecore_audio_handler.dart` (`insertAt`/`addToQueue` per id negativi se
mancano), `test/providers/play_online_test.dart`
1. `playOnline(YtResult r)`: chiave già in `DownloadIndex` → suona il brano di libreria (`idForPath`) con il tap di
   libreria di oggi (D-81); altrimenti `OnlineEntries.register` → inserisce dopo il corrente → salta lì (coda
   `[A*, B]` → `[A, X*, B]`) (R-01).
2. `enqueueOnline(r)` (in fondo) e `playOnlineNext(r)` (dopo il corrente, senza saltare): registrano e accodano; il
   preparer parte da solo (R-14 della fase 45).
3. `playOnlineList(List<YtResult> list, {bool shuffle})`: sostituisce la coda con la lista in ordine; `shuffle: true`
   = shuffle normale acceso e `shufflePlus` spento (mai Shuffle+, R-18).

R-01, R-18 (logica).
**Fatto quando:** `flutter test test/providers/play_online_test.dart` verde: coda `[A*, B]` + `playOnline(X)` →
`[A, X*, B]` e indice su X; risultato già scaricato → suona l'id di libreria, nessuna entry online; `enqueueOnline`
→ in fondo; `playOnlineNext` → dopo il corrente, corrente invariato; `playOnlineList(5 brani)` → coda = i 5 in
ordine; con `shuffle: true` shuffle acceso e `shufflePlus` falso. `flutter analyze` pulito.

### 46.2 — Player in caricamento
**File:** `lib/ui/screens/now_playing/now_playing_screen.dart`, `now_playing_cards.dart`,
`lib/ui/widgets/mini_player.dart`, `lib/services/audio/codecore_audio_handler.dart` (`_toMediaItem` in `loading`:
sottotitolo «Caricamento…» per la notifica), un provider di sola lettura dello stato `loading` in
`player_providers.dart` (con `select`, K-03), ARB, `test/ui/now_playing_loading_test.dart`, `test/ui/mini_player_test.dart`
1. `playOnline` e `playOnlineList` aprono `NowPlayingScreen` (stesso `push` di `mini_player.dart`): copertina
   (miniatura del risultato) e titolo subito, anello che gira al posto della copertina/pulsante play finché lo stato è
   `loading`.
2. Mini player e notifica: «Caricamento…» al posto dell'artista finché `loading`; abbassando il player resta il mini
   player.
3. Testo e curiosità compaiono quando la riga ombra li riceve (già dato da 45.4); nessuna ricostruzione per il
   progresso del download (K-03).

R-02.
**Fatto quando:** `flutter test test/ui/now_playing_loading_test.dart test/ui/mini_player_test.dart` verde: dopo il
tap su un risultato c'è la `NowPlayingScreen` con l'indicatore di caricamento e il titolo del risultato; il mini player
mostra «Caricamento…» finché lo stato è `loading` e l'artista dopo; `_toMediaItem` in `loading` ha «Caricamento…»
(test dell'handler). `flutter analyze` pulito.

### 46.3 — `StreamPromoter`: «Scarica» senza riscaricare
**File:** `lib/services/stream/stream_promoter.dart`, `lib/providers/stream_providers.dart`,
`lib/providers/youtube_providers.dart` (`DownloadsNotifier`: chiede prima al promoter),
`lib/data/repositories/track_repository.dart` (`promoteStreamRow`, `mergeStreamRow`),
`test/services/stream/stream_promoter_test.dart`
1. File in cache: copia nella cartella dei download (`rename` se stesso volume; altrimenti copia + verifica della
   dimensione + cancellazione, K-05) con il nome di `downloadBaseName(r)` → `DownloadIndex.add` → la riga ombra
   diventa `kind = 0` con `path` vero e `folderId` **prima** della scansione → scansione → `DownloadTagger.tag` →
   il file in cache si cancella (R-10, «Flussi» (d)). Errore di spazio: messaggio chiaro, il file in cache resta.
2. Senza file in cache: download di oggi; a scansione finita `mergeStreamRow` unisce la riga ombra della stessa chiave
   alla riga nuova (sposta `plays`, `play_count`, `lastPlayedAt`, testo e curiosità come `DuplicateRepository.merge`)
   e cancella la riga ombra.
3. Il file in cache non si modifica mai (invariante 6): i tag si scrivono solo sulla copia nella cartella dei download.

R-10.
**Fatto quando:** `flutter test test/services/stream/stream_promoter_test.dart` verde: «Scarica» su un brano in
cache non chiama il downloader; dopo, il file sta nella cartella dei download, la riga ha `kind = 0`, gli stessi
`plays` e il testo dell'arricchimento, `DownloadTagger` chiamato una volta; nessuna seconda riga dopo la scansione
(K-02); senza file in cache → downloader chiamato e riga ombra unita (ascolti spostati). K-01: `flutter test
test/services/online/download_test.dart test/services/library/download_tagger_test.dart` verde. `flutter analyze` pulito.

### 46.4 — «Aggiungi a playlist» su un brano online
**File:** `lib/providers/pending_playlist_adds.dart`, `lib/ui/widgets/track_actions.dart`,
`test/providers/pending_playlist_adds_test.dart`
1. «Aggiungi a playlist» su un brano online (riga online, brano in streaming nel player, suggerito): promozione
   (46.3) se il file è in cache, altrimenti download con `tag: 'addto:<playlistId>'` come oggi; a brano in libreria
   `PlaylistRepository.addTracks` (D-65).

R-17.
**Fatto quando:** `flutter test test/providers/pending_playlist_adds_test.dart` verde con due casi nuovi: brano in cache
→ spostamento (nessun download) e poi la riga in playlist; brano non in cache → download e poi la riga in playlist;
i casi di oggi verdi. `flutter analyze` pulito.

### 46.5 — Righe online: tap, swipe e menu ⋮
**File:** `lib/ui/screens/online/online_song_row.dart`, `lib/ui/screens/youtube/online_results_sections.dart`,
`lib/ui/screens/online/artist_songs_screen.dart`, `online_album_screen.dart` (righe), `lib/ui/widgets/track_row.dart`
(riuso della zona del bordo D-59), `lib/ui/widgets/track_actions.dart` (azioni per un `YtResult`), ARB,
`test/ui/online_song_row_test.dart`
1. Tap = `playOnline`; swipe a destra = `enqueueOnline` con la stessa zona esclusa dal bordo delle righe locali (D-59);
   resta il pulsante scarica (R-13, R-16).
2. Menu ⋮: Riproduci dopo (`playOnlineNext`), In coda, Aggiungi a playlist (46.4), Scarica (46.3), Vai all'artista
   (pagina artista online come oggi; il foglio di scelta per più artisti arriva in 49.3) (R-16).
3. In modalità selezione (`pick.selecting`) il tap resta selezione come oggi.

R-13, R-16.
**Fatto quando:** `flutter test test/ui/online_song_row_test.dart` verde: tap → `playOnline`; swipe → `enqueueOnline`;
swipe che parte dal bordo → nessun accodamento; il menu ⋮ ha le 5 voci e ognuna chiama l'azione giusta; il pulsante
scarica c'è. `flutter analyze` pulito.

### 46.6 — Via l'anteprima con le cuffie
**File:** cancellare `lib/ui/screens/youtube/listen_bar.dart`, `lib/providers/listen_providers.dart`,
`test/providers/listen_test.dart`, `test/ui/listen_bar_test.dart`; togliere gli usi in `online_song_row.dart`,
`online_results_sections.dart`, `online_results.dart`, `online_page_frame.dart`,
`lib/ui/screens/now_playing/suggestions_screen.dart` («Ascolta» → `playOnline`); ARB non più usate (con
`scripts/arb_add.py` o a mano in tutte le lingue); `StreamSource.streamUrl`, `StreamAddress`, `FastClientGate` in
`youtube_service.dart` e le implementazioni in `yt_dlp_process_service.dart`/`android_yt_dlp_service.dart` se
`grep` non mostra altri usi.

R-04.
**Fatto quando:** `grep -rn "ListenButton\|listenProvider\|listenBackendFactoryProvider" lib test` = 0;
`grep -rn "streamUrl\|FastClientGate" lib` = 0 (o, se restano, una riga in PROGRESS che dice chi li usa);
`flutter test test/ui/suggestions_screen_test.dart test/ui/online_pages_test.dart` verde; `flutter analyze` pulito.

### 46.7 — Album online: Play, Shuffle e menu ⋮
**File:** `lib/ui/screens/online/online_album_screen.dart` (`_AlbumHeader`), `lib/ui/widgets/track_actions.dart`
(o un menu della testata), ARB, `test/ui/album_screen_test.dart` (o `test/ui/online_pages_test.dart`)
1. Testata con solo Play e Shuffle: Play = `playOnlineList(brani)`; Shuffle = `playOnlineList(brani, shuffle: true)`;
   entrambi aprono il player in caricamento (R-18).
2. Menu ⋮ della testata: «Scarica album» (la `_downloadAlbum` di oggi, invariata), «Metti in coda l'album»
   (`enqueueOnline` per ogni brano, in ordine), «Aggiungi a playlist» (scarica e aggiunge, 46.4, in ordine),
   «Condividi» (link dell'album, come le altre condivisioni di link dell'app) (R-19).

R-18, R-19.
**Fatto quando:** widget test verde: Play → coda = brani dell'album nell'ordine e player in caricamento; Shuffle →
shuffle acceso e `shufflePlus` falso; il menu ⋮ ha le 4 voci e ognuna chiama l'azione giusta («Scarica album»
chiama lo stesso percorso di oggi). `flutter analyze` pulito.

### 46.8 — «Scarica» nel menu ⋮ del player per un brano in streaming
**File:** `lib/ui/screens/now_playing/now_playing_controls.dart`, `lib/ui/widgets/track_actions.dart`,
`test/ui/track_actions_test.dart`
1. Brano corrente in streaming (entry online o riga `kind = 2`): voce «Scarica» (→ 46.3); un brano locale non l'ha.

R-06.
**Fatto quando:** `flutter test test/ui/track_actions_test.dart` verde: la voce «Scarica» esiste per un brano in
streaming e non per un brano locale. `flutter analyze` pulito.

### 46.9 — Controlli di fase (K-01, K-02, K-03)
1. K-01: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
2. K-02: `flutter test test/data/stream_rows_hidden_test.dart` verde.
3. K-03 (D-19, come in 45.7):
   `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 40m <scratchpad>/perf46.log -- python3 scripts/perf_device.py 0d7ae9df206e --label streaming-46 --playback`;
   tabella «Dopo la fase 46» in `misure.md` contro «Finale», con la tolleranza decisa in 45.7.
4. RNF-02: `grep -rn "Sync(" lib/services/stream lib/ui/screens/online` = 0.
5. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–5 sono verdi; `build/perf/streaming-46.md` esiste e la tabella copre ogni
riga di «Finale».

### 46.10 — Prove a mano (utente) [~]
Materiale per l'utente (R-30, K-04). Su **Linux e Mi A3**:
- Ricerca → tap su un brano mentre ne suona un altro: il player si apre in caricamento, poi suona; dopo, la coda
  riprende con il brano che seguiva (R-01, R-02); «Caricamento…» nel mini player e nella notifica (Mi A3).
- Swipe su una riga online → in fondo alla coda; swipe dal bordo sinistro → torna indietro il telefono, niente coda (R-13).
- Menu ⋮ di una riga online: le 5 voci (R-16).
- Album online di **15 brani**: Play (in ordine) e Shuffle; si ascoltano almeno 5 passaggi di brano; poi log esportato
  senza 403/429 ripetuti (K-04).
- «Scarica» su un brano già ascoltato in streaming: compare in libreria subito, con testo e copertina, senza un nuovo
  download (R-10); «Aggiungi a playlist» da una riga online (R-17).
- Nessun pulsante cuffie nelle righe online (R-04).

**Fatto quando:** l'utente conferma le prove su Linux e Mi A3 (casella `[~]` → `[x]` in PROGRESS).
