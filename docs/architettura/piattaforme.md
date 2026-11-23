# Piattaforme

## Scopo
Dove vive il codice nativo (Kotlin, C++/GTK, Swift), come si costruiscono e si pacchettizzano le cinque uscite (Android full/lite, Windows, Linux, macOS) e che cosa il Dart distingue per piattaforma. Serve a sapere dove mettere le mani quando una funzione dipende dal sistema.

## Mappa del codice

### Dart: il confine con la piattaforma
| File | Simbolo | Ruolo |
|---|---|---|
| `lib/core/platform.dart` | `isAndroid`, `isDesktop`, `defaultMusicDir`, `debugIsAndroidOverride`, `debugIsDesktopOverride` | Unico punto per «dove sono». I due `debug…Override` sono `@visibleForTesting`: i test li impostano per provare il percorso Android o il layout telefono su un host Linux. |
| `lib/core/constants.dart` | `kEnableYoutube` | `--dart-define=CODECORE_YOUTUBE=false` per la variante lite. |
| `lib/services/perf/perf_probe.dart` | `kPerfBuild`, `kPerfReal`, `kPerfProbe` | `CODECORE_PERF` e `CODECORE_PERF_REAL`: build di misura (vedi `qualita-e-rilascio.md`). |
| `lib/core/paths.dart` | `appSupportDir`, `databaseFile`, `restoreStagingDir` | Cartelle dati (da `path_provider`). |
| `lib/main.dart` | `main` | Gate per piattaforma: orientamento (Android), `JustAudioMediaKit.ensureInitialized()` (Linux e Windows), `AudioService.init` (Android), `MprisControls` (Linux), `SmtcControls` (Windows), widget e nome dispositivo (Android). |
| `lib/services/audio/system_media_controls.dart` | `SystemMediaControls`, `NoSystemMediaControls` | Interfaccia dei controlli di sistema; `mpris_controls.dart`, `mpris_mapping.dart` (Linux), `smtc_controls.dart` (Windows). |
| `lib/services/audio/media_browse_tree.dart` | `MediaBrowseTree`, `DbBrowseSource` | Albero di Android Auto, sui repository esistenti. |
| `lib/services/android/` | `incoming_files.dart`, `media_deleter.dart`, `release_notifier.dart`, `screen_flag.dart`, `widget_bridge.dart`, `widget_sync.dart` | Lato Dart dei ponti Kotlin. |

Fuori da `lib/services/android/`, i canali Kotlin hanno il loro lato Dart in: `lib/core/system_volume.dart` (volume), `lib/core/network_kind.dart` (rete a consumo), `lib/services/app_icon/app_icon.dart` (icona), `lib/services/memory/disk_space.dart` (spazio), `lib/services/export/save_file.dart` (salva), `lib/services/issue/link_opener.dart` (link), `lib/services/audio/output_route.dart` e `bluetooth_outputs.dart` (uscita), `lib/services/share/share_notifier.dart` (servizio di ricezione), `lib/providers/import_notification_providers.dart` (import), `lib/services/online/android_yt_dlp_service.dart` (yt-dlp), `lib/services/jam/remote/jam_beacon.dart`.

### Android (`android/`)
Il video karaoke usa `media_kit_video` con `media_kit_libs_android_video` (libmpv, circa +5,5 MB per ABI nella full). La lite le esclude in `build.gradle.kts` (`packaging.jniLibs.excludes` di `libmpv.so` e `libmediakitandroidhelper.so` con `CODECORE_LITE=1`, D-654). Su macOS: `media_kit_libs_macos_video`. Le librerie sono solo l'estensione della libmpv per il video: l'audio resta ExoPlayer. La lite (`CODECORE_LITE=1`, `kEnableYoutube` falso) non ha YouTube né video: `videoUrl` non esiste nel canale e `karaokeVideoProvider` non viene letto in `main.dart`.

Codice Kotlin in `android/app/src/main/kotlin/com/codecore/player/` (il pacchetto resta `com.codecore.player`).

