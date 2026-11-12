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
