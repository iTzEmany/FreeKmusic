# Fase 53 — Completamento e Registro

**Obiettivo:** la libreria esistente si completa da sola. `EnrichCompleter` gira in background ad app aperta, un brano
alla volta, solo sulle parti accese e dovute, in pausa mentre l'utente scorre, cerca o scarica; il comando «Completa
l'arricchimento» fa tutto subito. Il centro Attività mostra l'avanzamento con Pausa e Riprendi. Il Registro si salva
nel database per 30 giorni e ci finisce ogni processo in background, con una riga per giro di arricchimento che si
apre sull'elenco dei brani. La pagina Memoria mostra quanto pesa l'arricchimento.

**Prerequisiti:** fasi 50–52 chiuse (`completeOne` con tutte le parti e `isDue`, tabella `activity_log`). Fase 38/44
(`scripts/perf_device.py`, misure «Finale»), centro Attività e Registro di oggi (`activity_providers.dart`,
`activity_log_providers.dart`).

**Riferimenti:** `docs/feature-arricchimento.md` (R-51…R-53, R-58…R-62; RNF-04, RNF-05, RNF-06; componenti
«`EnrichCompleter`», «`UserActivity`», «Registro», «Memoria»; flusso (b); invarianti 3, 4, 8; rischi K-AR-04,
K-AR-07, K-AR-09); decisioni D-102, D-103, D-104, D-112, D-113, D-120, D-125, D-126.

**Intoccabili:** la fluidità (misure «Finale» di `docs/refactor/ui-fluida/misure.md`, tolleranza un frame, D-85);
«Arricchisci» e `_autoEnrich` dopo la scansione come oggi; le voci del centro Attività e del Registro di oggi con lo
stesso testo. Il completamento gira solo ad app aperta (D-102). **Nessun pacchetto nuovo.** **Schema invariato (v15).**

## Task

### 53.1 — Registro nel database (30 giorni)
**File:** `lib/data/repositories/activity_log_repository.dart` (nuovo), `lib/providers/activity_log_providers.dart`
(`ActivityLogNotifier` scrive e legge la tabella invece della lista da 500), `lib/ui/screens/activity/activity_log_screen.dart`,
`test/data/activity_log_repository_test.dart` (nuovo), `test/providers/activity_log_test.dart`
1. Ogni `LogEntry` diventa una riga di `activity_log` (`detail` JSON facoltativo); scrittura fuori dal thread UI.
2. All'avvio si cancellano le righe con `at` di oltre 30 giorni; «Svuota» = `DELETE FROM activity_log`.
3. Lo schermo del Registro legge la tabella in ordine di `at` decrescente, a pagine.

R-59.
**Fatto quando:** `flutter test test/data/activity_log_repository_test.dart test/providers/activity_log_test.dart test/ui/activity_test.dart`
verde: riga di 31 giorni fa sparita all'avvio, una di 29 resta; dopo il «riavvio» (nuovo `ProviderContainer` sullo
stesso DB) le righe ci sono; «Svuota» → tabella vuota; i test di oggi del Registro verdi. `flutter analyze` pulito.

### 53.2 — Ogni attività finisce nel Registro
> Dalla fase 50 (D-127): la pausa di 24 h dei crediti Deezer (`DeezerGwClient.onPaused`) scrive una riga nel Registro; mentre gw è in pausa la parte crediti non è dovuta per i brani che solo Deezer può dare. `completeOne` restituisce già l'esito per parte (`PartOutcome`).
**File:** `lib/providers/activity_providers.dart` (`ActivityKind` + `podcastRefresh`, `radio`, `enrichBackground`;
regola «c'era, non c'è più → riga»), `lib/providers/podcast_ops.dart`, `lib/providers/radio_ops.dart`,
`lib/ui/screens/activity/activity_sheet.dart`, ARB con `scripts/arb_add.py`, `test/providers/activity_test.dart`
1. Un ascoltatore confronta `running` prima e dopo: una voce che sparisce senza riga propria nel Registro (scan,
   enrich, cleanup, releases, podcastRefresh, radio) lascia una riga con nome, conteggi ed esito (finito, fermato, in
   pausa). Download, episodi, trasferimenti, import e secondo parere restano come oggi (nessuna riga doppia).