| File | Canale / ruolo |
|---|---|
| `MainActivity.kt` | Registra i ponti. Canali propri: `codecore/audio` (`outputRoute`, `bluetoothOutputs`, `netPrefix`, `bluetoothOutputActive`, permessi Bluetooth), `codecore/screen` (`keepOn`), `codecore/share` (`startService`, `stopService`, `showOffer`). |
| `CodecoreApp.kt` | `Application`: vive quanto il processo, ridisegna widget e tile quando Dart scrive un nuovo stato. |
| `IncomingBridge.kt` | `codecore/incoming`: ZIP/CSV aperto con FreeKmusic («Apri con», «Condividi»). Copia nella cache (massimo 20 MB), `takeIncoming`, `takeIncomingText`. Gli App Link `https://itzemany.github.io/FreeKmusic/…` (intent-filter `autoVerify` in `MainActivity`, D-702) arrivano come testo con il `#frammento` (`Uri.toString` lo conserva), all'avvio e con `onNewIntent`. |
| `VolumeBridge.kt` | `codecore/volume`: `get` (0..1), `start`/`stop` di un `ContentObserver` che manda `changed`. Alla base della pausa a volume zero. |
| `IconBridge.kt` | `codecore/icon`: l'icona è uno di 16 `activity-alias` di `MainActivity` (`.IconViolaDark`…). `setIcon` ricorda la scelta, `apply` cambia in background. |
| `NetworkBridge.kt` | `codecore/net`: `isMetered`, evento `changed`. Shuffle+ evita i dati mobili. |
| `StorageBridge.kt` | `codecore/storage`: `diskSpace`, `openFolder`. |
| `SaveFileBridge.kt` | `codecore/save`: copia a flusso verso un file scelto dall'utente. |
| `MediaDeleteBridge.kt` | `codecore/media`: elimina dal dispositivo. |
| `MediaPublishBridge.kt` | `codecore/publish`: `sdk`, `publish` (copia in `Music/FreeKmusic` con `MediaStore.Audio`, `IS_PENDING`, MIME audio, sottocartelle), `replace` (riscrive un file pubblicato con "wt", per i tag). Accetta `volume` (nome MediaStore del volume SD): `publish` fallisce sulla SD se manca `DATA`. Solo da Android 11 (D-567). Dart: `lib/services/online/media_publisher.dart`. |
| `RestartChannel.kt`, `RestartActivity.kt` | `codecore/restart`: `restart` avvia `RestartActivity` nel processo `:restart` con il pid di quello principale; l'activity uccide il processo principale, riapre l'app in un task nuovo ed esce (schema di ProcessPhoenix, senza dipendenze). Un `startActivity` seguito dal kill nello stesso processo lascia l'app chiusa sui telefoni veloci. Dart: `lib/services/restart/app_restart.dart` (fase 137). |
| `UpdateChannel.kt` | `codecore/update`: `abi` (`SUPPORTED_ABIS[0]`), `canInstall`, `openInstallSettings`, `sameSigner(path)`, `install(path)` (`FileProvider` + `ACTION_VIEW`). Dart: `lib/services/update/android_update.dart`. |
| `NotifyBridge.kt` | `codecore/notify`: notifica «Nuove uscite», `takeLaunchTarget`. |
| `LinkBridge.kt` | `codecore/link`: `openUrl`, `deviceInfo`. |
| `JamBeaconBridge.kt` | `codecore/jam_beacon`: annuncio e scansione BLE della Jam a distanza. |
| `ImportService.kt` | Servizio in primo piano per import e download (`ImportBridge`, `codecore/import`, `ImportActionReceiver`). |
| `ReceiveService.kt`, `ShareNotifications.kt`, `ShareActionReceiver.kt` | Servizio in primo piano «ricevi dalla rete locale» e notifiche delle offerte. |
| `NowPlayingWidget.kt` | `NowPlayingWidget4x1`, `NowPlayingWidget2x2`. |
| `PlayTileService.kt` | Tile delle impostazioni rapide. |
| `WidgetStore.kt`, `WidgetActionReceiver.kt`, `MediaKeys.kt` | Stato di widget e tile (preferenze condivise) e tasti media «a freddo». |
| `src/full/kotlin/.../YtDlpChannel.kt`, `NewPipeUrl.kt` | Solo variante full: canale `codecore/ytdlp`, `youtubedl-android`. |
| `src/lite/kotlin/.../YtDlpChannel.kt` | Variante lite: stesso nome, senza yt-dlp. |
| `android/app/build.gradle.kts` | `namespace`, `applicationId`, varianti, firma, minify. |
| `android/app/src/main/AndroidManifest.xml` | Permessi, servizi, widget, tile, `AudioService`, metadati Android Auto. |

