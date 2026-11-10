# Fase 35 — Secondo parere da YouTube Music in «Da revisionare»

**Obiettivo:** i brani in **Libreria → «Da revisionare»** ricevono da soli un **secondo tentativo con YouTube Music**
(artista, album, copertina 544 px, anno, numero di traccia), applicato **solo se YouTube Music conferma** che è
proprio quel brano. Dopo la conferma si cercano anche il **genere** (MusicBrainz) e il **testo** (scheda «Testo» di
YouTube Music). Le **curiosità** ricevono due ripieghi senza chiave quando Wikipedia non dà nulla: la descrizione
della pagina artista di YouTube Music e le note di Discogs. Si corregge anche «Riprova», che oggi può far sparire i
brani dalla lista.
**Prerequisiti:** fase 29.1 («Da revisionare»: `ReviewQueries`, `ReviewReason`, `ReviewActions`), 30 (`YtmCatalog`,
`YtmArtistPage.description`, `YtmCatalog.album`), 32 (`sourceCooldownProvider`), 21 (`scoreCandidate`,
`sureThreshold` dell'import CSV), 6 (`EnrichmentService`, `enrichJobProvider`, `MusicBrainzClient`, `CuriosityFinder`).
**Principio:** meglio un buco in più che un dato falso. Si scrivono solo campi vuoti, mai si sovrascrive; la rete
parte solo dall'apertura di «Da revisionare» (una volta per brano) e da «Riprova». Nessun pacchetto nuovo, nessuna
chiave API. Progetto approvato: `docs/superpowers/specs/2026-10-22-secondo-parere-ytm-design.md` (lo si legge per i
perché; questo documento è la fonte per il «come»).

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)

