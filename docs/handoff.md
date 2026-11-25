# Handoff
Aggiornato: 2026-11-25 · Stato: refactor «desktop-e-coerenza» **chiuso** (fasi 150-161, PR #234-#247, D-748), archiviato in `storico/refactor/desktop-e-coerenza/`; Flutter 3.47.9; schema DB invariato (v24); ultima decisione D-748.

## Prossima sessione
Prossimo obiettivo consigliato: **fase 162 «memoria della griglia e prove a mano del refactor»**: RSS dopo il giro della libreria a 778 MB contro la soglia di 680 (dalla 156 la Libreria desktop parte in griglia e decodifica molte più copertine: provare a limitare `imageCache` sul desktop o `cacheWidth` delle copertine della griglia, poi rimisurare), più le prove a mano rimaste aperte. Prompt: `/kickoff fase 162 memoria della griglia` oppure `/obiettivo` dopo aver scritto la fase in `docs/fasi/`.

Altri obiettivi possibili:
1. Release 1.8.0 con il refactor (alzare la versione, `release-notes/<versione>.md`, `python3 scripts/fdroid_version.py`, tag).
2. Rendere `integration-linux` obbligatorio dal **9/12** se resta verde e stabile (D-733).
3. Stabilizzare i test instabili sotto carico `performance_lists_test` e `daylist_provider_test`.

## Tocca a te
- [ ] **Mi A3**: riavviarlo a mano (è bloccato in un ciclo di crash del servizio fotocamera di Android dopo la prova monkey; nessun crash dell'app). Poi la prova 161.2 (home con il Riprendi ad anello, player, collezioni, gesti D-721), volume 0.
- [ ] **Flatpak** (161.4): `flatpak install --user` del bundle della prossima release (runtime 25.08 con `codecs-extra`), avvio, brano AAC, istanza unica, «Apri con», avviso di primo avvio, comando di aggiornamento.
- [ ] **Windows**: compilare il runner (istanza unica, `WM_COPYDATA`, classe `FREEKMUSIC_RUNNER_WIN32_WINDOW`), tray e clic sull'icona, finestra nascosta rimostrata da un secondo avvio, «Chiudi nella barra di sistema» acceso di default.
- [ ] **GNOME** con e senza l'estensione AppIndicator: con l'estensione la tray compare, senza la X chiude l'app.
- [ ] Posizione della finestra ripristinata su un desktop vero (sotto Xvfb torna solo la dimensione).

## Da sapere
- Fasi del refactor e note di deviazione: `storico/fasi/fase-150-*.md` … `fase-161-*.md`; decisioni D-714..D-748.
- Avvii di prova su Linux: sempre Xvfb, HOME finto **vuoto e nuovo**, `FREEKMUSIC_NON_UNIQUE=1` (istanza unica dalla 158); vedi `.claude/obiettivo.md`.
- Pacchetti desktop: window_manager 0.6, tray_manager 0.8.3 su `nativeapi` (FFI con hook di build: in CI servono `libgtk-3-dev libx11-dev libxi-dev`), desktop_drop 0.8 (D-747).
- Il Motorola edge 40 (ZY22HKD85K) è il telefono dell'utente, non di prova. Mi A3 e Redmi sono i telefoni di test (volume 0, ripulire a fine prova).
- Stringhe nuove nelle 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`.
