# Fase 39 — Fluidità (refactor «ui-fluida»)

**Obiettivo:** eliminare gli scatti che l'utente vede su Mi A3 e Motorola: apertura del player, scorrimento delle liste,
fogli e finestre, cambio di pagina o di scheda. Un rilievo = un passo = una PR/commit piccolo, con misura prima e dopo.

**Prerequisiti:** fase 38 chiusa (strumenti, test A–E, misure di partenza in `docs/refactor/ui-fluida/misure.md`).
Rilievi in `docs/refactor/ui-fluida/analisi.md`, decisioni in `docs/decisioni.md`.

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

**Principio:** si toglie costo (layer di opacità a tutta pagina, `setState` a ogni frame), non si cambia ciò che l'utente
vede, tranne dove una decisione lo dice (D-11: copertina che ruota spenta di default). I test della fase 38 (A, B) devono
restare verdi o essere aggiornati **nello stesso passo** con il motivo scritto nel commit.

## Comportamento invariato
- Stesse schermate, stessi gesti, stessi risultati. Cambiano solo come si disegnano.
- Golden identici (D-20): se un passo li cambia, non va bene, a meno che il passo lo dica (qui: nessuno lo dice).
- `lib/data`, provider, servizi, Jam, l10n non cambiano (tranne la nuova impostazione di 39.6, solo UI e `SettingsStore`).

## Misura (stesso comando prima e dopo ogni passo)
`python3 scripts/perf_device.py 0d7ae9df206e --label <passo> --playback --no-push` via `sorveglia.sh --pesante`
(JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14). Si confronta con `ui-fluida-prima`. Soglie nella tabella della fase 38.
Un passo che peggiora il suo scenario di oltre mezzo punto percentuale si ferma e si annota in `docs/refactor/ui-fluida/misure.md`.

## Task

### 39.1 — F-40: transizione di pagina senza opacità (D-10)
1. Provare in `lib/ui/theme/app_theme.dart` (`CcPageTransitionsBuilder`) due varianti senza `FadeTransition`: scorrimento
   laterale e zoom leggero (durate dei token D-23: 250/320 ms, easeOutCubic in entrata, easeInCubic in uscita).
2. Misurare «Apri album» per tutte e due sul Mi A3. **Vince quella con meno frame oltre 16,7 ms**; il risultato e il
   perché vanno in `misure.md`. Tenere solo la vincente.

**Fatto quando:** `flutter test test/ui/transitions_characterization_test.dart test/ui/motion_test.dart` verde (aggiornato dove la
transizione cambia); `perf_device.py` scenario «Apri album» ≤ 3 %; `flutter analyze` pulito.

### 39.2 — F-41: apertura e chiusura del player (D-18)
1. In `lib/ui/widgets/grow_route.dart`: via la `FadeTransition` a tutta pagina.
2. Costruire le card di `NowPlayingScreen` dopo la fine della transizione (placeholder piatto prima); niente rotazione
   della copertina durante il volo Hero; durata dai token. Il resto lo decide la misura.

**Fatto quando:** `flutter test test/ui/now_playing_grow_test.dart test/ui/transitions_characterization_test.dart` verde; scenario «Apertura player» ≤ 3 % e p99 ≤ 33 ms (oggi 40,8 ms).

### 39.3 — F-44: cambio di scheda senza sfumatura a tutto corpo
`TabFade` in `lib/ui/widgets/motion.dart`: tolta l'opacità sul corpo (stato delle schede conservato, test A).

**Fatto quando:** `flutter test test/ui/motion_test.dart test/ui/app_shell_test.dart test/ui/transitions_characterization_test.dart` verde; «Pallino schede» ≤ 2 % (oggi 4,6 %).

### 39.4 — F-42: swipe del mini player senza ricostruzione
`mini_player.dart`: lo spostamento in un `AnimationController`/`ValueNotifier` + `Transform.translate` su un figlio costruito una volta; i 5 provider non si riosservano a ogni frame.

**Fatto quando:** `flutter test test/ui/transitions_characterization_test.dart` (soglia, ritorno, tap) verde; «Swipe mini player» ≤ 2 %.

### 39.5 — F-31: trascinamento di chiusura del player
`now_playing_screen.dart`: `ValueNotifier` + `Transform` al posto del `setState` a ogni movimento.

**Fatto quando:** `flutter test test/ui/transitions_characterization_test.dart test/ui/now_playing_test.dart` verde; nessun `setState` nel gestore del trascinamento (`grep -n "setState" lib/ui/screens/now_playing/now_playing_screen.dart` non lo mostra nel drag).

### 39.6 — F-33: copertina che ruota come opzione, spenta di default (D-11)
1. Impostazione nuova nel `SettingsStore` (chiave nuova, default `false`; nessuna chiave esistente cambia, D-07) e interruttore nella pagina Aspetto.
2. La rotazione (`motion.dart`) parte solo se accesa, non c'è «riduci animazioni» (app o sistema) e non si è in volo Hero.

