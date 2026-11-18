# Fase 132 — Aggiornamento dall'app

## Obiettivo
«Aggiorna» al posto del link da copiare: l'app sceglie il file giusto della Release di GitHub, lo scarica, lo verifica
con lo SHA-256 e lo installa (Android con l'installer di sistema, Windows col setup silenzioso, AppImage sostituendo
il file) o apre il browser sul file (.deb, Flatpak, zip, macOS). Fuori: note formattate, canale beta, aggiornamento
senza tocco, pkexec, build F-Droid.

## Riferimenti
D-640..D-645, D-646 (Windows e AppImage), D-656. Specifica: [`../storico/feature/feature-karaoke-video-e-aggiornamenti.md`](../storico/feature/feature-karaoke-video-e-aggiornamenti.md)
(§ Architettura F, rischi F-7, F-8). Mockup: [`../storico/feature/mockup-karaoke-video-e-aggiornamenti.html`](../storico/feature/mockup-karaoke-video-e-aggiornamenti.html).
Documenti d'area: `../architettura/online.md`, `piattaforme.md`, `qualita-e-rilascio.md`.

## Mockup
```text
Avviso all'avvio (snackbar di oggi)       Impostazioni › Aggiornamenti
+--------------------------------------+  +------------------------------------+
| Disponibile la versione 1.6.4 [Aggiorna] | Controlla all'avvio            [on] |
+--------------------------------------+  | Disponibile la versione 1.6.4      |
                                          | freekmusic-full-arm64-v8a…, 84 MB  |
Errori: «Download interrotto [Riprova]»,  | [#########--------]  35 di 84 MB   |
«File danneggiato [Riprova]»,             | [Annulla]                          |
«Firma diversa» (build di prova/debug).   +------------------------------------+
Desktop: Windows/AppImage [Aggiorna]; .deb/Flatpak/zip/macOS [Scarica dal browser]
```

## Task
- [ ] 132.1 File giusto della Release (R-266)
  - File: `lib/services/online/update_checker.dart` (`UpdateInfo.assets`: nome, `browser_download_url`, dimensione, `digest`), `lib/services/update/update_target.dart` (nuovo: `detectUpdateTarget`, `pickUpdateAsset` puro), canale `codecore/update` lato Dart per l'ABI (`Build.SUPPORTED_ABIS[0]`).
  - Comando mirato: `flutter test test/services/update/update_target_test.dart test/services/online/update_checker_test.dart`
  - Fatto quando: la scelta è testata su ogni combinazione (full/lite × arm64-v8a/armeabi-v7a, Windows, AppImage, .deb, Flatpak, zip, macOS) coi nomi reali della Release v1.6.2 e la versione come segnaposto; `UpdateInfo` legge gli asset da una risposta d'esempio.
- [ ] 132.2 Download, verifica e pulizia (R-267, R-273)
  - File: `lib/services/update/update_installer.dart` (nuovo: `dio` in `<cache>/updates/`, avanzamento come stream, annullo, SHA-256 con `crypto` in un isolate), `lib/providers/update_providers.dart` (stato del download; pulizia della cartella dopo `startupSettledProvider`; su rete a consumo, `networkProbeProvider`, prima del download la dimensione e una conferma, D-656).
  - Comando mirato: `flutter test test/services/update/update_installer_test.dart test/providers/update_providers_test.dart`
  - Fatto quando: con un server HTTP finto, digest giusto → pronto; sbagliato → file assente ed errore; interruzione → stato «Riprova»; cartella svuotata all'avvio; rete a consumo → richiesta di conferma con la dimensione prima di scaricare.
- [ ] 132.3 Android: installer di sistema e firma (R-268, R-269; F-7) — **review Opus** (manifest e installazione)
  - File: `android/app/src/main/kotlin/com/codecore/player/UpdateChannel.kt` (nuovo: `abi`, `canInstall`, `openInstallSettings`, `sameSigner(path)` con `getPackageArchiveInfo` e i certificati di firma, `install(path)` con `FileProvider` + `ACTION_VIEW`), `MainActivity.kt` (registrazione del canale), `AndroidManifest.xml` (`REQUEST_INSTALL_PACKAGES`, `provider` con `res/xml/update_paths.xml` solo per `cache/updates`), `lib/services/update/android_update.dart`.
  - Comando mirato: `flutter test test/services/update/android_update_test.dart` + `flutter build apk --debug` (con `sorveglia.sh --pesante`)
  - Fatto quando: test del canale lato Dart (permesso mancante → impostazioni; firma diversa → messaggio e nessun installer); l'APK di debug compila; sul Mi A3 con la build di debug e un APK della Release v1.6.2 scaricato: compare il messaggio «Firma diversa», nessun installer.
- [ ] 132.4 Windows, AppImage, browser (R-270, R-271, R-272; F-8)
  - File: `lib/services/update/desktop_update.dart` (nuovo: Windows `Process.start(setup, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], detached)` e uscita; AppImage: scrittura accanto a `$APPIMAGE`, `chmod 755`, rinomina, avvio staccato e uscita, cartella non scrivibile → browser; `.deb`/Flatpak/zip/macOS: `xdg-open` / `open`), `packaging/windows/freekmusic.iss` (riga `[Run]` che riapre l'app in modalità silenziosa).
  - Comando mirato: `flutter test test/services/update/desktop_update_test.dart`
  - Fatto quando: argomenti e comandi testati con un esecutore di processi finto; sostituzione dell'AppImage su file temporanei (permesso di esecuzione, vecchio file sostituito, cartella non scrivibile → browser).
- [ ] 132.5 «Aggiorna» in Impostazioni e nell'avviso (R-265)
  - File: `lib/ui/screens/settings/update_tiles.dart` (pulsante, avanzamento, «Annulla», «Riprova», messaggi d'errore, conferma con la dimensione sui dati mobili, al posto di «Copia indirizzo»), `lib/app.dart` (azione «Aggiorna» nello snackbar di `updateOnStartProvider`), ARB ×6 (anche `updateOnStartHint`: oggi dice «Non scarica né installa niente»).
  - Comando mirato: `flutter test test/ui/update_tiles_test.dart`
  - Fatto quando: con `UpdateStatus.newer` c'è «Aggiorna» e non il link da copiare; avanzamento ed errori come nel mockup; lo snackbar ha l'azione.
- [ ] 132.6 Area e controllo di fine fase
  - Aggiorna `../architettura/online.md`, `piattaforme.md`, `qualita-e-rilascio.md` (l'aggiornamento richiede APK firmati con la chiave di D-569) e la colonna «Fase» della specifica. La prova reale dell'aggiornamento si fa nella fase 133, dopo la Release.

## Tocca a te
- Nessuna cosa in questa fase: la prova reale (Mi A3, AppImage, Windows) è nella 133.

## Note di deviazione
