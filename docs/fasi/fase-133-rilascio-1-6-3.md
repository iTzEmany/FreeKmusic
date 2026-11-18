# Fase 133 — Rilascio 1.6.3

## Obiettivo
Uscita della versione 1.6.3 con il video karaoke (fase 131) e l'aggiornamento dall'app (fase 132): CI di tutti i
sistemi verde, tag, Release completa, poi la prova reale dell'aggiornamento. Parte solo con 131 e 132 fuse (D-650).

## Riferimenti
D-638, D-648, D-650 (come D-544 e D-553). Specifica: [`../storico/feature/feature-karaoke-video-e-aggiornamenti.md`](../storico/feature/feature-karaoke-video-e-aggiornamenti.md) (R-274, R-268..R-271).
Documento d'area: `../architettura/qualita-e-rilascio.md`. Workflow: `.github/workflows/ci.yml` (job `check`,
`test-windows`, `build-android`, `build-linux`, `build-windows`, `integration-android`, `build-apple`) e `release.yml`
(job `linux`, `flatpak`, `android`, `windows`, `macos`, `publish`).

## Task
- [ ] 133.1 Versione e CI di tutti i sistemi (R-274)
  - File: `pubspec.yaml` (`version: 1.6.3+12`).
  - Passi: ramo da `origin/master`, PR con auto-merge; dopo la fusione `gh workflow run ci.yml --ref master` e attesa.
  - Comando: `gh run list --workflow ci.yml -L 1 --json conclusion,headSha` → `success` su ogni job; CI rossa → `github-ci`.
  - Fatto quando: `ci.yml` su `master` con la 1.6.3 è verde in tutti i job.
- [ ] 133.2 Tag e Release (R-274)
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
