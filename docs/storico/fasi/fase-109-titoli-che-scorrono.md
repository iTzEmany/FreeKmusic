# Fase 109 — Titoli che scorrono

**Obiettivo:** nel player a schermo intero, nel mini player, nella barra desktop e nel player della Jam un titolo che non ci sta scorre piano fino a mostrarsi intero; nelle liste resta «…». **Cambio di comportamento voluto** (D-486).

**Prerequisiti:** fase 108 chiusa (anche 107 per il test di caratterizzazione dei titoli). Analisi F-133, F-134, F-135 e «Rete» riga D. Mockup approvato: `refactor/coda-e-libreria/mockup/titoli.html` (D-498). Aree a rischio: nessuna; vincolo di prestazioni: scatti nello scroll ≤ fase 90 (`fase-90-intestazioni-che-scorrono.md`, 1–2 % dei frame).

**Comando mirato:** `flutter test test/ui/marquee_text_test.dart test/ui/mini_player_test.dart test/ui/now_playing_test.dart test/ui/now_playing_reduce_motion_test.dart test/ui/a11y_guidelines_test.dart test/ui/jam_screen_test.dart test/goldens/player_golden_test.dart test/goldens/ui_fluida_golden_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

## Task

### 109.1 — `MarqueeText` (F-133, F-135, D-486)
- Widget nuovo in `lib/ui/widgets/marquee_text.dart` (nessun pacchetto nuovo, D-491). Comportamento:
  - scorre **solo se il testo non ci sta** (misura con `TextPainter`); altrimenti `Text` fermo;
  - pausa iniziale 2 s, scorrimento lento (~30 dp/s) fino a mostrare la fine, pausa, ritorno all'inizio, e ripete;
  - movimento ridotto (`app.dart:124`): testo fermo con «…»;
  - `Semantics` con il titolo intero (come `track_row.dart:378`); la parte che scorre è esclusa dall'albero semantico per non farlo leggere due volte;
  - `IgnorePointer`: nessun tocco intercettato (il mini player si scorre col dito);
  - animazione ferma quando la schermata non è visibile (`TickerMode`) e `dispose` del controller;
  - ripartenza da capo al cambio di brano/titolo.
- Test `test/ui/marquee_text_test.dart` (uno per comportamento): titolo corto fermo; lungo scorre dopo 2 s; movimento ridotto fermo con «…»; etichetta col titolo intero; il tocco arriva al genitore; animazione ferma a schermata coperta; reset al cambio titolo.

### 109.2 — Dove si usa (F-133, F-134)
- Sostituire `Text(maxLines: 1, overflow: ellipsis)` con `MarqueeText` per il titolo (e l'artista dove il mockup lo mostra) in `now_playing_screen.dart:603`, `widgets/mini_player.dart:154+`, `shell/desktop_player_bar.dart:107,169,238`, `screens/jam/jam_player.dart:290`.
- **Non** in `widgets/track_row.dart:384`, `now_playing/queue_sheet.dart:332,393`, `collection_header.dart` (D-486: nelle liste resta «…»).
- Test: i test di 107.4 (titolo lungo con «…») cambiano e dicono che il titolo scorre; `mini_player_test.dart`, `now_playing_test.dart`, `now_playing_reduce_motion_test.dart` (movimento ridotto = «…»), `a11y_guidelines_test.dart`, `jam_screen_test.dart`; overflow a 200 % del mini player (`ui_fluida_golden_test.dart:50-53`); golden con titoli lunghi dove ci sono.

### 109.3 — Prestazioni
- Controllo: `grep -rn MarqueeText lib/ui/widgets/track_row.dart lib/ui/screens/now_playing/queue_sheet.dart` = 0 righe.
- `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label marquee-109 --playback` (con `sorveglia.sh --pesante 40m`), confronto con `prima-107` in `refactor/coda-e-libreria/misure.md` e con i valori della fase 90: nessun peggioramento degli scatti nello scroll e col player aperto.

### 109.4 — Controlli di fase
`flutter analyze`; comando mirato; review del diff (Sonnet); prova sul Mi A3 contro `titoli.html` con un titolo lungo (player, mini player, Jam) e con «Rimuovi animazioni» attivo. Ripulire il telefono.

**Fatto quando:** i titoli lunghi scorrono nei quattro posti e solo lì, TalkBack legge il titolo intero, le prestazioni non peggiorano, i test sono verdi.

## Da decidere
(nessuno)
