# Fase 23 — Podcast (RSS) con episodi scaricabili

**Obiettivo:** iscriversi a un podcast (incollando l'URL del feed RSS o cercandolo per nome), vedere l'elenco degli
episodi, scaricarli e ascoltarli con lo stesso player della musica, con stato «ascoltato», ripresa dal punto
lasciato e pulizia opzionale degli episodi già ascoltati.
**Prerequisiti:** Fase 17 (segnalibro «riprendi da qui», colonna `tracks.resume_position_ms`, velocità di
riproduzione), Fase 14 (coda di download robusta), Fase 11 (Libreria, Centro Attività).
**Principio:** la rete parte **solo** da un'azione dell'utente: «Aggiorna», apertura della schermata di un podcast,
«Scarica». Niente aggiornamento in background, niente download automatici dei nuovi episodi. I file degli episodi
vivono in una cartella dell'app **fuori** dalle cartelle musicali: non finiscono mai in «Tutti i brani».

## Decisioni
| Tema | Scelta |
|---|---|
| Sorgente | Feed RSS 2.0 (con estensioni `itunes:`). Iscrizione da URL incollato o dalla ricerca pubblica iTunes `https://itunes.apple.com/search?media=podcast&term=…` (senza chiave, come `itunes_client.dart`) |
| Aggiornamento | Manuale («Aggiorna» nella pagina podcast o «Aggiorna tutti» nella lista) e all'apertura della pagina di un podcast se l'ultimo controllo ha più di 6 ore. Mai all'avvio dell'app |
| Episodi nel player | Un episodio **scaricato** diventa una riga di `tracks` con `kind = 1` (0 = musica). `CodecoreAudioHandler`, `PlayQueue`, persistenza della coda e notifica funzionano senza modifiche perché lavorano su `Track.id` |
| Episodi non scaricati | Solo righe di `podcast_episodes` (nessun `Track`): niente streaming nella v1 della fase, si scarica prima (vedi «Fuori da questa fase») |
| Esclusione dalla musica | Tutte le query musicali filtrano `kind = 0`: `library_queries.dart`, `track_repository.dart` (`watchTracks`, `liteEntries`, `countAll`), `library_search.dart`, `home_sections.dart`, `playlist_repository.dart`, `import_providers.dart`. Gli episodi non si aggiungono alle playlist |
| Cartella | `<appSupportDir>/podcasts/<podcastId>/<guid-sanificato>.<ext>`: non è nella tabella `folders`, quindi lo scanner non la vede e non la segna mai `missing` |
| Ascoltato / posizione | Riuso del segnalibro di fase 17 (`resume_position_ms`), soglia ridotta a 0 per gli episodi (si ricorda sempre la posizione). «Ascoltato» = arrivato oltre il 95 % o fine brano, oppure segnato a mano |
| Pulizia | Opzione per podcast «Elimina gli episodi ascoltati dopo N giorni» (spenta di default; 1/7/30). Cancella **solo** file dentro `<appSupportDir>/podcasts/` (regola 10: mai file musicali dell'utente). Eseguita all'apertura della sezione Podcast, non con un timer |
| Schema | **v9**: colonna `tracks.kind` + tabelle `podcasts`, `podcast_episodes`. Se una fase precedente con schema non è stata fatta, usa la prossima versione libera e adatta il test di migrazione |
| Pacchetti nuovi | `xml` (parser XML puro Dart) **(da approvare con l'utente prima del task 23.2)**. Download con `dio` (già presente), non con yt-dlp |

## Task

### 23.1 — Verifiche preliminari
1. Scegli 3 feed veri e diversi (uno italiano, uno con `<itunes:episode>`/stagioni, uno grande > 500 episodi).
   Salva le risposte in `test/fixtures/podcast_*.xml` (troncate a ~50 episodi tranne quello grande, che resta
   intero per la prova di prestazioni se < 5 MB).
2. Prova `https://itunes.apple.com/search?media=podcast&term=<nome>&limit=10`: annota in PROGRESS i campi utili
   (`collectionName`, `artistName`, `feedUrl`, `artworkUrl600`). Salva in `test/fixtures/itunes_podcast_search.json`.
3. Controlla in `~/.pub-cache` l'API reale del pacchetto `xml` (`XmlDocument.parse`, `findAllElements`,
   namespace `itunes`). **Fermati** se il pacchetto non è approvato.
**Verifica:** note in PROGRESS con i campi trovati e il tempo di parsing del feed grande.

### 23.2 — Parser RSS (logica pura)
**File:** `lib/services/podcast/rss_parser.dart`, `test/services/podcast/rss_parser_test.dart`
1. `PodcastFeed parseFeed(String xml)`: titolo, autore (`itunes:author`), descrizione, immagine (`itunes:image@href`
   o `image/url`), lingua.
2. `PodcastEpisodeInfo` per ogni `item`: `guid` (o `enclosure@url` se manca), titolo, data (`pubDate` RFC 822,
   parser scritto da noi con ripiego a null), durata (`itunes:duration` in `s`, `mm:ss`, `hh:mm:ss`),
   `enclosure` (url, tipo, lunghezza), descrizione in testo semplice (tag HTML tolti, entità decodificate).
3. Item senza `enclosure` audio → saltati (conteggio `skipped`). Feed non RSS → `FormatException`.
4. Parsing in `Isolate.run`.
**Test:** i 3 feed di 23.1 (numero di episodi, primo episodio), date malformate, durate nei 3 formati, guid mancante,
descrizione con HTML, feed Atom/HTML → errore.

### 23.3 — Schema v9: `kind`, `podcasts`, `podcast_episodes`
**File:** `tables.dart`, `app_database.dart` (+ `build_runner`), test di migrazione, `docs/03-modello-dati.md`
```dart
// Tracks: IntColumn kind => integer().withDefault(const Constant(0))();   // 0 musica · 1 episodio
class Podcasts extends Table {
  IntColumn id; TextColumn feedUrl (unique); TextColumn title; TextColumn author?; TextColumn imageUrl?;
  TextColumn coverKey?; IntColumn lastCheckedAt?; IntColumn autoDeleteDays?;  // null = mai
  IntColumn addedAt;
}
class PodcastEpisodes extends Table {
  IntColumn id; IntColumn podcastId (references Podcasts, cascade); TextColumn guid; TextColumn title;
  IntColumn publishedAt?; IntColumn durationMs?; TextColumn audioUrl; IntColumn sizeBytes?;
  TextColumn description?; IntColumn trackId? (references Tracks, set null); BoolColumn played (default false);
  IntColumn playedAt?;
  // unique {podcastId, guid}
}
```
Indice su `tracks.kind`. Migrazione: `addColumn(tracks, tracks.kind)` + `createTable` (mai distruttiva).
**Test:** migrazione v8 → v9 con dati esistenti intatti e `kind = 0` su tutti i brani.

### 23.4 — Escludere gli episodi dalle viste musicali
**File:** `library_queries.dart`, `track_repository.dart`, `library_search.dart`, `home_sections.dart`,
`playlist_repository.dart`, `import_providers.dart` (+ test dei repository)
1. Ogni query che oggi filtra `missing = false` aggiunge `kind = 0` (cerca `missing.equals(false)` e `missing = 0`).
2. `PlaylistRepository.addTracks` rifiuta gli id con `kind = 1` (nessun errore in UI: li ignora e lo logga).
3. Album/artisti/generi/Home non mostrano mai episodi.
**Test:** con un episodio nel DB: non compare in `watchTracks`, album, artisti, ricerca, «Più ascoltati», `liteEntries`.

### 23.5 — `PodcastRepository` e `PodcastService`
**File:** `lib/data/repositories/podcast_repository.dart`, `lib/services/podcast/podcast_service.dart`,
`lib/providers/podcast_providers.dart` (+ test con `WebClient` finto e DB in memoria)
1. Repository: `subscribe(feed)`, `unsubscribe(id)` (chiede conferma in UI; cancella righe e file scaricati dell'app),
   `upsertEpisodes(podcastId, list)` (per `guid`, non duplica, non tocca `played`/`trackId`), `watchPodcasts`,
   `watchEpisodes(podcastId)`, `markPlayed(episodeId, bool)`.
2. Servizio: `subscribeFromUrl(String url)` (scarica, analizza, salva, copertina nel `CoverStore`),
   `refresh(podcastId)` e `refreshAll()` (uno alla volta, timeout dio standard, `User-Agent` dell'app),
   `search(String term)` sull'API iTunes (riusa `WebClient`/`RateLimiter` di `http_client.dart`).
3. Limiti: feed > 20 MB rifiutato (`FormatException` con messaggio chiaro); solo `http/https`.
**Test:** iscrizione, aggiornamento che aggiunge solo i nuovi, feed rotto → errore leggibile, ricerca iTunes dalla fixture.

### 23.6 — Download degli episodi
**File:** `lib/services/podcast/episode_downloader.dart`, `podcast_service.dart`, `activity_providers.dart` (+ test)
1. `download(episodeId)`: `dio.download` in `<appSupportDir>/podcasts/<podcastId>/` su file `.part`, poi `rename`;
   annullabile (`CancelToken`); progresso nel Centro Attività come `ActivityKind.download` (nome = titolo episodio).
2. A file completo: legge durata con `TagReader` (in isolate), crea la riga `tracks` con `kind = 1`, `folderId = null`,
   titolo = titolo episodio, artista = titolo podcast, album = titolo podcast, `coverKey` del podcast; salva `trackId`.
3. Estensione dal `content-type`/URL (`mp3`, `m4a`, `ogg`, `opus`); altro → errore «formato non supportato».
4. `.part` orfani rimossi all'apertura della sezione Podcast (come per i download YouTube).
**Test:** con un downloader finto: riga `tracks` creata con `kind = 1`, annullamento senza file residui, formato ignoto.

### 23.7 — Ascoltato, posizione e pulizia
**File:** `codecore_audio_handler.dart` (solo il punto del segnalibro di fase 17), `podcast_service.dart`,
`lib/services/podcast/podcast_cleanup.dart` (+ test)
1. Per `kind = 1` il segnalibro vale sempre (soglia 0) e oltre il 95 % (o a fine brano) segna l'episodio `played`.
2. `PodcastCleanup.run(now)`: per i podcast con `autoDeleteDays`, cancella i file degli episodi `played` con
   `playedAt` più vecchio, **solo se il percorso è dentro `<appSupportDir>/podcasts/`** (controllo con `p.isWithin`),
   poi cancella la riga `tracks` (l'episodio resta in elenco come «non scaricato»). Episodio in riproduzione o in coda → saltato.
3. Lanciata all'apertura della sezione Podcast, in background (I/O fuori dal thread UI).
**Test:** soglia del 95 %; pulizia che non tocca un percorso fuori cartella, l'episodio in coda, gli episodi non ascoltati.

### 23.8 — Interfaccia: sezione Podcast
**File:** `library_screen.dart` (nuovo filtro/scheda `LibraryKind.podcast` accanto a playlist/album/artisti),
`lib/ui/screens/podcast/podcasts_screen.dart`, `podcast_detail_screen.dart`, `podcast_subscribe_sheet.dart`, ARB
1. Lista podcast (copertina, titolo, «3 nuovi»), pulsante **«Aggiungi podcast»** → foglio con campo «URL del feed» e
   ricerca per nome (risultati iTunes con copertina). Avviso: «I podcast si aggiornano solo quando lo chiedi».
2. Pagina podcast: intestazione con «Aggiorna», impostazione pulizia; elenco episodi (`ListView.builder`, `itemExtent`
   fisso) con data, durata, stato (scaricato / in corso / ascoltato / posizione «mancano 12 min»), azioni Scarica,
   Riproduci (solo se scaricato), Segna come ascoltato, Elimina file.
3. Riproduci = `PlayerController.playQueue` con gli episodi scaricati del podcast in ordine cronologico, dal toccato.
   Il `PlayContext` mostra «In riproduzione da: <podcast>».
4. Velocità: scorciatoia alla velocità di fase 17 nella pagina episodio.
**Verifica:** widget test di lista, pagina e foglio con dati finti; scatti a 100 % e 150 %.

### 23.9 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es per tutte le stringhe nuove.
2. `docs/02-architettura.md` (cartella `services/podcast`, flusso), `docs/03-modello-dati.md` (schema v9),
   `docs/99-rischi-e-fallback.md` (R56–R58), README («Podcast»).
3. Prestazioni: feed da 2.000 episodi → pagina aperta < 1 s dopo il parsing (isolate), scroll fluido.
**Tocca a te (Linux + telefono):** iscriversi da URL e da ricerca, scaricare 2 episodi, ascoltare a metà, chiudere
l'app e riprendere dal punto giusto, velocità 1,5×, segnare come ascoltato, pulizia a 1 giorno (cambiando data del
DB o aspettando), verificare che gli episodi non compaiano in Tutti i brani/Home/ricerca e che lo schermo bloccato
mostri titolo e podcast.

## Fuori da questa fase
Streaming senza scaricare, download automatico dei nuovi episodi, notifiche di nuovi episodi, aggiornamento in
background, capitoli (`podcast:chapters`), trascrizioni, import/export OPML (candidato per una fase futura insieme al
backup di fase 13), podcast nel formato portabile del backup (si aggiunge solo dopo questa fase).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R56 | Feed malformati o enormi (HTML al posto dell'XML, 20 MB) | Parser tollerante con errore chiaro, limite di dimensione, parsing in isolate |
| R57 | Gli episodi «sporcano» la libreria musicale | Colonna `kind` filtrata in tutte le query musicali, test dedicati (23.4), cartella fuori dalla scansione |
| R58 | La pulizia cancella file sbagliati | Solo percorsi dentro `<appSupportDir>/podcasts/` (`p.isWithin`), mai l'episodio in coda, opzione spenta di default |

## Definition of Done
- [ ] Iscrizione da URL e da ricerca iTunes; aggiornamento solo su azione dell'utente
- [ ] Episodi scaricati riproducibili con coda, notifica e ripresa dal punto lasciato
- [ ] Gli episodi non compaiono mai nelle viste musicali né nelle playlist
- [ ] Pulizia opzionale che tocca solo i file dell'app
- [ ] Test: parser RSS, migrazione v9, esclusione dalle viste, servizio con finti, download, pulizia
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
