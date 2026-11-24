# Fase 150 — Rete di sicurezza del refactor desktop-e-coerenza

## Obiettivo
Prima di toccare la UI: test di caratterizzazione di tutte le aree del refactor, goldens desktop a 1000/1440/1920 px (F-211) e baseline di oggi, accessibilità estesa a home e libreria desktop. **Nessun codice di prodotto cambia**: ogni test nuovo deve essere verde sul codice di oggi.

## Riferimenti
D-719, D-721, D-734, D-735. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md), [`rete.md`](../refactor/desktop-e-coerenza/rete.md) (sezioni «Test di caratterizzazione», «Goldens», «Metriche di arrivo»). Regole: `../01-regole-di-lavoro.md`. Architettura: `../architettura/qualita-e-rilascio.md`, `../architettura/ui-e-design.md`.
Codice: `test_shots/support/shot_harness.dart` (`ShotSize`: oggi `phone` 360×800 e `desktop` 1280×800), `test/goldens/tolerant_comparator.dart` (`withGoldenShot`), `test/goldens/screens_golden_test.dart`, `test/support/app_harness.dart`.

## Task
- [ ] 150.1 Caratterizzazione di home, player e barra desktop
  - File: `test/ui/home_screen_test.dart`, `test/ui/resume_rows_test.dart` (nuovo), `test/ui/now_playing_test.dart`, `test/ui/desktop_player_bar_test.dart` (nuovo).
  - Passi: 1) una tile della home apre la sua destinazione; «Tutti» raggiungibile dove c'è oggi; 2) tocco su una voce di `ResumeRows` (`lib/ui/screens/home/resume_rows.dart`) riprende da lì; 3) il cuore del player grande alterna il preferito con «Annulla» (brano locale); 4) barra desktop (`lib/ui/shell/desktop_player_bar.dart`): play/pausa, avanti, indietro, cuore, volume.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/resume_rows_test.dart test/ui/now_playing_test.dart test/ui/desktop_player_bar_test.dart` + `flutter analyze`
  - Fatto quando: i test passano senza modifiche a `lib/` (`git diff --stat lib` vuoto).
- [ ] 150.2 Caratterizzazione di liste, azioni, fogli, scorciatoie, collezioni
  - File: `test/ui/all_tracks_screen_test.dart` (e i test di album e playlist in `test/ui/collection_pages_test.dart`), `test/ui/cc_sheet_test.dart`, `test/ui/shell_keys_test.dart`, `test/ui/collection_header_test.dart`, `test/providers/curiosity_provider_test.dart`.
  - Passi: 1) suonando da una riga la coda è la lista visibile, nell'ordine, con l'indice giusto (tutti i brani, album, playlist); 2) valore restituito da `showCcSheet` (`lib/ui/widgets/cc_sheet.dart`), base per il dialogo desktop; 3) mappa tasto → azione di `lib/ui/shell/shell_keys.dart` e `app_shell.dart`: Spazio, Ctrl+frecce, Ctrl+↑/↓, Ctrl+F, Alt+←, Esc; 4) azioni di `CollectionScaffold` (`lib/ui/widgets/collection_header.dart`): play, casuale, scarica, Condividi, ⋮; 5) curiosità in pausa MusicBrainz: il comportamento di oggi (poi corretto da F-215 nella 160).
  - Comando mirato: `flutter test` sui cinque file sopra + `flutter analyze`
  - Fatto quando: verdi sul codice di oggi; nessun file in `lib/` modificato.
- [ ] 150.3 Gesti del telefono (D-721)
  - File: `test/ui/phone_gestures_d721_test.dart` (nuovo, `debugIsDesktopOverride = false` da `lib/core/platform.dart`).
  - Passi: un test per comportamento: scorrimento in coda, pressione lunga e tocco in selezione, tocco e doppio tocco, seek ad arco, anteprima dalla copertina sulle righe online, indietro.
  - Comando mirato: `flutter test test/ui/phone_gestures_d721_test.dart`
  - Fatto quando: verde; se un gesto non è raggiungibile in un test widget, lo scrivi in «Note di deviazione» e va nella prova a mano della 161.
- [ ] 150.4 `ShotSize` a 1000/1440/1920 e baseline
  - File: `test_shots/support/shot_harness.dart`, nuovo `test/goldens/desktop_widths_golden_test.dart`, PNG `test/goldens/desktop_w<1000|1440|1920>_<schermata>.png`.
  - Passi: 1) aggiungi a `ShotSize` tre valori desktop (larghezza 1000, 1440, 1920; altezza 900, dpr 1) senza cambiare `phone` e `desktop` (i ~150 PNG esistenti restano identici); 2) nuovo file con 9 schermate (home, libreria, tutti i brani, album, playlist, cerca, impostazioni, player, ascolto) × 3 larghezze = 27 e 5-6 schermate telefono a 360 dp; 3) `TolerantComparator` 0,5 %, solo Linux come gli altri; 4) genera la baseline con `flutter test --update-goldens test/goldens/desktop_widths_golden_test.dart`, controlla a occhio e committa.
  - Comando mirato: `flutter test test/goldens` + `ls test/goldens/desktop_w*.png | wc -l`
  - Fatto quando: ≥ 27 PNG e i goldens esistenti invariati (`git status test/goldens` mostra solo file nuovi).
- [ ] 150.5 Accessibilità: home e libreria desktop
  - File: `test/ui/a11y_guidelines_test.dart`.
  - Passi: aggiungi home e libreria con `debugIsDesktopOverride = true` a 1280 px; gli errori nuovi vanno corretti solo se il costo è nullo, altrimenti si elencano in `_known` (che oggi ha 2 voci) con il motivo e si chiudono nelle fasi 152 e 157.
  - Comando mirato: `flutter test test/ui/a11y_guidelines_test.dart`
  - Fatto quando: verde; il numero di voci di `_known` e il motivo di ognuna sono scritti nelle note di deviazione.

## Tocca a te
Niente.

## Note di deviazione
