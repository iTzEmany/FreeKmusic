# Fase 83 — Chiusura del refactor «ui-uso-quotidiano»

**Obiettivo:** confrontare le misure finali con quelle di partenza (fase 77.1) e chiudere i controlli trasversali.

**Prerequisiti:** fasi 77–82 chiuse. Metriche e soglie: `refactor/ui-uso-quotidiano/analisi.md` «Rete».

## Task

### 83.1 — Misure finali
- Cambio scheda Libreria: `python3 scripts/perf_device.py 0d7ae9df206e --label 83-finale` e `flutter test integration_test/perf_test.dart -d linux`; confronto con la 77.1 (soglia p90 build ≤ 16 ms sul telefono, −50 % su Linux) e con le soglie della fase 38 per gli altri scenari (nessun peggioramento).
- `grep -rn CircularProgressIndicator lib/ui`: restano solo equalizzatore, memoria, sorgenti playlist.
- `flutter test test/theme/contrast_test.dart test/ui/a11y_guidelines_test.dart test/goldens` verdi; overflow a 2,0× su tutte le schermate del perimetro.

### 83.2 — Prova a mano e chiusura
- Giro completo sul Mi A3 seguendo `refactor/ui-uso-quotidiano/mockup/indice.html` schermata per schermata; etichette di Home, Cerca e Registro controllate con `uiautomator dump` (D-381: niente prova a orecchio con TalkBack).
- Handoff aggiornato, `docs/refactor/ui-uso-quotidiano/analisi.md` con lo stato finale dei rilievi, pulizia del disco.

**Fatto quando:** misure scritte qui e dentro le soglie, prova a mano fatta.

## Dalla review della fase 77
- Campi di ricerca fatti a mano rimasti fuori dal perimetro (F-09 ne citava tre): `add_tracks_screen.dart:89`, `share/track_picker_screen.dart:66`, `import_manual_search_sheet.dart:101`, `playlist_source_sheet.dart:150`. Migrare a `CcSearchField` o dichiararli debito.

## Dalla review della fase 79
- Tutti i brani scrive `trackQueryProvider(false)` da `initState` e `dispose` (`all_tracks_screen.dart:142-172`): «Mostra tutti» della Home e «Tutti i brani» della Libreria vivono in due Navigator e possono essere aperte insieme, e una azzera o cancella il testo dell'altra. Il testo diventa stato locale e `tracksProvider` prende una `TrackQuery` (family autoDispose); l'ordinamento ricordato resta nel notifier. Stessa cosa per `favorites_screen.dart:123`. Oppure dichiararlo debito.

## Animazioni fedeli ai mockup (richiesta dell'utente, 2026-11-04)
- La lente della Libreria (79.2) oggi è una dissolvenza: va come nel mockup `libreria-ricerca.html` (lente che scivola a sinistra con `AnimatedAlign`, campo che si allarga attorno a lei, titolo e icone che escono con opacità e spostamento, contenuto sotto che sfuma come strato unico). Solo trasformazioni e opacità (niente `SizeTransition` su liste lunghe, `RepaintBoundary` sugli strati che sfumano), durate dai token, zero con riduci movimento.
- **Transizioni fra schermate** (D-382): ogni schermata nuova entra a schermo intero con una dissolvenza ease-in, niente slide da sinistra (oggi Impostazioni e sottoimpostazioni scattano a metà); i contenuti compaiono appena caricati; finché non ci sono, skeleton della loro forma ovunque (nessuno spinner fuori da equalizzatore, memoria, sorgenti playlist), mostrato solo se i dati non arrivano entro ~150 ms così le schermate veloci non lampeggiano. Un `PageTransitionsTheme` unico nel tema; il player tiene il suo slide dal basso.
- **Chiusura del player** (D-382): la copertina resta tonda per tutta l'animazione verso il mini player (oggi diventa quadrata a metà): `flightShuttleBuilder` dell'`Hero` con lo stesso ritaglio tondo, o raggio che interpola fra tondo e tondo.
- Giro sugli altri mockup del refactor: le animazioni semplificate rispetto alle note vanno allineate con le stesse regole. Misura dopo, nella 83.1.

