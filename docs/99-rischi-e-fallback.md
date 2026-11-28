# Rischi noti e piano B

Per ogni rischio: **sintomo** → **cosa fare**. Se scatta un fallback che cambia lo stack, fermati e chiedi all'utente.

| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R1 | `audio_metadata_reader` non legge bene un formato (durata/bitrate/cover) | durata 0, cover assente su certi file | Tieni `TagReader` come interfaccia. Prova `metadata_god` (Rust, richiede cargo — già installato) o `audiotags`. Per la durata: usa la durata che riporta il player al primo caricamento e salvala nel DB. |
| R2 | Su Android l'elenco di `/storage/emulated/0/Music` risulta vuoto pur con permesso | scansione = 0 file | 1) controlla che il permesso sia `audio` (API 33+). 2) prova una cartella scelta con `file_picker`. 3) fallback: `on_audio_query` (o fork mantenuto) per leggere da MediaStore e salvare il percorso restituito. |
| R3 | `just_audio_media_kit` non funziona su Windows/Linux | silenzio o crash all'avvio audio | Verifica `libmpv` (Linux: `libmpv-dev`). Alternative dietro `AudioBackend`: `media_kit` diretto, oppure `audioplayers` (meno controllo). |
| R4 | `audio_service` non supporta il desktop | eccezione su `AudioService.init` | Già previsto: su desktop non si chiama `init`, si usa il handler diretto. |
| R5 | `youtube_explode_dart` si rompe (YouTube cambia) | errori su manifest/stream | Aggiorna il pacchetto (`flutter pub upgrade youtube_explode_dart`). Se persiste: spegni la funzione con `kEnableYoutube=false`; alternativa fuori dall'app: `yt-dlp` da riga di comando. |
| R6 | Windows non compilabile da Linux | `flutter build windows` non disponibile | Compila su una macchina Windows (o CI GitHub Actions `windows-latest`). Sviluppa e testa tutto su Linux + Android. |
| R7 | Prima scansione molto lenta (10k+ file, chiavetta USB) | minuti | È normale la prima volta: scansione in isolate con progresso; la successiva è incrementale. Riduci i blocchi per isolate se la memoria sale. |
| R8 | Android ammazza il servizio in background (risparmio batteria) | musica si ferma a schermo spento | Guida utente: escludere l'app dall'ottimizzazione batteria; verifica `foregroundServiceType=mediaPlayback` e `androidStopForegroundOnPause`. |
| R9 | `drift` + codegen lento o conflitti | build_runner fallisce | `dart run build_runner build --delete-conflicting-outputs`; se persiste `flutter clean` e rigenera. |
| R10 | Scritture tag non supportate | l'utente vuole i tag modificati nel file | **Chiuso dalla Fase 21** (21.7–21.9): opzione `writeTagsToFiles`, spenta di default, `metadata_god` dietro `TagWriter` e `SafeTagWriter` (copia temporanea, verifica, backup, `rename` atomico). Vedi R50–R51. |
| R11 | Percorsi Android non-latini / molto lunghi | file non trovato | Usa sempre `File(path)` senza ricostruire stringhe; logga il percorso esatto; non applicare `sanitizeFileName` a percorsi esistenti, solo a nomi nuovi. |
| R12 | Lingua/ARB: chiavi mancanti | `null` in UI | `flutter gen-l10n` fallisce se manca una chiave nel template: tenere `app_it.arb` come template e allineare le altre. |

## Limiti accettati nella v1
- Niente "bit-perfect/esclusivo". Crossfade/gapless (fase 18) e equalizzatore Android (fase 17) sono opzionali.
- Niente traduzione automatica di testi/curiosità.
- Niente Android Auto.
- Niente scrittura dei tag nei file.
- Condivisione LAN solo HTTP con PIN (non cifrata).

## Jam (fase 8)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R13 | Il proprietario di un brano esce dalla rete | Il brano non parte / si interrompe | Precarico in cache del brano successivo; altrimenti salto con avviso |
| R14 | Android ferma l'app in background (Doze, risparmio energetico) | La Jam si interrompe a schermo spento | Servizio in primo piano con notifica «Termina»; guida utente: escludere dall'ottimizzazione batteria |
| R15 | Deriva tra stato e posizione di ascolto | Il telecomando mostra una posizione diversa | Soglia di correzione 1,5 s; nessuna promessa di sincronia (la riproduzione sincronizzata è fuori scope) |
| R16 | Reti con isolamento dei client o sottoreti diverse | Nessun dispositivo trovato | Messaggio chiaro; collegamento manuale (IP:porta) come fallback |
| R17 | Scarto udibile tra uscite sincronizzate (Wi‑Fi irregolare, Bluetooth) | Eco o «effetto flanger» | Cache completa prima dell'avvio, correzione continua, compensazione manuale della latenza; fallback a uscita singola |
| R18 | Orologio dell'host che salta (NTP, sospensione) | Tutte le uscite si riallineano di colpo | Differenze su orologio monotono, rinnovo periodico dell'offset, isteresi sulle correzioni |

