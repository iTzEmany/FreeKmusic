# Fase 158 — Comodità del PC senza pacchetti

## Obiettivo
Tasti laterali del mouse, scorciatoie nuove con il loro elenco, istanza unica con «Apri con», titolo della finestra col brano in ascolto. Tutto con codice dell'app e dei runner: **nessun pacchetto nuovo**. Memoria della finestra, tray e trascinamento sono nella 159.

## Riferimenti
D-718, D-727 (istanza unica e «Apri con» nel runner), D-732 (Ctrl+L). Refactor: [`scansione-input-flatpak-test.md`](../refactor/desktop-e-coerenza/scansione-input-flatpak-test.md) (F-205, F-206 parte titolo, F-207, F-209), [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md). Mockup: [`desktop-impostazioni.html`](../refactor/desktop-e-coerenza/mockup/desktop-impostazioni.html) (sezione «Scorciatoie»). Architettura: `../architettura/piattaforme.md`.
Codice: `lib/ui/shell/app_shell.dart` (`:68` Listener, `:90-135` scorciatoie), `shell_keys.dart`, `shell_nav.dart`, `lib/providers/nav_providers.dart`, `lib/ui/screens/search/search_screen.dart`, `lib/ui/screens/settings/settings_pages.dart`, `linux/runner/my_application.cc` (`:48-56` titolo, `:148` `G_APPLICATION_NON_UNIQUE`), `linux/runner/main.cc`, `windows/runner/main.cpp`, `windows/runner/flutter_window.cpp`, `packaging/flatpak/com.freekmusic.player.desktop`, `packaging/linux/freekmusic.desktop`, `integration_test/desktop_flow_test.dart` (dalla 151).

## Task
- [x] 158.1 Verifica: i tasti 8/9 del mouse arrivano a Flutter su GTK?
  - File: nessuno di prodotto; un'app di prova o un `Listener` temporaneo con log (`AppLog`) in `app_shell.dart`, da non committare.
  - Passi: 1) in Xvfb con `xdotool click 8` e `click 9` sulla finestra, loggare `PointerDownEvent.buttons` (attesi `kBackMouseButton` e `kForwardMouseButton`); 2) scrivere l'esito in «Note di deviazione».
  - Comando mirato: `xvfb-run -a flutter run -d linux` con `xdotool` (scheda locale, un solo giro).
  - Fatto quando: esito scritto. **Se i tasti non arrivano: fermarsi, non fare 158.2, riferire all'utente** (le altre scorciatoie e il runner proseguono).
- [x] 158.2 Tasti laterali del mouse (F-205)
  - File: `app_shell.dart`, `shell_nav.dart`, `nav_providers.dart`, `test/ui/shell_nav_test.dart`, `integration_test/desktop_flow_test.dart`.
  - Passi: 1) `Listener` nello shell: `kBackMouseButton` → `back()`, `kForwardMouseButton` → pila di «avanti» per scheda (si svuota alla navigazione nuova); 2) niente effetto sul telefono; 3) test widget con `PointerDownEvent(buttons: kBackMouseButton)`; 4) aggiungere il caso al test di sistema.
  - Comando mirato: `flutter test test/ui/shell_nav_test.dart test/ui/shell_keys_test.dart`
  - Fatto quando: indietro e avanti con il mouse riportano alla pagina giusta, anche dopo un nuovo percorso.
