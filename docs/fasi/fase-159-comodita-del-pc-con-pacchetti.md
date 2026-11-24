# Fase 159 — Comodità del PC con pacchetti

## Obiettivo
Prima l'aggiornamento di Flutter all'ultima 3.47.x, poi i tre pacchetti decisi: finestra ricordata (`window_manager`), icona nella barra di sistema (`tray_manager`) e trascinamento di file (`desktop_drop`). Nessun altro pacchetto.

## Riferimenti
D-718, D-727, D-728, D-729. Refactor: [`ricerca-pacchetti.md`](../refactor/desktop-e-coerenza/ricerca-pacchetti.md) (fonti, versioni, avvisi), [`scansione-input-flatpak-test.md`](../refactor/desktop-e-coerenza/scansione-input-flatpak-test.md) (F-206, F-208). Mockup: [`desktop-impostazioni.html`](../refactor/desktop-e-coerenza/mockup/desktop-impostazioni.html) (opzione «Chiudi nella barra di sistema»). Regole: `../01-regole-di-lavoro.md` (pacchetti: solo quelli decisi; leggere il sorgente in `~/.pub-cache` se l'API non coincide). Architettura: `../architettura/piattaforme.md`, `../architettura/qualita-e-rilascio.md`.
Codice: `.github/workflows/ci.yml` (`FLUTTER_VERSION`, 3.47.1), `.github/workflows/release.yml`, `.github/workflows/deps.yml`, `.github/workflows/nightly.yml`, `pubspec.yaml`, `lib/main.dart`, `lib/ui/shell/app_shell.dart`, `lib/data/settings/settings_store.dart`, `lib/ui/screens/settings/settings_pages.dart`, `lib/providers/player_providers.dart`, `linux/runner/my_application.cc`, `packaging/flatpak/com.freekmusic.player.yml` (`finish-args`).

## Task
- [ ] 159.1 Flutter all'ultima 3.47.x (D-728, passo a sé)
  - File: `.github/workflows/ci.yml`, `release.yml`, `deps.yml`, `nightly.yml` (ogni `FLUTTER_VERSION`), `pubspec.lock` se cambia, doc in `qualita-e-rilascio.md`.
  - Passi: 1) `flutter upgrade` locale e `flutter --version`; la versione CI deve essere uguale (la regola del commento in `ci.yml`); 2) `flutter pub get`, `flutter analyze`, `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`; 3) PR con solo questo cambio; 4) i goldens sono Linux: se il motore cambia il rendering, rigenerare **in questo passo** e dirlo.
  - Comando mirato: `flutter analyze` + test mirati di UI e goldens (`flutter test test/goldens`); la suite la esegue la CI
  - Fatto quando: CI verde (check «Analyze and test») con la nuova versione in tutti i workflow; `grep -rn "3.47.1" .github` vuoto.
- [ ] 159.2 Caratterizzazione di chiusura e impostazioni
  - File: `test/ui/app_shell_test.dart`, `test/ui/settings_index_test.dart`.
  - Passi: fissare che la chiusura oggi non è intercettata e le voci di Impostazioni › Avanzate (o dove vanno le opzioni desktop).
  - Comando mirato: `flutter test test/ui/app_shell_test.dart test/ui/settings_index_test.dart`
  - Fatto quando: verdi.
- [ ] 159.3 `window_manager`: dimensione e posizione (F-206)
  - File: `pubspec.yaml`, `lib/main.dart`, nuovo `lib/services/window/window_state.dart`, `settings_store.dart`, `linux/runner/my_application.cc` (compatibilità), test con adattatore finto.
  - Passi: 1) `flutter pub add window_manager` e controllare versione e licenza (la ricerca dice 0.7.1, MIT; ripetere la verifica); 2) (fuori dal backup, D-739) salva `getBounds` a ogni cambio (con ritardo), ripristina all'avvio; schermo cambiato o fuori campo → dimensione standard; 3) **Wayland: solo dimensione** (la posizione non è impostabile dall'app); 4) preferenza fuori dal backup; 5) il titolo della 158.5 non si rompe.
  - Comando mirato: `flutter test test/services/window/` + `flutter analyze` + `flutter build linux --debug`
  - Fatto quando: test: bounds salvati e ripristinati; bounds fuori schermo scartati; su Wayland nessuna chiamata a posizione.