2. L'aggiornamento dei podcast e il controllo della radio compaiono in `running` mentre girano.

R-60.
**Fatto quando:** `flutter test test/providers/activity_test.dart test/providers/activity_log_test.dart` verde: per ogni
valore di `ActivityKind` una voce che parte e finisce produce **una** riga del Registro; un download finito non ne
produce due. `flutter analyze` pulito.

### 53.3 — `UserActivity`
**File:** `lib/providers/user_activity_provider.dart` (nuovo: `lastActivityAt`, `isBusy`), `lib/ui/shell/app_shell.dart`
(`NotificationListener<ScrollNotification>` alla radice), `lib/ui/screens/search/search_screen.dart` (testo della ricerca
locale e online), `test/providers/user_activity_test.dart` (nuovo), `test/ui/app_shell_test.dart`
1. Scorrimento, testo cercato e voci di `activityProvider.running` di tipo download, import, trasferimento aggiornano
   `lastActivityAt` (nessuna ricostruzione dei widget: un valore letto dal completer, non uno stato osservato dalla UI).
2. `idleFor(5 s)` = nessuna di queste da 5 s e niente in corso (D-120).

Parte di R-52.
**Fatto quando:** `flutter test test/providers/user_activity_test.dart test/ui/app_shell_test.dart` verde con orologio
finto: scroll in una lista della shell → occupato, libero dopo 5 s; download in corso → occupato finché finisce + 5 s;
testo nella ricerca → occupato. `flutter analyze` pulito.

### 53.4 — `EnrichCompleter` in modalità *piano*
> Dalla fase 52: le curiosità (CuriosityFinder) e i crediti si identificano ancora ognuno per conto suo su MusicBrainz (K-AR-07 non rispettato del tutto): il finder vuole l'`artistId`, non solo l'MBID dei crediti. Prima del completamento di massa, far riusare a `_identify` l'MBID salvato in `track_enrich.mbid`, così un giro non raddoppia le chiamate.
> Dalla review di architettura della fase 52, prima di 53.4: (a) dividere `completeOne` in `gather` (letture e rete, nessuna scrittura) e `commit(List)` (una transazione per blocco di 10, RNF/collaudo 53.9), con `CuriosityService` diviso in `find` e `save`: oggi curiosità e copertina scrivono `tracks` fuori dalla transazione del brano; (b) un brano `failed` non ha marca e torna dovuto subito: il completer tiene in memoria i brani già provati nel giro (`dueTrackIds(exclude:)`); (c) `fills` ripete le condizioni di `_writeFields`: farle restituire a `_writeFields` ciò che ha scritto; (d) estrarre il resolver Deezer/iTunes (con la cache `_albums`) da `enrichment_service.dart` (~800 righe), oggi passato a `CreditsEnricher` con callback.
**File:** `lib/services/online/enrich_completer.dart` (nuovo), `lib/providers/enrich_completer_providers.dart` (nuovo),
`lib/data/repositories/credits_repository.dart` (`dueTrackIds(parts, now, limit: 20)`: `tracks` `kind IN (0,2)` LEFT
JOIN `track_enrich`, solo colonne leggere), `lib/providers/startup_providers.dart` (avvio dopo la scansione e a ogni cambio
degli interruttori), `test/services/online/enrich_completer_test.dart` (nuovo)
1. Blocchi di 20 id dalla query (nessun cursore salvato: lo stato nel DB basta per ripartire); un brano alla volta;
   prima di ogni brano attende `UserActivity.idleFor(5 s)`; `completeOne`; scritture raccolte e messe in una
   transazione ogni **10** brani (invariante 4, K-AR-04).
2. Un 429 o un errore di una fonte = quella fonte salta il brano (cooldown di oggi), le altre vanno avanti; nessun
   «niente» per errore (invariante 3). Nessuna parte accesa o nessun brano dovuto → nessuna richiesta.
3. Tutto async fuori dal thread UI (RNF-05).