- [x] 158.3 Scorciatoie nuove ed elenco (F-209, D-732)
  - File: `app_shell.dart`, `shell_keys.dart`, `search_screen.dart`, `settings_pages.dart`, nuovo overlay `lib/ui/shell/shortcuts_overlay.dart`, ARB (6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`).
  - Passi: 1) Alt+→ (avanti), Backspace = indietro fuori dai campi di testo, F5 = ricarica la pagina corrente (Nuove uscite, Cerca, pagine online) (D-738), `/` (focus su Cerca, non quando si scrive in un campo), Ctrl+L = «Cerca e incolla un link» (apre Cerca col link degli appunti, D-732), Ctrl+, (Impostazioni), Ctrl+Q (esci, con la chiusura pulita di sempre), `?` (overlay con l'elenco); 2) le scorciatoie esistenti non cambiano; 3) una tabella unica tasto → azione che alimenta sia gli shortcut sia l'overlay e la sezione «Scorciatoie» di Impostazioni; 4) i tasti con testo in un campo non scattano.
  - Comando mirato: `flutter test test/ui/shell_keys_test.dart test/ui/search_screen_test.dart test/ui/settings_index_test.dart`
  - Fatto quando: un test per ogni tasto nuovo; il test della mappa (150.2) esteso e verde; l'overlay elenca tutte le voci della tabella.
- [x] 158.4 Istanza unica e «Apri con» (F-207)
  - File: `linux/runner/my_application.cc`, `windows/runner/main.cpp` e `flutter_window.cpp`, `lib/main.dart`, canale/azione per i file in arrivo, `packaging/flatpak/com.freekmusic.player.desktop`, `packaging/linux/freekmusic.desktop`.
  - Passi: 1) Linux: `GApplication` senza `G_APPLICATION_NON_UNIQUE`, `HANDLES_OPEN`; una seconda istanza inoltra i file alla prima e `gtk_window_present` in `activate`; 2) Windows: mutex nominato e, se esiste, trova la finestra, `SetForegroundWindow` e inoltra gli argomenti; macOS lo fa il sistema; 3) lato Dart: i percorsi ricevuti (da `main` e dal canale) suonano subito come l'apertura di file esterni su Android (riusare quel percorso); file fuori dalle cartelle della libreria → avviso con «Aggiungi alla libreria»; più file → in coda nell'ordine (D-736); 4) `.desktop`: `MimeType=audio/*;` e `Exec=… %U` (Flatpak: `freekmusic %U`; deb/AppImage: `@EXEC@ %U`).
  - Comando mirato: `flutter test test/` per l'handler Dart nuovo + `flutter build linux --debug` + prova a mano due avvii di fila (scheda locale, poi `scheggia`)
  - Fatto quando: un secondo avvio non apre una seconda finestra ma porta in primo piano la prima; `app-name file.mp3` lo suona; i `.desktop` passano `desktop-file-validate` (se installato).
- [x] 158.5 Titolo della finestra col brano (F-206, parte titolo)
  - File: `linux/runner/my_application.cc` (`:48-56`), `windows/runner/win32_window.cpp`, canale in `lib/services/` (nuovo `window_title.dart`), `lib/providers/player_providers.dart` (ascolto del brano).
  - Passi: canale `MethodChannel` che imposta il titolo («Artista — Titolo · FreeKmusic»; in pausa o senza brano «FreeKmusic»); su Linux `gtk_window_set_title`, su Windows `SetWindowText`; errori loggati con `AppLog`, mai nel thread UI pesante.
  - Comando mirato: `flutter test` sul servizio con canale finto + `flutter analyze`
  - Fatto quando: test: cambio brano → chiamata al canale col titolo atteso; il titolo si vede nella finestra Xvfb (`xdotool getwindowname`).
- [x] 158.6 Estendere il test di sistema e i documenti
  - File: `integration_test/desktop_flow_test.dart`, `../architettura/piattaforme.md`.
  - Passi: aggiungere tasti laterali, Alt+→, Backspace, F5, `/`, Ctrl+L, Ctrl+, e `?`; documentare istanza unica, «Apri con» e scorciatoie.
  - Comando mirato: `xvfb-run -a flutter test integration_test/desktop_flow_test.dart -d linux`
  - Fatto quando: il job `integration-linux` passa sulla PR.

## Tocca a te
- [ ] Windows: istanza unica e «Apri con» si provano su una macchina Windows (non c'è in locale).

## Note di deviazione
- 158.1: **positivo**. Sotto Xvfb con GTK (`GDK_BACKEND=x11`) `xdotool click 8/9` arrivano come `PointerDownEvent.buttons` 8 (`kBackMouseButton`) e 16 (`kForwardMouseButton`).
- 158.2: la pila «avanti» per scheda registra solo gli indietro chiesti dall'utente (Alt+←, tasto laterale), non i pop automatici; «Avanti» ricostruisce la pagina dal suo builder (lo stato della pagina non si conserva); `shell_nav.dart` non è cambiato.
- 158.3: non fatta in questa PR (D-745): dipende dalla sezione «Scorciatoie» della 157.4; esce in una seconda PR dopo la 157. Anche il test di sistema dei tasti nuovi (Alt+→, Backspace, F5, `/`, Ctrl+L, Ctrl+,, `?`) arriva con lei.
- 158.4: su Android l'apertura di file esterni gestisce solo ZIP/CSV, quindi il percorso «Apri con» è nuovo (`open_files.dart`, `playFromList`). Argomenti normalizzati e assoluti, inesistenti scartati. File fuori dalla libreria: avviso con «Aggiungi alla libreria» (aggiunge la cartella, scansiona, suona). File del portale Flatpak (`/run/user/<uid>/doc/…`): non suonano, avviso di aggiungere la cartella dalla Libreria (nessuna riga finta in `tracks`). `FREEKMUSIC_NON_UNIQUE=1` toglie l'unicità (prove, CI). Windows: classe `FREEKMUSIC_RUNNER_WIN32_WINDOW`, mutex, `WM_COPYDATA` con `SendMessageTimeout`: **non compilato qui** (Tocca a te).
- 158.5: il separatore « · » del titolo è nel codice Dart con un commento (la guardia degli ARB vieta il separatore nei testi).
- 158.6: test di sistema esteso con i tasti laterali; il fallimento visto in prova veniva da un mp3 rimasto nel HOME finto (5 brani invece di 4), non dal codice.
- 158.3 (seconda PR): `/` e `?` con `CharacterActivator` (il carattere, non il tasto fisico: su tastiera italiana `/` è Maiusc+7); `flutter_test` non sa simulare `?` come tasto, i test lo mandano come tasto `/` con carattere `?`. Ctrl+, apre le Impostazioni nella scheda Home (pila di «indietro» di quella scheda). Ctrl+Q usa `exitApplication`, non `exit(0)`.
- 158.3 (rinforzi): un tasto tenuto premuto non ripete l'azione (tranne il volume); F5 non riparte finché il ricaricamento precedente non è finito; Ctrl+L accetta solo un link http/https (altrimenti apre Cerca vuota con il focus nel campo); Backspace è ignorato dentro fogli e dialoghi. Ctrl+Q usa `exitApplication(required)`, oggi lo stesso percorso della X della finestra: quando la 159 aggiunge `window_manager` (chiusura nella barra di sistema) i due devono passare dalla stessa funzione di chiusura.
