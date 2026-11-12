# Qualità e rilascio

## Scopo

Questo documento dice come si verifica una modifica e come esce una versione. Copre i test, i golden, i workflow di CI, il versionamento, gli script di prestazioni e le regole per provare sui telefoni. Il lavoro autonomo per fasi ha un profilo suo: `.claude/obiettivo.md` (skill globale `/obiettivo`). Qui ci sono solo i punti di contatto.

## Mappa del codice

### Test

| Percorso | Cosa contiene |
|---|---|
| `test/core`, `test/data`, `test/services`, `test/providers` | Test di logica: utilità, DB drift, servizi, provider. |
| `test/jam` | Jam locale, della cassa e a distanza (cifratura inclusa). |
| `test/ui`, `test/theme` | Test di widget e di convenzione (`architecture_test.dart`, `no_stray_colors_test.dart`, `no_separator_literals_test.dart`). |
| `test/l10n` | `arb_test.dart`: le sei lingue hanno le stesse chiavi. |
| `test/goldens` | `*_golden_test.dart`, PNG di riferimento, `tolerant_comparator.dart`. |
| `test/live` | Prove contro la rete vera, attive solo con `CODECORE_LIVE=1`. |
| `test/fixtures`, `test/support` | Dati di prova e finti: `app_harness.dart` (`Harness`), `fake_backend.dart`, `fake_ytm.dart` e altri. |
| `integration_test/` | `app_flow`, `import`, `jam_crypto_bench`, `perf`, `playback`, `playlist` (`_test.dart`), con `support/app_driver.dart`. |

### Script (`scripts/`)

| Script | Uso |
|---|---|
| `guardie.sh` | Test di convenzione veloci (arb, separatori, architettura, colori) più i golden se il ramo tocca `lib/ui`. Gira come hook pre-push. |
| `integration.sh` | Lancia `app_flow`, `playback`, `playlist`, `import`, `perf` (usato dalla CI su emulatore). |
| `perf_device.py` | Costruisce un'app `.perf` e misura i frame sul telefono. Opzioni: `--label`, `--real`, `--only`, `--playback`, `--no-build`, `--apk`, `--no-push`, `--runs`. |
| `perf_library.py` | Rigenera `build/perf_library` (libreria di prova per `perf_device.py`). |
| `telefono.py` | Comandi adb per i telefoni di prova. |
| `shots.sh` | Schermate dal dispositivo. |
| `check_perf_labels.py` | Controlla le etichette delle misure di prestazioni (gira in CI e in `guardie.sh`). |
| `check_docs_links.py` | Controlla i link di `docs/guida`, `docs/architettura`, `docs/fasi`, `docs/00-INDICE.md` e `docs/storico/README.md`. |
| `live_summary.py` | Riassunto dei test live notturni. |
| `stream_times.py`, `gap_probe.py` | Analisi dei tempi di avvio dello stream e dei vuoti fra brani dal log. |
| `arb_add.py` | Aggiunge una chiave a tutti gli ARB. |
| `package-linux.sh`, `package-appimage.sh` | Pacchetti Linux. |
| `deps_report.sh`, `deps_report.py` | Rapporto sulle dipendenze (usato da `deps.yml`). |
| `pulizia-auto.sh`, `sorveglia.sh`, `build_len.py` | Pulizia, sorveglianza di comandi pesanti, lunghezza della build. |

### CI (`.github/workflows/`)

| File | Quando | Che cosa fa |
|---|---|---|
| `ci.yml` | Push su `master`, tag `v*`, PR, avvio a mano (`integration`) | Job `check`, `test-windows`, `build-*`, `integration-android`, `build-apple`. |
| `release.yml` | Tag `v*` o avvio a mano | Pacchetti per ogni piattaforma e pubblicazione. |
| `deps.yml` | Settimanale | Solo un rapporto sulle dipendenze. |
| notturno (test live) | Pianificato | `flutter test` su `test/live/*` (senza `curiosity_survey`). |

### Versione

| Dove | Cosa |
|---|---|
| `pubspec.yaml` | `version: 1.4.1+6` (nome e build). |
| `lib/core/app_info.dart` | `kAppVersion = '1.4.1'` (da tenere uguale a `pubspec.yaml`), `kReleaseRepo = 'iTzEmany/FreeKmusic'`. |

## Come funziona

### Strategia di test

- Un test per comportamento. Niente test di codice senza logica.
- In locale si lanciano solo i test toccati dalla modifica. La suite completa la esegue la CI.
- Prima di ogni PR: `flutter analyze` pulito e i test mirati verdi. Se la modifica tocca `lib/ui`, anche `scripts/guardie.sh`.
- I test usano `Harness` (`test/support/app_harness.dart`) con i finti di `test/support`: niente rete e niente audio vero.
- I test di prestazioni (`test/data/performance_*`, `performance_backup_test.dart`) hanno un budget. `CODECORE_PERF_MARGIN` lo allarga; la CI lo imposta a 4.

