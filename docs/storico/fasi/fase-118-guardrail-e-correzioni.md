# Fase 118 — Guardrail e correzioni

## Obiettivo
Dopo le prove dell'11/11 (Motorola, Linux con il .deb di un amico, Release Linux con `Liked_Songs.csv`), l'app deve funzionare anche per chi non configura niente. Ogni dispositivo ha una cartella predefinita creata da FreeKmusic, l'onboarding non si salta e yt-dlp c'è sempre. Gli errori dicono la verità e i tag si scrivono anche sui brani con più artisti. Un'importazione riprende da sola e mostra a che punto è. Comprende i download pubblici in `Music/FreeKmusic` (prima R-217 della vecchia fase 118).
Fuori: i ritocchi di UI e la 1.6.0 (fase 119), lo spostamento dei download già in `Android/data` (D-547).

## Riferimenti
- Decisioni D-547, D-554 (MediaStore), D-557..D-566.
- Aree: [`piattaforme.md`](../architettura/piattaforme.md), [`online.md`](../architettura/online.md), [`libreria-e-dati.md`](../architettura/libreria-e-dati.md), [`ui-e-design.md`](../architettura/ui-e-design.md).
- Diagnosi dell'11/11 in breve:
  - yt-dlp rotto nelle APK release per R8 (corretto nella 1.5.1, D-557);
  - il .deb e lo zip Linux non includono yt-dlp e il .deb non lo dichiara: senza yt-dlp nel PATH, o con quello vecchio di apt, i download falliscono;
  - l'arricchimento resta spento se si salta l'onboarding (`autoEnrich`, `autoLyrics`, `autoCuriosities`, `creditsDetails` falsi in `settings_store.dart` 43, 413-419);
  - i download di un'importazione sono nascosti dalle attività (`activity_providers.dart` ~232) e arrivano nel Registro solo a fine download;
  - dopo un riavvio i blocchi dell'importazione restano in pausa;
  - i brani con più artisti restano senza tag nel file (`safe_tag_writer.dart:82`: la verifica cerca il primo artista nella lista intera);
  - gli errori interni del canale yt-dlp diventano «YouTube è cambiato» (`ytExceptionFromStderr`, `android_yt_dlp_service.dart` ~217) e si ritentano;
  - su Linux senza il portale dei file, «Scegli file» gira all'infinito (`import_intro_sheet.dart:62`, file_picker_linux solo via portale).

