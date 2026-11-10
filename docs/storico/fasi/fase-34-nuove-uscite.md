# Fase 34 — Nuove uscite degli artisti

**Obiettivo:** sapere quando i **tuoi artisti** pubblicano qualcosa di nuovo (album, singoli, EP). Si seguono con
un pulsante **«Segui»** sulla pagina artista della fase 30 e, se vuoi, in automatico si seguono anche gli artisti che
**ascolti di più**. Un controllo **al giorno**, all'apertura dell'app: le novità compaiono in **Home → «Nuove
uscite»** e, su Android, in una **notifica**. Un tocco apre la pagina album (fase 30.9) con «Ascolta» e «Scarica album».
**Prerequisiti:** fase 30 (catalogo YouTube Music: `parseArtistPage` con le sezioni per tipo, `YtmRelease`,
`YtmCatalog`, `ArtistPageScreen`, `OnlineAlbumScreen`, `pickYtmArtist` della 30.11, `googleThumbAt`), 20
(cronologia `plays`), 13 (backup), 28.8 (`startupSettledProvider`), 31.12 (`networkKindProvider`, canale `codecore/net`).
**Principio:** la rete parte solo per artisti che l'utente ha scelto di seguire (o con l'opzione dei «più
ascoltati» accesa), al più una volta al giorno, una richiesta leggera per artista, in serie. Il primo controllo di
un artista segna tutto come già visto: niente valanga di «novità» del passato. Nessun pacchetto nuovo; il controllo ad
app chiusa (WorkManager) è un extra da approvare. Assente nella variante `lite`.

## Misure dal vivo (2026-10-22, PC di sviluppo, rete di casa)
`POST https://music.youtube.com/youtubei/v1/browse?prettyPrint=false`, contesto `WEB_REMIX 1.20250101.01.00`, id
degli artisti trovati con il filtro artisti della fase 30.

| Richiesta | Tempo | Peso gzip | Cosa c'è |
|---|---|---|---|
| Pagina artista **intera** (Lucio Corsi · Vasco Rossi · Coldplay · Taylor Swift) | 0,31–0,39 s | 22 · 34 · 36 · 36 KB | come in fase 30 |
| Stessa pagina con la **maschera delle uscite** (sotto) | 0,29–0,41 s | **6,5 · 10,4 · 11,4 · 11,6 KB** | intestazione (nome) e solo i `musicCarouselShelfRenderer`, con copertine |
| Maschera senza copertine (solo id, titolo, sottotitolo) | 0,33 s | 5,0 KB | non basta: in Home serve la copertina |
| Carosello «Albums» / «Singles & EPs» | — | — | al più **10** voci, con `moreContentButton` (discografia) quando ce ne sono di più (Lucio Corsi: 6 e 7, senza «more») |
| Sottotitolo delle uscite | — | — | **solo l'anno**: album «2025»; singoli «Single • 2025» (`hl en`) / «Singolo • 2025» (`hl it`). Nessuna data precisa |
| Ordine | — | — | dalla più recente, **ma non sempre**: in Lucio Corsi «La Chitarra Nella Roccia (Live)» (2025) è l'ultima del carosello «Album», dopo il 2015 |
| Varianti | — | — | Taylor Swift: «The Life of a Showgirl: The …» (2026), «… + Acoustic» (2025), «The Life of a Showgirl» (2025), «… (Track by Track)» (2025) = 4 voci per un album; Coldplay «Moon Music» + «Moon Music (Full Moon Edition)»; Vasco Rossi: riedizioni «40° RPLAY» (2022–2025), ognuna con il suo id |
| Singoli 2026 (oggi è il 22/10/2026) | — | — | Taylor Swift «Patient Zero», «I Knew It, I Knew You…», «Elizabeth Taylor»; Vasco Rossi «Una Nuova Canzone Per Lei…», «Marea (Vasco Live 20\|26)» |

Maschera delle uscite: `header.musicImmersiveHeaderRenderer(title),contents.singleColumnBrowseResultsRenderer.tabs.tabRenderer.content.sectionListRenderer.contents(musicCarouselShelfRenderer(header.musicCarouselShelfBasicHeaderRenderer(title,moreContentButton),contents.musicTwoRowItemRenderer(title,subtitle,navigationEndpoint,thumbnailRenderer)))`

Stima: 50 artisti × ≈ 10 KB ≈ **0,5 MB** e ≈ 1 minuto e mezzo (in serie, 1,5 s fra due) per giro; un giro al giorno.

