# Feature — Libreria leggera, karaoke, Cerca con le classifiche, comandi multimediali

Kickoff del 15/11/2026 (modalità feature). Decisioni D-571..D-598. Le fasi che la realizzano (dalla 123) citano questo file.

**Cosa fa.** Permette di tenere la libreria in streaming con una smart cache invece di scaricare tutto (scelta in
onboarding e nelle impostazioni, con SD, qualità regolabile e «Libera spazio»); aggiunge il karaoke (voce
regolabile da 0 a 100 % su libreria e streaming); chiude la notifica Android dopo 30 minuti senza musica; rifà Cerca
(barra fissa in alto, top 20 per macrogenere dalle classifiche); ripara i tasti Bluetooth e i comandi della tendina.
**Per chi.** Chi ha poca memoria sul dispositivo; chi vuole cantare sulle basi; tutti per il resto.
**Perché ora.** L'app tiene come mp3 anche la musica che si potrebbe ascoltare in streaming e riempie la memoria; i
comandi multimediali si sono rotti dopo gli ultimi rilasci.

L'idea iniziale era Google Drive: scartata (D-572) dopo l'analisi in
[`feature-analisi-google-drive.md`](feature-analisi-google-drive.md). Anche il cloud WebDAV è accantonato (D-588,
[`../../13-idee-future.md`](../../13-idee-future.md)).

## Requisiti

Priorità: I = indispensabile, U = utile, R = rimandabile. La colonna «Fase» si riempie col piano.

### Comandi multimediali e notifica
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-226 | Tasti multimediali (cuffie Bluetooth play/pausa/avanti/indietro, tendina, schermata di blocco) funzionano sempre, anche dopo una Jam finita o interrotta (D-594) | I | Test del gestore audio: `playbackState.controls` e `systemActions` pubblicati in ogni stato (anche dopo `attachRemote`/detach); sul Mi A3 `adb shell input keyevent 85/87/88/126/127` e i tasti della tendina cambiano lo stato del player | 123 |
| R-227 | Pausa è sempre pausa: `KEYCODE_MEDIA_PAUSE` con la musica ferma non la fa ripartire (backlog del 10/11) | I | Test del gestore: `pause()` da fermo lascia `playing == false`; sul Mi A3 keyevent 127 due volte di fila → resta in pausa | 123 |
| R-228 | Dopo 30 minuti senza musica (pausa o stop) il player esce dalla tendina e il servizio in primo piano si ferma; coda e posizione restano; non scatta con una Jam attiva (D-589) | I | Test con orologio finto: 30 min in pausa → `stop` del servizio chiamato, coda salvata; con Jam attiva nessuno stop; sul telefono la notifica sparisce e Play dall'app riparte dallo stesso punto | 123 |