## Dalla review della fase 80
- `CcSearchField`: `touch()` dentro `_changed` sempre (oggi solo con `onQuery`); Cerca (`search_screen.dart:60-80`, debounce suo) e Radio (`radio_screen.dart:141`) passano a `onQuery`, insieme ai 4 campi di D-378; `searchPrefillProvider` da `radio_providers.dart` a `ui_providers.dart`.
- Mix del genere: `interleave(tracks, GenreMixState)` funzione pura in `genre_mix.dart` (oggi `_mixRows` in `genre_screen.dart:33-80`), `_genreMix` da `shuffle_plus_providers.dart:318-343` a `services/shuffle_plus/`, predicato «già in libreria» e alimentatore dei semi comuni a Shuffle+ e mix, `libraryIndexProvider` con cache al posto del getter del controller e del `compute` per ogni genere (dopo il `RadioGate` della 81).

## Dalla review della fase 81
- **Prima di tutto (bug) — fatto (W1a):** `PlayerController._context` tolto; il contesto sta nell'handler (`playContext`, unica copia) e si salva con la coda in `PlaybackPersistence` (`lastContextKind`/`lastContextName`, assenti nei dati vecchi = nessun contesto) e torna con `restore()`. `main` lo rimette in `playContextProvider` dopo il ripristino. `playStations` lo imposta sull'handler; `playFromMediaId` (Android Auto) lo azzera. Test: riavvio simulato → `resumeLastQueue` conserva tipo e nome.
- Ciclo di import `player_providers.dart` ↔ `shuffle_plus_providers.dart`: `suggestionLogProvider` in un file foglia.
- Una sola scrittura nel registro dei suggeriti: `SuggestionLog.addSuggestion(r, seedTitle)` al posto di `logSuggestion` (`player_providers.dart:457`) e del `log.add` di `shuffle_plus_controller.dart:443-448`.
- `StreamCardsWait` (`now_playing_cards.dart:556-611`) legge `preparer.phases` e `indexKey`: un metodo/provider dell'handler (`shadowWaitOf(queueId)` → attesa / non disponibile, col tetto di 60 s) e il widget tiene solo il timer dei 20 s; `retryShadow` tramite `PlayerController`.
- `shufflePlusPendingProvider` filtra da sé Shuffle+ spento e Jam (oggi lo fa `queue_sheet.dart:179-184`, che importa il servizio).
- Player vuoto: `_EmptyInfo` di `desktop_player_bar.dart:83` riusa la scheda del mini player; un helper `emptyPlayerAction(l, last)` accanto a `emptyPlayerSubtitle` (tooltip ▶ copiato in `desktop_player_bar.dart:337` e `mini_player.dart:339`); `playWhenEmpty` in `TrackOps`.
- `GenreMixState`: lista di `(YtResult, seedTitle)` invece della mappa `seedTitles` parallela (col refactor di `interleave`); `shuffle_plus_controller.dart:571` usa `gate.nextAsk`.
- `Skeleton`: i parametri senza chiamanti (`margin`, `card(title:)`, `label` su card/gridCell/bars) si tolgono se la fase 82 non li usa.
- Registro su desktop: il dettaglio di un gruppo di download mostra tutti i brani del gruppo (oggi solo il primo).
- `docs/02-architettura.md:398`: tetto di 60 s, `lastQueueProvider`/`resumeLastQueue`/`playShufflePlus` (D-364), `playStations` fuori da `_start`.

