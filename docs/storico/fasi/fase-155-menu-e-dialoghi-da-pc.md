# Fase 155 — Menu e dialoghi da PC

## Obiettivo
Sul desktop il tasto destro apre un menu sotto il puntatore (brano locale e online, album, artista, playlist) con le scorciatoie, e i fogli diventano dialoghi o popover alti quanto il contenuto. Sul telefono resta il foglio dal basso (D-721). Stessi valori restituiti.

## Riferimenti
D-717, D-720, D-721. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-101, F-102, F-103), [`scansione-desktop.md`](../refactor/desktop-e-coerenza/scansione-desktop.md). Mockup: [`desktop-menu-dialoghi.html`](../refactor/desktop-e-coerenza/mockup/desktop-menu-dialoghi.html). Dopo la 152 (catalogo azioni). Architettura: `../architettura/ui-e-design.md`.
Codice: `lib/ui/widgets/cc_sheet.dart` (`showCcSheet`, `showCcActionSheet`, `CcAction`), `lib/ui/widgets/track_row.dart` (`onSecondaryTap`, `:527`, `:690`), `lib/ui/screens/online/online_song_row.dart` (`:225`, solo `onLongPress`), `lib/ui/widgets/track_actions.dart`, `lib/ui/widgets/album_card.dart`, `lib/ui/widgets/playlist_sheet.dart`, `lib/ui/widgets/new_playlist_menu.dart`, `lib/ui/screens/radio/radio_station_row.dart` (ha già `onSecondaryTap`), `lib/core/platform.dart` (`isDesktop`, `debugIsDesktopOverride`), `test/support/menu_support.dart`.

## Task
- [x] 155.1 Caratterizzazione di fogli e azioni
  - File: `test/ui/cc_sheet_test.dart`, `test/ui/cc_action_sheet_test.dart`, `test/ui/track_actions_test.dart`, `test/ui/track_sheet_61_test.dart`.
  - Passi: oltre a quanto fatto in 150.2, fissare le azioni e il risultato di «Aggiungi a playlist» e di «Nuova playlist» aperti da un foglio; lo stesso test deve poter girare con `debugIsDesktopOverride` true e false.
  - Comando mirato: `flutter test test/ui/cc_sheet_test.dart test/ui/cc_action_sheet_test.dart test/ui/track_actions_test.dart`
  - Fatto quando: verdi sul codice di oggi.
- [x] 155.2 Menu contestuale al puntatore
  - File: nuovo `lib/ui/widgets/context_menu.dart`, `track_row.dart`, `online_song_row.dart`, `album_card.dart`, `lib/ui/screens/library/artist_screen.dart` e le card artista (`lib/ui/screens/online/artist_card.dart`), righe playlist (`desktop_sidebar.dart`, `playlists_screen.dart`), ARB per le scorciatoie mostrate.
  - Passi: 1) `showContextMenu(context, position, actions)` ancorato al punto del clic, voci da 36 px, scorciatoia a destra dove esiste (da `shell_keys.dart`), voci con icone del catalogo; 2) tasto destro (`kSecondaryButton`) su brano locale e **online** (F-102: `onSecondaryTap` in `online_song_row.dart` come in `track_row.dart`), album, artista, playlist; 3) le azioni sono le stesse del foglio di oggi (stesse funzioni di `track_actions.dart`); 4) il pulsante ⋮ apre lo stesso menu ancorato al pulsante; 5) tastiera: frecce, Invio, Esc; 6) telefono: pressione lunga e foglio invariati.
  - Comando mirato: `flutter test test/ui/online_song_row_test.dart test/ui/track_row_selection_test.dart test/ui/track_actions_test.dart` + un test nuovo `test/ui/context_menu_test.dart`
  - Fatto quando: test: clic destro su riga online apre il menu nel punto del clic; Esc lo chiude; voci uguali al foglio; su telefono nessun menu al puntatore.
