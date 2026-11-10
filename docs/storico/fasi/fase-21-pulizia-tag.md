# Fase 21 — Pulizia della libreria e scrittura dei tag nei file

**Obiettivo:** trovare e risolvere i **duplicati** (stesso file in due cartelle, stesso brano in due qualità),
correggere a mano gli **album** spezzati o uniti male e, **solo se l'utente lo attiva**, scrivere i tag modificati
anche **dentro i file** in modo sicuro.
**Prerequisiti:** Fase 13 (backup: va proposto prima di una pulizia), Fase 19 (selezione multipla), Fase 20
(tabella `plays`, da fondere tra duplicati).
**Principio:** niente si perde per sbaglio. Ogni pulizia mostra un'**anteprima**; i dati utente (preferiti,
playlist, testi, ascolti, etichette) si **spostano** sul brano tenuto, mai si cancellano; un file si cancella solo
su richiesta esplicita con doppia conferma.

> ⚠️ Questa fase **riapre una decisione v1**: «tag solo in lettura» (`02-architettura.md`, regole 6 e 10 di
> `01-regole-di-lavoro.md`, R10). La scrittura nei file è un'opzione **spenta di default**, limitata a MP3/FLAC/M4A,
> e passa sempre da copia temporanea + verifica + backup + `rename` atomico. Mai in-place.

