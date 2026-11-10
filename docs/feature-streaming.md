# Feature «Streaming e coda online»

Si ascolta in streaming tutto ciò che si trova online (un brano, la coda, un album intero, anche nella Jam). Il player si apre in caricamento mentre il brano viene scaricato in una cache su disco e arricchito. La feature porta anche lo shuffle a 3 stati senza interruttore, Play e Shuffle separati in Home e un link per ogni artista ospite.
Per chi: l'utente, su telefono e PC, anche in Jam con gli amici. Perché ora: oggi lo streaming esiste solo per i suggeriti di Shuffle+; il resto della ricerca obbliga a scaricare o a usare l'anteprima con le cuffie.

Kickoff del 2026-10-24 (richiesta originale: `docs/prossimi-lavori.md` §2a). Decisioni: D-61 e seguenti in `docs/decisioni.md`.
Fasi: vedi `docs/PROGRESS.md` (45 e seguenti).

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Tutto vale uguale su Android, Linux e Windows (R-30).

### Streaming di un brano
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-01 | Il tap su un brano online (ricerca, album online, pagina artista online) lo inserisce dopo il brano in corso e lo suona subito; il resto della coda resta dopo. Fa come il tap su un brano di libreria | I | Coda [A*, B], tap sul risultato X → coda [A, X*, B] e X parte appena pronto (test del controller) || 46 |
| R-02 | Si apre in automatico la schermata di riproduzione in stato di caricamento: copertina e titolo del risultato subito, anello che gira; «Caricamento…» anche nel mini player e nella notifica. Abbassando il player resta il mini player | I | Widget test: dopo il tap c'è la NowPlaying con l'indicatore di caricamento; il mini player mostra «Caricamento…» finché lo stato è loading || 46 |
| R-03 | Il brano viene scaricato per intero nella cache di streaming e parte appena il file c'è; l'arricchimento (metadati, testo, curiosità, copertina) gira in parallelo e testo e curiosità compaiono nel player appena arrivano | I | Test: con un downloader finto, la riproduzione parte prima della fine di un arricchimento lento; quando l'arricchimento finisce, il player mostra il testo || 45 |
| R-04 | L'anteprima con le cuffie (ListenButton, listenProvider, backend separato) sparisce del tutto | I | `grep -rn "ListenButton\|listenProvider" lib` = 0 || 46 |
| R-05 | Caricamento fallito (rete, 403, yt-dlp): un solo nuovo tentativo, poi messaggio breve e passaggio al brano successivo (stesso conteggio degli errori consecutivi di oggi) | I | Test: download finto che fallisce 2 volte → un retry, poi skip; dopo `maxConsecutiveErrors` il player va in idle || 45 |
| R-06 | Nel player, un brano in streaming ha «Scarica» nel menu ⋮ | I | Widget test: la voce esiste per un brano in streaming e non per un brano locale || 46 |
| R-07 | Lo streaming funziona anche su rete a consumo; il blocco «solo Wi‑Fi» vale solo per i suggeriti di Shuffle+ | I | Test: con rete a consumo e `shufflePlusUnmeteredOnly` acceso, il tap su un risultato suona; i suggeriti restano bloccati || 45 |

### Cache di streaming
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-08 | La cache su disco ha un limite in MB; superato il limite si cancellano i brani usati meno di recente (LRU). Il brano in corso e i prossimi in coda non si cancellano mai | I | Test: limite 10 MB, 4 file da 4 MB → resta sotto il limite, sparisce il meno recente, mai quello in riproduzione || 45 |
| R-09 | Impostazioni: cursore «Spazio per lo streaming» da 256 MB a 8 GB (di serie 1 GB), con lo spazio usato e il pulsante «Svuota» | I | Widget test del cursore e di «Svuota» (cache vuota dopo, tranne il brano in corso) || 45 |
| R-10 | «Scarica» su un brano già in cache sposta il file (già arricchito) nella cartella della libreria senza riscaricarlo: tag e copertina si scrivono come nei download normali, poi scansione e indice dei download | I | Test: «Scarica» su un brano in cache non chiama il downloader; dopo, il file sta nella cartella dei download e il brano è in libreria con i dati dell'arricchimento || 46 |
| R-11 | I file della cache non compaiono mai in libreria, nella scansione o nei backup | I | Test: la cartella della cache è fuori dalle cartelle della scansione; il backup non la include || 45 |
| R-12 | I brani in streaming (compresi i suggeriti di Shuffle+, D-79) contano in cronologia e statistiche con le stesse regole dei brani locali, anche se non sono in libreria; i blocchi della Home restano di soli brani di libreria (D-83) | I | Test: 2 ascolti in streaming dello stesso brano → compare nella cronologia e nelle statistiche con 2 ascolti || 45 |