R-51, R-52.
**Fatto quando:** `flutter test test/services/online/enrich_completer_test.dart` verde con client finti e orologio finto:
3 brani incompleti, completer «riavviato» dopo il primo → riprende dal secondo; tutti completi → zero richieste; download in
corso → nessun brano lavorato finché finisce + 5 s; 25 brani → 3 transazioni di scrittura, non 25; 429 da Deezer → testo
e curiosità del brano salvati lo stesso. `flutter analyze` pulito.

### 53.5 — «Completa l'arricchimento» (modalità *subito*)
**File:** `lib/ui/screens/settings/enrich_complete_tile.dart` (nuovo, nelle impostazioni dell'arricchimento in
`settings_pages.dart`), `lib/services/online/enrich_completer.dart` (`runNow`, `cancel`), ARB,
`test/services/online/enrich_completer_test.dart`, `test/ui/enrich_complete_tile_test.dart` (nuovo)
1. Senza le pause di `UserActivity` e con `force` sulle attese di 30 giorni; salta i brani completi; entro i limiti
   delle fonti (RNF-06). Si interrompe dalla tile o dal centro Attività.

R-53.
**Fatto quando:** `flutter test test/services/online/enrich_completer_test.dart test/ui/enrich_complete_tile_test.dart`
verde: 5 brani, 2 completi e 1 «niente» di ieri → 3 lavorati; scroll in corso non lo ferma; «Interrompi» → nessun brano
dopo quello in corso. `flutter analyze` pulito.

### 53.6 — Voce nel centro Attività con Pausa e Riprendi
**File:** `lib/providers/activity_providers.dart` (voce `enrichBackground` da `enrichCompleterProvider`),
`lib/ui/screens/activity/activity_sheet.dart`, `test/ui/activity_test.dart`
1. Mentre il completer gira: «Arricchimento» con «completi / totale» aggiornato a ogni blocco di 10 (non a ogni brano),
   pulsanti Pausa e Riprendi. La pausa a mano vale fino a Riprendi o al riavvio dell'app.

R-62.
**Fatto quando:** `flutter test test/ui/activity_test.dart` verde: voce con «1530 / 2196» e Pausa; tocco su Pausa → il
completer non lavora e compare Riprendi; Riprendi → riparte. `flutter analyze` pulito.

### 53.7 — Riga per giro nel Registro con l'elenco dei brani
**File:** `lib/services/online/enrich_completer.dart` (conteggi per parte del giro), `lib/providers/activity_log_providers.dart`,
`lib/ui/screens/activity/enrich_round_screen.dart` (nuovo), `lib/ui/screens/activity/activity_log_screen.dart`, ARB,
`test/ui/enrich_round_screen_test.dart` (nuovo)
1. A ogni pausa o fine: una riga «Arricchimento: 120 brani completati, 8 senza testo»; `detail` = id dei brani
   aggiornati e senza risultato, per parte.
2. Tocco sulla riga → elenco in due gruppi (aggiornati / senza risultato, con la parte), brani toccabili; un brano
   cancellato nel frattempo non compare.

R-61.
**Fatto quando:** `flutter test test/ui/enrich_round_screen_test.dart test/services/online/enrich_completer_test.dart`
verde: giro di 3 brani (2 aggiornati, 1 senza testo) → una riga con quei numeri; tap → elenco con i due gruppi.
`flutter analyze` pulito.

### 53.8 — Riga «Arricchimento» nella pagina Memoria
**File:** `lib/data/repositories/memory_queries.dart` (`enrichmentBytes()`: `SUM(length(...))` di testi, curiosità,
`artist_infos.body`, `track_credits`, `track_enrich.details`), `lib/ui/screens/memory/memory_screen.dart`,
`lib/providers/memory_providers.dart`, ARB, `test/data/memory_queries_test.dart`, `test/ui/memory_screen_test.dart`
1. Riga «Arricchimento: N MB» con il dettaglio testi, curiosità, crediti; nessun pulsante per cancellare (D-113).
2. Query fuori dal thread UI, solo all'apertura della pagina.