- [ ] 159.4 `tray_manager ^0.8.3` e «Chiudi nella barra di sistema» (D-729)
  - File: `pubspec.yaml` (`tray_manager: ^0.8.3`; 0.9.x vuole Flutter 3.50), nuovo `lib/services/window/tray_service.dart`, `lib/main.dart`, `settings_pages.dart`, `settings_store.dart`, ARB (6 lingue via `scripts/arb_add.py`), `packaging/flatpak/com.freekmusic.player.yml`, CI apt (`libgtk-3-dev libx11-dev libxi-dev` già presenti per la build).
  - Passi: 1) icona con menu **Play/Pausa, Successivo, Mostra/Nascondi, Esci** (Linux: StatusNotifierItem, solo menu, nessun clic sull'icona); 2) opzione «Chiudi nella barra di sistema»: **accesa di default su Windows, spenta su Linux**; se la tray non è disponibile l'opzione non nasconde mai la finestra; 3) con l'opzione accesa la X nasconde (`setPreventClose` + `onWindowClose`), «Esci» chiude davvero con la chiusura pulita; 4) flatpak: provare `--talk-name=org.kde.StatusNotifierWatcher` in `finish-args` (dedotto, da verificare); 5) il menu usa gli stessi comandi del player.
  - Comando mirato: `flutter test test/services/window/ test/ui/settings_index_test.dart`
  - Fatto quando: test: default Windows vero e Linux falso; X con opzione accesa nasconde, spenta chiude; i quattro comandi del menu chiamano le azioni giuste.
- [ ] 159.5 `desktop_drop`: trascinare file (F-208)
  - File: `pubspec.yaml` (`desktop_drop`, versione compatibile col Flutter di 159.1; la ricerca dice 0.9.2, ≥ 3.47.7, Apache-2.0, `localPath` può essere null), nuovo `lib/ui/shell/drop_overlay.dart`, `app_shell.dart`, ARB.
  - Passi: 1) `DropTarget` sullo shell con velo «Rilascia per …» mentre si trascina; 2) file audio ricevuti → stesso percorso di «Apri con» (158.4, D-736: suonano subito, più file in coda nell'ordine); cartelle e file non audio ignorati con messaggio; `localPath` nullo → messaggio e `AppLog.w`; 3) nessun I/O pesante nel thread UI (lettura tag fuori dal thread UI come la scansione).
  - Comando mirato: `flutter test test/ui/drop_overlay_test.dart`
  - Fatto quando: test con file finti: audio accettato, non audio rifiutato, percorso nullo gestito.
- [ ] 159.6 Verifica dei pacchetti, flatpak e documenti
  - Passi: 1) `flutter pub deps` senza altri pacchetti nuovi oltre i tre; 2) `scripts/guardie.sh`; 3) `piattaforme.md` (finestra, tray, drop, limite Wayland e GNOME senza estensione AppIndicator); 4) `integration_test/desktop_flow_test.dart` ancora verde (la tray non si avvia nel test).
  - Comando mirato: `flutter analyze` + `git diff pubspec.yaml`
  - Fatto quando: nel diff di `pubspec.yaml` ci sono solo `window_manager`, `tray_manager`, `desktop_drop`.

## Tocca a te
- [ ] GNOME senza estensione AppIndicator: provare che la tray manchi e che l'app non si nasconda senza via d'uscita.
- [ ] Windows: tray e «Chiudi nella barra di sistema» su una macchina vera.
- [ ] Flatpak: permesso StatusNotifier e drop di file (percorsi `/run/user/UID/doc/`).

## Note di deviazione