### Coda online
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-13 | Lo swipe su una riga online (ricerca, album, artista online) mette il brano in fondo alla coda, come per i brani locali; vale la zona esclusa dal bordo (D-59) | I | Widget test: lo swipe su `OnlineSongRow` chiama l'accodamento; uno swipe che parte dal bordo non lo fa || 46 |
| R-14 | I brani online in coda si scaricano in cache in ordine di coda, al massimo 2 download insieme; partono appena il brano entra in coda. Su Wi‑Fi si prepara tutta la coda, su rete a consumo solo i prossimi 3 (D-78) | I | Test: 4 brani in coda → al massimo 2 download attivi, nell'ordine della coda; con rete a consumo e 10 brani online se ne preparano 3 || 45 |
| R-15 | A fine brano parte il successivo; se non è ancora pronto il player resta in caricamento finché lo è (con il limite di R-05) | I | Test: brano B ancora in download a fine A → stato loading, poi B parte da solo quando il file c'è || 45 |
| R-16 | Righe online (ricerca, album, artista online): tap = streaming, swipe = in coda, menu ⋮ completo come i brani locali (Riproduci dopo (tolto, D-487), In coda, Aggiungi a playlist, Scarica, Vai all'artista), resta il pulsante scarica | I | Widget test del menu ⋮ su una riga online || 46 |
| R-17 | «Aggiungi a playlist» su un brano online lo scarica in libreria e poi lo aggiunge alla playlist (le playlist restano di soli brani locali) | I | Test: aggiungi a playlist di un brano online → download (o spostamento dalla cache, R-10) e poi la riga in playlist || 46 |

### Album online
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-18 | La testata di un album online mostra solo Play e Shuffle. Play sostituisce la coda con l'album in ordine; Shuffle lo mescola (shuffle normale, mai Shuffle+). Il player si apre in caricamento finché non parte il primo brano | I | Widget test: Play → coda = brani dell'album nell'ordine, player in caricamento; Shuffle → shuffle acceso, modalità plus non attiva || 46 |
| R-19 | Il menu ⋮ della testata ha: Scarica album (come oggi), Metti in coda l'album, Aggiungi a playlist (scarica e aggiunge, R-17), Condividi (link dell'album) | I | Widget test: le 4 voci esistono e chiamano le azioni giuste || 46 |

### Jam
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-20 | Host e ospiti mettono in coda nella Jam brani online: chi li trova li scarica nella sua cache e li serve agli altri come i file della libreria. Il brano compare nella coda condivisa quando il file è pronto, nell'ordine delle aggiunte (D-80) | I | Test di integrazione Jam (host+ospite in memoria): l'ospite accoda un brano online, l'host lo riproduce leggendo il file dalla cache dell'ospite || 47 |
| R-21 | Se chi ha accodato un brano online esce dalla Jam prima che suoni, il dispositivo che fa da uscita lo scarica da YouTube per conto suo | I | Test: proprietario uscito → l'uscita risolve il brano dall'id YouTube e lo scarica nella sua cache || 47 |
| R-22 | Via il pulsante «aggiungi brani». In Jam lo swipe e «In coda» (libreria e online) vanno nella coda condivisa; con la Jam vuota un testo guida dice «Metti in coda dalla libreria o dalla ricerca» | I | Widget test: niente FAB in JamScreen; con Jam attiva lo swipe chiama `jam.add`; testo guida a coda vuota || 47 |
| R-23 | Il tap su una riga della Jam apre, per host e ospiti, la schermata del brano (copertina, testo, curiosità, artisti); l'host salta al brano dal menu ⋮ della riga o dal pulsante nella schermata | I | Widget test: tap su riga → schermata info, per entrambi i ruoli; «Salta qui» solo per l'host || 47 |
| R-24 | Copertina, testo e curiosità di un brano di un altro dispositivo si chiedono al proprietario con una richiesta Jam nuova; se non risponde (vecchio APK, uscito) si mostrano i dati di base | I | Test della rotta nuova sull'host e del ripiego sui dati di base || 47 |

