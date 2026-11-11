# Fase 117 — Ripristino completo, download pubblici e ritocchi

## Obiettivo
«Unisci» porta su un altro dispositivo tutto ciò che sta nel backup, e rifarlo non duplica niente. I download nuovi vanno nella cartella pubblica `Music/FreeKmusic`. In più sei ritocchi di UI (Registro, swipe, selezione, sfocatura, trasparenza dei temi). Chiude con la versione 1.6.0 e la Release. Viene prima della CI Windows.
Fuori: spostare i download già in `Android/data` (D-547), la selezione multipla delle card di album, playlist e artisti (D-550), un'impostazione per scegliere la cartella dei download.

## Riferimenti
- Decisioni D-545..D-555. Richieste e diagnosi: `.claude/obiettivi/2026-11-11-richieste-utente.md`.
- Aree: [`sync-backup-jam.md`](../architettura/sync-backup-jam.md) (Backup), [`piattaforme.md`](../architettura/piattaforme.md), [`riproduzione-e-coda.md`](../architettura/riproduzione-e-coda.md), [`ui-e-design.md`](../architettura/ui-e-design.md).
- Caso reale: un backup di Codecore (musica in `Android/data`) ripristinato su FreeKmusic (musica in `Music/FreeKmusic`), quindi percorsi diversi e solo «Unisci».

