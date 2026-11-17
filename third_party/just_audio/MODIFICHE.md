# Modifiche a just_audio

Base: `just_audio` 0.10.6 (pub.dev). Collegata in `pubspec.yaml` con `dependency_overrides` (fase 127, D-603).

## Cosa cambia
Solo Android più un metodo Dart. Il piattaforma-interface non cambia: il messaggio nuovo va su un `MethodChannel`
`com.ryanheise.just_audio.methods.<id del player>`, lo stesso del plugin.

- `android/src/main/java/com/ryanheise/just_audio/VoiceFilterProcessor.java` (nuovo): `AudioProcessor` Media3
  (`BaseAudioProcessor`). Su stereo 16 bit o float: medio m=(L+R)/2 e laterale s=(L-R)/2; il medio passa in un
  Butterworth del 2° ordine a 150 Hz (basso e cassa); uscita `L = basso + livello*(m-basso) + s`, `R = basso +
  livello*(m-basso) - s`. Livello 1.0 (o null, o NaN) = copia identica dei byte, ma il passa-basso continua a seguire il medio, così abbassare il livello dopo non parte da uno stato vecchio; mono e altri formati = processore inattivo.
  Livello `volatile`, ammorbidito per frame (nessun click), cambia senza ripreparare il player.
- `android/src/main/java/com/ryanheise/just_audio/VoiceFilterRenderersFactory.java` (nuovo): sottoclasse di
  `DefaultRenderersFactory`; `buildAudioSink` è quello di default più `setAudioProcessors({processore})`.
- `android/.../AudioPlayer.java`: riga 82 campo `voiceFilter`; righe 469-472 `case "setVoiceLevel"` in `onMethodCall`;
  riga 785 `new DefaultRenderersFactory(context)` diventa `new VoiceFilterRenderersFactory(context, voiceFilter)`.
- `android/build.gradle.kts` riga 76: `testImplementation("junit:junit:4.13.2")`.
- `android/src/test/java/com/ryanheise/just_audio/VoiceFilterProcessorTest.java` (nuovo): test JVM del processore.
- `lib/just_audio.dart`: campo `_voiceLevel` (riga 117); `AudioPlayer.setAndroidVoiceLevel(double?)` con `_sendVoiceLevel`
  (righe 1185-1199; NaN vale null; attivo anche sotto `flutter test`, come gli effetti, così `test/services/audio/android_voice_level_test.dart` prova il livello rimandato dopo `stop()`); righe 1679-1685 dentro `setPlatform`: dopo la creazione del player nativo rimanda il livello
  ricordato (dopo uno `stop()` il player nativo nasce con un id nuovo).

## Perché
Filtro della voce del karaoke (R-243). `AudioPlayer.java` costruiva `DefaultRenderersFactory` senza punto d'innesto per
i processori audio. Un solo `ExoPlayer` e una sola sorgente concatenata: il gapless non cambia.

## Provare
`cd android && ./gradlew :just_audio:testDebugUnitTest` (JAVA_HOME = JBR 17): il modulo del plugin è dentro il progetto
Gradle dell'app.

## Come riallineare a un aggiornamento
1. Copiare la nuova versione da `~/.pub-cache/hosted/pub.dev/just_audio-<versione>` sopra questa cartella, poi rimettere
   i file nuovi (`VoiceFilter*.java`, `src/test/`) e questo file.
2. Rifare a mano le righe elencate sopra in `AudioPlayer.java`, `build.gradle.kts` e `just_audio.dart`.
3. `diff -r ~/.pub-cache/hosted/pub.dev/just_audio-<versione> third_party/just_audio`: devono restare solo quelle righe e
   i file nuovi. Se il pacchetto ha un punto d'innesto proprio per i processori audio, togliere la copia e l'override.
