# Fase 48 — Shuffle a 3 stati e Home

**Obiettivo:** il pulsante shuffle cicla nessuno → shuffle → Shuffle+ → nessuno senza interruttore nelle impostazioni,
e salta Shuffle+ quando la coda non lo permette. Attivando Shuffle+ a coda in corso i suggeriti entrano subito nel
piano; spegnendolo escono quelli non ancora suonati. In Home, «Casuale su tutto» ha un pulsante Play e lo stesso
pulsante shuffle a 3 stati del player.

**Prerequisiti:** fasi 45–47 chiuse (i suggeriti passano dalla cache). Fase 31 (`ShufflePlusController`,
`nextInsertion`, `ShuffleButton`, `ShufflePlusTiles`, `shuffle_plus_sheet.dart`), fase 43 (Home, `ShuffleHero`).

**Riferimenti:** `docs/feature-streaming.md` (R-25, R-26, R-27, R-28, R-31, R-30; componente «Shuffle»; K-03);
decisioni D-72, D-73, D-76, D-81 (chiave `shufflePlus` invariata).

**Intoccabili (D-76):** libreria e playlist; i download di oggi; la fluidità. **Nessun pacchetto nuovo.** **Schema
del DB invariato (D-77).** Chiavi delle impostazioni: `shufflePlus`, `shufflePlusEvery`, `shufflePlusUnmeteredOnly`
restano con lo stesso nome e significato (`shufflePlus` = il bit della modalità che `cycleShuffle` salva, D-81).

## Task

### 48.1 — `plusAllowed` e ciclo che salta Shuffle+
**File:** `lib/providers/player_providers.dart` (`cycleShuffle`), `lib/services/shuffle_plus/plus_allowed.dart`
(nuovo, funzione pura `plusAllowed(...)`), ARB (messaggi), `test/services/shuffle_plus/plus_allowed_test.dart`,
`test/ui/shuffle_button_test.dart`
1. `plusAllowed` → `null` se Shuffle+ è possibile, altrimenti il motivo: coda di un album in streaming (tutte entry
   online / `playOnlineList`), Jam attiva, radio (`PlayContextKind.radio`), meno di 5 brani locali nella lista. Gli
   altri blocchi di oggi (`ShufflePlusBlock.noTool`, `metered`, `stopped`) non tolgono lo stato dal ciclo: Shuffle+
   resta scelto e in attesa come oggi.
2. `cycleShuffle`: con `plusAllowed` ≠ null il ciclo è nessuno → shuffle → nessuno; la modalità si salva come oggi.
3. Messaggio breve che spiega perché, «la prima volta»: **una volta per sessione** (stato in memoria, nessuna chiave nuova; D-87).

R-25.
**Fatto quando:** `flutter test test/services/shuffle_plus/plus_allowed_test.dart test/ui/shuffle_button_test.dart`
verde: coda di album online → ciclo off → shuffle → off; Jam → idem; radio → idem; 4 brani locali → idem; coda locale
di ≥ 5 brani → off → shuffle → plus → off; messaggio mostrato secondo la regola decisa al punto 3. `flutter analyze` pulito.

### 48.2 — Suggeriti inseriti subito e tolti allo spegnimento
**File:** `lib/services/shuffle_plus/insertion_plan.dart` (funzione pura `plusPlan(items, currentIndex, every)` →
posizioni), `lib/services/shuffle_plus/shuffle_plus_controller.dart`, `lib/providers/shuffle_plus_providers.dart`,
`test/services/shuffle_plus/insertion_plan_test.dart`, `test/providers/shuffle_plus_test.dart`
1. Attivando Shuffle+ a coda in corso i suggeriti entrano subito nel piano: uno ogni N brani (N =
   `shufflePlusEvery`) a partire dal brano corrente, quindi il primo dopo N brani, senza aspettare il cambio di brano
   (R-26). Il bacino si riempie con i limiti di oggi (1 radio al minuto, pausa su 429).
2. Spegnendo Shuffle+ (dal ciclo, dalla notifica/MPRIS che spengono lo shuffle) si tolgono dalla coda i suggeriti dopo
   il corrente (`removeQueueId` + `forget`); il corrente e quelli già suonati restano (R-27).

