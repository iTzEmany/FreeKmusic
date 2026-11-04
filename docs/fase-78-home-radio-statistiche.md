# Fase 78 — Home, Radio e Statistiche (refactor «ui-uso-quotidiano»)

**Obiettivo:** Home con riquadri invece delle linee, Radio con le tue radio in cima, generi in griglia da 4 e radio vicine, Statistiche con il mese ricordato e le barre toccabili.

**Prerequisiti:** fase 77 chiusa (`Skeleton`). Rilievi e scelte: `refactor/ui-uso-quotidiano/analisi.md`; mockup `refactor/ui-uso-quotidiano/mockup/home.html` (variante A), `refactor/ui-uso-quotidiano/mockup/radio.html`, `refactor/ui-uso-quotidiano/mockup/statistiche.html`. Decisioni D-362, D-363, D-369, D-370.

**Comando mirato:** `flutter test test/ui/home_screen_test.dart test/ui/home_test.dart test/ui/radio_screen_test.dart test/ui/radio_home_library_test.dart test/ui/stats_screen_test.dart test/data/stats_queries_test.dart test/theme/contrast_test.dart test/ui/a11y_guidelines_test.dart`.

## Task

### 78.1 — Home (F-01, F-02, F-18…F-21, U1, D-369)
- Scorciatoie Preferiti / Playlist / Radio: tre riquadri `surface1` raggio `rCard`, gap 8, niente `Border` né `IntrinsicHeight` (`home_blocks.dart:126-200`); una sola etichetta semantica «Preferiti, 148 brani».
- Riprendi / Più ascoltati / Riscopri: un riquadro per blocco, niente `Divider` (`home_row.dart:92-97`); letterali 4/6/64/52 sostituiti dai token; `MergeSemantics` sulla riga (F-19); `CoverFan` con gli stili del tema (F-20).
- «Casuale su tutto»: restano ▶ (tutta la libreria, D-137) e il pulsante Shuffle che cambia solo la modalità (D-369). Verificare anche il «Casuale su tutto» che nella prova 76 non ha avviato nulla (handoff, obiettivo 0).
- Golden home rigenerato e rivisto.

### 78.2 — Radio (F-10, F-28, U6, D-370)
- Ordine: Le tue radio → Generi → Vicino a te → Più ascoltate (`radio_screen.dart:96-102`). Aggiornare «sections come in order».
- Generi in griglia uniforme da 4 colonne (`radio_sections.dart:240-278`): celle ≥ 56 dp, testo 12 centrato fino a 2 righe; colonne 4 / 3 / 2 secondo la scala del testo (< 1,3 / < 1,8 / oltre). `ValueKey('genre-$tag')` resta.
- Test: ordine delle sezioni; 4 colonne a 360 dp; nessun overflow a 2,0×.

### 78.3 — Statistiche (F-11, F-12, F-64, F-65, U7, U8, D-362, D-363)
- Bug del mese: `_setYear` (`stats_screen.dart:48-50`) ricorda l'ultimo mese visto (aggiornato dalle frecce, :120-121); se nessuno, lo stesso mese di oggi anche per un anno passato. Test: Anno→Mese torna all'ultimo mese visto; senza mese visto → novembre 2025 guardando il 2025 a novembre 2026.
- Barre toccabili: tocco o trascinamento sul grafico, barra scelta per posizione orizzontale; barra evidenziata, le altre attenuate, etichetta sopra «12 mar · 2 h 14 min» / «Marzo · 41 h»; la selezione resta al rilascio e si azzera al cambio periodo; giorni futuri non selezionabili; etichette dell'asse ogni N; `labelBand` e `TextPainter` con `textScaler`; `semanticsBuilder` per TalkBack.
- Cambio periodo senza spinner: valore precedente attenuato o skeleton delle barre (`history_providers.dart:19`).
- Test: tocco → etichetta; Semantics per barra; nessun `CircularProgressIndicator` nel cambio periodo.

### 78.4 — Controlli di fase
`flutter analyze`; comando mirato; golden `radio`, `stats` (barra toccata) nuovi in `test/goldens/screens_golden_test.dart` (phone_100, desktop_100, phone_150); code-review medium; scheggia. Sul Mi A3: Home, Radio (posizione già scelta), Statistiche (tocco, trascinamento, Anno→Mese).

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Dalla review della fase 77
- Radio: il campo di ricerca (`radio_screen.dart:133`, ✕ propria con tooltip `l.close`) passa a `CcSearchField` nella stessa PR della schermata.
- Radio: `_Loading` di `radio_sections.dart` (~:87/:114/:208) è ancora uno spinner (F-68, nessuna fase lo copriva): diventa `Skeleton`.
- Statistiche: `Skeleton.bars` e `Skeleton.gridCell` non hanno ancora chiamanti né test; chi li introduce aggiunge un test di rendering per variante (`bars` vuole altezza limitata).

## Esiti

### 78.4 — Controlli (2026-11-04)
- `flutter analyze` pulito; comando mirato verde; golden nuovi `radio` e `stats` (barra toccata) su phone_100, phone_150, desktop_100, desktop_150; `home`, `home_fan_open`, `mini_dock` rigenerati. Le 4 immagini desktop album/selection cambiavano solo per la striscia della scrollbar (instabile): lasciate come su master.
- Review medium per task (Sonnet), rilievi applicati: titoli dei riquadri interi a 2,0×, «In diretta» nel riquadro Radio senza stazioni (prima «Stazioni in …» tagliato al 100%), celle dei generi `surface1`/`rCard` come il mockup, asse delle Statistiche «ogni N» calcolato da larghezza e scala, etichetta del valore nella fascia in alto su `surface2`, corpo attenuato con `IgnorePointer` e `ExcludeSemantics`, tocco su `onTapUp`, `TextPainter` liberati. Non applicati: debounce che riparte anche per il solo cursore (innocuo); parole spezzate a 1,79× con 3 colonne (limite della regola 4/3/2).
- Scheggia di passo: nessun bug; test rinforzati (selezione per barra, `_shown` dopo un periodo vuoto, ricerca radio con spazi e trim, soglia 1,3×).
- Sul telefono l'anno mostra tutte e 12 le iniziali (ci stanno in larghezza): la nota «una ogni 2» del mockup scatta solo se non ci stanno.
- **Mi A3** (APK debug 3c62a99): Home con un'etichetta per riquadro nel dump di `uiautomator` («Preferiti, 2 brani», «Radio, In diretta»), blocchi senza divisori; ▶ di «Casuale su tutto» avvia la riproduzione (il «non avvia nulla» della prova 76 non si ripete: il percorso ▶ → `playAll` → `playQueue` è corretto, probabile tocco sul titolo o Jam attiva); Shuffle cambia solo la modalità. Radio: griglia da 4, ✕ «Cancella ricerca», skeleton al posto degli spinner, «Vicino a te» arriva dopo ~10 s. Statistiche: tocco «3 nov, 36 min», trascinamento, giorni futuri non selezionabili, Anno→Mese torna a settembre. Nessuna eccezione nel log.
