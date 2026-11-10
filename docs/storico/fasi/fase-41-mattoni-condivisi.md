# Fase 41 — Mattoni condivisi (refactor «ui-fluida»)

**Obiettivo:** aggiungere una funzione non deve voler dire toccare 62 file. Si creano i mattoni che mancano in
`lib/ui/widgets/` e si migrano le schermate. Nessuna schermata si riscrive da zero (D-06).

**Prerequisiti:** fasi 38–40 chiuse (le soglie di fluidità raggiunte, token fissati).

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

## Percorso a piccoli passi (strangler, D-24)
1. Si crea il mattone nuovo **con il suo test**, mentre il vecchio resta.
2. Si migrano i file a gruppi: **una cartella di `lib/ui/screens/` per commit**. Dopo ogni gruppo: `flutter analyze` e i test toccati verdi.
3. Quando l'ultimo uso del vecchio sparisce, si toglie il vecchio (commit a parte).

Ogni mattone ha tre sotto-passi nel suo task: **a)** mattone + test, **b)** migrazione per gruppi (elencare in
PROGRESS i gruppi fatti), **c)** rimozione del vecchio e controllo del grep di arrivo.

## Comportamento invariato
- Ogni schermata migrata appare e si comporta come prima: stessi testi, durate, colori. Golden identici (D-20).
- `lib/data`, provider, servizi, Jam, l10n non cambiano (il messaggio resta nella stessa chiave ARB).
- I test della fase 38 (C) per le copie vecchie restano verdi dopo la migrazione: ora provano il mattone nuovo.

## Test in locale
Solo i test dei file toccati dal gruppo e quello del mattone. `integration_test` gira una volta prima di 41.1 e una dopo 41.8
(gruppo C della «Rete»), via `sorveglia.sh --pesante`.

## Task

### 41.1 — F-01: `showMsg(context, text)`
1. a) `lib/ui/widgets/show_msg.dart`: un messaggio alla volta (sostituisce il precedente), durata fissa dai token, sicuro dopo un `await` (controlla `context.mounted`). Test: durata, un messaggio alla volta, smontaggio dopo await.
2. b) Migrare le funzioni `say()` locali e i `SnackBar(` (106 usi in 62 file; es. `backup_section.dart:79`, `duplicates_screen.dart:22`, `radio_actions.dart:41`), un gruppo per commit. Le `SnackBar` con azione («Annulla») usano un parametro `action` del mattone.
3. c) Togliere le copie locali.

**Fatto quando:** `flutter test test/ui/show_msg_test.dart` verde; `grep -rn "SnackBar(" lib/ui | wc -l` = 1 (dentro `show_msg.dart`); `flutter analyze` pulito.

### 41.2 — F-06: `promptName()`
a) Dialogo «scegli un nome» in `widgets/` con le regole di validazione comuni (le 6 copie a confronto sono nel test di 38.5: si prendono le più severe, D-32, e si dice quali nel commit). b) Migrare `playlist_dialogs.dart:66`, `tags_screen.dart:38`, `tags_sheet.dart:196,287`, `desktop_sidebar.dart:220`, `playlist_picker.dart:32`, `playlists_screen.dart:38`. c) Togliere le copie.

**Fatto quando:** `flutter test test/ui/prompt_name_test.dart test/ui/name_dialogs_characterization_test.dart` verde; `grep -rln "TextEditingController" lib/ui/screens | xargs grep -l "AlertDialog" ` non elenca più i 6 file per il nome.

### 41.3 — F-12: `CcAppBar`
a) `CcAppBar` in `widgets/` (titolo da tipografia D-23, azioni, schede). b) Migrare i 48 `AppBar(` a gruppi; `CollectionHeader` (2 usi) resta una variante dichiarata. c) Un solo `AppBar(` rimasto, dentro `CcAppBar`.

**Fatto quando:** `flutter test test/ui/cc_app_bar_test.dart test/golden` verde con golden identici; `grep -rn "AppBar(" lib/ui | grep -v CcAppBar | wc -l` = 1.

### 41.4 — F-13: `AsyncBody<T>`
a) Wrapper di `AsyncValue<T>` con caricamento (lineare), vuoto, errore («Riprova» + `AppLog`) e dati; usa gli stati vuoti della casa. Test: i 4 stati, errore con ritenta. b) Migrare i 32 `CircularProgressIndicator` e 19 lineari fatti a mano e i `.when(` locali, a gruppi. c) Togliere gli stati a mano.

**Fatto quando:** `flutter test test/ui/async_body_test.dart` verde; `grep -rn "CircularProgressIndicator" lib/ui | wc -l` ≤ 3 (spinner di azione, dentro i mattoni); `flutter analyze` pulito.

### 41.5 — F-14: una regola per finestre e fogli
Regola scritta in `docs/02-architettura.md`: **dialogo per il testo, foglio per le scelte**. Il `showModalBottomSheet` crudo passa da `showCcSheet`; i `showDialog` che sono scelte si spostano un gruppo per volta.

**Fatto quando:** `grep -rn "showModalBottomSheet" lib/ui | wc -l` = 1 (dentro `showCcSheet`); `flutter test test/ui/lists_sheets_characterization_test.dart` verde.

### 41.6 — F-18: `AppLog` nei catch tipizzati
Gli 8 catch tipizzati senza log ricevono `AppLog.w`; il messaggio all'utente non cambia.

**Fatto quando:** `grep -rnE "on [A-Za-z]+ catch" lib/ui` mostra un `AppLog` in ogni blocco (controllo a vista sulle 8 righe, elencate nel commit); `flutter analyze` pulito.

### 41.7 — F-19: `reorder(ids)` atteso
`radio_sections.dart:142`: `await` + messaggio d'errore con `showMsg` (41.1). Test: un errore di `reorder` mostra il messaggio e ripristina l'ordine.

**Fatto quando:** `flutter test test/ui/radio_sections_test.dart` verde con il caso d'errore; `flutter analyze` pulito (nessun `unawaited_futures`).

### 41.8 — Chiusura della fase
Metriche di struttura con `python3 scripts/build_len.py lib/ui` e i grep della fase 38; `integration_test` (gruppo C) via `sorveglia.sh`.

**Fatto quando:** `SnackBar(` = 1 · `AppBar(` = 1 · `flutter test integration_test -d linux` verde · `docs/refactor/ui-fluida/misure.md` aggiornato con i conteggi.