## Importazione da CSV (fase 12)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R19 | `yt-dlp` di sistema troppo vecchio (< 2025.11: niente `--js-runtimes`, «Please sign in») | ricerca/download falliscono con «YouTube ha cambiato qualcosa» | Desktop: Impostazioni → Download → **Aggiorna** (fase 14: binario ufficiale con controllo SHA-256, il vecchio resta `.old`); in alternativa `pip install -U yt-dlp`. Su Android si aggiorna da solo |
| R20 | YouTube risponde 429 / «Sign in to confirm you're not a bot» a molte ricerche di fila | importazione in pausa con avviso «YouTube ha chiesto di rallentare» | Una ricerca alla volta con 1,5 s di pausa; aspettare qualche minuto e «Riprendi» |
| R21 | 403 transitorio sul flusso audio | un brano «con errori» in mezzo a un'importazione | Ritento a scalare nella coda dei download (5/20/60 s, solo errori transitori, fase 14); poi «Riprova tutti» nella schermata «Rivedi» |
| R22 | Exportify cambia nome o ordine delle colonne | «Questo file non sembra un CSV di Exportify» | Le colonne si riconoscono dall'intestazione (`Track Name`, `Artist Name(s)`, `Duration (ms)`…); aggiungere i nuovi nomi in `exportify_reader.dart` |
| R23 | Brano sbagliato scelto con sicurezza (versione live, cover, durata diversa) | nella playlist suona un'altra versione | Soglia 0,80 e durata come criterio principale; i casi dubbi vanno in «Da verificare»; «Cerca a mano» per correggere |

## Download robusti (fase 14)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R27 | Binario yt-dlp scaricato compromesso o troncato | yt-dlp non parte o fa altro | Solo HTTPS da GitHub, SHA-256 contro `SHA2-256SUMS` della stessa release, rinomina atomica, il precedente resta come `yt-dlp.old` (rinominalo per tornare indietro) |
| R28 | Più download insieme → più 403/429 | Righe «con errori» o importazione in pausa | Predefinito 2 (massimo 3); ricerche sempre una alla volta; ritento a scalare con jitter; `rateLimited` mette in pausa; abbassare «Download contemporanei» a 1 |
| R29 | Formato «originale» non leggibile da tag reader o player | Durata 0 o brano che non parte | Spento di default (MP3); se manca m4a si ottiene opus/webm (estensioni già scansionate); riattivare MP3 e riscaricare |
| R30 | Cache delle ricerche con risultati vecchi (video rimosso) | Si propone un video non più disponibile | Scadenza 30 giorni; un download `unavailable` cancella le voci della riga; «Svuota cache ricerche» nelle Impostazioni |

## Importazione 2 (fase 15)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R31 | Un servizio cambia le colonne del suo CSV | «Formato non riconosciuto» o titolo/artista vuoti | Colonne per sinonimi in `csv_profiles.dart` (aggiungere i nuovi nomi); basta un CSV con una colonna titolo e una artista |
| R32 | «Sincronizza» toglie brani che si voleva tenere | La playlist perde brani dopo un aggiornamento del file | L'anteprima mostra quanti ne toglie; si toglie **solo dalla playlist** (file e libreria restano): si riaggiungono dalla libreria; i brani aggiunti a mano non si toccano |
| R33 | M3U/XSPF con codifiche o percorsi strani | Brani non trovati in libreria o titoli storti | Latin-1 di ripiego per `.m3u`, `Uri.decodeFull`, ricerca per cartelle finali; le righe illeggibili sono contate come «ignorate», mai errore sull'intero file; il file XSPF si legge con un lettore a espressioni regolari (pacchetto `xml` solo se serve) |

