# Fase 16 — CI e test automatici

**Obiettivo:** ogni modifica viene controllata da sola: `flutter analyze` + `flutter test` + build di **APK, Linux e
Windows** su GitHub Actions, con artefatti scaricabili a ogni tag. Le prove che oggi si fanno a mano con `adb`
(scansione, riproduzione, playlist, importazione) diventano test d'integrazione ripetibili sul telefono; le
schermate principali hanno golden test veri; le prove «live» e il controllo delle dipendenze girano di notte o a
settimana senza che nessuno se ne ricordi.
**Prerequisiti:** Fasi 0–12 (base completa). Utili, non obbligatorie: Fasi 13–15 (più test da far girare).
**Principio:** la CI non fa nulla che l'app non faccia già in locale; nessun segreto nel repository. Il **push lo fa
l'utente**: l'agente prepara i file e verifica in locale quello che può (sintassi YAML, comandi), poi lascia in
«Tocca a te» la creazione del repository GitHub e il primo push.

> Nota: dal 2026-10-16 il repo non ha nessun remote (il vecchio `origin` sulla chiavetta USB è stato rimosso).
> Serve un repository GitHub (privato va benissimo) aggiunto come secondo remote (`github`).

## Decisioni
| Tema | Scelta |
|---|---|
| Servizio | GitHub Actions. Tre job: `check` (ubuntu: analyze + test), `build-android` + `build-linux` (ubuntu), `build-windows` (`windows-latest`, R6) |
| Versione Flutter | Fissata nel workflow (`subosito/flutter-action` con `flutter-version` uguale a quella locale, letta con `flutter --version` in 16.1); cache di pub e Gradle |
| Quando | `push` e `pull_request` su `master` → `check`; tag `v*` → anche le tre build con artefatti; `workflow_dispatch` per lanciarla a mano |
| Firma APK | In CI solo **APK debug** o release firmato con chiave di debug. Il keystore personale (`android/codecore-release.jks`) **non** va su GitHub; un eventuale segreto è una scelta dell'utente (fuori fase) |
| Test d'integrazione | Pacchetto `integration_test` dell'SDK, cartella `integration_test/`; si lanciano **sul telefono** in locale (`flutter test integration_test -d <id>`), non in CI (nessun emulatore in CI in questa fase) |
| Golden | `matchesGoldenFile` in `test/goldens/` con file PNG **committati**, generati solo su Linux (font e rendering cambiano tra sistemi): in CI girano solo sul job ubuntu |
| Test live | Restano dietro `CODECORE_LIVE=1`; workflow `nightly.yml` pianificato (cron) con yt-dlp standalone scaricato nel runner; un fallimento non blocca nulla, si legge l'esito |
| Dipendenze | Workflow settimanale: `flutter pub outdated --json` + `dart pub deps` → rapporto come artefatto e nel riepilogo del job |
| Prestazioni | DB sintetico da 50.000 brani in un test unitario con budget (estende `test/data/performance_test.dart`, oggi 20.000) |
| Pacchetti nuovi | `integration_test` (SDK Flutter, dev_dependency) **(da approvare con l'utente prima del task 16.5)**. Azioni GitHub: `actions/checkout`, `subosito/flutter-action`, `actions/setup-java`, `actions/upload-artifact`, `actions/cache` (versioni fissate) |

## Task

### 16.1 — Verifiche preliminari
1. Annota in PROGRESS: `flutter --version` (versione esatta e canale), `java -version` usata da Gradle,
   `git remote -v`, se esiste già un repository GitHub dell'utente (chiedere: **non** crearlo dall'agente).
2. Controlla che `flutter test` giri **senza** rete e senza `libmpv` (i test non devono dipendere dal desktop):
   lancia `flutter test` con `HOME` temporaneo e annota i test che falliscono o leggono file fuori dal repo.
3. Controlla che `flutter build linux` funzioni partendo da zero su ubuntu: elenca i pacchetti apt necessari
   (`clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev …`) leggendo `linux/CMakeLists.txt` e la doc di
   `media_kit_libs_linux`.
4. Windows: leggi `windows/CMakeLists.txt` e `media_kit_libs_windows_audio` per sapere se la build scarica DLL
   durante CMake (serve rete nel runner: va bene).
**Verifica:** note in PROGRESS. Se un test dipende dalla rete o da file locali, **fermati e riporta** prima di 16.2:
va corretto il test, non saltato in CI.

### 16.2 — Workflow `ci.yml`: analyze e test
**File:** `.github/workflows/ci.yml`
1. Job `check` su `ubuntu-latest`: checkout → Flutter fissato con cache → `flutter pub get` →
   `dart run build_runner build --delete-conflicting-outputs` → verifica che i `.g.dart` non cambino
   (`git diff --exit-code`) → `flutter analyze` → `flutter test --reporter expanded`.
