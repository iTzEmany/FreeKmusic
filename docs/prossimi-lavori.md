# Prossimi lavori (backlog, riordinato il 10 nov 2026)

Solo ciò che è ancora aperto, per area (le stesse di [`architettura/`](architettura/00-panoramica.md)). Le voci fatte o chiuse sono nella storia (`storico/`, `storico/PROGRESS.md`). Una voce che diventa lavoro vero diventa una fase in `docs/fasi/`.

## Da fare subito (richieste dell'11/11)
- Fasi 117–121 chiuse (117 «Ripristino completo», 118 «Guardrail e correzioni», 119 «Ritocchi e 1.6.0», 120 «CI Windows», 121 «Test di sistema») e fase 122 «CI di tutti i sistemi» fatta; versione 1.6.0 rilasciata (tag e Release dopo il merge). Prossimi: le voci aperte qui sotto per area, in particolare «Qualità e rilascio».
- **Feature «Libreria leggera, karaoke, Cerca con le classifiche, comandi multimediali»** (kickoff del 15/11): fasi 123–129 in [`fasi/`](fasi/README.md), specifica in [`storico/feature/feature-libreria-leggera-karaoke-cerca.md`](storico/feature/feature-libreria-leggera-karaoke-cerca.md). La voce «`KEYCODE_MEDIA_PAUSE` a musica in pausa la fa ripartire» è passata nella fase 123 (R-227).

- **Feature «Video karaoke, aggiornamento dall'app, rilascio 1.6.3»** (kickoff del 18/11): fasi 131–133 in [`fasi/`](fasi/README.md), specifica in [`storico/feature/feature-karaoke-video-e-aggiornamenti.md`](storico/feature/feature-karaoke-video-e-aggiornamenti.md), mockup in [`storico/feature/mockup-karaoke-video-e-aggiornamenti.html`](storico/feature/mockup-karaoke-video-e-aggiornamenti.html), decisioni D-631..D-651.