## Decisioni
| Tema | Scelta |
|---|---|
| Chi si controlla | (1) **Seguiti**: pulsante «Segui» nella pagina artista online (30.8) e «Segui su YouTube Music» nella pagina artista della libreria (passa da `pickYtmArtist`: un nome uguale → si segue, più di uno → foglio di scelta, nessuno → messaggio). (2) **Più ascoltati** (opzione): i **15** artisti con più ascolto negli ultimi 90 giorni (`plays`; senza cronologia, la somma di `play_count`), ognuno collegato all'id di YouTube Music **solo** se `pickYtmArtist` trova un unico nome uguale; altrimenti «da confermare» nella pagina «Artisti seguiti» (mai indovinato). Tetto: 100 seguiti + 15 automatici |
| Smettere | «Non seguire più» su un seguito lo toglie; su un automatico lo **esclude** (non torna anche se resta fra i più ascoltati). Campanella per artista = niente notifica, ma la novità compare in Home |
| Dati | Schema **v13** (la v12 è della fase 33). `followed_artists`: `ytm_id` (pk), `name`, `thumb_url`, `origin` (0 seguito · 1 automatico), `excluded`, `muted`, `followed_at`, `last_checked_at`, `last_error`, `checks_failed`. `artist_releases`: `browse_id` (pk), `artist_id` (fk, cascade), `title`, `kind` (album · singolo/EP, dalla sezione), `year`, `thumb_url`, `first_seen_at`, `is_new`, `opened_at`, `group_key` |
| Prima volta | Il primo controllo di un artista (nessuna riga in `artist_releases`) salva tutto con `is_new = false`: nessuna notifica per il passato |
| Cosa è «nuovo» | id `MPREb_…` **mai visto** e anno ≥ anno corrente − 1 (un'uscita vecchia che YouTube mostra solo ora non è una novità). Le **varianti** arrivate nello stesso giro (`group_key` = `matchTitleKey` del titolo senza parentesi, senza ciò che segue «:» o «+», senza «Deluxe», «Edition», «Version») diventano una voce sola «e altre N versioni»; una riedizione con un titolo suo resta una novità (Vasco «40° RPLAY»). Ordine per anno e poi per `first_seen_at`, mai per posizione nel carosello |
| Lettura | `browse` dell'artista con la maschera delle uscite e `hl` della lingua dell'app; si riusa `parseArtistPage` della fase 30 (sezioni riconosciute per tipo: caroselli di `MUSIC_PAGE_TYPE_ALBUM`); manca un carosello = nessuna uscita di quel tipo. Il controllo **non** usa né scrive la `CatalogCache` (dati sempre freschi, maschera diversa). Nessun ripiego yt-dlp (non esiste per la pagina artista, R74) |
| Quando | All'apertura dell'app, dopo `startupSettledProvider` + 30 s, **se l'ultimo giro è di oltre 24 h fa**; ogni 24 h se l'app resta aperta; «Controlla ora» nella pagina «Nuove uscite». Mai a rete assente; «Solo su Wi‑Fi» (rete non a consumo) **spento** di serie (≈ 0,5 MB al giorno). **Ad app chiusa nulla**: servirebbe WorkManager (pacchetto nuovo `workmanager`): extra facoltativo 34.11, da approvare |
| Limiti | In serie, 1,5 s fra due artisti; 429 → giro fermato, riprova dopo 6 h; `InnerTubeChanged` → giro fermato, riga nel log, riprova al giro dopo; `ArtistNotFound` 3 giri di fila → artista segnato «non trovato» (resta, non si controlla più finché l'utente non tocca «Riprova») |
| Regola §9 (rete solo da azioni o opzioni attive) | Seguire è un'azione dell'utente. I **più ascoltati** partono solo con l'opzione accesa: una card **una volta** in Home «Vuoi sapere quando escono brani nuovi dei tuoi artisti più ascoltati? [Attiva] [No, grazie]», poi l'interruttore in Impostazioni → Online |
| Home | Sezione **«Nuove uscite»** subito dopo «Riprendi» (solo se c'è qualcosa degli ultimi 30 giorni): card con copertina (`googleThumbAt` 226), titolo, artista, «Album · 2026» / «Singolo · 2026», pallino «nuovo» finché non la apri; al più 10; «Mostra tutte» → `NewReleasesScreen` (90 giorni, filtro per artista, «Artisti seguiti (N)», «Controlla ora», ora dell'ultimo controllo). Tocco → `OnlineAlbumScreen` (30.9) |
| Notifica (Android) | Una per giro, solo se ci sono novità di artisti non silenziati: «3 nuove uscite: Lucio Corsi, Vasco Rossi» con «Mostra» → l'app si apre su «Nuove uscite». Kotlin in un file nuovo `NotifyBridge.kt` (canale `codecore/notify`, canale di notifica «Nuove uscite», importanza predefinita, `PendingIntent` con un extra letto da Dart all'avvio e al ritorno). Il permesso `POST_NOTIFICATIONS` è già dichiarato e chiesto (importazioni); se negato resta Home. Interruttore «Notifiche delle nuove uscite». Desktop: niente notifica di sistema (Linux via `dbus`, già fra le dipendenze: fuori fase) |
| Backup | Ripristino completo: DB. Formato portabile: `followedArtists` (id, nome, origine, esclusi, silenziati); le uscite **no** (dopo un'unione il primo giro le segna come viste: nessuna notifica falsa) |
| File condivisi | `lib/ui/screens/home/home_screen.dart` è toccato anche dalla fase 33 (riga «Le tue radio»), `MainActivity.kt` dalle fasi 29.2 e 31.12: controllare `git status`/`git log` prima; il codice Android nuovo sta in un file suo |
| Pacchetti nuovi | Nessuno (extra 34.11: `workmanager`, da approvare) |

## Task

### 34.1 — Verifiche preliminari e fixture
Gli esiti dal PC sono nella tabella «Misure dal vivo». Restano:
1. Fixture ridotte (senza `trackingParams`/`clickTrackingParams`), con la maschera delle uscite:
   `test/fixtures/innertube/ytm_artist_releases.json` (Taylor Swift: varianti dello stesso album, singoli 2026),
   `ytm_artist_releases_it.json` (Lucio Corsi, `hl it`, caroselli senza «more», live in fondo),
   `ytm_artist_releases_reissues.json` (Vasco Rossi, riedizioni). Una seconda copia di una delle tre con un'uscita
   tolta a mano serve al test del confronto (34.2).
2. **Motorola edge 40 (LTE):** tempo di 20 controlli in serie con lo script di prova (fuori da `lib/`).
3. **Motorola (Android 15):** una notifica di prova da Kotlin con `PendingIntent` ed extra: arriva a Dart aprendo
   l'app da chiusa e da sfondo? (serve a 34.9).
**Verifica:** fixture nel repository, note in PROGRESS. **Stop** se la maschera delle uscite non restituisce i caroselli
o se l'extra della notifica non arriva a Dart: riportare.

### 34.2 — Confronto delle uscite (logica pura)
**File:** `lib/services/releases/release_diff.dart`, `test/services/releases/release_diff_test.dart`
1. `releaseYear(String subtitle)` (prima cifra di 4 numeri plausibile, 1900–anno corrente + 1); `releaseGroupKey(title)`.
2. `diffReleases({known: Set<String>, fetched: List<YtmReleaseShelf>, firstCheck, now})` → `ReleaseDiff {toStore,
   fresh: List<NewRelease{release, kind, year, groupKey, variants}>}` (regole in Decisioni).
**Verifica:** primo controllo → tutto salvato, niente di nuovo; un id nuovo dell'anno → nuovo; un id nuovo di 5 anni fa →
salvato, non nuovo; quattro varianti di «The Life of a Showgirl» → una voce con 3 varianti; riedizione con titolo
diverso → nuova; carosello mancante → nessun errore; ordine per anno e non per posizione.

### 34.3 — Schema v13 e repository
**File:** `lib/data/db/tables.dart` (`FollowedArtists`, `ArtistReleases`), `app_database.dart` (v13),
`lib/data/repositories/follow_repository.dart`, `release_repository.dart`, `test/data/migration_test.dart`,
`test/data/follow_repository_test.dart`
1. Tabelle e migrazione (`createTable`); `dart run build_runner build`.
2. `FollowRepository`: `follow(ref)`, `unfollow(id)` (seguito → riga via; automatico → `excluded`), `setMuted`,
   `watchFollowed()`, `toCheck({limit})` (non esclusi, non «non trovati», per `last_checked_at` più vecchio),
   `markChecked(id, {error})`.
3. `ReleaseRepository`: `knownIds(artistId)`, `store(artistId, diff)` (una transazione), `watchRecent({days, onlyNew})`,
   `markOpened(browseId)`, `countNew()`.
**Verifica:** un DB v12 diventa v13 e tiene le stazioni radio e i brani; seguire due volte = una riga; non seguire un
automatico lo esclude e `toCheck` non lo dà più; togliere un artista cancella le sue uscite; `store` del primo controllo
non crea novità.

### 34.4 — Artisti più ascoltati in automatico
**File:** `lib/data/repositories/stats_queries.dart` (`topArtistsSince(from, {limit})`),
`lib/services/releases/auto_follow.dart` (puro), `lib/providers/releases_providers.dart`,
`test/services/releases/auto_follow_test.dart`, `test/data/stats_queries_test.dart`
1. `topArtistsSince`: per artista principale (`matchKey(extractPrimaryArtist)`, come la libreria), ascolto in ms
   negli ultimi 90 giorni; senza righe in `plays`, somma di `play_count`.
2. `planAutoFollow({top, followed, excluded, resolved})` → da aggiungere / da togliere (un automatico che esce dai 15
   si toglie, un seguito a mano mai) / da confermare (nessun id unico).
3. Risoluzione: per i nomi nuovi una ricerca artisti della fase 30 (`YtmCatalog.searchArtists`) e `pickYtmArtist`;
   al più 5 risoluzioni per giro, 1,5 s fra due; esito ricordato 30 giorni (anche «nessuno»).
**Verifica:** `topArtistsSince` con cronologia e senza; il piano non tocca i seguiti a mano, non riaggiunge gli
esclusi, mette «da confermare» due omonimi; tetto di 15.

### 34.5 — Il giro di controllo
**File:** `lib/services/releases/release_checker.dart`, `test/services/releases/release_checker_test.dart`
1. `ReleaseChecker(catalog, follows, releases, {now, gap = 1,5 s})`: `run()` → per ogni artista di `toCheck(limit:
   115)`: `catalog.releases(id, hl)` (maschera delle uscite, nuovo metodo di `YtmCatalog` della fase 30 senza cache)
   → `diffReleases` → `store`; errori per artista (vedi Limiti); 429 → stop e `retryAt` = ora + 6 h.
   Restituisce `CheckOutcome {fresh, checked, failed, stoppedBy}`.
2. Annullabile (cancel token) se l'app va in pausa di rete o l'utente spegne l'opzione.
**Verifica (catalogo finto e orologio finto):** primo giro di due artisti → niente novità; secondo giro con un'uscita
in più → una novità; 429 al secondo artista → il terzo non si chiede e `retryAt` + 6 h; `ArtistNotFound` tre giri di
fila → «non trovato»; attesa di 1,5 s fra due richieste.

### 34.6 — Quando parte il giro e impostazioni
**File:** `lib/services/releases/check_schedule.dart` (puro), `lib/providers/releases_providers.dart`
(`ReleaseCheckController`), `lib/data/settings/settings_store.dart` (`releasesTopArtists`, `releasesNotify`,
`releasesUnmeteredOnly`, `releasesLastRunAt`, `releasesRetryAt`, `releasesTopCardSeen`), `lib/main.dart`,
`lib/ui/screens/settings/release_settings_tiles.dart` (nuovo: gruppo «Nuove uscite» in `settings_screen.dart`), ARB,
`test/services/releases/check_schedule_test.dart`
1. `isCheckDue({lastRunAt, retryAt, now, hasArtists, network, unmeteredOnly})`.
2. Controller: dopo `startupSettledProvider` + 30 s e poi ogni ora guarda se è dovuto; avvia `ReleaseChecker`; riga
   nel Centro Attività solo con «Controlla ora» (il giro automatico è silenzioso, finisce nel Registro).
**Verifica:** dovuto dopo 24 h e non prima; mai senza artisti, senza rete, su rete a consumo con «Solo su Wi‑Fi», prima di
`retryAt`; «Controlla ora» ignora le 24 h ma non `retryAt`.

### 34.7 — «Segui» e «Artisti seguiti»
**File:** `lib/ui/screens/online/artist_page_screen.dart` (pulsante nell'intestazione),
`lib/ui/screens/library/artist_screen.dart` («Segui su YouTube Music»), `lib/ui/screens/releases/followed_artists_screen.dart`,
`lib/ui/screens/online/artist_picker_sheet.dart` (della 30.11, riusato), ARB, `test/ui/follow_button_test.dart`
1. Pulsante «Segui» / «Segui già» (con conferma per smettere); seguire avvia subito il primo controllo di quell'artista
   (quello che segna tutto come visto), così la pagina «Nuove uscite» non resta vuota senza motivo.
2. `FollowedArtistsScreen`: seguiti e automatici (etichetta «Più ascoltato»), campanella, «Non seguire più», righe «da
   confermare» con il foglio di scelta, righe «non trovato» con «Riprova».
**Verifica:** widget test: il pulsante cambia stato e chiama il repository; un automatico tolto non ricompare.
**Telefono:** seguire 3 artisti dalla ricerca e uno dalla libreria; la lista li mostra con la foto.

### 34.8 — «Nuove uscite» in Home e pagina dedicata
**File:** `lib/ui/screens/home/home_screen.dart` (vedi «File condivisi»), `lib/ui/screens/releases/new_releases_shelf.dart`,
`lib/ui/screens/releases/new_releases_screen.dart`, `lib/ui/screens/releases/top_artists_card.dart` (la card una
tantum), ARB, `test/ui/new_releases_shelf_test.dart`
1. Scaffale come le altre mensole di Home (`ListView.builder` orizzontale, `EnterOnce`), card della 30.9; aprire una
   card la segna aperta (`markOpened`).
2. Pagina con elenco per data (90 giorni), filtro per artista, «Controlla ora», «Artisti seguiti (N)», ora dell'ultimo
   controllo ed eventuale motivo dell'ultimo stop («YouTube chiede una pausa: riprovo alle 18:40»).
3. Card una tantum per i più ascoltati (Decisioni), solo se l'opzione non è mai stata scelta.
**Verifica:** widget test: scaffale nascosto senza novità, mostrato con una, pallino che sparisce dopo l'apertura.
**Telefono (Mi A3):** Home con lo scaffale senza scatti; tocco → pagina album con «Scarica album».

### 34.9 — Notifica Android
**File:** `android/app/src/main/kotlin/com/codecore/player/NotifyBridge.kt` (+ una riga in `MainActivity.kt`, vedi
«File condivisi»), `lib/services/android/release_notifier.dart`, `lib/providers/releases_providers.dart`,
`lib/ui/shell/app_shell.dart` (apertura su «Nuove uscite» dall'extra: solo lettura e `ShellNav.open`), ARB,
`test/services/releases/release_notification_text_test.dart`
1. Canale `codecore/notify`: `showReleases(title, body)` e `takeLaunchTarget()` (l'extra dell'ultimo `Intent`, poi
   azzerato). Canale di notifica «Nuove uscite» creato una volta.
2. Testo (puro, `releaseNotificationText(fresh, l10n)`): «Nuova uscita: <titolo> di <artista>» per una, «<N> nuove
   uscite: <artista>, <artista> e altri <M>» per più; solo artisti non silenziati.
**Verifica:** testi per 1, 2, 5 novità e con artisti silenziati (nessuna notifica se tutti silenziati).
**Telefono (Motorola):** giro con una novità (artista seguito con un'uscita tolta a mano dal DB) → notifica; tocco
dall'app chiusa e dallo sfondo → «Nuove uscite»; permesso negato → nessuna notifica, Home sì.

### 34.10 — Artisti seguiti nel backup
**File:** `lib/services/backup/user_data.dart` (`followedArtists`), `lib/data/repositories/backup_merge.dart`,
`backup_queries.dart`, `test/data/backup_merge_test.dart`
1. Esportazione e unione degli artisti seguiti (con esclusi e silenziati); le uscite non si esportano.
**Verifica:** backup → unione su un DB vuoto → stessi artisti; dopo l'unione il primo giro non crea novità (catalogo finto).

### 34.11 — (Facoltativo, da approvare) Controllo ad app chiusa
**File:** `pubspec.yaml` (`workmanager`, **da approvare**), `lib/services/releases/background_check.dart`, Android
1. Un lavoro periodico di 24 h (rete richiesta, batteria non scarica) che avvia un motore Dart senza interfaccia e fa
   lo stesso giro di 34.5 con la stessa notifica.
**Verifica:** prova sul Motorola con `adb shell cmd jobscheduler run`. **Si salta** senza approvazione: il controllo
resta all'apertura dell'app.

### 34.12 — Test dal vivo, documentazione e prova a mano
1. `test/live/ytm_releases_live_test.dart` (dietro `CODECORE_LIVE=1`, giro notturno): la maschera delle uscite di Pink
   Floyd (`UCO6LS_5W7vqG9mALDNzSFug`) dà ≥ 1 carosello di album con anni leggibili.
2. ARB it/en/de/es/fr/pt; `docs/02-architettura.md` (sezione «Nuove uscite (fase 34)»: chi si controlla, v13, regole
   del «nuovo», quando parte, notifica), `docs/03-modello-dati.md` (due tabelle), `docs/99-rischi-e-fallback.md`
   (R91–R94), guida utente.
**Tocca a te (Mi A3, Motorola, Linux):** seguire 5 artisti, attivare i più ascoltati e controllare chi viene preso
(giusti? omonimi?); il giorno dopo aprire l'app: giro in background senza scatti, notifica solo se c'è davvero qualcosa;
«Scarica album» da una novità; silenziare un artista; spegnere tutto (nessuna richiesta nel log).

## Fuori da questa fase
Controllo ad app chiusa senza WorkManager, notifiche di sistema su Linux/Windows, uscite **annunciate** (pre-save),
concerti, «Nuove uscite» per genere o di artisti che non segui (pagina «New releases» di YouTube Music), scaricare in
automatico le novità, iscrizione all'artista su YouTube (serve un account), uscite da SoundCloud, video musicali nuovi.

## Rischi (proposti per `99-rischi-e-fallback.md`, da copiare in 34.12)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R91 | Artista automatico collegato al canale sbagliato (omonimi, cover band, nomi scritti diversamente) | Novità di un altro artista | Solo con un **unico** nome uguale (`pickYtmArtist`), altrimenti «da confermare»; «Non seguire più» lo esclude per sempre; i seguiti a mano usano l'id della pagina aperta |
| R92 | Falsi «nuovi»: riedizioni, varianti, vecchie uscite che compaiono tardi, ordine del carosello non per data | Home piena di versioni dello stesso album | Primo giro = tutto visto; anno ≥ anno corrente − 1; varianti raggruppate per `group_key`; ordine per anno; fixture con le varianti misurate |
| R93 | Troppe richieste a YouTube Music (giro di 115 artisti) o formato che cambia (R74) | 429, «YouTube chiede una pausa» anche nella ricerca | In serie con 1,5 s fra due, un giro al giorno, 429 → stop per 6 h; maschera leggera; `InnerTubeChanged` → stop del giro; test notturno |
| R94 | Notifica che non arriva o non apre la pagina (permesso negato, Android che chiude l'app, nessun lavoro ad app chiusa) | Novità viste solo aprendo Home | Home resta la fonte; il giro parte a ogni apertura dopo 24 h; WorkManager come extra; verifica 34.1 dell'extra dell'intent |

## Domande aperte per l'utente
1. **Più ascoltati in automatico:** quanti (proposta **15**, ultimi 90 giorni) e attivati con una card in Home la prima
   volta (proposta) oppure già accesi senza chiedere?
2. **Notifica**: una al giorno con tutte le novità insieme (proposta) o una per ogni uscita?
3. **Solo su Wi‑Fi** spento di serie (≈ 0,5 MB al giorno, proposta) o acceso?
4. Cosa conta come uscita: **album, singoli ed EP** (proposta); anche le riedizioni con un titolo nuovo (proposta: sì;
   le varianti dello stesso titolo si raggruppano)?
5. Vuoi il controllo anche **ad app chiusa** (34.11, pacchetto nuovo `workmanager`)?
6. Dove tenere l'elenco **«Artisti seguiti»**: dentro «Nuove uscite» (proposta) o come voce fissa della Libreria?

## Definition of Done
- [ ] «Segui» sulla pagina artista online e da quella della libreria; più ascoltati in automatico con l'opzione accesa
- [ ] Un giro al giorno all'apertura (e ogni 24 h ad app aperta), in serie, con stop su 429; primo giro = tutto visto
- [ ] «Nuove uscite» in Home e pagina dedicata; tocco → pagina album con «Scarica album»
- [ ] Notifica Android raggruppata che apre «Nuove uscite»; campanella per artista
- [ ] Artisti seguiti nel backup; nessuna richiesta senza artisti o con tutto spento
- [ ] Test: confronto delle uscite (prima volta, anno, varianti), migrazione e repository, automatici, giro con 429 e non trovati, quando parte, testi della notifica, backup
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato

## Decisioni prese in autonomia (notte del 2026-10-22, obiettivo notturno: l'utente dorme)
- «Più ascoltati»: i **15** più ascoltati, attivati dalla card in Home (scelta esplicita). Al più **una notifica al giorno**. «Solo su Wi‑Fi» **spento** (≈ 15 KB per artista). Le riedizioni/varianti si raggruppano e **non** contano come novità se l'album c'era già. «Artisti seguiti» come voce in Libreria.
- **34.11 WorkManager non si fa** (dipendenza Android nuova da approvare) → in «Tocca a te».
