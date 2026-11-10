# Fase 37 — Metadati che viaggiano

**Obiettivo:** quando un brano passa a un altro dispositivo (condivisione in rete, offerta, sincronizzazione tra
dispositivi fidati) arriva con **i suoi metadati**, non solo con un nome di file. Oggi il ricevente costruisce la riga
dai tag del file; i brani scaricati da YouTube (m4a) non ne hanno, e così arrivano con il titolo sbagliato, «Artista
sconosciuto» e nessun album. Dopo questa fase: titolo, artista, album, anno, genere, numeri di traccia e disco, ISRC,
testo e copertina arrivano insieme al file, e i tag si scrivono **dentro** i file scaricati o ricevuti, così anche una
copia via USB porta i dati con sé.

**Prerequisiti:** fase 21 (`TagWriter`, `SafeTagWriter`, `TrackFileSync`, `writeTagsToFiles`/`tagsAlsoInFile`), 24
(offerte, `/playlists` e `/want` tra dispositivi fidati), 25/26 (condivisione con PIN, `ShareEntry`, `/manifest`,
`/cover/<id>`), 36.2 (`Tracks.isrc`, schema v14) e 36.5 (opzione «Metadati da Deezer», `EnrichmentService` con Deezer).
**Da fare dopo la fase 36**, che cambia il modello dei metadati (ISRC, Deezer); la 36 non tocca il codice della
condivisione, quindi le due fasi non si pestano.
**Principio:** il pacchetto è un dato non fidato come ogni altro input di rete: si legge con la stessa severità di
`OfferItem.tryParse` (tipi, lunghezze, intervalli) e un campo sbagliato si scarta, mai il brano intero. Si scrive solo
dentro i file che Codecore ha scaricato o ricevuto: **i file della libreria dell'utente non si toccano mai in automatico**.
L'ISRC non si scrive nei file. Compatibilità nei due sensi con le versioni di prima. Pacchetti nuovi: **nessuno**.

## Come è collegato oggi e cosa cambia

| Passo di oggi | Come funziona (file) | Con questa fase |
|---|---|---|
| Elenco con PIN (`/manifest`) | `ShareEntry.toManifestJson()` (`lan_server.dart`): `id, title, artist, album, sizeBytes, durationMs, ext`; `RemoteTrack.fromJson` (`lan_client.dart`) | In più un blocco `meta` (vedi decisione «Pacchetto»); il ricevente vecchio lo ignora |
| Offerta (`POST /offers`) | `OfferItem` (`offers.dart`): `id, title, artist, album, sizeBytes, ext`; `offerPayload` da `ShareEntry` | Stesso blocco `meta` in ogni voce, più `hasCover`; nuova rotta `GET /offers/<id>/cover/<n>` |
| Nome del file ricevuto | `baseName` = `sanitizeFileName('$artist - $title')`, in `<cartella download>/Ricevuti` | Invariato (serve anche a chi apre la cartella) |
| Riga del brano ricevuto | `libraryScanner.scanFiles(folder, saved)` → `upsertBatch` con i soli tag del file | Dopo la scansione si applica il `meta` alla riga: **vince il pacchetto** |
| Copertina | Solo nel flusso con PIN (`/cover/<id>`), e il ricevente non la usa; le offerte non la portano | Si scarica dopo il file e si salva con `CoverStore.saveFromBytes` |
| Sincronizzazione tra dispositivi fidati (24) | `/want` → offerta come sopra | Eredita tutto dalle offerte, nessun codice in più |
| Tag nei file scaricati da YouTube | Mai: l'm4a resta senza tag; l'arricchimento scrive solo nel DB | Dopo il download e dopo l'arricchimento automatico si scrivono nel file (opzione nuova, **accesa di default**) |
| Tag nei file ricevuti | Mai | Si scrivono nel file appena ricevuto, con la stessa opzione |
| File senza tag | Titolo = nome del file intero, artista vuoto | Nome «Artista - Titolo» diviso in artista e titolo (solo se il tag manca) |
| ISRC al ricevente | Non esiste | Arriva nel pacchetto; con «Metadati da Deezer» attivo il ricevente completa i campi vuoti per ISRC |

### Cosa **non** entra in questa fase, e perché
- **Doppioni.** Un brano ricevuto che c'è già diventa un doppione, come oggi. Lo gestisce «Duplicati» (fase 29).
  Riconoscerlo prima del download (per ISRC o `sha256`) è un'idea per dopo.
- **Testo e curiosità nei file.** Il testo viaggia nel pacchetto e va nel DB, ma non si scrive nel file
  (`metadata_god` non lo scrive). Le curiosità restano locali.
