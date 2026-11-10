# Fase 0 — Setup del progetto

**Obiettivo:** progetto Flutter creato dentro `codecore_flutter/`, dipendenze installate, schermata
vuota che gira su Linux e si compila per Android. Nessuna logica di business.

**Stato dell'ambiente (verificato):** Flutter 3.47.1 in `~/flutter`, Rust/cargo 1.98 installati,
Android SDK in `~/Android/Sdk`. Windows: la build si fa solo da una macchina Windows con Visual Studio.

## Task

### 0.1 — Verifica toolchain
1. `flutter doctor -v` (usa il percorso `~/flutter/bin/flutter` se non è nel PATH).
2. Se manca l'SDK Android: `flutter config --android-sdk ~/Android/Sdk` poi `flutter doctor --android-licenses`
   (**serve l'utente**: chiedi di eseguirlo con `! flutter doctor --android-licenses`).
3. Per Linux desktop servono (chiedi all'utente di eseguirli, `sudo`):
   `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev mpv libsqlite3-dev`
**Verifica:** `flutter doctor` mostra ✓ per Flutter, Linux toolchain e Android toolchain (Chrome/Windows possono mancare).

### 0.2 — Creare il progetto
1. Da `codecore_flutter/` (cartella con già `docs/`, `CLAUDE.md`, `README.md`):
   `flutter create --org com.codecore --project-name codecore --platforms=android,linux,windows .`
2. Non sovrascrivere `README.md` e `CLAUDE.md` (se `flutter create` li tocca, ripristinali con `git checkout` o riscrivili: il contenuto è nei documenti).
3. In `android/app/build.gradle*`: lascia `minSdk` al valore di Flutter, ma verifica che sia **≥ 24**; imposta `applicationId "com.codecore.player"` se diverso.
**Verifica:** `flutter analyze` pulito sul template; `flutter run -d linux` apre la finestra demo.

### 0.3 — Dipendenze
Esegui, uno per volta, con `flutter pub add` (non modificare `pubspec.yaml` a mano per le versioni):
```
flutter pub add flutter_riverpod
flutter pub add drift drift_flutter path_provider path
flutter pub add just_audio just_audio_media_kit media_kit_libs_linux media_kit_libs_windows_audio
flutter pub add audio_service
flutter pub add audio_metadata_reader
flutter pub add file_picker permission_handler shared_preferences
flutter pub add dio crypto collection intl
flutter pub add --dev drift_dev build_runner
```
Aggiungi anche (fasi successive, ma meglio ora per un solo `pub get`):
`flutter pub add youtube_explode_dart` (fase 5).
In `pubspec.yaml` aggiungi sotto `flutter:` → `generate: true` (per l'l10n della fase 4) e le
dipendenze `flutter_localizations: {sdk: flutter}`.
**Verifica:** `flutter pub get` senza errori; `flutter analyze` pulito.
Se un pacchetto non risolve su una piattaforma, **fermati** e riportalo (vedi `99-rischi-e-fallback.md`).

### 0.4 — Scheletro cartelle e utilità
Crea le cartelle di `02-architettura.md` (vuote dove non serve ancora) e questi file:
- `lib/core/app_log.dart`: classe `AppLog` con metodi statici `d/i/w/e(String msg, [Object? err, StackTrace? st])`.
  In debug `debugPrint`; in release scrive su `<appSupportDir>/codecore.log`, con rotazione a 1 MB (tieni 2 file).
- `lib/core/platform.dart`: `bool get isAndroid`, `bool get isDesktop`, `Future<String> defaultMusicDir()` secondo la tabella di `02-architettura.md`.
- `lib/core/paths.dart`: `appSupportDir()`, `coversDir()` (la crea se manca) via `path_provider`.
- `lib/core/text_utils.dart`: `normalize`, `stripDiacritics` (tabella manuale per le accentate latine comuni), `sanitizeFileName` (vedi `04-specifiche-da-python.md` §7), `computeAlbumKey(...)` (vedi `03-modello-dati.md`).
- `test/core/text_utils_test.dart`: test per i casi elencati in `04` §7 e per `computeAlbumKey`.
**Verifica:** `flutter test` verde.

### 0.5 — `main.dart` e `app.dart`
1. `main()`: `WidgetsFlutterBinding.ensureInitialized()`;
   `if (Platform.isLinux || Platform.isWindows) JustAudioMediaKit.ensureInitialized();`
   poi `runApp(ProviderScope(child: CodecoreApp()))`.
2. `CodecoreApp`: `MaterialApp` con `useMaterial3: true`, tema scuro con `ColorScheme.fromSeed`, home = `Scaffold` con testo "Codecore".
3. `AppLog.i('avvio')` all'inizio.
**Verifica:** `flutter run -d linux` mostra la schermata; nessuna eccezione in console.

### 0.6 — Primo build Android
1. `flutter build apk --debug`.
2. Se l'utente ha un telefono collegato con debug USB: `flutter run -d <id>` e conferma che si apre.
**Verifica:** l'APK si genera (`build/app/outputs/flutter-apk/app-debug.apk`). Telefono opzionale in questa fase.

### 0.7 — `.gitignore` e commit locale (solo se l'utente lo chiede)
Il template porta già un `.gitignore` Flutter. Aggiungi `*.g.dart` **non** va ignorato (committa i file generati
di drift) — verifica che non sia escluso.

## Definition of Done
- [ ] `flutter analyze` e `flutter test` puliti
- [ ] App avviabile su Linux
- [ ] APK debug generato
- [ ] `AppLog`, `platform`, `paths`, `text_utils` presenti e testati
- [ ] `docs/PROGRESS.md` aggiornato
