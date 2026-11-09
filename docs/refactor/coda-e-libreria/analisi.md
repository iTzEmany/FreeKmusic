# Refactor «coda-e-libreria» — analisi

> Giro 1 del `/refactor` del 2026-11-09. Tipo: `tutto` (UI + un difetto + cambi di comportamento chiesti dall'utente).
> Lettura statica del codice (nessuna misura dal vivo): le righe citate sono quelle di `master` a `513acd38`.

## Perimetro
1. **Titoli lunghi**: oggi tagliati con «…»; devono scorrere piano fino a mostrarsi interi.
2. **Libreria**: via «Statistiche», al suo posto «brani scaricati che non stanno in nessuna playlist».
3. **Coda**: dopo lo skip di un suggerito arriva un altro suggerito invece del brano messo in coda.
4. **Ricerca nel dettaglio di una playlist**.
5. **«Aggiungi in coda»** come blocco in cima alla coda (ordine di arrivo), **«Riproduci dopo» tolto**.

Sono cambi di comportamento voluti (regola 1 di `/refactor`): vanno in `docs/decisioni.md`.

## Misure di partenza
Nessuna metrica di prestazione da migliorare. Unico vincolo misurato: la fase 90 ha portato gli scatti nello scroll delle liste all'1–2 % dei frame sul Mi A3 (`docs/fase-90-intestazioni-che-scorrono.md`); il testo che scorre non deve peggiorarlo.

## Sintesi per area
- **Coda**: la coda è una lista piatta di id (`PlayQueue._items`) che non sa chi ha messo cosa. «Aggiungi in coda» accoda in fondo, dietro tutti i suggeriti: è la causa più probabile del difetto. «Riproduci dopo» inserisce subito dopo il corrente ma al contrario (l'ultimo aggiunto suona per primo).
- **Titoli**: nessun widget di testo che scorre; la fase 90 ha fatto intestazioni che si ritraggono, non testo che scorre. Serve un widget nuovo, piccolo.
- **Libreria**: «Statistiche» è solo una scorciatoia; la schermata resta raggiungibile dalla Home (blocco «Il tuo mese», solo con ≥ 10 ascolti nel mese). Non esiste un'indicazione «scaricato» nei brani: si ricava dalla cartella dei download.
- **Playlist**: il dettaglio non ha ricerca; riordino e rimozione lavorano per posizione nella lista intera, quindi con la lista filtrata vanno spenti o tradotti.

## Rilievi (per priorità)
Formato: `F-NN · area · titolo · dove · prova · danno · impatto · rischio · costo · proposta`.

- **F-129** · coda · «Aggiungi in coda» va in fondo, dietro i suggeriti · `lib/services/audio/play_queue.dart:372` (`append`), `codecore_audio_handler.dart:1735` · `_items.add(trackId)` · con i simili da Cerca (blocchi da 10 in coda) o Shuffle+ il brano dell'utente suona dopo tutti i suggeriti già in coda, e i rabbocchi lo scavalcano: è il «dopo lo skip arriva un altro suggerito» · A · M · M · blocco dell'utente in cima alla coda (F-132).
- **F-130** · Shuffle+ · dopo vari skip di brani della libreria il suggerito finisce subito dopo il corrente · `shuffle_plus_controller.dart:~300,317`, `insertion_plan.dart`; test voluto `test/services/shuffle_plus/insertion_plan_test.dart:38` · `_played` cresce a ogni skip e libera il primo posto · un suggerito appena dopo il corrente; anche una possibile corsa fra lo skip e `_followCurrent` · M · M · S · il piano dei suggeriti parte dopo il blocco dell'utente e non lo conta come «ascoltati».
- **F-131** · coda · «Riproduci dopo» è al contrario e da togliere · UI `widgets/track_actions.dart:255,595`, `widgets/bulk_actions.dart:111`; backend `player_providers.dart:382,524` (`playNext`, `playOnlineNext`), `codecore_audio_handler.dart:1727`, `play_queue.dart:313` (`insertNext`); ARB `playNext`, `playNextDone`, `playNextMany` in 6 lingue · `_items.insert(_pos + 1, …)` · la multiselezione rovescia l'ordine · B · B · S · togliere voci, metodi e chiavi; non verificato: azioni Android Auto/MPRIS.
- **F-132** · coda · shuffle, ripristino dell'ordine e Shuffle+ non conoscono un «blocco dell'utente» · `play_queue.dart` (`_shuffledFrom`, `_restoreNaturalOrder`, `moveInQueue`, `removeAt`, `rebuildUpcoming`), `playback_persistence` · coda senza segno di provenienza · senza questo il blocco si sparpaglia con lo shuffle o si perde · A · A (area a rischio: audio handler) · M · un insieme delle chiavi aggiunte dall'utente in `PlayQueue`, rispettato da shuffle, ripristino, Shuffle+ e svuota.
- **F-133** · titoli · tagliati con «…» ovunque, nessun testo che scorre · `now_playing_screen.dart:603`, `widgets/mini_player.dart:154+`, `shell/desktop_player_bar.dart:107,169,238`, `screens/jam/jam_player.dart:290`, `widgets/track_row.dart:384`, `now_playing/queue_sheet.dart:332,393`, `collection_header.dart` · `maxLines: 1, overflow: TextOverflow.ellipsis`; `grep -i marquee lib` vuoto · titoli lunghi illeggibili · M · B · M · widget nuovo `MarqueeText` (scorre solo se il testo non ci sta, pausa iniziale, velocità bassa).
- **F-134** · titoli · dove farlo scorrere · `track_row.dart` è in ogni lista · un'animazione per riga = decine di animazioni insieme sul Mi A3 · scatti nello scroll (contro la fase 90) · M · M · S · player a schermo intero, mini player e barra desktop; nelle liste resta «…».
- **F-135** · titoli · accessibilità del testo che scorre · `track_row.dart:378` (etichetta col titolo intero), mini player senza etichetta; `app.dart:124` (movimento ridotto) · TalkBack leggerebbe il testo tagliato o in movimento · utenti con movimento ridotto · M · B · S · etichetta col testo intero, testo fermo con «…» se il movimento è ridotto, animazione ferma quando la schermata non è visibile, nessun tocco intercettato (il mini player si scorre col dito).
- **F-136** · libreria · «Statistiche» è una scorciatoia, la schermata resta · `screens/library/library_screen.dart:440-443` (+ import :48) · entrata alternativa `home/home_bottom_rows.dart:108` solo con ≥ 10 ascolti nel mese · sotto i 10 ascolti le statistiche diventano irraggiungibili · M · B · S · togliere la scorciatoia; decidere se le statistiche hanno un'altra porta fissa.
- **F-137** · libreria · cosa vuol dire «scaricato» · `data/db/tables.dart:13` (nessun campo «scaricato»), `folder_ops.dart:24` (`resolveDownloadFolder`) · i download finiscono nella cartella dei download; i download online sono anche in `services/online/download_index.dart:12` (`downloads.json`, fonte:id → percorso) · con «file presente» entrerebbe tutta la libreria scansionata · A · M · M · stream nuovo nel `TrackRepository`: `kind = 0 AND missing = 0 AND ignored = 0 AND folder_id = <download> AND NOT EXISTS (playlist_tracks …)`.
- **F-138** · libreria · trappole della query · `tables.dart:200` (playlist intelligenti: solo regole), preferiti = `tracks.is_favorite`, righe ombra `kind = 2` e episodi `kind = 1` (K-02, `docs/feature-streaming.md:150`) · righe ombra o episodi nella lista · M · M · S · sempre `kind = 0`; playlist intelligenti e preferiti non contano; test con una riga `kind = 2`.
- **F-139** · libreria · riusare «Tutti i brani» · `screens/library/all_tracks_screen.dart:110` (`trackQueryProvider`, `watchTracks` :182) · il costruttore non ha un filtro · M · B · M · parametro facoltativo della sorgente, così la lista nuova ha ricerca, ordinamento e scorrimento A–Z come «Tutti i brani».
- **F-140** · playlist · nessuna ricerca nel dettaglio · `screens/playlists/playlist_detail_screen.dart:212-345` · nessun campo di ricerca · playlist lunghe difficili da scorrere · M · M · M · `CcSearchField` (`widgets/cc_search_field.dart`) sopra la lista, filtro in Dart su titolo, artista, album.
- **F-141** · playlist · riordino e rimozione per posizione con la lista filtrata · `playlist_detail_screen.dart:250,265-266` (`ops.reorder(id, from, to)`, `removeTrack(index:)`) · gli indici sono quelli della lista intera · si sposterebbe o toglierebbe il brano sbagliato · A · A · M · con una ricerca attiva: modifica e riordino spenti, rimozione con l'indice originale.
- **F-142** · playlist · ricerca senza accenti · `track_repository.dart:490-497` (`LIKE`, ignora maiuscole solo per ASCII) · «e» non trova «é» · B · B · S · stesso comportamento della Libreria (minuscole), o normalizzazione degli accenti per tutte e due.
- **F-143** · playlist · le playlist intelligenti hanno una schermata a parte · `screens/smart/smart_playlist_screen.dart:27` · il filtro del dettaglio non le copre · B · B · S · decidere se aggiungerlo anche lì.

## Test esistenti toccati
`test/services/audio/play_queue_test.dart` (`insertNext` 115, 122; `append` 130–318 con fuzz), `test/services/audio/codecore_audio_handler_test.dart:89,108`, `test/ui/track_actions_test.dart:253`, `test/ui/queue_reorder_test.dart`, `test/providers/play_online_jam_test.dart:98,158`, `test/services/audio/gapless_handler_test.dart:75,144,154`, `test/services/shuffle_plus/insertion_plan_test.dart`, `shuffle_plus_source_change_test.dart`, `test/jam/*`. Mancano: skip di un suggerito, «Aggiungi in coda» insieme ai suggeriti o al rabbocco dei simili.

## Rilievi aggiunti (link incollati in Cerca, 2026-11-09)
- **F-144** · cerca · un link a una playlist o a un canale apre solo il download · `lib/ui/screens/youtube/online_results.dart:80-90` (`listingUrl` → `PlaylistSourceSheet.show`), `playlist_source_sheet.dart:65-80` · nessun Play/Shuffle, non esiste una pagina playlist online · non si ascolta in streaming · A · B · M · pagina nuova `OnlinePlaylistScreen(url)` su `playlistListingProvider` (`youtube_providers.dart:36`) con le parti di `online_album_screen.dart` (righe `OnlineSongRow`, Play/Shuffle con `playOnlineListAndOpen`, Jam come `_queueAlbum`), «Scarica» nel menu apre il foglio di oggi.
- **F-145** · cerca · link a un album YouTube Music non riconosciuto · `youtube_urls.dart:57` (→ `other`), regex privata `direct_search_service.dart:10-16` · `music.youtube.com/browse/MPREb_…` diventa una ricerca testuale · B · B · S · riconoscerlo e aprire `OnlineAlbumScreen(browseId)`.
- **F-146** · cerca · link Spotify e Deezer non gestiti · nessun codice (`grep open.spotify.com` vuoto) · ricerca testuale dell'URL · M · M · L · lettura del link + abbinamento brano per brano (come l'import Exportify, fase 36), sotto il budget di rete.
- **F-147** · rete · `listPlaylist` (yt-dlp) fuori da `budgetedYtm` · `youtube_service.dart:250` · processo lento, limite 500 voci (`truncated`) · B · B · S · tenerlo così, con la cache del provider (niente nuova lettura tornando indietro).
Test esistenti: `test/services/online/youtube_urls_test.dart`, `query_intent_test.dart`, `smart_search_test.dart:558`; nessun test del foglio né dei link a un album YouTube Music.

## Scelte (giro 2)
- **Affrontati tutti**: F-129..F-143 (D-483..D-490).
- **Rimandati / scartati**: nessuno. Testo che scorre nelle righe delle liste: scartato (D-486).
- **Traguardo**: comportamento chiesto dall'utente con la coda prevedibile; nessuna perdita di fluidità.
- **Quanto osare**: ritocchi mirati; `PlayQueue` ristrutturata nella sua parte (blocco dell'utente).
- **Intoccabili** (D-491): nessun pacchetto nuovo; schema DB e formato del backup invariati; Jam (coda condivisa) invariata; statistiche e loro query invariate (cambia solo da dove si aprono); `/code-review high` su `codecore_audio_handler.dart` e `play_queue.dart`.

## Arrivo (giro 3)

### Struttura: il blocco dell'utente in `PlayQueue`
- **Modello**: `PlayQueue` tiene `List<int> _user` (chiavi delle voci aggiunte dall'utente non ancora suonate, in ordine di arrivo) e `bool _currentFromUser`. Invarianti: **I1** le chiavi di `_user` stanno esattamente in `_pos+1 .. _pos+userAhead`, nell'ordine di `_user`; **I2** la voce corrente non è mai in `_user`. Un `_settle()` privato le ripristina alla fine di ogni operazione che sposta `_pos` o riordina. Getter pubblici `userAhead`, `currentFromUser`.

| Operazione (oggi → dopo) | Dove oggi | Regola nuova |
|---|---|---|
| `append` → `enqueue(id)` | `play_queue.dart:372`, handler `:1735` | inserisce a `_pos+1+userAhead`, aggiunge la chiave a `_user`; coda vuota = `setItems([id])`; più brani = un `enqueue` per brano in ordine (`bulk_actions.dart:129`, `album_detail_screen.dart:238`) |
| `next` | `:194` | la testa del blocco diventa corrente ed esce dal blocco |
| `previous`, `jumpTo`, giro della radio | `:212`, `:228`, handler `:1587` | `_settle()`: il blocco resta subito dopo il nuovo corrente; saltare dentro il blocco toglie dal blocco quella voce |
| `setItems` su un contesto nuovo | `:122`, handler `:365`, `:452` | `keepUser: true` da `playQueue` (D-488): il blocco torna subito dopo il nuovo corrente; `playStations` (`:382`) lo svuota |
| shuffle acceso/spento | `:68`, `_shuffledFrom :84`, `_restoreNaturalOrder :93` | come oggi + `_settle()`: il blocco non si mescola |
| `move` | `:257` | dentro `[_pos+1, _pos+1+n′]` entra nel blocco, fuori diventa normale (D-487) |
| `removeAt`/`removeId`/`removeTracks` | `:237` | toglie la chiave da `_user`; `_settle()` se era il corrente |
| `insertAt` (Shuffle+, simili) | `:332` | un indice dentro il blocco viene spostato subito dopo il blocco |
| «Svuota» + Annulla | `rebuildUpcoming :272`, `QueueState :6`, `:292,:296` | «Svuota» azzera il blocco; `QueueState` copia `_user` e `_currentFromUser`, Annulla li rimette |
| riavvio | `playback_persistence.dart:11`, `settings_store.dart:306,728,749`, handler `:460` | chiave prefs nuova `lastQueueUser` (quante voci del blocco dopo il corrente ripristinato), assente = 0; il backup copia già tutte le prefs (`backup_service.dart:56`): formato invariato |
| Jam | `player_providers.dart:383,389`, handler `:1818`, `jam_local_queue.dart:44,89` | nessun cambio di codice |

- **Shuffle+** (`insertion_plan.dart:11`, `shuffle_plus_controller.dart:291-303,396,415,464`, `shuffle_host.dart:42`): `plusPlan` riceve `skip = userAhead` e pianifica dopo il blocco; le voci del blocco non contano come ascolti della libreria. D-489: un brano della libreria saltato prima degli ultimi 3 s restituisce il suo conto (`_played - 1`); un brano del blocco non conta; `_followCurrent` si ripete subito prima del piano (chiude la corsa con lo skip). Il test `insertion_plan_test.dart:38` cambia nome («una lunga serie di brani ascoltati…»), l'asserzione resta.
- **Simili da Cerca** (`similar_queue.dart:169`): inseriscono già in fondo, quindi dopo il blocco; nessun cambio.
- **Foglio della coda** (`queue_sheet.dart:55,183,238`): legge `handler.userAhead` accanto a `currentIndex`; con `n > 0` intestazione nuova `queueUpNext` («Prossimi in coda») sopra il blocco e `queueThen` («Poi») sopra la voce `n`; con `n = 0` resta `queueNext` («Prossimi») come oggi (D-495).
- **Via «Riproduci dopo»**: `track_actions.dart:255-261,595-605`, `bulk_actions.dart:111-125`, `PlayerController.playNext`/`playOnlineNext` (`player_providers.dart:382-386,525-531`), `CodecoreAudioHandler.playNext` (`:1727-1733`), `PlayQueue.insertNext` (`:313`), chiavi ARB `playNext`, `playNextDone`, `playNextMany` in 6 lingue. Android Auto, MPRIS e SMTC non lo espongono (verificato).

### Percorso a piccoli passi (ognuno lascia l'app funzionante)
1. Via «Riproduci dopo» (UI, metodi, ARB, test).
2. Caratterizzazione senza toccare il prodotto: passeggiata casuale a semi fissi su `PlayQueue` con l'impronta di `items` + `currentIndex` dopo ogni passo; vecchio salvataggio senza `lastQueueUser`; «Svuota» + Annulla.
3. Blocco in `PlayQueue` (senza UI), con i test delle regole e I1/I2 controllate nel test a operazioni casuali.
4. Gestore e persistenza (`userAhead`, `restore`, `lastQueueUser`, D-488).
5. Intestazione nel foglio della coda + ARB.
6. Shuffle+ (`skip` nel piano, correzione di `_played`, D-489): prima un test rosso.

### Mockup approvati (D-498)
`mockup/titoli.html` (D-486), `mockup/libreria.html` (D-484, D-485), `mockup/playlist-ricerca.html` (D-490), `mockup/coda.html` (D-487..D-489, D-492..D-496). Stile e token: quelli approvati in D-408, nessuna direzione estetica nuova.

## Rete (giro 4)
Base verde prima di ogni passo: `flutter test test/services/audio/play_queue_test.dart test/services/audio/gapless_handler_test.dart test/providers/play_online_test.dart test/providers/play_online_jam_test.dart`. Già esistenti da riusare: `normalize`/`stripDiacritics` (`lib/core/text_utils.dart:30`) e la ricerca senza accenti degli artisti (`lib/data/repositories/library_search.dart:42-49`, test `library_search_test.dart:77`).

| Parte | Caratterizzazione PRIMA | Test nuovi (uno per comportamento) | Test da aggiornare | Comando mirato |
|---|---|---|---|---|
| A · via «Riproduci dopo» | nessuna (il comportamento sparisce) | nessuno | togliere `play_queue_test.dart:115,122`; sostituire `insertNext`/`playNext` con `append`/`insertAt` in `play_queue_test.dart:160,199,292,319`, `gapless_handler_test.dart:75,144,154`, `play_online_test.dart:93-96,313,317`, `play_online_jam_test.dart:98,100,158`; fake di `online_song_row_test.dart:50`; menu in `track_actions_test.dart`, `menus_characterization_test.dart`, `all_tracks_screen_test.dart:89`, `selection_bar_test.dart:181` | `flutter test test/services/audio/play_queue_test.dart test/services/audio/gapless_handler_test.dart test/providers/play_online_test.dart test/providers/play_online_jam_test.dart test/ui/online_song_row_test.dart test/ui/track_actions_test.dart test/ui/menus_characterization_test.dart test/ui/all_tracks_screen_test.dart test/ui/selection_bar_test.dart` |
| B · blocco in coda | `test/services/audio/play_queue_characterization_test.dart`: passeggiata casuale a semi fissi (5 × 200 operazioni senza `append`) con l'impronta `items`+`currentIndex` incollata; in `playback_persistence_test.dart` un salvataggio senza `lastQueueUser` si ripristina come oggi («Svuota»+Annulla è già in `play_queue_test.dart:313-358`) | in `play_queue_test.dart`: FIFO; più brani in fondo al blocco; shuffle on/off; `next`; `previous` (D-493); `jumpTo` oltre (D-494); `move` dentro/fuori; `removeAt`; `insertAt` dentro → dopo; Svuota+Annulla; Ripeti tutto (D-492); I1/I2 asserite a ogni passo del test a operazioni casuali. Handler: `keepUser` (D-488), radio svuota (D-496). `jam_exit_restore_test.dart`: ospite ritrova l'ordine. Persistenza: `lastQueueUser`. Foglio: con blocco due intestazioni, senza blocco `queueNext` | `play_queue_test.dart` (`append` → `enqueue`: «va in fondo» cambia), `queue_provider_test.dart` se usa `append` | `flutter test test/services/audio/play_queue_test.dart test/services/audio/play_queue_characterization_test.dart test/services/audio/codecore_audio_handler_test.dart test/services/audio/playback_persistence_test.dart test/providers/queue_provider_test.dart test/providers/jam_exit_restore_test.dart test/ui/queue_incoming_test.dart test/ui/queue_reorder_test.dart test/ui/jam_queue_sheet_test.dart test/goldens/player_golden_test.dart` |
| C · Shuffle+ | `insertion_plan_test.dart:38` esiste (rinominato, asserzione uguale) | prima un test **rosso** in `test/providers/shuffle_plus_test.dart`: skip di un brano della libreria prima degli ultimi 3 s non avvicina il suggerito; un brano del blocco non conta; `plusPlan(skip: n)` in `insertion_plan_test.dart` | fake di `ShuffleHost` in `shuffle_plus_test.dart:63`, `shuffle_plus_source_change_test.dart:24` | `flutter test test/services/shuffle_plus test/providers/shuffle_plus_test.dart test/providers/shuffle_plus_config_test.dart test/providers/shuffle_plus_pending_provider_test.dart test/providers/queue_provider_test.dart` |
| D · titoli che scorrono | un test che fissa il titolo lungo con «…» nel player e nel mini player (se `mini_player_test`/`now_playing_test` non lo fanno già) | `test/ui/marquee_text_test.dart`: titolo corto fermo; lungo scorre dopo 2 s; movimento ridotto fermo con «…»; etichetta col titolo intero; il tocco arriva al genitore; animazione ferma a schermata coperta | golden con titoli lunghi se ci sono; overflow a 200 % del mini player (`ui_fluida_golden_test.dart:50-53`) | `flutter test test/ui/marquee_text_test.dart test/ui/mini_player_test.dart test/ui/now_playing_test.dart test/ui/now_playing_reduce_motion_test.dart test/ui/a11y_guidelines_test.dart test/ui/jam_screen_test.dart test/goldens/player_golden_test.dart test/goldens/ui_fluida_golden_test.dart` |
| E · Libreria e Statistiche | `stats_screen_test.dart` e `home_screen_test.dart` fissano già schermata e porta in Home | `track_repository_test.dart`: lo stream nuovo (righe `kind=1`/`kind=2`, preferito e playlist intelligente contano come «senza playlist», playlist normale esclusa, fuori dalla cartella download esclusa); `all_tracks_screen_test.dart`: la sorgente nuova; `settings_index_test.dart`: voce Statistiche | `library_screen_test.dart:659-690` (blocchi della griglia), golden di Libreria e Impostazioni (`screens_golden_test.dart:45`) | `flutter test test/data/track_repository_test.dart test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/settings_index_test.dart test/ui/stats_screen_test.dart test/ui/home_screen_test.dart test/goldens/screens_golden_test.dart` |
| F · ricerca e accenti | in `track_repository_test.dart` un test che fissa la ricerca di oggi («e» non trova «é»), da cambiare insieme al codice | filtro (titolo/artista/album, maiuscole e accenti) in `test/core/text_utils_test.dart`; dettaglio playlist: tocco su un risultato suona tutta la playlist da lì, riordino spento, rimozione con l'indice originale; playlist intelligente col campo (`smart_playlists_test.dart`); Libreria: «e» trova «é» | `playlist_sort_test.dart`, `library_screen_test.dart:472` se cambia il layout | `flutter test test/core/text_utils_test.dart test/data/track_repository_test.dart test/data/library_search_test.dart test/ui/collection_pages_test.dart test/ui/smart_playlists_test.dart test/ui/playlist_sort_test.dart test/ui/settings_and_playlists_test.dart` |

### Metriche di arrivo
| Metrica | Soglia | Comando |
|---|---|---|
| «Riproduci dopo» sparito | 0 righe | `grep -rniE "playNext\|playOnlineNext\|insertNext" lib test` |
| Statistiche fuori dalla Libreria | 0 righe | `grep -rn "StatsScreen" lib/ui/screens/library` |
| Niente testo che scorre nelle liste | 0 righe | `grep -rn MarqueeText lib/ui/widgets/track_row.dart lib/ui/screens/now_playing/queue_sheet.dart` |
| Invarianti del blocco | 0 violazioni su tutti i semi | test a operazioni casuali di `play_queue_test.dart` |
| Comportamento della coda senza aggiunte | impronta identica | `play_queue_characterization_test.dart` senza modifiche dopo il passo 2 |
| Prestazioni delle query (50k brani) | dentro le soglie già presenti | `flutter test test/data/performance_50k_test.dart` con la misura della lista nuova e della ricerca senza accenti |
| Scatti nello scroll e col player aperto (Mi A3) | ≤ valori della fase 90 (1–2 % dei frame) | `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label <l> --playback` (prima e dopo) |

### Comportamento invariato
- **Jam**: `flutter test test/jam test/providers/jam_*_test.dart test/ui/jam_*_test.dart` verde senza modifiche ai test; `git diff --stat origin/master -- lib/services/jam lib/providers/jam*` vuoto, salvo il titolo che scorre in `jam_player.dart`.
- **DB e backup**: `git diff origin/master -- lib/data/db/tables.dart lib/services/backup` vuoto; `schemaVersion` invariato; test di migrazione e backup verdi senza modifiche.
- **Statistiche**: schermata, query (`stats_queries`) e blocco in Home invariati; cambia solo la porta (D-484).
- **Righe delle liste**: restano con «…»; il mini player si scorre col dito come oggi.
- **Coda senza aggiunte dell'utente**: impronta della caratterizzazione identica.
