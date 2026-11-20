# Fase 134 — Rilascio 1.6.4 (Linux)

## Obiettivo
La 1.6.3 per Linux (AppImage) non partiva su Ubuntu 24.04: le librerie incluse volevano glibc 2.43, perché `ubuntu-latest` è passato a una versione nuova. La 1.6.4 la ricostruisce su `ubuntu-24.04`; nient'altro cambia per l'utente.

## Riferimenti
Trovato nella 133.3 (`../storico/fasi/fase-133-rilascio-1-6-3.md`). Documento d'area: `../architettura/qualita-e-rilascio.md` (sezione «Linux: la glibc del runner è il minimo»). Tag e Release come D-638.

## Task
- [ ] 134.1 Runner e pacchetto
  - File: `.github/workflows/release.yml` (job `linux`), `.github/workflows/ci.yml` (job `build-linux`): `runs-on: ubuntu-24.04`. `scripts/package-appimage.sh`: la lista delle librerie escluse confronta il nome seguito da `.` o `-` (prima `libglib-2.0.so.0`, `libgio-2.0`, `libgtk-3` entravano nell'AppImage) e aggiunge `libpangocairo`, `libpangoft2`, `libgdk_pixbuf`.
  - Fatto quando: l'AppImage costruita dalla CI (`release.yml` lanciato sul ramo, senza pubblicare) parte su questo PC (Ubuntu 24.04, glibc 2.39) sotto Xvfb e nessuna libreria inclusa chiede più di `GLIBC_2.39`.
- [ ] 134.2 Versione 1.6.4+13, tag `v1.6.4`, Release con i 10 file e il `digest`.
- [ ] 134.3 «Aggiorna» da un'AppImage 1.6.3 costruita qui → il file diventa la 1.6.4 e l'app si riavvia (la parte che nella 133.3 non si era vista).

## Tocca a te
- Chi ha scaricato l'AppImage 1.6.3 e non partiva: scaricare a mano la 1.6.4 (dalla 1.6.3 non si arriva a «Aggiorna»).
- Android: nessun telefono collegato, prova reale dell'aggiornamento ancora da fare (vedi 133.3).

## Note di deviazione
- Prova locale (AppImage costruita su questo PC con lo script corretto): 184 librerie incluse, massimo `GLIBC_2.38`; parte su Xvfb e mostra l'onboarding.
