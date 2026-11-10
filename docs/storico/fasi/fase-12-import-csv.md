# Fase 12 — Importare playlist da CSV (Exportify)

**Obiettivo:** l'utente esporta una playlist Spotify come file CSV dal sito **Exportify
(https://exportify.net)**, la carica nell'app e ottiene una **playlist vera** con lo stesso nome e lo stesso
ordine: i brani già in libreria vengono collegati, gli altri vengono cercati e scaricati con yt-dlp.
**Prerequisiti:** Fase 5 (yt-dlp, coda di download, `query_cleaner`), Fase 11 (Centro Attività, Libreria).
**Niente chiavi API, niente login a Spotify dentro l'app:** il login lo fa l'utente su Exportify, nel browser.
**Principio:** la rete parte solo da un'azione dell'utente («Importa»). Un'importazione interrotta non riparte
da sola all'avvio: resta «In pausa» con il pulsante Riprendi.

> ⚠️ Come in Fase 5 parte B: scaricare da YouTube viola i suoi Termini d'uso. Uso strettamente personale.
> Con `kEnableYoutube = false` l'importazione funziona lo stesso ma **collega solo** i brani già in libreria;
> gli altri finiscono in «Non trovati».

## Decisioni
| Tema | Scelta |
|---|---|
| Sorgente | Solo CSV di Exportify. Colonne riconosciute dall'**intestazione**, non dalla posizione (Exportify le ha cambiate nel tempo) |
| Nome playlist | Nome del file senza `.csv` (Exportify lo chiama come la playlist); modificabile nell'anteprima |
| Ricerca | 1° YouTube Music, sezione Brani (`https://music.youtube.com/search?q=…#songs`) → 2° `ytsearch5:` normale |
| Scelta del risultato | Punteggio (durata, titolo, artista, canale, parole vietate) → **sicuro** / **da verificare** / **non trovato** |
| Tag del brano scaricato | Titolo, artista e album **dal CSV**, scritti nel DB come una «Modifica info» (`userEdited = true`). I file non si toccano (regola 6) |
| Ordine | Ogni brano entra nella playlist nella sua posizione del CSV, anche se i download finiscono in ordine sparso |
| Persistenza | Due tabelle nuove (schema v4): l'importazione sopravvive alla chiusura dell'app |
| Ricerche | Una alla volta, 1,5 s di pausa tra una e l'altra; su 429/«Sign in to confirm» si mette in pausa tutto e si avvisa |
| Pacchetti nuovi | Nessuno. Parser CSV scritto da noi; `file_picker` c'è già. Niente `url_launcher`: l'indirizzo di Exportify si mostra e si copia |

## Task

### 12.1 — Verifiche preliminari (prima di scrivere codice)
1. **Linux:** `yt-dlp -J --flat-playlist "https://music.youtube.com/search?q=daft+punk+one+more+time#songs"`.
   Annota in PROGRESS: funziona? Quali campi ci sono per ogni voce (`id`, `title`, `channel`/`uploader`/`artists`,
   `duration`)? Se `duration` manca in modalità flat, annota il tempo di una ricerca **senza** `--flat-playlist`
   limitata a 5 voci (`--playlist-items 1-5`).
2. Stessa prova con `ytsearch5:daft punk one more time` (riferimento).
3. **Tocca a te:** esportare da https://exportify.net una playlist vera (meglio con accenti, feat., remix e un brano
   «strano») e salvarla come `test/fixtures/exportify_sample.csv`. Serve per i test del parser.
**Verifica:** note in PROGRESS con i comandi e i campi trovati. Se YouTube Music non funziona con yt-dlp,
**fermati e riporta**: il piano B è solo `ytsearch` con query «artista - titolo» e bonus ai canali «- Topic».

### 12.2 — Parser CSV Exportify
**File:** `lib/services/import/csv_parser.dart`, `lib/services/import/exportify_reader.dart`,
`test/services/import/csv_parser_test.dart`, `test/services/import/exportify_reader_test.dart`
1. `List<List<String>> parseCsv(String text)` (RFC 4180): virgolette, `""` dentro le virgolette, virgole e a capo
   dentro i campi, `\r\n` e `\n`, BOM UTF-8 iniziale, riga vuota finale.