| Richiesta | Tempo | Esito |
|---|---|---|
| YTM `POST /youtubei/v1/next` `{"videoId":…}` (`WEB_REMIX 1.20250101.01.00`, `hl it`) | 0,54 s | 200. Schede in `contents.singleColumnMusicWatchNextResultsRenderer.tabbedRenderer.watchNextTabbedResultsRenderer.tabs[].tabRenderer`; la scheda del testo ha `endpoint.browseEndpoint.browseId` che inizia per **`MPLY`** (di solito la seconda: cercarla per prefisso, non per indice). Brano senza testo = nessuna scheda `MPLY` |
| YTM `POST /youtubei/v1/browse` `{"browseId":"MPLY…"}` | 0,62 s, 3 KB | 200. `musicDescriptionShelfRenderer`: `description.runs[].text` = testo con `\r\n` (54 righe per «Viva la Vida»); `footer.runs[].text` = «Fonte: LyricFind» (crediti **fuori** dal testo) |
| MusicBrainz `recording` `recording:"Viva la Vida" AND artist:Coldplay` | — | Prima i **live e i bootleg**, spesso senza `length` |
| Stessa, con `AND status:official AND primarytype:album AND NOT secondarytype:live` | — | Primo risultato giusto (244 000 ms, release-group «Viva la Vida or Death and All His Friends») |
| MusicBrainz, generi (`inc=genres`) | — | **Registrazione inaffidabile** («jazz» con 1 voto, o vuoto); release-group buono (alternative rock 12); **artista** buono (alternative rock 36, pop 15) |
| MusicBrainz, collegamento Discogs | — | Sta sul **release-group** (`release-group/{id}?inc=url-rels`, relazione `discogs`, «https://www.discogs.com/master/26600»), non sull'uscita |
| Discogs `GET api.discogs.com/masters/26600` senza chiave | 0,54 s | 200, header `x-discogs-ratelimit: 25` (al minuto). `notes` parla dell'**album**, con BBCode `[url=…]…[/url]`, `[a=…]` |
| Discogs `releases/{main_release}` | — | `notes` sulla confezione («Gatefold cardboard sleeve…»): **inutili** |
| MusicBrainz in generale | — | 503 frequenti: `_get` riprova già una volta (pausa 1,1 s fra richieste) |

## Decisioni

| Tema | Scelta |
|---|---|
| Conferma | Ricerca **brani** (`InnertubeClient.searchSongs`, primi 5) con titolo e artista locali così come sono. Un risultato conferma se: ha `albumId`; non supera 20 min; `scoreCandidate(ImportRow(titolo, artista, album, durata locali), r) ≥ sureThreshold` (0.80); la durata locale è **nota** e differisce di **≤ 3 s**. Artista locale vuoto: in più titolo identico dopo `matchTitleKey` e nessun altro risultato ≥ 0.80 con artista diverso (omonimi). Si valutano tutti e si prende il migliore che passa. Senza durata locale: nessuna conferma |
| Cosa si scrive | Solo campi vuoti, regole di `EnrichmentService.apply` (`userEdited`, `albumKey` ricalcolata, copertina d'album solo se il file non c'è): artista (primo del risultato), album (`YtResult.album`), copertina (pagina album 544 px, se `!hasCover`), anno e numero di traccia (pagina album; traccia = riga con lo stesso videoId, o titolo uguale dopo `matchTitleKey`). Album locale **presente e diverso** (`matchTitleKey`) → si scrive **solo l'artista** e niente genere, testo, Discogs |
| Stato | Conferma con almeno un campo scritto o no → `enrichStatus = 1`. Nessuna conferma → lo stato resta quello del giro di base. Una riga `AppLog` per ogni conferma (videoId, campi scritti) |
| Genere | Solo dopo una conferma e solo se vuoto. Registrazione MusicBrainz scelta con la ricerca filtrata (ufficiale, album, non live; `matchKey` su titolo e artista; se `length` c'è, entro 3 s dalla durata locale). Genere della **registrazione solo con ≥ 2 voti**; altrimenti il genere con più voti (≥ 1) dell'**artista** della registrazione. Iniziale maiuscola come `_titleCase` di `wikipedia_client.dart`. Niente genere dal release-group (scelta: l'artista basta e risparmia una richiesta) |
| Testo | Solo dopo una conferma, solo se il brano non ha né `lyricsPlain` né `lyricsSynced`, dopo LRCLIB (già nel giro di base). `next` del videoId confermato → scheda `MPLY…` → `browse` → `description` unita, `\r\n` → `\n`. Va in `lyricsPlain`, **mai** in `lyricsSynced`. Scartato se meno di 3 righe non vuote o se è solo una riga di crediti. Il `footer` non si salva |
| Quando parte | (a) Apertura di «Da revisionare»: per i brani in lista **mai controllati**, in sottofondo, uno alla volta. Insieme dei controllati nelle impostazioni (come «Va bene così»; niente migrazione); un brano entra solo se la ricerca YTM è andata a buon fine (confermato o no). (b) «Riprova»: giro di base, poi secondo parere su chi ha ancora buchi, ignorando l'insieme. Se un altro lavoro gira: all'apertura si aspetta in silenzio (si riprova alla prossima apertura); «Riprova» dà «occupato» come oggi |
| Limiti | `sourceCooldownProvider` (stesso della ricerca intelligente): YouTube in raffreddamento → non parte; 429 o «rallenta» → lo fa scattare, il lavoro si ferma e lo dice; i brani non raggiunti restano non controllati. Un brano alla volta con il `RateLimiter` dell'arricchimento; per brano al più: 1 ricerca, 1 pagina album (cache `YtmCatalog`), 2 richieste per il testo, 2 MusicBrainz (ricerca + artista) |
| «Riprova» corretto | Non si azzera più `enrichStatus`. `enrichJobProvider.start` riceve `force: true`, che salta il controllo su stato 2 di `needsEnrichment`. Lo stato si scrive solo per i brani davvero provati: un brano non raggiunto resta com'era, in lista |
| Interfaccia | In «Da revisionare», sotto il titolo, finché il lavoro gira: riga «Controllo con YouTube Music, 3 di 12» con un pulsante «Ferma». A fine lavoro, se almeno un brano ha avuto un campo scritto: snackbar «Aggiornati 5 brani con YouTube Music» (plurale ICU). Dopo un 429: «YouTube Music chiede di rallentare: riprovo più tardi». Nient'altro cambia |
| Curiosità, artista | In `CuriosityFinder`, solo quando Wikipedia dà null per l'artista: `YtmCatalog.topArtist(artista, hl)` → `artist(id, hl)` → `YtmArtistPage.description` se ≥ 80 caratteri; fonte = `https://music.youtube.com/channel/{id}`. Vale ovunque si cerchino curiosità (non solo in «Da revisionare») |
| Curiosità, brano | Solo quando Wikipedia dà null per il brano: registrazione MusicBrainz già identificata → suo release-group (`inc=release-groups` o dalla ricerca filtrata) → `release-group/{id}?inc=url-rels` → relazione `discogs` con `/master/N` → `api.discogs.com/masters/N` → `notes` senza BBCode (`[url=x]testo[/url]` → testo, `[a=Nome]` → Nome, altri tag tolti), ≥ 80 caratteri. Fonte = `https://www.discogs.com/master/N`. Al più 1 richiesta Discogs per brano; 429 e altri errori → `songError` come oggi. Il testo parla **dell'album**: la scheda lo dice con l'etichetta «Dall'album, da Discogs» |
| Rete nei test | Mai. YTM con `test/support/fake_ytm.dart`, MusicBrainz e Discogs con un `WebClient` finto e fixture in `test/fixtures/` |
| Pacchetti nuovi | Nessuno |

## Task

### 35.1 — Fixture
Ridotte (senza `trackingParams`/`clickTrackingParams`), ricavate dalle risposte vere della tabella:
`test/fixtures/innertube/ytm_next_lyrics_tab.json` (con scheda `MPLY`), `ytm_next_no_lyrics.json` (senza),
`ytm_lyrics_browse.json` (`musicDescriptionShelfRenderer` con footer), `test/fixtures/musicbrainz/recording_search_official.json`,
`artist_genres.json`, `release_group_url_rels.json`, `test/fixtures/discogs/master_notes.json` (con BBCode).

### 35.2 — Conferma e scrittura
Servizio nuovo `lib/services/online/second_opinion.dart` (`SecondOpinion`) che, dato un `Track`, cerca, valuta (regole
«Conferma») e scrive (regole «Cosa si scrive» e «Stato»). Restituisce l'esito: non confermato, confermato con i campi
scritti, errore di rete, rallenta. Test: conferma giusta; durata fuori di 4 s → no; senza durata → no; omonimi senza
artista → no; album locale diverso → solo artista; campi già pieni non toccati; `userEdited` rispettato.

### 35.3 — «Riprova» con `force`
`enrichJobProvider.start(..., force: true)` e `enrichMany`/`needsEnrichment` con la stessa opzione; via `resetStatus` da
`ReviewActions.retry`. Test: lavoro annullato a metà → i brani non raggiunti restano nella lista con lo stato di prima.

### 35.4 — Quando parte, controllati e raffreddamento
Insieme dei controllati in `SettingsStore` (`readReviewChecked`/`writeReviewChecked`), lavoro del secondo parere
(provider suo con stato `running`, `done`, `total`, `updated`, `throttled`, `cancel()`), avvio all'apertura della
schermata e in coda a «Riprova». Raffreddamento con `sourceCooldownProvider`. Test: apertura → solo i mai controllati;
errore di rete → non segnato; 429 → si ferma e accende il raffreddamento; raffreddamento acceso → non parte.

### 35.5 — Genere da MusicBrainz
`MusicBrainzClient`: ricerca filtrata (ufficiale, album, non live) con `length`, generi della registrazione e
dell'artista (`inc=genres`). Regola ≥ 2 voti / artista ≥ 1. Chiamato da `SecondOpinion` dopo una conferma. Test con le
fixture: 1 voto sulla registrazione → genere dell'artista; registrazione con `length` lontana → scartata.

### 35.6 — Testo dalla scheda «Testo»
Metodo nuovo nel client InnerTube (`lyrics(videoId)` → `String?`) con il parser in un file suo; chiamato da
`SecondOpinion` dopo una conferma. Test: testo con `\r\n` → righe giuste, footer escluso; senza scheda → null; due righe
→ null.

### 35.7 — Interfaccia e ARB
Riga di avanzamento con «Ferma» e i due messaggi in `review_screen.dart`; chiavi in 6 ARB (it, en, de, es, fr, pt) con
le regole di `arb_test.dart`. Test widget: riga visibile durante il lavoro, sparisce a fine; snackbar con il numero.

### 35.8 — Curiosità: YouTube Music e Discogs
Ripieghi in `CuriosityFinder` (decisioni «Curiosità, artista» e «Curiosità, brano»); client Discogs minimo
(`lib/services/online/discogs_client.dart`, solo `master(id)`); pulizia BBCode con test. Etichetta «Dall'album, da
Discogs» nella scheda delle curiosità (ARB, dopo la 35.7). Test: Wikipedia null → note Discogs; note corte → null;
Wikipedia null per l'artista → descrizione YTM.

### 35.9 — Prova dal vivo e documentazione
Sul Motorola (brani «Da revisionare» reali, con hot reload): avanzamento, brani confermati usciti dalla lista, un brano
dubbio rimasto, «Riprova» interrotta senza brani spariti, genere e testo scritti, curiosità da Discogs. Esiti in
`docs/PROGRESS.md`.