### Windows, Linux, macOS
| Percorso | Ruolo |
|---|---|
| `windows/runner/main.cpp` | Crea la finestra «FreeKmusic». |
| `windows/CMakeLists.txt` | Include `-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`. |
| `packaging/windows/freekmusic.iss` | Inno Setup: installa in `{localappdata}\Programs\FreeKmusic`, porta `yt-dlp.exe` e `ffmpeg.exe` e le licenze. |
| `linux/CMakeLists.txt` | `BINARY_NAME "freekmusic"`, `APPLICATION_ID "com.freekmusic.player"`. |
| `linux/runner/my_application.cc` | Finestra GTK «FreeKmusic». |
| `scripts/package-linux.sh`, `scripts/package-appimage.sh` | Zip, `.deb` (`/opt/freekmusic`, `/usr/bin/freekmusic`), AppImage con libmpv. |
| `packaging/linux/freekmusic.desktop`, `packaging/linux/deb/control.in` | Voce di menu e metadati del `.deb`. |
| `packaging/flatpak/com.freekmusic.player.yml` (+ `.desktop`, `.metainfo.xml`, `icon-512.png`) | Manifest Flatpak. |
| `packaging/fdroid/com.freekmusic.player.yml` | Bozza di metadati F-Droid. |
| `macos/Runner/` | `AppDelegate.swift`, `MainFlutterWindow.swift`, `Configs/AppInfo.xcconfig` (`PRODUCT_NAME = freekmusic`, `com.freekmusic.player`), entitlements. |

## Come funziona

### Identità dell'app Android
`namespace = "com.codecore.player"` è solo il pacchetto del codice e della classe `R`. L'`applicationId` è quello che vede il sistema: `com.freekmusic.player` (D-539), oppure `com.freekmusic.player.perf` con `CODECORE_PERF=1`, con dati propri. Un'app con id nuovo è un'app nuova: i dati si portano col backup. Il canale di notifica di `audio_service` è `com.freekmusic.player.audio` (in `main.dart`).

### «Flavor» full / lite / perf
Non sono `productFlavors` di Gradle: sono variabili d'ambiente lette da `build.gradle.kts`.
| Variante | Come | Effetto |
|---|---|---|
| full | predefinita | Sorgenti `src/full/kotlin`; `youtubedl-android` (yt-dlp, Python, QuickJS, ffmpeg) e NewPipeExtractor. |
| lite | `CODECORE_LITE=1` e `--dart-define=CODECORE_YOUTUBE=false` | Sorgenti `src/lite/kotlin`, niente yt-dlp, niente download da YouTube (`kEnableYoutube` falso). Le due metà vanno sempre insieme. |
| perf | `CODECORE_PERF=1` (e `--dart-define=CODECORE_PERF=true`) | `applicationId` `.perf`, etichetta «FreeKmusic Perf». Solo per `scripts/perf_device.py`. |
Le release producono un APK per ABI (`arm64-v8a`, `armeabi-v7a`), `minify` e `shrinkResources` attivi (`proguard-rules.pro`). Senza `android/key.properties` si firma con la chiave di debug.

### La sessione media è l'unico punto di comando
Widget, tile, Android Auto e orologio mandano tasti alla sessione di `audio_service`; non toccano DB o file. Dart scrive titolo, artista, copertina e stato in `FlutterSharedPreferences` (`flutter.widget.*`, tramite `widget_bridge.dart`); `CodecoreApp` ascolta `flutter.widget.stamp` e ridisegna. Non c'è un canale perché il motore avviato da `audio_service` senza attività non ha quelli di `MainActivity`. A freddo `MediaKeys.pressSurely` preme il tasto due volte (R63). L'albero di Android Auto (`MediaBrowseTree`) include i brani in streaming delle playlist: si riproducono se c'è rete (D-674).