2. `ExportifyPlaylist readExportify(String fileName, String text)`:
   ```dart
   class ImportRow { final int index; final String title; final List<String> artists;
                     final String? album; final int? durationMs; final String? isrc; final String? spotifyUri; }
   class ExportifyPlaylist { final String name; final List<ImportRow> rows; final int skipped; }
   ```
   Intestazioni riconosciute senza distinzione di maiuscole: titolo `Track Name`; artisti `Artist Name(s)`;
   album `Album Name`; durata `Duration (ms)` o `Track Duration (ms)`; `ISRC`; `Track URI` o `Spotify ID`.
   Controlla i nomi veri sul file di 12.1 e adatta. Righe senza titolo → `skipped`. Gli **episodi di podcast**
   (`spotify:episode:`) e i brani locali (`spotify:local:`) vengono saltati.
3. Mancano titolo o artisti nell'intestazione → `FormatException` con un messaggio che dice «non sembra un
   file di Exportify».
4. Parsing in `Isolate.run` (un CSV da 10.000 righe non deve bloccare la UI).
**Test:** campi con virgola e virgolette, a capo dentro un campo, BOM, intestazione in ordine diverso,
file non di Exportify → errore, podcast saltato, il file vero di 12.1 (numero righe e prime 3 righe).

### 12.3 — Abbinamento e punteggio (logica pura)
**File:** `lib/services/import/track_matcher.dart`, `test/services/import/track_matcher_test.dart`
1. `String matchKey(String s)`: minuscolo, senza accenti, senza punteggiatura, spazi compressi; riusa `coreTitle` /
   `extractPrimaryArtist` di `query_cleaner.dart`. Toglie da titolo: `- Remastered 2011`, `(feat. …)`, `- Radio Edit`
   (solo per il confronto, non per i tag).
2. `LibraryMatch? findInLibrary(ImportRow r, List<LibraryEntryLite> lib)`: stesso titolo e artista principale
   (per `matchKey`) e, se entrambe note, durata entro ±3 s. `LibraryEntryLite` = id, titolo, artista, durata,
   caricati una volta per importazione (non una query per riga).
3. `double scoreCandidate(ImportRow r, YtResult c)` tra 0 e 1:
   - durata: ±2 s → pieno; fino a ±10 s scala; oltre ±15 s → punteggio 0 (scarto quasi certo);
   - somiglianza titolo (token in comune su `matchKey`) e presenza dell'artista principale in titolo o canale;
   - bonus: canale `<artista> - Topic`, `VEVO`, canale uguale all'artista;
   - penalità forte se il risultato contiene `live`, `cover`, `karaoke`, `remix`, `sped up`, `slowed`, `nightcore`,
     `8d`, `instrumental`, `reverb`, `1 hour` **e** il titolo del CSV non le contiene.
4. `MatchDecision decide(ImportRow r, List<YtResult> cands)`: miglior punteggio ≥ 0,80 → `sure`;
   ≥ 0,55 → `review` (si salvano i primi 3 candidati); altrimenti `notFound`.
**Test:** almeno 12 casi scritti a mano (es. versione Topic vs videoclip con intro di 40 s; «Live at Wembley»
scartato; remix accettato quando il CSV dice remix; feat. nel titolo; accenti; durata ignota; due artisti).

### 12.4 — Ricerca su YouTube Music nel `YoutubeService`
**File:** `youtube_service.dart`, `yt_dlp_process_service.dart`, `android_yt_dlp_service.dart`, `MainActivity.kt`
1. Nuovo metodo `Future<List<YtResult>> searchSongs(String query, {int limit = 5})` che usa l'URL di YouTube Music
   verificato in 12.1 (query codificata con `Uri.encodeQueryComponent`). `search` resta com'è.
2. Android: il metodo `search` del canale accetta un argomento `target` già pronto (`ytsearch5:…` o l'URL di YouTube
   Music), così la logica sta tutta in Dart. Gestire `--playlist-items` se servito in 12.1.
