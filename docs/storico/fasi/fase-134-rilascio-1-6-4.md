# Fase 134 — Rilascio 1.6.4 (Linux)

## Obiettivo
La 1.6.3 per Linux (AppImage) non partiva su Ubuntu 24.04: le librerie incluse volevano glibc 2.43, perché `ubuntu-latest` è passato a una versione nuova. La 1.6.4 la ricostruisce su `ubuntu-24.04`; nient'altro cambia per l'utente.

## Riferimenti
Trovato nella 133.3 (`fase-133-rilascio-1-6-3.md`). Documento d'area: `../../architettura/qualita-e-rilascio.md` (sezione «Linux: la glibc del runner è il minimo»). Tag e Release come D-638.

## Task
- [x] 134.1 Runner e pacchetto
  - File: `.github/workflows/release.yml` (job `linux`), `.github/workflows/ci.yml` (job `build-linux`): `runs-on: ubuntu-24.04`. `scripts/package-appimage.sh`: la lista delle librerie escluse confronta il nome seguito da `.` o `-` (prima `libglib-2.0.so.0`, `libgio-2.0`, `libgtk-3` entravano nell'AppImage) e aggiunge `libpangocairo`, `libpangoft2`, `libgdk_pixbuf`.
  - Fatto quando: l'AppImage costruita dalla CI (`release.yml` lanciato sul ramo, senza pubblicare) parte su questo PC (Ubuntu 24.04, glibc 2.39) sotto Xvfb e nessuna libreria inclusa chiede più di `GLIBC_2.39`.
- [x] 134.2 Versione 1.6.4+13, tag `v1.6.4`, Release con i 10 file e il `digest`.
- [x] 134.3 «Aggiorna» da un'AppImage 1.6.3 costruita qui → il file diventa la 1.6.4 e l'app si riavvia (la parte che nella 133.3 non si era vista).

## Tocca a te
- Chi ha scaricato l'AppImage 1.6.3 e non partiva: scaricare a mano la 1.6.4 (dalla 1.6.3 non si arriva a «Aggiorna»).
- Android: nessun telefono collegato, prova reale dell'aggiornamento ancora da fare (vedi 133.3).

## Note di deviazione
- Prova locale (AppImage costruita su questo PC con lo script corretto): 184 librerie incluse, massimo `GLIBC_2.38`; parte su Xvfb e mostra l'onboarding.
- 134.1: AppImage costruita dalla CI (`release.yml` lanciato sul ramo, run 44692947884, senza pubblicare): 184 librerie, massimo `GLIBC_2.38`, nessuna libreria glib/GTK/pango inclusa; parte su questo PC (Ubuntu 24.04) sotto Xvfb.
- Fuori piano: il `ci.yml` completo sul ramo ha trovato un bug vero in «Test (Windows)» (`pending_tags_test`): le prime chiamate di `PendingTags` leggevano il file ciascuna per conto suo e su Windows finivano fuori ordine, così un `remove` chiesto dopo un `add` poteva essere applicato prima (un file appena taggato restava «da taggare»). Corretto con una lettura condivisa (PR #207), test di regressione rosso sul codice vecchio.
- 134.2: `ci.yml` completo verde in tutti i job (run 44701714474, stesso albero di master `321a7a21`); tag `v1.6.4` (con l'ok dell'utente: il permesso automatico aveva bloccato il primo invio); `release.yml` verde in 17 min; Release con i 10 file, ognuno con il `digest`.
- 134.3: AppImage 1.6.3 costruita qui (Xvfb, HOME di prova) → «Aggiorna» → 106 MB in ~77 s, file sostituito con lo stesso nome (sha256 uguale al digest), nessun `.new` rimasto; l'app si è chiusa e riavviata da sola (processo nuovo, `APPIMAGE` sul file aggiornato), Home senza onboarding (preferenze tenute), «Versione 1.6.4» in Impostazioni.