### Aggiornamento dall'app per piattaforma (fase 132)
Dettagli in `online.md`; qui solo cosa tocca la piattaforma.
- **Android**: permesso `REQUEST_INSTALL_PACKAGES` e `provider` `androidx.core.content.FileProvider` con autorità `${applicationId}.updates`, che espone solo `cache/updates` (`res/xml/update_paths.xml`). Anche la lite ha l'aggiornamento. In una build F-Droid va spento (firma diversa; nota in `packaging/fdroid/com.freekmusic.player.yml`).
- **Windows**: il setup parte silenzioso con `/CLOSEAPPLICATIONS`; la riga `[Run]` di `freekmusic.iss` con `Check: WizardSilent` riapre l'app. Da provare su Windows: se i figli `yt-dlp.exe`/`ffmpeg.exe` in corso tengono bloccati i file (prova nella 133.3).
- **Linux**: AppImage (`$APPIMAGE` con eseguibile sotto `APPDIR` o `/tmp/.mount_`) si sostituisce da sola; `.deb` si riconosce solo da `/usr/bin/freekmusic`, `/usr/lib/freekmusic/`, `/opt/freekmusic/`; Flatpak da `$FLATPAK_ID`; il resto è lo zip. `.deb`, Flatpak e zip aprono il browser.
- **macOS**: solo browser sullo zip.

