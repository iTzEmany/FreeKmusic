# Fase 40 — Accessibilità e token (refactor «ui-fluida»)

**Obiettivo:** far valere le opzioni di sistema, portare contrasto e bersagli ai minimi, dare ai gesti un'etichetta e una
via da tastiera, e fissare i token di arrivo (D-23) prima del nuovo aspetto. Un rilievo = un passo.

**Prerequisiti:** fase 39 chiusa. Test D ed E della fase 38 (`a11y_guidelines_test`, `contrast_test`, golden a 200 %).

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

## Cambi di comportamento voluti (qui, e solo qui)
- Animazioni ridotte se lo chiede l'app **o** il sistema; scala del testo = sistema × app (D-14).
- Contrasto corretto: `textFaint` e accento come testo su s2/s3 (D-17): **piccolo cambio di aspetto, golden rigenerati**
  (D-20), e solo nei passi 40.2 e 40.3, con il motivo nel commit.
- Densità compatta solo con il mouse del desktop; sul telefono bersagli ≥ 48 dp (D-15).
- Copertine decorative escluse dalla semantica (D-16).
- Tema personalizzato poco leggibile: solo un **avviso**, nessuna correzione automatica (D-13).

## Comportamento invariato
Tutto il resto: golden identici fuori dai passi 40.2, 40.3, 40.5 (bersagli, se spostano pixel) e 40.9; `lib/data`, provider,
servizi, Jam, l10n non cambiano; chiavi delle impostazioni e file di tema restano leggibili.

## Test in locale
Solo quelli toccati dal passo. Golden: `flutter test test/golden --update-goldens` **solo** nei passi che lo dicono, poi
`git diff --stat test/golden` per controllare che cambino solo i file attesi.

## Task

### 40.1 — F-60: opzioni di sistema (D-14)
`lib/app.dart:70-72`: `reducedMotion = s.reducedMotion || MediaQuery.disableAnimationsOf(context)`; `TextScaler` = scala di sistema × `s.fontScale`. Tutti i punti che leggono `reducedMotion` usano lo stesso valore.

**Fatto quando:** `flutter test test/ui/accessibility_characterization_test.dart test/ui/font_scale_test.dart test/ui/now_playing_reduce_motion_test.dart` verde, con test nuovi «sistema chiede meno animazioni» e «sistema 1,3 × app 1,5 = 1,95»; il test D che fissava il difetto è aggiornato.

### 40.2 — F-61: `textFaint` ≥ 4,5:1
`lib/ui/theme/tokens.dart:44,68`: scuro #887F99, chiaro #6D6280 (D-23), verificati su s1. Golden rigenerati.

**Fatto quando:** `flutter test test/theme/contrast_test.dart` verde con `textFaint` su s1 ≥ 4,5 in tutti e 3 i temi; `flutter test test/golden --update-goldens` e `git diff --stat test/golden` mostra solo golden con testo debole.

### 40.3 — F-62 (D-17): accento ed errore su s2/s3
`palette.dart:40-47`, `tokens.dart:62,64`: come testo su s2/s3 si usa `accentSoft` (tutti gli 8 accenti, tema chiaro compreso). Golden rigenerati.

**Fatto quando:** `flutter test test/theme/contrast_test.dart` verde con `accentSoft` e errore su s2/s3 ≥ 4,5 per 8 accenti × 3 temi.

### 40.4 — F-63 (D-13): avviso sul tema personalizzato
Solo avviso, nell'editor e all'import del tema, quando text/muted/faint su bg stanno sotto 4,5 (usa `ensureContrast` per calcolare, non per correggere). `resolve()` e `fromJson` non cambiano i colori; il file di tema resta com'è (D-07).

**Fatto quando:** `flutter test test/theme/custom_theme_test.dart` verde con un test nuovo: bg #808080 produce l'avviso e i colori restano quelli del file; stringa ARB nuova in it/en/de/es e `flutter gen-l10n` senza errori.