R-26, R-27.
**Fatto quando:** `flutter test test/services/shuffle_plus/insertion_plan_test.dart test/providers/shuffle_plus_test.dart`
verde: coda di 20 brani locali, posizione 5, N = 4 → suggeriti alle posizioni previste dal piano senza un cambio di
brano; plus → off toglie i suggeriti dopo il corrente e lascia il corrente e i precedenti; i casi di oggi (Jam, rete a
consumo, 429) verdi. `flutter analyze` pulito.

### 48.3 — Impostazioni e foglio Shuffle+ senza interruttore
**File:** `lib/ui/screens/settings/shuffle_plus_tiles.dart` (via lo `SwitchListTile` di `shufflePlus`),
`lib/ui/screens/now_playing/shuffle_plus_sheet.dart`, ARB, `test/ui/shuffle_plus_tiles_test.dart`
1. Al posto dell'interruttore la nota «Si attiva dal pulsante shuffle (terzo tocco). Non disponibile per album in
   streaming, Jam e radio»; restano «1 ogni N» e «Solo su Wi‑Fi». Il foglio (pressione lunga sul pulsante) segue lo
   stesso schema, con lo stato attuale di oggi.

R-28.
**Fatto quando:** `flutter test test/ui/shuffle_plus_tiles_test.dart` verde: nessuno `SwitchListTile` per
`shufflePlus` nelle impostazioni né nel foglio; la nota è presente; intervallo e «Solo su Wi‑Fi» ci sono.
`grep -n "shufflePlus: on" lib/ui/screens/settings/shuffle_plus_tiles.dart` = 0. `flutter analyze` pulito.

### 48.4 — Home: Play e shuffle separati in «Casuale su tutto»
**File:** `lib/ui/screens/home/home_blocks.dart` (`ShuffleHero`), `lib/ui/widgets/shuffle_button.dart` (riuso),
ARB, `test/ui/home_screen_test.dart`
1. Due pulsanti: Play (avvia `playAll` di tutta la libreria con la modalità scelta) e lo stesso `ShuffleButton` a 3
   stati del player, che cambia solo la modalità e non avvia nulla. Oggi `ShuffleHero` accende lo shuffle e avvia: il
   tocco unico sparisce.

R-31.
**Fatto quando:** `flutter test test/ui/home_screen_test.dart` verde: il tocco sullo shuffle in Home cambia la modalità
senza chiamare `playAll`; Play chiama `playAll` con la modalità scelta (shuffle spento → in ordine; shuffle o plus →
mescolato). `flutter analyze` pulito.

### 48.5 — Controlli di fase (K-01, K-02, K-03)
1. K-01: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
2. K-02: `flutter test test/data/stream_rows_hidden_test.dart` verde.
3. K-03 (D-19, come in 45.7):
   `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 40m <scratchpad>/perf48.log -- python3 scripts/perf_device.py 0d7ae9df206e --label streaming-48 --playback`;
   tabella «Dopo la fase 48» in `misure.md` contro «Finale», con la tolleranza decisa in 45.7.
4. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–4 sono verdi; `build/perf/streaming-48.md` esiste e la tabella copre ogni
riga di «Finale».

### 48.6 — Prove a mano (utente) [~]
Materiale per l'utente (R-30, K-04). Su **Linux e Mi A3**:
- Playlist di ≥ 5 brani: tre tocchi sul pulsante shuffle → shuffle, Shuffle+, nessuno; a Shuffle+ i suggeriti compaiono
  subito nella coda, uno ogni N dal brano corrente (R-25, R-26); al quarto tocco spariscono quelli non suonati (R-27).
- Album online in streaming, Jam, radio: il ciclo salta Shuffle+ e il messaggio spiega perché (R-25).
- Impostazioni e foglio Shuffle+: nessun interruttore, la nota c'è (R-28).
- Home: lo shuffle cambia solo la modalità; Play avvia tutta la libreria in quell'ordine (R-31).
- Log senza 403/429 ripetuti dopo 30 minuti di Shuffle+ (K-04).

**Fatto quando:** l'utente conferma le prove su Linux e Mi A3 (casella `[~]` → `[x]` in PROGRESS).
