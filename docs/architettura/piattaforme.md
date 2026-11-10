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
Codice Kotlin in `android/app/src/main/kotlin/com/codecore/player/` (il pacchetto resta `com.codecore.player`).

| File | Canale / ruolo |
|---|---|
| `MainActivity.kt` | Registra i ponti. Canali propri: `codecore/audio` (`outputRoute`, `bluetoothOutputs`, `netPrefix`, `bluetoothOutputActive`, permessi Bluetooth), `codecore/screen` (`keepOn`), `codecore/share` (`startService`, `stopService`, `showOffer`). |
| `CodecoreApp.kt` | `Application`: vive quanto il processo, ridisegna widget e tile quando Dart scrive un nuovo stato. |
| `IncomingBridge.kt` | `codecore/incoming`: ZIP/CSV aperto con FreeKmusic («Apri con», «Condividi»). Copia nella cache (massimo 20 MB), `takeIncoming`, `takeIncomingText`. |
| `VolumeBridge.kt` | `codecore/volume`: `get` (0..1), `start`/`stop` di un `ContentObserver` che manda `changed`. Alla base della pausa a volume zero. |
| `IconBridge.kt` | `codecore/icon`: l'icona è uno di 16 `activity-alias` di `MainActivity` (`.IconViolaDark`…). `setIcon` ricorda la scelta, `apply` cambia in background. |
| `NetworkBridge.kt` | `codecore/net`: `isMetered`, evento `changed`. Shuffle+ evita i dati mobili. |
| `StorageBridge.kt` | `codecore/storage`: `diskSpace`, `openFolder`. |
| `SaveFileBridge.kt` | `codecore/save`: copia a flusso verso un file scelto dall'utente. |
| `MediaDeleteBridge.kt` | `codecore/media`: elimina dal dispositivo. |
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
Widget, tile, Android Auto e orologio mandano tasti alla sessione di `audio_service`; non toccano DB o file. Dart scrive titolo, artista, copertina e stato in `FlutterSharedPreferences` (`flutter.widget.*`, tramite `widget_bridge.dart`); `CodecoreApp` ascolta `flutter.widget.stamp` e ridisegna. Non c'è un canale perché il motore avviato da `audio_service` senza attività non ha quelli di `MainActivity`. A freddo `MediaKeys.pressSurely` preme il tasto due volte (R63).

