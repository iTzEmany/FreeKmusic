# Fase 126 — Libreria leggera: SD, qualità, «Libera spazio», backup

## Obiettivo
Completa la libreria leggera: download e cache sulla scheda SD (sul computer, cartella dei download a scelta), qualità
Alta/Media/Bassa per download e streaming, «Libera spazio» che converte download in brani in streaming, «Tieni offline»
su playlist e album, backup automatico settimanale, sostituzione dei brani in streaming spariti da YouTube. Nessun file
si cancella senza un gesto esplicito (D-598). Fuori: cloud WebDAV (D-588).

## Riferimenti
D-578..D-581, D-588, D-598, D-612, D-613, D-615; specifica [`../feature/feature-libreria-leggera-karaoke-cerca.md`](../feature/feature-libreria-leggera-karaoke-cerca.md)
§ Architettura C («Scheda SD», «Qualità», «Libera spazio», «Backup automatico», «Brani spariti»), RNF-03, rischi F-2, F-5.
Documenti d'area: `../../architettura/libreria-e-dati.md`, `../../architettura/online.md`, `../../architettura/sync-backup-jam.md`,
`../../architettura/piattaforme.md`.

## Mockup
```text
Memoria e streaming (completa)
+--------------------------------------------------+
| Dove tieni la musica          Streaming con cache |
| Cache dello streaming · 1,0 GB                    |
| Memoria per download e cache       Interna      > |
|   (computer: Cartella dei download  ~/Musica  >)  |
| Qualità download                   Alta         > |
| Qualità streaming                  Media (~128) > |
| Pre-carica anche con i dati mobili (fino a 3) [on]|
| Backup automatico   Documenti/Backup · sab 14 nov |
| [ Libera spazio ]                                 |
+--------------------------------------------------+
```

```text
Libera spazio                        Onboarding (aggiunte)
+--------------------------------+   +--------------------------------+
| Libera spazio                  |   | ( ) Streaming con cache        |
| Questi brani diventano in      |   | ( ) Sul dispositivo            |
| streaming: il file si cancella,|   | ( ) Scheda SD                  |
| restano preferiti, playlist... |   |     I download vanno sulla     |
| Non ascoltati da 90 giorni     |   |     scheda (32 GB liberi).     |
| [x] Get Lucky · Daft Punk 9,8MB|   |  (solo se c'è una scheda)      |
| [x] Lisztomania · Phoenix 7,1MB|   | [ ] Backup automatico ogni     |
| [ ] Tutti i download (312) 2,9G|   |     settimana                  |
| [ Libera 25,3 MB ]             |   | [Indietro]          [Avanti]   |
+--------------------------------+   +--------------------------------+
```

## Task
- [x] 126.1 Scheda SD e cartella dei download (R-238, D-579)
  - File: `lib/data/settings/settings_store.dart` (volume o cartella), `lib/providers/youtube_providers.dart`
    (`resolveDownloadFolder`), `android/app/src/main/kotlin/com/codecore/player/MediaPublishBridge.kt` (nome del volume,
    Android 11+), `lib/services/stream/stream_cache.dart` (`inAppSupport` sul volume scelto), voce in «Memoria e
    streaming», scelta «Scheda SD» nell'onboarding (solo con una SD), `test/providers/android_download_publish_test.dart`.
  - Passi: 1. test prima: risoluzione della cartella con un volume SD finto (Android 10: cartella dell'app sulla SD;
    11+: `Music/FreeKmusic` sul volume) e cartella scelta sul computer; 2. volumi da `getExternalStorageDirectories`;
    3. sul computer `file_picker` (cartella), aggiunta anche come cartella della libreria; 4. su Android 10 la voce dice
    che i file spariscono disinstallando.
  - Comando mirato: `flutter test test/providers/android_download_publish_test.dart test/ui/onboarding_test.dart test/ui/architecture_test.dart` (più `flutter analyze`), `flutter build apk --debug` (con `JAVA_HOME`)
  - Fatto quando: test verdi; senza SD la voce e la scelta d'onboarding non compaiono sul Mi A3; con una SD (se c'è)
    un download finisce sul volume SD.

- [x] 126.2 Qualità download e streaming (R-239, D-580)
  - File: `lib/services/online/yt_dlp_args.dart` (`downloadChoice` col livello), `android/app/src/full/kotlin/com/codecore/player/NewPipeUrl.kt`
    (`:45`, flusso con `averageBitrate` sotto il tetto), impostazioni e due voci in «Memoria e streaming», ARB,
    `test/services/online/yt_dlp_args_test.dart`.
  - Passi: 1. test prima: formato per Alta (come oggi), Media (`bestaudio[abr<=128]/bestaudio`), Bassa
    (`bestaudio[abr<=64]/worstaudio`); 2. provare le stringhe su yt-dlp (Linux) e youtubedl-android (Mi A3), annotare
    gli scarti; 3. NewPipe: livello passato dal canale.
  - Comando mirato: `flutter test test/services/online/yt_dlp_args_test.dart` (più `flutter analyze`), `flutter build apk --debug`
  - Fatto quando: test verdi; sul Mi A3 con «Bassa» un download pesa circa metà della «Media» e il log del flusso
    mostra un bitrate ≤ 64 kbps.