### Golden

- I golden girano solo su Linux (`if (!Platform.isLinux) return;`): i caratteri e il rendering cambiano da un sistema all'altro.
- Il comparatore (`tolerant_comparator.dart`) accetta fino allo 0,5% di pixel diversi.
- Si rigenerano con `--update-goldens` solo per un cambio visivo voluto (D-20) e solo per il file che fallisce. Poi si annullano con `git checkout` i PNG cambiati senza motivo.
- Gli errori finiscono in `test/goldens/failures`: la CI li carica come artefatto. In locale va ripulita con `pulizia.sh`.
- Su Linux senza schermo: `HOME=<scratch>/home env -u WAYLAND_DISPLAY GDK_BACKEND=x11 xvfb-run -a -s "-screen 0 1280x800x24" <comando>`.

### Test live

I test in `test/live/*` parlano con servizi veri e partono solo con `CODECORE_LIVE=1`. Il workflow notturno li esegue con un `yt-dlp` fissato e verificato, con `continue-on-error`, e scrive il riassunto con `scripts/live_summary.py`. Un rosso notturno è un segnale, non blocca nessuna PR.

### `ci.yml`

- `check` ("Analyze and test") è il check obbligatorio di `master`. Se la PR cambia solo documenti, salta la toolchain. Altrimenti controlla che `build_runner` e `gen-l10n` non producano differenze, lancia `check_docs_links.py` e `check_perf_labels.py`, poi `flutter analyze` e `flutter test`. Carica `test/goldens/failures` se i golden falliscono.
- `test-windows` dipende da `check`.
- `build-android`, `build-linux`, `build-windows` girano solo su tag o avvio a mano.
- `integration-android` gira solo a mano con l'input `integration`: emulatore API 34 e `scripts/integration.sh`.
- `build-apple` ("macOS / iOS (trial)") gira solo a mano, con `continue-on-error`: `flutter build macos --debug` e `flutter build ios --debug --no-codesign`. Serve a tenere compilabili i due runner, non produce una release.

### `release.yml`

| Job | Risultato |
|---|---|
| `linux` | zip, `.deb`, AppImage (artefatto `linux`). |
| `flatpak` | bundle Flatpak (artefatto `flatpak`). |
| `android` | Quattro APK: full e lite per ABI. Chiave dai segreti, senza segreti chiave di debug. Artefatto `android`. |
| `windows` | Installer Inno Setup `FreeKmusic-Setup-*.exe`, con yt-dlp e ffmpeg LGPL (artefatto `windows`). |
| `macos` | `.app` non firmato in `FreeKmusic-<versione>-macos.zip` (D-543). Senza yt-dlp né ffmpeg. |
| `publish` | Solo su tag `v*`. Scarica gli artefatti e li pubblica con `softprops/action-gh-release` e note generate. Dipende da tutti i job sopra. |

### Versionamento e tag

1. Alza `version` in `pubspec.yaml` e `kAppVersion` in `lib/core/app_info.dart` (devono coincidere).
2. Entra con una PR.
3. Un tag `v*` su `master` fa partire `release.yml`.

Se un job della release fallisce, il tag esiste ma la release no. È successo con v1.4.0 (D-538): si corregge e si pubblica una versione nuova (v1.4.1), non si riscrive il tag.

### Prestazioni sul telefono

`perf_device.py` costruisce una variante `.perf` (`applicationId` con suffisso `.perf`, `CODECORE_PERF=1`), la installa e misura i frame. Serve `JAVA_HOME` (`~/.jdks/jbr-17.0.14`). Le prove su 60–140 frame sono rumorose e "Pallino schede" è bimodale: per un confronto si usano due APK (A/B) e più `--runs`.

### Regole sui dispositivi

- Il volume del telefono resta a zero (D-535).
- Il Redmi è solo per l'app: mai toccare i file già presenti (D-502). Il Mi A3 si può disinstallare (con `-k`), mai cancellare i suoi file musicali. Il Motorola ha dati veri: non si usa per le prove.
- Dopo una prova si ripristina la rotazione dello schermo dell'utente.
- `uiautomator` vuole una UI ferma.
- Su Mi A3 si installa con `install -r -d`. Con lo schermo spento si blocca col PIN.
- Test d'integrazione su Linux: un file alla volta, e il driver chiama `JustAudioMediaKit.ensureInitialized()`.

