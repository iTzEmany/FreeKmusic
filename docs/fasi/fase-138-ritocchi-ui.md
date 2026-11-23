# Fase 138 — Ritocchi di UI

## Obiettivo
Una dozzina di ritocchi da poco: fogli a tutta larghezza, ricerca senza tastiera automatica, testate trasparenti, superfici della home con l'intestazione dentro, anteprima del tema con l'immagine, card daylist con il tocco su tutta la riga, «Come risolvere» e «Tutto/Nessuno» come azioni proprie. Fuori: Riprendi a griglia (142), testata delle collezioni a icone (141), segnalazione (143).

## Riferimenti
D-667, D-687, D-692, D-693, D-698, D-699. Rilievi F-25..F-31, F-33 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); dettaglio e elenco dei 26 fogli in [`../refactor/grande-revisione/scansione-ui.md`](../refactor/grande-revisione/scansione-ui.md) (punti 1-6, 10, 11); rete.md riga 138. Mockup: `mockup/home.html` (F-27, F-29), `mockup/segnalazione.html` (F-30..F-33), nella cartella `../refactor/grande-revisione/mockup/`. Area: `../architettura/ui-e-design.md`. Fase di sola UI: niente caratterizzazione; si mantengono verdi `test/ui/a11y_guidelines_test.dart` e `test/ui/accessibility_characterization_test.dart`. Ogni task UI lancia anche `test/ui/architecture_test.dart` e `test/ui/no_separator_literals_test.dart`.

## Task
- [x] 138.1 Fogli a tutta larghezza (F-30; mockup `segnalazione.html`)
  - File: `lib/ui/widgets/cc_sheet.dart` (`showCcSheet`, ~11-31), `lib/ui/theme/app_theme.dart` (~151, `maxWidth: 560` senza `minWidth`), `lib/ui/screens/devices/devices_sheet.dart` (~35-41, perde il tetto dei 560), `test/ui/cc_sheet_test.dart` (nuovo).
  - Passi: 1) `minWidth: min(560, larghezza schermo)` in `showCcSheet`, un solo punto; 2) `devices_sheet` usa `showCcSheet` o mantiene il tetto; 3) un solo test che apre un foglio con poco contenuto e verifica la larghezza (non uno per foglio); 4) golden dei fogli (foglio d'esempio).
  - Comando mirato: `flutter test test/ui/cc_sheet_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart` + `flutter analyze`
  - Fatto quando: il foglio di prova occupa `min(560, larghezza)`; `devices_sheet` ha il tetto su desktop.
- [x] 138.2 Ricerca e «+» senza tastiera automatica (F-25; D-667)
  - File: `lib/ui/screens/library/library_screen.dart` (`autofocus: true` ~330, `requestFocus` ~259 per Ctrl+F), `lib/ui/shell/app_shell.dart` (`requestFocus` ~122, ~160-164), `lib/ui/widgets/playlist_sheet.dart` (`autofocus` ~152).
  - Passi: 1) togliere i quattro focus automatici; 2) Ctrl+F resta solo su desktop; 3) test: i campi di ricerca e il nome della playlist non hanno focus all'apertura.
  - Comando mirato: `flutter test test/ui/library_screen_test.dart test/ui/app_shell_test.dart test/ui/shell_keys_test.dart test/ui/architecture_test.dart`
  - Fatto quando: nessun `autofocus: true` né `requestFocus` non-desktop nei quattro punti (grep).
- [x] 138.3 Tutti i brani e testate senza sfondo opaco (F-26; D-687, D-698)
  - File: `lib/ui/screens/library/all_tracks_screen.dart` (icone dei `BlockItem` ~295-307, `ShrinkingHeader(color: cc.bg)` ~271-273), `lib/ui/widgets/shrinking_header.dart` (~34, `ColoredBox` opaco), `lib/ui/widgets/collection_header.dart` (~93-105, `backgroundColor: cc.bg` di `SliverAppBar`), `lib/ui/widgets/library_filter_bar.dart`.
  - Passi: 1) via le icone dai blocchi di ordinamento; 2) `ShrinkingHeader` e `CollectionScaffold` trasparenti con `ClipRect` per il contenuto che scorre (si vede `AppBackground`); 3) test di widget e golden `all_tracks`.
  - Comando mirato: `flutter test test/ui/all_tracks_screen_test.dart test/ui/collection_header_test.dart test/ui/architecture_test.dart` più i golden (`flutter test test/goldens/`, aggiornare `desktop_100_all_tracks*.png`)
  - Fatto quando: `grep -n "color: cc.bg" lib/ui/screens/library/all_tracks_screen.dart` = 0 (metrica di rete.md); golden `all_tracks` rigenerato e rivisto.
