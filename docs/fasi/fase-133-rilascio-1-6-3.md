# Fase 133 — Rilascio 1.6.3

## Obiettivo
Uscita della versione 1.6.3 con il video karaoke (fase 131) e l'aggiornamento dall'app (fase 132): CI di tutti i
sistemi verde, tag, Release completa, poi la prova reale dell'aggiornamento. Parte solo con 131 e 132 fuse (D-650).

## Riferimenti
D-638, D-648, D-650, D-655, D-657, D-659, D-660 (come D-544 e D-553).

**Regole della notte:** CI rossa e non riparabile → niente tag né Release, tutto pronto per il risveglio (D-657); se dopo 6 ore di lavoro questa fase non è partita, fermati prima del tag (D-659). Specifica: [`../storico/feature/feature-karaoke-video-e-aggiornamenti.md`](../storico/feature/feature-karaoke-video-e-aggiornamenti.md) (R-274, R-268..R-271).
Documento d'area: `../architettura/qualita-e-rilascio.md`. Workflow: `.github/workflows/ci.yml` (job `check`,
`test-windows`, `build-android`, `build-linux`, `build-windows`, `integration-android`, `build-apple`) e `release.yml`
(job `linux`, `flatpak`, `android`, `windows`, `macos`, `publish`).

## Task
- [x] 133.1 Versione e CI di tutti i sistemi (R-274)
  - File: `pubspec.yaml` (`version: 1.6.3+12`).
  - Passi: ramo da `origin/master`, PR con auto-merge; dopo la fusione `gh workflow run ci.yml --ref master` e attesa.
  - Comando: `gh run list --workflow ci.yml -L 1 --json conclusion,headSha` → `success` su ogni job; CI rossa → `github-ci`.
  - Fatto quando: `ci.yml` su `master` con la 1.6.3 è verde in tutti i job.
- [x] 133.2 Tag e Release (R-274)
  - Passi: `git tag v1.6.3 <sha di master>` e `git push origin v1.6.3` (autorizzato, D-638); attesa di `release.yml`.
  - Comando: `gh run list --workflow release.yml -L 1` → `success`; `gh release view v1.6.3 --json assets -q '.assets[].name'` contiene i 10 file: `freekmusic-{full,lite}-{arm64-v8a,armeabi-v7a}-release.apk`, `FreeKmusic-Setup-1.6.3.exe`, `freekmusic-linux-x64.zip`, `freekmusic_1.6.3_amd64.deb`, `freekmusic-1.6.3-x86_64.AppImage`, `freekmusic.flatpak`, `FreeKmusic-1.6.3-macos.zip`; ogni asset ha il `digest`.
  - Fatto quando: Release pubblicata (non bozza, non pre-release) con tutti i file.
- [ ] 133.3 Prova reale dell'aggiornamento (rischio F-7, D-648)
  - Android (Mi A3, volume 0): build release locale del codice di `master` con versione finta **1.6.2+11** (`--build-name=1.6.2 --build-number=11`), firmata con `android/key.properties` (la chiave della Release, D-569) e flavor full, installata con `adb install -r` (dati del telefono intatti); Impostazioni › Aggiornamenti › «Aggiorna» → permesso → installer → l'app riparte alla 1.6.3 e la libreria c'è ancora. Prova del messaggio «Firma diversa» con la build di debug.
  - Linux: AppImage costruita in locale dal codice di `master` con versione finta 1.6.2 (`scripts/package-appimage.sh`; quella della Release 1.6.2 non ha «Aggiorna»), in una cartella di prova → «Aggiorna» → il file diventa la 1.6.3 e l'app si riavvia.
  - Dopo: telefono come trovato (rimetti la build che c'era, `adb uninstall -k` se serve), cartelle di prova e screenshot cancellati.
  - Fatto quando: i due esiti (versione prima e dopo, libreria intatta) sono nelle «Note di deviazione».

## Tocca a te
- Windows: con la 1.6.3 installata, la prossima Release (o una build 1.6.2 di prova) deve aggiornarsi con «Aggiorna» e riaprirsi da sola (F-8). Io non ho una macchina Windows.
- Da qui in poi chi ha la 1.6.2 aggiorna a mano un'ultima volta: dalla 1.6.3 basta «Aggiorna».

## Note di deviazione
- 133.1: il primo `ci.yml` completo su master 1.6.3 (run 44448459012) era rosso solo in «Test (Windows)»: i due test dell'AppImage controllano chmod e una cartella in sola lettura (POSIX, ora `skip` su Windows) e il test del gate in streaming controllava il caricamento dopo un solo giro della coda di eventi (lento sul runner Windows). Corretto con la PR #204. Il `ci.yml` completo verde (tutti i job, Windows incluso; «Integration» parte solo con l'input `integration`) è quello sul ramo della correzione (run 44455002132): l'albero di master dopo la fusione è identico (`677893d6`), quindi il tag non ha aspettato un secondo giro su master (run di traccia 44457788682).
- 133.2: tag `v1.6.3` su `522cd435`; `release.yml` verde in 16 min; Release pubblicata (non bozza, non pre-release) con i 10 file, ognuno con il `digest` sha256 (letto dall'API: `gh release view --json assets` non mostra il campo).
- 133.3: la build «finta 1.6.2» non si fa con `--build-name`: il controllo confronta `kAppVersion`, quindi le build di prova sono state fatte dal master prima del cambio di versione (b66d97f6).
- 133.3 Android, «Firma diversa» (build debug 1.6.2 sul Mi A3): trovata la 1.6.3, «Aggiorna» scarica l'APK full arm64 (96 MB, ~20 min con rete lenta), poi «Firma diversa» col testo previsto. Nota: la firma dell'archivio si può leggere solo a download finito; avanzamento e riga del file stanno sotto le note lunghe e vanno cercati scorrendo.
- 133.3 Android, aggiornamento vero: **non fatto**. Dopo `pm uninstall -k` della build debug, l'APK firmato con la chiave della Release viene rifiutato (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`: i dati tenuti restano legati alla firma debug); una disinstallazione completa cancellerebbe la musica del telefono di prova. Rimessa la build debug (dati intatti). Resta in «Tocca a te».
- 133.3 Linux: AppImage 1.6.2 di prova (cartella e HOME di prova, Xvfb) → «Aggiorna» → download in ~80 s, il file è diventato la 1.6.3 (sha256 uguale al digest della Release); l'app si è chiusa ma non è ripartita, perché **l'AppImage 1.6.3 della Release non parte su Ubuntu 24.04 (glibc 2.39)**: le librerie incluse vogliono `GLIBC_2.43` (il job Linux di `release.yml` gira su `ubuntu-latest`, ora con glibc 2.43). Da correggere (vedi `../prossimi-lavori.md`).