- **Grande revisione** (22/11, D-662..D-699, analisi in [`refactor/grande-revisione/analisi.md`](refactor/grande-revisione/analisi.md), rete di test in [`rete.md`](refactor/grande-revisione/rete.md)): fasi 135-147 in [`fasi/`](fasi/README.md), una per riga:
  - ~~Fase 135 «riproduzione affidabile»~~ fatta (#210): [`storico/fasi/fase-135-riproduzione-affidabile.md`](storico/fasi/fase-135-riproduzione-affidabile.md)
  - Fase 136 «arricchimento unico»: [`fasi/fase-136-arricchimento-unico.md`](fasi/fase-136-arricchimento-unico.md)
  - Fase 137 «backup, ripristino, aggiornamento»: [`fasi/fase-137-backup-ripristino-aggiornamento.md`](fasi/fase-137-backup-ripristino-aggiornamento.md)
  - Fase 138 «ritocchi di UI»: [`fasi/fase-138-ritocchi-ui.md`](fasi/fase-138-ritocchi-ui.md)
  - Fase 139 «stato del brano e download»: [`fasi/fase-139-stato-brano-download.md`](fasi/fase-139-stato-brano-download.md)
  - Fase 140 «streaming per prima»: [`fasi/fase-140-streaming-per-prima.md`](fasi/fase-140-streaming-per-prima.md)
  - Fase 141 «collezioni»: [`fasi/fase-141-collezioni.md`](fasi/fase-141-collezioni.md)
  - Fase 142 «Riprendi a griglia»: [`fasi/fase-142-riprendi-a-griglia.md`](fasi/fase-142-riprendi-a-griglia.md)
  - Fase 143 «registro e segnalazioni»: [`fasi/fase-143-registro-e-segnalazioni.md`](fasi/fase-143-registro-e-segnalazioni.md)
  - Fase 144 «modelli e dizionari»: [`fasi/fase-144-modelli-e-dizionari.md`](fasi/fase-144-modelli-e-dizionari.md)
  - Fase 145 «condivisione esterna»: [`fasi/fase-145-condivisione-esterna.md`](fasi/fase-145-condivisione-esterna.md)
  - Fase 146 «sincronizzazione tra dispositivi»: [`fasi/fase-146-sincronizzazione-dispositivi.md`](fasi/fase-146-sincronizzazione-dispositivi.md)
  - Fase 147 «verifica finale sul telefono»: [`fasi/fase-147-verifica-finale.md`](fasi/fase-147-verifica-finale.md)

## Libreria e dati
- **Database più nuovo dell'app** (6 nov, fase 88): se si installa sopra un APK più vecchio, drift chiama `onUpgrade(from > to)`, salta le migrazioni e abbassa `user_version`; al prossimo aggiornamento le migrazioni ripartono su colonne già presenti e l'app va in crash. Rimedio: una guardia `from > to` in `onUpgrade`/`beforeOpen` di `app_database.dart`, con un messaggio chiaro. Il ripristino è già protetto (88.5b).
- **`m.createIndex` prima della v15 senza IF NOT EXISTS** (6 nov): dopo un ritorno a una build più vecchia e un nuovo aggiornamento l'avvio fallisce. Rimedio: un helper unico per gli indici con IF NOT EXISTS.
- **Una sola chiave per «stesso brano»** (6 nov): `LibraryIndex` e `LibraryOverlap` usano `libraryTitleKey` più le parole dell'artista; `TrackResolver`, `SeedIndex.keyOf`, `import_diff` e `playlist_import_service` usano `matchTitleKey` più l'artista principale. Unificarle evita che la sincronizzazione delle playlist riaggiunga un brano già collegato.
- **Credito annidato troppo largo** (6 nov): «Prince» contro «Prince Royce», stesso titolo e durata entro 5 s, risulta posseduto (raro). Rimedio: l'artista più corto deve essere prefisso dell'altro e avere almeno 2 parole non comuni.
- **Remaster con live** (6 nov): «Song (Remastered Live)» e «Song - 2011 Remaster - Live» coincidono con «Song» perché `_remasterGroup`/`_remasterTail` in `matchTitleKey` tolgono anche «Live».
- **Parentesi non chiuse** (6 nov): «Song (Deluxe Edition» non viene ripulito (falso negativo, innocuo).
- **Cache dei paesi divisa** fra la closure di `watchByRules` e `_watchWithCountries` (6 nov, bassa). Rimedio: una `CountryArtistsCache` in `rule_country.dart`.
- **Nomi paralleli della chiave artista** (6 nov): `artistCountryKey` → `ArtistInfoRepository.keyOf` → `artistKey`; `_artistKey` di `stats_queries.dart` è un'altra chiave (minuscole ASCII come `lower()`). Rimedio: rinominarla `_libraryNameKey` e togliere gli alias.
- **`spellingsOf`** fa `SELECT DISTINCT artist` su tutta la tabella a ogni apertura della pagina artista e vive in `services/library/rules` ma lo usa il repository (6 nov). Rimedio: spostarlo in `data/repositories` con una cache come `libraryIndexProvider`; `artistAllSongsProvider` legge i brani locali una volta sola.
- **SQL della copertina automatica ripetuto** in `memory_queries.dart` e `playlist_repository.dart` (7 nov, fase 103): una costante condivisa.
- **`FollowRepository.watchNames`** ricostruisce tutta la mappa nomi a ogni scrittura su `artist_lookups`/`followed_artists` (Artisti uniti si ridisegna durante l'arricchimento). Rimedio: limitarla agli ID uniti o «diversi», o `.distinct`.
- **Rilettura dei generi ferma mentre suona** (D-390): per chi ascolta quasi sempre può non finire mai. Rimedio: dopo N giorni leggere a basso ritmo anche durante la riproduzione.
- **Dopo «Elimina dal dispositivo»** `files/downloads.json` tiene la voce del brano cancellato (10 nov, scheggia 116): capire se si pulisce da sola, altrimenti toglierla alla cancellazione.
- **Orfani di testi** (7 nov): `unsyncedLyrics`, `manualRomanization`, `handWrittenLyrics` non vengono mai potati (solo crescono); l'unione dei doppioni (`duplicate_repository._mergeTrackFields`) sposta il testo senza traslitterazione a mano né segni.

## Riproduzione e coda
- **Crossfade sul Mi A3 (Android 11)** (27 ott): dopo alcuni cambi `AudioEffect: set/get parameter error` e il cambio ripiega sul caricamento normale (gap ~530 ms). Da capire con un log del player (fase 57, «Note»).
- **Pausa a volume zero in secondo piano** (10 nov): il tasto «volume su» la fa ripartire solo entro circa 2 s, poi Android lo manda alla suoneria. Valutare se tenere attiva la sessione multimediale più a lungo, o scriverlo nella descrizione dell'impostazione.
- **Scatti dopo la fase 113** (`refactor/coda-e-libreria/misure.md`, «Dopo la 113»): «Apri album» 11 → 17 %, «In riproduzione» 2,4 → 5–6 %, «Pallino schede» 7 → 9–10 % rispetto a prima-107. Profilare (`flutter run --profile`, DevTools) il titolo che scorre in Now Playing, i listener nuovi della radice e la pagina album.
- **`queueProvider`** combina indice, chiavi e `userAhead` letti dal vivo con una lista asincrona: per qualche ms può non combaciare; `queueTracks` scarta gli id che non trova e sfasa l'indice. Più robusto: uno snapshot `(tracks, keys, currentIndex, userAhead)`.
- **`_settle`** ricostruisce una mappa e due liste grandi quanto la coda a ogni next/jumpTo/move/previous mentre il blocco non è vuoto. Rimedio: via veloce se `_user` sta già subito dopo il corrente.
- **Shuffle+**: arrivo per (id, `currentFromUser`) non distingue due copie dello stesso id di fila (chiave della voce da `ShuffleHost`); `currentFromUser` non è salvato (dopo un riavvio un corrente nato dal blocco conta una volta); il controller ha ancora il suo giro radio (`_take`/`_fill`), non passa da `RadioFill`.
- **Blocco «in coda»**: `playQueue(keepUser)` suona due volte un brano toccato che sta anche nel blocco; in `move` una voce del blocco non si può lasciare come prima sotto «Poi».
- **`listPlayingProvider`** copia `sourceIds`, fa `listEquals` e calcola gli hash dell'intera sorgente per ogni pill visibile a ogni evento della coda. Rimedio: tenere l'hash della sorgente nel controller. **`listKeyOf`** usa il contenuto: aggiungere un brano a una playlist azzera la sua modalità Casuale (le chiavi non sono salvate); `_modeOf` in `shuffle_button.dart` → `listShuffleModeProvider(key)`.
- **`player_providers.dart`** (1039 righe) ha un ciclo d'import con `shuffle_plus_providers`. Rimedio: estrarre `SimilarSession` in `services/shuffle_plus/`, spostare `similarFillProvider`/`libraryMatchIdProvider` in `similar_providers.dart`, `playFromSearchNotice`/`playFromSearchAndOpen` in un file di Cerca. Doppia logica «id locale»: `_idOf` e `_similarId` (un parametro su `_idOf`).
- **File da spezzare** (rinviato, rischio medio senza guadagno di comportamento): `play_queue.dart`, `queue_sheet.dart`, `shuffle_plus_controller.dart`.
- **Simili da Cerca**: un brano della libreria senza abbinamento sicuro su YouTube Music (`SeedResolver`, esito negativo in `SeedIndex`) dà «Nessun brano simile» anche con la rete; ripiego su un seme dal primo risultato o «Brano non trovato su YouTube Music».
- **Brani dell'artista in libreria da due fonti**: scaffale «Dai tuoi» e `LibraryOverlap` per una sola grafia (`watchArtistTracks`), Play/Shuffle per tutte (`tracksOfArtist`); `artistAllSongsProvider` rifà la mappa titolo → brano. Rimedio: `watchArtistTracks` per chiave con `spellingsOf` e `LibraryOverlap.trackFor(r)`.
- **Copia di `audio_service` in `third_party/`** (16 nov, review della fase 123): con `dependency_overrides` né `pub outdated` né la CI dicono quando esce una versione nuova (correzioni per Android 14/15 perse in silenzio). Rimedio: uno step o uno script che confronta la versione della copia con l'ultima su pub.dev e avvisa; una riga nelle Trappole di `architettura/riproduzione-e-coda.md`.
- **Stato pubblicato dopo la Jam** (16 nov, review della fase 123): `attachRemote(null)` pubblica `ready` fisso invece di ricavarlo dal player locale come fa l'ascolto del backend (seconda copia della mappatura); anche i `_publish(playbackState.value.processingState)` dopo il parcheggio possono ripubblicare un `idle` vecchio per un attimo. Rimedio: un `_localProcessing()` unico. Da allineare anche D-610 («30 minuti anche in Jam») con D-589 e il codice (non in Jam).

- **Review di fine fase 125 (libreria in streaming)** (16 nov): (a) «cosa suona senza rete» è calcolato in due posti (`_availableIndex`/`_nextFile` nel gestore e `queueOfflineOutProvider`) e divergono sugli episodi http; `_availableIndex` legge il DB voce per voce a ogni salto. Rimedio: un predicato condiviso. (b) Il controllo «modo streaming» è ricopiato in 5 punti della UI e il filtro delle righe del backup è doppio (`backup_queries.dart`, `backup_service.dart`). Rimedio: `isStreamingModeProvider` e `isBackupRow`. (c) `StreamPreparer` ha 4 callback di rete e `_skipBack` è un campo del gestore. Rimedio: `_skipBack` come parametro di `_loadCurrent`. (d) Per la fase 126: la chiave della cache non contiene la qualità, quindi dopo un cambio di qualità si suona il file vecchio.

## Online (arricchimento, testi, riconoscimento, link, podcast, radio)
- **Budget e pausa 429 scritti a mano** fuori da `budgetedYtm` (6 nov): `YtmPodcasts._guarded` (con attesa), `_askCard`/`_fail` di `smart_search`, `second_opinion_providers.dart`. Rimedio: variante con attesa e `tripIfRateLimited(cooldown, e)`. Restano aperte di proposito le pagine degli alias fuori dal budget (D-465) e la chiave propria di `mergeArtistShelves`. `YtmPodcasts._guarded`: `acquire()` attende fino a 60 s senza dirlo all'utente.
- **`mergeArtistWith`** (UI) compone cooldown, limiter e catalogo da sé, come `artistMergeSearchProvider` (la cui cache non ha limite). Rimedio: una ricerca degli artisti con budget in `ArtistMergeOps`.
- **Cerca senza rete** (8 nov, Mi A3): tre volte «Rete non disponibile» e nessuna sezione «Nella tua libreria»; tornata la rete la stessa query resta in errore per più di un minuto (cache dell'errore?).
- **«Non mi piace»** (7 nov): `SuggestionGate` non è l'unico filtro (`artistAllSongsProvider` rifà le regole; `suggestionArtistKey` vive in `suggestion_pool.dart`); «artista di un suggerito» calcolato in tre punti (`primaryArtist(YtResult)` e `SuggestionActions.artistToBlock(queueId)`); tre iscrizioni a `store.changes` (un `dislikesProvider` con istantanea immutabile); `dislikes_screen.dart` scrive sullo store dalla UI (`unblockTrack`/`unblockArtist` in `SuggestionActions`); percorso di `dislikes.json` in tre punti (`DislikeStore.defaultFile(dir)`).
- **Radio**: costruzione di `RadioFill` con `radioOffReason` → `log.load` → `filter.load` in 3-4 copie (`daylist_providers.dart`, `similarFillProvider`, `genreMixProvider`) e `gate.trip()` sul 429 in `genre_mix.dart`/`similar_queue.dart`. Rimedio: `radioFillFor(ref, seeds, inLibrary)` e `RadioFill.take` che fa il trip da solo.
- **Daylist** (8 nov): non si salva mai quando la radio è spenta per un motivo permanente e il seme casuale cambia a ogni build (a ogni avvio nella stessa fascia esce una daylist diversa): salvarla con un flag `partial` o un seme da chiave + `until`. L'avviso «Meno di 15 brani» (D-473) compare solo per la fascia in corso. `musicLight()` porta tutta la libreria nel main isolate e `Isolate.run` la copia a ogni build: da misurare sul Mi A3 con la fixture 50k.
- **Podcast** (7 nov): regola «riga remota di episodio» in più forme (`isRemoteEpisode(Track)`, `TrackKindX.isRemoteEpisode`, un'espressione SQL unica); la riga `tracks` di un episodio si costruisce in tre punti con regole della copertina diverse (`setCoverKey` aggiorna solo `podcasts`, `PodcastOps.save` aspetta la copertina in rete prima del play); il gestore audio conosce la politica dello streaming degli episodi (interfaccia `EpisodeMarks`); `unfollowPodcast` è un flusso di dominio nella UI (`PodcastOps.unfollow(id, deleteDownloads:)`, `showMsg` sull'errore); resta solo la ricerca del foglio «Aggiungi podcast» fuori da `PodcastOps`.
- **Testi traslitterati** (8 nov, fase 106): due giri su NetEase per lo stesso brano (con fonte `netease` salvare `romalrc` in `RomanizationCache`); le «righe come mostrate» si calcolano in 4-5 punti, con un testo CRLF la traduzione tiene un `\r` (`shownLines(plain, synced)` in `lyrics_shown.dart`); `romanization_cache.json` e `cedict/` non compaiono in Memoria né in «Svuota cache» (`AppDataPaths` e pulitore); download verificato duplicato fra `cedict_download` e `yt_dlp_updater` (`downloadVerified(...)`, `downloadDioProvider`); la tile «Scarica» del dizionario carica tutta la mappa solo per verificarla (basta lo sha256).
- **Link e Shazam** (9–10 nov): con il casuale della pagina link acceso, i brani pronti dopo Play vanno comunque in fondo; il timeout della ricerca di un link video sul telefono ha lasciato Cerca vuota (non riprodotto) e il messaggio «non disponibile» riusato per le playlist dice «video»; testo Shazam in arabo («ليلى di فيروز») abbinato a un video con titolo diverso (soglie del `CollectionMatcher` larghe su titoli non latini, da guardare con una fixture); solo testi Shazam it-IT riconosciuti (R-210): si aggiunge una riga per ogni testo vero raccolto.
- **Classifiche: logica nel file dei provider** (16 nov, review di fine fase 124): `_readChart`/`_fetchChart`, JSON e salvataggio degli abbinamenti stanno in `online_collection_providers.dart` (~150 righe) e `chartRefetchProvider` è un `Set` mutabile dentro un `Provider`. Rimedio: un `ChartService` in `services/online/` con un `force` per il ricaricamento. Minori: titolo segnaposto + `withTitle` e `sourceUrl: 'chart:…'` finto; selettore del paese duplicato da quello della radio (`CountryTile` comune); id dei generi come stringhe in 3 mappe (un `enum` darebbe lo switch esaustivo); le classifiche condividono le 60 voci di `CatalogCache` con artisti e album.

## Sync, backup e Jam
- Nessun lavoro aperto in backlog. Le prove a mano rimaste di Jam e broker sono nelle fasi archiviate (`storico/fasi/fase-84-broker-e-debito-jam.md`); su UniBA la scoperta con la maschera vera va riprovata (vedi le Trappole di [`sync-backup-jam.md`](architettura/sync-backup-jam.md)).

## Piattaforme
- **Video karaoke senza librerie** (fase 131): iOS non ha le librerie video; macOS e i pacchetti Linux (AppImage, `.deb`, Flatpak) con `media_kit_video` sono provati solo dalla CI. Da provare a mano. Poi un controllo in CI che la lite non contenga `libmpv.so` e la full sì.
- (10/11) Database desktop in `<Documenti>/codecore.sqlite`, condiviso con Codecore e fuori dalla cartella dell'app: spostarlo in `appSupportDir` con una migrazione all'avvio (copia se manca), poi aggiornare D-539 e `piattaforme.md`.
- **Runtime Flatpak `org.freedesktop.Platform/ffmpeg-full` 24.08 a fine vita**: passare a 25.08.
- **Accessibilità TalkBack, minori** (8 nov, prova fase 105): risultati di ricerca omonimi («Blue In Green, Artista» ×4) senza altro dettaglio; campo di Cerca e campo dell'editor del testo con `content-desc` vuoto (il suggerimento è un nodo a parte); chip del filtro di Cerca con un nodo cliccabile esterno senza etichetta accanto a quello interno.

- **libmpv per Windows con `pan`/`asplit`/`amix`/`lowpass` per il karaoke** (17/11, D-617): quella di `media_kit_libs_windows_audio` 1.0.9 ha `--disable-filters`, quindi il microfono non compare su Windows; con una libmpv che li abbia, abilitare `DesktopVoiceFilter.supported` anche lì.

## UI e design
- **Dialogo dell'icona dopo una cancellazione dei dati** (11/11, prova fase 117 sul Mi A3): dopo `pm clear` l'alias dell'icona resta il vecchio (Arancio) e a ogni avvio compare «Cambiare anche l'icona dell'app?», prima dell'onboarding. Allineare la preferenza all'alias attivo all'avvio.
- **`libraryEntriesProvider`** tiene vive fino a 64 combinazioni (scheda, ordine, verso) che si riordinano sul thread UI a ogni cambio della libreria; tenerle è voluto. Rimedio: tenere viva solo l'ultima combinazione per scheda.
- **`PlaylistOrder.apply`** viene chiamato dentro `build`.
- **`app_fr.arb` con chiavi duplicate** (`dislikeSheet*`, `dislikeArtistDone`, `artistBlockedLabel`, già su master): vale l'ultima, da ripulire.

## Online, video karaoke (fase 131)
- **Dipendenza fra cartelle** online → `karaoke_video` → online: spostare `KaraokeVideoStream` in `online/`, mettere `videoUrl` in `YoutubeService` con default `toolMissing`, togliere `KaraokeVideoSource` e il cast `yt as YtDlpProcessService`.
- **Doppio scarico dello stesso flusso video** (player dall'URL e download in cache): con i dati mobili il traffico raddoppia. Suonare dal file a download finito, o niente cache sui dati mobili.
- **Sequenza Dio + `.part` + rename in tre posti** (`SeparationService`, `JamCache`, `KaraokeVideoCache`): un helper comune.
- **Scadenza ripetuta** per prefisso: `StreamCache.expireEvery(prefix, idle)`.
- **Test con attese reali** in `karaoke_video_cache_test` e `karaoke_video_controller_test`: orologio iniettabile in `StreamCache`, `release()` che restituisce un Future.
- **Costante unica per i 10 s di attesa** (oggi nel gestore e nel controller).
- **Precarico fallito**: non riparte finché il brano resta in coda.
- **Avviso «Video non disponibile»** quando il player si apre con lo stato già `failed`.

## Qualità e rilascio
- **Aggiornamento Android: firma controllata dopo il download** (96 MB scaricati per poi dire «Firma diversa»): confrontare prima la firma installata con quella della Release (certificato noto), se si vuole evitarlo.
- **`StreamCache`**: default del costruttore 500 MB contro impostazione 1024 MB (vale l'impostazione): allineare.
- **Test di poco valore** in `settings_store_test` («blurred dock off by default and kept»): da togliere.
- **Karaoke: ~20 s senza testo** fra il 100 % del download del modello e lo 0 % della separazione (decodifica e caricamento dei modelli): mostrare «Preparo…» (prova sul Redmi, fase 130).