3. `parseYtDlpJson`: se manca `channel`, usare `artists`/`uploader`; durata da `duration` o `duration_string`.
4. Errore «troppe richieste» (429, «Sign in to confirm you're not a bot») → `YtErrorKind.rateLimited` (nuovo).
**Test:** `parseYtDlpJson` con una risposta YouTube Music salvata in `test/fixtures/ytmusic_search.json` (presa da 12.1).
Nessun test di rete.

### 12.5 — Tabelle dell'importazione (schema v4)
**File:** `tables.dart`, `app_database.dart` (+ `build_runner`), `lib/data/repositories/import_repository.dart`,
test migrazione, `docs/03-modello-dati.md`
```dart
class PlaylistImports extends Table {        // una per CSV caricato
  IntColumn id; IntColumn playlistId (references Playlists, cascade); TextColumn sourceName;
  IntColumn createdAt; IntColumn status;      // 0 in corso · 1 in pausa · 2 finita · 3 annullata
}
class PlaylistImportItems extends Table {    // una per riga del CSV
  IntColumn importId (cascade); IntColumn rowIndex; TextColumn title; TextColumn artists; // artisti uniti con " · "
  TextColumn album?; IntColumn durationMs?; TextColumn isrc?;
  IntColumn status;  // 0 da cercare · 1 in coda · 2 scaricato · 3 collegato (era in libreria) · 4 da verificare
                     // 5 non trovato · 6 errore · 7 saltato dall'utente
  TextColumn videoId?; TextColumn candidates?; // JSON dei primi 3 per «da verificare»
  IntColumn trackId? (references Tracks, set null); RealColumn score?;
  primaryKey {importId, rowIndex}
}
```
Repository: crea importazione + righe in un'unica transazione, `nextPending`, `setStatus`, `watchImport`,
`watchUnfinished`, conteggi per stato. Cancellare la playlist cancella l'importazione (cascade).
**Test:** migrazione v3 → v4 (dati esistenti intatti, come per v2/v3); repository con DB in memoria.

### 12.6 — Posizione nella playlist secondo il CSV
**File:** `playlist_repository.dart` (+ test)
`Future<void> placeImported(int playlistId, int importId, int rowIndex, int trackId)`: inserisce il brano **prima
del primo brano già presente con `rowIndex` maggiore** della stessa importazione; se non c'è, in coda. Rinumera in
transazione. Brano già nella playlist → non lo duplica. Se l'utente ha riordinato nel frattempo l'ordine resta
il suo: il riferimento sono solo i brani importati già presenti.
**Test:** arrivi in ordine 3, 1, 2 → ordine 1, 2, 3; brano aggiunto a mano in mezzo resta dov'è; duplicato ignorato.

### 12.7 — Coda di download: sapere a chi appartiene un download
**File:** `download_queue.dart`, `youtube_providers.dart` (+ test della coda)
1. `add(YtResult r, {String? tag})`; `DownloadItem.tag`. Formato del tag per l'import: `import:<importId>:<rowIndex>`.
2. `onDownloaded` riceve il `DownloadItem` (non solo il path). La scansione del singolo file e `downloadIndex`
   restano come ora.
3. `cancelWhere(bool Function(DownloadItem))` per annullare tutti i download di un'importazione.
4. Nome del file: per i download dell'import si usa `<artista CSV> - <titolo CSV>` sanificato (non il titolo del video).
**Test:** il tag arriva a `onDownloaded`; `cancelWhere` annulla solo quelli giusti.

### 12.8 — `PlaylistImportService` (il motore)
**File:** `lib/services/import/playlist_import_service.dart`, `lib/providers/import_providers.dart` (+ test con servizi finti)
1. `start(ExportifyPlaylist p, {int? intoPlaylistId})`: crea la playlist (o usa quella scelta), registra l'importazione,
   collega subito i brani già in libreria (12.3 punto 2 + 12.6), poi avvia il ciclo.
2. Ciclo, una riga alla volta: `searchSongs("<artista principale> <titolo>")` → `decide`; se non `sure`,
   `search("<artista principale> - <titolo>")` e si ridecide sull'insieme. Un `videoId` già in `downloadIndex` →
   collegamento senza riscaricare. `sure` → coda di download con tag. `review`/`notFound` → stato salvato, si prosegue.
3. A download finito (tag `import:`): scansione (già fatta dal notifier) → `trackId` dal path →
   `TrackEditor.save` con titolo/artista/album del CSV → `placeImported` → stato 2. Se `autoEnrich`/`autoLyrics`
   sono attivi l'arricchimento parte come per gli altri download (copertine da iTunes: con i tag del CSV funziona meglio).
4. Pausa, Riprendi, Annulla (annulla anche i download in coda di quell'import con `cancelWhere`; i brani già
   scaricati restano). Un solo ciclo di ricerca alla volta: una seconda importazione aspetta in coda.
5. `rateLimited` → stato «in pausa» e messaggio «YouTube ha chiesto di rallentare: riprova tra qualche minuto».
6. All'avvio dell'app: le importazioni con stato «in corso» diventano «in pausa» (nessuna rete automatica).
7. Reimportare un CSV aggiornato nella stessa playlist: si saltano le righe con lo stesso `isrc` (o stessa
   `matchKey` titolo+artista) già collegate; si aggiungono solo le nuove.
**Test:** con `YoutubeService` e coda finti: brano in libreria collegato senza ricerca; `sure` va in coda;
`review` salva 3 candidati; `rateLimited` mette in pausa; Annulla ferma il ciclo; riavvio → «in pausa»; reimport
salta i già presenti.

### 12.9 — Pulsante «Importa da Exportify» e anteprima
**File:** `playlists_screen.dart`, sezione Playlist di `library_screen.dart`, `lib/ui/screens/import/import_intro_sheet.dart`,
`import_preview_dialog.dart`, ARB
1. Dove: accanto a «Nuova playlist» (FAB esteso secondario o voce del menu «+»), con icona `upload_file` ed etichetta
   **«Importa da Exportify (CSV)»**. Stesso pulsante nella sezione Playlist della Libreria su desktop.
2. Il pulsante apre un foglio che **dice chiaramente da dove viene il file**:
   > **Importa una playlist di Spotify**
   > Il file CSV si crea gratis dal sito **Exportify — exportify.net** (non serve nessuna app).
   > 1. Apri **https://exportify.net** nel browser (anche dal telefono).
   > 2. Tocca «Get Started» e accedi con il tuo account Spotify.
   > 3. Accanto alla playlist che vuoi tocca **Export**: si scarica un file `.csv` col nome della playlist.
   > 4. Torna qui e tocca **Scegli file CSV**.
   >
   > Codecore cerca i brani nella tua libreria e scarica gli altri da YouTube Music.
   L'indirizzo è testo selezionabile con un pulsante **«Copia indirizzo»** (Clipboard + snackbar «Indirizzo copiato»).
   Pulsante principale **«Scegli file CSV»**.
3. Scelta file con `FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])` (controlla l'API nel
   sorgente di `file_picker` 13; se su Android il filtro `csv` non funziona, accetta qualunque file e controlla
   l'estensione dopo). Lettura UTF-8; errore di 12.2 → messaggio nel foglio, non snackbar che sparisce.
4. Anteprima: nome playlist modificabile, «N brani · X già in libreria · Y da scaricare» (calcolato in isolate),
   stima del tempo (Y × ~8 s di ricerca + download), cartella di destinazione. Se esiste già una playlist con lo
   stesso nome: scelta **«Aggiorna quella esistente»** (aggiunge solo i nuovi, 12.8 punto 7) o **«Crea nuova»**.
   Pulsante **«Importa»**.
5. Con `kEnableYoutube = false` il testo dice «verranno collegati solo i brani già in libreria».
**Verifica:** widget test del foglio (l'indirizzo exportify.net è visibile e copiabile) e dell'anteprima con dati finti.
Scatti a 100% e 150%.

### 12.10 — Avanzamento, «Da verificare» e «Non trovati»
**File:** `activity_providers.dart`, `activity_sheet.dart`, `playlist_detail_screen.dart`,
`lib/ui/screens/import/import_review_screen.dart`, ARB
1. Centro Attività: nuova `ActivityKind.import`, riga «Importazione «<nome>» · 42/120», avanzamento, Pausa/Riprendi,
   Annulla (con conferma). I singoli download dell'import compaiono come gli altri.
2. Pagina della playlist: finché l'importazione non è finita, un riquadro in cima «Importazione: 42/120 · 5 da
   verificare · 3 non trovati» con «Rivedi». I brani non ancora arrivati **non** compaiono come righe finte.
3. «Rivedi» apre `import_review_screen`: per ogni riga «da verificare» il brano del CSV (titolo, artista, durata) e i
   3 candidati (miniatura, titolo, canale, durata, differenza di durata colorata) → tocco = scarica quello;
   **«Cerca a mano»** apre Cerca → YouTube con la query precompilata e, al download, il brano entra nella playlist
   al suo posto; **«Salta»**. Sezione «Non trovati» con «Cerca a mano» / «Salta» e «Riprova tutti».
4. A fine importazione: snackbar «Importazione completata: 110 aggiunti, 6 da verificare, 4 non trovati».
**Verifica:** test del provider di attività con un'importazione finta; widget test della pagina di revisione.

### 12.11 — Rifinitura e prova a mano
1. ARB it/en/de/es completi per tutte le stringhe nuove.
2. `docs/02-architettura.md` (cartella `services/import`), `docs/03-modello-dati.md` (schema v4), README (come importare).
3. Prestazioni: CSV da 5.000 righe sintetico → anteprima < 2 s, nessun frame bloccato (parsing e abbinamento in isolate).
**Tocca a te (Linux + Mi A3):** importare una playlist vera da exportify.net di 30–50 brani con alcuni già in
libreria; controllare ordine, nome, tag del CSV nei brani scaricati, «Da verificare» sensati, chiusura dell'app a
metà → «In pausa» → Riprendi, Annulla a metà, reimport dello stesso CSV con 2 brani in più.

## Fuori da questa fase
Altri formati (TuneMyMusic, Soundiiz, M3U), lettura diretta dei link Spotify, fonti diverse da YouTube
(SoundCloud, Bandcamp), download in parallelo, sottocartella per playlist. Si valutano dopo la prova a mano.

## Rischi
| Rischio | Mitigazione |
|---|---|
| yt-dlp non legge più la ricerca di YouTube Music | Piano B già previsto: solo `ytsearch` + bonus «- Topic» (12.1) |
| YouTube limita molte ricerche di fila (429 / «sign in») | Una ricerca alla volta, 1,5 s di pausa, stop automatico con «in pausa» (12.8) |
| Exportify cambia le colonne | Colonne per intestazione, messaggio chiaro, fixture vera nei test |
| Abbinamenti sbagliati (live, cover, versioni diverse) | Durata come criterio principale, soglie prudenti, «Da verificare» invece di scaricare a caso |
| Android: ogni ricerca avvia Python (lenta) | Stima del tempo onesta nell'anteprima; tutto in background nel Centro Attività |
| Import lunghissimo interrotto | Stato su DB riga per riga, Riprendi dal primo «da cercare» |

## Definition of Done
- [x] Il pulsante di importazione dice chiaramente che il CSV si crea su **exportify.net**, con istruzioni e «Copia indirizzo»
- [x] Playlist creata con il nome del CSV e l'ordine del CSV; brani già in libreria collegati, non riscaricati
- [x] Brani scaricati con titolo/artista/album del CSV; nessun file riscritto
- [x] «Da verificare» e «Non trovati» risolvibili a mano; Pausa/Riprendi/Annulla funzionanti; sopravvive al riavvio
- [x] Test: parser CSV, lettore Exportify, matcher (≥ 12 casi), migrazione v4, posizionamento, servizio con finti
- [x] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Come è andata (2026-10-16)
Fatta e provata dal vivo su PC (Linux) e telefono (Mi A3): vedi `docs/PROGRESS.md` (note «Fase 12»). Deviazioni principali:
pulsante nel menu «+» (Libreria e barra laterale) e nel FAB di `PlaylistsScreen`; artisti salvati con `;`;
«Cerca a mano» è un foglio dentro «Rivedi»; `LibraryIndex` tollera ±5 s; un ritento automatico per download falliti
con errore transitorio. Il selettore di sistema su Linux (portal GNOME) è stato provato dopo la chiusura della fase:
dialogo con titolo «Scegli file CSV», cartella iniziale Download; vedi `docs/PROGRESS.md`.