### 40.5 — F-70 (D-15): bersagli da 48 dp
`app_theme.dart:106` compact solo se il puntatore è il mouse del desktop; `mini_player.dart:286`, `online_queue_row.dart:117`, `duplicate_member_row.dart:124`, `jam_parts.dart:203`, `radio_now.dart:75`, `peer_card.dart:96,105`, `alpha_scroller.dart:67` portati a 48 dp su telefono.

**Fatto quando:** `flutter test test/ui/a11y_guidelines_test.dart` verde con la lista di eccezioni **più corta** (le voci sistemate tolte); `grep -rn "VisualDensity.compact" lib/ui` solo dietro il controllo del puntatore.

### 40.6 — F-71: gesti con etichetta e tastiera
`mini_player.dart:242`, `desktop_player_bar.dart:112`, `album_card.dart:43`, `preview_cover.dart:26`: `InkWell` + `Semantics(button, label)`; azione di accessibilità per l'anteprima (oggi solo pressione lunga).

**Fatto quando:** `flutter test test/ui/a11y_guidelines_test.dart` verde (`labeledTapTargetGuideline`) con lista di eccezioni più corta; test nuovo: da tastiera Invio apre il player dal mini player.

### 40.7 — F-74: focus visibile
`app_theme.dart:97`: `focusColor` con alfa circa 0,4 e un contorno sui tasti principali; `FocusTraversalGroup` nella shell e nel mini player.

**Fatto quando:** `flutter test test/ui/focus_test.dart` verde (nuovo: il focus sul tasto play ha un contorno); `grep -rc "FocusTraversalGroup" lib/ui` > 0.

### 40.8 — F-72 (D-16): copertine e lettore di schermo
`cover_image.dart:87`: `excludeFromSemantics: true` di default; etichetta solo dove la copertina è l'unico contenuto (es. grande nel player).

**Fatto quando:** `flutter test test/ui/a11y_guidelines_test.dart test/ui/cover_image_test.dart` verde; test nuovo: una riga di brano espone un solo nodo per titolo+artista, non uno in più per la copertina.

### 40.9 — F-73: scala del testo al 200 %
`app.dart:72` (tetto 2,0, D-31), `mini_player.dart:144` (56 dp fissi), `car_mode_screen.dart:59`: nessun overflow a textScale 2,0. I golden a 200 % di 38.6 si aggiornano **qui** (aspetto cambiato apposta).

**Fatto quando:** `flutter test test/ui/large_text_test.dart test/ui/anello_text_scale_test.dart test/golden` verde; mini player, dock e car mode a 2,0 senza overflow.

### 40.10 — F-67: stili di testo nel tema
27 `TextStyle(` e 16 `fontSize:` fuori dal tema → `TextTheme`; 11 px portati al minimo di 12 (`bottom_bar.dart:247`, `now_playing_screen.dart:273`, `stats_charts.dart:36`). Unbounded solo per l'invito della Home (28) e i titoli (20); Figtree 15/13/12 (D-23). Golden rigenerati dove il testo cresce.

**Fatto quando:** `grep -rn "fontSize:" lib/ui | wc -l` ≤ 2 (solo nel tema); `flutter analyze` pulito; `flutter test test/golden` verde dopo la rigenerazione motivata.

### 40.11 — F-68: scala di spaziature e raggi
`CcDims`: costanti `gap4/8/12/16/24/32` e raggi 4/8/12/16/28 (D-23); i 4 raggi letterali e gli `EdgeInsets` più usati migrano per gruppo di `screens/` (un commit a gruppo). Niente ombre, separatori 1 dp in s2.

**Fatto quando:** `grep -rnE "BorderRadius.circular\([0-9]" lib/ui | wc -l` = 0 fuori da `CcDims`; `flutter analyze` pulito; golden identici (valori uguali a quelli di oggi).

### 40.12 — F-69: `oled`
`tokens.dart:34-47`: `oled = notte.copyWith(bg: Colors.black)`.

**Fatto quando:** `flutter test test/theme/tokens_test.dart test/theme/contrast_test.dart` verde (nuovo: `oled` diverso da `notte` solo per `bg`); golden identici.
