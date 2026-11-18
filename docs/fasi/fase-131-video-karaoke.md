# Fase 131 — Video karaoke in Cerca e nel player

## Obiettivo
In Cerca un filtro «Karaoke» trova i video karaoke di YouTube; per i brani karaoke in streaming il player mostra il
video muto e sincronizzato al posto di copertina e anello, e l'audio (la base) parte solo quando il video è pronto.
Sotto, solo i testi sincronizzati. Fuori: video nella Jam, video offline, qualità a scelta, variante lite.

## Riferimenti
D-631..D-639, D-646..D-649, D-651, D-653..D-655, D-658. Specifica: [`../storico/feature/feature-karaoke-video-e-aggiornamenti.md`](../storico/feature/feature-karaoke-video-e-aggiornamenti.md)
(§ Architettura A–E, rischi F-1..F-6, F-9). Mockup: [`../storico/feature/mockup-karaoke-video-e-aggiornamenti.html`](../storico/feature/mockup-karaoke-video-e-aggiornamenti.html).
Documenti d'area: `../architettura/online.md`, `riproduzione-e-coda.md`, `ui-e-design.md`, `piattaforme.md`.

## Mockup
```text
Cerca                               Player (brano karaoke)
+------------------------------+    +------------------------------+
| [Q hello adele             ] |    | +--------------------------+ |
| Tutte|YT Music|YouTube|[Kar.]|    | |  VIDEO 16:9 muto          | |  <- al posto di copertina+anello
| [thumb] Adele - Hello (Kar.) |    | |  Hello, it's me ...       | |     tocco = schermo intero
|         Sing King · 4:56     |    | +--------------------------+ |
| [thumb] Hello | Karaoke w/ L |    | Adele - Hello (Karaoke V.)   |
|         KaraFun · 4:58       |    | Sing King                    |
+------------------------------+    | ----o--------------  1:43    |  <- barra di D-156
                                    |   |<<    ( > )    >>|        |  <- niente microfono AI
In attesa: riquadro con «Carico     | Testo sincronizzato          |
il video…», play con indicatore;    |  Hello, it's me              |
errore: copertina+anello e avviso   +------------------------------+
«Video non disponibile: suona solo la base.»
```

## Task
- [ ] 131.0 `master` di nuovo verde (D-658)
  - Il check «Analyze and test» è rosso dal push di #198 per un solo test: `test/goldens/screens_golden_test.dart` «phone_150 settings». Se la differenza viene da una modifica voluta (Impostazioni del karaoke, Android 10), rigenera il golden come fa il progetto (vedi il test e `docs/architettura/qualita-e-rilascio.md`); altrimenti correggi il codice.
  - Comando mirato: `flutter test test/goldens/screens_golden_test.dart`
  - Fatto quando: il test è verde in locale e nella CI della PR.
- [ ] 131.1 Pacchetto video e misura dell'APK (D-637, F-1)
  - File: `pubspec.yaml` (`media_kit_video: 2.0.1`, `media_kit_libs_android_video`, `media_kit_libs_windows_video` al posto di `media_kit_libs_windows_audio`; macOS: `media_kit_libs_macos_video` o il meta-pacchetto `media_kit_libs_video` 1.0.7), `docs/architettura/piattaforme.md`.
  - Passi: 1) misura l'APK full e lite di `master` (`flutter build apk --release --split-per-abi`, flavor come in `release.yml`); 2) aggiungi i pacchetti; 3) escludi le librerie video dalla variante lite (Gradle, `packaging.jniLibs.excludes` per flavor, D-654) e controlla che la lite si avvii; 4) rimisura. **Se la full cresce di oltre 25 MB per ABI: prosegui e annota la misura** (D-653), decide l'utente; 5) `flutter build linux` e avvio: l'audio suona come prima.
  - Comando mirato: `flutter analyze`; build con `sorveglia.sh --pesante`.
  - Fatto quando: le misure prima/dopo per ABI (full e lite) sono nelle «Note di deviazione»; la lite non cresce; analyze pulito; audio su Linux invariato.
