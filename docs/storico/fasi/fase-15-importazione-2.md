# Fase 15 — Importazione 2: altri formati, sincronizzazione e rifiniture

**Obiettivo:** il motore di fase 12 accetta anche **M3U/M3U8/XSPF** e i CSV di **TuneMyMusic, Soundiiz e Last.fm**;
una playlist importata si **sincronizza** con un CSV aggiornato (aggiunte **e** rimozioni); i brani di uno stesso album
si cercano **come album**; arrivano le dieci «Idee specifiche per la fase 12» di `docs/13-idee-future.md`
(anteprima degli abbinamenti, soglie, ETA, cartella dedicata, file numerati, copertine, esito esportabile, avviso
per CSV grandi, «solo collega»).
**Prerequisiti:** Fase 12. Fase 13 (`writeCsv`, salvataggio file). Fase 14 (ISRC, cache delle ricerche, limiti del CSV).
**Principio:** stesso motore, cambia solo il lettore (`*_reader.dart`). La rete parte solo da «Importa»/«Sincronizza».
Una rimozione dalla playlist **non** cancella mai il file (regola 6).

> ⚠️ Come in Fase 5 parte B: scaricare da YouTube viola i suoi Termini d'uso. Uso strettamente personale.

## Decisioni
| Tema | Scelta |
|---|---|
| Riconoscimento del formato | Per estensione (`.m3u`, `.m3u8`, `.xspf`, `.csv`) e, per i CSV, dall'**intestazione** (profili: Exportify, TuneMyMusic, Soundiiz, Last.fm, generico «titolo + artista») |
| Voci locali di M3U/XSPF | Percorso (assoluto o relativo alla cartella del file) cercato **prima** nella libreria; poi titolo/artista come per il CSV |
| XSPF | XML semplice: lettore nostro a espressioni regolari limitato a `<track>`/`<location>`/`<title>`/`<creator>`/`<album>`/`<duration>` + decodifica entità. Se 15.1 mostra file reali che non regge → pacchetto `xml` **(da approvare con l'utente)** |
| Sincronizza | Differenza per `isrc`, poi `matchKey` titolo+artista principale: nuove righe → importate; righe sparite → **tolte dalla playlist** (stato nuovo «rimosso dalla sorgente»), file tenuti; ordine riallineato al nuovo CSV. Sempre con anteprima |
| Anteprima degli abbinamenti | Opzione «Rivedi prima di scaricare»: il ciclo cerca tutte le righe, mette le `sure` in stato «pianificato» e si ferma; l'utente vede la tabella e avvia i download |
| Soglie | `importSureThreshold` (0,80) e `importReviewThreshold` (0,55) in Impostazioni → Avanzate; vincolo review < sure − 0,05 |
| Cartella e nomi | Opzioni dell'anteprima: «Cartella per questa playlist» (`<download>/<nome playlist>/`) e «Numera i file» (`07 - Artista - Titolo`, cifre secondo il totale) |
| Copertine | Opzione dell'anteprima «Cerca le copertine» (spunta visibile, è un'azione dell'utente): iTunes per album+artista del CSV (`entity=album`), ISRC se 15.1 lo conferma |
| CSV grandi | Oltre 200 brani da scaricare: stima in ore + proposta «Importa a blocchi da 100» (un'importazione per blocco, in fila) |
| Schema DB | **v5** (se una fase precedente con schema non è stata fatta, usa la prossima versione libera e adatta il test di migrazione) |
| Pacchetti nuovi | Nessuno (eventuale `xml`, vedi sopra) |

## Task

### 15.1 — Verifiche preliminari
1. **Tocca a te:** procurare e salvare in `test/fixtures/`: un CSV di TuneMyMusic, uno di Soundiiz, un export Last.fm
   (es. da *lastfm-to-csv*: colonne artista/album/titolo/data), un `.m3u8` di VLC o Poweramp, un `.xspf` di VLC.
   Senza file veri: fixture sintetiche dai formati documentati e i task dei lettori restano `[~]`.
2. Annota in PROGRESS le intestazioni reali di ogni CSV (nome colonne, separatore artisti, durata in ms o `m:ss`).
3. Album su YouTube Music: `yt-dlp -J --flat-playlist "https://music.youtube.com/search?q=<album artista>#albums"`
   restituisce playlist `OLAK5uy_…`? Con `--playlist-items 1-20` sull'URL dell'album: titoli, durate, ordine.
   Se non funziona, **15.12 si salta** (annota).
4. iTunes: `https://itunes.apple.com/lookup?isrc=<ISRC>` restituisce qualcosa? Se no, solo album+artista.
**Verifica:** note in PROGRESS. Se i file di un formato non si possono ottenere, prosegui con gli altri e riporta.

### 15.2 — Schema v5 per le importazioni
**File:** `tables.dart`, `app_database.dart` (+ `build_runner`), `import_repository.dart`, `test/data/migration_test.dart`,
`docs/03-modello-dati.md`
1. `playlist_imports`: `sourceKind` text (default `exportify`), `folderPath` text?, `numberFiles` bool (false),
   `linkOnly` bool (false), `planFirst` bool (false), `fetchCovers` bool (false).
2. `playlist_import_items`: `note` text? (motivo di «non trovato» / «durata diversa»), `location` text? (voce locale M3U/XSPF).
3. `ImportItemStatus`: nuovi valori in coda **8 pianificato** · **9 rimosso dalla sorgente** (gli indici esistenti non cambiano).
**Test:** migrazione v4 → v5 con un'importazione esistente intatta; repository con i nuovi campi.

### 15.3 — Interfaccia comune dei lettori
**File:** `lib/services/import/playlist_reader.dart`, `exportify_reader.dart`, `lib/core/import_row.dart`, `import_flow.dart`,
`import_intro_sheet.dart`, `test/services/import/playlist_reader_test.dart`
1. `ImportedPlaylist { name, kind, rows, skipped }` (rinomina di `ExportifyPlaylist`, con `typedef` temporaneo se aiuta);
   `ImportRow.location` (percorso della voce locale, opzionale).
2. `ImportedPlaylist readPlaylistFile(String fileName, String text)`: sceglie il lettore; nessuno adatto →
   `FormatException` «formato non riconosciuto» con l'elenco dei formati supportati. In `Isolate.run`.
3. Foglio d'importazione: titolo «Importa una playlist», Exportify resta la prima istruzione; sotto «Accetta anche:
   TuneMyMusic, Soundiiz, Last.fm (CSV), M3U/M3U8, XSPF». `pickFiles` con le nuove estensioni.
**Test:** ogni estensione va al lettore giusto; CSV Exportify invariato (test di fase 12 verdi).

### 15.4 — Lettori CSV: TuneMyMusic, Soundiiz, Last.fm, generico
**File:** `lib/services/import/csv_profiles.dart`, `test/services/import/csv_profiles_test.dart`
1. Un profilo = nomi di colonna per titolo/artisti/album/durata/ISRC + separatore artisti + unità della durata.
   Exportify diventa un profilo (stesse intestazioni di `exportify_reader.dart`).
2. Scelta del profilo dall'intestazione (il più specifico che combacia); generico = qualunque CSV con titolo e artista.
3. Last.fm (ascolti, non playlist): righe duplicate dello stesso brano → una sola, ordine della prima apparizione.
**Test:** le fixture di 15.1, durata `m:ss` e ms, artisti con `,` `;` `&`, file Last.fm con duplicati.

### 15.5 — Lettori M3U/M3U8 e XSPF
**File:** `lib/services/import/m3u_reader.dart`, `lib/services/import/xspf_reader.dart`, `track_matcher.dart`
(`LibraryIndex.findByPath`), `TrackRepository.liteEntries` (+ `path`), test
1. M3U: `#EXTINF:<s>,<artista> - <titolo>`, `#PLAYLIST:`, righe-percorso (assolute, relative, `file://`), codifica
   Latin-1 per `.m3u` se l'UTF-8 fallisce. URL `http(s)` → solo titolo dall'`#EXTINF`.
2. XSPF: lettore limitato (vedi Decisioni), `location` decodificato (`Uri.decodeFull`).
3. `LibraryIndex.findByPath(location, baseDir)`: percorso normalizzato; poi `find` come oggi.
**Test:** M3U di VLC e Poweramp, percorsi Windows, voce relativa trovata in libreria, XSPF con entità `&amp;`.

### 15.6 — Anteprima degli abbinamenti e «solo collega»
**File:** `playlist_import_service.dart`, `import_preview_dialog.dart`, `lib/ui/screens/import/import_plan_screen.dart`, ARB (+ test)
1. Anteprima: interruttori «Solo collega (nessun download)» → `linkOnly` (righe non in libreria → «non trovato» senza
   ricerca, come con `kEnableYoutube = false`) e «Rivedi prima di scaricare» → `planFirst`.
2. Con `planFirst`: `sure` → stato «pianificato» con candidato salvato; a fine ricerche l'importazione va in pausa con
   evento `planned`. `import_plan_screen`: per riga CSV → candidato (canale, durata, differenza colorata, punteggio),
   tocco = scegli un altro dei 3 / «Salta»; pulsante «Scarica N brani».
3. Candidato con `videoId` già in `downloads.json` (anche con altro nome): etichetta «già scaricato» e collegamento
   senza download (idea 5).
**Test:** `linkOnly` non chiama mai il servizio YouTube; `planFirst` non accoda nulla finché non si avvia; videoId noto → collegato.

### 15.7 — Soglie regolabili e CSV grandi
**File:** `track_matcher.dart` (`decide` con soglie parametriche), `settings_store.dart`,
`lib/ui/screens/settings/advanced_section.dart`, `import_preview_dialog.dart`, ARB (+ test)
1. `decide(row, cands, {double sure = sureThreshold, double review = reviewThreshold})`; il servizio legge le impostazioni.
2. Impostazioni → Avanzate: due cursori con il vincolo, «Ripristina predefiniti».
3. Anteprima: «circa 2 h 10 min»; oltre 200 brani da scaricare → riquadro d'avviso con «Importa a blocchi da 100»
   (crea più importazioni nella stessa playlist, eseguite una dopo l'altra: il ciclo lo fa già).
**Test:** soglie diverse cambiano la decisione; blocchi: 250 righe → 3 importazioni con indici di riga conservati.

### 15.8 — Contatore e tempo residuo
**File:** `lib/services/import/eta_estimator.dart`, `activity_providers.dart`, `import_banner.dart`, test
1. `EtaEstimator`: media mobile esponenziale del tempo per riga (ricerca + download), ignora le righe collegate;
   `Duration? remaining(int left)` null finché non ci sono almeno 3 campioni.
2. Riga del Centro Attività e banner: «42/120 · circa 18 min».
**Test:** stima con tempi finti, righe collegate escluse, pausa che non falsa la media.

### 15.9 — Cartella dedicata e file numerati
**File:** `youtube_service.dart` (`YtResult.subdir` accanto a `downloadName`), `download_queue.dart`,
`playlist_import_service.dart`, `import_preview_dialog.dart` (+ test)
1. Con `folderPath`: download in `<cartella download>/<nome sanificato>/` (sottocartella di una cartella già
   scansionata: `scanFiles` funziona con la cartella radice).
2. Con `numberFiles`: `downloadName` = `NN - <artista> - <titolo>` (NN = posizione nel CSV, cifre del totale).
**Test:** nomi `07 - …` con 120 righe → `007 - …`; sottocartella creata; il brano entra comunque in playlist.

### 15.10 — Copertine dal CSV ed esito esportabile
**File:** `playlist_import_service.dart`, `itunes_client.dart`, `import_review_screen.dart`, ARB (+ test)
1. Con `fetchCovers`: dopo il download, iTunes per `album` + artista principale (`entity=album`, poi ISRC se 15.1 ok);
   la copertina si salva con `CoverStore` come l'arricchimento attuale; titolo/artista restano quelli del CSV.
2. «Esporta esito» in «Rivedi»: CSV (`writeCsv` di fase 13) con riga, titolo, artista, stato, `note`, video scelto,
   punteggio; salvataggio come in fase 13.
3. `note` riempita: «nessun risultato», «durata fuori tolleranza», «solo versioni live», ecc.
**Test:** esito con righe di ogni stato; iTunes finto → copertina salvata per l'album, nessuna chiamata con `fetchCovers` spento.

### 15.11 — Sincronizza da CSV
**File:** `lib/services/import/import_diff.dart`, `playlist_import_service.dart`, `import_preview_dialog.dart`,
`playlist_repository.dart`, ARB, `test/services/import/import_diff_test.dart`
1. `ImportDiff diffImport(List<PlaylistImportItem> old, List<ImportRow> fresh)` (puro): `added`, `removed`, `kept`
   (con nuovo indice). Chiave: `isrc`, poi `matchKey` titolo+artista principale.
2. Playlist esistente con stesso nome: tre scelte «Aggiungi solo i nuovi» (comportamento di fase 12), **«Sincronizza»**
   («+5 nuovi · −2 rimossi dalla playlist (i file restano)»), «Crea nuova».
3. Applica in transazione: rimossi → `removeTrack` + stato 9; tenuti → indice di riga aggiornato e playlist riordinata
   secondo il CSV (brani aggiunti a mano restano, in coda al loro vicino precedente); nuovi → importati.
**Test:** aggiunte, rimozioni, riordino, brano aggiunto a mano conservato, ISRC cambiato ma titolo uguale → tenuto.

### 15.12 — Importazione per album intero
**File:** `youtube_service.dart` (`searchAlbums`, `albumTracks`), `yt_dlp_process_service.dart`,
`android_yt_dlp_service.dart`, `MainActivity.kt`, `playlist_import_service.dart` (+ test)
1. Solo se 15.1 punto 3 è positivo. Righe con stesso `album` (≥ 3 nella stessa importazione): una ricerca album →
   tracce dell'album → `decide` per ogni riga **prima** della ricerca singola; risultati in cache (fase 14).
2. Il punteggio resta lo stesso; un brano dell'album che non arriva a `sure` torna al flusso normale.
**Test:** 4 righe dello stesso album → una sola ricerca album; riga che non combacia → ricerca singola.

### 15.13 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es completi.
2. `docs/02-architettura.md` (lettori, profili CSV, sincronizzazione), `docs/03-modello-dati.md` (schema v5, stati 8–9),
   `docs/99-rischi-e-fallback.md` (R31–R33), README («Formati accettati», «Sincronizzare una playlist»).
3. Prestazioni: M3U di 5.000 voci locali → anteprima < 2 s.
**Tocca a te (Linux + Mi A3):** un M3U8 di VLC con brani già in libreria (tutti collegati, zero rete); CSV TuneMyMusic;
playlist Spotify riesportata con 3 brani in più e 2 in meno → «Sincronizza»; «Rivedi prima di scaricare» su 10 righe;
«Numera i file» + cartella dedicata letta in un altro lettore nell'ordine giusto.

## Fuori da questa fase
Lettura diretta dei link Spotify/Apple Music, sincronizzazione automatica pianificata, SoundCloud e playlist YouTube come
sorgente (fase 22), sincronizzazione tra dispositivi (fase 24).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R31 | Un servizio cambia le colonne del suo CSV | Profili per intestazione, fixture vere, profilo generico «titolo + artista» come ripiego |
| R32 | «Sincronizza» toglie brani che l'utente voleva tenere | Anteprima con elenco dei rimossi, solo dalla playlist (file e libreria intatti), stato 9 reversibile con «Aggiungi di nuovo» |
| R33 | XSPF/M3U con codifiche o percorsi strani | Latin-1 di ripiego, `Uri.decodeFull`, voci illeggibili contate in `skipped`, mai errore per tutto il file |

## Definition of Done
- [ ] Import da M3U/M3U8/XSPF e CSV TuneMyMusic/Soundiiz/Last.fm con lo stesso motore
- [ ] «Sincronizza» con anteprima: aggiunte, rimozioni (solo dalla playlist), ordine del nuovo CSV
- [ ] Anteprima degli abbinamenti, «solo collega», soglie regolabili, ETA, cartella dedicata e file numerati
- [ ] Copertine dal CSV, esito esportabile, avviso e blocchi per CSV grandi, album intero (se 15.1 ok)
- [ ] Test: migrazione v5, lettori, profili, diff, ETA, soglie, servizio con finti
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