## Requisiti
| ID | Requisito | Pri | Criterio di accettazione |
|---|---|---|---|
| R-217 | I download nuovi su Android vanno in `Music/FreeKmusic` via MediaStore, leggibili da altre app, adb e MTP (dalla vecchia fase 118) | I | sul Mi A3: un brano scaricato compare in `/sdcard/Music/FreeKmusic` con `adb shell ls -l`, si riproduce, ha i tag; «Elimina dal dispositivo» lo cancella |
| R-227 | Cartella predefinita su ogni dispositivo: Android `Music/FreeKmusic`; Linux, Windows, macOS la cartella Musica del sistema come libreria e `Musica/FreeKmusic` per i download (D-560); iOS la cartella documenti dell'app. FreeKmusic la crea se manca | I | test: il risolutore della cartella dà il percorso giusto per piattaforma (Linux da `XDG_MUSIC_DIR`/`xdg-user-dir MUSIC` con ripiego `~/Music`, Windows `%USERPROFILE%\Music`, macOS `~/Music`); la cartella viene creata |
| R-228 | All'avvio, se la libreria non ha nessuna cartella, l'app aggiunge quella predefinita e la scansiona (D-562) | I | test: avvio con tabella `folders` vuota → una riga con la cartella predefinita |
| R-229 | Onboarding non saltabile: niente «Salta»; si chiude solo con l'ultimo passo. Chi l'aveva saltato lo vede una volta al prossimo avvio (D-562) | I | test widget: nessun pulsante «Salta»; con la preferenza «onboarding fatto» assente l'onboarding parte |
| R-230 | Arricchimento automatico acceso di partenza (le quattro opzioni automatiche), spegnibile nell'onboarding (D-561) | I | test: `AppSettings` di partenza con le quattro opzioni vere; le preferenze già salvate non cambiano |
| R-231 | Desktop: se yt-dlp manca o è più vecchio di una soglia, l'app scarica da sola la sua copia con l'aggiornatore esistente, all'avvio o al primo uso, e lo dice nelle attività (D-563) | I | test: `locateYtDlp` senza candidati → parte il download gestito; versione vecchia → aggiornamento; errore di rete → avviso con «Riprova» |
| R-232 | Gli errori interni del canale yt-dlp (classe Java, inizializzazione, `PlatformException` che non viene da stderr di yt-dlp) hanno un tipo proprio: niente ritentativi e niente messaggio «YouTube è cambiato» | I | test: un `PlatformException(YTDLP, 'java.lang.NoClassDefFoundError: il0')` dà il tipo nuovo; uno stderr «Sign in to confirm» resta come oggi |
| R-233 | I tag si scrivono anche sui brani con più artisti: la verifica dopo la scrittura confronta ciò che è stato scritto (primo artista come artista dell'album) | I | test: brano «Tinariwen, Matt Sweeney, Alain Johannes» → file con titolo, artista e album; nessun `verifyFailed` |
| R-234 | Linux: se il selettore file non risponde (manca il portale), dopo un tempo breve compare un errore chiaro con cosa installare (`xdg-desktop-portal-gtk` o `-kde`), non una rotella infinita | U | test con un selettore finto che non risponde → messaggio; il caso normale invariato |
| R-235 | Un'importazione interrotta (app chiusa) riprende da sola al riavvio (D-564) | I | test: blocchi in pausa per chiusura dell'app → all'avvio tornano in coda; una pausa voluta dall'utente resta pausa |
| R-237 | Immagine dell'artista scelta a mano, come per album e playlist: stesso foglio e stesse fonti, ripristino dell'immagine automatica, nel backup e nell'unione se lo sono le copertine a mano di album e playlist (D-566) | I | test: dopo la scelta la pagina e le card dell'artista mostrano l'immagine nuova, anche dopo un riavvio; «ripristina» torna all'automatica; backup e unione la portano |
| R-236 | Avanzamento di un'importazione: nelle attività in corso «Importazione <playlist>: N di M»; nel Registro una sola riga che si aggiorna fino alla fine (D-565) | I | test: durante l'importazione l'attività ha N e M giusti; il Registro ha una riga, aggiornata, non una per blocco |

## Architettura
- **Cartella predefinita (R-217, R-227, R-228)**: un solo punto che risolve la cartella per piattaforma, al posto di `defaultMusicDir()` (`lib/core/platform.dart:18-21`) e dei tre calcoli della cartella dei download (`_resolveDownloadFolder` in `youtube_providers.dart:108-126`, `downloadFolderIdProvider` in `library_providers.dart:160-172`, `perf_probe.dart`). Android: download in una cartella privata di lavoro (yt-dlp e `SafeTagWriter` hanno bisogno di un percorso), poi pubblicazione con `MediaStore.Audio` (`RELATIVE_PATH = Music/FreeKmusic`, `IS_PENDING`) da Kotlin accanto a `MediaDeleteBridge.kt`; il percorso finale va in `downloads.json`, `folders` e `scanFiles` (D-554). Desktop: `Musica` come cartella della libreria, `Musica/FreeKmusic` creata per i download. L'aggiunta all'avvio sta dove oggi `addDefaultFolderAndScan` (`folder_actions.dart:27-31`).
- **Onboarding (R-229, R-230)**: `onboarding_pages.dart` (interruttore a 274): niente «Salta». I valori di partenza in `settings_store.dart` cambiano solo per chi non li ha mai salvati.
- **yt-dlp sul desktop (R-231)**: `locateYtDlp` (`yt_dlp_update_providers.dart:18`) e `YtDlpUpdateNotifier` (oggi solo col pulsante). Soglia di «troppo vecchio»: un'età (per esempio 90 giorni dalla data della versione), non un numero fisso.
- **Errori (R-232)**: `ytExceptionFromStderr` e il messaggio del canale Kotlin (dalla 1.5.1 contiene `| root: <classe>: <messaggio>`); `retry_policy.dart:27` non ritenta il tipo nuovo.
- **Tag (R-233)**: `SafeTagWriter._write` (`safe_tag_writer.dart:61-88`) e `DownloadTagger._write` (`download_tagger.dart:96-132`): la verifica deve confrontare il valore effettivamente scritto.
- **Importazione (R-235, R-236)**: `playlist_import_service.dart` (stato dei blocchi in `playlist_imports.status`), `activity_providers.dart` (~232, oggi nasconde i download con il tag dell'importazione), `activity_log_providers.dart` (`groupLog` :191, `_record` :340). Si distingue la pausa dell'utente dalla chiusura dell'app.
- **Selettore file (R-234)**: `import_intro_sheet.dart:62` e gli altri punti che aprono il selettore su Linux, con un timeout.

## Rischi
| Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|
| Scrittura dei tag su un file MediaStore negata (Android 10/11) | ripiego su `ContentResolver`; prova sul Mi A3 | «Tag non scritti» o `EACCES` dopo un download |
| Sul Motorola esiste già una cartella scritta «FreeKMusic» | la memoria condivisa di Android non distingue le maiuscole: verificarlo sul Mi A3 creando prima «FreeKMusic» | due cartelle quasi uguali in `Music/` |
| La cartella Musica di Linux non è standard (XDG in un'altra lingua: «Musica») | leggere `XDG_MUSIC_DIR` da `~/.config/user-dirs.dirs` o `xdg-user-dir MUSIC`; ripiego `~/Music` | due cartelle `Music` e `Musica` |
| Un utente con la libreria già configurata vede l'onboarding di nuovo | si mostra solo se la preferenza «onboarding fatto» manca **e** non ci sono cartelle (D-562) | segnalazione di onboarding ripetuto |
| Il download automatico di yt-dlp su una rete lenta blocca il primo uso | in background, con avanzamento nelle attività; la riproduzione locale non aspetta | primo avvio che resta in «Caricamento» |
| Riprendere da sola un'importazione all'avvio consuma rete a sorpresa | rispetta l'impostazione «solo Wi-Fi» se c'è, e la pausa voluta dall'utente | download partiti su rete mobile |
| Regressioni di R8 in altre librerie (NewPipe, Jackson) | prova sul Mi A3 con una build **release**, non debug | `ClassNotFound`, `NoClassDefFoundError` nel logcat |

## Task
- [x] 118.1 Cartella predefinita e download pubblici (R-217, R-227, R-228). **Area a rischio (piattaforme, permessi): `/code-review high`**
  - File: `lib/core/platform.dart`, `lib/providers/youtube_providers.dart`, `library_providers.dart`, `folder_actions.dart`, `lib/services/online/android_yt_dlp_service.dart`, `stream_promoter.dart`, `perf_probe.dart`, Kotlin accanto a `MediaDeleteBridge.kt`
  - Passi: 1) risolutore unico per piattaforma; 2) pubblicazione MediaStore su Android; 3) cartella aggiunta all'avvio se la libreria non ne ha; 4) prova sul Mi A3 con una build release
  - Comando mirato: `flutter test <test toccati>` + `flutter build apk --release --target-platform android-arm64`
  - Fatto quando: i criteri di R-217, R-227, R-228
