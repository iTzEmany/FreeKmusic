# Fase 160 — Pacchetto e arricchimento

## Obiettivo
Flatpak sul runtime 25.08, avviso di primo avvio sulla cartella dati, comando di installazione dopo l'aggiornamento scaricato nel flatpak, curiosità che rispettano la pausa di MusicBrainz, versione di fdroid dal pubspec.

## Riferimenti
D-715, D-722. Refactor: [`scansione-input-flatpak-test.md`](../refactor/desktop-e-coerenza/scansione-input-flatpak-test.md) (F-202, F-204, F-213, F-214, F-215). **Già fatti nella PR #231** (D-715): F-201 (metainfo dal pubspec), F-203 (controllo pubspec = `kAppVersion` in CI), F-212 (`/app/lib/ffmpeg`), F-216 (nome del bundle con la versione); qui non si rifanno. Architettura: `../architettura/piattaforme.md`, `../architettura/qualita-e-rilascio.md`, `../architettura/online.md`.
Codice: `packaging/flatpak/com.freekmusic.player.yml` (`runtime-version`, moduli `libplacebo`, `libass`, `libmpv`), `.github/workflows/release.yml` (job `flatpak`, righe `flatpak install … //24.08`), `packaging/fdroid/com.freekmusic.player.yml` (`versionName`), `lib/services/update/update_target.dart` (`UpdateKind.flatpak`, nome del file atteso), `lib/ui/screens/settings/update_tiles.dart`, `lib/services/online/curiosity_service.dart`, `curiosity_finder.dart`, `musicbrainz_client.dart` (`MusicBrainzUnavailable`, fine della pausa), `lib/providers/curiosity_provider.dart`, `lib/core/app_info.dart`.

## Task
- [ ] 160.1 Curiosità e pausa di MusicBrainz (F-215)
  - File: `curiosity_provider.dart`, `curiosity_service.dart`, `musicbrainz_client.dart`, `test/providers/curiosity_provider_test.dart`.
  - Passi: 1) con `MusicBrainzUnavailable` («resting until …») la curiosità non ritenta ogni 3 s: aspetta la fine della pausa del client (come il resto dell'arricchimento) e non scrive una riga di log ogni volta; 2) il test di caratterizzazione di 150.2 si aggiorna al comportamento voluto.
  - Comando mirato: `flutter test test/providers/curiosity_provider_test.dart test/services/online/curiosity_finder_test.dart`
  - Fatto quando: test con orologio finto: in pausa nessuna richiesta nuova; a pausa finita una sola.
- [ ] 160.2 Runtime flatpak 25.08 (F-213)
  - File: `packaging/flatpak/com.freekmusic.player.yml`, `.github/workflows/release.yml` (job `flatpak`), `docs/architettura/piattaforme.md`.
  - Passi: 1) `runtime-version` e i tre `flatpak install … //24.08` (Platform, Sdk, `ffmpeg-full`) → 25.08; 2) il modulo `libplacebo` esiste perché mpv 0.38 voleva ≥ 6.338.2 e il 24.08 non lo dava: verificare se il 25.08 lo dà e, se sì, toglierlo; altrimenti ricompilare `libplacebo`, `libass` e `libmpv` contro il nuovo runtime; 3) controllare che la riga `mkdir -p /app/lib/ffmpeg` (PR #231) resti; 4) costruire il bundle in locale (`flatpak-builder`) e provare l'avvio, con e senza `ffmpeg-full`, e un brano AAC.
  - Comando mirato: `flatpak-builder --user --force-clean --repo=repo build-dir packaging/flatpak/com.freekmusic.player.yml` (con `sorveglia.sh --pesante`)
  - Fatto quando: il bundle si costruisce, l'app parte nel sandbox e suona; `grep -n "24.08" packaging .github` vuoto.
- [ ] 160.3 Avviso di primo avvio nel flatpak (F-214)
  - File: nuovo `lib/services/platform/flatpak_data_notice.dart`, `lib/ui/screens/onboarding/` o l'avvio dell'app, `settings_store.dart` (avviso già mostrato), ARB (6 lingue via `scripts/arb_add.py`).
  - Passi: 1) solo se `FLATPAK_ID` è impostato (come in `update_target.dart`), libreria vuota e avviso non ancora mostrato: avviso una volta sola che spiega che AppImage e deb usano `~/.local/share/com.freekmusic.player` mentre il flatpak usa `~/.var/app/com.freekmusic.player/data/com.freekmusic.player`, con il comando di copia e il pulsante «Copia comando»; 2) il sandbox non può leggere la cartella vecchia: l'avviso **non** controlla che esista (può solo suggerire); 3) mai migrazione automatica, nessun cambio di schema (D-721).
  - Comando mirato: `flutter test test/services/platform/ test/ui/onboarding_test.dart`
  - Fatto quando: test: compare con flatpak e libreria vuota la prima volta, non la seconda, non fuori da flatpak, non con libreria piena.
- [ ] 160.4 Comando `flatpak install --user` dopo il download (F-204)
  - File: `lib/ui/screens/settings/update_tiles.dart` (`:214` apre il browser), `lib/services/update/update_target.dart`, `update_providers.dart`, ARB, `test/ui/update_tiles_test.dart`, `test/services/update/update_target_test.dart`.
  - Passi: 1) dopo il download del bundle (nome con versione dopo F-216: aggiornare l'espressione regolare a `update_target.dart:61` se serve) mostrare il comando `flatpak install --user <percorso del file>` con «Copia»; 2) niente esecuzione dal sandbox; 3) gli stati e le azioni degli altri formati non cambiano.
  - Comando mirato: `flutter test test/ui/update_tiles_test.dart test/services/update/update_target_test.dart`
  - Fatto quando: test: con `UpdateKind.flatpak` compaiono comando e «Copia» col percorso giusto; con gli altri formati no.
- [ ] 160.5 Versione di fdroid dal pubspec (F-202)
  - File: `packaging/fdroid/com.freekmusic.player.yml` (`versionName`, `versionCode`), lo script che in CI scrive il metainfo (dalla PR #231), `.github/workflows/ci.yml` o `release.yml`.
  - Passi: stesso script del metainfo aggiorna anche il yml di fdroid (bozza non pubblicata); il controllo di versione in CI lo include.
  - Comando mirato: lo script con la versione del pubspec in locale + `git diff packaging/fdroid`
  - Fatto quando: `versionName` e `versionCode` uguali al pubspec; il controllo in CI fallisce se non lo sono.

## Tocca a te
- [ ] Provare il bundle nuovo sul tuo PC: installazione del flatpak col runtime 25.08.

## Note di deviazione
