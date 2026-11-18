# Feature — Video karaoke in Cerca, aggiornamento dall'app, rilascio 1.6.3

Kickoff del 18/11/2026 (modalità feature). Decisioni D-631..D-651. Le fasi che la realizzano (dalla 131) citano questo file.

**Cosa fa.** In Cerca un filtro «Karaoke» trova i video karaoke di YouTube; toccandone uno, il player mostra il video
rettangolare (testo già impresso) al posto della copertina con l'anello, mentre sotto si cercano solo i testi
sincronizzati. In più l'app scarica e installa da sola l'aggiornamento dalla Release di GitHub. Poi esce la 1.6.3.
**Per chi.** Per l'utente, che vuole cantare su una base col testo a schermo senza aspettare la separazione AI, e
aggiornare l'app senza cercare il file giusto a mano.
**Perché ora.** Entrambe entrano nella 1.6.3, da rilasciare con la CI e la Release verdi su tutti i sistemi.

Da non confondere con il **karaoke AI** delle fasi 123–130 (separazione della voce con Spleeter, D-585..D-629): quello
lavora sull'audio di qualunque brano; questo è un video YouTube che è già una base.

## Requisiti

Priorità: I = indispensabile, U = utile, R = rimandabile. Tutti i requisiti scelti dall'utente sono I.

### Video karaoke (D-631..D-639)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-251 | Filtro «Karaoke» come quarto blocco di `SourceFilterChips` («Tutte / YouTube Music / YouTube / Karaoke»); selezionato, rifà la ricerca video con «<query> karaoke»; assente nella variante lite | I | Widget test di `online_results`: con `kEnableYoutube` vero il blocco c'è e la richiesta di ricerca riceve «<q> karaoke»; con `kEnableYoutube` falso il blocco non c'è | 131 |
| R-252 | Restano solo i video con «karaoke» nel titolo; scartati reaction, cover, live; i canali noti (Sing King, KaraFun, Karaoke Version, Stingray) salgono in cima | I | Test unitario della funzione di filtro e ordinamento su una lista di titoli e canali (tenuti, scartati, ordine) | 131 |
| R-253 | Toccare un risultato lo suona come un brano online: l'audio è quello del video (la base); coda, notifica, cuffie, Android Auto invariati | I | Widget test: tocco → `playOnline` con il `YtResult`; test esistenti del gestore audio verdi | 131 |
| R-254 | Nel player, per ogni brano YouTube video (non YTM) con «karaoke» nel titolo, da dovunque parta (filtro, cronologia, coda, playlist), il video 16:9 muto prende il posto di copertina e anello; in ogni altro caso resta la copertina | I | Widget test di `now_playing`: brano YouTube «… Karaoke …» → riquadro video, niente `RingProgress`; brano YTM, locale o senza «karaoke» → `RingProgress` | 131 |
| R-255 | Il video segue l'audio: play, pausa, spostamento, cambio brano; se si scosta di oltre 300 ms si riallinea | I | Test unitario della logica di sincronia con posizioni finte (scarto > 300 ms → seek; pausa e play seguiti; brano nuovo → video nuovo); prova sul Mi A3 (a volume 0) | 131 |
| R-256 | La barra orizzontale che c'è già (D-156) resta sotto il video e lo sposta insieme all'audio | I | Widget test: seek dalla barra → seek del player video | 131 |
| R-257 | Tocco sul video → schermo intero orizzontale (su Android ruota), Indietro esce; su desktop il video riempie la finestra | I | Widget test: tocco → pagina a schermo intero, Indietro → player; su Android `SystemChrome` riceve l'orientamento orizzontale e poi quello di prima | 131 |
| R-258 | Video sempre a bassa qualità: 360p, al massimo 480p, mp4/avc1 se c'è, anche con i dati mobili | I | Test degli argomenti yt-dlp del flusso video; test della selezione NewPipe (Dart sul risultato del canale); prova sul Mi A3: risoluzione ≤ 480p | 131 |
| R-259 | App in background o schermo spento → video in pausa, l'audio continua; al ritorno il video riparte allineato | I | Test con `AppLifecycleState` finto: paused → video in pausa; resumed → seek alla posizione dell'audio e play | 131 |
| R-276 | Per un brano karaoke l'audio parte solo quando il video è carico (al massimo 10 s, poi audio con copertina e avviso); dopo uno spostamento l'audio aspetta il video al massimo 3 s (D-647) | I | Test del gestore con un «video pronto» finto: niente `play()` prima del via; via dopo 10 s senza video → play e stato `failed`; brano normale → nessuna attesa | 131 |
| R-260 | Flusso video che non si carica o scade → una nuova risoluzione dell'indirizzo, poi copertina e anello con un avviso breve; l'audio non si ferma | I | Test: errore del player video due volte → copertina + avviso, nessuna chiamata al gestore audio | 131 |
| R-261 | Testi sincronizzati sotto: titolo del video ripulito (via «karaoke», «version», nome del canale) e ricerca senza vincolo di durata; se non trova, la scheda dice che non ci sono testi. Nessun'altra informazione cercata | I | Test unitario: «Sing King - Adele - Hello (Karaoke Version)» → artista «Adele», titolo «Hello»; test di `LyricsChain` per un brano karaoke: LRCLIB `/search` accettato anche con durata diversa | 131 |
| R-262 | Con un video karaoke in riproduzione il pulsante karaoke AI (microfono) è nascosto | I | Test di `karaokeButtonVisibleProvider` con un brano karaoke video → falso | 131 |
| R-263 | Un brano karaoke scaricato o offline mostra la copertina: il video c'è solo in streaming | I | Widget test: brano locale con «karaoke» nel titolo → `RingProgress` | 131 |
| R-275 | Il video si salva nella smart cache mentre suona (chiave `karaoke:video:…`); una seconda riproduzione entro 15 minuti usa il file; scade 15 minuti dopo l'ultimo uso, mai mentre suona, su tutte le piattaforme (D-649) | I | Test con orologio finto: file usato 16 min fa → cancellato; in riproduzione → tenuto; seconda riproduzione entro 15 min → `StreamStart.file` | 131 |
| R-277 | I brani karaoke nella coda manuale precaricano anche il video nella smart cache; restano finché sono nella coda manuale; con i dati mobili seguono `prefetchOnMobile` (D-651) | I | Test: coda manuale con due brani karaoke e uno normale → due precarichi video; con dati mobili e precarico spento → nessuno; brano tolto dalla coda → scade dopo 15 min | 131 |
| R-264 | TalkBack legge «Video karaoke» sul riquadro; la barra resta regolabile con i gesti | I | Widget test della semantica (etichetta nelle 6 ARB) | 131 |

