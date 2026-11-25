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
| `ci.yml` | Push su `master`, tag `v*`, PR, avvio a mano (`integration`) | Job `check`, `test-windows`, `build-*`, `integration-android`, `integration-linux`, `build-apple`. `integration-linux` (non bloccante, D-733): `integration_test/desktop_flow_test.dart` sull'app Linux vera sotto Xvfb (barra laterale, scansione, play, tasto destro, selezione, scorciatoie, ridimensionamento); saltato sulle PR di sola documentazione; resta fuori dai check obbligatori di `master` finché non ha due settimane verdi. |
| `release.yml` | Tag `v*` o avvio a mano | Pacchetti per ogni piattaforma e pubblicazione. |
| `deps.yml` | Settimanale | Solo un rapporto sulle dipendenze. |
| notturno (test live) | Pianificato | `flutter test` su `test/live/*` (senza `curiosity_survey`). |

### Versione

| Dove | Cosa |
|---|---|
| `pubspec.yaml` | `version: <nome>+<build>` (da alzare a ogni rilascio, nella PR che lo prepara). |
| `lib/core/app_info.dart` | `kAppVersion` (da tenere uguale alla `version` di `pubspec.yaml`), `kReleaseRepo = 'iTzEmany/FreeKmusic'`. |

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
- Taglie (`ShotSize` in `test_shots/support/shot_harness.dart`): `phone` 360×800 e `desktop` 1280×800 sono quelle di `ShotSize.values`, su cui girano i golden storici; `desktop1000/1440/1920` (altezza 900) servono solo a `desktop_widths_golden_test.dart` (rete del refactor desktop, fase 150: 9 schermate × 3 larghezze più 6 `phone360_*`).
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

### Aggiornamento dall'app e Release
- L'aggiornamento dall'app funziona solo con APK firmati con la chiave della Release (D-569): una build di debug o locale dà «Firma diversa» e non si installa.
- Funziona solo con asset che hanno il `digest` (SHA-256) nella Release di GitHub; senza, l'app apre il browser.
- I nomi degli asset in `release.yml` sono un contratto con `pickUpdateAsset` (`lib/services/update/update_target.dart`): `freekmusic-{full,lite}-<abi>-release.apk`, `FreeKmusic-Setup-*.exe`, `freekmusic-*-x86_64.AppImage`, `freekmusic_*_amd64.deb`, `freekmusic-<versione>.flatpak` (il vecchio `freekmusic.flatpak` resta accettato), `freekmusic-linux-x64.zip`, `FreeKmusic-*-macos.zip`. Cambiarli rompe l'aggiornamento: aggiorna anche `test/services/update/update_target_test.dart`.

### Linux: la glibc del runner è il minimo (fase 134)
- L'AppImage include le librerie di libmpv prese dal sistema che la costruisce: la glibc del runner diventa la più vecchia su cui parte. Per questo i job Linux di `release.yml` e `ci.yml` sono fissati su `ubuntu-24.04` (glibc 2.39), non `ubuntu-latest`: la 1.6.3, costruita su glibc 2.43, non partiva su Ubuntu 24.04. Non scendere sotto 24.04: lì `libmpv.so.2` non c'è.
- `scripts/package-appimage.sh` non include le librerie che ogni desktop ha (glibc, X11, GL, GTK, glib, pango, cairo…): la lista confronta il nome seguito da `.` o `-` (`libglib-2.0.so.0`). Zip e .deb non includono librerie di sistema.
- Controllo rapido prima di pubblicare: `for f in <AppDir>/usr/lib/*; do objdump -T "$f" | grep -o 'GLIBC_2\.[0-9]*'; done | sort -t. -k2 -n -u | tail -1` deve dare al massimo `GLIBC_2.39`.

### Versionamento e tag