## Requisiti
| ID | Requisito | Pri | Criterio di accettazione |
|---|---|---|---|
| R-211 | «Unisci» applica `settings.json` del backup: vince il backup, tranne `kDeviceBoundKeys`; i temi personalizzati (`customThemes`) si uniscono per id, e a parità di id vince il backup (D-545) | I | test: un'impostazione cambiata nel backup arriva, `deviceId`/`deviceName`/`trustedDevices` restano quelli locali, un tema solo locale resta e un tema solo del backup arriva |
| R-212 | Il backup contiene l'immagine di sfondo dei temi personalizzati; il ripristino (completo e «Unisci») la rimette in `themeDir()` e riscrive `imagePath` col percorso del dispositivo | I | test: zip con `theme/<file>`; dopo l'unione il tema punta a un file esistente nel `themeDir()` locale |
| R-213 | Lo storico degli ascolti (`plays`) del backup arriva sui brani riconosciuti con `TrackResolver`; quelli non riconosciuti si saltano e si contano (D-546) | I | test: gli ascolti di un brano riconosciuto arrivano con `playedAt`, `msPlayed`, `context`, `contextName`; il resoconto riporta «N ascolti non collegati» |
| R-214 | Le copertine automatiche si collegano come quelle a mano: un brano locale senza copertina prende la `coverKey` del brano del backup, se il file esiste (anche `.webp`) | I | test: un brano con `coverSource` 0 nel backup e la copertina in `covers/` ce l'ha dopo l'unione; una copertina locale già presente non cambia |
| R-215 | Tag (`user_tags`, `track_tags`), playlist smart (`smart_playlists`) e podcast (`podcasts`, `podcast_episodes`) arrivano dall'unione | I | test: dopo l'unione esistono con gli stessi nomi, regole e iscrizioni; i tag sono sui brani riconosciuti |
| R-216 | «Unisci» due volte di fila non duplica niente: playlist (anche quelle rinominate «(ripristinata N)»), ascolti, tag, playlist smart, podcast, episodi, temi, radio, artisti | I | test: dopo la seconda unione il conteggio di ogni tabella toccata è uguale a quello dopo la prima |
| R-217 | I download nuovi su Android vanno in `Music/FreeKmusic` via MediaStore, leggibili da altre app, adb e MTP; su desktop non cambia niente | I | sul Mi A3: un brano scaricato compare in `/sdcard/Music/FreeKmusic` con `adb shell ls -l`, si riproduce, ha i tag scritti; «Elimina dal dispositivo» lo cancella |
| R-218 | Registro: con un tema che ha un'immagine o un gradiente di sfondo, l'intestazione fissa dei giorni mostra lo stesso sfondo della pagina (D-548) | I | test widget o golden: con `pageBackdrop` attivo l'intestazione non dipinge un riquadro `cc.bg` pieno |
| R-219 | Registro: una voce per ogni brano che non parte (titolo e motivo); se lo stesso brano fallisce più volte di fila, la voce è una sola (D-549) | I | test: due `PlaybackFailure` dello stesso brano di fila danno una sola voce; uno di un altro brano ne dà una seconda |
| R-220 | Lo swipe per mettere in coda funziona in ogni lista di brani, compresi i brani online: daylist (propri e suggeriti), playlist online, Suggeriti e righe online di `LiveTrackRow`. Le varianti coda e scelta restano senza | I | test widget: lo swipe sulla riga della daylist e su una riga online chiama la messa in coda |
| R-221 | Lo swipe per la coda si ferma a circa 3/5 della larghezza della riga: la riga non scorre oltre (comportamento nuovo, non un bug) | I | test widget: trascinando oltre il bordo, lo spostamento della riga non supera il 60 % della larghezza |
| R-222 | Selezione multipla: le righe dei brani (locali e online) mostrano la copertina e la casella di spunta sopra la copertina, non più in una colonna a parte (D-550) | I | test widget: in modalità selezione la copertina c'è e la casella sta sopra di essa |
| R-223 | `LibraryIsland` segue «Dock e intestazioni sfocati» (`blurredChrome`) come il dock, con lo stesso effetto (sfocatura 20 e `surface2` all'alfa 0,78), estratto in un widget comune | I | test widget: con `blurredChrome` attivo c'è un `BackdropFilter`, spento non c'è |
| R-224 | Editor del tema avanzato: Superficie 1, 2 e 3 hanno un cursore di trasparenza (minimo 20 % di opacità); i controlli di contrasto usano il colore composto sopra lo sfondo; le altre voci restano opache (D-551) | I | test: alfa salvata e riletta da `CustomTheme` per le superfici; sotto il 20 % si ferma al 20 %; il testo resta opaco |
| R-226 | Player di un brano suggerito: i tre pulsanti Scarica, Aggiungi a playlist e Non mi piace sono blocchi con superficie (`surface2`), angoli arrotondati (raggio delle card) e 8 px fra l'uno e l'altro, come nel mockup `docs/storico/refactor/ascolto-quotidiano/mockup/player-suggerito.html` (`.tiles button`, alti 64 px) (D-555) | I | test widget: ogni pulsante di `SuggestedInfo` ha uno sfondo `surface2` con bordo arrotondato; golden aggiornato se c'è |
| R-225 | Versione 1.6.0, CHANGELOG, tag `v1.6.0` e Release (D-553) | I | `gh release view v1.6.0` mostra i pacchetti |

## Architettura
- **Unione (R-211..R-216)**, in `restore_service.dart` (`mergeBackup`) e `backup_merge.dart` (`mergeUserData`):
  - `settings.json` si legge dallo zip e passa da `applySettingsJson` (già filtra `kDeviceBoundKeys`). Prima di applicarlo, `customThemes` si fonde per id con i temi locali. Le impostazioni si applicano dopo la transazione del DB: se il DB fallisce, le impostazioni non cambiano.
  - Le tabelle che non stanno in `user_data.json` (plays, tag, playlist smart, podcast) si leggono dal `codecore.sqlite` del backup, estratto in una cartella temporanea e aperto in **sola lettura** (pacchetto `sqlite3`, già dipendenza di drift). Il codice deve sopportare uno schema più vecchio: legge solo le colonne che esistono (`PRAGMA table_info`). Per tradurre gli id dei brani del backup in id locali si costruisce un `TrackRef` dalla riga `tracks` del backup, come fa `backup_queries.dart:215-219`, e si passa al `TrackResolver`.
  - Senza doppioni: ascolti per `(trackId, playedAt)`; tag per nome (già UNIQUE NOCASE); `track_tags` per coppia; playlist smart per nome e regole; podcast per `feedUrl` (UNIQUE); episodi per `(podcastId, guid)`. Playlist rinominata: si salva l'uuid del backup in una mappa persistente (o nella riga) per riconoscerla alla volta dopo; la scelta tocca all'implementer, purché passi R-216 senza toccare lo schema.
  - Copertine: `mergeUserData` collega anche `coverSource` 0. `TrackUserData` deve allora portare `coverKey` anche senza copertina a mano: nei backup vecchi manca, e lì il ripiego è la `cover_key` della riga del backup nel sqlite. `_coverFileExists` guarda anche `.webp`.
  - Immagine del tema: `createBackup` aggiunge `theme/*` allo zip. Il ripristino la copia in `themeDir()` e riscrive `imagePath` = `themeDir()/<basename>`.
- **Download pubblici (R-217)**: yt-dlp scrive come oggi in una cartella privata di lavoro, e lì `DownloadTagger` e `SafeTagWriter` scrivono i tag. Poi un nuovo metodo Kotlin (canale `codecore/media` esistente, `MediaDeleteBridge`, oppure uno nuovo accanto) pubblica il file con `MediaStore.Audio`: `RELATIVE_PATH = Music/FreeKmusic`, `IS_PENDING` 1→0. Restituisce il percorso finale `/storage/emulated/0/Music/FreeKmusic/<nome>`, che va in `downloads.json`, nella tabella `folders` e in `scanFiles`. La cartella dei download diventa `Music/FreeKmusic` in `_resolveDownloadFolder`, `downloadFolderIdProvider` e `perf_probe.dart`. Le modifiche dei tag dopo il download (`SafeTagWriter`) restano possibili, perché l'app è proprietaria del file MediaStore; se `installFile` fallisce, ripiega su una scrittura via `ContentResolver.openFileDescriptor`. Da verificare sul Mi A3 (Android 11). `stream_promoter.dart` (cache stream → download) usa la stessa pubblicazione. Podcast (`episode_downloader.dart`) fuori.
- **Registro (R-218, R-219)**: `_DayHeader` non dipinge `cc.bg` quando c'è `pageBackdrop`, ma lo stesso sfondo della pagina (il backdrop ritagliato, per esempio con `pageBackdrop` dietro l'intestazione allineato alla pagina). Gli errori: un nuovo `ActivityKind.playback` (o una voce diretta via `ActivityLogNotifier.add`) che ascolta `playerErrorsProvider`; testo localizzato nelle 6 lingue.
- **Swipe (R-220, R-221)**: `SwipeToQueue` riceve una callback, non un id; `OnlineQueueRow` dentro `LiveTrackRow`, le righe della daylist, `online_playlist_screen` e `suggestions_screen` la usano (`enqueueOnline` per i brani online). Limite: il trascinamento si ferma al 60 % (Dismissible non lo permette: un `GestureDetector` orizzontale con offset limitato, oppure un clamp sul `Dismissible`); la soglia per mettere in coda resta 0,3.
- **Selezione (R-222)**: in `TrackRow` e `OnlineSongRow` la `SelectionBox` va in uno `Stack` sopra `CoverImage`; la colonna di 40 px resta per il numero fuori dalla selezione.
- **Sfocatura (R-223)**: un widget `BlurredChrome` (estratto da `bottom_bar.dart:128-148`) usato dal dock e da `LibraryIsland`.
- **Trasparenza (R-224)**: `CustomTheme.withColor` e `fromJson` tengono l'alfa solo per surface1/2/3 (con limite 0x33); `CcColorPicker(allowAlpha: true)` solo su queste tre voci; contrasto con `Color.alphaBlend(surface, bg)`.