### Aggiornamento dall'app (D-640..D-645)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-265 | Pulsante «Aggiorna» nell'avviso del controllo all'avvio e in Impostazioni, al posto del link da copiare; il controllo all'avvio resta disattivabile | I | Widget test di `update_tiles` e dell'avviso: con `UpdateStatus.newer` c'è «Aggiorna», il link da copiare non c'è più | 132 |
| R-266 | Scelta automatica del file giusto della Release per piattaforma, variante (full/lite), ABI (arm64-v8a/armeabi-v7a) e forma di installazione Linux (AppImage, .deb, Flatpak, zip) e macOS | I | Test unitario della scelta su ogni combinazione, coi nomi reali della Release v1.6.2 | 132 |
| R-267 | Download con avanzamento, fuori dal thread UI, e verifica con lo SHA-256 dell'asset (`digest`); file sbagliato → cancellato ed errore; rete assente o interruzione → avviso con «Riprova», l'app resta com'è | I | Test con HTTP finto: digest giusto → pronto; sbagliato → file assente ed errore; interruzione → stato «Riprova» | 132 |
| R-268 | Android: dopo il download si apre l'installer di sistema (`FileProvider` + `REQUEST_INSTALL_PACKAGES`); la prima volta si chiede il permesso per le app sconosciute; l'app si aggiorna tenendo i dati | I | Test del canale lato Dart; prova sul Mi A3 dopo la Release: build release locale 1.6.2+11 firmata con la chiave della Release → «Aggiorna» → 1.6.3 installata, libreria intatta | 132 |
| R-269 | Android: se la firma dell'APK scaricato è diversa da quella installata (build di debug o locali) compare un messaggio chiaro e l'installer non parte | I | Test del messaggio lato Dart; prova sul Mi A3 con una build di debug: messaggio, nessun installer | 132 |
| R-270 | Windows: si avvia `FreeKmusic-Setup-<v>.exe` in modalità silenziosa, l'app si chiude e Inno Setup aggiorna | I | Test degli argomenti del processo; la CI Windows compila; prova su Windows in «Tocca a te» | 132 |
| R-271 | Linux AppImage (`$APPIMAGE`): la nuova AppImage sostituisce il file (scrittura accanto e rinomina, permesso di esecuzione) e l'app si riavvia | I | Test unitario della sostituzione su file temporanei; prova locale con l'AppImage della Release | 132 |
| R-272 | Linux `.deb`, Flatpak (`$FLATPAK_ID`), zip e macOS: si apre il browser sul file giusto (`xdg-open` / `open`) | I | Test unitario di forma di installazione → URL → comando | 132 |
| R-273 | Il file scaricato si cancella dopo l'installazione o al prossimo avvio | I | Test: all'avvio la cartella degli aggiornamenti viene svuotata | 132 |

