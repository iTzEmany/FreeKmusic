# Fase 122 — CI verde su tutti i sistemi

## Obiettivo
Tutti i job della CI (Analyze and test, Test (Windows), Windows, APK full e lite, Linux zip e .deb, Integration Android, macOS / iOS) verdi in un run manuale completo, senza nascondere errori. Il codice del prodotto non cambia.

## Riferimenti
R-240 «tutti i job della CI verdi in un run manuale completo». Documento d'area: `../architettura/qualita-e-rilascio.md`.

## Task
- [ ] 122.1 Run manuale completo verde
  - File: `.github/workflows/ci.yml`, `test/services/audio/online_playback_test.dart`
  - Passi: 1. togliere `continue-on-error` da `build-apple`; 2. rendere deterministico il test «the next track still downloading…»; 3. lanciare il workflow con `integration=true` e correggere ciò che è rosso.
  - Comando mirato: `flutter test test/services/audio/online_playback_test.dart` (più `flutter analyze`)
  - Fatto quando: un run `workflow_dispatch` con `integration=true` ha tutti i job verdi.

## Tocca a te
Niente.

## Note di deviazione
- `build-apple` non ha più `continue-on-error` (era verde nel run 43122152347); il commento di `integration-android` dice ora «cinque» test, come `scripts/integration.sh`.
- Test `online_playback_test`: dopo `gate.complete()` il test aspettava con `pumpEventQueue` (un numero fisso di giri), ma il caricamento passa da DB e file veri; su una macchina lenta l'asserzione scattava prima (`/m/a.mp3`), il test finiva, `dispose()` chiudeva i controller e la catena ancora in corso falliva con «Cannot add new events after calling close». Ora il test aspetta la condizione (secondo caricamento) con un limite di 5 s.
- Integration Android (run 43133244918): «No application found for TargetPlatform.android_x64». `build.gradle.kts` filtrava le ABI a arm64-v8a e armeabi-v7a, quindi `flutter test -d emulator-5554` (x86_64) non trovava nulla da installare. Con `CODECORE_X64=1` (impostato solo nel job) si aggiunge x86_64; le release non cambiano.
- Test (Windows) (stesso run) in rosso per ipotesi di percorso POSIX nei test e in `resolveDefaultFolders`: `default_folders_test` (con HOME di Windows il controllo «assoluto» usava il contesto POSIX e cadeva su `getApplicationDocumentsDirectory`; ora desktop usa il contesto dell'host e normalizza `$HOME/...`), `track_repository_test` e `android_download_publish_test` (percorsi con `/` fissi, ora `p.join`), `yt_dlp_auto_update_test` (`filePortalMissing` esce subito se non Linux: nuovo parametro `linux`, solo per i test).
- Integration Android, secondo giro: `flutter test -d` ora trova l'app (APK debug x86_64 compilato prima), `app_flow` passa; `playback` falliva con «Bad state: Cannot add new events after calling close» (`_enterTrack` ← `_failAndSkip` ← `_onCompleted`): `dispose()` chiude i controller mentre un caricamento o la fine di un brano è ancora in volo, e poi la catena ci scrive. Stessa causa dell'errore visto in `online_playback_test`. Correzione nel prodotto: flag `_disposed` in `CodecoreAudioHandler` che fa uscire subito `_loadCurrent`, `_failAndSkip`, `_goIdle` ed `_enterTrack`.