### Windows
Backend audio libmpv (`just_audio_media_kit`), controlli di sistema SMTC (`smtc_windows`, un crate Rust compilato da cargokit). Il rilascio è un installer Inno Setup con `yt-dlp.exe` e `ffmpeg.exe` (build LGPL) accanto all'app. Nota MSVC: `permission_handler_windows` include `<experimental/coroutine>`, che con MSVC 14.51 dei runner GitHub dà l'errore STL1011; la definizione in `windows/CMakeLists.txt` lo silenzia (PR #163).

### Linux
Backend libmpv, MPRIS (`MprisControls`, percorso `/org/codecore/track/<id>` in `mpris_mapping.dart`). Tre pacchetti: zip e `.deb` da `package-linux.sh`, AppImage da `package-appimage.sh` (copia libmpv e le sue dipendenze, tranne quelle di ogni desktop). Il Flatpak (`org.freedesktop.Platform` 24.08) costruisce da sorgente `libplacebo` 6.338.2 e `libass` 0.17.3 perché mpv 0.38 li richiede e il runtime non li ha, poi `libmpv`; `yt-dlp` è un file fissato per hash; ffmpeg viene dall'estensione `ffmpeg-full`. Permessi: rete, audio (PulseAudio), Wayland/X11, `xdg-music`, `xdg-download`, nome MPRIS `org.mpris.MediaPlayer2.freekmusic`.

### macOS
Il runner Flutter esiste in `macos/` (id `com.freekmusic.player`). `just_audio_media_kit` si inizializza solo su Linux e Windows, quindi su macOS suona il backend nativo di `just_audio`. La CI lo compila con `flutter build macos --debug` nel job `build-apple` (solo a mano). La release (D-543) ha il job `macos`: `flutter build macos --release` e `.app` in zip non firmato (`FreeKmusic-<versione>-macos.zip`), senza yt-dlp né ffmpeg dentro. Niente firma né notarizzazione.

### Differenze per piattaforma
| Aspetto | Android | Windows / Linux | macOS |
|---|---|---|---|
| Audio | ExoPlayer | libmpv | nativo di `just_audio` |
| Controlli di sistema | `audio_service` (notifica, schermata di blocco, cuffie) | SMTC / MPRIS | non cablati in `main.dart` |
| Equalizzatore | `AndroidEqualizer` (la voce compare solo se `equalizerProvider` non è nullo) | assente (il filtro `af` di mpv è di `scaletempo`) | non verificato |
| Permessi file | `READ_MEDIA_AUDIO` (`READ_EXTERNAL_STORAGE` fino ad API 32) | nessuno | sandbox |
| Cartella musica | `/storage/emulated/0/Music` | `~/Music` o `%USERPROFILE%\Music` | `~/Music` (`defaultMusicDir`) |
| Orientamento | bloccato in verticale | libero | libero |
| Scoperta in LAN (`discovery.dart`) | senza `reusePort` | `reusePort` solo su Linux | `reusePort` |

## Invarianti da non rompere
- **Nessun `Platform.isX` sparso per nuove funzioni**: usa `isAndroid` e `isDesktop` di `core/platform.dart`, così i test possono forzarli. (Oggi 24 file usano ancora `Platform.is…` direttamente, per lo più in `main.dart` e nei servizi di piattaforma; il nuovo codice non li aumenta.)
- **Nomi dei canali invariati** (`codecore/…`): Dart e Kotlin devono restare allineati; sono parte del filo (vedi `sync-backup-jam.md`).
- **`namespace` resta `com.codecore.player`** finché le classi Kotlin stanno in quel pacchetto: cambiarlo senza spostare i file rompe la `R` e il manifest (`.MainActivity` è relativo al namespace).
- **`applicationId` e `appLabel` dipendono da `perf`**: la build di misura non deve mai poter sovrascrivere l'app vera.
- **Le due metà della variante lite** (`CODECORE_LITE` e `CODECORE_YOUTUBE=false`) vanno sempre insieme; ogni funzione di YouTube sta dietro `kEnableYoutube`.
- **Il cambio dell'icona avviene in background** (`IconBridge.apply`): cambiare l'alias attivo mentre l'utente guarda può far chiudere l'app al launcher.
- **Un nuovo canale usato anche dal servizio senza attività** non può passare da `MainActivity`: va su `FlutterSharedPreferences` come i widget.
- **Nessun lavoro pesante nel thread UI**; sui ponti, risultati rapidi o asincroni.
- **I pacchetti del Flatpak sono fissati** (commit, hash): aggiornarli è una scelta, non un effetto collaterale.

## Come si estende
- **Nuovo ponte Android**: `object XxxBridge` con `register(messenger, context)` in un file nuovo di `main/kotlin/...`, chiamato da `MainActivity.configureFlutterEngine`; lato Dart una classe con `MethodChannel` iniettabile (come `SystemVolume` o `NetworkKind`) e un fake nei test. Nome del canale `codecore/<nome>`.
- **Nuova funzione solo Android**: il Dart passa da `isAndroid`; il test imposta `debugIsAndroidOverride = true`.
- **Nuova funzione solo desktop**: `isDesktop`; il test imposta `debugIsDesktopOverride = false` per vedere il layout telefono.
- **Nuova funzione legata a YouTube**: dietro `kEnableYoutube`, e una versione vuota in `src/lite/kotlin` se tocca `YtDlpChannel`.
- **Nuovo permesso Android**: in `AndroidManifest.xml` e nella richiesta runtime lato `MainActivity`; se il servizio è in primo piano, aggiungi il tipo corretto.
- **Nuovo widget o tile**: un `AppWidgetProvider` o `TileService` che legge solo `WidgetStore`; i dati li scrive `widget_sync.dart`.
- **Nuovo pacchetto Linux/Windows**: nuovo script in `scripts/` o `packaging/`, poi un job in `release.yml` (vedi `qualita-e-rilascio.md`).
- **Nuovo identificativo di app**: mai a caso; è una decisione (D-539), perché cambia la cartella dei dati.

## Trappole
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
- **Da verificare per macOS**: `macos/Runner/Release.entitlements` contiene solo `com.apple.security.app-sandbox`, senza `com.apple.security.network.client`. Un pacchetto di rilascio sandboxed senza quell'entitlement non fa richieste di rete in uscita; controlla prima di distribuirlo.

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