## CI e test automatici (fase 16)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R34 | Golden diversi tra macchine (font, antialiasing, versione Flutter) | Golden rossi in CI e verdi in locale (o viceversa) | Generati e confrontati solo su Linux con Flutter fissato (3.47.1); tolleranza 0,5 %; font dagli asset; rigenerare con `flutter test --update-goldens test/goldens` solo dopo aver guardato i PNG |
| R35 | Test verdi in locale e rossi in CI (rete, HOME, percorsi, libmpv) | Un solo job rosso | La suite è verificata ermetica (HOME temporaneo, nessuna rete); i test live stanno dietro `CODECORE_LIVE`; per i percorsi `\` guardare il job Windows |
| R36 | YouTube blocca i runner GitHub (IP dei datacenter) nei test live notturni | `nightly.yml` rosso | Sono informativi (`continue-on-error`); la verità resta la prova dal PC di casa |

## Riproduzione avanzata (fase 17)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R37 | Cambiare l'opzione `pitch` di `just_audio_media_kit` altera la correzione di velocità della Jam | La Jam va fuori sincronia o cambia tono | Nessuna modifica fatta (misurato: `scaletempo` tiene 440 Hz a 0,75× e 1,5×); rilanciare `test/jam/` e la misura prima di toccarla |
| R38 | `AndroidEqualizer` non disponibile o con bande strane su alcuni telefoni | Voce Equalizzatore assente o curva poco fedele | `equalizer == null` → voce nascosta; i preset sono interpolati sulle bande reali; errori loggati, riproduzione invariata |
| R39 | Pacchetto MPRIS/SMTC abbandonato o incompatibile con `audio_service` | Niente tasti multimediali di sistema su desktop | Dietro un'interfaccia dedicata; fase 17.7/17.8 ferme in attesa di approvazione dei pacchetti; il resto non dipende |
| R40 | Due notifiche (Jam e `audio_service`) o notifica che resta dopo la Jam | Notifica con il brano sbagliato | Un solo trasporto attivo, staccato in `_teardown`; test dell'handler con trasporto finto; prova con Jam terminata da host e ospite |

## Gapless e crossfade (fase 18)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R41 | La finestra del backend si disallinea dalla coda (brano ripetuto o saltato), o il brano successivo è un file danneggiato | Un brano saltato o ripetuto al passaggio, errore di riproduzione al confine | `PlayQueue` unica autorità, `revision` per ricalcolare, `_onAdvanced` ricarica nel modo normale se la coda non è più quella annunciata; l'impostazione torna su «Normale» (che è il predefinito). Un file illeggibile ma presente non si vede prima del passaggio |
| R42 | mpv o ExoPlayer non sono davvero gapless con certi formati o telefoni | Buco o «clic» al confine | Misurato su Linux (0 ms; mp3 −11 ms per il taglio dell'inizio). `scripts/gap_probe.py` e `test/live/gapless_live_test.dart` rifanno la misura; su Android/Windows prova a orecchio; «Normale» resta disponibile |
| R43 | Regressioni nella Jam o nel timer di spegnimento | Jam fuori sincronia, timer «fine brano» che non ferma | Nessuna modifica ai file della Jam (`git diff` vuoto) e test che lo impediscono (`test/jam/jam_transition_test.dart`); `pauseAtTrackEnd` svuota la finestra e impedisce la dissolvenza |

## Interfaccia (fase 19)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R44 | Gesti in conflitto (pressione lunga, swipe «In coda», riordino, `Draggable` desktop) | Una riga che non si seleziona o che scatta in coda mentre si trascina | In selezione niente swipe; il riordino di una playlist è una modalità a parte (entrando si esce dalla selezione); su desktop il trascinamento parte da pochi pixel (test con mouse simulato) e vince sullo swipe; il menu del brano resta su ⋯, clic destro e (desktop) pressione lunga |
| R45 | Tema chiaro con contrasto insufficiente (copertine chiare, accento giallo) | Testo o icone poco leggibili al sole | Palette chiusa di 8 accenti (scuri nel chiaro), test AA su ogni combinazione (24), `heroTint` chiaro ≥ 7:1; si torna a «Notte viola» da Impostazioni → Aspetto |
| — | Azione di massa sbagliata | Si tolgono 300 brani da una playlist | Conferma col numero, «Annulla» nello snackbar (ripristina le posizioni), niente tocco ai file, backup della fase 13 |

## Libreria intelligente (fase 20)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R46 | `plays` cresce senza limite (anni di ascolti) | Database grande, recap lento | Indici su `played_at` e coprente su `(track_id, played_at, ms_played)`; query aggregate in SQL (misurato: ricapitolo annuale di 100 000 ascolti ~260 ms, mensile ~60 ms); «Cancella cronologia» e interruttore «Registra la cronologia» in Impostazioni; il backup (fase 13) la include |
| R47 | Regole tradotte male in SQL o testo dell'utente iniettato | Risultati sbagliati o query che si rompe mentre si digita | Solo `Variable` (test con `'; DROP TABLE…`, `%`, `_`, `\`); oracolo in Dart sui 28 brani del test; il parser non lancia mai e un termine invalido è testo libero con avviso |
| R48 | Playlist intelligenti o ricerche con molti risultati lente su librerie grandi | Lista che impiega più di mezzo secondo | Misurato su 20 000 brani: ricerche selettive 5–15 ms; con risultati enormi (`-live` = 18 000 brani) il costo è quello di elencarli (~300 ms). Le playlist hanno il limite facoltativo; la ricerca mostra 4 brani e «Mostra tutti» |