### Shuffle a 3 stati
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-25 | Il pulsante shuffle cicla nessuno → shuffle → Shuffle+ → nessuno, senza bisogno dell'interruttore nelle impostazioni (la modalità si salva come oggi). Se la coda non permette Shuffle+ (album in streaming, Jam, radio, meno di 5 brani locali) il ciclo salta lo stato plus, con un breve messaggio la prima volta che spiega perché | I | Test di `cycleShuffle`: con coda di album online il ciclo è off→shuffle→off; con coda locale ≥ 5 arriva a plus || 48 |
| R-26 | Attivando Shuffle+ a coda in corso, i suggeriti entrano subito nel piano: uno ogni N brani (N dalle impostazioni) a partire dal brano corrente, quindi il primo dopo N brani | I | Test: coda di 20 brani locali, posizione 5, N=4 → suggeriti inseriti alle posizioni previste senza aspettare il cambio di brano || 48 |
| R-27 | Spegnendo Shuffle+ si tolgono dalla coda i suggeriti non ancora suonati | I | Test: plus → off toglie i suggeriti dopo il corrente e lascia gli altri || 48 |
| R-28 | Impostazioni: via l'interruttore Shuffle+; al suo posto la nota «Si attiva dal pulsante shuffle (terzo tocco). Non disponibile per album in streaming, Jam e radio»; restano intervallo e «solo Wi‑Fi». Il foglio Shuffle+ (pressione lunga) segue lo stesso schema | I | Widget test: nessuno `SwitchListTile` per `shufflePlus`; la nota è presente || 48 |
| R-29 | I suggeriti di Shuffle+ (che vengono dalla radio di YouTube Music) usano la stessa cache su disco con arricchimento; il vecchio percorso a indirizzo diretto (StreamAddressCache) si toglie | I | Test: un suggerito passa dal downloader della cache; `grep -rn StreamAddressCache lib` = 0 || 45 |

### Home e artisti
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-30 | Comportamento uguale su Android, Linux e Windows | I | I test sono indipendenti dalla piattaforma; prova a mano su Linux e Mi A3 || 45–49 |
| R-31 | Home, blocco «Casuale su tutto»: pulsante Play e pulsante shuffle separati. Lo shuffle è lo stesso pulsante a 3 stati del player e decide solo l'ordine (non avvia nulla); Play avvia tutta la libreria in quell'ordine | I | Widget test: il tocco su shuffle cambia la modalità senza avviare; Play avvia `playAll` con la modalità scelta || 48 |
| R-32 | Brano con più artisti: nel player e nella barra desktop ogni nome è un link separato («A, B feat. C») | I | Widget test: 3 artisti → 3 zone toccabili, ognuna apre la pagina giusta || 49 |
| R-33 | Voce ⋮ «Vai all'artista» (menu dei brani, schermata Jam): con un artista apre la pagina; con più artisti apre un foglio di scelta | I | Widget test del foglio con 2+ artisti || 49 |
| R-34 | Risoluzione del link: prima la libreria (artista con lo stesso nome normalizzato), altrimenti la pagina online. Se la ricerca online trova più artisti simili, si sceglie fra i primi 3; se non ne trova, un messaggio. I brani online usano gli id degli artisti di YouTube Music quando ci sono | I | Test della risoluzione: libreria, online esatto, scelta, nessuno || 49 |

## Requisiti non funzionali
| ID | Requisito | Misura |
|---|---|---|
| RNF-01 | Nessun peggioramento della fluidità rispetto alle misure finali della fase 44 (apertura del player, liste, cambio di brano), con tolleranza di un frame per scenario (D-85) | `scripts/perf_device.py` sul Mi A3, confronto con `docs/refactor/ui-fluida/misure.md` «Finale» |
| RNF-02 | Download, arricchimento e gestione della cache fuori dal thread UI | review del codice; nessun I/O sincrono nei widget |
| RNF-03 | I download di oggi (brano, album, import di playlist) restano invariati | test esistenti di download e import verdi |

