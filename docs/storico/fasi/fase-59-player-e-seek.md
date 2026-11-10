# Fase 59 — Player e seek (refactor «ui-jam-ricerca»)

**Obiettivo:** scheda del testo di nuovo stabile, poi un solo seek (anello + barra orizzontale) con una sola fonte di posizione
e un solo stato di trascinamento, riusabile dalla Jam (fase 63).

**Prerequisiti:** fase 58 chiusa. Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`. Decisioni D-156, D-161.
Mockup: `docs/refactor/ui-jam-ricerca/mockup/jam-player.html` (fotogramma del player senza Jam).

**Comando mirato:** `flutter test test/ui/ring_progress_test.dart test/ui/now_playing_test.dart test/ui/seek_characterization_test.dart test/ui/lyrics_screen_test.dart`.

## Task

### 59.1 — Scheda del testo a larghezza piena e altezza fissa (F-58, D-161)
`now_playing_screen.dart` `_cards()`: `crossAxisAlignment: CrossAxisAlignment.stretch` sul `Column` dentro `RiseIn` (regressione della fase 39, bf4656d).
`LyricsCard` (`now_playing_cards.dart`): corpo alto 5 righe fisse per testo sincronizzato, semplice e assente; in `_SyncedLines`
la finestra di 5 righe arretra a fine brano (`from = (center-2).clamp(0, max(0, len-5))`) invece di accorciarsi.

**Fatto quando:** test nuovo: `LyricsCard` ha la stessa larghezza delle altre schede e la stessa altezza con testo sincronizzato
(anche sulle ultime 2 righe), semplice e assente; comando mirato verde.

### 59.2 — `RingProgress` con posizione e `onSeek` iniettati (F-04, F-17)
Parametri opzionali `position`, `duration`, `onSeek`; di serie restano `positionProvider`, `durationProvider` e `playerController.seek`.
Il painter resta isolato (RepaintBoundary) e ascolta la fonte di 59.3 con `repaint:`.

**Fatto quando:** test nuovo con posizione e `onSeek` finti; i casi di `seek_characterization_test` (angolo, vuoto di 40°) verdi senza modifiche.

### 59.3 — Una sola fonte di posizione (F-06, F-18)
Posizione interpolata ~10 aggiornamenti/s, ferma in pausa e a schermata coperta, usata da anello, barra e tempi.
Sostituisce il Timer da 500 ms di `jam_seek_bar.dart`.

**Fatto quando:** test nuovo: in pausa nessun aggiornamento in 2 s simulati; in riproduzione la posizione avanza in modo continuo.

### 59.4 — `SeekBar` condivisa e un solo stato di trascinamento (F-08, F-09)
Un widget `SeekBar(position, duration, onSeek)` al posto dei tre `Slider` con `_dragging` (Jam, desktop, player).
`ringDragProvider` diventa uno stato di trascinamento dal nome neutro, scritto da anello e barra.

**Fatto quando:** test nuovo: trascinando la barra l'anello mostra la stessa posizione, e viceversa; seek solo al rilascio.

### 59.5 — Barra orizzontale di nuovo nel player (F-07, F-03)
In `NpSeekRow` (`now_playing_controls.dart`) la barra torna fra i due tempi; chip di qualità e velocità sotto, centrati (mockup).
Il vuoto di 40° dell'anello resta (identità, F-03).

**Fatto quando:** `now_playing_test` riscritto di proposito (righe 62, 161-213) verde; golden `now_playing` rigenerati una volta (`flutter test --update-goldens test/goldens/<file>`) e confrontati con il mockup.

### 59.6 — Accessibilità del seek (F-14, F-15)
TalkBack annuncia solo l'anello come slider (±5 s); la barra è esclusa dalla semantica. Tempi a 12 sp minimo (token).

**Fatto quando:** test nuovo «un solo slider»; `flutter test test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart test/ui/font_scale_test.dart test/ui/large_text_test.dart` verde.

### 59.7 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; comando mirato e `flutter test test/goldens` verdi; review del diff; CI della PR verde.