### Libreria leggera (streaming con smart cache)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-229 | Impostazione «Dove tieni la musica»: «Streaming con cache» o «Sul dispositivo»; chi aggiorna resta «Sul dispositivo» (D-575, D-598) | I | Test delle impostazioni: default «Sul dispositivo» per un'installazione con `onboardingDone`; cambio salvato e riletto | 125 |
| R-230 | In modalità streaming «Aggiungi alla libreria» sostituisce «Scarica» nei menu dei brani online; il brano entra in Brani/Album/Artisti con una nuvola e suona in streaming passando dalla cache; «Scarica» resta a mano (D-574) | I | Test: aggiungere un risultato online crea la riga ombra marcata come salvata, visibile in `watchByRules` della scheda Brani; widget test della nuvola | 125 |
| R-231 | Filtro in cima alle schede della libreria: «Tutti · Sul dispositivo · In streaming», di partenza «Tutti» (D-596) | I | Widget test: il filtro cambia l'elenco; golden della scheda Brani | 125 |
| R-232 | I brani in streaming salvati valgono come brani della libreria ovunque: Home, daylist, Shuffle+, playlist smart, statistiche, backup (D-597; per loro cambia D-79/D-83) | I | Test delle query di Home, daylist e playlist smart con una riga salvata; backup e ripristino la conservano | 125 |
| R-233 | In modalità streaming i download automatici (Shazam con scaricamento automatico, importazione e sincronizzazione delle playlist) diventano «aggiungi alla libreria» senza file (D-576) | I | Test di `ShazamInbox` e dell'import: in modalità streaming nessun job in `DownloadQueue`, righe salvate create | 125 |
| R-234 | Senza rete, un brano in streaming non in cache è grigio e in coda si salta; avviso «Senza rete: N brani disponibili» (D-577) | I | Test del gestore: voce non in cache e rete assente → salto al prossimo disponibile; widget test della riga grigia | 125 |
| R-235 | Smart cache: oltre all'LRU di oggi, i preferiti restano finché c'è spazio; pre-caricamento di al massimo 3 brani di seguito in coda (il successivo, poi altri 2); in Wi-Fi sempre, con i dati mobili se è acceso «Pre-carica anche con i dati mobili» (di partenza acceso) (D-578, D-609) | I | Test di `StreamCache`: con il limite superato esce prima un non preferito; test del pre-caricamento: mai più di 3 avanti, a consumo con l'opzione spenta nessuno, con l'opzione accesa 3 | 125 |
| R-236 | «Tieni offline» su playlist e album = download veri dei brani mancanti (D-578) | U | Test: «Tieni offline» accoda solo i brani senza file | 126 |
| R-237 | Onboarding: passo «Dove tieni la musica» (Streaming con cache · Sul dispositivo · Scheda SD se c'è), suggerito lo streaming con meno di 4 GB liberi, con la proposta del backup automatico (D-575, D-588) | I | Widget test del passo: con spazio libero finto < 4 GB è preselezionato lo streaming; la scelta finisce nelle impostazioni | 125 |
| R-238 | Memoria per download e cache: interna o scheda SD (Android, `Music/FreeKmusic` sul volume SD); sul computer scelta della cartella dei download (D-579) | U | Test della risoluzione della cartella con un volume SD finto; prova sul telefono con SD (se disponibile) | 126 |
| R-239 | «Qualità download» e «Qualità streaming»: Alta (come oggi), Media (~128 kbps), Bassa (~64 kbps) (D-580) | U | Test della scelta del formato (yt-dlp e NewPipe) per ciascun livello | 126 |
| R-240 | In Memoria, «Libera spazio» converte i download scelti in brani in streaming (cancella i file, tiene preferiti, playlist, statistiche, testi), proponendo prima i non ascoltati da 90 giorni (D-581) | U | Test: la conversione cancella il file e trasforma la riga in salvata mantenendo id, playlist e ascolti | 126 |
| R-241 | Backup automatico in una cartella scelta dall'utente, una volta a settimana, tenendo gli ultimi 3 (D-588) | U | Test con orologio finto: dopo 7 giorni nasce un nuovo zip, il quarto più vecchio viene cancellato | 126 |
| R-242 | Un brano in streaming salvato che sparisce da YouTube viene sostituito con la stessa versione (titolo, artista, durata ±2 s) e l'utente è avvisato nel registro (D-588) | U | Test con catalogo finto: errore «non disponibile» → nuova chiave salvata sulla stessa riga, voce nel registro | 126 |

### Karaoke
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-243 | Filtro voce in tempo reale con cursore 0–100 % su Android, Linux e Windows, per file locali e streaming; resta acceso fra un brano e l'altro e il livello si ricorda; funziona col crossfade; spento da solo su episodi e radio (D-583, D-584, D-586) | I | Test del controller (livello salvato, spento su episodio/radio); sul Mi A3 e su Linux la voce si abbassa in modo udibile a 0 % su un brano stereo | 127 |
| R-244 | Pulsante microfono in «In riproduzione» e nella vista testi: apre il cursore; accendendo il karaoke si apre la vista dei testi sincronizzati se ci sono (D-584) | I | Widget test del pulsante e del cursore; golden di «In riproduzione» con il karaoke acceso | 127 |
| R-245 | «Alta qualità»: separazione AI del brano su richiesta, con avanzamento; la base elaborata va nella smart cache; per lo streaming dopo che il file è in cache (D-585) | U | Test del servizio con un separatore finto (avanzamento, file in cache, ripiego al filtro); misura dei tempi sul Mi A3 annotata | 128 |
| R-246 | Karaoke nella Jam: vale per tutti; l'host decide se gli ospiti lo comandano; «Ignora per me» nella Jam a distanza; versioni vecchie ignorano il campo (D-587) | U | Test del protocollo: messaggio con il campo karaoke letto da una versione che non lo conosce senza errori; test di `applyCommand` col permesso spento | 129 |

### Cerca
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-247 | Barra di ricerca fissa in cima a Cerca, anche sul telefono; il dock perde il campo di testo e il suo tasto porta a Cerca con la tastiera aperta (D-590) | I | Widget test: scorrendo la pagina la barra resta visibile; il tasto del dock dà il fuoco al campo | 124 |
| R-248 | Senza testo: ricerche recenti, poi la griglia dei 12 macrogeneri; il tocco apre «Top 20 · <genere>» con Riproduci, Casuale, scorrimento per la coda e menu del brano (D-591, D-593) | I | Widget test della griglia e della pagina Top 20 con dati finti; golden di Cerca vuota e della pagina | 124 |
| R-249 | Classifiche da Deezer (`/chart/{id}/tracks`) con ripiego e «Italiana» da Apple RSS del paese; paese dalla regione del dispositivo, modificabile; cache 24 h; senza rete l'ultima salvata con la data; ogni brano abbinato a un risultato YouTube suonabile (D-592) | I | Test dei client con fixture salvate (mai rete nella suite); test della cache con orologio finto; test dell'abbinamento (titolo + artista + durata) | 124 |
| R-250 | I generi della libreria escono da Cerca e si raggiungono da Libreria (oggi la griglia dei generi locali sta solo in Cerca e in Radio): voce «Generi» in Libreria che riusa `GenreGrid`/`GenreScreen` (D-593) | I | Widget test: da Libreria si apre la griglia dei generi locali e un genere apre `GenreScreen` | 124 |

### Requisiti non funzionali
| ID | Requisito | Misura |
|---|---|---|
| RNF-01 | Il filtro karaoke in tempo reale non introduce scatti | Sul Mi A3 nessun buco udibile con il filtro acceso; CPU del processo audio misurata con `perf_device.py --playback` entro +10 % |
| RNF-02 | Le classifiche non pesano sui limiti di YouTube Music | Al massimo 1 richiesta per genere ogni 24 h verso Deezer/Apple; l'abbinamento a YouTube passa da `budgetedYtm` e dalla `SearchCache` |
| RNF-03 | Nessuna perdita di dati nel cambio di modo | Nessun file cancellato senza un gesto esplicito; test di aggiornamento da 1.6.2 con download presenti |
| RNF-04 | Accessibilità | Pulsante microfono, cursore, filtro della libreria e riquadri dei generi con etichette TalkBack (test semantici) |

### Convivenza con l'app di oggi (D-598)
- Chi aggiorna trova tutto com'era: modo «Sul dispositivo», download intatti.
- Nessun file viene cancellato senza un gesto esplicito («Libera spazio» o «Elimina»).
- Il ripristino di un backup su un altro dispositivo porta anche i brani in streaming salvati, che si suonano da lì.
- La versione «lite» (senza yt-dlp) si comporta come oggi.

### Fuori perimetro
- Google Drive (D-572): analisi in [`feature-analisi-google-drive.md`](feature-analisi-google-drive.md).
- Cloud WebDAV (D-588): nelle idee future, con le scelte già fatte.
- Tempo di chiusura della notifica regolabile (D-589: fisso a 30 minuti).
- Karaoke dal menu di ogni brano; livello ricordato per brano (D-584).
- Classifiche da YouTube Music, Last.fm o Spotify (D-592).

## Vincoli (giro 3, D-599..D-602)
- **Licenza:** il progetto passa a GPLv3 (D-599) nella prima fase: `LICENSE` alla radice, voce nel README e in Informazioni.
  Rimedia all'obbligo verso il codice GPLv3 già distribuito (NewPipeExtractor, youtubedl-android); vedi
  [`feature-analisi-google-drive.md`](feature-analisi-google-drive.md) § 5.
- **Piattaforme:** tutto su Android, Linux e Windows; il karaoke non compare su macOS e iOS (D-600). Cerca, libreria
  in streaming e backup valgono anche su macOS/iOS come il resto dell'app.
- **Spesa:** nessun servizio a pagamento, nessun account, nessun backend (D-601).
- **Privacy:** le classifiche mandano a Deezer e Apple solo genere e paese; il modello AI si scarica alla prima «Alta
  qualità» e i brani non escono mai dal dispositivo (D-601).
- **Peso:** l'APK di base non cresce per l'AI: se il motore pesa troppo, «Alta qualità» è un componente scaricato a
  parte come yt-dlp (D-602).
- **Telefono di prova:** Mi A3 (Android 10, API 29) è il riferimento delle misure (RNF-01, tempi dell'AI). Su API 29
  i download stanno in `Music/FreeKmusic` senza `MediaPublisher`; la scheda SD si prova solo se ce n'è una.
- **Nessuna scadenza.**

## Stack (giro 4, D-603..D-605)
Versioni bloccate oggi (`pubspec.lock`, 15/11/2026): `just_audio` 0.10.6 (Android: ExoPlayer/Media3),
`just_audio_media_kit` 2.1.0, `media_kit` 1.2.6 (libmpv sul desktop), `audio_service` 0.18.19, `dio` come oggi.

| Pezzo | Scelta | Versione / fonte (15/11/2026) | Note |
|---|---|---|---|
| Filtro voce Android | copia modificata di `just_audio` in `third_party/just_audio/` (solo il pacchetto Android), `dependency_overrides` in `pubspec.yaml` (D-603) | base 0.10.6; `AudioPlayer.java` costruisce `DefaultRenderersFactory` senza un punto d'innesto per i processori audio | sottoclasse di `DefaultRenderersFactory` con un `AudioProcessor` Media3 che produce lato (L−R) più medio passa-basso (~150 Hz) per tenere basso e cassa; livello 0–100 % regolato da un metodo nuovo sul canale. Licenza di just_audio: MIT |
| Filtro voce desktop | copia modificata di `just_audio_media_kit` in `third_party/just_audio_media_kit/` (D-603) | base 2.1.0; il `Player` di media_kit è privato (`mediakit_player.dart:16`) | espone `setProperty('af', 'lavfi=[pan=…]')`; da verificare all'inizio della fase che la libmpv di Windows abbia `lavfi`/`pan` e che conviva con `scaletempo` (velocità) |
| Motore AI | `flutter_onnxruntime` 1.9.0, MIT (D-604) | pub.dev, ONNX Runtime 1.23; Android, iOS, Linux, macOS, Windows | solo nella fase «Alta qualità»; se fa crescere troppo l'APK diventa un componente scaricato (D-602) |
| Modello di separazione | da scegliere dopo un passo di prova (D-605) | Spleeter 2-stem (pesi senza licenza dichiarata), MDX-Net (licenza dei pesi non chiara) | misure sul Mi A3 e sul PC: tempo per minuto di audio, memoria, peso del modello; senza licenza usabile la fase si ferma |
| Classifiche | `dio` già nel progetto, nessun pacchetto nuovo | Deezer `api.deezer.com/chart/{genre_id}/tracks` (per genere, verificato); Apple RSS `rss.marketingtools.apple.com/api/v2/<paese>/music/most-played/100/songs.json` | ID Deezer: pop 132, rap 116, rock 152, dance 113, electro 106, R&B 165, jazz 129, classica 98, metal 464, country 84, reggae 144, reggaeton 122, latina 197, alternative 85, folk 466, soul/funk 169. YouTube Music non ha classifiche per genere in Italia |
| Cartella del backup | `file_picker` già nel progetto (cartella) | — | su Android la cartella scelta passa da SAF se serve; da verificare in fase |

**Politica sulle dipendenze per questa feature:** l'unico pacchetto nuovo approvato è `flutter_onnxruntime` (D-604);
le tre copie modificate (`just_audio`, `just_audio_media_kit`, `audio_service`: D-603, D-608) si tengono minime (diff annotato in `third_party/<pacchetto>/MODIFICHE.md`) e si riallineano a
ogni aggiornamento di `just_audio`/`just_audio_media_kit`/`audio_service`. Qualsiasi altro pacchetto va chiesto.

## Architettura

Righe verificate sul codice del 15/11/2026 (master `9364c42a`); «(da verificare)» = non controllato o da provare sul
telefono. Ordine delle aree = ordine delle fasi (D-606). Nessun pacchetto nuovo oltre a `flutter_onnxruntime` (D-604).

### A. Comandi multimediali e notifica (R-226..R-228, D-599)
**Ipotesi sulle cause (da confermare sul Mi A3 con `adb shell input keyevent` e cuffie JBL, prima di correggere):**
- **H1, pausa che fa ripartire (R-227), quasi certa dal sorgente.** `audio_service` 0.18.19 manda 126, 127, 85 e
  `HEADSETHOOK` tutti a `onClick(MediaButton.media)` (`AudioService.java:976-981`); il `click()` di base
  (`audio_service.dart:3089`) commuta su `playbackState.playing` e il gestore non lo ridefinisce: da fermo 127 chiama
  `play()`; mentre uno stream aspetta il file (`_waitingStream`, `playing == false`) la pausa diventa un `play()` vuoto.
  Le cuffie (AVRCP) mandano PLAY e PAUSE separati. La tendina usa `KEYCODE_BYPASS_*` → `onPlay`/`onPause`: non c'entra.
- **H2, tasti morti dopo una Jam (R-226).** `_showRemote` (`codecore_audio_handler.dart:1887`) pubblica `idle` quando
  la Jam non ha brani; `AudioService._observePlaybackState` (`audio_service.dart:1132`) al passaggio a `idle` chiama
  `_stop()` → `stopService` → `deactivateMediaSession()`. Alla fine della Jam `attachRemote(null)` (`:1860`) ripubblica
  `_publishedProcessing` (`:1917`), cioè l'ultimo stato **della Jam**: se era `idle` la sessione resta spenta finché
  non si preme Play nell'app, e Android manda i tasti a un'altra app.
- **H3** `_remote` lasciato appeso se `_teardown` (`jam_providers.dart:982`, stacca a `:995`) non gira (errore a metà):
  play/pausa vanno a un trasporto morto (da verificare con una Jam chiusa uccidendo l'ospite).
- **H4** `androidStopForegroundOnPause: true` (`main.dart:174`): in pausa il processo può morire e il tasto riparte
  da `MediaButtonReceiver` (da verificare su Android 12+; il Mi A3 è API 29).

**Correzione.** Tutto in `codecore_audio_handler.dart` (area a rischio, `/code-review high`):
1. `click()` ridefinito: `next`/`previous` come oggi; `media` → `togglePlayPause()` (`:1509`), che già considera
   `_waitingStream && _playWhenReady`. Per «pausa = sempre pausa» con 127 serve distinguere il tasto, cosa che il Dart
   di `audio_service` non può fare → **scelta aperta 2** (copia minima di `audio_service` in `third_party/` con
   `KEYCODE_MEDIA_PLAY → onPlay()` e `KEYCODE_MEDIA_PAUSE → onPause()` in `onMediaButtonEvent`).
2. `attachRemote(null)` ricalcola lo stato da quello locale (`_current == null ? idle : ready`), non da
   `_publishedProcessing`; `_showRemote` non pubblica mai `idle` mentre la Jam è aperta (`ready` con
   `playing: false`), così la sessione resta viva per tutta la Jam.
3. Test nuovo `test/services/audio/handler_media_buttons_test.dart`: comandi dopo attach → detach, `click(media)`.

**Chiusura dopo 30 minuti (R-228, D-589).** Nel gestore (deve vedere `_remote`, `_state` e `_clock`), attiva solo con
`stopServiceWhenIdle: true` dal costruttore in `main.dart` su Android (MPRIS/SMTC non hanno un servizio da fermare):
- `_idleTimer` di 30 min, armato in `_publish` quando `!playing && _remote == null && !_waitingStream`, annullato da
  `playing`, `attachRemote(transport)` e `_goIdle`. La fine del timer del sonno è una pausa: nessun caso speciale.
- Allo scadere `_park()`: `_saveResume()` e `processingState: idle` **senza** svuotare `_current`, coda o posizione
  (backend in pausa) → `audio_service` ferma il servizio e toglie la notifica. Un flag `_parked` tiene `idle` finché
  `play()` non lo azzera e chiama `_backend.play()` (`enterPlayingState` riavvia il primo piano). Coda e posizione su
  disco le salva già `PlaybackPersistence` (`playback_persistence.dart:37`); nessuna UI legge `idle` (grep in `lib/ui`).
- Invariante: con una Jam attiva non scatta mai, nemmeno con la Jam in pausa da ore.

**Licenza (D-599).** `LICENSE` (GPLv3) alla radice, riga nel README, voce accanto a `showLicensePage` (`settings_pages.dart:492`).

### B. Cerca (R-247..R-250)
**Client delle classifiche.**
- `DeezerClient.chart(int genreId, {int limit = 20})` in `deezer_client.dart` (accanto a `artistTop`, `:143`): una GET
  `/chart/{id}/tracks?limit=20` con `_getPaged` (pausa di 5 s sul codice 4, niente riposo di 10 min). La classifica
  di Deezer segue il paese dell'IP, non un parametro (da verificare con una fixture).
- `lib/services/online/apple_rss_client.dart` (nuovo, `WebClient.getJson` come gli altri): `mostPlayed(country)` su
  `rss.marketingtools.apple.com/api/v2/<paese>/music/most-played/100/songs.json` → titolo, artista, generi della
  voce (campo `genres[].name`, da verificare sulle fixture). Niente durata.
- `lib/services/online/chart_genres.dart` (nuovo, solo costanti): i 12 macrogeneri di D-591.

| Macrogenere | Deezer (principale) | Ripiego Apple (feed del paese filtrato per genere) |
|---|---|---|
| Pop | 132 | Pop |
| Rap e Hip-hop | 116 | Hip-Hop/Rap |
| Rock | 152 | Rock |
| Dance ed Elettronica | 113 (poi 106) | Dance, Electronic |
| R&B e Soul | 165 (poi 169) | R&B/Soul |
| Latina e Reggaeton | 197 (poi 122) | Latin |
| Italiana | — | feed `it` intero (sempre l'Italia, non il paese dell'utente) |
| Indie e Alternative | 85 | Alternative |
| Jazz | 129 | Jazz |
| Classica | 98 | Classical |
| Metal | 464 | Metal, Hard Rock |
| Country | 84 | Country |

**Cache 24 h.** Si riusa `CatalogCache` (`catalog_cache.dart:33`, un file JSON, LRU, copie scadute tenute per
l'offline con la data): nuovo valore `CatalogKind.chart(Duration(hours: 24))`, chiave `chart:<genere>:<paese>`. La
voce tiene i 20 brani **e** gli abbinamenti già trovati (`ytResultToJson` di `search_cache.dart`): riaprire un genere
nello stesso giorno non fa ricerche su YouTube (RNF-02). Niente tabella drift.

**Abbinamento a YouTube.** La pagina «Top 20» è `OnlinePlaylistScreen` (`online_playlist_screen.dart:36`) con un
nuovo `OnlineCollectionRef.chart(genre)` → `ChartRef` in `online_collection_providers.dart:19`. In
`onlineCollectionProvider` (`:102`) il ramo `ChartRef` legge la cache o i client e produce una `ExternalCollection`;
`onlineMatchesProvider` (`:131`) usa lo stesso `CollectionMatcher` (prima la libreria, poi `searchRow` sotto
`budgetedYtm` col limite di 40/min, `request_budget.dart:27`) e scrive gli abbinamenti nella voce di cache. Da
aggiornare gli `switch` sul tipo sigillato: `refreshOnlineCollection` (`:155`), `retryOnlineCollection` (`:173`) e
`_external` (`online_playlist_screen.dart:49`, diventa `is! YoutubeListingRef`). Riproduci, Casuale, coda che si
allunga e menu del brano ci sono già (con «Salva in Libreria» e «Scarica tutto», da confermare nei mockup). Paese: `PlatformDispatcher.instance.locale.countryCode`, sovrascritto da `chartCountry` in
`settings_store.dart`.

**UI.** `search_screen.dart:113`: `showField` sempre vero (la barra c'è già, oggi solo su schermo largo). Dock:
`_SearchField` (`bottom_bar.dart:161`) e `searchBarProvider` (`ui_providers.dart:77`, usato da `shell_nav.dart`,
`app_shell.dart`, `bottom_bar.dart`, `search_screen.dart:182`) si tolgono; il tasto Cerca apre la scheda e chiama
`searchFocusProvider.requestFocus()`. `_EmptyQuery` (`:165`): recenti come oggi, poi una `GenreGrid` coi 12
macrogeneri (riquadri colorati, etichette TalkBack) al posto dei generi locali (`:212-228`).
**Generi in Libreria (R-250).** Nuova `LibraryShortcut` «Generi» in `library_screen.dart` (elenco a `:399-446`) che
apre una schermata con il blocco spostato da `_EmptyQuery` (`genresProvider` + `GenreGrid` → `GenreScreen`). Radio
(`radio_sections.dart:248`) invariata.

### C. Libreria leggera (R-229..R-242)
**Modello dati: come si segna un brano in streaming «salvato».** Proposta: **colonna nuova `tracks.saved`**
(`BoolColumn`, di serie `false`) sulle righe ombra (`kind = 2`, `path = stream:<chiave>`); schema **v19 → v20**
(`kSchemaVersion`, `app_database.dart:12`) con un solo `m.addColumn(tracks, tracks.saved)` nel blocco `if (from < 20)`,
sullo stesso modello del controllo `PRAGMA table_info` di `from < 19` (`:203`). Le righe ombra di oggi restano
`saved = false`, quindi nascoste come prima (D-598). Perché non `kind = 3`: tutto ciò che oggi riconosce uno stream
da `kind == kStreamKind` (`isStreamTrack`, `online_entries.dart:13`; `streamRow`, `track_repository.dart:139`;
`upsertStreamRow` `:227`; `trackRefOf`, `backup_queries.dart:237`; il gestore a `:527`) continua a funzionare senza
toccarlo: una query di libreria dimenticata nasconde un brano, mentre un controllo di stream dimenticato farebbe
aprire `stream:…` come file nel gestore audio. Alternativa nella **scelta aperta 1**.
- Un predicato solo, in `track_kinds.dart`: `libraryRowSql = '(kind = 0 OR (kind = 2 AND saved = 1))'` e l'equivalente
  drift `isLibraryRow(t)`; il filtro R-231 usa `kind = 0` (Sul dispositivo) o `kind = 2 AND saved = 1` (In streaming).
- `albumKey` di una riga salvata: oggi `stream|<chiave>` (`track_repository.dart:263`, un album per brano). Al
  salvataggio diventa `stream|` + chiave normalizzata di artista dell'album e album: le righe salvate dello stesso
  album si raggruppano fra loro, mai con un album locale (le copertine restano separate).
- `TrackRepository.setSaved(int id, bool)` e `saveStream(YtResult)` = `ensureStreamRow` (`:245`) + `saved = true` +
  `albumKey`, in una transazione.

**Query da cambiare (K-02, un passo solo, `/code-review high`).** Passano a `libraryRowSql`/`isLibraryRow`:
- Schede e conteggi: `watchTracks` (`track_repository.dart:530`), `musicLight` (`:520`), `tracksOfArtist` (`:686`),
  `tracksOfAlbums` (`:844`), `liteEntries` (`:1041`, indice usato da import e matcher: così una riga salvata conta come
  «già in libreria»), `countAll`/`watchCount` (`:1221`/`:1232`); `library_queries.dart` `watchAlbums` (`:120`),
  `watchArtistAlbums` (`:135`), copertine e righe degli artisti (`:157`, `:175`), `artistNamed` (`:201`),
  `watchArtistTracks` (`:224`), `watchGenres` (`:253`), `watchGenreTracks` (`:268`), `watchAlbumTracks` (`:282`),
  `genreCounts` (`:299`); `filter_counts_repository.dart:27`; `credits_repository.dart:113`;
  `artist_country_repository.dart:47`.
- Home, daylist, Shuffle+, smart: `watchRecentlyAdded` (`track_repository.dart:978`), `watchTopTracks`
  (`library_queries.dart:239`), `randomTracks` (`:322`), `daylist_store.dart:83`, `seed_resolver.dart:62`,
  `shuffle_plus_controller.dart:421`, `player_providers.dart:765`, `rule_sql.dart:34` (quindi `watchByRules`,
  `track_repository.dart:720`, e i tag).
- Statistiche: `stats_queries.dart:108` e `:275`; `:433`/`:439` usano già `listenKinds` (invariati).
- **Restano `kind = 0`** (lavorano sui file): `_downloadedNoPlaylist` (`:559`), `mp3LengthRows` (`:919`),
  `duplicate_repository.dart:26`, `review_queries.dart:29`, `track_genre_repository.dart:171`, `memory_queries.dart:11`
  e `:198`, `track_deleter.dart:68`, `bulk_actions.dart:104`, `playlist_sync_repository.dart:96`,
  `track_actions.dart:304`/`:361` (per una riga salvata: «Rimuovi dalla libreria» = `setSaved(false)` e «Scarica»).
- `deleteUnplayedStreamRows` (`:147`): aggiunge `saved = false` (una riga salvata senza ascolti non si cancella mai).

**Smart cache (R-235).** `StreamCache._evict` (`stream_cache.dart:148`) ordina per data e salta i fissati: si
aggiunge `Future<Set<String>> Function()? keepLonger` (chiavi delle righe salvate preferite, dal provider in
`stream_providers.dart`) e l'ordine diventa «non preferiti per LRU, poi preferiti per LRU». `clear()` resta uguale
(gesto esplicito). **Wi-Fi:** l'app lo sa già: `NetworkBridge.kt` (`isMetered`) → `networkProbeProvider`
(`shuffle_plus_providers.dart:71`) → `StreamPreparer.isMetered` (`stream_providers.dart:63`). Oggi il pre-caricamento
va oltre D-578: senza consumo scarica **tutta** la coda, a consumo i prossimi 3 (`stream_preparer.dart:406`,
`meteredAhead = 3`). Diventa al massimo 3 sempre; a consumo 3 con l'opzione «Pre-carica anche con i dati mobili» accesa (default), nessuno con l'opzione spenta (D-609).

**Offline (R-234).** Riga grigia da un provider (chiavi in `StreamCache` + rete). Se `_nextFile`
(`codecore_audio_handler.dart:1270`) torna `null` per una riga ombra e `preparer.hasNetwork` è falso, il gestore salta
al prossimo brano con un file invece dell'errore; «Senza rete: N brani disponibili» lo conta la UI sulla coda.

**Dove si sceglie fra scaricare e aggiungere (R-230, R-233).** Un punto solo: `libraryAdder` (nuovo, in
`lib/providers/library_add_providers.dart`) con `add(YtResult r, {String? tag})` → in modo «Streaming con cache»
`saveStream(r)`, altrimenti `downloadsProvider.notifier.add(r, tag: tag)`. Lo chiamano al posto di
`downloadsProvider…add`: `shazam_providers.dart:102`, `import_providers.dart:62` (`enqueue` dell'import),
`pending_playlist_adds.dart` (tag `addto:`), e i menu dei risultati online (`online_song_row.dart:55`/`:146`,
`online_results_sections.dart:341`, `track_actions.dart:619`, `genre_screen.dart:198`, `suggestion_actions.dart:226`),
che cambiano anche l'etichetta («Aggiungi alla libreria»). «Scarica» a mano resta e chiama sempre la coda dei
download. Per import e `addto:` la playlist oggi si riempie a download finito (`parseImportTag`,
`import_providers.dart:315`): in modo streaming la riga si aggiunge subito con `addStreamTracks`
(`playlist_repository.dart:150`) (da verificare il percorso dell'import). Lo scarico di una riga salvata usa il
percorso di oggi: `mergeStreamRow` (`track_repository.dart:203`) sposta ascolti, preferito e playlist sul file.
Impostazione `storageMode` in `settings_store.dart` (di serie «Sul dispositivo» se `onboardingDone`, D-598).

**Onboarding (R-237).** Pagina nuova in `onboarding_pages.dart`, inserita dopo `FoldersPage` (`onboarding_screen.dart:85`);
spazio da `diskSpaceOf` (`disk_space.dart:35`), streaming preselezionato sotto i 4 GB, proposta del backup automatico.

**Scheda SD (R-238).** Volumi con `getExternalStorageDirectories` (`path_provider`, già presente). Download: su
Android 11+ `MediaPublisher`/`MediaPublishBridge.kt` riceve il nome del volume (`MediaStore.Audio.Media.getContentUri
(volume)`) e pubblica in `Music/FreeKmusic` sulla SD; su Android 10 e prima (D-567, Mi A3) la cartella dell'app sul
volume SD (`…/Android/data/<pkg>/files/Music`, sparisce disinstallando: detto nell'impostazione).
`resolveDownloadFolder` (`youtube_providers.dart:100`) legge l'impostazione. Cache: `StreamCache.inAppSupport`
(`stream_cache.dart:25`) prende la cartella dell'app sul volume scelto. Desktop: scelta della cartella con
`file_picker` (da verificare l'aggiunta come cartella della libreria).

**Qualità (R-239).** `downloadChoice` (`yt_dlp_args.dart:18`) riceve il livello: Alta = oggi, Media =
`bestaudio[abr<=128]/bestaudio`, Bassa = `bestaudio[abr<=64]/worstaudio` (da verificare su yt-dlp e youtubedl-android);
in streaming anche `NewPipeUrl.kt:45` sceglie il flusso con `averageBitrate` sotto il tetto invece del più alto.

**«Libera spazio» (R-240).** Inverso di `promoteStreamRow` (`track_repository.dart:168`) sulla **stessa riga**:
`demoteToStream(id, key)` scrive `path = stream:<chiave>`, `kind = 2`, `saved = true`, `folderId = null`,
`format = ''`, `sizeBytes = 0` (stesso id, quindi playlist, ascolti, preferito, testi restano senza `merge`), poi
cancella il file (`MediaDeleteBridge.kt` su Android 11+). La chiave viene da `DownloadIndex` (`download_index.dart`,
`<fonte>:<id>` → percorso): solo i file scaricati dall'app sono convertibili; i file propri dell'utente non compaiono
nell'elenco. Ordine: prima la riga, poi il file (un file rimasto si rivede alla scansione; il contrario perde dati).

**Backup automatico (R-241).** Nessun lavoro in background: come il controllo delle uscite (`isCheckDue` in
`check_schedule.dart:15`, lanciato all'avvio e a ogni `onResume` in `startup_providers.dart:82`), un
`isBackupDue(lastAt, now)` ≥ 7 giorni → `BackupService.createBackup` (`backup_service.dart:132`) nella cartella
scelta, poi si tengono gli ultimi 3 `freekmusic-backup-*.zip` (`fileName`, `:129`). Su Android 11+ una cartella fuori
dall'app può richiedere SAF (da verificare in fase, riga «Cartella del backup» dello Stack).
**Backup e ripristino delle righe salvate.** La copia del DB (`VACUUM INTO`) porta la colonna; il formato portabile
oggi esclude `kind = 2` (`backup_queries.dart:25`): diventa `kind != 2 OR saved = 1`, la `TrackRef` ha già
`streamKey` (`:237`) e `TrackUserData` prende `saved: true`; il ripristino crea la riga con `ensureStreamRow` (come per
le playlist, `backup_merge.dart`) e la segna. Conteggio del riepilogo a `backup_service.dart:148` allineato.

**Brani spariti (R-242).** `YtErrorKind.unavailable` (`youtube_service.dart:135`) su una riga salvata → `searchRow`
(titolo, artista, durata ±2 s) sotto `budgetedYtm` → trovato: `path = stream:<nuova>` sulla stessa riga e voce nel
registro attività; non trovato: solo la voce. Mai fuori tolleranza.

### D. Karaoke (R-243..R-246)
**Controller.** `lib/services/karaoke/karaoke_controller.dart` (puro Dart) + `lib/providers/karaoke_providers.dart`:
stato `{on, level}` salvato in `settings_store.dart`; ascolta il brano corrente e mette il filtro in bypass su
episodi (`kind == kEpisodeKind`) e radio (`handler.isRadio`), senza toccare il livello salvato.
**Motore.** Interfaccia `VoiceFilter { Future<void> setLevel(double? level) }` (null = spento) accanto a `Equalizer`, e
`AudioBackend.voiceFilter` (null dove manca: macOS/iOS, anteprima, player della Jam), come `equalizer`
(`audio_backend.dart:49`).
- Android: nella copia di `just_audio` (D-603) un `AndroidVoiceFilter` sullo stesso modello di `AndroidEqualizer`
  (`AudioPipeline(androidAudioEffects: …)`, `just_audio_backend.dart:26`), ma lato Java è un `AudioProcessor` Media3
  inserito nella sottoclasse di `DefaultRenderersFactory`, con un metodo `setVoiceLevel` sul canale del player. Il
  gapless (`setNext`, una sola `ExoPlayer`) non cambia: il processore vale per tutta la sorgente concatenata.
- Desktop: nella copia di `just_audio_media_kit` un accesso a `setProperty('af', …)` del `Player` privato
  (`mediakit_player.dart:16`) con `lavfi=[pan=…]` (lato attenuato, basso tenuto); da verificare il legame fra
  `AudioPlayer` e il player di media_kit (id del player) e la libmpv di Windows (F-6).
- Crossfade: `CrossfadeEngine` ha già `MirrorEqualizer` (`crossfade_engine.dart:393`) per i due player: si aggiunge
  `MirrorVoiceFilter` uguale, così il secondo player nasce col livello giusto durante la dissolvenza.
**UI.** Microfono in «In riproduzione» e nei testi, cursore in un foglio; assente se `voiceFilter == null` (macOS/iOS).
**«Alta qualità» (R-245, dopo la prova di D-605).** `lib/services/karaoke/separation_service.dart`: modello scaricato
alla prima richiesta con lo schema di `yt_dlp_updater.dart` (cartella dati, versione, sha256); decodifica in PCM
(Android `MediaCodec` in Kotlin, desktop ffmpeg: da verificare); inferenza `flutter_onnxruntime` fuori dal thread UI
(da verificare se il plugin va in un isolate secondario); base in `StreamCache` con chiave `karaoke:<chiave stream>` o
`karaoke:local:<id>:<mtime>` (LRU, fissata mentre suona). Il gestore consulta `karaokeSource(Track) → String?` in
`_nextFile`/`_loadCurrent` prima del percorso normale; il cambio a metà brano ricarica alla stessa posizione. Con la
base attiva il filtro è in bypass e il cursore diventa base/originale (mockup). APK troppo pesante → componente (D-602).
**Jam (R-246, ultima fase).** `JamState.toJson` (`jam_models.dart:287`) aggiunge `'kar': {'l': livello, 'g':
ospitiAmmessi}` solo se acceso (come `'spk'`/`'mode'`); `tryParse` lo legge se c'è. Comando nuovo
`JamCommandType.karaoke`: una versione vecchia lo scarta perché `JamCommand.tryParse` torna `null` sui tipi sconosciuti
(`:465`, verificato); `applyCommand` (`jam_state.dart:19`) lo rifiuta da un ospite senza permesso. «Ignora per me» è una
preferenza locale del dispositivo che suona. Area a rischio: review Opus del protocollo.

### Scelte chiuse al giro 5 (15/11)
1. Segno «salvato»: colonna `tracks.saved`, schema v20 (D-607).
2. «Pausa = sempre pausa»: copia minima di `audio_service` in `third_party/` (D-608), terza copia accanto a quelle di D-603.
3. Pre-caricamento: al massimo 3 brani avanti; con i dati mobili decide l'utente, di partenza acceso (D-609).

## Flussi principali
**(a) Aggiungi alla libreria in streaming.** Menu di un risultato → `libraryAdder.add(r)` → modo streaming →
`saveStream(r)` (riga `kind = 2`, `saved = 1`, `albumKey` d'album) → la riga compare in Brani/Album/Artisti con la
nuvola (`isLibraryRow`) → Play → `_nextFile` → `preparer.cachedFile` scarica in `StreamCache` → `upsertStreamRow`
riempie formato e peso → il brano suona; i 3 dopo si pre-caricano (con i dati mobili solo se l'opzione è accesa); la pulizia della cache toglie il
file ma mai la riga.
**(b) Tocco su un genere.** Cerca vuota → riquadro «Rock» → `OnlinePlaylistScreen(OnlineCollectionRef.chart(rock))` →
`CatalogCache` fresca? sì: brani e abbinamenti subito; no: `DeezerClient.chart(152)` (errore → Apple RSS filtrato per
«Rock»; offline → copia scaduta con la data) → righe `pending` → `CollectionMatcher` (libreria, poi YouTube a 40/min)
→ righe suonabili e abbinamenti salvati nella voce → Riproduci/Casuale come una playlist esterna.
**(c) Karaoke acceso e crossfade.** Microfono → livello 30 % → `KaraokeController` → `backend.voiceFilter.setLevel(0.3)`
→ `MirrorVoiceFilter` lo manda al player attivo → a fine brano `CrossfadeEngine` crea o riusa il secondo player, che
riceve il livello da `MirrorVoiceFilter.add` prima della rampa → il brano dopo è un episodio → il controller mette il
filtro in bypass; al brano musicale seguente torna al 30 %.

## Rischi della feature
F-1 e F-2 sono quelli che preoccupano di più l'utente (D-610): test di regressione scritti prima della modifica, review Opus o `/code-review high`, e per F-1 una prova sul Mi A3 con una Jam vera.

| # | Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|---|
| F-1 | **Regressione Jam/notifica** correggendo i tasti: la Jam perde la notifica o il gestore locale la riprende mentre la Jam è aperta; il parcheggio a 30 min scatta in Jam | modifiche solo in `click()`, `attachRemote(null)`, `_showRemote` e `_park`, con test attach → detach → tasti; il timer si arma solo con `_remote == null`; prova sul Mi A3 con una Jam vera e Linux ospite | notifica con i comandi locali durante una Jam; servizio fermo dopo una Jam lunga in pausa |
| F-2 | **K-02: righe ombra dove non devono stare o righe salvate perse**: una query dimenticata mostra righe non salvate, o una pulizia cancella righe salvate | predicato unico `isLibraryRow`, elenco delle query sopra spuntato in un passo solo, `/code-review high`; `test/data/stream_rows_hidden_test.dart` esteso (ombra non salvata invisibile ovunque, salvata visibile in schede/Home/smart); `deleteUnplayedStreamRows` con riga salvata | brani con la nuvola che spariscono dopo «Svuota cache»; righe ombra mai salvate in «Tutti i brani» |
| F-3 | **Migrazione v20** fallita o ripristino di un backup nuovo su un'app vecchia | un solo `addColumn` con controllo `PRAGMA` come in `from < 19`; test di migrazione da un DB v19 di 1.6.2 con download e righe ombra (RNF-03); il formato portabile aggiunge solo campi facoltativi | errore all'apertura del DB dopo l'aggiornamento; «Unisci» che fallisce su una versione precedente |
| F-4 | **Copia di just_audio** che rompe la riproduzione, il gapless o l'equalizzatore su Android | diff minimo annotato in `third_party/just_audio/MODIFICHE.md`; processore in bypass a livello 100 % (copia esatta dei campioni); test di riproduzione/gapless/crossfade di oggi verdi; `perf_device.py --playback` (RNF-01) | buco udibile fra due brani; CPU del processo audio +10 %; equalizzatore che non agisce più |
| F-5 | **Backup/ripristino** che perde le righe salvate o i loro preferiti e ascolti | `collectUserData` con `kind != 2 OR saved = 1`; test backup → ripristino su DB vuoto (righe salvate, preferiti, playlist uguali); backup automatico che non cancella mai lo zip appena scritto | ripristino con meno brani in «In streaming»; quarto zip che resta o zip nuovo cancellato |
| F-6 | **Windows: libmpv senza `lavfi`/`pan`** o in conflitto con `scaletempo` | prima attività della fase karaoke: prova di `af` su Windows dalla CI o da una macchina Windows; senza, il pulsante non compare lì (come macOS) | errore di mpv nel log impostando `af`; velocità della Jam che non cambia più col filtro |
| F-7 | **Modello AI senza licenza usabile o troppo lento** sul Mi A3 | passo di prova di D-605 prima di ogni codice; numeri annotati; senza licenza la fase si ferma e resta il filtro | più di 2 min per un brano di 4 min; licenza dei pesi assente |
| F-8 | **Deezer/Apple cambiano formato o limitano**, oppure l'abbinamento sceglie il brano sbagliato (cover, live, karaoke) | fixture salvate e client tolleranti; ripiego Apple, poi copia scaduta; abbinamento con le soglie di Exportify e durata; «Cerca a mano» sulle righe non trovate | genere sempre vuoto; righe «non trovato» oltre 1 su 4; versioni live in cima |
| F-9 | **Tempo**: sette fasi, due copie di pacchetti da riallineare e una fase AI dall'esito incerto | ordine di D-606 (prima i guasti, poi Cerca e libreria); karaoke col filtro utile da solo; «Alta qualità» e Jam rimandabili | fase karaoke ferma per il motore desktop; fase AI senza modello dopo la prova |
