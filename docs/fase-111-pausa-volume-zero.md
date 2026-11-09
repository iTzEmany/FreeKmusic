# Fase 111 — Pausa a volume zero

**Obiettivo:** funzione nuova: con l'interruttore acceso, portare a zero il volume mette in pausa la musica; rialzandolo riparte da sola, ma solo se l'aveva fermata questa funzione. **Funzione nuova** (D-504, D-505, D-506, D-507).

**Prerequisiti:** fase 110 chiusa. Nessuna sezione di analisi (funzione aggiunta dopo l'analisi, D-504..D-508). Nessun mockup: una riga di impostazione nello stile di quelle esistenti (D-408). Aree a rischio: audio handler (`codecore_audio_handler.dart`, `/code-review high`), lato nativo Android (nuovo bridge Kotlin).

**Comando mirato:** `flutter test test/providers/volume_zero_pause_test.dart test/services/audio/codecore_audio_handler_test.dart test/ui/settings_and_playlists_test.dart test/ui/settings_index_test.dart test/providers/sleep_timer_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`.

## Task

### 111.1 — Impostazione «Metti in pausa quando il volume è a zero» (D-507)
- `SettingsStore` (`lib/data/settings/settings_store.dart`): getter/setter `pauseOnZeroVolume`, `shared_preferences`, **spento di serie** (le prove si fanno a volume 0). Il backup copia già tutte le prefs (formato invariato, D-491).
- UI: un interruttore in Impostazioni › Riproduzione (`settingsPagePlayback`, `lib/ui/screens/settings/settings_pages.dart`, accanto alle altre scelte di riproduzione), con testo di aiuto breve. ARB it, en, de, es, fr, pt (`scripts/arb_add.py`, `flutter gen-l10n`): `pauseOnZeroVolume` e `pauseOnZeroVolumeHelp`. Nome esatto: «Metti in pausa quando il volume è a zero».
- Test: `settings_and_playlists_test.dart` (interruttore spento di serie, si accende e si ricorda).

### 111.2 — Logica unica in Dart (D-504, D-505, D-506)
- Un controller piccolo (`lib/providers/volume_zero_pause_provider.dart`, `Notifier` Riverpod come `sleep_timer_provider.dart`) che riceve un flusso di «volume dell'utente» (0..1) e agisce sull'handler:
  - volume che **arriva** a 0 mentre l'audio locale suona e l'interruttore è acceso → `pause()` e flag `_pausedByZeroVolume = true`;
  - volume che **torna** > 0 con `_pausedByZeroVolume` ancora vero → `play()` e flag a falso;
  - qualunque azione dell'utente sul trasporto fra le due cose (Play, un altro brano, Stop, Svuota) azzera il flag: la ripresa avviene **solo** se la pausa l'ha fatta la funzione (D-505, non una pausa dell'utente);
  - con l'interruttore spento, o spento a metà, il flag si azzera e nulla accade.
- **Jam (D-506):** vale solo per l'audio locale. Se c'è una Jam o un trasporto remoto attaccato (`attachRemote`, `codecore_audio_handler.dart:1827`) la funzione non fa nulla: non ferma la Jam né gli altri. La pausa di un ospite o dell'host Jam non è mai provocata da qui.
- Test `test/providers/volume_zero_pause_test.dart` (uno per comportamento): a 0 con musica in corso va in pausa; rialzando riparte; pausa dell'utente a volume 0 poi rialzando **non** riparte; interruttore spento non fa nulla; già in pausa a 0 non imposta il flag; con Jam attiva non agisce; Play dell'utente mentre il volume è 0 azzera il flag.

### 111.3 — Android: osservare il volume multimediale (D-504)
- **Meccanismo scelto:** nuovo `VolumeBridge.kt` in `android/app/src/main/kotlin/com/codecore/player/`, nello stesso stile di `NetworkBridge.kt` (`register(messenger, context)` / `unregister()`, canale `codecore/volume`, evento `changed` spinto a Dart con `invokeMethod`, risposta `get` con il volume corrente) e registrato in `MainActivity.configureFlutterEngine` accanto a `NetworkBridge` (`MainActivity.kt:68`), staccato dove si stacca `NetworkBridge.unregister()` (`:169`).
- **API Android (D-509):** un `ContentObserver` registrato sul **contesto dell'applicazione** (non sull'Activity) con `ContentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, observer)`; a ogni `onChange` si rilegge `AudioManager.getStreamVolume(STREAM_MUSIC)` e si confronta con `getStreamMinVolume(STREAM_MUSIC)` (può essere > 0 su certi telefoni), inviando a Dart solo i cambi del valore. Tutte API pubbliche; l'osservatore si toglie con `unregisterContentObserver` quando l'interruttore è spento o il motore si chiude.
- **Verifica nei sorgenti locali** (`~/Android/Sdk/sources/android-36/`): `ContentResolver.registerContentObserver` (`android/content/ContentResolver.java:2674`), `ContentObserver` (`android/database/ContentObserver.java:41`), `Settings.System.CONTENT_URI`, `AudioManager.getStreamVolume`/`getStreamMinVolume` sono pubblici. Scartata `AudioManager.VOLUME_CHANGED_ACTION`: esiste (`AudioManager.java:204`) ma è `@hide`/`@UnsupportedAppUsage`, non API pubblica. Che l'osservatore scatti con tasti, pannello e cuffie Bluetooth va provato sul Mi A3 e sul Redmi.
- **Con l'app in secondo piano:** il ricevitore sta sul contesto dell'applicazione, quindi vive quanto il processo, che resta vivo con il servizio di riproduzione in primo piano (`audio_service`, `foregroundServiceType="mediaPlayback"`, `AndroidManifest.xml:286`). `MainActivity` estende `AudioServiceActivity` (`MainActivity.kt:23`): **da verificare** (leggendo il sorgente di `audio_service` in `~/.pub-cache`) se il motore Flutter, e quindi il canale verso Dart, sopravvive alla distruzione dell'Activity; se non sopravvive, il ricevitore deve registrarsi dove vive l'handler Dart (stesso motore) e non nell'Activity. La prova sul telefono con schermo spento e app chiusa dagli ultimi usati è parte di 111.5.
- Dart: lato `lib/core/` un piccolo lettore del canale (come `network_kind.dart:17`, `MethodChannel('codecore/volume')`) che alimenta il controller di 111.2 con volume 0/non-0 solo su Android; su desktop non c'è canale.
- Nessun permesso nuovo nel manifest (il broadcast non ne richiede); controllare con `git diff -- android/app/src/main/AndroidManifest.xml` vuoto.

### 111.4 — Desktop: cursore del volume dell'app (D-504)
- Il volume dell'utente è `VolumeNotifier.set` (`player_providers.dart:822-825`): lo scrivono il cursore (`now_playing_controls.dart`, `_VolumeRow`), `toggleMute` (`:827`) e le richieste esterne (`volumeRequests`, MPRIS: `codecore_audio_handler.dart:320-330`, `requestVolume`). Il controller di 111.2 ascolta `volumeProvider` (non l'handler) su Linux e Windows: così **le discese interne non fanno scattare la funzione**, perché passano da `handler.setVolume` senza toccare `volumeProvider`:
  - la sfumatura del timer di spegnimento: `sleep_timer_provider.dart:79` (`h.setVolume(original * …)`) e `:84`;
  - l'anteprima: `preview_player.dart:68` (`backend.setVolume(0)`), `:99`, `:109`, su un backend separato;
  - `CodecoreAudioHandler.setVolume` (`:1783`) è comune e non distingue chi chiama: per questo l'ascolto sta su `volumeProvider`, non sul flusso `_volumeController`.
