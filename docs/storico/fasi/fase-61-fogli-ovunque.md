# Fase 61 — Fogli ovunque (refactor «ui-jam-ricerca»)

**Obiettivo:** ogni ⋮, e anche timer, «+», ordinamenti e clic destro, apre un foglio dal basso come quello del player.
Niente più menu fluttuanti in tutta l'app.

**Prerequisiti:** fase 60 chiusa. Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`. Decisioni D-148, D-149, D-157.
Mockup: `docs/refactor/ui-jam-ricerca/mockup/fogli.html`. Tabella dei menu da convertire: analisi «Menu ⋮».

**Comportamento invariato:** stesse voci, nello stesso ordine e con lo stesso effetto (`menus_characterization_test` della fase 58:
cambia solo come il test apre e legge il menu, gli elenchi attesi restano).

**Comando mirato:** `flutter test test/ui/menus_characterization_test.dart test/ui/track_actions_test.dart test/ui/selection_bar_test.dart test/ui/settings_and_playlists_test.dart test/ui/tag_write_options_test.dart test/ui/architecture_test.dart test/ui/lists_sheets_characterization_test.dart`.

## Task

### 61.1 — Helper dei fogli (F-40, F-49, F-51, F-54, F-55, F-57)
Un helper sopra `showCcSheet` (`cc_sheet.dart`): intestazione opzionale, gruppi di voci da 59 dp, voci distruttive in `cc.error` in fondo,
`barrierLabel` localizzato e titolo semantico, autofocus sulla prima voce, Esc chiude, altezza massima 85 %, larghezza massima 560 dp su desktop (nel tema).
Gli helper dei test cercano le voci nel BottomSheet (F-56).

**Fatto quando:** test nuovo dell'helper (intestazione, distruttive in fondo e rosse, autofocus, Esc, `barrierLabel`, 560 dp) verde.

### 61.2 — Brano, selezione, clic destro (F-41, F-42, F-50)
Il foglio del brano (`track_actions.dart`) usa l'helper; il ⋮ della selezione (`selection_bar.dart`) lo condivide con titolo «N selezionati»
invece del codice duplicato; il clic destro su desktop (`showTrackContextMenu`) apre lo stesso foglio; nella playlist «Rimuovi dalla playlist»
va in cima al foglio del brano, senza il secondo foglio.

**Fatto quando:** test nuovi «N selezionati» e «Rimuovi dalla playlist in cima»; comando mirato verde.

### 61.3 — Collezioni, podcast e schermate di servizio (F-40, F-47, F-48)
Album, playlist, smart, libreria, podcast (barra ed episodio), backup dei tag, brani mancanti: ⋮ (`more_vert`) ovunque, anche nelle intestazioni, e foglio dell'helper.
Il ⋮ della riga della coda della Jam passa all'helper qui (la riga cambia nella fase 63).

**Fatto quando:** comando mirato verde; `grep -rn "more_horiz" lib/ui` vuoto.

### 61.4 — Timer, «+» e ordinamenti (F-43, F-44, F-45)
Timer di spegnimento come foglio a blocchi come `SpeedSheet`; «+» nuova playlist e ordinamenti (Libreria, Preferiti) come fogli, con la scelta corrente segnata.

**Fatto quando:** test nuovo «ordinamento con la scelta segnata»; comando mirato verde.

### 61.5 — Coda e ⋮ della riga (F-46, F-52, F-53)
Nel foglio della coda la voce unica diventa un pulsante diretto «Suggerimenti recenti». Il ⋮ nascosto (`Opacity 0`, `track_row.dart:307`) è fuori da semantica e focus; ogni ⋮ ha un'area di tocco ≥ 48 dp.

**Fatto quando:** test nuovi «pulsante diretto nella coda», «⋮ nascosto fuori da semantica e focus», «⋮ ≥ 48 dp».

### 61.6 — Regola di architettura
In `architecture_test.dart`: niente `PopupMenuButton` né `showMenu(` nel codice UI.

**Fatto quando:** `flutter test test/ui/architecture_test.dart` verde e `grep -rn "PopupMenuButton\|showMenu(" lib/ui` vuoto.

### 61.7 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; comando mirato, test di accessibilità (vedi 59.6) e `flutter test test/goldens` verdi (golden del foglio di 58.6 rigenerato una volta); sul Mi A3 `--only "Fogli"` entro la soglia; review del diff; CI verde.