1. Alza `version` in `pubspec.yaml` e `kAppVersion` in `lib/core/app_info.dart` (devono coincidere).
2. Entra con una PR.
3. Il file `release-notes/<versione>.md` (formato in `release-notes/README.md`, D-711) si scrive nella stessa PR del bump: `master` è protetto e l'app lo legge dagli asset (D-741), quindi non si può aggiungere dopo. Lo esige `test/core/app_version_test.dart` (dalla 1.7.0 esclusa).
   Senza il file il job `notes` fa fallire la release prima delle build; `publish` lo mette in cima alla Release. L'app mostra solo quel blocco.
4. Un tag `v*` su `master` fa partire `release.yml`.

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

### Worker delle segnalazioni

Il Worker Cloudflare che trasforma una segnalazione anonima in una issue GitHub (etichetta `da-triage`) vive in `tools/report-worker/` ([D-701](../decisioni.md)). Accetta solo il media type `application/json` (parametri e maiuscole ammessi, 415), corpo massimo 32 KB con `content-length` decimale obbligatorio (413), `cf-connecting-ip` obbligatorio (400); valida titolo (normalizzato), corpo e versione, togliendo da titolo e corpo i caratteri di controllo e di formato (RTL override, zero-width; nel corpo restano a capo e tab). Limita a 5 invii l'ora per IP (IPv6 sul /64, `::ffff:a.b.c.d` come IPv4) e a 100 al giorno in totale (429): il tetto giornaliero conta solo le richieste che passano il limite per IP, così un solo IP non lo brucia per tutti; non inoltra l'IP a GitHub. Le `@` nel titolo e nel corpo diventano `@` + U+200B, così GitHub non notifica nessuno. La chiamata a GitHub scade in 8 s; errori e risposte senza `html_url` sono 502 generici, repo o token mancanti 500. L'etichetta `da-triage` esiste già (creata il 23/11). `shortcut:` i limiti stanno in memoria per isolate (deboli fra istanze e riavvii): un vero 5/ora richiede un Durable Object, da usare se si vede abuso. Si prova con `cd tools/report-worker && node --test` (GitHub finto, niente rete). La CI li esegue nel job «Analyze and test» (passo «Report Worker tests», node è già su ubuntu-latest) e `test/core/report_worker_contract_test.dart` verifica che i limiti di `index.js` (titolo, corpo, richiesta, regex della versione) e il repo di `wrangler.toml` coincidano con le costanti Dart (`issue_report.dart`, `kReleaseRepo`). Si pubblica con `cd tools/report-worker && npx wrangler deploy`, e lo fa l'utente. Il token GitHub è solo il segreto `GITHUB_TOKEN` del Worker (`wrangler secret put`): mai nel repo né nell'APK.

### Pagina di condivisione (fase 145)

`docs/site/` (`index.html` con CSS e JS inline, `fragment.js` che decodifica il frammento: base64url, gzip, limite 64 KB, controlli FK1) è pubblicata su GitHub Pages da `.github/workflows/pages.yml` a ogni push su `master` che tocca `docs/site/**` (o a mano). Nessuna richiesta di rete con i dati del frammento. La prova è `node --test test/site/fragment.test.mjs` (il test sta fuori da `docs/site`, che è pubblicata) (passo «Share page tests» di «Analyze and test»); in `ci.yml` `docs/site/*` non conta come sola documentazione.

### Metriche di arrivo della grande revisione (fase 147)

Le metriche di `rete.md` (storico, fasi 135-146) sono tutte rispettate: 258 test mirati verdi, più i `grep` sul codice (nessun `color: cc.bg` in Tutti i brani, una sola barra di download, un solo punto d'invio della segnalazione, le 8 pagine con una sola testata); l'unica deviazione è nota (139.4: altri 4 file osservano `downloadsProvider` solo per trovare l'`item` della riga). Accessibilità delle schermate nuove verificata con `uiautomator` sul Mi A3 e con i due test dedicati; esiti per fase in `fasi/fase-147-verifica-finale.md`. In CI «Analyze and test» lancia anche i test `node` del Worker (`tools/report-worker/test/`) e della pagina di condivisione (`test/site/`). Restano all'utente le prove su telefono dopo il tag v1.7.0 (stessa fase, «Tocca a te»).

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