## Pulizia libreria e tag (fase 21)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R49 | Fusione sbagliata (due versioni diverse prese per duplicati) | Un brano live o una traccia con lo stesso titolo sparisce | Anteprima obbligatoria per gruppo, durata entro 2 s, titolo e artista non vuoti, «Non sono duplicati» (si ricorda), i nascosti si ripristinano da Impostazioni → Pulizia libreria → Brani nascosti; l'unione è una sola transazione (provato con un errore a metà) |
| R50 | Scrittura dei tag che rovina il file o perde copertina/ReplayGain | File che non si apre, copertina sparita | **Implementata (21.7–21.9)**: `SafeTagWriter` lavora su una copia in `tagwork/`, rilegge con `TagReader` e confronta (campi scritti, copertina e durata invariate, campi non toccati invariati), salva l'originale in `tag_backups/` (ultimi 200 o 2 GB), poi `rename` atomico (ripiego: copia accanto al file + `rename` se le partizioni differiscono); qualunque errore lascia l'originale intatto. Verificato in 21.1: `metadata_god` (lofty) conserva audio, copertina e tag sconosciuti, `audiotags` li perde (scartato). Opzione `writeTagsToFiles` spenta di serie, con avviso. Limite: un campo svuotato non si cancella nel file |
| R51 | Il pacchetto Rust non compila su una piattaforma | Build Android che fallisce | **Successo su Linux**; su Android `metadata_god` 1.1.0 fallisce con Gradle 9 (cargokit usa `project.exec`, `compileSdk` 33): usata una **copia locale** in `third_party/metadata_god/` con `docs/patches/metadata_god-gradle9.patch` (dipendenza `path:`). Windows da provare in CI (serve Rust). Se il pacchetto non è disponibile l'avvio della scrittura fallisce con un errore tipizzato e la libreria si aggiorna lo stesso |
| R52 | Eliminazione dei file negata (Android, disco esterno) o sbagliata | «Non eliminato», o un file sparisce per errore | Solo dopo due conferme, con l’elenco dei percorsi; mai il file tenuto, mai un collegamento che porta ad esso; errori raccolti con il motivo del sistema e mostrati; i brani non eliminati restano nascosti e ripristinabili |

