# Fase 98 — Rete di sicurezza, formattazione e script delle misure (refactor «ascolto-quotidiano»)

**Obiettivo:** prima di toccare la logica, formattare i 4 file storti, sistemare `scripts/perf_device.py` e fissare con test di caratterizzazione il comportamento che le fasi 99–104 spostano. **Nessun cambio di comportamento in `lib/`** (salvo la sola formattazione).

**Prerequisiti:** fase 97 chiusa. Analisi: `refactor/ascolto-quotidiano/analisi.md` (F-116..F-122, sezione «Rete»). Decisioni D-434, D-442, D-454. Mockup: nessuno. Aree a rischio: nessuna.

**Comando mirato:** `flutter test test/providers/artist_merge_providers_test.dart test/ui/artist_picker_sheet_test.dart test/services/online/artist_key_test.dart test/ui/artist_page_test.dart test/data/watch_with_countries_test.dart test/data/filter_counts_test.dart test/services/shuffle_plus/genre_mix_test.dart test/services/shuffle_plus/suggestion_log_test.dart test/services/backup/backup_service_test.dart`

## Task

### 98.1 — Formattazione di 4 file (F-122, D-434)
- `dart format lib/ui/shell/app_shell.dart lib/ui/screens/library/library_island.dart lib/ui/screens/library/library_toolbar.dart lib/ui/screens/smart/smart_playlist_editor.dart`, **commit a parte** che contiene solo questo (`style(98): dart format di 4 file`). Nessun altro file formattato: gli altri 495 restano come sono.
- Verifica: `dart format --set-exit-if-changed` sui 4 file → 0; `flutter analyze` pulito.

### 98.2 — Script delle misure (F-120, F-121)
- «Album» e «Libreria Tutto→Playlist…» non dipendono più dallo scenario precedente: preparazione con `to_library_top` (Libreria → «Tutto» → in cima), poi `^Album$`; via il BACK iniziale di `open_album_tab` (`perf_device.py:322-335`).
- Gli scenari misurati con `scenario()` e `dev.tap` dentro la misura (Tutti i brani, Libreria Tutto→…, Ricerca, Anello e gli altri elencati in analisi F-121) passano a `gestures()`: posizioni trovate nella preparazione (schema `find`/`pos[]`), dentro la misura solo `input tap` sulle coordinate salvate; niente `time.sleep` fissi dentro la finestra misurata. «Anello» misura un gesto vero o si toglie, con il motivo in Esiti.
- Verifica sul Mi A3 (`0d7ae9df206e`, build profile): `python3 scripts/perf_device.py 0d7ae9df206e --only "Album"` gira da solo; un giro completo senza errori. Numeri in Esiti (non sono una nuova base: servono a vedere che lo script funziona). Dopo: ripulire il telefono.

### 98.3 — Caratterizzazione del debito (F-116..F-119)
- `test/providers/artist_merge_providers_test.dart`: 429 → `null` e pausa attiva; pausa attiva → nessuna chiamata, `null`.
- `test/ui/artist_picker_sheet_test.dart`: 429 in `mergeArtistWith` → eccezione mostrata dal foglio.
- `test/services/online/artist_key_test.dart`: tabella su `matchKey(extractPrimaryArtist(x))` («feat.», «&», maiuscole, accenti, null, vuoto). Nella 99 lo stesso test passa a `artistKey` senza cambiare i valori attesi.
- Test di `groupShelvesProvider` («raggruppa come oggi») accanto a quelli di `mergeArtistShelves` in `test/ui/artist_page_test.dart`.
- `test/data/watch_with_countries_test.dart` (`fakeAsync`): una raffica di scritture su `tracks` dà l'ultimo valore corretto; un artista nuovo in `tracks` compare nei conteggi per paese.

### 98.4 — Caratterizzazione di backup
- In `test/services/backup/backup_service_test.dart`: un backup con campi sconosciuti si ripristina ignorandoli; un backup del formato di oggi si ripristina intatto (base per `DislikeStore` e `unsyncedLyrics`, D-442).

### 98.5 — Controlli di fase
`flutter analyze`; comando mirato verde **senza modificare `lib/`** (salvo 98.1); review del diff (Sonnet); scheggia in modalità passo sui test nuovi (devono fallire se si cambia il comportamento che fissano).

**Fatto quando:** 98.1 in un commit a sé, lo script gira con `--only "Album"`, i test di caratterizzazione sono verdi su `master`.

## Esiti

- **98.2** (script, Mi A3 `0d7ae9df206e`, build profile; non è una nuova base, serve solo a vedere che lo script gira): `scripts/perf_device.py` non ha più `scenario()`, tutti gli scenari sono `gestures()` con posizioni trovate nella preparazione e solo `input tap`/`swipe` sulle coordinate salvate dentro la misura. «Album» e «Libreria Tutto→…» partono da `to_library_top` (via il BACK di `open_album_tab`); «Ricerca» usa la scheda Cerca del dock (la lente della Libreria si teneva la query e rompeva «Scroll Libreria»). `--only "Album"` da solo: 578 frame, build p50/p90/p99 3,2/5,6/10,8 ms, raster 6,5/9,6/22,7 ms, 1,7 % oltre 16,7 ms. Giro completo (`--playback`, 15 scenari) senza errori: da Pallino schede 2,3 % a Apertura player 4,0 % oltre 16,7 ms (Album 595 frame, 1,3 %; Ricerca 0,4 %; Cambio scheda 3,8 %; Fogli 3,8 %); avvio a freddo mediana 2804 ms, PSS 270 MB.
- **Anello** tolto: era solo `mini` + `sleep(6)` (il player aperto fermo), nessun gesto da misurare; le animazioni dell'anello sono già dentro «Apertura player», «Lettore dal dock» e «Fogli». Tolto anche dall'elenco `SCENARIOS`.