## Fuori perimetro
- Playlist con brani online non scaricati (D-65: aggiungere = scaricare).
- Link agli artisti nel mini player (non richiesto).
- Compatibilità della Jam con APK precedenti: non è un requisito (D-71). Si mantiene dove non costa nulla (campi sconosciuti tollerati).

## Architettura
Approvata dall'utente il 2026-10-25 (D-77…D-81). Idea guida: **un solo percorso per l'audio online** (ricerca, album, coda, Jam, suggeriti, radio di YouTube Music) = scarica il file intero in una cache su disco, poi lo suona come un file locale. Il vecchio indirizzo diretto (`StreamAddressCache`) sparisce (R-29).

### Identità di un brano online
- Chiave: `YtResult.indexKey` (`downloadIndexKey(source, videoId)`, quella di `DownloadIndex`). Vale in coda, cache, Jam e cronologia.
- In coda resta l'id negativo di `OnlineEntries` (come i suggeriti di oggi): `PlayQueue` non cambia. `OnlineEntry` guadagna `trackId?` = la sua **riga ombra** (sotto).
- Se la chiave è già in `DownloadIndex` (brano già scaricato in libreria) il tap suona il brano di libreria: niente cache.

### Componenti
| Componente | Nuovo / cambia | Responsabilità | Dipende da | Cartella |
|---|---|---|---|---|
| `StreamCache` | nuovo | File in `<appSupportDir>/stream_cache/<chiave>.<ext>`; `fileFor(chiave)`, `put`, `touch` (data di modifica = ultimo uso: niente indice da salvare), `pin`/`unpin`, `evict()` LRU fino al limite, `clear()`, `usedBytes`. All'avvio: cancella i `.part`, misura la cartella | `dart:io`, impostazione `streamCacheMb` | `lib/services/stream/` |
| `StreamPreparer` | nuovo | Guarda la coda (corrente + successivi online) e scarica in ordine di coda, **max 2 insieme**; un solo download per chiave; 1 nuovo tentativo poi errore (R-05); a file pronto crea/aggiorna la riga ombra e lancia l'arricchimento; espone `Future<File> ready(chiave)` e lo stato per riga | `YoutubeService.download` (stesso yt-dlp dei download), `StreamCache`, `TrackRepository`, `EnrichmentService` | `lib/services/stream/` |
| Riga ombra | nuovo uso di `tracks` | Una riga `tracks` con **`kind = 2`** (brano in streaming), `folderId = null`, `path = 'stream:<chiave>'` (UNIQUE: la ricerca per chiave usa l'indice esistente). Porta conteggi, cronologia e arricchimento (testo, curiosità, `coverKey`) | `TrackRepository` | `lib/data/repositories/` |
| `CodecoreAudioHandler` | cambia | `_loadCurrent`: per un'entry online o una riga `kind = 2` → `await preparer.ready(chiave)` restando in `loading`, poi `_backend.load(file)`. `_loadStream` e `addresses` si tolgono. Conteggio ascolti e cronologia anche per l'online (via `trackId` ombra) | `StreamPreparer` | `lib/services/audio/` |
| `EnrichmentService` | invariato | `propose(Track sintetico)` parte con il download; `apply(proposta, trackId ombra)` quando c'è la riga. Nessun tag scritto nel file in cache | — | — |
| `StreamPromoter` | nuovo | «Scarica»/«Aggiungi a playlist» su un brano in cache: copia (o `rename` se stesso volume) nella cartella dei download, `DownloadIndex.add`, aggiorna la riga ombra (`path` reale, `kind = 0`, `folderId`) **prima** della scansione, così la scansione la ritrova per percorso; poi `DownloadTagger` scrive tag e copertina come oggi (R-10, R-17) | `StreamCache`, `DownloadIndex`, `TrackRepository`, `DownloadTagger`, scansione | `lib/services/stream/` |
| `DownloadsNotifier` | cambia poco | «Scarica» chiede prima a `StreamPromoter`; se non c'è il file, il percorso di oggi (RNF-03) | `StreamPromoter` | `lib/providers/youtube_providers.dart` |
| `PlayerController` | cambia | `playOnline(result)` = registra, inserisce dopo il corrente, salta lì, apre NowPlaying (R-01, R-02); `enqueueOnline`, `playOnlineList(list, shuffle)` per l'album (R-18); in Jam l'accodamento va a `jam.add` (R-22) | `OnlineEntries` | `lib/providers/player_providers.dart` |
| Righe online | cambiano | `OnlineSongRow`: tap = `playOnline`, swipe = `enqueueOnline` (zona del bordo D-59), menu ⋮ completo. Via `ListenButton`/`listenProvider`/`preview_player.dart` (R-04) | `PlayerController` | `lib/ui/screens/online/` |
| Jam | cambia | `JamItem.ref = 'yt:<chiave>'` per i brani online + campo nuovo `videoId` (visibile a tutti); `_localFile` del proprietario risolve `yt:` da `StreamCache`; l'uscita senza proprietario usa `StreamPreparer` (R-21); rotta nuova `GET /<sid>/meta/<itemId>` che risponde un `TrackMeta` (fase 37) (R-24) | `StreamPreparer`, `TrackMeta` | `lib/services/jam/`, `lib/providers/jam_providers.dart` |
| Shuffle | cambia | `cycleShuffle` salta plus se la coda non lo permette (funzione pura `plusAllowed(queueIds, jam, radio, localCount)`); `ShufflePlusController` inserisce subito / toglie i suggeriti non suonati (R-25…R-27) | — | `lib/providers/player_providers.dart`, `lib/services/shuffle_plus/` |
| Artisti | cambia | `splitArtists(track/result)` da `query_cleaner` (`_artistSplit` reso pubblico); `ArtistLinkResolver`: libreria per nome normalizzato → `pickYtmArtist` (primi 3) → messaggio (R-32…R-34) | `ytm_artist_resolver.dart` | `lib/services/online/`, `lib/ui/widgets/` |

### Flussi
**(a) Tap su un risultato.** `OnlineSongRow` → `PlayerController.playOnline(r)` → `OnlineEntries.register` → coda `[A, X*, B]` → NowPlaying aperta (titolo e copertina del risultato, anello) → `_loadCurrent` pubblica `loading` → `StreamPreparer` scarica X (priorità al corrente) e intanto `propose()` → file pronto: `StreamCache.put`, riga ombra creata, `_backend.load(file)` → suona → `apply()` sulla riga ombra → il provider del brano corrente rilegge la riga: testo e curiosità compaiono (R-03).
**(b) Fine brano, successivo non pronto.** `_onCompleted` → `_loadCurrent(next)` → `ready(chiave)` non risolto: resta `loading` (mini player e notifica «Caricamento…») → file pronto → parte da solo. Errore: 1 nuovo tentativo, poi `_failAndSkip` con il contatore di errori consecutivi di oggi (R-05, R-15).
**(c) Jam.** L'ospite accoda X → il suo `StreamPreparer` scarica in cache → a file pronto (le aggiunte successive aspettano, per tenere l'ordine) `jam.add(JamItem(ref 'yt:…', videoId))` → l'host/uscita legge `GET /<sid>/file/<itemId>` dall'ospite (resolveFile → `StreamCache`, file **fissato** finché è nella coda della Jam) e lo mette in `JamCache` come oggi. L'ospite esce prima: l'item resta con `videoId`; l'uscita lo passa al proprio `StreamPreparer` e lo suona dalla sua cache (R-20, R-21).
**(d) Promozione.** «Scarica» su X in cache → `StreamPromoter`: copia nella cartella dei download → `DownloadIndex.add` → riga ombra diventa `kind = 0` con il percorso vero (conteggi, cronologia e arricchimento restano suoi) → scansione → `DownloadTagger` → il file in cache si cancella. Senza file in cache: download di oggi e, a scansione finita, `TrackRepository` unisce la riga ombra della stessa chiave (sposta `plays` e conteggi, come `DuplicateRepository.merge`).