## Decisioni
| Tema | Scelta |
|---|---|
| Schema | **v8**: colonna `tracks.ignored` (bool, default false). Se una fase precedente con schema non è stata fatta, usa la prossima versione libera e adatta il test di migrazione |
| Duplicati esatti | `sha256` (colonna già esistente, oggi mai calcolata) calcolato **su richiesta** in isolate, solo per i brani con stessa dimensione (`sizeBytes`) — pochi hash invece di 10 000 |
| Duplicati probabili | Stesso `matchTitleKey` + stesso artista principale (funzioni di `track_matcher.dart`) + durata entro ±2 s |
| Brano da tenere (proposto) | Lossless (`flac`, `wav`, `alac`) > bitrate più alto > `userEdited` > ha copertina > aggiunto per primo. L'utente può cambiarlo |
| Gli altri | `ignored = true`: spariscono da tutte le viste, lo scanner **non** li riattiva (diverso da `missing`). Ripristinabili da Impostazioni → «Brani nascosti» |
| Cancellare file | Opzionale, dopo la fusione, doppia conferma con l'elenco dei percorsi; mai automatico |
| Album | Unisci/dividi via `TrackEditor.save` (`albumArtist`/`album` → nuovo `albumKey`, `userEdited = true`); nessuno schema |
| Scrittura tag | Pacchetto Rust da scegliere in 21.1 (candidati `metadata_god`, `audiotags`); dietro un'interfaccia nostra `TagWriter` |
| Pacchetti nuovi | Uno tra `metadata_god` / `audiotags` (**da approvare con l'utente prima del task 21.7**; richiede toolchain Rust e, per Android, NDK) |

## Task

### 21.1 — Verifiche preliminari (prima di scrivere codice)
1. Leggere il sorgente in `~/.pub-cache` (dopo un `flutter pub add` di prova su un ramo usa e getta) di
   `metadata_god` e `audiotags`: piattaforme (Android, Linux, Windows), formati in **scrittura**, se scrivono su un
   percorso dato (serve per la copia temporanea), se conservano copertina e tag sconosciuti (ReplayGain `TXXX`,
   Vorbis comments extra).
2. Prova su Linux con 3 fixture di `test/fixtures/` (mp3, flac, m4a se presente): scrivi titolo/artista/album su una
   copia, rileggi con `AudioMetadataTagReader`, confronta l'hash dell'**audio** (ffmpeg `-map 0:a -f md5`) prima e dopo.
3. Build APK debug con il pacchetto: tempo di build, dimensione aggiunta.
**Verifica:** note in PROGRESS. **Stop:** se nessun pacchetto scrive senza alterare l'audio o perde tag/copertina,
o se serve installare Rust/NDK (sudo o licenze), **fermati e chiedi**: i task 21.2–21.6 (duplicati e album) si fanno
lo stesso, 21.7–21.9 restano in attesa.

### 21.2 — Colonna `ignored` (schema v8) e viste
**File:** `lib/data/db/tables.dart`, `app_database.dart` (+ `build_runner`), `track_repository.dart`,
`library_queries.dart`, `library_entries.dart`, `home_sections.dart`, `rule_sql.dart` (Fase 20), `library_scanner.dart`,
`test/data/migration_test.dart`
1. `BoolColumn ignored` default false; migrazione `if (from < 8) addColumn`.
2. Ovunque oggi c'è `missing = 0` / `t.missing.equals(false)` aggiungere `ignored = 0` (cercare con `grep -rn missing lib/data`).
3. `upsertBatch` non tocca `ignored` (oggi riscrive `missing: false`: `ignored` resta com'è).
4. `TrackRepository.setIgnored(Set<int> ids, bool v)` e `watchIgnored()`.
**Test:** migrazione v7 → v8; un brano `ignored` non compare in brani/album/artisti/ricerca; dopo una nuova
scansione resta `ignored`.

### 21.3 — Ricerca dei duplicati (logica pura + isolate)
**File:** `lib/services/library/duplicate_finder.dart`, `lib/services/library/file_hasher.dart`,
`test/services/library/duplicate_finder_test.dart`
1. `List<DuplicateGroup> findProbable(List<DupEntry> lib)`: gruppi per chiave titolo+artista, poi spezzati per durata
   (±2 s, a catena). `DupEntry` = id, path, titolo, artista, durata, formato, bitrate, size, flag utili (caricati con
   una query leggera come `liteEntries`).
2. `Future<Map<int,String>> hashCandidates(List<DupEntry>)`: solo brani con `sizeBytes` uguale a un altro; SHA-256 a
   flusso (`crypto`, già presente) in `Isolate.run`, salvato in `tracks.sha256` (non si ricalcola se `mtime` uguale).
3. `DuplicateGroup.exact` se tutti gli hash coincidono. `proposeKeeper(group)` con l'ordine delle Decisioni.
**Test:** cartella temporanea con file identici in due sottocartelle → gruppo esatto; stesso brano mp3 128 k e flac →
probabile, tenuto il flac; due brani diversi con lo stesso titolo e durate distanti → nessun gruppo; «Intro» di album
diversi con artisti diversi → nessun gruppo.

### 21.4 — Fusione dei dati utente
**File:** `lib/data/repositories/duplicate_repository.dart`, `test/data/duplicate_merge_test.dart`
1. `merge(int keepId, List<int> dropIds)` in **una** transazione:
   - preferito se almeno uno lo era; `playCount` sommati, `lastPlayedAt` massimo;
   - `playlist_tracks`: il tenuto prende il posto del primo duplicato presente in ogni playlist (nessun doppione,
     posizioni rinumerate come in `PlaylistRepository._renumber`);
   - `plays`, `track_tags`, `playlist_import_items.track_id` spostati sul tenuto;
   - testi / curiosità / modifiche (`userEdited`) copiati solo se il tenuto non li ha;
   - duplicati → `ignored = true`.
2. Nessuna cancellazione di righe `tracks` (servono per «Ripristina»).
**Test:** due duplicati in 2 playlist e con testi diversi → stato atteso campo per campo; transazione annullata a
metà (eccezione simulata) → nulla cambiato.

### 21.5 — Schermata «Duplicati»
**File:** `lib/ui/screens/cleanup/duplicates_screen.dart`, `duplicate_group_card.dart`, `settings_screen.dart`
(voce «Pulizia libreria»), `activity_providers.dart`, ARB
1. Avvio con «Cerca duplicati» (riga nel Centro Attività durante gli hash). Prima, proposta di backup (Fase 13).
2. Una scheda per gruppo: righe con percorso, formato, bitrate, dimensione, il **proposto** evidenziato; tocco cambia
   il tenuto; «Unisci» / «Non sono duplicati» (si ricorda: tabella non necessaria, basta una chiave in
   `SettingsStore` con le coppie ignorate).
3. «Unisci tutti gli esatti» con conferma «N gruppi, M brani nascosti».
4. Dopo l'unione: «Elimina anche i file (M, 1,2 GB)» → secondo dialogo con l'elenco dei percorsi → `File.delete`
   per ciascuno, errori raccolti e mostrati; su Android solo file nelle cartelle accessibili (altrimenti messaggio).
5. Impostazioni → «Brani nascosti»: elenco con «Ripristina» (anche in massa, Fase 19).
**Verifica:** widget test con gruppi finti; test che «Elimina file» non è raggiungibile senza la seconda conferma.

### 21.6 — Unire e dividere album a mano
**File:** `album_detail_screen.dart`, `lib/ui/screens/cleanup/album_merge_dialog.dart`, `track_editor.dart`
(metodo `saveMany`), ARB (+ `test/services/track_editor_test.dart`)
1. **Unisci:** dalla Libreria → selezione multipla di album (o «Unisci con…» dal menu album) → scelta di titolo e
   artista dell'album risultante → `TrackEditor.saveMany` imposta `album`/`albumArtist` su tutti i brani
   (`userEdited = true`) → stesso `albumKey`. Copertina: quella dell'album scelto come principale.
2. **Dividi:** nella pagina album, selezione multipla di brani → «Sposta in un nuovo album» (nome) → stessi passi.
3. `TrackEditor.restoreFromFile` resta la via per annullare (per brano); in più «Annulla» nello snackbar.
**Test:** unione di due album con chiavi diverse → una sola chiave, copertina scelta; divisione → due chiavi.

### 21.7 — `TagWriter` (interfaccia e implementazione)
**Solo dopo l'approvazione di 21.1.**
**File:** `lib/services/tags/tag_writer.dart`, `lib/services/tags/<pacchetto>_tag_writer.dart`, `test/services/tag_writer_test.dart`
1. `abstract class TagWriter { Future<void> write(String path, TagChanges c); bool supports(String format); }`
   con `TagChanges` (titolo, artista, album, albumArtist, anno, genere, numero traccia; `null` = non toccare).
2. Procedura in `SafeTagWriter` (nostra, attorno all'implementazione):
   copia in `<appSupportDir>/tagwork/<nome>.tmp` nella **stessa partizione** del file se possibile (altrimenti
   cartella dell'app + copia finale) → scrittura sulla copia → rilettura con `TagReader` e confronto dei campi →
   backup dell'originale in `<appSupportDir>/tag_backups/` (ultimi 200 o 2 GB) → `rename` atomico della copia
   sul percorso originale → aggiornamento `sizeBytes`/`mtimeMs` nel DB (la scansione incrementale non lo rilegge
   come «cambiato» per errore).
3. Qualunque errore → originale intatto, `AppLog.e`, eccezione tipizzata con motivo.
**Test:** con un `TagWriter` finto che fallisce dopo la scrittura o produce tag diversi → originale invariato
(hash), backup assente; caso riuscito → file nuovo, backup presente, DB aggiornato.

### 21.8 — Opzione «Scrivi le modifiche nei file»
**File:** `settings_store.dart` (`writeTagsToFiles`, default **false**), `settings_screen.dart`,
`track_edit_dialog.dart`, `track_editor.dart`, `lib/ui/screens/cleanup/tag_backups_screen.dart`, ARB
1. Attivarla mostra un avviso (cosa fa, formati, dove stanno i backup) e propone un backup completo (Fase 13).
2. Con l'opzione attiva, «Modifica info» e le azioni di 21.6 chiedono «Anche nel file?» (ricordabile); il DB resta la
   fonte di verità e si aggiorna comunque, anche se la scrittura nel file fallisce (avviso, non errore bloccante).
3. Formati non supportati o file in sola lettura (Android fuori dalle cartelle dell'app, chiavetta) → voce
   disattivata con il motivo.
4. «Backup dei tag»: elenco con «Ripristina originale» e «Elimina backup».
**Verifica:** widget test dell'avviso; test di `TrackEditor` che con opzione spenta non chiama mai `TagWriter`.

### 21.9 — Regole e documenti aggiornati
**File:** `docs/01-regole-di-lavoro.md`, `docs/02-architettura.md`, `docs/99-rischi-e-fallback.md`
1. Regola 6: «Il DB è la fonte di verità. I tag nei file si scrivono **solo** con l'opzione `writeTagsToFiles`,
   attraverso `SafeTagWriter`.» Regola 10: «Non riscrivere i tag in-place; non cancellare file musicali dell'utente
   senza doppia conferma esplicita (unica via: pulizia duplicati).»
2. `02-architettura.md`: «Decisioni già prese» aggiornate (tag scrivibili su opt-in), R10 chiuso con rimando a questa fase.

### 21.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es/fr/pt.
2. Prestazioni: 20 000 brani con 500 duplicati sintetici → ricerca probabili < 1 s; hash solo dei candidati.
3. `docs/03-modello-dati.md` (schema v8, `ignored`, uso di `sha256`), `docs/99-rischi-e-fallback.md` (R49–R52), README.
**Tocca a te (Linux + telefono, dopo un backup):** cartella copiata due volte → «Unisci tutti gli esatti»; stesso
album in mp3 e flac → tenuto il flac, playlist e preferiti intatti; unione di un album spezzato; con
`writeTagsToFiles` attivo modificare 3 brani (mp3/flac/m4a) e controllare con un altro lettore che audio e copertina
siano intatti; ripristino da «Backup dei tag».

## Fuori da questa fase
Impronta audio per duplicati «diversi file, stesso brano» (vedi Fase 14 per il controllo a fine download), scrittura di copertine
e testi nei file, rinomina/spostamento dei file secondo i tag, pulizia automatica senza anteprima (esclusa).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R49 | Fusione sbagliata (due versioni diverse prese per duplicati) | Anteprima obbligatoria, durata ±2 s, «Non sono duplicati», brani solo `ignored` e ripristinabili |
| R50 | Scrittura tag che corrompe il file o perde copertina/ReplayGain | `SafeTagWriter`: copia, verifica, backup, `rename` atomico; verifica dell'audio in 21.1; opt-in spento |
| R51 | Pacchetto Rust non compila su una piattaforma (NDK, Windows) | Dietro `TagWriter`; senza implementazione la voce non compare; stop in 21.1 |
| R52 | Cancellazione di file su Android negata (scoped storage) o su disco esterno | Solo dopo doppia conferma; errori raccolti e mostrati; il brano resta `ignored` comunque |

## Definition of Done
- [ ] Duplicati esatti e probabili trovati con anteprima; dati utente fusi; doppioni nascosti e ripristinabili
- [ ] Unione/divisione album a mano; nessun file toccato senza opzione esplicita
- [ ] (Se approvato) scrittura tag sicura su MP3/FLAC/M4A con backup e ripristino; regole 6/10 aggiornate
- [ ] Migrazione v8 testata; `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