- [x] 118.2 Onboarding non saltabile e arricchimento acceso (R-229, R-230)
  - File: `lib/ui/screens/onboarding/*`, `lib/data/settings/settings_store.dart`, avvio in `lib/app.dart` o `main.dart`, ARB se cambiano i testi
  - Comando mirato: `flutter test <test toccati> test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart`
  - Fatto quando: i criteri di R-229, R-230
- [x] 118.3 yt-dlp sempre presente ed errori veri; tag dei brani con più artisti; selettore file su Linux (R-231..R-234)
  - File: `lib/providers/yt_dlp_update_providers.dart`, `lib/services/online/android_yt_dlp_service.dart`, `retry_policy.dart`, `yt_dlp_process_service.dart`, `lib/services/tags/safe_tag_writer.dart`, `lib/services/library/download_tagger.dart`, `import_intro_sheet.dart` (selettore), ARB
  - Comando mirato: `flutter test test/services/online/ test/services/tags/ <altri toccati>`
  - Fatto quando: i criteri di R-231..R-234; su Linux, con `PATH` senza yt-dlp e una home finta, un download funziona dopo il download automatico
- [x] 118.4 Importazione che riprende e mostra l'avanzamento (R-235, R-236)
  - File: `lib/services/import/playlist_import_service.dart`, `lib/providers/import_providers.dart`, `activity_providers.dart`, `activity_log_providers.dart`, ARB
  - Comando mirato: `flutter test test/services/import/ test/providers/ <toccati>`
  - Fatto quando: i criteri di R-235, R-236; prova con `Liked_Songs.csv` sulla Release Linux (schermo virtuale, home finta) per almeno 30 minuti, con un riavvio a metà

- [x] 118.5 Immagine dell'artista scelta a mano (R-237)
  - File: pagina e card dell'artista (`lib/ui/screens/artist*`), il foglio delle copertine già usato da album e playlist, dove si salva l'immagine dell'artista (senza cambiare lo schema se si può; altrimenti una sola migrazione), backup e unione se servono, ARB
  - Comando mirato: `flutter test <test toccati> test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart test/l10n/arb_test.dart`
  - Fatto quando: il criterio di R-237

## Tocca a te
- Chiedere al tuo amico, dopo la versione con questa fase, di riprovare il .deb e di mandare «Esporta log» se qualcosa non va.

## Note di deviazione
- D-567: la pubblicazione MediaStore vale solo da Android 11 (API 30); sotto, i download restano nella cartella dell'app come nella 1.5.1.
- Chiave ARB `onboardingSkip` tolta: l'onboarding non ha più «Salta».
- Immagine dell'artista: riga di `artist_infos` con chiave `image:<artistKey>` (esclusa da biografie e Memoria, nessuna migrazione), esportata in `user_data.json` come `artistImages`.
- Tag sui file MediaStore: scritti via `ContentResolver` in sostituzione ("wt"); se fallisce, riga di errore nel Registro. Le righe `IS_PENDING` orfane si tolgono all'avvio.
- yt-dlp desktop: aggiornamento automatico oltre i 90 giorni. Errori «interni» solo per radici di classe JVM (`| root: <classe>`).
- Golden `now_playing` aggiornati: `creditsDetails` parte vero (D-563).
- Verifica su Mi A3: in corso (tag, `Music/FreeKmusic`, build release).
