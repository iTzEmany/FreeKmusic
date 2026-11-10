# Fase 26 — Distribuzione: pacchetti, installer, APK più leggero, aggiornamenti, guida utente

**Obiettivo:** installare Codecore senza compilarlo: **AppImage / .deb / Flatpak** su Linux, **installer** su Windows
con yt-dlp e ffmpeg inclusi, APK Android più piccoli (uno per ABI), un **avviso di nuova versione** rispettoso della
privacy, una valutazione onesta di **F-Droid** e di **macOS/iOS**, e una **guida utente** con immagini.
**Prerequisiti:** Fase 16 (CI GitHub Actions con build Linux/Windows/APK e artefatti ai tag), Fase 14 (yt-dlp
gestito dall'app su desktop: percorso del binario scelto dall'app, controllo di versione).
**Principio:** uso personale, niente store a pagamento né firme commerciali obbligatorie. Le release sono costruite
dalla CI a partire da un tag; i segreti (keystore Android `android/codecore-release.jks`, password) stanno **solo**
nei *secrets* del repository, mai in chiaro nel codice o nei log. La rete per gli aggiornamenti parte solo se
l'utente lo chiede o se attiva l'opzione (spenta di default, regola 9).

## Decisioni
| Tema | Scelta |
|---|---|
| Linux | Tre formati dallo stesso bundle `flutter build linux --release`: **AppImage** (include `libmpv` e dipendenze, per «scarica e lancia»), **.deb** (`Depends: libmpv2 | libmpv1`, per Debian/Ubuntu), **Flatpak** (manifest con runtime `org.freedesktop.Platform`, libmpv come modulo). Lo zip di `scripts/package-linux.sh` resta |
| yt-dlp su Linux | AppImage/.deb: yt-dlp **non** incluso, lo gestisce l'app (fase 14). Flatpak: i processi esterni del sistema non sono visibili → yt-dlp standalone e ffmpeg **dentro** il Flatpak (`/app/bin`), oppure `flatpak-spawn --host` (richiede un permesso ampio: scartato) |
| Windows | **Inno Setup** (installer `.exe` per utente, senza diritti di amministratore) con `yt-dlp.exe` e `ffmpeg.exe` nella cartella dell'app. MSIX scartato: richiede un certificato di firma attendibile |
| Licenze | yt-dlp: Unlicense. ffmpeg: si include solo una build **LGPL** (o GPL dichiarata) con testo di licenza e link ai sorgenti nell'installer e in «Informazioni → Licenze» (`LicenseRegistry` come per i font) |
| APK | `flutter build apk --release --split-per-abi` (arm64-v8a, armeabi-v7a) + `minifyEnabled`/`shrinkResources` con regole ProGuard per `youtubedl-android`, `audio_service`, `media_kit`. Python/QuickJS/ffmpeg di `youtubedl-android` **restano** finché il download è attivo (note 5.9 in PROGRESS) |
| Flavor senza download | Flavor Android `lite` senza `youtubedl-android` (`kEnableYoutube = false` via `--dart-define`), per F-Droid e per chi vuole un APK piccolo |
| Aggiornamenti | «Controlla aggiornamenti» in Impostazioni → Informazioni: legge l'ultima release dall'API pubblica di GitHub (`/repos/<owner>/<repo>/releases/latest`), confronta con `kAppVersion`, mostra note e link. Opzione «Controlla all'avvio» **spenta** di default. Nessun download/installazione automatica |
| Repository | Owner/nome in una costante `kReleaseRepo` (`lib/core/app_info.dart`); vuota = funzione nascosta. Oggi `origin` è un repository locale: la fase 16 crea quello su GitHub |
| F-Droid | Solo **valutazione** documentata: build riproducibile, nessun blob binario. Il flavor completo non è accettabile (yt-dlp/ffmpeg precompilati, YouTube); si valuta il flavor `lite` |
| macOS / iOS | Solo **build di prova** sui runner `macos-latest` della CI (fase 16): `flutter build macos` e `flutter build ios --no-codesign`. Nessuna release, nessuna firma Apple |
| Guida utente | `docs/guida/` in Markdown, una pagina per funzione, immagini dai golden/scatti di `test_shots/` |
| Pacchetti nuovi | Nessun pacchetto Dart. Strumenti di build nella CI: `appimagetool`/`linuxdeploy`, `flatpak-builder`, Inno Setup (`iscc`) **(da approvare con l'utente prima del task 26.1)** |

## Task

### 26.1 — Verifiche preliminari
1. Su una copia della CI (branch di prova): installa `linuxdeploy` + plugin, `appimagetool`, `flatpak-builder` su
   `ubuntu-latest`, Inno Setup su `windows-latest` (preinstallato o con `choco install innosetup`). Annota versioni.
2. Scegli la build di ffmpeg per Windows e verifica la licenza (file `LICENSE`/`README` della build, configurazione
   `--enable-gpl` sì/no). Annota in PROGRESS.
3. Misura oggi: APK release universale, APK per ABI, bundle Linux, cartella Windows.
4. Verifica che la fase 14 cerchi yt-dlp/ffmpeg **anche** nella cartella dell'eseguibile (Windows) e in `/app/bin`
   (Flatpak). Se no, annota il punto da cambiare in 26.4/26.3.
**Fermati** se servono strumenti non approvati o se la licenza di ffmpeg non è chiara.
**Verifica:** note in PROGRESS con dimensioni e versioni.

### 26.2 — AppImage e .deb
**File:** `scripts/package-linux.sh` (nuove opzioni `--appimage`, `--deb`), `packaging/linux/codecore.desktop`,
`packaging/linux/deb/control.in`, `.github/workflows/release.yml`
1. `.desktop` e icona condivisi dai tre formati (oggi generati inline dallo script Python).
2. AppImage con `linuxdeploy`: bundle + `libmpv.so*` e dipendenze; `AppRun` imposta `LD_LIBRARY_PATH`.
3. `.deb`: `/opt/codecore/`, collegamento in `/usr/bin/codecore`, `.desktop` in `/usr/share/applications/`,
   `Depends: libmpv2 | libmpv1`, versione da `pubspec.yaml`.
4. CI: ai tag `v*` pubblica zip, AppImage e .deb come artefatti della release.
**Verifica:** la CI produce i file; `dpkg-deb --info` corretto. **Tocca a te:** AppImage avviata su un Linux senza
`libmpv` installato; `.deb` installato e disinstallato su Ubuntu.

### 26.3 — Flatpak
**File:** `packaging/flatpak/com.codecore.player.yml`, `packaging/flatpak/com.codecore.player.metainfo.xml`,
`release.yml`
1. Runtime `org.freedesktop.Platform` (versione recente), moduli: libmpv (da sorgente), bundle Flutter, yt-dlp
   standalone e ffmpeg (estensione `org.freedesktop.Platform.ffmpeg-full` o modulo).
2. Permessi minimi: `--share=network`, `--socket=pulseaudio`, `--socket=wayland`/`fallback-x11`,
   `--filesystem=xdg-music`; selettore file via portal (già usato).
3. Discovery UDP e server LAN funzionano con `--share=network` (verificare).
4. Bundle `.flatpak` come artefatto (nessuna pubblicazione su Flathub in questa fase).
**Verifica:** `flatpak-builder` riuscito in CI. **Tocca a te:** installare il bundle, scansione di `~/Music`,
riproduzione, download da YouTube, invio LAN al telefono.

### 26.4 — Installer Windows
**File:** `packaging/windows/codecore.iss`, `release.yml`, `lib/main.dart` (registrazione della licenza ffmpeg)
1. Script Inno Setup: installazione per utente in `%LOCALAPPDATA%\Programs\Codecore`, collegamenti Start/desktop,
   disinstallazione che **non** cancella i dati in `%APPDATA%` (si chiede).
2. Copia di `yt-dlp.exe`, `ffmpeg.exe` e relative licenze accanto a `codecore.exe`.
3. Testo di licenza ffmpeg aggiunto a `LicenseRegistry`.
4. Versione dell'installer da `pubspec.yaml`.
**Verifica:** CI `windows-latest` produce `Codecore-Setup-<versione>.exe`. **Tocca a te (PC Windows):** installare,
avviare, scansione, riproduzione, download YouTube senza yt-dlp di sistema, tasti multimediali, disinstallare.

### 26.5 — APK più leggero e flavor `lite`
**File:** `android/app/build.gradle.kts`, `android/app/proguard-rules.pro`, `lib/core/constants.dart`, `release.yml`
1. `kEnableYoutube` da `bool.fromEnvironment('CODECORE_YOUTUBE', defaultValue: true)`.
2. Flavor `full` (oggi) e `lite` (senza le dipendenze `youtubedl-android`, `MainActivity.kt` senza il canale
   `codecore/ytdlp` → codice del canale in un sorgente solo del flavor `full`).
3. `isMinifyEnabled = true`, `isShrinkResources = true` in release; regole ProGuard verificate con una build e un
   avvio (nessun crash di riflessione).
4. CI: APK `full` e `lite` per ABI, firmati con il keystore dai *secrets* (`base64` → file temporaneo, mai stampato).
**Verifica:** tabella dimensioni prima/dopo in PROGRESS; `flutter test` verde con `CODECORE_YOUTUBE=false`.
**Tocca a te:** installare `full` arm64 (aggiornamento sopra quello esistente, stessa firma) e `lite`.

### 26.6 — Avviso di aggiornamento
**File:** `lib/services/online/update_checker.dart`, `settings_screen.dart`, `settings_store.dart`
(`checkUpdatesOnStart`, default `false`), `lib/core/app_info.dart` (`kReleaseRepo`), ARB (+ test)
1. `compareVersions(String a, String b)` (semver semplice, `v` iniziale ignorata) — logica pura.
2. `UpdateChecker.latest()` con `WebClient` (timeout e `User-Agent` dell'app); 403/429 di GitHub → messaggio «riprova
   più tardi», nessun ritento automatico.
3. Impostazioni → Informazioni: «Controlla aggiornamenti», esito con versione, note (testo semplice) e indirizzo
   copiabile (come per exportify.net: niente `url_launcher`).
4. Con l'opzione attiva: al più un controllo al giorno all'avvio, banner non invadente.
**Test:** `compareVersions` (8 casi), checker con client finto (nuova, uguale, errore).

### 26.7 — Valutazione F-Droid
1. Prova a costruire il flavor `lite` in un container pulito con `fdroidserver` (`fdroid build` su una ricetta
   locale `packaging/fdroid/com.codecore.player.yml`) e verifica la riproducibilità (due build → stesso hash, oppure
   annota le differenze).
2. Elenca i blocchi: dipendenze non libere, binari precompilati (font OK: OFL), funzioni «anti-feature».
**Verifica:** sezione «F-Droid» in PROGRESS con esito (fattibile / bloccato da …). Nessuna richiesta di inclusione
senza l'accordo dell'utente.

### 26.8 — Build di prova macOS / iOS
**File:** `.github/workflows/ci.yml` (job manuale `workflow_dispatch` su `macos-latest`)
1. `flutter create --platforms=macos,ios .` solo se l'utente lo approva (aggiunge cartelle): **fermati e chiedi**.
2. Job: `flutter build macos --debug` e `flutter build ios --debug --no-codesign`; annota errori (plugin non
   supportati: `media_kit_libs_*`, `youtubedl-android` solo Android, `audio_service` su macOS).
**Verifica:** esito del job annotato in PROGRESS; nessun codice di prodotto cambiato per Apple in questa fase.

### 26.9 — Guida utente
**File:** `docs/guida/README.md`, `docs/guida/<funzione>.md` (libreria, player, playlist, importazione, download,
condivisione e Jam, backup, podcast, impostazioni), `docs/guida/img/`
1. Una pagina per funzione: a cosa serve, passi numerati, limiti, avvisi legali (YouTube) dove servono.
2. Immagini generate dai golden/scatti (`scripts/shots.sh`, `test_shots/`), a 100 %, in tema `notte`.
3. Il README rimanda alla guida e alla pagina delle release.
**Verifica:** tutti i link interni validi (controllo con uno script in `scripts/`), immagini < 300 KB l'una.

### 26.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es per le stringhe nuove (aggiornamenti).
2. `docs/02-architettura.md` (packaging, flavor, `update_checker`), `docs/99-rischi-e-fallback.md` (R66–R69),
   README («Installare» con i nuovi formati).
3. Versione `1.2.0` in `pubspec.yaml` e `kAppVersion`; tag `v1.2.0` → release completa dalla CI.
**Tocca a te:** scaricare dalla release e installare su Linux (AppImage + .deb), Windows (installer), Android
(`full` arm64), controllare «Controlla aggiornamenti» con una release finta più nuova.

## Fuori da questa fase
Pubblicazione su Play Store, Flathub, Microsoft Store, F-Droid ufficiale (solo valutazione), firme Apple e release
macOS/iOS, aggiornamento automatico che scarica e installa, Snap.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R66 | Licenza della build ffmpeg incompatibile o non chiara | Solo build con licenza verificata (26.1), testo di licenza incluso; altrimenti ffmpeg non incluso e conversione MP3 disattivata su Windows |
| R67 | Flatpak senza yt-dlp/ffmpeg funzionanti (sandbox) | Binari dentro `/app/bin` e percorso cercato dalla fase 14; altrimenti Flatpak senza download, dichiarato |
| R68 | Keystore esposto o perso (APK non aggiornabili) | Solo nei *secrets* della CI, mai stampato; backup offline del file (già annotato in fase 7) |
| R69 | ProGuard rompe plugin con riflessione (crash in release) | Regole esplicite, avvio della release in CI su emulatore o a mano prima del tag; piano B: `minify` spento |

## Definition of Done
- [ ] Release dalla CI con zip, AppImage, .deb, Flatpak, installer Windows, APK per ABI (`full` e `lite`)
- [ ] Installer Windows con yt-dlp e ffmpeg e licenze incluse
- [ ] APK release più piccolo (dimensioni annotate), firmato con il keystore dai *secrets*
- [ ] «Controlla aggiornamenti» manuale; opzione all'avvio spenta di default
- [ ] Esiti F-Droid e macOS/iOS documentati
- [ ] Guida utente in `docs/guida/` con immagini
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