### Dati
| Cosa | Dove | Note |
|---|---|---|
| File audio in streaming | `<appSupportDir>/stream_cache/` | memoria interna dell'app, mai in `folders`, mai nel backup (R-11). LRU = data di modifica del file |
| Righe ombra | `tracks` con `kind = 2` | **nessuna migrazione**: la colonna `kind` c'è dalla v9; `kSchemaVersion` resta 14 |
| Ascolti | `plays` come oggi (`trackId` = riga ombra) | R-12 senza toccare `plays`; il CASCADE è innocuo perché la riga ombra non si cancella mentre ha ascolti |
| Arricchimento | colonne della riga ombra + `CoverStore` | niente JSON accanto al file; la promozione lo eredita perché è la stessa riga |
| Jam | `JamItem.videoId` (campo nuovo, facoltativo) | i client tollerano campi sconosciuti |

- **Query**: le viste di libreria restano `kind = 0` (la riga ombra non compare mai: brani, album, artisti, ricerca, playlist, doppioni, regole). Cronologia e statistiche passano a `kind IN (0, 2)`; i blocchi della Home restano `kind = 0` (D-83) (una costante `listenKinds`). `_beginListen` registra anche `kind = 2`.
- **Pulizia**: l'eviction cancella il file, la riga ombra resta (con `path` marcatore, il brano si riscarica se lo si risuona dalla cronologia). Righe ombra senza ascolti e senza file: cancellate a «Svuota».
- **Backup**: il `.sqlite` contiene le righe ombra (innocue: il ripristino le tratta come brani senza file); `user_data.json` esporta solo `kind = 0`.
- Alternative scartate per R-12: (b) `plays.videoId` + `trackId` nullable (migrazione e ogni query delle statistiche con `LEFT JOIN`/`UNION`); (c) tabella `stream_tracks` separata (migrazione, statistiche doppie).
- **Impostazioni**: nuova `streamCacheMb` (int, 1024; 256–8192) in `AppSettings`. **`shufflePlus` resta** con lo stesso nome: è già il bit della modalità che `cycleShuffle` salva (si toglie solo l'interruttore); rinominarla perderebbe la scelta salvata senza alcun vantaggio. `shufflePlusEvery` e `shufflePlusUnmeteredOnly` restano.

### Invarianti
1. La cartella della cache non è mai dentro una cartella scansionata né nel backup; nessuna riga `kind = 2` compare in una vista di libreria.
2. Tutto l'audio online passa da `StreamPreparer` → `StreamCache` → `_backend.load(file)`. Nessun `loadUri` per YouTube.
3. Il file corrente, i prossimi 2 online in coda e quelli della Jam sono fissati: l'eviction non li tocca, anche oltre il limite.
4. Download, eviction, copia e arricchimento girano fuori dal thread UI (servizi async, I/O mai sincrono nei widget); la UI vede solo `loading` e lo stato per riga, non il progresso byte per byte.
5. Un brano online ha una sola chiave (`indexKey`) e al più un download in corso.
6. Il file in cache non si modifica mai (niente tag): i tag si scrivono solo nella cartella dei download, dopo la promozione.
7. I download di oggi (`DownloadQueue`, import) non passano da `StreamPreparer` e non cambiano.

### Dove va il codice nuovo
- `lib/services/stream/`: `stream_cache.dart`, `stream_preparer.dart`, `stream_promoter.dart`, `stream_key.dart`.
- `lib/providers/stream_providers.dart`: provider di cache, preparer, uso della cache per le impostazioni.
- `lib/ui/screens/settings/stream_cache_tile.dart`; `lib/ui/widgets/artist_links.dart`, `artist_picker_sheet.dart`; `lib/ui/screens/jam/jam_track_info_screen.dart`.
- Test: `test/services/stream/` (cache con cartella temporanea, preparer con downloader finto), test di integrazione Jam host+ospite in memoria accanto a quelli esistenti.

## Rischi
| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale |
|---|---|---|---|---|---|
| K-01 | Regressione dei download e dell'import: `StreamPreparer` e `DownloadQueue` usano lo stesso yt-dlp (su Android un solo canale); un album in download blocca lo streaming o viceversa | M | A | Nessun codice condiviso oltre `YoutubeService`; verificare se il canale Android serializza e, se sì, priorità allo streaming; test esistenti di download/import verdi a ogni fase (RNF-03) | caricamento > 15 s mentre ci sono download attivi |
| K-02 | Righe ombra che trapelano: una query senza filtro `kind` mostra brani in streaming in libreria, Home, doppioni, regole o export; doppioni dopo la promozione se la scansione arriva prima dell'aggiornamento della riga | M | A | Test unico che crea una riga `kind = 2` e controlla ogni vista; audit `grep` delle query su `tracks`; promozione che aggiorna la riga prima di copiare/scansionare | brano «Online» in Brani o Album; due righe con lo stesso titolo dopo «Scarica» |
| K-03 | Fluidità (RNF-01): NowPlaying aperta in loading, aggiornamenti di stato per riga e scritture DB a raffica peggiorano apertura del player e liste | M | M | Stato per riga solo a cambio di fase (in coda/scarica/pronto), mai il progresso; `select` sui provider; `scripts/perf_device.py` a fine fasi 45 e 46 | frame oltre soglia rispetto a `misure.md` «Finale» |
| K-04 | 403 / limite di richieste di YouTube: un album o una coda lunga scarica molti brani di fila | M | A | Max 2 insieme, 1 tentativo, pausa come `source_cooldown`/429 di Shuffle+; aggiornamento di yt-dlp esistente | 403/429 nel log, errori consecutivi |
| K-05 | Spazio su Android: la cache sta nella memoria interna; 8 GB su un telefono pieno; la copia verso la cartella dei download può cambiare volume (`rename` fallisce) | M | M | Limite = min(cursore, spazio libero − margine); promozione con copia + verifica dimensione + cancellazione; errore chiaro se manca spazio | `No space left`, promozione fallita |
| K-06 | Conteggio dello spazio sbagliato: `.part`, download in corso, file fissati, file non cancellabile su Windows perché in uso | M | B | `usedBytes` ricalcolato dalla cartella all'avvio e dopo ogni eviction; `.part` cancellati all'avvio; cancellazione fallita = riprovata al giro dopo, loggata | spazio usato che cresce oltre il limite |
| K-07 | Jam: il proprietario evicta il file mentre è in coda; `int.parse(ref)` su `yt:` rompe le versioni miste; uscita che riscarica tutto se il proprietario esce | M | M | File della Jam fissati; `ref` analizzato con prefisso; test host+ospite in memoria (R-20, R-21) | 404 sulla rotta dei file, brano non disponibile |
| K-08 | Passaggi fra brani: ora l'online è un file locale e verrebbe voglia di dargli gapless/dissolvenza; toccare `NextWindow` rischia i passaggi di oggi | B | M | Fase 45 lascia `NextWindow` = null per l'online come oggi; gapless sull'online eventuale, a parte | salti o doppio audio a fine brano |

**Controlli a ogni fase** (l'utente teme K-01, K-02, K-03, K-04): test esistenti di download/import verdi (K-01); test «riga `kind = 2` in ogni vista» verde (K-02); `perf_device.py` sul Mi A3 a fine fasi 45, 46, 48 contro «Finale» (K-03); log senza 403/429 ripetuti nella prova a mano con un album di 15 brani (K-04).

## Fasi proposte
1. **Fase 45 — Cache e motore**: `StreamCache`, `StreamPreparer`, righe ombra, caricamento dal file nel gestore, via `StreamAddressCache`; i suggeriti di Shuffle+ passano di qui (le stazioni della Radio internet restano dirette, D-88); cursore e «Svuota». R-03, R-05, R-07, R-08, R-09, R-11, R-12, R-14, R-15, R-29.
2. **Fase 46 — Streaming dalla ricerca**: tap/swipe/menu ⋮ sulle righe online, player in caricamento, album online (Play/Shuffle, menu), «Scarica» e «Aggiungi a playlist» con promozione, via l'anteprima. R-01, R-02, R-04, R-06, R-10, R-13, R-16…R-19.
3. **Fase 47 — Jam online**: accodamento online di host e ospiti, file dalla cache, uscita che scarica da sé, schermata info con rotta `meta`, via il FAB. R-20…R-24.
4. **Fase 48 — Shuffle a 3 stati e Home**: ciclo che salta plus, inserimento/rimozione immediati dei suggeriti, nota nelle impostazioni, Play + shuffle in Home. R-25…R-28, R-31.
5. **Fase 49 — Artisti ospiti**: nomi toccabili, «Vai all'artista» con foglio di scelta, risoluzione libreria → online. R-32…R-34.
R-30 vale per tutte (prova a mano su Linux e Mi A3 a fine fase).