## Rischi
| Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|
| L'unione delle impostazioni sovrascrive qualcosa di legato al dispositivo che non sta in `kDeviceBoundKeys` (per esempio `jamBrokers`, cartelle, `downloadFolder`) | rileggere tutte le chiavi di `settings_store.dart` e allargare `kDeviceBoundKeys` dove serve, con un test | dopo l'unione la Jam o la scansione puntano a percorsi dell'altro dispositivo |
| Il sqlite di un backup vecchio ha uno schema diverso | lettura per colonne esistenti, test con un DB di schema v15 | eccezione SQL durante «Unisci» |
| Ascolti doppi se due ascolti diversi hanno lo stesso `playedAt` | chiave `(trackId, playedAt)`: due ascolti nello stesso millisecondo sono lo stesso | — |
| Con lo scoped storage la scrittura dei tag su un file MediaStore fallisce (Android 10/11) | ripiego su `ContentResolver`; prova sul Mi A3 prima del merge | «Tag non scritti» o `EACCES` nei log dopo un download |
| Nome della cartella: sul Motorola esiste già una cartella scritta «FreeKMusic» | la memoria condivisa di Android non distingue le maiuscole: `Music/FreeKmusic` cade nella stessa cartella; verificarlo sul Mi A3 creando «FreeKMusic» prima | due cartelle quasi uguali in `Music/` |
| Superfici trasparenti rendono illeggibili testi su sfondi con immagine | minimo 20 %, contrasto calcolato sul colore composto | avviso di contrasto che non scatta con un'immagine chiara |
| Regressioni dello swipe (gesto di sistema «indietro», scroll verticale) | si tiene il bordo `edge` attuale e la soglia 0,3; test widget | swipe che parte scorrendo in verticale |

