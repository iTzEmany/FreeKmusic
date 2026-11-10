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
- **90.1**:
  - `ShrinkingHeader` è uno sliver flottante scritto a mano (`RenderSliverSingleBoxAdapter`). Segue il dito 1:1 e non ha snap; il figlio è spostato con `paintOffset`, così disegno e tocco coincidono; ha sfondo opaco.
  - `SliverFloatingHeader` di Flutter è stato scartato: fa sempre lo snap a fine gesto. `SliverAppBar(floating)` è stato scartato perché, con una parte fissa, ha una zona morta.
- **90.2**: Tutti i brani ha una riga fissa fuori dallo scroll (conteggio, tempo, shuffle, play); ricerca e filtri stanno nell'intestazione che si ritrae. Il salto A–Z nasconde l'intestazione e porta la riga subito sotto la riga fissa; la striscia A–Z parte sotto l'intestazione visibile.
- **90.3**:
  - L'isola (`library_island.dart`) è un corpo unico sopra la lista. Il titolo esce per primo, poi Ordina per; le schede restano. Le righe crescono con la scala del testo, e a ogni frame di scroll si ricostruiscono solo i due ritagli.
  - Il Registro è sempre visibile nel titolo.
  - **Scostamento dal documento**: l'isola non usa `ShrinkingHeader`. La riga delle schede resta ferma fra due righe che escono, e uno sliver flottante non si può impilare (verificato nella review di 90.1). L'isola è quindi una superficie sopra la lista, guidata dalle notifiche di scroll.
- **90.4**: la lente si allarga nel campo dentro l'isola (con riduci movimento non c'è animazione). In ricerca la riga di Ordina per si chiude; le schede filtrano i risultati e mostrano tutte le voci della sezione; la selezione non agisce sui brani nascosti.
  - Differenza minore dal mockup, accettata (D-3a): i risultati della lente partono sotto l'isola invece di scorrerle sotto.
- **Review**:
  - review Sonnet (high) dello sliver: bug critico del `paintOffset` (l'intestazione non scorreva davvero e i tocchi andavano al bersaglio sbagliato), hit test oltre la viewport, unbind del controller; tutto corretto con test sulle posizioni disegnate;
  - `code-review high` (Opus) su `library_screen`: 10 rilievi, 9 applicati (fling a lente aperta, selezione nascosta, campo che chiudendosi teneva il focus, animazione della lente inerte, scala del testo, risultati per scheda, risultati coperti durante l'animazione, ricostruzioni per frame, scroll fra griglia ed elenco); scartato «un solo componente» (vedi sopra). In più, il Registro mancava nel titolo.
- **Scheggia**: 4 mutanti su 6 uccisi; i 2 sopravvissuti e un terzo caso sono stati coperti con test nuovi. Sul Mi A3 l'isola, la lente durante un fling, i filtri per scheda, il Registro, il salto A–Z avanti e indietro e l'ultima riga sopra il dock sono a posto. Due bug corretti con test: l'intestazione di Tutti i brani era trasparente sopra le righe; dopo un cambio di scheda o di vista le prime righe potevano restare sotto l'isola.
- **Golden**: 16 rigenerati (Libreria in tutte le schede, lente, Tutti i brani).
- **Misure sul Mi A3**, build profile, % di frame oltre 16,7 ms (il primo giro dopo l'installazione è scartato perché c'è il riscaldamento):

  | Scenario | Base 87 | Fase 90 |
  |---|---|---|
  | Scroll Libreria (isola) | 4,7 % | 0,8–1,1 % |
  | Lente Libreria | 1,9 % | 0,8–1,2 % |
  | Scroll Tutti i brani | 2,3 % | 1,2 % |
  | Cambio scheda | 5,5 % | 2,1 % |
- **Limiti noti**: una scheda interna della Libreria non ricorda più la sua posizione (riparte in cima, per non lasciare righe sotto l'isola); con un tema con immagine di sfondo l'intestazione di Tutti i brani è un rettangolo pieno del colore di fondo.
- **Non provati**: rotazione e scala del carattere di sistema sul telefono (regole del dispositivo); la scala 2.0 è coperta dai widget test.
- **Motorola**: rinviato alla fase 97 (D-419, D-420).
