# Modifiche a just_audio_media_kit

Base: `just_audio_media_kit` 2.1.0 (pub.dev). Collegata in `pubspec.yaml` con `dependency_overrides` (fase 127, D-603).

## Cosa cambia
- `lib/mediakit_player.dart`: `MediaKitPlayer` ha `voiceTag` e `applyVoiceFilter(af)`; scrive la proprietà `af` di mpv
  come `scaletempo:scale=…` (la velocità) seguito dal filtro della voce. `setSpeed` e `setPitch` rimettono il filtro
  dopo che media_kit ha sovrascritto `af`.
- `lib/just_audio_media_kit.dart`: `JustAudioMediaKit.voiceFilterTag(int)` e `JustAudioMediaKit.setVoiceFilter(tag, af)`;
  `init` legge il tag da `audioLoadConfiguration.darwinLoadControl.preferredPeakBitRate` (campo inutilizzato su
  Linux/Windows) e applica il filtro già memorizzato, così un player ricreato (stop, poi nuovo brano) lo mantiene.

## Perché
Filtro della voce del karaoke (R-243). L'`id` dell'`AudioPlayer` di just_audio è privato e cambia a ogni reinizializzazione:
il tag passato nella configurazione è il legame stabile fra l'`AudioPlayer` dell'app e il `Player` privato di media_kit.

## Come riallineare a un aggiornamento
Copiare la nuova versione da `~/.pub-cache/hosted/pub.dev/`, riapplicare le righe elencate in «Cosa cambia», `diff -r` per controllare.