## Task
- [ ] 117.1 Unione: impostazioni, temi con immagine, copertine automatiche, playlist senza doppioni (R-211, R-212, R-214, R-216 per playlist e temi). **Area a rischio (backup): `/code-review high`**
  - File: `lib/services/backup/backup_service.dart`, `restore_service.dart`, `user_data.dart`, `lib/data/repositories/backup_merge.dart`, `lib/data/settings/custom_theme.dart` (solo se serve per l'unione dei temi), test in `test/services/backup/` e `test/data/backup_merge_test.dart`
  - Passi: 1) `theme/*` nel backup, ripristino dell'immagine e riscrittura di `imagePath` (completo e unione); 2) `mergeBackup` legge `settings.json`, fonde `customThemes`, applica dopo il DB; rivedere `kDeviceBoundKeys`; 3) copertine con `coverSource` 0 e `.webp`; 4) playlist rinominata riconosciuta alla seconda unione; 5) un test «due volte» che copre tutto ciò che il task tocca
  - Comando mirato: `flutter test test/services/backup/ test/data/backup_merge_test.dart`
  - Fatto quando: i criteri di R-211, R-212, R-214 verdi, e R-216 per playlist, temi, radio e artisti
- [ ] 117.2 Unione: ascolti, tag, playlist smart, podcast dal sqlite del backup (R-213, R-215, R-216 per queste tabelle). **Area a rischio (backup): `/code-review high`**
  - File: nuovo `lib/services/backup/backup_db_reader.dart` (sola lettura, colonne esistenti), `restore_service.dart`, `backup_merge.dart` (o `backup_queries.dart`), `MergeReport` (+ ascolti non collegati), testo del resoconto nell'ARB (6 lingue)
  - Passi: 1) estrarre `codecore.sqlite` in una cartella temporanea e aprirlo in sola lettura; 2) mappa id del backup → id locale con `TrackResolver`; 3) inserimento senza doppioni nella stessa transazione di `mergeUserData`; 4) test con un DB di backup costruito nel test (anche con uno schema senza colonne recenti) e con l'unione ripetuta due volte
  - Comando mirato: `flutter test test/services/backup/ test/data/backup_merge_test.dart`
  - Fatto quando: i criteri di R-213, R-215 e R-216 verdi; prova sul Mi A3: backup fatto lì, poi spostata la cartella della musica (percorsi diversi), «Unisci» due volte, e statistiche, tag, playlist smart, podcast e tema con immagine presenti una volta sola
