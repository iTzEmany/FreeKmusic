# Fase 108 — Coda: «Aggiungi in coda» come blocco in cima

**Obiettivo:** «Aggiungi in coda» mette i brani dopo il corrente, in ordine di arrivo, davanti ai suggeriti; shuffle, Shuffle+ e simili da Cerca non lo mescolano; «Riproduci dopo» sparisce. **Cambi di comportamento voluti** (D-483, D-487, D-488, D-489, D-492, D-493, D-494, D-495, D-496, D-497).

**Prerequisiti:** fase 107 chiusa. Analisi F-129, F-130, F-131, F-132; «Arrivo» (struttura del blocco in `PlayQueue`, tabella delle operazioni, percorso a 6 passi) e «Rete» righe A, B, C. Mockup approvato: `refactor/coda-e-libreria/mockup/coda.html` (D-498). Aree a rischio: audio handler e `PlayQueue` (`/code-review high`), persistenza, Jam (invariata, D-491).

**Comando mirato:** `flutter test test/services/audio/play_queue_test.dart test/services/audio/play_queue_characterization_test.dart test/services/audio/codecore_audio_handler_test.dart test/services/audio/gapless_handler_test.dart test/services/audio/playback_persistence_test.dart test/providers/queue_provider_test.dart test/providers/jam_exit_restore_test.dart test/providers/play_online_test.dart test/providers/play_online_jam_test.dart test/ui/queue_incoming_test.dart test/ui/queue_reorder_test.dart test/ui/jam_queue_sheet_test.dart test/goldens/player_golden_test.dart test/services/shuffle_plus test/providers/shuffle_plus_test.dart test/providers/shuffle_plus_config_test.dart test/providers/shuffle_plus_pending_provider_test.dart`

## Task

### 108.1 — Via «Riproduci dopo» (F-131, D-487; analisi «Arrivo» passo 1, Rete riga A)
- UI: `widgets/track_actions.dart:255-261,595-605`, `widgets/bulk_actions.dart:111-125`. Backend: `PlayerController.playNext`/`playOnlineNext` (`player_providers.dart:382-386,525-531`), `CodecoreAudioHandler.playNext` (`:1727-1733`), `PlayQueue.insertNext` (`play_queue.dart:313`). ARB: `playNext`, `playNextDone`, `playNextMany` in it, en, de, es, fr, pt (`lib/l10n/`; poi `flutter gen-l10n`).
- Test: togliere `play_queue_test.dart:115,122`; sostituire `insertNext`/`playNext` con `append`/`insertAt` in `play_queue_test.dart:160,199,292,319`, `gapless_handler_test.dart:75,144,154`, `play_online_test.dart:93-96,313,317`, `play_online_jam_test.dart:98,100,158`; fake di `online_song_row_test.dart:50`; menu in `track_actions_test.dart:253`, `menus_characterization_test.dart`, `all_tracks_screen_test.dart:89`, `selection_bar_test.dart:181`.
- Controllo: `grep -rniE "playNext|playOnlineNext|insertNext" lib test` = 0 righe. Android Auto, MPRIS, SMTC non lo espongono (verificato in analisi).
- Comando: `flutter test test/services/audio/play_queue_test.dart test/services/audio/gapless_handler_test.dart test/providers/play_online_test.dart test/providers/play_online_jam_test.dart test/ui/online_song_row_test.dart test/ui/track_actions_test.dart test/ui/menus_characterization_test.dart test/ui/all_tracks_screen_test.dart test/ui/selection_bar_test.dart`