### Lavoro autonomo

`/obiettivo` esegue il piano a fasi: una PR per fase, un commit per task, check "Analyze and test", poi `gh pr merge --auto --squash`. Il profilo (verifiche, aree a rischio per la review, regole dei telefoni) sta in `.claude/obiettivo.md`. Con `git config core.hooksPath .githooks` si attiva l'hook `pre-push` che lancia `guardie.sh`.

## Invarianti da non rompere

- Su `master` si entra solo con PR in auto-merge (squash). Il check obbligatorio è "Analyze and test".
- `kAppVersion` e `version` di `pubspec.yaml` coincidono.
- I golden si aggiornano solo per un cambio visivo voluto, e solo quelli che falliscono.
- I test non usano rete, orologio o audio veri, tranne `test/live` (con `CODECORE_LIVE=1`).
- Nessun `catch (_) {}` muto: si logga con `AppLog`.
- La suite completa non si lancia in locale: lo fa la CI.
- Sui telefoni di prova si tocca solo l'app (D-502), a volume zero (D-535).

## Come si estende

- **Nuovo test di convenzione**: aggiungilo in `test/ui` o `test/l10n` e mettilo nella lista `tests` di `scripts/guardie.sh`.
- **Nuovo golden**: un `*_golden_test.dart` in `test/goldens`, con il comparatore tollerante. Genera solo il PNG nuovo.
- **Nuovo test d'integrazione**: un file in `integration_test/` e il nome in `scripts/integration.sh`.
- **Nuovo pacchetto di release**: un job in `release.yml` con un artefatto, poi aggiungilo a `needs` di `publish`.
- **Nuova misura di prestazioni**: un'etichetta controllata da `check_perf_labels.py`.

## Trappole

- `perf_device.py --only`: «Album» e «Apri album» vogliono anche «Tutti i brani» nell'elenco (è lo scenario che apre la scheda), altrimenti esce con `nothing on screen matches '^Album$'`.
- `perf_test.dart` al secondo giro: `Bad state: No element` su «Tutti i brani» se la libreria da 3000 brani è ancora in caricamento; serve un `waitFor` prima del tap.
- `latestIs(x)` in `watch_with_countries_test.dart` ritorna subito se l'ultimo valore è già `x`: dopo una scrittura che deve dare lo stesso risultato, aspetta davvero la riesecuzione (contatore dello `_Spy` o attesa oltre i 300 ms).
- Test instabili noti: `download_tagger_test`, `shuffle_plus_test`, `online_playback_test`, `smart_playlists_test`, `daylist_provider_test`, `seek_characterization`, `now_playing_loading`, `performance_backup`. Prima di dare la colpa al cambiamento, rilancia.
- Su Windows sono instabili `stream_preparer_test` e i test di seek. `jam_gate_test` è rosso su Windows.
- `pr-attendi.sh` legge le esecuzioni duplicate annullate come rosse: controlla "Analyze and test" con `gh pr checks`. Accetta i minuti come `15m` o `15`; `sorveglia.sh` vuole l'unità (`5m`).
- `gradlew --stop` ferma anche le build degli altri.
- Mai `dart format` su una cartella intera: riformatta file non toccati. Formatta i file che hai cambiato.
- Un `FutureProvider` che fallisce può non riprovare come ti aspetti: vedi `../storico/gotchas.md`.
- La classe dell'activity sta nel namespace `com.codecore.player`, mentre l'applicationId è `com.freekmusic.player*`: `perf_device.py` avvia `{PKG}/com.codecore.player.MainActivity`.
- Scrivere uno scenario di `perf_device.py`: dipende dalla semantica del mini player (`mini()`, `setup_mini()`: se cambia il mini player vanno aggiornati); le liste non tornano in cima fra uno scenario e l'altro (`dev.top()` prima di un tap su una riga in alto); la lente di ricerca della Libreria resta aperta con la query, quindi ogni scenario parte da `to_library_top`.
- Chiusura dei lavori in background: ferma le shell e i monitor che non servono più; per aspettare usa comandi che escono da soli.

## Decisioni chiave

| Decisione | In breve |
|---|---|
| [D-20](../decisioni.md) | Golden rigenerati solo per un cambio visivo voluto. |
| [D-502](../decisioni.md) | Redmi di prova: solo l'app. |
| [D-535](../decisioni.md) | Volume del telefono a zero durante le prove. |
| [D-538](../decisioni.md) | v1.4.0 senza release: si pubblica v1.4.1. |
| [D-543](../decisioni.md) | Mac nella release: `.app` non firmato in zip. |

Vedi anche `.claude/obiettivo.md` (il vecchio elenco: `../storico/gotchas.md`).
