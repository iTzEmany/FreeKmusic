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