- [x] 155.3 Fogli → dialogo o popover sul largo (F-103)
  - File: `lib/ui/widgets/cc_sheet.dart`, `playlist_sheet.dart`, `new_playlist_menu.dart`, `lib/ui/screens/jam/speaker_sheets.dart`, `lib/ui/screens/radio/radio_screen.dart` (foglio «Scegli la regione»).
  - Passi: 1) `showCcSheet` su larghezza ≥ 840 px mostra un dialogo centrato o un popover ancorato al pulsante, senza maniglia, **alto quanto il contenuto** (massimo 80 % dell'altezza), senza velo sopra barra laterale e player dove non serve; 2) stessa firma e stesso valore restituito (test di 150.2, ora nelle due modalità); 3) sotto 840 px e sul telefono: foglio di oggi.
  - Comando mirato: `flutter test test/ui/cc_sheet_test.dart test/ui/sheet_over_dock_test.dart test/ui/xl_layout_test.dart`
  - Fatto quando: lo stesso test restituisce lo stesso valore in modalità foglio e dialogo; a 1280 px nessun foglio ha la maniglia.
- [x] 155.4 Tastiera nei menu e dialoghi
  - File: i widget di 155.2 e 155.3.
  - Passi: focus iniziale sulla prima voce, ritorno del focus al chiamante alla chiusura, `Semantics` di menu; anello di focus dalla 152/157.
  - Comando mirato: `flutter test test/ui/context_menu_test.dart test/ui/focus_test.dart`
  - Fatto quando: test di apertura da tastiera (Maiusc+F10 o tasto Menu, se Flutter lo espone) e di ritorno del focus.
- [x] 155.5 Goldens, guardie, documenti
  - Passi: `flutter test --update-goldens test/goldens` una volta (Linux): aggiungere un golden del menu al puntatore e del dialogo a 1440 px; `scripts/guardie.sh`; `ui-e-design.md`.
  - Comando mirato: `flutter test test/goldens test/ui/phone_gestures_d721_test.dart`
  - Fatto quando: verdi.

## Tocca a te
Niente.

## Note di deviazione
- 155.2: `showContextMenu(context, position, groups)` in `lib/ui/widgets/context_menu.dart` usa `showMenu` ancorato al punto del clic; `architecture_test` ammette `showMenu`/`PopupMenuButton` **solo** in quel file (D-717). Le voci dei brani sono le stesse del foglio (`menuGroups`), l'azione parte a menu chiuso. Album e playlist non hanno un foglio di oggi: menu minimi («Aggiungi in coda», «Aggiungi a playlist» / «Condividi»); la card artista online ha solo «Vai all'artista»; la riga coda online non ha il clic destro. Nessuna azione dei brani ha una scorciatoia propria, quindi il menu non mostra tasti a destra. Il menu non si aggiorna se un download finisce mentre è aperto.
- 155.3: `showCcSheet` è un dialogo centrato (massimo 560 px di larghezza, alto quanto il contenuto fino all'80 %) quando `isDesktop` e la larghezza è ≥ 840 px; stessa firma e stesso valore. Niente popover ancorato (il dialogo centrato basta). Il velo copre anche barra laterale e player (sta sulla radice). I chiamanti passavano già tutti da `showCcSheet`. Le code in `DraggableScrollableSheet` nel dialogo occupano l'80 %.
- 155.4: focus sulla prima voce con `Focus(autofocus: true)`, ritorno del focus al chiamante dalla route; tasto Menu e Maiusc+F10 con `CallbackShortcuts` (Flutter non ha un `ContextMenuIntent`), provati su una `TrackRow` vera raggiunta con Tab.
- 155.5: golden rigenerati sulla pila; su master non cambiano. Il golden del menu al puntatore e del dialogo a 1440 px non è stato aggiunto: il dialogo a 1440 px è coperto da `cc_sheet_test`, il menu da `context_menu_test` (posizione, voci da 36 px).
