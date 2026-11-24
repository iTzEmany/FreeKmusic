# Fase 157 — Schermate da PC

## Obiettivo
Le schermate desktop restanti: home a griglia, un solo telaio di pagina, player a tutto schermo con pannelli chiusi e ricordati, impostazioni senza opzioni da telefono, pagine di ascolto e altre, focus visibile e tooltip su ogni icona.

## Riferimenti
D-717, D-720. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-106, F-107, F-111, F-112, F-113, F-115, F-116, F-119), [`scansione-desktop.md`](../refactor/desktop-e-coerenza/scansione-desktop.md). Mockup: [`desktop-home.html`](../refactor/desktop-e-coerenza/mockup/desktop-home.html), [`desktop-player.html`](../refactor/desktop-e-coerenza/mockup/desktop-player.html), [`desktop-impostazioni.html`](../refactor/desktop-e-coerenza/mockup/desktop-impostazioni.html), [`desktop-ascolto.html`](../refactor/desktop-e-coerenza/mockup/desktop-ascolto.html), [`desktop-altro.html`](../refactor/desktop-e-coerenza/mockup/desktop-altro.html). Larghezza massima 1136 px, margini 32 px, testo minimo 13 px, bersagli 36 px, anello di focus 2 px (D-720, `tokens.css`). Dopo 152-156. Architettura: `../architettura/ui-e-design.md`, `../architettura/piattaforme.md`.
Codice: `lib/ui/screens/home/home_screen.dart` (`:110`), `lib/ui/shell/app_shell.dart` (pannello destro, `~:410`), `side_panel.dart`, `lib/ui/screens/now_playing/now_playing_screen.dart`, `lib/ui/screens/settings/settings_pages.dart` (`:156`), `settings_screen.dart`, `settings_summaries.dart`, `lib/ui/screens/radio/radio_screen.dart` (`:112`), `lib/ui/screens/online/online_page_frame.dart`, `lib/ui/widgets/focus_ring_button.dart`, `desktop_sidebar.dart`, `lib/data/settings/settings_store.dart`.

## Task
- [ ] 157.1 Caratterizzazione di impostazioni e pannelli
  - File: `test/ui/settings_index_test.dart`, `test/ui/app_shell_test.dart`, `test/ui/focus_test.dart`, `test/ui/xl_layout_test.dart`.
  - Passi: fissare le voci e le sezioni di Impostazioni (8), l'apertura del pannello destro da 1200 px, l'ordine del Tab di base.
  - Comando mirato: `flutter test` sui quattro file
  - Fatto quando: verdi sul codice di oggi.
- [ ] 157.2 Telaio di pagina e home a 12 colonne (F-106, F-107)
  - File: nuovo `lib/ui/widgets/page_frame.dart`, `home_screen.dart`, `home_blocks.dart`, `radio_screen.dart`, `online_page_frame.dart`, schermate podcast e Libreria.
  - Passi: 1) un solo contenitore: larghezza massima 1136 px centrata, margini 32 px, bordo sinistro fisso; 2) home su griglia a 12 colonne con scaffali orizzontali di copertine (Riprendi con lo stesso provider della 153); 3) sotto 840 px: telefono invariato.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/xl_layout_test.dart test/ui/radio_screen_test.dart`
  - Fatto quando: test: a 1920 px il contenuto è 1136 px e centrato in ogni pagina elencata; home senza metà vuota (golden).
- [ ] 157.3 Player a tutto schermo e pannelli (F-111, F-112)
  - File: `now_playing_screen.dart`, `app_shell.dart`, `side_panel.dart`, `settings_store.dart`, ARB.
  - Passi: 1) copertina grande a sinistra, Testo e Coda a tutta altezza a destra, barra di posizione lineare con i tempi (non più l'anello); 2) pannello destro **chiuso di default** e scelta dell'utente ricordata (preferenza); 3) Registro e Daylist non si riducono a 830 px da soli.
  - Comando mirato: `flutter test test/ui/now_playing_test.dart test/ui/seek_characterization_test.dart test/ui/app_shell_test.dart`
  - Fatto quando: test: primo avvio a 1440 px con pannello chiuso; dopo l'apertura e un riavvio simulato resta aperto.
- [ ] 157.4 Impostazioni da PC (F-113)
  - File: `settings_pages.dart` (`:156`), `settings_screen.dart`, `settings_summaries.dart`, `lib/l10n/app_*.arb` (le chiavi «può rallentare sui telefoni»), `lib/core/platform.dart`.
  - Passi: nascondere sul desktop le opzioni solo-telefono («Dimensione testo» a blocchi, testi sui telefoni); colonna di dettaglio con larghezza massima, etichetta e interruttore vicini; sezione «Scorciatoie» predisposta per la 158.
  - Comando mirato: `flutter test test/ui/settings_index_test.dart test/ui/advanced_settings_test.dart`
  - Fatto quando: test con `debugIsDesktopOverride`: opzioni solo-telefono assenti sul desktop, presenti sul telefono.
- [ ] 157.5 Ascolto, altre schermate, stati vuoti (F-119)
  - File: `lib/ui/screens/history/`, `lib/ui/screens/podcast/`, `lib/ui/screens/stats/`, `lib/ui/screens/activity/activity_log_screen.dart`, `lib/ui/screens/daylist/`, `lib/ui/screens/library/favorites_screen.dart`, `lib/ui/screens/releases/`.
  - Passi: seguire `desktop-ascolto.html` (Cronologia, Daylist, Statistiche, Podcast) e `desktop-altro.html` (Registro, Radio, Artisti seguiti, Generi, Etichette, Preferiti); stati vuoti con icona, testo e azione (`EmptyState` della 152) per Cronologia, Etichette, Artisti seguiti, Preferiti.
  - Comando mirato: `flutter test test/ui/radio_screen_test.dart test/ui/search_screen_test.dart` + i test di ogni schermata toccata
  - Fatto quando: un test per schermata con dati e uno vuoto (icona, testo, azione).
- [ ] 157.6 Focus e tooltip (F-115, F-116)
  - File: `lib/ui/widgets/focus_ring_button.dart`, `desktop_sidebar.dart`, `segmented_blocks.dart`, `library_filter_bar.dart`, `cc_tile.dart`, pulsanti a icona (⋮, «+», chip attività, intestazioni).
  - Passi: 1) anello di focus 2 px nel colore d'accento su barra laterale, chip, segmenti, tile; distinto dalla selezione; 2) `tooltip` su ogni `IconButton` desktop e bersaglio ≥ 32 px (36 dove il telaio lo permette); 3) estendere `a11y_guidelines_test` a Cerca, impostazioni, player desktop.
  - Comando mirato: `flutter test test/ui/focus_test.dart test/ui/a11y_guidelines_test.dart`
  - Fatto quando: test: dopo 3 Tab l'elemento focalizzato ha l'anello e non ha lo stato «selezionato»; `_known` non cresce.
- [ ] 157.7 Goldens, guardie, documenti
  - Passi: `flutter test --update-goldens test/goldens` una volta (Linux, 27 desktop e telefono), `scripts/guardie.sh`, `flutter analyze`; `ui-e-design.md`.
  - Comando mirato: `flutter test test/goldens`
  - Fatto quando: verdi; il controllo visivo contro i mockup è nella 161.

## Tocca a te
Niente.

## Note di deviazione