- [ ] 117.3 Download in `Music/FreeKmusic` via MediaStore (R-217)
  - File: `lib/providers/youtube_providers.dart` (`_resolveDownloadFolder`), `library_providers.dart` (`downloadFolderIdProvider`), `perf_probe.dart`, `lib/services/online/android_yt_dlp_service.dart`, `stream_promoter.dart`, Kotlin accanto a `MediaDeleteBridge.kt` (pubblicazione con `RELATIVE_PATH`/`IS_PENDING`), `SafeTagWriter` solo per il ripiego
  - Passi: 1) download e tag nella cartella privata di lavoro; 2) pubblicazione MediaStore e percorso finale in `downloads.json`, `folders`, `scanFiles`; 3) download già in `Android/data`: nessuno spostamento, continuano a funzionare finché ci sono (D-547); 4) prova sul Mi A3: download, `adb shell ls -l /sdcard/Music/FreeKmusic`, riproduzione, modifica di un tag, «Elimina dal dispositivo»
  - Comando mirato: `flutter test test/services/online/ test/providers/` (solo i file toccati) + `flutter build apk --debug`
  - Fatto quando: il criterio di R-217 sul Mi A3; desktop invariato (test esistenti verdi)
- [ ] 117.4 Ritocchi UI: Registro (sfondo ed errori di streaming), swipe ovunque fino a 3/5, spunta sopra la copertina, sfocatura dell'isola, trasparenza delle superfici, pulsanti del brano suggerito (R-218..R-224, R-226)
  - File: `activity_log_screen.dart`, `activity_log_providers.dart`, `activity_providers.dart`, `track_row.dart` (`SwipeToQueue`, `TrackRow`), `online_song_row.dart`, `online_queue_row.dart`, `daylist_screen.dart`, `online_playlist_screen.dart`, `suggestions_screen.dart`, `bottom_bar.dart`, `library_island.dart`, nuovo widget comune per la sfocatura, `theme_editor_screen.dart`, `custom_theme.dart`, `lib/ui/screens/now_playing/suggested_info.dart` (`_Tile`), ARB (6 lingue) per la voce di errore
  - Passi: uno per requisito, ognuno col suo test widget; lo swipe con un limite al 60 % e la soglia 0,3 invariata
  - Comando mirato: `flutter test <test toccati> test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` + golden se cambiano (`scripts/guardie.sh`)
  - Fatto quando: i criteri di R-218..R-224 e R-226 verdi; prova a vista sul Mi A3 (swipe in daylist e Cerca, selezione, isola sfocata, tema con superfici trasparenti, un brano che non parte con la rete spenta nel Registro)
- [ ] 117.5 Rilascio 1.6.0 (R-225)
  - File: `pubspec.yaml` (1.6.0+8), `CHANGELOG.md`, documenti d'area (`sync-backup-jam.md`, `piattaforme.md`, `ui-e-design.md`), `prossimi-lavori.md`
  - Passi: dopo il merge della PR della fase: tag `v1.6.0` su master e Release dal workflow esistente (come D-544)
  - Fatto quando: `gh release view v1.6.0` con APK, Linux, Windows, macOS

## Tocca a te
- A fine fase, sul Motorola: aggiorna FreeKmusic con l'APK della Release (stessa firma) e rifai «Unisci» col backup di Codecore. Controlla temi, statistiche, copertine, tag, playlist smart e podcast. Poi puoi disinstallare Codecore: i file rimasti nella sua cartella `Android/data` verranno cancellati (D-547).

## Note di deviazione
