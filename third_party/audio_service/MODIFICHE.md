# Modifiche a audio_service

Base: `audio_service` 0.18.19 (pub.dev). Collegata in `pubspec.yaml` con `dependency_overrides` (R-227, D-608).

## Cosa cambia
Solo `android/src/main/java/com/ryanheise/audioservice/AudioService.java`, in `onMediaButtonEvent` (circa righe 965-985):
- `KEYCODE_MEDIA_PLAY` chiama `onPlay()` e `KEYCODE_MEDIA_PAUSE` chiama `onPause()`, invece di `listener.onClick(...)`.
- `KEYCODE_MEDIA_PLAY_PAUSE`, `KEYCODE_HEADSETHOOK`, NEXT e PREVIOUS restano `onClick`.
- Corretto il refuso `PUASE` nel commento e aggiunto il perché.

## Perché
Il tasto pausa deve mettere sempre in pausa. Il Bluetooth (AVRCP) manda PLAY e PAUSE separati, ma il pacchetto li
trasformava in un clic che commuta: un «pausa» su un player già in pausa lo faceva partire.

## Come riallineare a un aggiornamento
1. Copiare la nuova versione da `~/.pub-cache/hosted/pub.dev/audio_service-<versione>` sopra questa cartella.
2. Rifare la modifica sopra in `AudioService.java` (e rimettere questo file).
3. Controllare con `diff -r ~/.pub-cache/hosted/pub.dev/audio_service-<versione> third_party/audio_service`: devono
   restare solo quelle righe e `MODIFICHE.md`. Se il pacchetto ha già risolto, togliere la copia e l'override.