## Dalla review della fase 82
- `apply` (accetta singola e correzioni automatiche, anche `onSure` in `online_providers.dart:235`) ignora l'esito del file: passi da `_writeFile(..., backup: byUser)` come «Accetta tutte» e `revert`, così un file non scritto lascia la riga «File non aggiornato». Decisione (autonomia, rumore): le correzioni AUTOMATICHE (`byUser: false`, `onSure`) non scrivono quella riga (una libreria grande con formati non scrivibili ne farebbe migliaia, resta il log); la scrivono solo le azioni dell'utente (Accetta, Accetta tutte, Ripristina, Annulla), e con la scrittura dei tag spenta nessuna.
- L'Annulla di «Accetta tutte» vive nella UI (`proposals_screen.dart:40-55`) con N transazioni: `TrackCorrections.revertAll(AcceptedAll)` in una transazione, file dopo.
- Il Registro si aggiorna solo con `reload()` a mano (`proposal_card.dart:143`, `_undo`): il notifier ascolta `tableUpdates` di `activity_log` e i `reload()` si tolgono; `loadMore` non pagina per offset (salta righe inserite nel frattempo). `ActionButton` va in `lib/ui/widgets/` senza ricaricare il Registro.
- Selezione desktop del Registro per `at` in ms (`activity_log_screen.dart:62`): le N righe di «Accetta tutte» possono avere lo stesso ms → per `LogEntry.id`.
- Regola «Errori» scritta in SQL e in Dart (`LogEntry.failed`, `_counts`, `LIKE '%"noAnswer":true%'` legato al formato di `jsonEncode`): un solo helper; getter tipizzati su `LogEntry` per `file`, `noAnswer`, `old`/`new` (oggi letti crudi in `activity_log_entry.dart`).
- `recogSourcesLine` (`activity_log_screen.dart:28-41`) riusa `recogSourceLabel`; la regola «artista vuoto = resta quello di prima» in un posto solo (`proposals_screen.dart:198` e `_applyDb`).
- Un solo orologio: il `now` di `TrackCorrections` e gli `at: DateTime.now()` del notifier passano a `nowMs`.
- Repository: `TrackRepository.setUserEdited` (oggi `revert` scrive `tracks.userEdited` diretto) e `ActivityLogRepository.byIds` coi blocchi dentro.
- Filtro con conteggio 0: niente lettura di tutte le pagine (`activity_log_screen.dart:121`).
- Documenti: `02-architettura.md` (:190 «in memoria, ultimi 500»; :360 revert e `revertible`; `acceptAll` in una transazione, `reopen` D-372, righe `correction` fallite senza old/new; :371 filtri e `countsByKind`; :377 Annulla/`undismiss`; :59 percorsi), `03-modello-dati.md:206` (`detail` per tipo di riga), `nowMsOverride`.

## Esiti

### 83.1 — Misure finali (2026-11-05, HEAD 9918946e + correzioni di questa task)
**Linux A/B** (`integration_test/perf_test.dart`, xvfb 1280x800, debug, 3000 brani, rendering software). A = commit 16b34d4 (prima del refactor) in un worktree temporaneo, con il solo `perf_test.dart` preso da face036e (ha lo scenario Libreria); B = HEAD. 5 corse alternate A,B,A,B… per lato. Celle: mediana delle 5 corse di build p50 / p90 / max (ms); fra parentesi l'intervallo del p90.

| Scenario | A (prima) | B (HEAD) |
|---|---|---|
| Tutti i brani | 0,53 / 3,2 / 4,8 (3,1-3,3) | 0,52 / 3,2 / 5,1 (3,1-3,4) |
| Album | 2,25 / 7,3 / 15,7 (6,7-8,4) | 3,76 / 8,2 / 16,4 (6,8-8,3) |
| **Libreria Tutto→Playlist→Album→Artisti** | 1,04 / 3,0 / 54,2 (2,5-5,5) | 1,03 / 2,7 / 54,4 (2,5-6,8) |
| Ricerca | 0,48 / 3,0 / 18,4 (2,8-3,2) | 0,60 / 1,0 / 21,5 (0,9-1,1) |