- Caso limite da coprire con un test: il timer di spegnimento che termina con `h.pause()` e `setVolume(original)` (`:83-84`) **non** deve lasciare un flag di «pausa a volume zero» né far ripartire la musica.
- Test (in `volume_zero_pause_test.dart`): `VolumeNotifier.set(0)` mette in pausa; `toggleMute` due volte riparte; sfumatura del timer (chiamate a `handler.setVolume` fino a 0) **non** mette in pausa; anteprima non agisce.

### 111.5 — Controlli di fase
- `flutter analyze`; comando mirato; `/code-review high` su handler e bridge Kotlin; scheggia di passo (effort `high`, area a rischio).
- **Prova sul Mi A3** (`0d7ae9df206e`, via adb, anche con le cuffie JBL come da memoria «prove a due telefoni»): interruttore acceso, musica in corso, tasti del volume fino a 0 → pausa; rialzando → riparte; pausa a mano a volume 0 poi rialzando → resta in pausa; interruttore spento → niente; app in secondo piano con schermo spento (verifica del punto «da verificare» di 111.3); con la Jam attiva → la Jam non si ferma. Con l'adb: `adb shell media volume --stream 3 --set 0` per i passi senza tasti.
- **Prova sul Redmi Note 9 Pro** (`8bbad1cd`, D-502): stessa prova per confermare l'osservatore del volume su un altro Android; **mai toccare i file già presenti** (foto, documenti, `/sdcard/Download`): solo l'app e brani di prova copiati da noi, poi toglierli. A fine prova disinstallare l'app o cancellarne i dati.
- Ripulire i telefoni (volume riportato dove era, interruttore spento, dati di prova tolti), mai i file musicali del Mi A3.
- Desktop: prova su Linux **solo su schermo virtuale** (`.claude/obiettivo.md`, `xvfb-run`), mai `wpctl`/volume del PC.

**Fatto quando:** con l'interruttore acceso il volume a zero ferma la musica locale su Android e su desktop e rialzarlo la fa ripartire solo se l'aveva fermata la funzione, la sfumatura del timer e l'anteprima non la fanno scattare, la Jam non cambia, i test sono verdi e l'osservatore del volume è provato su Mi A3 e Redmi.

## Da decidere
(nessuno)
