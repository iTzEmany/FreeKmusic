# Fase 131 — Video karaoke in Cerca e nel player

## Obiettivo
In Cerca un filtro «Karaoke» trova i video karaoke di YouTube; per i brani karaoke in streaming il player mostra il
video muto e sincronizzato al posto di copertina e anello, e l'audio (la base) parte solo quando il video è pronto.
Sotto, solo i testi sincronizzati. Fuori: video nella Jam, video offline, qualità a scelta, variante lite.

## Riferimenti
D-631..D-639, D-646..D-649, D-651. Specifica: [`../storico/feature/feature-karaoke-video-e-aggiornamenti.md`](../storico/feature/feature-karaoke-video-e-aggiornamenti.md)
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
- [ ] 131.1 Pacchetto video e misura dell'APK (D-637, F-1)
  - File: `pubspec.yaml` (`media_kit_video: 2.0.1`, `media_kit_libs_android_video`, `media_kit_libs_windows_video` al posto di `media_kit_libs_windows_audio`; macOS: `media_kit_libs_macos_video` o il meta-pacchetto `media_kit_libs_video` 1.0.7), `docs/architettura/piattaforme.md`.
  - Passi: 1) misura l'APK full e lite di `master` (`flutter build apk --release --split-per-abi`, flavor come in `release.yml`); 2) aggiungi i pacchetti; 3) rimisura. **Se cresce di oltre 25 MB per ABI: fermati e chiedi all'utente** (D-637); 4) `flutter build linux` e avvio: l'audio suona come prima.
  - Comando mirato: `flutter analyze`; build con `sorveglia.sh --pesante`.
  - Fatto quando: le misure prima/dopo per ABI sono nelle «Note di deviazione»; analyze pulito; audio su Linux invariato.
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
  - Mi A3 via adb, **volume 0** (pausa a volume zero spenta), build debug full: Cerca → Karaoke → un brano di Sing King; 3 minuti di riproduzione con spostamenti, schermo spento e riacceso, schermo intero.
  - Verifiche: `adb shell dumpsys audio` senza perdita del focus di FreeKmusic quando parte il video (F-2); nel log (`AppLog`) al massimo un riallineamento ogni 10 s (F-3); risoluzione del flusso ≤ 480p nel log; video in cache e cancellato dopo 15 min.
  - Linux: `flutter run -d linux`, stesso percorso; il riquadro non è nero (F-4).
  - A fine fase: aggiorna `../architettura/online.md`, `riproduzione-e-coda.md`, `ui-e-design.md`, `piattaforme.md` e la colonna «Fase» della specifica. Ripulisci il telefono (app di debug come trovata, file temporanei, screenshot cancellati).
  - Fatto quando: le verifiche sopra sono nelle «Note di deviazione», con i numeri.

## Tocca a te
- Provare a cantare un paio di brani sul telefono e dire se il video è a tempo con la base.
- Windows: controllare che l'audio suoni ancora dopo il cambio delle librerie (F-5); la CI compila ma non ascolta.

## Note di deviazione