- [ ] 131.2 Filtro «Karaoke» in Cerca (R-251, R-252, R-253; D-631, D-646)
  - File: `lib/services/online/karaoke_filter.dart` (nuovo: `karaokeResults`, lista dei canali noti, parole escluse), `lib/ui/screens/youtube/online_results_sections.dart` (`SourceFilterChips` a quattro casi), `lib/ui/screens/youtube/online_results.dart` (`_search` con «<q> karaoke» e solo la fonte `ytVideo`; i primi tre filtri restano lato client), `lib/services/online/smart_search.dart` (richiesta con le sole fonti scelte, se non c'è già), ARB ×6.
  - Comando mirato: `flutter test test/services/online/karaoke_filter_test.dart test/ui/online_results_test.dart test/services/online/smart_search_test.dart`
  - Fatto quando: test di filtro e ordinamento; widget test del blocco (assente con `kEnableYoutube` falso) e della query inviata; tocco → `playOnline`.
- [ ] 131.3 Riconoscimento e indirizzo del video (R-258, R-262, R-263; D-634, D-635)
  - File: `lib/services/karaoke_video/karaoke_video.dart` (`isKaraokeVideo(Track)`, id dalla chiave), `android/app/src/full/kotlin/com/codecore/player/NewPipeUrl.kt` (`videoUrl`: `getVideoOnlyStreams`, MPEG-4/avc1, altezza più vicina a 360 e ≤ 480), `YtDlpChannel.kt` (metodo `videoUrl`), `src/lite/.../YtDlpChannel.kt` (non implementato), `lib/services/online/android_yt_dlp_service.dart`, `lib/services/online/yt_dlp_args.dart` (formato solo video `bv*[height<=480][vcodec^=avc1]/bv*[height<=480]/wv`), `lib/providers/karaoke_providers.dart` (`karaokeButtonVisibleProvider` falso per un video karaoke).
  - Comando mirato: `flutter test test/services/karaoke_video/karaoke_video_test.dart test/services/online/yt_dlp_args_test.dart test/services/online/android_yt_dlp_stream_url_test.dart test/providers/karaoke_providers_test.dart`
  - Fatto quando: `isKaraokeVideo` vero solo per streaming YouTube con «karaoke» nel titolo (falso per file locali); argomenti e scelta del flusso ≤ 480p testati; microfono nascosto.
- [ ] 131.4 Player video, sincronia, attesa dell'audio, cache (R-255, R-259, R-260, R-275, R-276, R-277; D-646, D-647, D-649, D-651) — **area a rischio: review Opus** (gestore audio)
  - File: `lib/services/karaoke_video/karaoke_video_controller.dart` (player media_kit senza audio, `syncStep` puro, ciclo di vita, nuova risoluzione e stato `failed`), `lib/providers/karaoke_video_providers.dart`, `lib/services/audio/codecore_audio_handler.dart` (aggancio «video pronto» prima di `play()`: 10 s all'avvio, 3 s dopo un seek; nullo per gli altri brani), `lib/services/stream/stream_preparer.dart` / `stream_cache.dart` (download solo video con chiave `karaoke:video:youtube:<id>`, `pin` mentre suona, scadenza 15 min su tutte le piattaforme, precarico della coda manuale con `prefetchOnMobile`), `lib/main.dart` (`MediaKit.ensureInitialized` alla prima creazione su Android/macOS).
  - Comando mirato: `flutter test test/services/karaoke_video/ test/services/stream/ test/services/audio/` (solo i file toccati)
  - Fatto quando: test di `syncStep` (scarto > 300 ms → seek, max uno ogni 2 s, seek utente sempre); ciclo di vita finto (paused → pausa, resumed → seek+play); due errori → `failed` senza toccare l'audio; gestore: nessun `play()` prima del via, via dopo 10 s senza video, brano normale senza attesa; cache: scadenza a 15 min con orologio finto, file in riproduzione tenuto, precarico solo per i karaoke della coda manuale.
- [ ] 131.5 Riquadro nel player e schermo intero (R-254, R-256, R-257, R-264)
  - File: `lib/ui/widgets/karaoke_video_view.dart` (nuovo), `lib/ui/screens/now_playing/now_playing_screen.dart` (`_PlayerCover`, figlio dello Stack `:549-574`), `lib/ui/screens/now_playing/karaoke_video_fullscreen.dart` (nuovo: `SystemChrome` orizzontale e immersivo su Android, ripristino all'uscita), ARB ×6 («Video karaoke», «Carico il video…», «Video non disponibile: suona solo la base.»).
  - Comando mirato: `flutter test test/ui/now_playing_test.dart test/ui/karaoke_video_view_test.dart test/ui/now_playing_reduce_motion_test.dart`
  - Fatto quando: brano karaoke → riquadro e niente `RingProgress`; brano normale, YTM o locale → `RingProgress` (regressione F-9); seek dalla barra → seek del video; tocco → schermo intero, Indietro → player e orientamento di prima; semantica «Video karaoke».
- [ ] 131.6 Testi sincronizzati per i karaoke (R-261)
  - File: `lib/services/online/query_cleaner.dart` (`karaokeLyricsQuery`), `lib/services/online/lyrics_chain.dart` (`ignoreDuration`), `lib/services/online/lrclib_client.dart` (durata `null` in `_validated` su quel percorso).
  - Comando mirato: `flutter test test/services/online/query_cleaner_test.dart test/services/online/lyrics_chain_test.dart test/services/online/lyrics_sources_test.dart`
  - Fatto quando: «Sing King - Adele - Hello (Karaoke Version)» → «Adele» / «Hello»; un karaoke con durata diversa trova il testo da `/search`; per gli altri brani la durata vale come prima.
- [ ] 131.7 Prove sul dispositivo (rischi F-2, F-3: D-648) e area
  - Mi A3 collegato via USB con le cuffie JBL (D-655), via adb, **volume 0** (pausa a volume zero spenta), build debug full: Cerca → Karaoke → un brano di Sing King; 3 minuti di riproduzione con spostamenti, schermo spento e riacceso, schermo intero.
  - Verifiche: `adb shell dumpsys audio` senza perdita del focus di FreeKmusic quando parte il video (F-2); nel log (`AppLog`) al massimo un riallineamento ogni 10 s (F-3); risoluzione del flusso ≤ 480p nel log; video in cache e cancellato dopo 15 min.
  - Linux: `flutter run -d linux`, stesso percorso; il riquadro non è nero (F-4).
  - A fine fase: aggiorna `../architettura/online.md`, `riproduzione-e-coda.md`, `ui-e-design.md`, `piattaforme.md` e la colonna «Fase» della specifica. Ripulisci il telefono (app di debug come trovata, file temporanei, screenshot cancellati).
  - Fatto quando: le verifiche sopra sono nelle «Note di deviazione», con i numeri.

## Tocca a te
- Provare a cantare un paio di brani sul telefono e dire se il video è a tempo con la base.
- Windows: controllare che l'audio suoni ancora dopo il cambio delle librerie (F-5); di notte vale solo la CI (D-660).
- Se l'APK è cresciuto oltre 25 MB per ABI (D-653): decidere se tenerlo o passare a `video_player` su Android.

## Note di deviazione

### 131.1 Misura dell'APK (D-637, D-653, D-654)
`release.yml`: full = `flutter build apk --release --split-per-abi`; lite = `CODECORE_LITE=1` + `--dart-define=CODECORE_YOUTUBE=false` (la lite è una variabile d'ambiente, non un flavor Gradle). MB = 10^6 byte. «Prima» = `master` (fa1902ac) senza pacchetto video, «dopo» = con `media_kit_video` e `media_kit_libs_android_video`. La Release v1.6.2 (full 84,1 / 76,3 MB, lite 29,4 / 28,2 MB) non è confrontabile: da allora è entrata la separazione karaoke con onnxruntime.

| Variante | ABI | Prima | Dopo | Differenza |
|---|---|---|---|---|
| lite | arm64-v8a | 40,19 | 40,19 | +0,00 |
| lite | armeabi-v7a | 38,10 | 38,11 | +0,01 |
| full | arm64-v8a | circa 94,9 (stima) | 100,62 | circa +5,7 |
| full | armeabi-v7a | circa 86,2 (stima) | 91,66 | circa +5,5 |

Il «prima» della full è stimato togliendo dal «dopo» `libmpv.so` e `libmediakitandroidhelper.so` compressi (5,72 e 5,49 MB): la build di controllo di `master` è stata uccisa da Gradle (daemon sparito). Sotto la soglia di 25 MB per ABI. La lite esclude `**/libmpv.so` e `**/libmediakitandroidhelper.so` (`packaging.jniLibs.excludes` se `CODECORE_LITE=1`) e non li contiene (verificato con `unzip -l`). Per macOS è stato scelto `media_kit_libs_macos_video` (non compilato di notte).