- [x] 126.3 «Libera spazio» (R-240, D-581, RNF-03) — `/code-review high`
  - File: `lib/data/repositories/track_repository.dart` (`demoteToStream(id, key)`), `lib/services/online/download_index.dart`,
    `lib/ui/screens/memory/free_space_screen.dart` (nuovo), voce in «Memoria e streaming», ARB, test in `test/data/track_repository_test.dart`
    e `test/ui/free_space_screen_test.dart` (nuovo).
  - Passi: 1. test prima: la conversione tiene id, playlist, ascolti, preferito e testi, scrive `path = stream:<chiave>`,
    `kind = 2`, `saved = true`, e cancella il file **dopo** la riga; i file non scaricati dall'app non compaiono; in cima
    i non ascoltati da 90 giorni; 2. cancellazione con `MediaDeleteBridge.kt` su Android 11+.
  - Comando mirato: `flutter test test/data/track_repository_test.dart test/ui/free_space_screen_test.dart test/data/stream_rows_hidden_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; sul Mi A3 un brano convertito resta nella playlist con la nuvola e suona in streaming.

- [x] 126.4 «Tieni offline» e brani spariti da YouTube (R-236, R-242, D-578, D-588) — `/code-review high` (scrive su `tracks`)
  - File: menu di playlist e album (`lib/ui/widgets/track_actions.dart` o dove stanno i menu delle raccolte), gestione
    di `YtErrorKind.unavailable` (`lib/services/online/youtube_service.dart`) con `searchRow` sotto `budgetedYtm`,
    voce nel registro attività, test in `test/providers/` e `test/services/online/`.
  - Passi: 1. test prima: «Tieni offline» accoda solo i brani senza file; con un catalogo finto «non disponibile» →
    nuova chiave sulla stessa riga salvata (titolo, artista, durata ±2 s) e voce nel registro; fuori tolleranza solo la voce;
    2. modifiche (solo righe salvate).
  - Comando mirato: `flutter test <test nuovi> test/ui/track_actions_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi.

- [x] 126.5 Backup automatico settimanale (R-241, D-588, F-5) — `/code-review high`
  - File: `isBackupDue(lastAt, now)` accanto a `lib/services/releases/check_schedule.dart`, `lib/providers/startup_providers.dart`
    (all'avvio e a `onResume`), `lib/services/backup/backup_service.dart`, impostazioni (cartella, ultimo backup), voce in
    «Memoria e streaming», interruttore nell'onboarding (spento di partenza; acceso apre la scelta della cartella),
    `test/services/backup/backup_service_test.dart`.
  - Passi: 1. test prima con orologio finto: a 7 giorni nasce uno zip, il quarto più vecchio si cancella, lo zip appena
    scritto mai; a 6 giorni niente; 2. cartella da `file_picker`; verificare su Android 11+ se serve SAF (annotare);
    3. un errore va nel registro, mai muto.
  - Comando mirato: `flutter test test/services/backup/backup_service_test.dart test/services/releases/check_schedule_test.dart test/ui/onboarding_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; sul Mi A3 con la data spostata di 8 giorni (pref) all'avvio compare un nuovo
    `freekmusic-backup-*.zip` nella cartella scelta.

## Tocca a te
- Se hai una scheda SD, mettila nel Mi A3 prima del task 126.1 e dimmelo; senza, la prova sulla SD si salta.
- Se vuoi, ascolta un brano in «Bassa» e dimmi se la qualità è accettabile.

## Note di deviazione

- **126.4, «Libera spazio» sui download vecchi** (16 nov): i download precedenti alla fase 126 o ripristinati da un backup non hanno firma in `downloads.sig.json` e non vengono offerti (D-598). Provare l'id dai tag non serve: i nostri download non lo scrivono (niente `--embed-metadata`). Restano eliminabili uno per uno dal menu del brano, «Elimina dal dispositivo».
- **126.2, prova di yt-dlp su Linux** (video `dQw4w9WgXcQ`, 16 nov): Alta `bestaudio[ext=m4a]/bestaudio/best` -> 140 (m4a, abr 129,5);
  Bassa `bestaudio[abr<=64]/worstaudio` -> 250 (opus, abr 61). Con il tetto 128 la Media cadeva su 250 (come la Bassa, perche
  l'AAC e 129,5): tetto portato a 135, Media `bestaudio[abr<=135]/bestaudio` -> 251 (opus, abr 128,9; yt-dlp preferisce Opus all AAC a pari bitrate, 140 qualifica comunque). Da provare su youtubedl-android (Mi A3).
- **126.5, cartella del backup su Android** (16 nov): `file_picker` usa SAF e restituisce un percorso di file, ma il manifest non ha `MANAGE_EXTERNAL_STORAGE`: su Android niente selettore. Cartella fissa `/storage/emulated/0/Documents/FreeKmusic` (Android 11+ permette la scrittura con `dart:io` in `Documents/`); se la creazione è rifiutata (Android 10 e prima) si ripiega sulla cartella esterna dell'app (`.../files/backups`), che sparisce con la disinstallazione (lo dice il testo dell'impostazione). Sul desktop resta il selettore. I backup automatici si chiamano `freekmusic-auto-<data>.zip` (mai toccati i manuali); si scrive in `<nome>.part` e si rinomina a fine lavoro; dopo un errore si riprova solo al prossimo avvio; errore nel Registro con il dettaglio e in `AppLog`; niente backup durante l'onboarding.
