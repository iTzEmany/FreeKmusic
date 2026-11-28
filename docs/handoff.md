# Handoff
Aggiornato: 2026-11-28 · Stato: refactor «playlist-aggiungi-e-casuale» (fasi 162-164, #258 #259 #262), «invia-playlist-completa» (fasi 165-166, #260 #266) e «karaoke-casuale» (fasi 167-169, #261 #264 #265) **chiusi**; nessuna fase aperta; Flutter 3.47.9; schema DB invariato (v24).

## Prossima sessione
Nessuna fase scritta in [`fasi/`](fasi/README.md). Obiettivi possibili:
0. **Seguiti della revisione di architettura delle fasi 162-169**: le 8 voci in [`prossimi-lavori.md`](prossimi-lavori.md) («Dalla revisione di architettura delle fasi 162-169»): un solo «Home bloccata», pulizia delle impostazioni in `PlaylistOps.delete`, parti delle playlist guidate da `OfferService`, esenzione dai limiti dopo la validazione, pausa 429 del karaoke, `KaraokeRadio` fuori da `PlayerController`, helper delle liste miste, righe ombra create in un solo modo. Prompt: `/refactor` oppure una fase scritta a mano.
1. Memoria della griglia (era la «fase 162» proposta il 25/11, mai scritta): RSS dopo il giro della libreria a 778 MB contro la soglia di 680; provare a limitare `imageCache` sul desktop o `cacheWidth` delle copertine della griglia, poi rimisurare. Numero di fase: 170.
2. Release 1.8.0 con i tre refactor (alzare la versione, `release-notes/<versione>.md`, `python3 scripts/fdroid_version.py`, tag).
3. Rendere `integration-linux` obbligatorio dal **9/12** se resta verde e stabile (D-733).
4. Stabilizzare i test instabili sotto carico `performance_lists_test` e `daylist_provider_test`.

## Tocca a te
- [ ] **Redmi** (8bbad1cd, volume 0): prove delle fasi 166, 168 e 169, rimaste da fare perché il telefono era bloccato (APK di debug della 166 già installato). Per farle fare a me: `! install -m 600 /dev/stdin ~/.config/pilot/pin/8bbad1cd` (incolla il PIN, poi Ctrl-D), oppure sbloccalo a mano. 168: coda dopo «Sing King - Adele - Hello (Karaoke Version)» fatta solo di karaoke dei simili; 169: il casuale di «Casuale su tutto» passa solo fra Casuale e Casuale+ (anche dalla notifica e dopo un riavvio); 166: «Invia a un dispositivo» di una playlist dal Redmi a Linux arriva come playlist con nome e ordine.
- [ ] **Mi A3**: riavviarlo a mano (è bloccato in un ciclo di crash del servizio fotocamera di Android dopo la prova monkey; nessun crash dell'app). Poi la prova 161.2 (home con il Riprendi ad anello, player, collezioni, gesti D-721), volume 0.
- [ ] **Flatpak** (161.4): `flatpak install --user` del bundle della prossima release (runtime 25.08 con `codecs-extra`), avvio, brano AAC, istanza unica, «Apri con», avviso di primo avvio, comando di aggiornamento.
- [ ] **Windows**: compilare il runner (istanza unica, `WM_COPYDATA`, classe `FREEKMUSIC_RUNNER_WIN32_WINDOW`), tray e clic sull'icona, finestra nascosta rimostrata da un secondo avvio, «Chiudi nella barra di sistema» acceso di default.
- [ ] **GNOME** con e senza l'estensione AppIndicator: con l'estensione la tray compare, senza la X chiude l'app.
- [ ] Posizione della finestra ripristinata su un desktop vero (sotto Xvfb torna solo la dimensione).

## Da sapere
- Refactor «karaoke-casuale» e «invia-playlist-completa»: analisi in `storico/refactor/karaoke-casuale/analisi.md` e `storico/refactor/invia-playlist-completa/analisi.md`; fasi e note di deviazione in `storico/fasi/fase-165-*.md` … `fase-169-*.md`; D-759..D-771.
- Formato dell'offerta LAN con playlist (fase 166): `playlist` con `key`, `name`, `part`/`parts`, `order` e le righe ombra solo in `playlist.shadow`; un ricevente vecchio rifiuta la parte con sole righe ombra e il mittente prosegue. Dettagli in `architettura/sync-backup-jam.md`.
- Refactor «playlist-aggiungi-e-casuale»: analisi, scelte, direzione e rete in `storico/refactor/playlist-aggiungi-e-casuale/analisi.md`; mockup approvato (variante A) in `storico/refactor/playlist-aggiungi-e-casuale/mockup/variante-a.html` (la variante B è scartata, resta per confronto); D-749..D-758.
- Fasi del refactor e note di deviazione: `storico/fasi/fase-150-*.md` … `fase-161-*.md`; decisioni D-714..D-748.
- Avvii di prova su Linux: sempre Xvfb, HOME finto **vuoto e nuovo**, `FREEKMUSIC_NON_UNIQUE=1` (istanza unica dalla 158); vedi `.claude/obiettivo.md`.
- Pacchetti desktop: window_manager 0.6, tray_manager 0.8.3 su `nativeapi` (FFI con hook di build: in CI servono `libgtk-3-dev libx11-dev libxi-dev`), desktop_drop 0.8 (D-747).
- Il Motorola edge 40 (ZY22HKD85K) è il telefono dell'utente, non di prova. Mi A3 e Redmi sono i telefoni di test (volume 0, ripulire a fine prova).
- Stringhe nuove nelle 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`.