- **File della libreria dell'utente.** La scrittura automatica vale solo per i file di Codecore. Per gli altri resta
  l'opzione della fase 21 (`writeTagsToFiles`), solo per le modifiche a mano.
- **Formati che `metadata_god` non scrive** (wav, opus, webm, aac, wma, aiff). Il `meta` va nel DB, il file resta
  com'è. Lo si annota nel registro, non è un errore.
- **Playlist ricevute.** Le playlist della sincronizzazione (24) portano già i loro brani. Qui cambia solo come
  arriva ogni brano.

## Decisioni

Le prime tre sono le **scelte dell'utente** (2026-10-23). Le altre sono mie: vanno controllate leggendo.

| Tema | Scelta |
|---|---|
| Tag nei file scaricati e ricevuti (scelta dell'utente) | **Accesa di default.** Impostazione nuova `writeTagsAfterDownload` (`SettingsStore`, default `true`), «Scrivi i tag nei file scaricati e ricevuti» nella sezione dei tag, accanto alle opzioni della fase 21. Spenta = solo DB, come oggi |
| Chi vince (scelta dell'utente) | **Il pacchetto.** Se i tag del file e il `meta` non coincidono, si tiene il `meta`, campo per campo. Un campo assente o scartato nel `meta` lascia quello del file |
| ISRC (scelta dell'utente) | **Mai nei file.** Sta solo nel DB (`Tracks.isrc`, fase 36) e nel pacchetto. `TagChanges` non lo prevede |
| Quali file si scrivono da soli (mia) | Solo quelli dentro la cartella di download di Codecore (quella di `resolveDownloadFolder`, comprese `Ricevuti` e le cartelle delle importazioni). Un percorso fuori da lì non si scrive mai in automatico, anche con l'opzione accesa. Controllo con `p.isWithin` sul percorso normalizzato |
| Pacchetto (mia) | Classe unica `TrackMeta` in `lib/services/share/track_meta.dart`, con `toJson()` e `static TrackMeta? tryParse(Object?)`. Campi: `title, artist, albumArtist, album` (testo, `clip` 200), `year` (1000–anno corrente+1), `genre` (`clip` 100), `trackNumber`, `discNumber` (1–999), `isrc` (12 caratteri `^[A-Z]{2}[A-Z0-9]{3}\d{7}$`, maiuscolo), `lyricsPlain` (≤ 20 000 caratteri), `lyricsSynced` (≤ 40 000, deve passare il parser LRC esistente), `enrichStatus` (solo i valori dell'enum, altrimenti assente), `origin` e `youtubeId` (11 caratteri `[A-Za-z0-9_-]`). Ogni campo si valida da solo: uno sbagliato diventa `null`, gli altri restano. Un `meta` che non è una mappa → `null`, il brano arriva come oggi |
| Dove viaggia (mia) | Chiave `meta` dentro ogni voce di `/manifest` e di `offerPayload`; i campi di oggi (`title, artist, album, …`) restano uguali, così una versione vecchia continua a funzionare nei due sensi. `TrackMeta` si costruisce una volta dal `Track` in `share_providers.dart`, dove nasce `ShareEntry`, e sta in `ShareEntry.meta` |
| Copertina (mia) | `hasCover` nella voce dell'offerta. Rotta nuova `GET /offers/<id>/cover/<n>` (stessa autorizzazione di `/<id>/file/<n>`, stessa sorgente di `/cover/<id>`: `ShareEntry.coverPath`). Il ricevente la scarica **dopo** il file, solo se `hasCover`; limite 5 MB, solo `image/jpeg` o `image/png`, decodifica di prova prima di salvare. Errore → brano senza copertina, una riga `AppLog`, nessun nuovo tentativo |
| Applicare il `meta` (mia) | Metodo `TrackRepository.applyReceivedMeta(int trackId, TrackMeta m)`: scrive i campi non nulli, ricalcola `albumKey` come la scansione, mette `userEdited = true` così una nuova scansione non sovrascrive titolo, artista e album. Lo chiama il codice di ricezione dopo `scanFiles`, trovando la riga dal percorso salvato |
| Rischio della nuova scansione (mia) | `upsertBatch` con `userEdited` tiene solo titolo, artista e album: anno, genere, numeri, copertina si rileggono dal file. Lo si risolve scrivendo i tag nel file (opzione accesa) e aggiornando `sizeBytes`/`mtimeMs` nel DB come fa `TrackFileSync`, così la scansione salta il file (controllo dimensione+data). Con l'opzione spenta resta il limite: se il file cambia fuori da Codecore, anno e genere tornano quelli del file. Va scritto in una riga di `shortcut:` nel codice |
| Scrittura dei tag (mia) | `TagChanges` cresce con `discNumber` e `cover` (byte + mime). `MetadataGodTagWriter` li passa a `Metadata.disc_number` e `Metadata.picture`, che `metadata_god` sa già scrivere. Si passa da `SafeTagWriter` (copia, verifica, backup) e poi da `TrackFileSync` per tenere in passo `sizeBytes`, `mtimeMs` e `sha256` (azzerato: i byte sono cambiati) |
| Quando si scrive (mia) | (1) dopo un download da YouTube, alla fine di `_autoEnrich` (o subito se l'arricchimento automatico è spento), con i campi che ha la riga; (2) dopo un'importazione, alla fine dell'arricchimento dell'import, per ogni brano scaricato; (3) dopo la ricezione, subito dopo `applyReceivedMeta` e la copertina. Fuori dal thread UI, un brano alla volta, in fila con i download (mai due scritture sullo stesso file insieme) |
| File in riproduzione (mia) | Se il file sta suonando, la scrittura si rimanda a quando il brano cambia (Windows tiene il file aperto). Una sola scrittura in attesa per file |
| Nome del file come ripiego (mia) | Funzione pura `splitArtistTitle(String baseName)`: divide al primo ` - ` (anche ` – ` e ` — `), toglie suffissi come «(Official Video)», «[HD]», «(Lyrics)». Si usa nella scansione **solo** se il tag del titolo manca e quello dell'artista anche. Nessuna divisione se una delle due parti resta vuota |
| Deezer al ricevente (mia) | Con `meta.isrc` e «Metadati da Deezer» acceso, il brano ricevuto entra nella fila dell'arricchimento automatico (`QuietEnricher`), che con l'ISRC usa `trackByIsrc` (fase 36). Scrive solo i campi vuoti, come sempre. Opzione spenta → niente rete |
| Versioni miste (mia) | Mittente nuovo → ricevente vecchio: il `meta` si ignora, tutto come oggi. Mittente vecchio → ricevente nuovo: niente `meta`, si usano tag e nome del file (con il ripiego nuovo). Nessun numero di versione del protocollo: basta la presenza della chiave |
| Rete nei test | Mai. Server e client finti come nei test della fase 24/25; file audio piccoli in `test/fixtures/` per i tag |
| Pacchetti nuovi | Nessuno |

## Task

### 37.1 — `TrackMeta`: pacchetto e lettura severa
1. `lib/services/share/track_meta.dart` con `TrackMeta`, `TrackMeta.fromTrack(Track t)`, `toJson()` e `tryParse`
   secondo la decisione «Pacchetto».
2. Test (`test/services/share/track_meta_test.dart`): andata e ritorno con tutti i campi; ogni campo sbagliato
   (anno 99999, ISRC di 11 caratteri, `trackNumber` negativo, titolo di 5000 caratteri tagliato a 200, `enrichStatus`
   sconosciuto, LRC non valido) diventa `null` senza toccare gli altri; `meta` non mappa → `null`; mappa vuota → tutti
   `null`.

**Fatto quando:** test verdi, `flutter analyze` pulito.

### 37.2 — Il pacchetto viaggia (elenco con PIN e offerte)
1. `ShareEntry.meta` (costruito in `share_providers.dart`), `toManifestJson()` con `meta`; `RemoteTrack.meta` da
   `tryParse`.
2. `OfferItem.meta` e `hasCover`, `offerPayload` e `OfferItem.tryParse` aggiornati.
3. Rotta `GET /offers/<id>/cover/<n>` in `offers.dart` (decisione «Copertina»), e `downloadOfferCover` in
   `lan_client.dart`.
4. Test: il `meta` arriva intero nei due flussi; voce senza `meta` (mittente vecchio) → come oggi; `meta` con campi
   sbagliati → voce accettata con quei campi a `null`; la rotta della copertina rifiuta un chiamante senza
   autorizzazione e un `n` fuori intervallo; copertina > 5 MB o non immagine → scartata.

**Fatto quando:** test verdi; un ricevente vecchio (test con il JSON di oggi) legge ancora l'offerta nuova.

### 37.3 — Il ricevente applica il pacchetto
1. `TrackRepository.applyReceivedMeta` (decisione «Applicare il `meta`»).
2. In `share_hub.dart` (offerte) e in `receive_tab.dart` (elenco con PIN): dopo `scanFiles`, per ogni file salvato,
   `applyReceivedMeta` e poi la copertina (`CoverStore.saveFromBytes` con la `albumKey` nuova, `hasCover = true`).
3. Test: file senza tag + `meta` completo → riga con tutti i campi del `meta` e `userEdited = true`; file con tag
   diversi → vince il `meta`; `meta` con artista `null` → resta quello del file; `albumKey` ricalcolata (il brano
   finisce nell'album giusto); copertina salvata e visibile; nuova scansione del file invariato → la riga non cambia.

**Fatto quando:** test verdi; nel flusso con PIN e in quello delle offerte il brano compare in Libreria con i dati del
mittente.

### 37.4 — Scrittura dei tag nei file di Codecore
1. `TagChanges.discNumber` e `TagChanges.cover`; `MetadataGodTagWriter` li scrive; `SafeTagWriter` li verifica
   (disco uguale, copertina presente).
2. `writeTagsAfterDownload` in `SettingsStore` (default `true`) e provider; interruttore nella sezione dei tag
   (`tag_write_tiles.dart`), ARB nei 6 file. Sottotitolo: «Solo nei file che Codecore ha scaricato o ricevuto. L'ISRC
   resta nell'app.»
3. Servizio `DownloadTagger` (`lib/services/library/download_tagger.dart`) sopra `TrackFileSync`: controllo «dentro la
   cartella di download», fila un file alla volta, rinvio se il file suona (decisioni «Quali file», «Quando si scrive»,
   «File in riproduzione»).
4. Chiamate: fine di `_autoEnrich` in `youtube_providers.dart` (o subito se l'arricchimento automatico è spento),
   fine dell'arricchimento dell'importazione, ricezione (dopo 37.3).
5. Test: file dentro la cartella → scritto (titolo, artista, album, anno, genere, traccia, disco, copertina; **niente
   ISRC**); file fuori dalla cartella → mai scritto; opzione spenta → mai scritto; formato non scrivibile (opus) → nessun
   errore, una riga di registro; `sizeBytes`/`mtimeMs` aggiornati e `sha256` azzerato; file in riproduzione → scritto
   dopo il cambio di brano; due richieste sullo stesso file → una scrittura.

**Fatto quando:** test verdi; un m4a scaricato da YouTube, aperto con un altro lettore, mostra titolo, artista, album e
copertina.

### 37.5 — Ripiego dal nome del file
1. `splitArtistTitle` (logica pura, `lib/services/scanner/file_name_tags.dart`) e uso nella scansione solo con titolo e
   artista mancanti.
2. Test: «Cesare Cremonini - Poetica (Official Video).m4a» → Cesare Cremonini / Poetica; trattino lungo; nome senza
   trattino → titolo intero, artista vuoto; « - Poetica» → nessuna divisione; file con tag → il nome non conta.

**Fatto quando:** test verdi.

### 37.6 — Deezer al ricevente
1. Brano ricevuto con `meta.isrc` e «Metadati da Deezer» acceso → in fila a `QuietEnricher` (decisione «Deezer al
   ricevente»); poi, se l'opzione dei tag è accesa, `DownloadTagger` scrive i campi nuovi.
2. Test con `DeezerClient` finto: campo vuoto riempito per ISRC; campo del `meta` non sovrascritto; opzione spenta →
   nessuna richiesta.

**Fatto quando:** test verdi.

### 37.7 — Prova dal vivo e documentazione
1. Motorola → PC (offerta) e PC → Mi A3 (elenco con PIN): 5 brani scaricati da YouTube, con e senza copertina, uno
   con testo sincronizzato. Controllare in Libreria titolo, artista, album, anno, copertina, testo; aprire il file
   ricevuto con un altro lettore (tag scritti, niente ISRC).
2. Un dispositivo con l'APK di prima (Mi A3 con la build di oggi, **prima** dell'aggiornamento): riceve come oggi, nessun
   errore.
3. Sincronizzazione tra dispositivi fidati (24) di una playlist con 3 brani: arrivano con i metadati.
4. Download da YouTube sul PC con l'opzione accesa: file con i tag; con l'opzione spenta: file com'è oggi.
5. Esiti in `docs/PROGRESS.md`; in `docs/03-modello-dati.md` il blocco `meta`; in `docs/02-architettura.md` una riga
   per `TrackMeta` e `DownloadTagger`.

Regole dei telefoni come sempre: niente disinstallazioni sul Motorola, sul Mi A3 solo `install -r`; si toccano solo i
file di prova, per nome.