2. `concurrency` per annullare le esecuzioni vecchie dello stesso ramo; `timeout-minutes: 30`.
3. I test di `test_shots/` restano fuori (non stanno in `test/`); quelli di `test/live/` si saltano da soli senza
   `CODECORE_LIVE`.
**Verifica:** `actionlint` se disponibile, altrimenti `python3 -c "import yaml,sys;yaml.safe_load(open(sys.argv[1]))"`
sul file. **Tocca a te:** creare il repo GitHub, `git remote add github …`, `git push github master` e controllare
che il job `check` sia verde.

### 16.3 — Build Android e Linux con artefatti
**File:** `.github/workflows/ci.yml`, eventuale `scripts/package-linux.sh` (solo se serve un parametro)
1. Job `build-android` (needs `check`, solo su tag `v*` o `workflow_dispatch`): `setup-java` (versione di 16.1),
   cache Gradle, `flutter build apk --release --split-per-abi` **firmato con la chiave di debug** se manca il keystore:
   leggi `android/app/build.gradle.kts` e assicurati che la mancanza di `codecore-release.jks` ricada su debug
   senza errore (oggi in locale c'è). Carica gli APK come artefatto.
2. Job `build-linux`: pacchetti apt di 16.1 → `flutter build linux --release` → `scripts/package-linux.sh` →
   artefatto `codecore-linux-x64.zip`.
**Verifica:** in locale, rinominando temporaneamente il keystore, `flutter build apk --debug` funziona ancora
(rimettilo subito al suo posto). **Tocca a te:** tag di prova `v1.1.1-ci` e push, artefatti scaricabili.

### 16.4 — Build Windows (`windows-latest`)
**File:** `.github/workflows/ci.yml`
1. Job `build-windows`: Flutter fissato → `flutter build windows --release` → zip di
   `build\windows\x64\runner\Release` → artefatto `codecore-windows-x64.zip`.
2. In questo job anche `flutter test` (scopre problemi di percorsi `\` vs `/`, finora mai provati su Windows):
   se falliscono test **solo su Windows**, annota in PROGRESS e correggi il codice (non il test) se il difetto è reale.
**Verifica:** YAML valido. **Tocca a te:** scaricare lo zip su un PC Windows, avviare `codecore.exe`, scansione di una
cartella e riproduzione di un brano; annotare in PROGRESS. È il primo vero avvio su Windows (vedi R6).

### 16.5 — Test d'integrazione sul telefono: base
**File:** `pubspec.yaml` (dev), `integration_test/app_flow_test.dart`, `integration_test/support/`
1. Approvazione del pacchetto, poi `integration_test: sdk: flutter` nelle dev_dependencies.
2. Avvio dell'app vera con DB in una cartella temporanea e cartella musicale preparata dal test
   (copia di `test/fixtures/sample.mp3` e `sample.flac` con nomi diversi); riusa le idee di
   `test/support/app_harness.dart` ma con il backend audio vero.
3. Flusso «scansione»: aggiungi la cartella via repository (il selettore di sistema non è automatizzabile),
   avvia la scansione, attendi la fine, verifica il numero di brani in «Tutti i brani».
**Verifica:** `flutter test integration_test/app_flow_test.dart -d <id-telefono>` verde (**Tocca a te** se il telefono
non è collegato: l'agente lo lancia solo se `adb devices` mostra un dispositivo). Anche `-d linux` deve funzionare.

### 16.6 — Test d'integrazione: riproduzione, playlist, importazione
**File:** `integration_test/playback_test.dart`, `integration_test/playlist_test.dart`, `integration_test/import_test.dart`
1. Riproduzione: tocco su un brano → `isPlayingProvider` vero entro 3 s, posizione che avanza, «successivo» cambia
   brano, pausa. Fine brano → avanzamento automatico (file di fixture corti).
2. Playlist: crea, aggiungi 3 brani, riordina, rinomina, elimina; i dati sopravvivono a un riavvio del `ProviderScope`.
3. Importazione con servizi **finti** (`YoutubeService` e downloader finti come in `test/services/import/`):
   CSV di fixture → playlist nell'ordine giusto; nessuna rete.
4. Annota nel documento cosa **non** si automatizza: selettore file di sistema, notifica e schermata di blocco,
   tasti delle cuffie, permessi al primo avvio (si concedono prima con `adb shell pm grant`).
**Verifica:** i tre file verdi su telefono e su `-d linux`. Script `scripts/integration.sh [device]` che li lancia in fila.

### 16.7 — Golden test delle schermate principali
**File:** `test/goldens/screens_golden_test.dart`, `test/goldens/*.png`, `test_shots/support/shot_harness.dart`
1. Leggi `test_shots/shots_test.dart`, `test_shots/support/shot_harness.dart`, `scripts/shots.sh` e la nota 11.1 in
   PROGRESS (copertine non caricate in fake async, font). Riusa `ShotSize`/`withShot` invece di riscriverli.
2. Promuovi 5 schermate: Libreria, Album, Now Playing, Impostazioni, Jam (finta), ciascuna a 100 % e 150 % di testo,
   telefono e desktop. Copertine: un `CoverImage` di prova con colore pieno (niente I/O) iniettato dal harness.
3. Font: carica Figtree e Unbounded dagli asset con `FontLoader` nel `setUpAll` (niente Liberation Sans di ripiego).
4. Golden generati su Linux con `flutter test --update-goldens test/goldens`; tolleranza minima con un
   `GoldenFileComparator` che accetta ≤ 0,5 % di pixel diversi (antialiasing). Su Windows i golden si saltano.
**Verifica:** `flutter test test/goldens` verde; cambiando un colore di `tokens.dart` il test fallisce (prova e annulla).

### 16.8 — Test live notturni e controllo delle dipendenze
**File:** `.github/workflows/nightly.yml`, `.github/workflows/deps.yml`, `scripts/deps_report.sh`
1. `nightly.yml` (cron giornaliero + `workflow_dispatch`): scarica il binario standalone di yt-dlp dalla release
   ufficiale (versione fissata, verificata con SHA-256 pubblicato), ffmpeg da apt, poi
   `CODECORE_LIVE=1 YTDLP=… flutter test test/live/`. `continue-on-error`; il riepilogo dice quali sorgenti
   (YouTube Music, iTunes, LRCLIB) hanno risposto.
2. `deps.yml` (settimanale): `scripts/deps_report.sh` → `flutter pub outdated --json` trasformato in tabella
   markdown (pacchetto, attuale, risolvibile, ultima) nel `$GITHUB_STEP_SUMMARY`; segnala i pacchetti con
   advisory (`dart pub get` li stampa) in rosso. Nessun aggiornamento automatico.
**Verifica:** `scripts/deps_report.sh` in locale produce la tabella. YAML valido.

### 16.9 — Profilo prestazioni su 50.000 brani
**File:** `test/data/performance_test.dart` (o `performance_50k_test.dart`), `docs/PROGRESS.md`
1. DB in memoria con 50.000 brani sintetici (2.000 album, 800 artisti, generi vari) inseriti in batch.
2. Budget (JIT, in CI con margine ×2): ricerca testo < 80 ms, `watchAlbums` < 150 ms, `watchArtists` < 150 ms,
   prima pagina di «Tutti i brani» < 300 ms, `liteEntries` (import) < 400 ms.
3. Avvio: tempo di apertura del DB + prima query della Home su file reale da 50.000 righe (cartella temporanea).
4. Se un budget salta: annota la query lenta e **proponi** un indice in PROGRESS; non cambiare lo schema in questa fase.
**Verifica:** test verde in locale; numeri annotati in PROGRESS accanto a quelli da 20.000 della fase 7.5.

### 16.10 — Rifinitura, documentazione e prova a mano
1. README: badge della CI, come scaricare gli artefatti, come lanciare `scripts/integration.sh`.
2. `docs/02-architettura.md`: sezione «CI e test» (job, cartelle `integration_test/`, `test/goldens/`, test live).
3. `docs/99-rischi-e-fallback.md`: R34–R36 (sotto).
4. Rimuovi da `docs/99` la frase «Windows non compilabile da Linux» solo se 16.4 è verde.
**Tocca a te:** primo push su GitHub, tag di prova, Windows avviato dallo zip, integrazione sul Mi A3.

## Fuori da questa fase
Emulatore Android in CI, firma release in CI con segreti, pubblicazione automatica delle release, build macOS/iOS
(fase 26), pacchetti AppImage/.deb/installer (fase 26), aggiornamento automatico delle dipendenze.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R34 | Golden diversi tra macchine (font, antialiasing, versione Flutter) | Generati e confrontati solo su Linux con Flutter fissato; tolleranza 0,5 %; font dagli asset |
| R35 | Test verdi in locale e rossi in CI (rete, HOME, percorsi, libmpv) | 16.1 trova le dipendenze nascoste; i test non toccano rete né cartelle dell'utente |
| R36 | YouTube blocca i runner GitHub (IP dei datacenter) nei test live | I live sono informativi (`continue-on-error`); la verità resta la prova a mano dal PC di casa |

## Definition of Done
- [ ] `ci.yml`: analyze + test su ogni push; APK, Linux e Windows come artefatti su tag
- [ ] Prima build Windows avviata davvero su un PC Windows (o annotato perché no)
- [ ] `integration_test/`: scansione, riproduzione, playlist, importazione con finti, verdi su telefono e Linux
- [ ] Golden di 5 schermate a 100 % e 150 %, committati e verificati in CI
- [ ] Test live notturni e rapporto settimanale delle dipendenze attivi
- [ ] Budget prestazioni su 50.000 brani misurati e annotati
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