**Fatto quando:** `flutter test test/ui/now_playing_reduce_motion_test.dart test/ui/settings_store_test.dart` verde, con un test nuovo «default spento»; `flutter analyze` pulito.

### 39.7 — F-35: tag Hero separati
`mini_player.dart:22,168`, `desktop_player_bar.dart:123`, `now_playing_screen.dart:346`: tag distinti per mini player e barra; controllare nella shell che i due non stiano insieme nell'albero.

**Fatto quando:** `flutter test test/ui/transitions_characterization_test.dart` verde (numero di Hero su telefono e desktop aggiornato nello stesso commit); `grep -rn "'player-cover'" lib/ui` non mostra più lo stesso tag in due file.

### 39.8 — F-30: testi sincronizzati
`lyrics_view.dart`: `ListView.builder`, colore animato al posto di `Opacity` per riga, si ricostruiscono solo la riga vecchia e la nuova. Si accende il test «con 100 righe non si costruiscono tutte» lasciato `skip` in 38.4.

**Fatto quando:** `flutter test test/ui/lists_sheets_characterization_test.dart test/ui/lyrics_screen_test.dart` verde, senza `skip`; `grep -c "Opacity(" lib/ui/screens/lyrics/lyrics_view.dart` = 0.

### 39.9 — F-43: fogli con liste pigre
`tags_sheet.dart`, `activity_sheet.dart`, `devices_sheet.dart`, `artist_picker_sheet.dart`: `ListView.builder` senza `shrinkWrap`. `queue_sheet.dart`: la `ReorderableListView` non si ricostruisce a ogni evento della coda.

**Fatto quando:** `flutter test test/ui/lists_sheets_characterization_test.dart test/ui/queue_reorder_test.dart` verde; scenario «Fogli» ≤ 3 %; `grep -rn "shrinkWrap: true" lib/ui/screens/*sheet*` vuoto per i quattro file.

### 39.10 — F-45: ricerca e cambio di scheda (regressione misurata)
Profilare la ricerca «notte» (risultati ricostruiti a ogni tasto? `debounce`, `select`, chiavi) con lo stesso scenario prima e dopo.

**Fatto quando:** `flutter test test/ui/search_screen_test.dart` verde; scenario «Ricerca» ≤ 3 % e build p99 ≤ 16 ms (oggi 9,8 %, 51,6 ms); «Tutti i brani» ≤ 1 %.

### 39.11 — F-32: riga seek
`now_playing_controls.dart:47`, `desktop_player_bar.dart:342`: `Consumer` solo su `Slider` e tempo.

**Fatto quando:** `flutter test test/ui/now_playing_test.dart test/ui/desktop_player_bar_test.dart` verde; «In riproduzione» build p99 sotto i 115,6 ms di oggi (annotare il valore).

### 39.12 — F-36: animazioni implicite per riga e backdrop
`now_playing_cards.dart:417`, `theme_editor_screen.dart:294`, `track_row_selection.dart:40-54`, `cover_backdrop.dart:29`: backdrop con `TweenAnimationBuilder` dentro `RepaintBoundary`; niente animazioni di layout per riga.

**Fatto quando:** `flutter test test/ui/selection_test.dart test/ui/now_playing_test.dart` verde, golden identici; «Tutti i brani» ≤ 1 %.

### 39.13 — F-65: `AnimatedSize` e movimento ridotto
`now_playing_cards.dart:418`: durata da `ccDuration` (0 con movimento ridotto).

**Fatto quando:** `flutter test test/ui/now_playing_reduce_motion_test.dart` verde con un caso nuovo che verifica durata 0.

### 39.14 — F-64: una sola scala di movimento
1. Una scala in `lib/ui/theme/tokens.dart` (D-23): 120 pressione, 180 entrata, 250 foglio, 320 hero/pagina. `Motion` in `motion.dart` tolta; i letterali 180/300/450/550/160/200 migrano ai token.
2. Gruppi di `screens/` uno per commit.

**Fatto quando:** `grep -rn "Duration(milliseconds" lib/ui | wc -l` ≤ 3 e solo in `tokens.dart`; `flutter analyze` pulito; `flutter test test/ui/motion_test.dart` verde.

### 39.15 — F-66: curve
`Motion.curve` unica: easeOutCubic in entrata, easeInCubic in uscita; via easeOut ×6 e easeInOut sparsi.

**Fatto quando:** `grep -rnE "Curves\.(easeOut|easeInOut)\b" lib/ui` vuoto; `flutter analyze` pulito.

### 39.16 — Misura finale della fase
`python3 scripts/perf_device.py 0d7ae9df206e --label fluidita-dopo --playback` (via `sorveglia.sh`). Tabella confrontata con `ui-fluida-prima` e con le soglie, in `misure.md`. Se una soglia non è raggiunta, si annota quale rilievo resta aperto (non si passa alla 40 senza dirlo all'utente).

**Fatto quando:** `build/perf/fluidita-dopo.md` esiste e `misure.md` ha la colonna «dopo 39» con ogni soglia della fase 38 segnata ok/no.