### Windows
Backend audio libmpv (`just_audio_media_kit`, librerie `media_kit_libs_windows_video` al posto di `_audio` per il video karaoke, D-637), controlli di sistema SMTC (`smtc_windows`, un crate Rust compilato da cargokit). Il rilascio è un installer Inno Setup con `yt-dlp.exe` e `ffmpeg.exe` (build LGPL) accanto all'app. Nota MSVC: `permission_handler_windows` include `<experimental/coroutine>`, che con MSVC 14.51 dei runner GitHub dà l'errore STL1011; la definizione in `windows/CMakeLists.txt` lo silenzia (PR #163).

### Linux
Backend libmpv, MPRIS (`MprisControls`, percorso `/org/codecore/track/<id>` in `mpris_mapping.dart`). Tre pacchetti: zip e `.deb` da `package-linux.sh`, AppImage da `package-appimage.sh` (copia libmpv e le sue dipendenze, tranne quelle di ogni desktop). Il Flatpak (`org.freedesktop.Platform` 24.08) costruisce da sorgente `libplacebo` 6.338.2 e `libass` 0.17.3 perché mpv 0.38 li richiede e il runtime non li ha, poi `libmpv`; `yt-dlp` è un file fissato per hash; ffmpeg viene dall'estensione `ffmpeg-full`. Permessi: rete, audio (PulseAudio), Wayland/X11, `xdg-music`, `xdg-download`, nome MPRIS `org.mpris.MediaPlayer2.freekmusic`.

### macOS
Il runner Flutter esiste in `macos/` (id `com.freekmusic.player`). `just_audio_media_kit` si inizializza solo su Linux e Windows, quindi su macOS suona il backend nativo di `just_audio`. La CI lo compila con `flutter build macos --debug` nel job `build-apple` (solo a mano). La release (D-543) ha il job `macos`: `flutter build macos --release` e `.app` in zip non firmato (`FreeKmusic-<versione>-macos.zip`), senza yt-dlp né ffmpeg dentro. Niente firma né notarizzazione. Il video karaoke usa media_kit direttamente (`MediaKit.ensureInitialized` alla prima creazione del player video, non in `main.dart`).

### Differenze per piattaforma
| Aspetto | Android | Windows / Linux | macOS |
|---|---|---|---|
| Audio | ExoPlayer | libmpv | nativo di `just_audio` |
| Controlli di sistema | `audio_service` (notifica, schermata di blocco, cuffie) | SMTC / MPRIS | non cablati in `main.dart` |
| Equalizzatore | `AndroidEqualizer` (la voce compare solo se `equalizerProvider` non è nullo) | assente (il filtro `af` di mpv è di `scaletempo`) | non verificato |
| Permessi file | `READ_MEDIA_AUDIO` (`READ_EXTERNAL_STORAGE` fino ad API 32) | nessuno | sandbox |
| Cartelle predefinite (`resolveDefaultFolders`, `lib/core/platform.dart`) | libreria `/storage/emulated/0/Music`, download `Music/FreeKmusic` (MediaStore da Android 11; sotto, cartella dell'app) | Linux: `XDG_MUSIC_DIR` / `xdg-user-dir MUSIC`, ripiego `~/Music`; Windows `%USERPROFILE%\Music`; download in `<Musica>/FreeKmusic` | `~/Music`; iOS: cartella documenti |
| Memoria dei download (D-579) | `effectiveLocation` (`lib/core/storage_volumes.dart`): scheda tolta = interna. Android 11+: `<SD>/Music/FreeKmusic` con MediaStore; Android 10: cartella dell'app sul volume | cartella scelta dall'utente, aggiunta alla libreria | non verificato |
| Backup automatico | `Documents/FreeKmusic` (ripiego: cartella dell'app) | cartella scelta | non verificato |
| Filtro della voce (karaoke, D-603, D-617) | `AudioProcessor` Media3 nella copia di `just_audio` | Linux: `lavfi` di mpv (`af`); Windows: assente (libmpv senza filtri) | assente (anche iOS) |
| Modelli e dizionari (D-673) | traduzione (ML Kit, 20 lingue) e modello karaoke Spleeter: sezioni presenti (`lyricsTranslatorProvider` e `separationServiceProvider` non nulli); dizionario CC-CEDICT presente | solo il dizionario: le sezioni Traduzione e Karaoke non compaiono | come desktop |
| Orientamento | bloccato in verticale, salvo lo schermo intero del video karaoke (orizzontale e immersivo, poi ripristinato) | libero | libero |
| Video karaoke (D-632, D-637) | libmpv da `media_kit_libs_android_video`, nella full (circa +5,6 MB per ABI), assente nella lite | Windows: `media_kit_libs_windows_video`; Linux: libmpv di sistema | `media_kit_libs_macos_video` (compilato solo in CI); iOS: nessuna libreria, non supportato |
| Scoperta in LAN (`discovery.dart`) | senza `reusePort` | `reusePort` solo su Linux | `reusePort` |

## Invarianti da non rompere
- **Android 10: `requestLegacyExternalStorage` (D-630).** Senza il flag la scansione di `Music` fallisce con errno 13 (scoped storage); da Android 11 il flag è ignorato. Le funzioni su file, download e SD si provano anche su Android 10.
- **Nessun `Platform.isX` sparso per nuove funzioni**: usa `isAndroid` e `isDesktop` di `core/platform.dart`, così i test possono forzarli. (Oggi 24 file usano ancora `Platform.is…` direttamente, per lo più in `main.dart` e nei servizi di piattaforma; il nuovo codice non li aumenta.)
- **Nomi dei canali invariati** (`codecore/…`): Dart e Kotlin devono restare allineati; sono parte del filo (vedi `sync-backup-jam.md`).
- **`namespace` resta `com.codecore.player`** finché le classi Kotlin stanno in quel pacchetto: cambiarlo senza spostare i file rompe la `R` e il manifest (`.MainActivity` è relativo al namespace).
- **`applicationId` e `appLabel` dipendono da `perf`**: la build di misura non deve mai poter sovrascrivere l'app vera.
- **La variante lite ha tre parti da tenere insieme**: `CODECORE_LITE=1` (sorgenti `src/lite`, niente yt-dlp, esclusione di `libmpv.so` e `libmediakitandroidhelper.so`), `--dart-define=CODECORE_YOUTUBE=false`, e ogni funzione di YouTube dietro `kEnableYoutube`. Il video karaoke non deve mai poter partire dove la libmpv non c'è.
- **Il cambio dell'icona avviene in background** (`IconBridge.apply`): cambiare l'alias attivo mentre l'utente guarda può far chiudere l'app al launcher.
- **Un nuovo canale usato anche dal servizio senza attività** non può passare da `MainActivity`: va su `FlutterSharedPreferences` come i widget.
- **Nessun lavoro pesante nel thread UI**; sui ponti, risultati rapidi o asincroni.
- **I pacchetti del Flatpak sono fissati** (commit, hash): aggiornarli è una scelta, non un effetto collaterale.

## Come si estende
- **Nuovo ponte Android**: `object XxxBridge` con `register(messenger, context)` in un file nuovo di `main/kotlin/...`, chiamato da `MainActivity.configureFlutterEngine`; lato Dart una classe con `MethodChannel` iniettabile (come `SystemVolume` o `NetworkKind`) e un fake nei test. Nome del canale `codecore/<nome>`.
- **Nuova funzione solo Android**: il Dart passa da `isAndroid`; il test imposta `debugIsAndroidOverride = true`.
- **Nuova funzione solo desktop**: `isDesktop`; il test imposta `debugIsDesktopOverride = false` per vedere il layout telefono.
- **Nuova funzione legata a YouTube**: dietro `kEnableYoutube`, e una versione vuota in `src/lite/kotlin` se tocca `YtDlpChannel`.
- **Permesso audio (fase 135, D-678)**: `lib/core/permissions.dart` chiede `Permission.audio` (Android 13+, `READ_MEDIA_AUDIO`) e `Permission.storage` (prima); `hasAudioPermission` vale se uno dei due è concesso (permission_handler dà negato quello che non esiste in quella versione). Il permesso può sparire senza che l'utente lo tocchi (successo sul Motorola il 21/11): l'handler lo ricontrolla quando un file locale non si apre, e `audioPermissionProvider` a ogni ritorno nell'app. File caricati via adb appartengono alla shell: senza il permesso non si leggono, e i tag non si scrivono comunque (scoped storage).
- **Nuovo permesso Android**: in `AndroidManifest.xml` e nella richiesta runtime lato `MainActivity`; se il servizio è in primo piano, aggiungi il tipo corretto.
- **Nuovo widget o tile**: un `AppWidgetProvider` o `TileService` che legge solo `WidgetStore`; i dati li scrive `widget_sync.dart`.
- **Nuovo pacchetto Linux/Windows**: nuovo script in `scripts/` o `packaging/`, poi un job in `release.yml` (vedi `qualita-e-rilascio.md`).
- **Nuovo identificativo di app**: mai a caso; è una decisione (D-539), perché cambia la cartella dei dati.
- **Database desktop nella cartella dati dell'app**: su Windows, Linux (anche Flatpak, dove Documenti non è raggiungibile) e macOS `databaseFile()` è `<appSupport>/codecore.sqlite`; `databaseDir()` (`lib/core/paths.dart`) è l'unica fonte del percorso, usata anche da `driftDatabase`. Al primo avvio `resolveDatabaseDir` COPIA il vecchio `<Documenti>/codecore.sqlite` (e `-wal`/`-shm`/`-journal`) se il nuovo non esiste, senza toccare l'originale; se la copia fallisce, quell'avvio usa ancora Documenti e riprova al successivo. Su Android e iOS resta la cartella documenti (già privata dell'app).

## Trappole
- **`share_plus` (D-670) solo dietro `ExternalShare`** (`lib/services/share/external_share.dart`, provider `externalShareProvider`): foglio di sistema di Android/Linux/Windows; `origin` ancora il foglio su desktop. Un errore di `share_plus` diventa `ExternalShareUnavailable` e la UI ripiega su «Copia testo»: su Linux `shareText` apre un `mailto:` e `shareFile` non è supportato (`UnimplementedError`), idem Windows prima di 10 RS5. I test usano un finto, mai il canale nativo.
- **`file_picker` passa dal SAF** e non c'è `MANAGE_EXTERNAL_STORAGE`: una cartella scelta a mano non è scrivibile con `dart:io` su Android; per questo i backup vanno in `Documents/FreeKmusic` e i download sulla SD nella cartella dell'app.
- **`flutter build apk` vuole il JDK 17 di JetBrains**: `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=~/.jdks/jbr-17.0.14/bin:$PATH flutter build apk --debug`. Con il Java di sistema Gradle fallisce.
- **`gradlew --stop` di un agente ferma la build di un altro**: due build Gradle in parallelo non si fidano; una alla volta. Dopo un processo interrotto, «Gradle build daemon disappeared unexpectedly»: `cd android && ./gradlew --stop` e si rilancia.
- **Mi A3, APK di debug**: `install -r -d` (col solo `-r` va in VERSION_DOWNGRADE).
- **yt-dlp su Android si aggiorna solo se viene chiamato**: l'aggiornamento parte in `ensureInit()` di `YtDlpChannel.kt` (full). La versione in uso: `run-as <pacchetto> cat shared_prefs/youtubedl-android.xml` (`dlpVersion`).
- **File grandi su un MethodChannel**: mai come `Uint8List` (copia nell'heap Java, `OutOfMemoryError`). Per salvare usa `saveFileAt` (`codecore/save`).
- **Selettore di file (DocumentsUI) sul Mi A3 via adb**: i tocchi non arrivano; `input keyevent TAB TAB ENTER` con il file copiato per primo. Un `am start -a SEND` con `file://` o `content://` dà `SecurityException` in `IncomingBridge`: non è un bug.
- **Ricevitore di broadcast di sistema: `RECEIVER_EXPORTED`** da Android 13 (caso `BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED`); sul Mi A3 (Android 11) il difetto non si vede.
- **Il prefisso di rete si legge con `java.net.NetworkInterface`**, non con i `LinkProperties` (D-227).
- **App Linux in uno schermo virtuale**: dentro `xvfb-run` serve `env -u WAYLAND_DISPLAY GDK_BACKEND=x11`, altrimenti la finestra si apre sullo schermo dell'utente. Comando completo in `.claude/obiettivo.md`.
- **Build Linux con `HOME` finto: «rustup is not installed»**: `metadata_god` compila Rust e cerca rustup nella home. Sotto `xvfb-run` tieni `HOME` vero e sposta solo `XDG_DATA_HOME` e `XDG_CONFIG_HOME`.
- **Integration test su Linux un file per volta**; il driver deve chiamare `JustAudioMediaKit.ensureInitialized()`, come `main`.
- **Movimento ridotto su Android via adb**: Flutter legge `transition_animation_scale`; servono tutti e tre `animator_duration_scale`, `transition_animation_scale`, `window_animation_scale` a 0, e a fine prova di nuovo a 1.
- **Rotazione dei telefoni**: l'utente la tiene spenta; una prova che forza l'orizzontale legge e poi ripristina `accelerometer_rotation` e `user_rotation`.
- **Pausa a volume zero in secondo piano**: il tasto volume su riprende solo entro circa 2 s (limite di Android).
- **`IndexedStack` e `TickerMode`**: vedi `ui-e-design.md`.
- **Un filtro che mpv non sa costruire ferma la riproduzione**: per questo il filtro della voce c'è solo su Linux (`DesktopVoiceFilter.supported`); la libmpv di Windows ha `--disable-filters`.
- **Un APK full senza libmpv cade al primo `Player()`** (`UnsatisfiedLinkError`): l'esclusione in `build.gradle.kts` vale solo con `CODECORE_LITE=1`. Dopo una build lite, `unzip -l app-*-release.apk | grep libmpv` non deve trovare nulla.
- **iOS non ha le librerie video**; macOS e i pacchetti Linux (AppImage, `.deb`, Flatpak) con `media_kit_video` non sono ancora provati fuori dalla CI.
- **Entitlements macOS**: `macos/Runner/Release.entitlements` ha `app-sandbox`, `network.client`, `network.server` e `files.user-selected.read-write`. Un entitlement in meno e l'app sandboxed perde rete o accesso ai file.

## Decisioni chiave
| ID | Significato |
|---|---|
| [D-227](../decisioni.md) | Prefisso di rete su Android con `NetworkInterface`. |
| [D-269](../decisioni.md) | Segreti della Jam: file su desktop, DataStore su Android. |
| [D-502](../decisioni.md) | Redmi Note 9 Pro come telefono di prova: solo l'app, mai i file presenti. |
| [D-535](../decisioni.md) | Volume dei dispositivi di prova a zero. |
| [D-538](../decisioni.md) | v1.4.0 senza release (build Windows MSVC 14.51, Flatpak); si pubblica v1.4.1. |
| [D-539](../decisioni.md) | Nome FreeKmusic, `applicationId` `com.freekmusic.player`, pacchetto Dart e `namespace` invariati. |
| [D-540](../decisioni.md) | Verifica di compatibilità con `ci.yml` lanciato a mano su tutte le piattaforme. |
| [D-637](../decisioni.md), [D-654](../decisioni.md) | Librerie video di media_kit per piattaforma; esclusione dalla lite. |