## Nuove fonti (fase 22)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R53 | SoundCloud dà solo anteprime da 30 s o brani con DRM | Risultati inutilizzabili o errore «DRM protected» | Misurato in 22.1: i brani completi esistono senza login, i commerciali sono spesso anteprime o DRM. Le anteprime si scartano (durata ≤ 31 s, formati `*_preview`), un brano DRM compare ma fallisce con un errore per riga (`unavailable`); l'elenco è flat così un DRM non rompe la ricerca su Android; **dalla fase 32 SoundCloud è fuori dalla ricerca e dall'importazione** (misura 32: 0 brani su 54 trovati solo lì), restano la lettura dei dati vecchi e il download dalla pagina |
| R54 | Playlist/canali enormi o con video privati/rimossi | Attesa lunga, elenco incompleto | `--flat-playlist` (250 voci in ~13 s), limite di 500 con avviso «Mostro i primi 500», avviso oltre 200 video con stima, privati/rimossi contati e non elencati, righe non scaricabili in errore e il resto continua |
| R55 | ML Kit pesante o lingua non supportata | APK più grande, modelli da scaricare | Modelli scaricati **solo su richiesta** (dialogo con ~30 MB, mai in automatico), eliminabili da Impostazioni → «Modelli di traduzione»; il traduttore è `null` fuori da Android, quindi nessuna voce su desktop; 20 lingue in elenco (le sei dell'app comprese), una lingua fuori elenco non si può scegliere; se il download o la traduzione falliscono, un avviso e il testo originale resta. Peso dell'APK: da misurare sul telefono |

## Podcast (fase 23)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R56 | Feed malformati o enormi (HTML al posto dell'XML, 20 MB) | Errore all'iscrizione, app lenta | Letto a flusso con limite di **20 MB** (`tooLarge`), solo http/https, un testo non RSS dà «Questo indirizzo non è un feed di podcast» (`notFeed`), nulla viene salvato a metà.|
| R57 | Gli episodi «sporcano» la libreria musicale | Un podcast in «Tutti i brani», nei più ascoltati, nelle playlist, nelle statistiche | `tracks.kind` filtrato in **tutte** le query musicali (test `podcast_exclusion_test.dart`: stesso titolo e artista di un brano, 9 ascolti), `addTracks` li rifiuta, niente cronologia, cartella fuori dalla scansione |
| R58 | La pulizia cancella file sbagliati | Un file musicale sparisce | Spenta di serie; solo episodi `kind = 1` con percorso **dentro** `<appSupportDir>/podcasts/` (`p.isWithin`, controllato due volte), mai quello in riproduzione o in coda; «annulla iscrizione» chiede conferma col numero di file e cancella solo dentro la cartella |

## Dispositivi fidati e sync (fase 24)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R59 | Generazione dei certificati lenta o non disponibile su una piattaforma | Avvio lento, errore al primo abbinamento | Verifica in 24.1 (EC prime256v1 con `basic_utils`, puro Dart, generato una volta in un isolate); ripiego: HTTP + PIN come oggi. **Non ancora**: 24.2 in attesa del pacchetto |
| R60 | Identità persa (reinstallazione, file corrotto) → fidati rotti | Un dispositivo già abbinato non viene più riconosciuto | `TrustedDevices.matches` accetta solo l'impronta salvata: stesso id con un'altra impronta **non** è fidato (messaggio «identità cambiata: riabbina»); revoca semplice; lista illeggibile → vuota e loggata, mai fiducia a caso |
| R61 | ExoPlayer/mpv non leggono HTTPS autofirmato | La Jam non parte | La Jam resta su HTTP con token (dichiarato), su un socket separato; verificato in 24.1 |
| R62 | Sync che sovrascrive una playlist curata | Una playlist ordinata a mano cambia da sola | «Ultima modifica vince» solo con **anteprima e conferma** (`showSyncPreview`); la versione più recente **qui** non viene toccata; nessuna cancellazione propagata; applicazione in **una transazione** (`PlaylistSyncRepository.apply`); `updated_at` dell'altro dispositivo copiato, niente rimbalzi |

## Android esteso (fase 25)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R63 | Tasto multimediale a freddo non riavvia la riproduzione | Widget, tile, cuffie o auto a app chiusa: nessun suono | **Confermato** (25.1): `audio_service` scarta il tasto se Dart non è ancora collegato. Widget e tile usano `MediaKeys.pressSurely`: premono, aspettano `widget.readyAt` scritto da Dart dopo il ripristino della coda e ripremono (suona dopo ~3 s, provato sul Mi A3). Cuffie Bluetooth a app chiusa: resta il limite di `audio_service` |
| R64 | Android Auto non mostra l'app (installata fuori dal Play Store) | Nessuna icona in auto | DHU o auto con «Origini sconosciute» nelle impostazioni sviluppatore di Android Auto; descrittore `automotive_app_desc` presente; a freddo la prima lista può essere vuota (basta riaprire). **Non provato** |
| R65 | Widget non aggiornato o batteria consumata | Titolo vecchio, consumo | Una scrittura solo a ogni cambio di brano/stato (`WidgetSync`, mai sulla posizione); nessun `updatePeriodMillis`; l'`Application` ascolta le preferenze e ridisegna. Dart scrive su `shared_preferences` perché il motore avviato senza attività non ha i canali di `MainActivity` |

## Distribuzione (fase 26)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R66 | Licenza della build ffmpeg incompatibile o non chiara | Installer Windows non distribuibile | Non ancora affrontato (26.1/26.4 aspettano l'approvazione degli strumenti): solo build con licenza verificata e testo incluso; altrimenti ffmpeg non incluso e conversione MP3 disattivata su Windows |
| R67 | Flatpak senza yt-dlp/ffmpeg funzionanti (sandbox) | Download assenti nel Flatpak | Binari dentro `/app/bin`; altrimenti Flatpak senza download, dichiarato. Non ancora costruito |
| R68 | Keystore esposto o perso | APK non aggiornabili | Solo nei *secrets* della CI, mai stampato; `android/key.properties` e `*.jks` sono in `.gitignore`; backup offline |
| R69 | R8/ProGuard rompe plugin con riflessione | Crash della release | Regole in `android/app/proguard-rules.pro`; la release `full` x86_64 è stata avviata su emulatore senza crash; resta da provare yt-dlp in release. Piano B: `isMinifyEnabled = false` (costa pochi MB: il codice pesa 2,8 MB) |
| R70 | La ricerca diretta (InnerTube, API interna di YouTube non documentata) cambia formato o rifiuta | Ricerche YouTube/YouTube Music lente come prima (≈ 3–14 s), riga «direct … search unreadable» nel log | **Ripiego automatico** su yt-dlp per la stessa ricerca e per i 10 minuti successivi (`DirectSearchService`); 429 e assenza di rete si segnalano senza ripiego. Aggiornare le fixture in `test/fixtures/innertube/` e, se serve, `clientVersion`/filtri in `innertube_client.dart`; il test dal vivo `test/live/innertube_live_test.dart` (nightly) se ne accorge per primo. **La radio di Shuffle+ (fase 31)** usa lo stesso schema: se `next` non si legge (riga «direct radio unreadable» nel log) si ripiega sul mix di yt-dlp per 10 minuti (4,6 s, 50 voci, senza album); fixture e test notturno `test/live/ytm_radio_live_test.dart` |
| R71 | «Ascolta» (28.6): l'indirizzo diretto scade dopo qualche ora ed è legato all'IP; su rete mobile il primo suono arriva più tardi | Errore «non raggiungibile» o attesa lunga | L'indirizzo si chiede a ogni ascolto (mai in cache), attesa con indicatore sulla riga e nella barra, errore con il messaggio della ricerca e la musica che torna; nessuna cache su disco (vedi PROGRESS 28.6). SoundCloud non si ascolta più (fase 32). **Aperto**: su YouTube l'indirizzo via yt-dlp costa ~10 s sul Mi A3: un indirizzo chiesto direttamente come per la ricerca (InnerTube `player`) lo ridurrebbe, con il rischio R70 |

## Backup e ripristino (fase 13)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R24 | Ripristino che corrompe o perde il DB | Libreria vuota dopo il riavvio | Staging in `<appSupport>/restore/` con marcatore `ready` scritto per ultimo; al riavvio il DB nuovo è controllato (`PRAGMA quick_check`) **prima** di toccare quello attuale, che diventa `codecore.sqlite.before-restore` (mai cancellato); qualunque errore lascia il DB com'era (testato con staging danneggiato) |
| R25 | Brani riconosciuti male su un altro dispositivo | Preferiti/playlist sul brano sbagliato | Percorso relativo → titolo+artista+durata ±2 s → hash; parità → «non trovato», con elenco copiabile; l'unione non cancella niente |
| R26 | Backup troppo grande per `saveFile` su Android (tutto in memoria) | Errore o app lenta salvando | Lo zip contiene copertine (già compresse, `store`) ma non musica; 20.000 brani + 2.000 copertine = 60 MB in 1,7 s. Se la libreria vera supera ~150 MB: piano B zip in una cartella dell'app con percorso mostrato (non ancora necessario) |

## Elimina dal dispositivo
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R72 | Android: un file non creato dall'app non si cancella con `File.delete` (Android 11+) e sotto Android 11 non c'è nemmeno `createDeleteRequest` | «Impossibile eliminare il file: Operation not permitted»; il brano resta in libreria | Da Android 11: **un** dialogo di sistema per tutta la selezione (`MediaDeleteBridge`), poi si ricontrolla il disco e si tolgono solo le righe dei file spariti; il file non cancellato resta in libreria e il motivo è mostrato. **Android 10 e precedenti: nessun ripiego** (minSdk 24): il brano resta; va tolto dal gestore file. Il dialogo di sistema è un secondo passaggio dopo la conferma dell'app. **Non provato su un telefono** |
| R73 | Windows: un file aperto dal player non si cancella | Rifiuto «in uso» sul brano che suona o è già preparato in gapless | La coda lascia andare i brani (`removeTracks` aspetta il ricaricamento e il rinnovo della finestra gapless) prima di cancellare; se un file resta bloccato è un fallimento normale: riga intatta e motivo mostrato |


## Pagina artista e catalogo online (fase 30)
| # | Rischio | Sintomo | Piano B |
|---|---|---|---|
| R74 | La pagina artista (InnerTube `browse`, non documentata) cambia formato o risponde vuota; per lei **non c'è** un ripiego yt-dlp | «La pagina dell'artista non si legge» | Lettura per tipo di elemento (non per titoli); maschera con richiesta intera se vuota; copia in cache anche scaduta; «Cerca i brani di <artista>» (ricerca con il suo ripiego); album via yt-dlp; fixture in `test/fixtures/innertube/` e test notturno `ytm_catalog_live_test.dart` |
| R75 | Artista sbagliato: omonimi, cover band, nome del canale diverso da quello dei tag («PINK FLOYD») | «Nella tua libreria» con brani di un altro o vuota; «Su YouTube Music» apre l'artista sbagliato | Dai risultati si usa sempre il `browseId`; confronto con `matchKey` su artista principale; dalla libreria si apre da solo solo con un unico nome uguale, altrimenti scelta fra 3; nessuna scrittura automatica nel DB |
| R76 | «Scarica album» lancia molte richieste (429) o crea doppioni | Importazione in pausa «YouTube chiede una pausa», album diviso | È un'importazione (attese e ripresa della fase 15, una ricerca per riga evitata perché i `videoId` sono noti); i brani già in libreria si collegano; conferma con il numero di brani. La playlist tecnica (`source_kind = 'ytm-album'`) è nascosta ovunque tramite `hidden_playlists.dart`: se compare in un nuovo elenco di playlist, usare quell'helper |
| R77 | Un id negativo (suggerito di Shuffle+) arriva a codice che si aspetta una riga di `tracks` | Preferito/modifica/eliminazione che falliscono o toccano il brano sbagliato, coda a schermo sfasata, riavvio con «non in libreria» | Registro `OnlineEntries` + `isOnlineId` prima di ogni scrittura; azioni ridotte per i suggeriti; `queueProvider` allineato per posizione; salvataggio senza id negativi; test con un repository che fallisce sugli id negativi |
| R78 | Indirizzo dello streaming lento (Mi A3 ~10 s), scaduto (6 h) o legato all'IP (403 dopo un cambio di rete) | Silenzio o salto al suggerito | Indirizzo chiesto quando il suggerito diventa il prossimo; scadenza letta dall'indirizzo; una nuova richiesta su 403; attesa massima 15 s poi salto; tre errori di fila → Shuffle+ spento per la sessione |
| R79 | La radio dà videoclip, doppioni o brani che hai già | Suggeriti con introduzioni parlate, brani ripetuti o già in libreria | Semi solo da brani di YouTube Music (un seme videoclip si sostituisce, misurato: 0 brani), filtro sui brani con album, doppioni per id e per titolo+artista+durata, registro di 30 giorni, «Non mi piace» |
| R80 | Rete in background: dati mobili, YouTube che risponde 429 | Consumo inatteso, ricerche e download dell'utente bloccati | Opzione spenta di serie, «Solo su Wi‑Fi» acceso di serie (rete non a consumo), 1 radio al minuto, pausa di 15 min su 429, niente rete in pausa o in Jam; stima di 15 MB/h mostrata nel foglio |
| R81 | Volume diverso fra brani della libreria (ReplayGain) e flussi di YouTube | Suggerito più forte o più piano | Nessuna correzione in questa fase; se l'ascolto lo chiede, un guadagno fisso per i flussi con «Normalizza» attivo (da misurare) |
| R82 | Confidenza sbagliata: il brano giusto negli Altri, o prima una versione live/cover/remaster | «Non trova» un brano che c'è | Soglia calibrata (brano esatto fra i Migliori in 34/34), Altri a un tocco, regole di versione nei due sensi, fixture di regressione da ricerche vere (32.7), filtro per fonte per vedere l'elenco di una fonte sola; test dal vivo `smart_search_live_test.dart` |
| R83 | Due o tre richieste per ricerca: più 429 e più lentezza sui telefoni lenti | «YouTube chiede una pausa» più spesso, prima riga oltre 2 s sul Mi A3 | Richieste solo all'invio, cache di 10 minuti, pausa di 5 minuti per la fonte con 429, annullamento delle vecchie, card con maschera da 0,7 KB; misura 32.1 e piano B (card dopo i brani) |
| R84 | Righe che si spostano mentre arrivano le fonti | Tocco sulla riga sbagliata | Blocco stabile: ciò che è a schermo non cambia posto, i ritardatari si uniscono o vanno in fondo; tetto di 1,5 s |
| R85 | Togliere SoundCloud fa perdere contenuti rari o rompe dati vecchi | Un bootleg che si trovava solo lì; download o revisioni SoundCloud che non si aprono | Misura (0 trovati solo su SoundCloud in 54 ricerche), compatibilità di `MediaSource.soundcloud` e test sui dati vecchi, link SoundCloud incollato (32.9, facoltativo), variante B se l'utente preferisce |
| R86 | Radio Browser lento o fermo: oggi c'è **un solo server** (`de1`) | Pagina Radio vuota o «non in linea» | Copia del paese per 7 giorni e stazioni salvate nel DB (si ascoltano anche senza Radio Browser: l'indirizzo è salvato); `/json/servers` a ogni avvio della sessione, poi `de1` fisso; nessun nuovo tentativo a raffica; test notturno `radio_browser_live_test.dart` |
| R87 | Stream che non suonano su un motore (codec, HLS, certificati, `http`), o che cadono cambiando rete | Silenzio, «La radio non risponde» | `hidebroken=true`, 3 tentativi a 2/5/15 s, messaggio chiaro, stazione segnata «non risponde» solo nella riga (niente cancellazioni); verifiche 33.1 su ExoPlayer e mpv |
| R88 | Consumo di dati (≈ 58 MB/h a 128 kbps) | Bolletta o soglia del telefono raggiunte | Bitrate e MB/h visibili, avviso alla prima radio su rete a consumo; nessun ascolto che parte da solo |
| R89 | Le voci online di tipo radio finiscono in codice che si aspetta un brano (estende R77) | Preferito, cronologia, seek, Jam o salvataggio della coda che falliscono | Stesse protezioni della fase 31 (`isOnlineId`), azioni ridotte (stella al posto del cuore, menu `radioTrackActions`), `systemActions` senza seek, test sul lettore con un repository che fallisce sugli id negativi |
| R90 | Dati delle stazioni scritti a mano (regioni sporche, favicon pesanti o rotte, nomi doppi) | Radio della regione mancanti, immagini lente | Tabella delle regioni con varianti e capoluoghi, «Le più ascoltate» del paese sotto, doppioni tolti, favicon decodificate alla misura mostrata con segnaposto (iniziale) |
| R91 | Artista automatico collegato al canale sbagliato (omonimi, cover band, nomi scritti diversamente) | Novità di un altro artista | Solo con un **unico** nome uguale (`pickYtmArtist`), altrimenti «da confermare»; «Non seguire più» lo esclude per sempre; i seguiti a mano usano l'id della pagina aperta |
| R92 | Falsi «nuovi»: riedizioni, varianti, vecchie uscite che compaiono tardi, ordine del carosello non per data | Home piena di versioni dello stesso album | Primo giro = tutto visto; anno ≥ anno corrente − 1; varianti raggruppate per `group_key`; ordine per anno; fixture con le varianti misurate |
| R93 | Troppe richieste a YouTube Music (giro di 115 artisti) o formato che cambia (R74) | 429, «YouTube chiede una pausa» anche nella ricerca | In serie con 1,5 s fra due, un giro al giorno, 429 → stop per 6 h; maschera leggera; `InnerTubeChanged` → stop del giro; test notturno `releases_live_test.dart` |
| R94 | Notifica che non arriva o non apre la pagina (permesso negato, Android che chiude l'app, nessun lavoro ad app chiusa) | Novità viste solo aprendo Home | Home resta la fonte; il giro parte a ogni apertura dopo 24 h; WorkManager come extra (34.11, da approvare); extra dell'intent letto da Dart all'avvio e alla ripresa (`takeLaunchTarget`) |
| R95 | «Continua qui»: brano sbagliato sull'arrivo (stesso titolo e artista, file diverso, o percorso uguale con contenuto diverso) | Sull'arrivo suona un'altra versione | Ordine relPath → sha256 → titolo|artista con la durata entro ±3 s come controllo; durata diversa → si usa il flusso LAN della partenza invece del file locale. Test con librerie finte che hanno omonimi |
| R96 | «Continua qui»: ripartenza in ritardo oltre 1 s o salto (bufferizzazione di `loadUri`, risoluzione degli online, orologi diversi) | L'arrivo parte indietro o in avanti | Posizione calcolata con l'orologio della partenza più il tempo trascorso misurato sull'arrivo (niente confronto fra orologi); seek dopo che il lettore è pronto; il primo brano si risolve prima di tutti gli altri. Test con orologio finto; misura sui due telefoni via adb |
| R97 | «Continua qui»: regressioni su Jam, «Invia» e `/sync` (stesso server, stesse rotte fidate) | Jam o invio che non vanno più dopo la feature | Rotte nuove solo sotto `/continue`, nessuna modifica a quelle esistenti né al beacon; nella fase i test esistenti di Jam, offerte e sync girano fra i test mirati; prova a due telefoni di Jam e Invia a fine fase |
| R98 | «Continua qui»: Android chiude la partenza in sottofondo mentre serve brani (Doze, risparmio energetico) | L'arrivo salta i brani presi dalla partenza | Servizio in primo piano (R-290); se cade, i brani si saltano (R-288), nessun blocco. Prova a schermo spento 10 min |
| R99 | «Continua qui»: due passaggi incrociati o doppio tocco | Entrambi suonano o entrambi in pausa | Un solo passaggio alla volta per dispositivo (le richieste durante un passaggio rispondono «occupato»); test con due richieste simultanee |