### Rilascio (D-638)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-274 | Versione 1.6.3+12 rilasciata: `ci.yml` verde su tutte le piattaforme, tag `v1.6.3`, `release.yml` verde in ogni job, Release con tutti i pacchetti | I | `gh run list --workflow ci.yml -L 1` e `gh run list --workflow release.yml -L 1` → success; `gh release view v1.6.3 --json assets` contiene i 10 file attesi (APK ×4, Setup .exe, zip Linux, .deb, AppImage, .flatpak, zip macOS) | 133 |

### Requisiti non funzionali
- Stringhe nuove nelle 6 ARB (it/en/de/es/fr/pt).
- Nessun lavoro pesante nel thread UI (download in streaming con `dio`, hash in un isolate).
- Nessun `catch` muto: errori con `AppLog`.

### Convivenza con l'app di oggi
- Cambia: in Cerca il quarto blocco del filtro; nel player, il riquadro video al posto della copertina per i brani karaoke
  in streaming; in Impostazioni e nell'avviso all'avvio, «Aggiorna» al posto del link da copiare.
- Non cambia: gli altri tre filtri (lato client, come oggi), il karaoke AI per tutti gli altri brani, download, Jam,
  cache, controllo degli aggiornamenti (stessa API GitHub, stessa frequenza).

### Fuori perimetro
- Spostare i testi in avanti o indietro, qualità del video a scelta, video nella Jam, video offline o scaricato.
- Nessuna informazione cercata oltre ai testi sincronizzati (niente copertine, album o artisti arricchiti per i karaoke).
- Variante lite: niente filtro (YouTube spento); l'aggiornamento invece c'è.
- Note di versione formattate, canale beta, aggiornamento in background senza tocco, installazione del `.deb` con pkexec.
- Build F-Droid (ricetta in `packaging/fdroid/`, mai inviata): se un giorno si invia, l'aggiornamento dall'app va spento lì.

## Vincoli
- Standalone, nessun backend: i video vengono da YouTube (InnerTube per la ricerca, NewPipe/yt-dlp per i flussi), gli
  aggiornamenti dalla Release pubblica `iTzEmany/FreeKmusic` (API anonima, limite di 60 richieste l'ora già gestito da
  `UpdateChecker`).
- Un solo pacchetto nuovo, approvato (D-637); se l'APK full cresce di oltre 25 MB per ABI ci si ferma e si chiede.
- La firma degli APK della Release è la chiave di D-569: l'aggiornamento funziona solo da APK firmati con quella.
- Telefoni di prova (Mi A3, Redmi) sempre a volume 0; sul Redmi solo l'app, mai i file già presenti (D-502).
- Windows: l'agente non ha una macchina Windows; la prova reale dell'aggiornamento è dell'utente.