- [x] 138.4 Superfici della home con l'intestazione dentro (F-27; D-687; mockup `home.html`)
  - File: `lib/ui/screens/home/home_row.dart` (`HomeBlock`, ~96-110: nuovo parametro `header`), `lib/ui/screens/home/home_blocks.dart` (~192-215, «Aggiunti da poco» senza superficie), `lib/ui/screens/home/home_bottom_rows.dart` (~42, ~62, ~113), `lib/ui/screens/home/resume_rows.dart` (~104).
  - Passi: 1) `HomeBlock(header:)` mette l'intestazione dentro la superficie; 2) «Aggiunti da poco» diventa un blocco con superficie; 3) tutte le sezioni della home passano `header`; 4) test di widget e golden `home`.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/home_test.dart test/ui/architecture_test.dart` più i golden (`desktop_100_home.png`)
  - Fatto quando: nessuna intestazione resta fuori dal blocco (grep sui quattro file); golden `home` rivisto.
- [x] 138.5 Card daylist: tocco su tutta la riga (F-29; mockup `home.html`)
  - File: `lib/ui/screens/daylist/daylist_card.dart` (~38-100, `InkWell` solo a sinistra, `PlayCircleButton` fratello).
  - Passi: 1) `InkWell` su tutta la riga, il tasto play resta un controllo accessibile distinto; 2) test: il tocco ovunque avvia la daylist, l'effetto copre il tasto play.
  - Comando mirato: `flutter test test/ui/daylist_ui_test.dart test/ui/architecture_test.dart`
  - Fatto quando: il test sul tocco sul tasto play e sul resto della card passa; i test di accessibilità restano verdi.
- [x] 138.6 Anteprima del tema con l'immagine (F-28)
  - File: `lib/ui/screens/settings/theme_editor_screen.dart` (`ThemePreview`, ~395, ~417-421), `lib/ui/theme/theme_background.dart` (`AppBackground`, ~51-128).
  - Passi: 1) `ThemePreview` riusa `AppBackground` (immagine, blur, dim); 2) niente decodifica pesante sul thread UI; 3) golden dell'anteprima con un'immagine di prova.
  - Comando mirato: `flutter test test/ui/theme_editor_test.dart test/ui/custom_theme_test.dart test/ui/architecture_test.dart`
  - Fatto quando: golden dell'anteprima con immagine rivisto; senza immagine l'anteprima è identica a oggi.
- [x] 138.7 Registro: «Come risolvere» con azione propria (F-31; mockup `segnalazione.html`)
  - File: `lib/ui/screens/activity/activity_log_entry.dart` (~400-407), `lib/ui/screens/activity/activity_log_screen.dart` (~95), `test/ui/activity_log_screen_test.dart`.
  - Passi: 1) callback distinta dal tocco sulla riga (su desktop con riga già selezionata apre comunque la guida; su telefono apre il foglio, ora a tutta larghezza grazie a 138.1); 2) test: l'azione differisce dal tocco sulla riga.
  - Comando mirato: `flutter test test/ui/activity_log_screen_test.dart test/goldens/activity_golden_test.dart`
  - Fatto quando: il test passa; golden `activity` invariato o rivisto.
- [x] 138.8 Import: «Seleziona tutto» e «Deseleziona tutto» (F-33; mockup `segnalazione.html`)
  - File: `lib/ui/screens/youtube/playlist_source_sheet.dart` (~160-176), `lib/ui/screens/import/import_plan_screen.dart` (~44: checkbox per riga più le due azioni), ARB ×6.
  - Passi: 1) due pulsanti separati in `playlist_source_sheet`; 2) lo stesso in `import_plan_screen` con checkbox per riga; 3) stringhe con `scripts/arb_add.py` poi `flutter gen-l10n`; 4) test: «Tutto» seleziona tutte le righe, «Nessuno» nessuna.
  - Comando mirato: `flutter test test/ui/import_plan_test.dart test/ui/csv_import_test.dart test/ui/architecture_test.dart`
  - Fatto quando: i due pulsanti compaiono in entrambe le schermate e i test passano.
- [x] 138.9 Area e controllo di fine fase
  - Aggiorna `../architettura/ui-e-design.md` (regola delle superfici D-687, `showCcSheet` con `minWidth`, `HomeBlock(header:)`; «Trappole»: testate senza colore opaco). Esegui `scripts/guardie.sh` (golden inclusi) prima del push.

## Tocca a te
- Nessuna cosa in questa fase: la rivista visiva dei golden la fa `/obiettivo`; l'utente guarda il risultato sul telefono nella 147.

## Note di deviazione
- 138.1: `app_theme.dart` non toccato: il `minWidth` sta in `showCcSheet`; i fogli con `constraints` propri (es. `artist_picker_sheet`) restano come sono.
- 138.3: `library_filter_bar.dart` non serviva; le testate delle collezioni seguono il colore del tema invece di un trasparente fisso (che toglieva lo sfondo nei temi senza immagine).
- 138.4: golden rigenerati anche `phone_100_home_fan_open`, `phone_*_mini_dock` (mostrano la home).
- 138.8: in `import_plan_screen` le righe non spuntate si saltano (`skip`) prima di avviare.
