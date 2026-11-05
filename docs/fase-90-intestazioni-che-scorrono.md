# Fase 90 — Intestazioni che scorrono e isola della Libreria (refactor «superfici-e-ricerca»)

**Obiettivo:** un solo componente di intestazione che si ritrae di quanto si scorre, usato da Tutti i brani e dall'isola della Libreria, con la lente rifatta dentro l'isola.

**Prerequisiti:** fase 89 chiusa (dock e margine in fondo). Mockup `refactor/superfici-e-ricerca/mockup/tutti-i-brani.html` e `libreria.html`. Decisioni D-391, D-398, D-407, D-409, D-416. Area a rischio: `lib/ui/screens/library/library_screen.dart` (`code-review high`).

**Comando mirato:** `flutter test test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/alpha_scroller_test.dart test/ui/alpha_scroller_offset_test.dart test/ui/app_shell_test.dart test/ui/a11y_guidelines_test.dart test/ui/talkback_labels_test.dart test/ui/button_tap_sweep_test.dart` più il test nuovo del componente (es. `test/ui/shrinking_header_test.dart`).

## Task

### 90.1 — Componente «intestazione che si ritrae» (D-407)
- Widget condiviso in `lib/ui/widgets/` (`SliverAppBar(floating: true, snap: false)` o `SliverPersistentHeader` con extent variabile): si ritrae di quanto si scorre, riappare risalendo.
- Test: segue il dito 1:1 (offset dell'intestazione = delta di scroll); riappare risalendo; con riduci movimento nessuna animazione di snap; altezza minima/massima rispettate.

### 90.2 — Tutti i brani (F-78)
- `all_tracks_screen.dart:136-165,269`: via `_onScroll` sulla direzione e `SizeTransition`. Riga fissa conteggio/tempo/shuffle/play; ricerca + filtri nell'intestazione che si ritrae; `CustomScrollView` + `SliverFixedExtentList`.
- `AlphaScroller`: offset = indice × altezza riga meno l'altezza visibile dell'intestazione; aggiornare `alpha_scroller_offset_test.dart` della 87.
- Riscrivere il test della barra in `all_tracks_screen_test.dart`. Test nuovi: ricerca attiva con intestazione ritratta; salto A–Z preciso.

### 90.3 — Isola della Libreria (F-77, D-391, D-407, D-409)
- `library_screen.dart:248-262,333-556`: via `_Veil` e `_LibraryHeader`. Un corpo unico `surface2` con il raggio del dock e margini laterali 8 dp, tre righe: titolo (lente, Registro, +) / schede / conteggio + Ordina per + vista.
- Scorrendo esce prima la riga del titolo (56 dp), poi quella di Ordina per (48 dp); le schede restano fisse. `ScanStatus` e `_KindTabs` dentro l'isola.
- Test: righe che si ritraggono nell'ordine; schede sempre visibili; Registro nel titolo; margine in fondo (89.1) ancora rispettato; bersagli ≥ 48 dp.

### 90.4 — Lente nell'isola (F-77, D-391, D-409)
- Sostituisce `_lensShift`, `_measure`, `_Veil` e il `TweenAnimationBuilder` (`library_screen.dart:296-550`): la lente si apre dentro l'isola con i token di animazione, ferma con riduci movimento.
- In ricerca la riga di Ordina per si chiude e le schede filtrano i risultati.
- Riscrivere i test della lente in `library_screen_test.dart`. Test nuovi: apri/chiudi con Esc e indietro; scheda filtra; Ctrl+F (`librarySearchRequestProvider`); semantica.

### 90.5 — Controlli di fase
`flutter analyze`; comando mirato; golden Libreria (Tutto/Playlist/Album/Artisti, lente aperta) e Tutti i brani rigenerati con `scripts/shots.sh`; review del diff (`code-review high` su `library_screen.dart`); scheggia (scroll veloce, lente durante scroll, scala testo 2.0, rotazione); prova sul Motorola (ZY22HKD85K) e sul Mi A3 (0d7ae9df206e) via adb. Misure `perf_device.py` degli scenari nuovi della 87 (scroll Libreria con isola, lente aperta/chiusa, scroll Tutti i brani con barra che si ritrae) confrontate con la base della 87 (soglie in `analisi.md` «Rete», D-398).

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
