# Fase 36 — Deezer per i metadati, Exportify semi-automatico

**Obiettivo:** due miglioramenti di cose che esistono già, senza funzioni nuove dal nulla.
1. **Deezer come fonte di metadati (mai di musica).** Oggi ogni fonte indovina il brano **dal testo** (titolo, artista):
   iTunes nell'arricchimento, MusicBrainz per genere e curiosità, YouTube Music nel secondo parere. Deezer è l'unica
   fonte pubblica senza chiave che trova un brano **per ISRC** (iTunes no: 0 su 3 nella 15.1). Con l'ISRC il brano è
   certo. Senza ISRC, Deezer dà comunque numero di traccia, disco e copertina 1000 px, e l'ISRC da salvare per le
   volte dopo.
2. **Sincronizzazione con Spotify via Exportify, semi-automatica.** Oggi la «Sincronizza» della fase 15 funziona una
   playlist alla volta: si scarica un CSV, lo si sceglie, si sceglie la playlist. Dopo questa fase: un promemoria
   (facoltativo), un tocco per aprire exportify.net, «Export All», e Codecore prende da solo lo ZIP con tutte le
   playlist, le abbina alle sue e mostra **un'anteprima unica** da confermare.

**Prerequisiti:** fase 5/6 (`EnrichmentService`, `ItunesClient`, `CoverStore`, `enrichJobProvider`), 12 e 15
(`readCsvPlaylist`, `ImportRow.isrc`, `PlaylistImportService.start/sync`, `diffImport`), 14.8 (`_byIsrc`), 19
(onboarding), 32 (`sourceCooldownProvider`), 35 (`SecondOpinion`, `MusicBrainzClient.genreFor`, `CuriosityFinder`).
**Principio:** meglio un buco in più che un dato falso. Deezer dà solo dati, mai audio né anteprime. Si scrivono solo
campi vuoti, con le regole di `EnrichmentService.apply`. La rete parte solo con l'opzione «Metadati da Deezer» attiva
(spenta di default, regola 9). Su Spotify non si salva nessuna credenziale e niente WebView (regola 10): l'utente
esporta da solo, Codecore prende il file. Pacchetti nuovi: **nessuno** (`archive` c'è già per il backup).

## Come è collegato oggi e cosa cambia

| Passo di oggi | Come funziona (file) | Con questa fase |
|---|---|---|
| Arricchimento di un brano | `EnrichmentService.propose`: iTunes (6 varianti di testo, `_pickBest`), LRCLIB, Wikipedia in parallelo | Prima Deezer (ISRC se c'è, altrimenti testo + album); iTunes **solo** se Deezer non conferma o non dà la copertina. LRCLIB e Wikipedia invariati |
| Numero di disco, ISRC | Mai trovati online (`ItunesClient._toMatch` non li legge) | Da Deezer (`disk_number`, `isrc`) |
| Copertina d'album | iTunes `searchAlbum` 600 px, per testo | Deezer `cover_xl` 1000 px (≈ 42 KB) se l'album passa il controllo d'edizione; altrimenti iTunes come oggi |
| Copertine nell'importazione («Cerca le copertine») | iTunes album + artista del CSV; l'ISRC non si usa (15.10) | Riga con ISRC → Deezer per ISRC, album confrontato con quello del CSV; poi iTunes. È l'idea 6 di `13-idee-future.md` |
| Identità per MusicBrainz (curiosità, genere del secondo parere) | Ricerca Lucene per testo (`recordings`) | Con l'ISRC: `/ws/2/isrc/{isrc}` (una richiesta, registrazione esatta); il testo resta il ripiego |
| ISRC del brano in libreria | Esiste solo nelle righe d'importazione (`PlaylistImportItems.isrc`, `isrcByTrack`); i tag del file non si leggono | Colonna `Tracks.isrc` (schema v14), riempita da importazione, scansione (TSRC/ISRC) e Deezer |
| Anno da Exportify | La colonna `Release Date` del CSV si ignora | Va nell'anno del brano, se vuoto, senza rete |
| Abbinamento a YouTube nell'importazione | `_byIsrc`: ricerca su YouTube Music con l'ISRC come testo (5/5, 34/34 sicure) | **Invariato**: YouTube non ha un indice per ISRC, Deezer non lo sostituisce |
| Secondo parere (fase 35) | YouTube Music per i brani «Da revisionare» | **Invariato**; ci arrivano meno brani perché il giro di base trova di più |
| Sincronizzazione con Spotify | Intro con 4 passi e indirizzo da **copiare**, scelta di un solo file, playlist trovata dal nome digitato (`_sameName`), «Sincronizza» per quella | Pulsante «Apri exportify.net», ZIP di «Export All», abbinamento automatico di tutte le playlist, un'anteprima, promemoria |
| Collegamento playlist ↔ sorgente | Nessuno, solo il nome | Nessuna colonna nuova: chiave del nome come la calcola Exportify, sul nome della playlist e sull'etichetta dell'ultima importazione (`PlaylistImports.sourceName`) |

### Dove Deezer **non** entra in questa fase, e perché
- **Pagina artista, discografia, nuove uscite (fasi 30, 34).** Deezer darebbe JSON stabile (`artist/{id}/albums` con
  `release_date` e `record_type` in 0,53 s per 122 album) al posto di InnerTube, che non è documentato. Ma tutto è
  legato agli id di YouTube Music: gli artisti seguiti, le uscite già viste (`browseId`), e il tocco che fa suonare.
  Servirebbe una mappa artista YTM ↔ Deezer e un abbinamento a YouTube per ogni uscita. Va fatto in una fase a parte,
  come **ripiego** quando InnerTube cambia (R74). Non serve per avere metadati migliori.
- **Casuale+ (31), ricerca intelligente (32).** Deezer dà solo id Deezer e anteprime di 30 s. Ogni suggerimento
  andrebbe abbinato di nuovo a YouTube per suonare, con una richiesta in più e lo stesso rischio di errore di oggi.
- **Righe senza ISRC (Soundiiz, TuneMyMusic, m3u, xspf).** Una ricerca Deezer potrebbe dare l'ISRC prima di
  `_byIsrc`. Ma costa una richiesta per riga e la strada titolo+artista funziona già. Si rimanda.
- **Genere.** Quello di Deezer è dell'album e grossolano («Pop» per McCartney, «Rock» per un cofanetto di Lennon).
  Serve solo come ultimo ripiego se iTunes non dà nulla. I generi del CSV Spotify si ignorano: per «Imagine» il
  fixture dice «christmas».
- **Etichetta, BPM, esplicito.** Deezer e il CSV li danno, ma nessuna schermata li mostra. Niente colonne finché non
  serve.

## Misure dal vivo (2026-10-22/23, PC di sviluppo, rete di casa)

| Richiesta | Tempo | Esito |
|---|---|---|
| Deezer `GET api.deezer.com/track/isrc:{isrc}`, 4 ISRC (Lucio Corsi, Dylan, Lennon, McCartney) | 0,24–0,32 s | 4/4 trovati, con `track_position`, `disk_number`, `bpm`, `release_date`, `album.id`, `album.cover_xl` (già quelli che iTunes non risolve nella 15.1) |
| Stessa, `GBAYE1000769` («Imagine - Remastered 2010», album del CSV «Imagine») | 0,24 s | Album **«Signature Box»**, disco 2, 2010: la registrazione è giusta, l'album no → serve il controllo d'edizione |
| Deezer `album/{id}` | ≈ 0,3 s | `record_type` (album/single/ep/compile), `nb_tracks`, `genres`, `label`, `upc`, `release_date`. «Signature Box» = `album`, **119 tracce** (un cofanetto non è sempre `compile`). Le tracce dentro `album/{id}` non hanno ISRC né posizione; `album/{id}/tracks` sì |
| Deezer `search?q=coldplay viva la vida` | ≈ 0,3 s | Primi: strumentale, live, suonerie. Con l'album («… viva la vida or death») primo quello giusto. «cremonini poetica»: primo giusto |
| Deezer ricerca avanzata `artist:"…" track:"…"` | — | `total 0` (con e senza codifica): **non si usa** |
| Deezer `search/artist?q=cremonini` | — | Primo «Cremonini» (42 fan), secondo «Cesare Cremonini» (127 967): l'artista si sceglie per nome **e** `nb_fan` |
| Deezer, errori e limiti | — | Errore = **HTTP 200** con `{"error":{"type":…,"code":800}}` (nessun dato); codice 4 = quota superata. Nessun header di limite; 60 richieste in fila (≈ 4 al secondo) tutte buone. Cookie Akamai (`_abck`) impostati: non servono |
| Copertina `cdn-images.dzcdn.net/…/1000x1000-…jpg` | — | 200, `image/jpeg`, 1000×1000, 42 KB; `1400x1400` dà 76 KB |
| iTunes, stessa copertina `600x600bb` / `1400x1400bb` / `3000x3000bb` | 0,23–0,28 s | 77 KB / 257 KB / 218 KB (3000 dà l'originale, 1425 px). Si resta a 600: lo spazio su disco conta più dei pixel |
| MusicBrainz `/ws/2/isrc/ITZ042500021?inc=artist-credits+releases` | 0,18 s | 1 registrazione con id, artista e `first-release-date`. `inc=genres` **non è ammesso** su questa risorsa (400): il genere resta una seconda richiesta (`genreFor`) |
| MusicBrainz `/ws/2/isrc/GBAYE1000769` | — | **2 registrazioni**: rimaster «2025-10-01» e originale «1971-09-09». Si sceglie quella con la durata più vicina |
| Exportify, sorgente (`PlaylistsExporter.tsx`, `PlaylistExporter.tsx`) | — | «Export All» salva **`spotify_playlists.zip`**: un CSV per playlist, nome = nome della playlist in minuscolo con ogni gruppo di ``\x00-\x1F \x7F / \ < > : ; " \| = , . ? * [ ] spazio`` sostituito da `_`, e ` (1)`, ` (2)` sui doppioni |
| Exportify, colonne (fixture `Just_a_mood.csv`) | — | `Track URI, ISRC, Track Name, Album Name, Artist Name(s), Release Date, Duration (ms), Popularity, Explicit, Added By, Added At, Genres, Record Label, …, Tempo, …`. Oggi se ne leggono titolo, artisti, album, durata, ISRC, URI |

## Decisioni

| Tema | Scelta |
|---|---|
| Opzione | «Metadati da Deezer» nelle impostazioni online e nella pagina «Online» dell'onboarding, **spenta di default**. Sottotitolo: solo dati (copertine, numeri di traccia), mai musica. Spenta = tutto come oggi |
| Condizioni di Deezer | Uso consentito: non commerciale, privato, in famiglia. Rischio da sapere: le condizioni vietano di usare i servizi in qualcosa che «promuove» lo scaricamento non autorizzato, e Codecore scarica da YouTube. Si limita il rischio: solo metadati, nessun marchio Deezer nell'interfaccia oltre al nome della fonte nel registro, opzione spenta di default. Lo dice anche la nota in fondo all'opzione |
| Client | `lib/services/online/deezer_client.dart` (`DeezerClient`) sopra `WebClient` (timeout e User-Agent nostri, mai l'email). Solo `trackByIsrc`, `searchTracks(q, limit 10)`, `album(id)`. JSON con `error`: codice 800 → null; codice 4 → `RateLimitedException` e raffreddamento di 10 min con `sourceCooldownProvider`. Modelli minimi in un file loro |
| Scelta del brano | ISRC noto → `trackByIsrc`, accettato se la durata locale (quando c'è) differisce di ≤ 3 s. Senza ISRC → `searchTracks("artista titolo album")` (album solo se noto), punteggio con `scoreCandidate` dell'import e `sureThreshold` (0.80), durata ≤ 3 s obbligatoria. Si scartano titoli con «instrumental», «karaoke», «live» se il titolo locale non li ha (`otherVersions` del matcher) |
| Controllo d'edizione | I campi dell'**album** (nome, copertina, anno, numero di traccia e di disco) si usano solo se `album(id)`: `record_type` ≠ `compile`, `nb_tracks` ≤ 40, e album locale vuoto oppure uguale dopo `matchTitleKey`. Altrimenti del brano Deezer si tengono solo ISRC (e artista, se vuoto). `album(id)` si chiede una volta per album per giro (mappa in memoria) |
| Cosa si scrive | Solo campi vuoti, `userEdited` rispettato, `albumKey` ricalcolata: artista, album, anno (`release_date` dell'album), numero di traccia, numero di disco, ISRC, copertina (`cover_xl`, solo se `!hasCover`, con `CoverStore.saveFromBytes`), genere (genere Deezer dell'album **solo** se iTunes non ne dà). Una riga `AppLog` per brano con la fonte |
| Ordine nel giro di base | Deezer (se attivo) → poi iTunes **solo** se Deezer non ha confermato o non ha dato la copertina. LRCLIB e Wikipedia in parallelo come oggi. Stesso `RateLimiter` per brano: al più 2 richieste Deezer per brano (brano + album) |
| ISRC in libreria | Schema **v14**: `Tracks.isrc` (testo, nullable, indice). Migrazione: copiato dall'ultima riga d'importazione con lo stesso `trackId`. Poi: scrittura quando una riga d'importazione si collega a un brano; lettura dai tag nella scansione (`TagInfo.isrc`; `audio_metadata_reader` legge TSRC e il commento Vorbis ISRC); da Deezer dopo una conferma. Mai scritto nei file in questa fase |
| MusicBrainz per ISRC | `MusicBrainzClient.recordingsByIsrc(isrc)` (`inc=artist-credits+releases`). Più registrazioni → quella con la durata più vicina alla locale. La usano `CuriosityFinder` (al posto della ricerca per testo) e `SecondOpinion` (genere) quando il brano ha l'ISRC; senza ISRC tutto come oggi |
| Anno da Exportify | `ImportRow.year` da `Release Date` (le prime 4 cifre, 1900–anno corrente+1), colonna `PlaylistImportItems.year` (v14). `applyTags` lo scrive se l'anno è vuoto. Solo questa colonna in più: genere, etichetta, BPM no (vedi sopra) |
| Copertine nell'importazione | Con «Cerca le copertine» e riga con ISRC e Deezer attivo: `trackByIsrc` → controllo d'edizione con l'album **del CSV** → `cover_xl`. Altrimenti `coverForAlbum` con iTunes, come oggi |
| ZIP di Exportify | `readExportifyZip(bytes)` in `Isolate.run`, con `ZipDecoder` di `archive`. Si leggono solo le voci `.csv` in cima allo ZIP. Limiti: ≤ 300 voci, ognuna ≤ `kMaxCsvBytes` **decompressa** (controllo sulla dimensione dichiarata prima di estrarre), totale ≤ 50 MB, ZIP ≤ 20 MB. Una voce che non si legge (per esempio gli album salvati, che hanno altre colonne) si salta e si conta |
| Abbinamento | `exportifyKey(nome)` = stessa regola di Exportify (vedi misure) + minuscolo. Voce `x.csv` ↔ playlist di Codecore con `exportifyKey(nome)` uguale, o con l'etichetta dell'ultima importazione uguale. Doppioni (` (1)`) o più playlist con la stessa chiave → «da scegliere», mai indovinate |
| Anteprima unica | Schermata «Sincronizza da Spotify»: per ogni voce abbinata `+N nuovi · −M rimossi` (da `previewSync`), spuntata se N + M > 0; quelle senza cambi raggruppate in fondo e non spuntate; quelle nuove («Nuova playlist») non spuntate. «Sincronizza» lancia `sync` o `start` per le spuntate, una dopo l'altra, con le opzioni dell'**ultima importazione** di quella playlist (`folderPath`, `numberFiles`, `linkOnly`, `fetchCovers`); le nuove con le opzioni predefinite |
| File in arrivo | **Android:** intent-filter su `MainActivity` per `VIEW` e `SEND` con `application/zip`, `text/csv`, `text/comma-separated-values` (così «Apri» dalla notifica di download di Chrome o «Condividi» dai File arrivano a Codecore). Kotlin copia il contenuto (`ContentResolver`) in un file della cache e passa il percorso a Dart su un canale (`codecore/incoming`). Lo ZIP apre l'anteprima unica, il CSV il flusso di oggi. **Desktop:** dopo «Apri exportify.net», quando l'app torna in primo piano entro 30 min, si cerca in Download uno `spotify_playlists*.zip` (o un `.csv`) più recente del tocco → banner «Trovata l'esportazione di Exportify» con «Sincronizza». Il selettore di file resta in tutti e due i casi |
| Apri Exportify | Pulsante «Apri exportify.net» nell'intro (accanto a «Copia»), con `LinkOpener` (Android, Windows, Linux). Si ricorda l'ora del tocco per il banner desktop |
| Promemoria | Impostazione «Ricordami di sincronizzare con Spotify»: spento (default), ogni 7, 14 o 30 giorni. `SettingsStore`: `exportifyRemindDays`, `exportifyLastSyncAt` (scritto a fine sincronizzazione Exportify, singola o di gruppo), `exportifySnoozeUntil`. Dopo `startupSettledProvider`, se è ora: scheda in Home con «Apri Exportify» e «Più tardi» (domani). Nessuna rete, nessuna notifica ad app chiusa (servirebbe WorkManager, non approvato) |
| Onboarding | Pagina facoltativa «Playlist da Spotify» dopo «Online»: due righe su come funziona, «Apri exportify.net», scelta del promemoria. `onboardingPageCount` 5. Saltarla lascia tutto spento |
| Rete nei test | Mai. `WebClient` finto con fixture in `test/fixtures/deezer/` e `test/fixtures/musicbrainz/`; ZIP costruiti nel test con `ZipEncoder` |
| Pacchetti nuovi | Nessuno |

## Task

### 36.1 — Verifiche preliminari e fixture
1. Fixture ridotte dalle risposte vere: `test/fixtures/deezer/track_isrc_corsi.json`, `track_isrc_imagine_box.json`,
   `album_volevo_essere_un_duro.json`, `album_signature_box.json`, `search_viva_la_vida.json` (strumentale e live in
   testa), `error_no_data.json`, `error_quota.json`; `test/fixtures/musicbrainz/isrc_two_recordings.json`.
2. `audio_metadata_reader` legge l'ISRC anche dagli `.m4a` (atomo `----:com.apple.iTunes:ISRC`)? Se no, solo mp3 e
   flac/ogg (annota).
3. **Tocca a te (utente):** «Export All» da exportify.net col proprio account → `spotify_playlists.zip` in
   `test/fixtures/` (o almeno l'elenco delle voci): c'è «Liked Songs»? ci sono gli album salvati? funziona con un
   account gratuito? Sul telefono: Chrome, a download finito, propone Codecore su «Apri»?

### 36.2 — Schema v14 e ISRC in libreria
`Tracks.isrc` con indice, `PlaylistImportItems.year`; migrazione `if (from < 14)` con la copia dell'ISRC dalle righe
d'importazione; `TagInfo.isrc` e lettura nel lettore dei tag; scansione e collegamento delle righe d'importazione che lo
scrivono se vuoto; `docs/03-modello-dati.md`. Test: migrazione da v13 (ISRC copiato dall'ultima riga); scansione con
`TagReader` finto che lo dà; brano con ISRC già presente non toccato.

### 36.3 — Client Deezer
`DeezerClient` con le regole della decisione «Client». Test con le fixture: ISRC trovato; codice 800 → null; codice 4
→ `RateLimitedException`; timeout → errore di rete, non «nessun dato».

### 36.4 — Scelta del brano e controllo d'edizione
Logica pura in `lib/services/online/deezer_match.dart`: scelta del brano (ISRC o testo) e controllo d'edizione.
Test: «Viva la Vida» → non la strumentale; durata fuori di 4 s → no; «Imagine» → brano sì, album «Signature Box» no
(119 tracce); Lucio Corsi → album sì; album locale diverso → solo ISRC.

### 36.5 — Arricchimento con Deezer
Opzione in `SettingsStore` e provider; Deezer in `EnrichmentService.propose` e `apply` con l'ordine e le regole delle
decisioni (iTunes solo se serve). `EnrichmentProposal` con disco, ISRC e fonte. Interruttore nelle impostazioni online,
con sottotitolo e nota sulle condizioni (ARB nei 6 file). Test: Deezer conferma con copertina → iTunes non chiamato;
Deezer senza conferma → iTunes come oggi; opzione spenta → nessuna richiesta Deezer; `userEdited` rispettato.

### 36.6 — Importazione: anno e copertine
`readCsvPlaylist` legge `Release Date` in `ImportRow.year`, salvato nella riga; `applyTags` lo scrive se vuoto;
`coverForAlbum` con il ramo per ISRC (decisione «Copertine nell'importazione»). Test: anno dal CSV; data non valida →
nessun anno; riga «Imagine» → niente copertina Deezer, si passa a iTunes.

### 36.7 — MusicBrainz per ISRC
`recordingsByIsrc` e uso in `CuriosityFinder` e `SecondOpinion` quando il brano ha l'ISRC. Test: due registrazioni →
quella con la durata più vicina; senza ISRC → ricerca per testo come oggi.

### 36.8 — ZIP di Exportify e abbinamento
`readExportifyZip` (limiti della decisione) e `exportifyKey` + abbinamento alle playlist (logica pura, in
`lib/services/import/`). Test: ZIP con 3 voci → 3 playlist; voce non CSV ignorata; voce troppo grande saltata prima di
estrarla; «Just a mood» ↔ `just_a_mood.csv`; due playlist con la stessa chiave → «da scegliere»; ` (1)` → «da
scegliere».

### 36.9 — «Sincronizza da Spotify» e «Apri exportify.net»
Schermata dell'anteprima unica (decisione «Anteprima unica»), avvio in fila, scrittura di `exportifyLastSyncAt`;
pulsante «Apri exportify.net» nell'intro; ingresso alla schermata dal selettore quando il file è uno ZIP. ARB nei 6
file. Test widget: voci spuntate secondo le regole; «Sincronizza» chiama `sync` solo per le spuntate.

### 36.10 — File in arrivo
Android: intent-filter, copia in cache e canale `codecore/incoming` in `MainActivity.kt` (anche a app già aperta,
`onNewIntent`). Desktop: controllo di Download al ritorno in primo piano e banner. Test: logica di scelta del file
(più recente del tocco, nome giusto, entro 30 min) con una cartella temporanea.

### 36.11 — Promemoria e onboarding
Impostazione, scheda in Home, «Più tardi», pagina facoltativa dell'onboarding (decisioni «Promemoria» e
«Onboarding»). ARB nei 6 file. Test: promemoria dovuto / non dovuto / rimandato; spento → mai.

### 36.12 — Prova dal vivo e documentazione
Su Motorola e PC: arricchimento con Deezer su 20 brani veri (quanti confermati, copertine, quanti iTunes evitati);
un cofanetto non scritto come album; importazione di un CSV Exportify con anno e copertine; «Export All» → «Apri» da
Chrome → anteprima unica → sincronizzazione di più playlist; promemoria. Esiti in `docs/PROGRESS.md`, una riga in
`docs/02-architettura.md` per `DeezerClient` e il canale `codecore/incoming`.
