# Fase 54 — Copertina a mano

**Obiettivo:** brano, album e playlist hanno «Cambia copertina» con un selettore unico: file dal dispositivo, proposte
online (Deezer e iTunes, con la misura in pixel, cercate solo all'apertura), copertina di un altro brano o album della
libreria; per la playlist le copertine dei suoi brani. La copertina d'album vale per tutti i suoi brani tranne quelli
con una copertina a mano propria. Scansione, arricchimento, ricezione e «Scarica» non la cambiano mai; «Ripristina
copertina originale» la toglie. Non si scrive nel file musicale ed è nel backup.

**Prerequisiti:** fasi 50–53 chiuse (colonna `tracks.cover_source` dalla 50.1, guardia di `completeOne` dalla 52.4).
Fase 7 (`CoverStore`), copertina della playlist di oggi (`_pickCover` in `playlist_detail_screen.dart`), fase 36
(`DeezerClient`, `ItunesClient`).

**Riferimenti:** `docs/feature-arricchimento.md` (R-63…R-67; RNF-07; componenti «Selettore copertina», «Protezione
copertina», «Backup e invio»; flusso (c); «Dati» → copertina a mano; invarianti 1, 2, 7; rischio K-AR-05); decisioni
D-114, D-115, D-116, D-117, D-123, D-125.

**Intoccabili:** le copertine delle playlist di oggi (stessa chiave nuova per ogni scelta, la vecchia si cancella);
la copertina originale `sha1(albumKey)` resta su disco; la copertina d'album delle righe con `cover_source = 0` uguale a
oggi. Niente indirizzi web (D-114); niente copertina a mano nel file (D-117). **Nessun pacchetto nuovo** (`file_picker`
c'è già). **Schema invariato (v15).**

## Task

### 54.1 — `cover_ops.dart`: salvare e ripristinare
**File:** `lib/providers/cover_ops.dart` (nuovo), `lib/data/repositories/track_repository.dart` (`setManualCover`,
`setManualAlbumCover`, `restoreCover`), `test/providers/cover_ops_test.dart` (nuovo)
1. Ogni scelta: `CoverStore.saveFromBytes('manual:<track|album|playlist>:<id>:<µs>', …)` (chiave nuova, come le
   playlist); la copertina a mano precedente si cancella dal disco, quella originale no.
2. Brano → `cover_key = k, cover_source = 2` su quel brano. Album → `UPDATE tracks SET cover_key = :k, cover_source = 1
   WHERE album_key = :a AND cover_source <> 2` (R-65). Playlist → `PlaylistRepository.setCover` di oggi.
3. «Ripristina copertina originale»: `cover_source = 0`, `cover_key = sha1(albumKey)` se il file esiste, altrimenti il
   `_resolveCover` della scansione; per l'album solo le righe `cover_source = 1`.

R-65, R-66 (ripristino).
**Fatto quando:** `flutter test test/providers/cover_ops_test.dart test/services/cover_store_test.dart` verde: album di 3
brani, uno con copertina a mano propria → cambiano gli altri 2; ripristino dell'album → i 2 tornano a `sha1(albumKey)`,
quello con la sua resta; ripristino del brano → torna l'originale; seconda scelta → la prima copertina a mano sparita dal
disco, l'originale c'è. `flutter analyze` pulito.

### 54.2 — Copertina d'album letta da `cover_source`
**File:** `lib/data/repositories/library_queries.dart` (righe 79 e 149: preferire `cover_source = 1`, ignorare `= 2`),
`lib/data/repositories/stats_queries.dart` (riga 281, stesso `MIN(cover_key)`), `lib/services/scanner/library_scanner.dart`
(un brano nuovo in un album con `cover_source = 1` ne eredita chiave e valore), `test/data/library_queries_test.dart`,
`test/data/stats_queries_test.dart`, `test/services/library_scanner_test.dart`
1. Album con righe tutte `cover_source = 0` → stessa copertina di oggi (K-AR-05). Album con una copertina d'album a mano
   → quella. Una copertina del brano (`= 2`) non diventa mai la copertina dell'album né dell'artista.

R-65 (viste).
**Fatto quando:** `flutter test test/data/library_queries_test.dart test/data/stats_queries_test.dart test/services/library_scanner_test.dart test/data/performance_lists_test.dart`
verde: album senza copertine a mano → `cover_key` uguale a prima; con copertina d'album → quella; con un solo brano a
mano → copertina dell'album invariata; brano nuovo scansionato nell'album → eredita la copertina a mano; tempi delle
liste entro il test di oggi. `flutter analyze` pulito.

### 54.3 — Nessuno scrittore tocca una copertina a mano
**File:** `lib/data/repositories/track_repository.dart` (`setCoverForAlbum` con filtro `cover_source = 0`),
`lib/services/scanner/library_scanner.dart` (upsert, righe 191–231: non cambia `cover_key` se `cover_source > 0`),
`lib/services/online/enrichment_service.dart` (`_applyCover`), `lib/services/share/received_meta.dart`,
`lib/services/stream/stream_promoter.dart`, `lib/services/library/download_tagger.dart` (`coverOf` salta le copertine a
mano), `test/services/online/cover_for_album_test.dart`, `test/services/library_scanner_test.dart`,
`test/services/share/received_meta_test.dart`, `test/services/stream/stream_promoter_test.dart`,
`test/services/library/download_tagger_test.dart`
1. Ogni scrittore elencato salta le righe con `cover_source > 0`; un brano a mano dentro un album non riceve la
   copertina d'album dell'arricchimento.
2. `DownloadTagger.coverOf` non restituisce mai una copertina con `cover_source > 0`: nel file va l'originale o niente
   (invariante 7).
3. Audit: `grep -rn "setCoverForAlbum\|cover_key\|coverKey: Value" lib/` e per ogni scrittore non elencato decidere e
   annotare in una riga di nota in PROGRESS.

R-66.
**Fatto quando:** `flutter test test/services/online/cover_for_album_test.dart test/services/library_scanner_test.dart test/services/share/received_meta_test.dart test/services/stream/stream_promoter_test.dart test/services/library/download_tagger_test.dart`
verde: dopo il cambio, scansione + arricchimento + ricezione + «Scarica» → stessa `coverKey`; tag scritti in un file di
prova → hash del file uguale a quello senza copertina a mano (nessuna immagine a mano incorporata); i casi di oggi
verdi. `flutter analyze` pulito.

### 54.4 — `cover_picker_sheet.dart`: file e libreria
**File:** `lib/ui/widgets/cover_picker_sheet.dart` (nuovo; il codice di `_pickCover` di
`lib/ui/screens/playlists/playlist_detail_screen.dart` si sposta qui), `playlist_detail_screen.dart`, ARB,
`test/ui/cover_picker_sheet_test.dart` (nuovo), `test/ui/settings_and_playlists_test.dart`
1. Fonti: «Dal dispositivo» (`FilePicker`, limite `CoverStore.maxBytes` come oggi), «Dalla libreria» (copertine di altri
   brani o album, lista leggera con `itemExtent` fisso). Per la playlist «Dalla libreria» = le copertine dei suoi brani.
2. Nessun campo per indirizzi web. Lettura dei byte fuori dal thread UI.

R-63.
**Fatto quando:** `flutter test test/ui/cover_picker_sheet_test.dart test/ui/settings_and_playlists_test.dart test/data/playlist_repository_test.dart`
verde: il selettore ha le tre fonti per brano e album (la terza, «Online», da 54.5); per la playlist propone le copertine
dei suoi brani; la copertina della playlist si cambia come oggi; file troppo grande → messaggio. `flutter analyze` pulito.

### 54.5 — Proposte online con la misura
**File:** `lib/ui/widgets/cover_picker_sheet.dart`, `lib/services/online/deezer_client.dart` (`albumCovers(album,
artist)`: più edizioni), `lib/services/online/itunes_client.dart` (`albumCovers`), `test/ui/cover_picker_sheet_test.dart`,
`test/services/online/online_clients_test.dart`
1. La ricerca parte **solo** all'apertura del selettore, anche con «Metadati da Deezer» spento (invariante 2: è
   l'utente che la chiede); più edizioni da Deezer e iTunes, cooldown di oggi.
2. Ogni proposta mostra larghezza × altezza misurate dall'immagine scaricata per l'anteprima (decodifica con le API di
   Flutter, fuori dal thread UI), non quelle dichiarate.

R-64.
**Fatto quando:** `flutter test test/ui/cover_picker_sheet_test.dart test/services/online/online_clients_test.dart` verde
con client finti: nessuna richiesta prima dell'apertura; all'apertura una richiesta per fonte anche con `deezerMeta`
spento; ogni proposta ha «L × A»; fonte in errore → le altre proposte ci sono. `flutter analyze` pulito.

### 54.6 — «Cambia copertina» e «Ripristina copertina originale» nei menu
**File:** `lib/ui/widgets/track_actions.dart`, `lib/ui/screens/library/album_detail_screen.dart`,
`lib/ui/screens/playlists/playlist_detail_screen.dart`, `lib/providers/cover_ops.dart`, ARB,
`test/ui/track_actions_test.dart`, `test/ui/album_screen_test.dart`
1. Brano (menu ⋮ di libreria) e album (intestazione): «Cambia copertina» apre il selettore; «Ripristina copertina
   originale» compare solo con `cover_source > 0`. Playlist: la voce di oggi apre il selettore. Righe online e Jam: niente.

R-63 (voci), R-66 (ripristino a schermo).
**Fatto quando:** `flutter test test/ui/track_actions_test.dart test/ui/album_screen_test.dart test/ui/cover_image_test.dart`
verde: le voci ci sono per brano e album, «Ripristina» solo con una copertina a mano; scelta → la copertina a schermo
cambia (chiave nuova); nessuna voce sulle righe online. `flutter analyze` pulito.

### 54.7 — Copertine a mano nel backup
**File:** `lib/services/backup/user_data.dart` (`TrackUserData.coverSource`, `coverKey` facoltativi),
`lib/data/repositories/backup_queries.dart`, `lib/data/repositories/backup_merge.dart`,
`lib/services/backup/backup_service.dart`, `lib/services/backup/restore_service.dart`,
`test/services/backup/user_data_test.dart`, `test/data/backup_merge_test.dart`, `test/services/backup/backup_service_test.dart`,
`test/services/backup/restore_service_test.dart`
1. Ripristino completo: `.sqlite` e cartella delle copertine (anche `manual:…`) come oggi. Unione: `coverSource` e
   `coverKey` si mettono solo se il file della copertina è nel backup e il brano non ha una copertina a mano propria.
2. Un backup vecchio senza i campi si legge come oggi.

R-67.
**Fatto quando:** `flutter test test/services/backup/ test/data/backup_merge_test.dart` verde: andata e ritorno (completo e
unione) con una copertina a mano di brano e una d'album → rimesse con la stessa immagine; backup vecchio → nessun errore,
copertine automatiche invariate. `flutter analyze` pulito.

### 54.8 — Controlli di fase (K-AR-01, K-AR-02, K-AR-03, K-AR-05)
1. K-AR-01: `flutter test test/services/online/enrichment_service_test.dart test/services/online/enrichment_needs_test.dart
   test/services/online/enrichment_deezer_test.dart test/services/online/cover_for_album_test.dart test/services/online/enrich_completer_test.dart` verde.
2. Download: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
3. K-AR-02/03: `flutter test test/services/backup/ test/data/backup_merge_test.dart test/data/duplicate_merge_test.dart
   test/services/share/ test/jam/` verde.
4. K-AR-05 (copertine): `flutter test test/data/playlist_repository_test.dart test/ui/album_screen_test.dart
   test/ui/cover_image_test.dart test/ui/cover_fan_test.dart test/services/cover_store_test.dart
   test/services/covers/cover_thumbnails_test.dart test/data/stream_rows_hidden_test.dart` verde.
5. K-AR-05 audit: `grep -rn "setCoverForAlbum\|cover_key = \|coverKey: Value" lib/` → ogni risultato rispetta
   `cover_source` (elenco nella nota di 54.3); `grep -rn "_pickCover" lib/` = 0.
6. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–6 sono verdi.

### 54.9 — Prove a mano (utente)
Materiale per l'utente (D-125). Su **Linux e Mi A3** (`0d7ae9df206e`; `-k` ammesso, mai cancellare i file musicali):
- Album: «Cambia copertina» → proposte online con la misura (anche con «Metadati da Deezer» spento), scelta → la
  copertina cambia sull'album e su tutti i brani; un brano con copertina propria resta (R-63…R-65).
- Brano: copertina da file e da un altro album della libreria; playlist: copertina da uno dei suoi brani (R-63).
- Nuova scansione e «Arricchisci» sull'album: copertina a mano invariata; «Ripristina copertina originale» → torna
  quella del file (R-66).
- «Scrivi i tag» o un download nello stesso album: la copertina nel file non è quella a mano (R-66).
- Backup su Linux, ripristino in unione sul Mi A3: copertine a mano rimesse (R-67).
Sul **Motorola edge 40** (`ZY22HKD85K`, D-125): prima di installare chiedere all'utente un backup completo dall'app e
annotare dove sta; `adb -s ZY22HKD85K install -r <apk>`; firma diversa → fermarsi, l'utente conferma il backup,
`adb uninstall -k`, installare e ripristinare; mai cancellare file musicali. Poi: copertine degli album e delle playlist
della libreria vera uguali a prima dell'installazione; una copertina a mano su un album vero resiste a una scansione.

**Fatto quando:** l'utente conferma le prove su Linux, Mi A3 e Motorola (casella `[ ]` → `[x]` in PROGRESS).