- Il raster p90 è 2,0-2,7 ms su entrambi i lati. Questa macchina oggi misura molto più stabile della 77.1 (p90 della Libreria 2,5-3,2 ms contro i 10-24 di allora): i numeri della 77.1/79.1 non sono confrontabili in assoluto, solo A/B nella stessa sessione.
- **Cambio scheda Libreria: nessun peggioramento (p90 3,0 → 2,7 ms, mediane; −10 %), ma il −50 % non è raggiunto.** Il costo è il picco di ~54 ms alla prima visita di ogni scheda, identico prima e dopo (54,2 contro 54,4): il refactor non l'ha toccato. Il p90 era già basso in A, quindi non c'è margine di −50 %.
- Album: p50 più alto in B (3,76 contro 2,25) e p90 +12 % ma gli intervalli delle 5 corse si sovrappongono (6,7-8,4 contro 6,8-8,3); picco uguale. Ricerca migliora (p90 3,0 → 1,0). Tutti i brani uguale.

**Mi A3** (`perf_device.py 0d7ae9df206e --label 83-finale --no-build --no-push`, profile, 3000 brani; avvio a freddo mediana 2760 ms, PSS 202 MB). p50/p90/p99 ms:

| Scenario | Frame | build | raster | > 16,7 ms |
|---|---|---|---|---|
| Pallino schede | 1704 | 2,4 / 3,9 / 7,2 | 5,2 / 5,9 / 11,1 | 0,3 % |
| Tutti i brani | 513 | 1,8 / 4,8 / 9,3 | 6,0 / 8,7 / 14,7 | 0,4 % |
| Album | 1189 | 3,1 / 7,1 / 10,9 | 5,7 / 7,9 / 16,6 | 0,9 % |
| **Libreria Tutto→Playlist→Album→Artisti** | 4188 | 3,2 / 8,2 / 12,4 | 5,7 / 7,9 / 18,7 | 2,8 % |
| Ricerca «notte» | 1032 | 1,7 / 6,0 / 8,1 | 3,9 / 7,8 / 20,0 | 3,7 % |
| Apri album | 397 | 2,8 / 8,3 / 32,8 | 6,0 / 10,1 / 13,9 | 2,3 % |

- **p90 build della Libreria 8,2 ms, sotto la soglia di 16 ms** (77.1: 6,6; 79.1: 6,8): +1,4 ms contro la 79.1, dentro la soglia ma non un miglioramento. Gli altri scenari: Tutti i brani 4,8 (79: 5,4), Album 7,1 (79: 5,6, ancora ben sotto 16).
- Confronto indicativo: stesso telefono ma sessione diversa. `perf_device.py` è stato corretto per il layout nuovo (il BACK da «Tutti i brani» non basta, i fling partivano al 75 % dell'altezza, cioè sul mini player, e aprivano il player): ora partono al 70 %, quindi i fling di questa corsa non sono identici a quelli della 79.

**CircularProgressIndicator in `lib/ui`** (27 occorrenze): equalizzatore e memoria (`memory_screen`, `memory_app_data`) come previsto; più avanzamenti/pulsanti occupati/attese con testo (mini player, now_playing_controls/screen/cards, credits_card, activity_button, yt_dlp_update_button, update_tiles, backup_section, import_*, jam_remote_*, devices_sheet, send_tab, podcast_*, new_releases, theme_background_editor, preview_cover, online_song_row). Sorgenti playlist non compare nell'elenco: non ha spinner.

**Overflow a 2,0×**: Home, genere, Registro, Da confermare, Da revisionare avevano già un test a 2,0×. Aggiunto `test/ui/text_scale_2x_test.dart` (Libreria, Tutti i brani, Cerca, coda, player vuoto): ha trovato due overflow veri (18 px) nelle righe a altezza fissa 64 della Libreria (`library_screen.dart`) e della coda (`queue_sheet.dart`); ora usano `trackRowExtentOf` come le altre liste. Rigenerati 6 golden a 150 % (library e queue_incoming, phone/desktop/light). Verdi: contrast, a11y_guidelines, goldens, i test a scala grande e i test toccati (249 test).