### 108.2 — Blocco in `PlayQueue`, senza UI (F-129, F-132, D-487, D-492, D-493, D-494)
- `lib/services/audio/play_queue.dart`: `List<int> _user` (chiavi delle voci aggiunte dall'utente non ancora suonate, in ordine di arrivo) e `bool _currentFromUser`; getter `userAhead`, `currentFromUser`. **I1**: le chiavi di `_user` stanno esattamente in `_pos+1 .. _pos+userAhead`, nell'ordine di `_user`. **I2**: la voce corrente non è mai in `_user`. `_settle()` privato le ripristina alla fine di ogni operazione che sposta `_pos` o riordina.
- Regole (tabella «Arrivo»):
  - `append` → `enqueue(id)` (`:372`): inserisce a `_pos+1+userAhead`, aggiunge la chiave a `_user`; coda vuota = `setItems([id])`; più brani = un `enqueue` per brano in ordine (`bulk_actions.dart:129`, `album_detail_screen.dart:238`).
  - `next` (`:194`): la testa del blocco diventa corrente ed esce dal blocco; un brano del blocco suonato diventa normale e torna nei giri di «Ripeti tutto» (D-492).
  - `previous` (`:212`), `jumpTo` (`:228`): `_settle()`, il blocco resta subito dopo il nuovo corrente (D-493); saltare oltre il blocco: parte il brano toccato e il blocco lo segue (D-494); saltare dentro il blocco toglie quella voce dal blocco.
  - shuffle on/off (`:68`, `_shuffledFrom :84`, `_restoreNaturalOrder :93`): come oggi + `_settle()`, il blocco non si mescola.
  - `move` (`:257`): dentro `[_pos+1, _pos+1+n′]` entra nel blocco, fuori diventa normale (D-487).
  - `removeAt`/`removeId`/`removeTracks` (`:237`): toglie la chiave; `_settle()` se era il corrente.
  - `insertAt` (`:332`, Shuffle+ e simili): un indice dentro il blocco va subito dopo il blocco.
  - «Svuota» + Annulla (`rebuildUpcoming :272`, `QueueState :6`, `:292,:296`): «Svuota» azzera il blocco; `QueueState` copia `_user` e `_currentFromUser`, Annulla li rimette.
  - `setItems` (`:122`) con `keepUser: true` (D-488): il blocco torna subito dopo il nuovo corrente.
- Test in `play_queue_test.dart` (`append` → `enqueue`: «va in fondo» cambia): FIFO; più brani in fondo al blocco; shuffle on/off; `next`; `previous`; `jumpTo` oltre; `move` dentro/fuori; `removeAt`; `insertAt` dentro → dopo; Svuota + Annulla; Ripeti tutto; I1/I2 asserite a ogni passo del test a operazioni casuali (tutti i semi). `play_queue_characterization_test.dart` **senza modifiche**.
- Comando: `flutter test test/services/audio/play_queue_test.dart test/services/audio/play_queue_characterization_test.dart`

### 108.3 — Gestore, persistenza, radio, Jam (F-132, D-488, D-496)
- Handler (`codecore_audio_handler.dart`): `enqueue` al posto di `append` (`:1735`); getter `userAhead`; `playQueue` (`:365`, `:452`) usa `keepUser: true`; il giro della radio (`:1587`) e `playStations` (`:382`) svuotano il blocco (D-496); `restore` (`:460`) legge il blocco.
- Persistenza: chiave prefs nuova `lastQueueUser` (quante voci del blocco dopo il corrente ripristinato; assente = 0) in `playback_persistence.dart:11` e `settings_store.dart:306,728,749`. DB e formato del backup invariati (`backup_service.dart:56` copia già tutte le prefs).
- Jam: nessun cambio di codice (`player_providers.dart:383,389`, handler `:1818`, `jam_local_queue.dart:44,89`); un ospite che esce ritrova i brani del blocco nello stesso ordine come brani normali (D-496).
- Test: handler `keepUser` (D-488) e radio che svuota (D-496) in `codecore_audio_handler_test.dart`; `jam_exit_restore_test.dart`: ospite ritrova l'ordine; `playback_persistence_test.dart`: `lastQueueUser` salvato e ripristinato, e il vecchio salvataggio senza chiave resta come oggi (test di 107.2 verde senza modifiche).
- Comando: `flutter test test/services/audio/codecore_audio_handler_test.dart test/services/audio/playback_persistence_test.dart test/providers/queue_provider_test.dart test/providers/jam_exit_restore_test.dart test/providers/play_online_jam_test.dart`

### 108.4 — Intestazioni nel foglio della coda (D-495)
- `now_playing/queue_sheet.dart:55,183,238`: legge `handler.userAhead` accanto a `currentIndex`; con `n > 0` intestazione `queueUpNext` sopra il blocco e `queueThen` sopra la voce `n`; con `n = 0` resta `queueNext` («Prossimi») come oggi. Come nel mockup `coda.html`.
- ARB: chiavi nuove `queueUpNext` («Prossimi in coda») e `queueThen` («Poi») in **it, en, de, es, fr, pt** (le sei lingue presenti in `lib/l10n/`; `queueNext` resta invariata); `scripts/arb_add.py`, poi `flutter gen-l10n`. Nota: la regola di CLAUDE.md parla di it/en/de/es, ma nel repo ci sono anche fr e pt e le altre chiavi le hanno: si aggiungono tutte.
- Test: con blocco due intestazioni, senza blocco solo `queueNext` (`queue_incoming_test.dart`/`queue_reorder_test.dart`); `test/goldens/player_golden_test.dart` aggiornato se cambia il foglio.
- Etichette TalkBack: intestazioni come intestazioni semantiche (come le altre `SectionHeader`).
- Comando: `flutter test test/ui/queue_incoming_test.dart test/ui/queue_reorder_test.dart test/ui/jam_queue_sheet_test.dart test/goldens/player_golden_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

### 108.5 — Shuffle+ dopo il blocco e correzione dello skip (F-130, D-489, D-497)
- **Prima un test rosso** in `test/providers/shuffle_plus_test.dart`: skip di un brano della libreria prima degli ultimi 3 s non avvicina il suggerito; un brano del blocco non conta. Poi `plusPlan(skip: n)` in `insertion_plan_test.dart`.
- `insertion_plan.dart:11`: `plusPlan` riceve `skip = userAhead` e pianifica dopo il blocco; `shuffle_plus_controller.dart:291-303,396,415,464` e `shuffle_host.dart:42`: le voci del blocco non contano come ascolti; un brano della libreria saltato prima degli ultimi 3 s (regola «ascoltato» di `_followCurrent`, D-497) restituisce il suo conto (`_played - 1`); `_followCurrent` si ripete subito prima del piano (chiude la corsa con lo skip).
- Simili da Cerca (`similar_queue.dart:169`): nessun cambio (inseriscono già in fondo, dopo il blocco).
- `insertion_plan_test.dart:38` cambia nome («una lunga serie di brani ascoltati…»), asserzione uguale. Fake di `ShuffleHost` in `shuffle_plus_test.dart:63`, `shuffle_plus_source_change_test.dart:24`.
- Comando: `flutter test test/services/shuffle_plus test/providers/shuffle_plus_test.dart test/providers/shuffle_plus_config_test.dart test/providers/shuffle_plus_pending_provider_test.dart test/providers/queue_provider_test.dart`

### 108.6 — Controlli di fase
- `flutter analyze`; comando mirato; Jam invariata: `flutter test test/jam test/providers/jam_*_test.dart test/ui/jam_*_test.dart` verde senza modifiche ai test, `git diff --stat origin/master -- lib/services/jam lib/providers/jam*` vuoto.
- `/code-review high` su `codecore_audio_handler.dart` e `play_queue.dart` (area a rischio, D-491).
- Scheggia di passo (effort `high`: area a rischio) e di fase.
- Prova sul Mi A3 (`0d7ae9df206e`) via adb contro `coda.html`, con `~/Downloads/Liked_Songs.csv` importato come playlist (D-503): più «Aggiungi in coda» insieme a simili da Cerca e Shuffle+, skip di un suggerito, trascinamento dentro/fuori, Svuota + Annulla, riavvio dell'app. Ripulire il telefono, mai i file musicali.

**Fatto quando:** dopo lo skip di un suggerito arriva il brano messo in coda, «Riproduci dopo» non esiste più, l'impronta della caratterizzazione è identica, I1/I2 reggono su tutti i semi, i test sono verdi.

## Da decidere
(nessuno)
