# Handoff
Aggiornato: 2026-11-28 · Stato: refactor «invia-playlist-completa» **pianificato** (fasi 165-166, D-759..D-764); refactor «playlist-aggiungi-e-casuale» **pianificato** (fasi 162-164, D-749..D-758); il precedente «desktop-e-coerenza» è chiuso (fasi 150-161, D-748); Flutter 3.47.9; schema DB invariato (v24).

## Prossima sessione
Prossimo obiettivo consigliato: **refactor «playlist-aggiungi-e-casuale»**, fasi 162 → 163 → 164 in [`fasi/`](fasi/README.md): Casuale salvato per playlist, «Aggiungi alla playlist» a più playlist con ricerca e «Crea «…»», brani simili che non hai nelle playlist intelligenti. Prompt: `/pilot phase 162`.

In alternativa, indipendente dalle 162-164: **refactor «invia-playlist-completa»**, fasi 165 → 166: «Invia a un dispositivo» di una playlist manda tutti i brani (oggi solo i file) e sul ricevente arriva la playlist con nome e ordine. Prompt: `/pilot phase 165`.

Altri obiettivi possibili:
0. Memoria della griglia (era la «fase 162» proposta il 25/11, mai scritta): RSS dopo il giro della libreria a 778 MB contro la soglia di 680; provare a limitare `imageCache` sul desktop o `cacheWidth` delle copertine della griglia, poi rimisurare. Numero di fase: il primo libero dopo la 166.
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
- Refactor «invia-playlist-completa»: analisi, scelte, direzione e rete in `refactor/invia-playlist-completa/analisi.md`; nessun mockup (D-764); le fasi 165-166 non dipendono dalle 162-164.
- Refactor «playlist-aggiungi-e-casuale»: analisi, scelte, direzione e rete in `refactor/playlist-aggiungi-e-casuale/analisi.md`; mockup approvato (variante A) in `mockups/playlist-aggiungi-e-casuale/variante-a.html` (la variante B è scartata, resta per confronto); D-749..D-758.
- Fasi del refactor e note di deviazione: `storico/fasi/fase-150-*.md` … `fase-161-*.md`; decisioni D-714..D-748.
- Avvii di prova su Linux: sempre Xvfb, HOME finto **vuoto e nuovo**, `FREEKMUSIC_NON_UNIQUE=1` (istanza unica dalla 158); vedi `.claude/obiettivo.md`.
- Pacchetti desktop: window_manager 0.6, tray_manager 0.8.3 su `nativeapi` (FFI con hook di build: in CI servono `libgtk-3-dev libx11-dev libxi-dev`), desktop_drop 0.8 (D-747).
- Il Motorola edge 40 (ZY22HKD85K) è il telefono dell'utente, non di prova. Mi A3 e Redmi sono i telefoni di test (volume 0, ripulire a fine prova).
- Stringhe nuove nelle 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`.