R-58.
**Fatto quando:** `flutter test test/data/memory_queries_test.dart test/ui/memory_screen_test.dart test/ui/memory_layout_test.dart`
verde: DB con dati noti → byte attesi per parte e totale; la riga c'è senza pulsanti; i test di oggi verdi. `flutter analyze` pulito.

### 53.9 — Controlli di fase (K-AR-01, K-AR-02, K-AR-03, K-AR-04, RNF-05)
1. K-AR-01: `flutter test test/services/online/enrichment_service_test.dart test/services/online/enrichment_needs_test.dart
   test/services/online/enrichment_deezer_test.dart test/services/online/cover_for_album_test.dart
   test/services/online/quiet_enricher_test.dart test/providers/enrich_job_test.dart` verde.
2. Download: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
3. K-AR-02/03: `flutter test test/services/backup/ test/data/backup_merge_test.dart test/services/share/ test/jam/` verde.
4. K-AR-04: `flutter test test/data/stream_rows_hidden_test.dart test/data/performance_lists_test.dart
   test/data/playlist_repository_test.dart` verde.
5. RNF-05 (D-19, build profile, solo app perf), con il completamento attivo su una libreria incompleta:
   `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 40m <scratchpad>/perf53.log -- env JAVA_HOME=$HOME/.jdks/jbr-17.0.14 PATH=$HOME/.jdks/jbr-17.0.14/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label arricchimento-53 --playback`.
   Tabella «Dopo la fase 53» in `docs/refactor/ui-fluida/misure.md` accanto a «Finale», stesse righe; tolleranza **un
   frame per scenario** (D-85); uno scenario oltre → fermarsi e riportare (regole §1.6).
6. Invariante 4: nel test di 53.4 nessuna scrittura su `tracks` più spesso di una ogni 10 brani.
7. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–7 sono verdi; `build/perf/arricchimento-53.md` esiste e la tabella in
`misure.md` copre ogni riga di «Finale».

### 53.10 — Prove a mano (utente)
Materiale per l'utente (D-125, D-126). Su **Linux e Mi A3** (`0d7ae9df206e`; `-k` ammesso, mai cancellare i file musicali):
- Interruttori accesi: il completamento parte da solo; mentre si scorre o si scarica si ferma, riparte 5 s dopo;
  nel centro Attività «completi / totale» con Pausa/Riprendi (R-51, R-52, R-62).
- App chiusa e riaperta a metà: riprende senza rifare i brani già completi (R-51).
- «Completa l'arricchimento»: lavora subito anche scorrendo; «Interrompi» lo ferma (R-53).
- Registro: righe di scansione, pulizia, podcast, radio, giro di arricchimento; tocco sulla riga del giro → elenco;
  dopo il riavvio il Registro c'è ancora; «Svuota» lo vuota (R-59…R-61).
- Memoria: riga «Arricchimento» con il dettaglio (R-58).
Sul **Motorola edge 40** (`ZY22HKD85K`, libreria vera, D-125, D-126):
- Prima di installare: chiedere all'utente un backup completo dall'app e annotare dove sta. `adb -s ZY22HKD85K install -r <apk>`;
  firma diversa → fermarsi, l'utente conferma il backup, `adb uninstall -k`, installare e ripristinare. Mai cancellare file musicali.
- «Crediti e dettagli» e «Curiosità automatiche» accesi, «Completa l'arricchimento» sull'intera libreria (2196 brani)
  fino alla fine: solo parti vuote, brani modificati a mano invariati; nessun 429/503 a raffica nel log (K-AR-07).
- Peso reale: la riga «Arricchimento» della pagina Memoria a fine giro, confrontata con la stima (≈ 20–25 MB,
  massimo 30 MB, RNF-04, K-AR-09); il valore misurato, con data e numero di brani completi, va in
  `docs/feature-arricchimento.md` §Stima del peso. Oltre 30 MB → fermarsi e riportare.
- Telefono non caldo durante la riproduzione con il completamento attivo (K-AR-09).

**Fatto quando:** l'utente conferma le prove su Linux, Mi A3 e Motorola e il peso reale è in §Stima (casella `[ ]` → `[x]` in PROGRESS).