## Stack (verificato su pub.dev il 18/11/2026)
| Pacchetto | Versione | Uso | Note |
|---|---|---|---|
| `media_kit_video` | 2.0.1 (02/12/2025, MIT) | Riquadro video (`Video` + `VideoController`) | Richiede `media_kit` ^1.2.3: nel lock c'è 1.2.6 |
| `media_kit_libs_android_video` | 1.3.8 | libmpv per il video su Android | Peso da misurare (D-637) |
| `media_kit_libs_windows_video` | 1.0.11 | Al posto di `media_kit_libs_windows_audio` 1.0.9 | Non vanno affiancati (README media_kit) |
| `media_kit_libs_macos_video` | dal meta-pacchetto `media_kit_libs_video` 1.0.7 | macOS | Facoltativo: si può usare il meta-pacchetto al posto dei singoli |
| `media_kit_libs_linux` | 1.2.1 (c'è già) | Linux usa la libmpv di sistema | CI già con `libmpv-dev mpv`; da verificare .deb, AppImage, Flatpak |

Scartati: `video_player` (+ `fvp` sul desktop) e gli embed iframe/webview (nessun supporto Linux e Windows).
L'aggiornamento non porta pacchetti: `dio`, `path_provider`, `Process` e un po' di Kotlin.

## Architettura

### A. Filtro «Karaoke» in Cerca (R-251, R-252)
- `SourceFilterChips` (`lib/ui/screens/youtube/online_results_sections.dart:133`) passa da `MediaKind?` a un valore con
  quattro casi (`all`, `ytmSong`, `ytVideo`, `karaoke`); i primi tre restano filtri lato client come oggi
  (`_shows`, `online_results.dart:246`).
- `karaoke` non filtra: in `OnlineResults._search()` (`online_results.dart:99`) rifà la richiesta
  (`SmartSearchRequest`, `smart_search_providers.dart:71`) con «<query> karaoke» e **solo la fonte `ytVideo`**, per non
  consumare il budget YTM (la cache è per `matchKey(query)`, quindi ha la sua voce).
- Funzione pura nuova `karaokeResults(List<SmartResult>)` in `lib/services/online/karaoke_filter.dart`: tiene i titoli
  con «karaoke», scarta reaction/cover/live, ordina i canali noti per primi (lista costante nello stesso file).
- Toccare un risultato: stesso percorso di oggi, `playOnline` (`player_providers.dart:484`) → `OnlineEntries.register`.

### B. Riconoscere un brano karaoke (R-254, R-262, R-263)
- `isKaraokeVideo(Track)` in `lib/services/karaoke_video/karaoke_video.dart`: vero se il brano è in streaming da
  YouTube (path `online:youtube:<id>` o riga ombra `stream:youtube:<id>`, `stream_key.dart:7`/`:11`) e il titolo contiene
  «karaoke» (senza distinzione di maiuscole). Un brano scaricato (file locale) non lo è mai. Niente colonne nuove.
- L'id del video si ricava dalla chiave (`keyOfStreamPath` / `OnlineEntry`), non serve salvarlo.
- `karaokeButtonVisibleProvider` (`karaoke_providers.dart:55`) aggiunge `&& !isKaraokeVideo(corrente)`.

### C. Indirizzo del flusso video (R-258, R-260)
- `KaraokeVideoSource.videoUrl(id)` → `({Uri url, Map headers, DateTime expires})`:
  - Android full: metodo nuovo `videoUrl` {id, maxHeight: 480} sul canale `codecore/ytdlp`
    (`android_yt_dlp_service.dart:19`) → `NewPipeUrl.videoUrl` in `NewPipeUrl.kt`: `getVideoOnlyStreams()`, preferisce
    MPEG-4/avc1, altezza più vicina a 360 senza superare 480; se fallisce, yt-dlp come per l'audio.
  - Desktop (e ripiego Android): yt-dlp `-g -f "bv*[height<=480][vcodec^=avc1]/bv*[height<=480]/wv"` con il processo
    che c'è già (`yt_dlp_args.dart`).
  - Cache (D-649): lo stesso `StreamPreparer`/`StreamCache` dell'audio, con un `YtResult` del video e opzioni di
    download solo video (`DownloadOptions` con il formato video); chiave `karaoke:video:youtube:<id>`, `pin` mentre suona.
    Scadenza: `cache.expire(…, stemPrefix: streamFileName('karaoke:video:'))` ogni 2 minuti con limite di 15 minuti,
    avviata dal provider del video su tutte le piattaforme (oggi `SeparationService.startExpiry` c'è solo su Android).
  - Scadenza dell'indirizzo: parametro `expire` dell'URL (come `_onUrl`, `stream_preparer.dart:329`); un errore del player video →
    una nuova risoluzione; un secondo errore → stato `failed` (copertina + avviso).

### D. Player video e sincronia (R-254..R-257, R-259)
- `KaraokeVideoController` in `lib/services/karaoke_video/karaoke_video_controller.dart`, esposto da un provider
  Riverpod: un `Player` di media_kit **senza audio** (flusso solo video, volume 0, uscita audio nulla) e il suo
  `VideoController`. Si crea al primo brano karaoke e si chiude quando parte un brano che non lo è.
- `MediaKit.ensureInitialized()` anche su Android e macOS, solo alla prima creazione (su Linux e Windows lo fa già
  `JustAudioMediaKit.ensureInitialized`, `main.dart:108`).
- Partenza insieme (D-647): per un brano karaoke il gestore audio aspetta un `Future` «video pronto» (primo fotogramma)
  prima di `play()`, al massimo 10 s (poi audio con copertina e avviso); dopo un seek aspetta il buffer del video al
  massimo 3 s. È un aggancio nel gestore (`codecore_audio_handler.dart`, area a rischio: review Opus), nullo per gli
  altri brani.
- Sincronia: ascolta la posizione e lo stato del gestore audio (la fonte unica di D-156, ~10 aggiornamenti al secondo).
  Funzione pura `syncStep(audioPos, videoPos, audioPlaying, videoPlaying, lastSeek)` → `none | play | pause | seek(pos)`:
  seek se lo scarto supera 300 ms, al massimo uno ogni 2 s salvo un seek dell'utente (che passa sempre).
- Ciclo di vita: `AppLifecycleListener` (come `speaker_providers.dart:21`): `paused`/`hidden` → pausa del video;
  `resumed` → seek alla posizione dell'audio e play se l'audio suona.
- UI: in `_PlayerCover` (`now_playing_screen.dart:511`, stesso widget per layout stretto e largo) il figlio dello Stack
  (`:549-574`) diventa `KaraokeVideoView` (`lib/ui/widgets/karaoke_video_view.dart`: `AspectRatio(16/9)`,
  `Video(controls: NoVideoControls)`, `Semantics(label: «Video karaoke»)`) quando `isKaraokeVideo` e lo stato non è
  `failed`; durante il caricamento si vede la copertina con l'indicatore. La barra orizzontale di oggi resta.
- Schermo intero: tocco → pagina `KaraokeVideoFullscreen` (stesso `VideoController`); su Android `SystemChrome`
  orizzontale e immersivo, ripristinati all'uscita; su desktop il video riempie la finestra.

### E. Testi sincronizzati (R-261)
- `karaokeLyricsQuery(title, channel)` accanto a `cleanSearchQuery` (`query_cleaner.dart`): toglie «karaoke», «version»,
  «instrumental», «with lyrics» e il nome del canale, poi separa «Artista - Titolo».
- `LyricsChain.find` (`lyrics_chain.dart:62`) riceve `ignoreDuration` per i brani karaoke: LRCLIB passa da `/search`
  e `_validated` (`lrclib_client.dart:68`) riceve `null` come durata; NetEase senza durata. Niente altro si cerca.

### F. Aggiornamento dall'app (R-265..R-273)
- `UpdateInfo` (`update_checker.dart`) aggiunge `assets`: nome, `browser_download_url`, dimensione, `digest`
  (`sha256:…`, presente negli asset della Release: verificato su v1.6.2).
- `lib/services/update/update_target.dart`: `detectUpdateTarget()` → Android (variante da `kEnableYoutube`, ABI dal
  nativo `Build.SUPPORTED_ABIS[0]`), Windows, Linux (`$APPIMAGE` → AppImage; `$FLATPAK_ID` → Flatpak; eseguibile sotto
  `/usr` o `/opt` → `.deb`; altrimenti zip), macOS. Funzione pura `pickUpdateAsset(assets, target)` per nome (schema dei
  nomi di `release.yml`, con la versione come segnaposto).
- `lib/services/update/update_installer.dart`: download con `dio` in `<cache>/updates/`, avanzamento come stream,
  SHA-256 con `crypto` (c'è già) in un isolate; poi per piattaforma:
  - Android: canale nuovo `codecore/update` (Kotlin `UpdateChannel.kt` in `src/main`): `abi`, `canInstall`
    (`canRequestPackageInstalls`), `openInstallSettings`, `sameSigner(path)` (`getPackageArchiveInfo` con i certificati
    di firma, confrontati con quelli installati), `install(path)` (`FileProvider` + `ACTION_VIEW`). Manifest:
    `REQUEST_INSTALL_PACKAGES` e il `provider` con `xml/update_paths.xml` (solo `cache/updates`).
  - Windows: `Process.start(setup, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], detached)`
    e uscita; in `packaging/windows/freekmusic.iss` una riga `[Run]` in più che rilancia l'app solo in modalità
    silenziosa (quella di oggi ha `skipifsilent`).
  - AppImage: scrittura accanto a `$APPIMAGE` (`.new`), `chmod 755`, rinomina sopra, avvio staccato e uscita; cartella
    non scrivibile → browser.
  - `.deb`, Flatpak, zip, macOS: `xdg-open` / `open` sull'URL dell'asset.
- UI: `update_tiles.dart` (Impostazioni) e l'avviso di `updateOnStartProvider` mostrano «Aggiorna» con avanzamento,
  «Riprova» sugli errori, il messaggio della firma diversa su Android.
- Pulizia: all'avvio (dopo `startupSettledProvider`) si svuota `<cache>/updates/`.

### Scelte chiuse al giro 5 (18/11)
Vedi D-646.

## Flussi principali
1. **Karaoke:** Cerca «hello adele» → Karaoke → ricerca «hello adele karaoke» (solo video) → `karaokeResults` →
   tocco → `playOnline` → audio come ogni brano online; il player vede `isKaraokeVideo` → `KaraokeVideoController`
   risolve l'URL solo video → `Video` muto al posto della copertina, sincronizzato; `LyricsChain` con titolo ripulito
   e senza durata → testi sotto.
2. **Aggiornamento:** avvio → `updateOnStartProvider` trova la 1.6.4 → avviso «Aggiorna» → `pickUpdateAsset` →
   download con avanzamento → SHA-256 → Android: `sameSigner` → installer di sistema; Windows: setup silenzioso e
   rilancio; AppImage: sostituzione e riavvio; altri: browser sul file.

## Rischi della feature
| ID | Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|---|
| F-1 | Le librerie video di media_kit gonfiano l'APK (anche la lite: non si separano per variante) | Misura con `flutter build apk --split-per-abi` nel primo task, prima del resto | Più di 25 MB per ABI → stop e domanda (D-637) |
| F-2 | Su Android il player video di media_kit disturba ExoPlayer (focus audio, uscita audio) | Flusso solo video, uscita audio nulla, nessuna richiesta di focus | L'audio si ferma o si abbassa quando parte il video |
| F-3 | Sincronia che scatta: seek continui, video a scatti sul Mi A3 | Soglia 300 ms, un seek ogni 2 s, prova sul Mi A3 a fine fase | Il video salta più di una volta ogni 10 s |
| F-4 | Video nero nei pacchetti Linux (.deb, AppImage, Flatpak: GL o libmpv senza video) | Build di tutti i pacchetti in CI e prova locale dell'AppImage | Riquadro nero o errore di libmpv nel log |
| F-5 | Regressione dell'audio su Windows passando a `media_kit_libs_windows_video` | Build Windows in CI; prova dell'utente su Windows | L'app su Windows non suona |
| F-6 | Il filtro Karaoke consuma il budget delle ricerche (rate limit InnerTube/YTM) | Solo fonte `ytVideo`, cache propria | `InnerTubeChanged` o cooldown più spessi nei log |
| F-7 | Aggiornamento Android: APK sbagliato, firma diversa, permesso «app sconosciute» che non torna all'app | Test sui nomi reali, controllo della firma prima dell'installer, prova sul Mi A3 dopo la Release | Installer che dice «App non installata» |
| F-8 | Aggiornamento Windows: file bloccati, l'app non si riapre | Uscita prima del setup, `/CLOSEAPPLICATIONS`, riga `[Run]` silenziosa | Dopo «Aggiorna» la versione resta la vecchia |
| F-9 | Regressioni in Cerca e nel player per tutti gli altri brani (filtro, copertina, karaoke AI) | Test esistenti di `online_results`, `now_playing`, `karaoke_providers` verdi; widget test «brano normale → copertina» | Un test esistente cambia |
