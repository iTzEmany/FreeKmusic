# Fase 69b — Un solo motore di arricchimento (refactor «arricchimento-unico», parte 2)

**Obiettivo:** un solo modo di arricchire i brani. Il lavoro manuale («Arricchisci» della libreria e dell'album, «Riprova») e il completamento in background passano entrambi sullo stesso motore a parti (gather/commit) e scrivono gli stessi segni «cercato, niente» (D-103). La regola «parte dovuta» e lo stato `enrich_status` si scrivono in un punto solo. Il vecchio motore `enrichMany` sparisce. `EnrichmentService` si divide per responsabilità. Rilievi: F-06…F-13, F-20, F-21.

**Prerequisiti:**
- Fase 69a chiusa.
- Da leggere: `docs/refactor/arricchimento-unico/analisi.md`, sezioni «Scelte», «Arrivo» (architettura e tabella prima → dopo) e «Rete».
- Decisioni: D-102, D-103, D-104, D-275, D-277…D-290.

**Intoccabili (D-280):**
- D-102, D-103 e D-104;
- lo schema DB v15: nessuna migrazione, nessuna colonna;
- il formato di backup e condivisione.

**Si può cambiare:** anteprima, stream e seconda opinione possono usare il motore unico dove ha senso, ma tengono `propose`/`apply`.

**Comportamento:** cambia solo nei punti scelti dall'utente (D-277/D-284, D-278, D-279/D-285, D-286, D-288). Ogni cambio ha il suo test, elencato in «Rete».

**Ordine:** regola e stato si unificano **prima** di togliere il vecchio motore. Altrimenti «Da revisionare» cambia senza volerlo. Ogni task lascia il codice funzionante: la strada nuova nasce accanto alla vecchia, i chiamanti passano uno per uno, poi si toglie il vecchio.

**Comando mirato:**
- task 69b.1: `flutter test test/services/online/enrich_status_characterization_test.dart test/services/online/enrich_parts_test.dart test/services/online/enrich_guards_test.dart test/services/online/enrichment_needs_test.dart test/services/online/second_opinion_test.dart test/services/online/enrich_completer_test.dart test/data/review_queries_test.dart`;
- dal task 69b.2: gli stessi, più `enrichment_credits_test`, `enrichment_service_test`, `enrichment_deezer_test`, `quiet_enricher_test`, `test/providers/download_enrich_test.dart`, `review_actions_test`, `enrich_job_test` ed `enrich_completer_providers_test`.

## Task

Al massimo 4 task per fase (profilo di `/obiettivo`), un commit per task. Ogni task ha i suoi passi, da fare nell'ordine scritto: ogni passo ha il suo «Fatto quando» e lascia il codice funzionante.

### 69b.1 — Rete, regola unica e stato (F-11, F-12, F-13)

#### Passo: Test di caratterizzazione
Si scrive solo codice di test. Nuovo file `test/services/online/enrich_status_characterization_test.dart` con `EnrichRig` (`test/support/enrich_fakes.dart`). Fissa il comportamento di **oggi**, difetti compresi. I casi sono nella tabella «Test di caratterizzazione» di `analisi.md` «Rete»:
- `enrich_status` dopo `enrichMany` e dopo `commit`;
- la seconda opinione che non scrive niente;
- i conteggi del job su 3 brani.

Il caso «brano a 1, poi niente» si legge dal codice vero mentre si scrive il test.

In `test/data/review_queries_test.dart` va un test «lista fissa», con queste righe:
- stato 0;
- stato 1 senza copertina;
- stato 2;
- riga stream;
- `lyricsByUser` senza testo;
- senza numero di traccia;
- `userEdited` senza album.

Il test asserisce gli id per ogni `ReviewReason`.

L'accordo `dueTrackIds`/`enrichCounts` con `isDue` (`enrich_completer_test.dart` vicino a :544 e :586) si estende a `lyricsByUser` e a `userEdited` senza album. Ogni asserzione destinata a cambiare porta nel nome il rilievo e il task, per esempio `(DEFECT F-12, flips with statusAfter)` o `(DEFECT F-08, flips with the runner)`. Si annota in un commento il numero di letture per brano di oggi nel commit, contato con un `QueryInterceptor` di drift.

**Fatto quando:** i test nuovi sono verdi sul codice di oggi senza toccare `lib/`.

#### Passo: Una regola per parte, in Dart e in SQL (F-11a, F-13)
In `enrich_parts.dart` arrivano:
- `AskMode {due, retryNone, force}`, al posto di `gather(force, ignoreMarks)` e di `EnrichCompleter.run(now)`. `force` resta solo per «Aggiorna» della scheda crediti (`credits_card.dart:35`);
- `dueSql(parts, mode)` ed `eligibleSql`, spostate da `credits_repository.dart:73-109`, accanto a `isDue`;
- `fillableFields(t)`, che prende il posto di `_fillable` (`enrichment_service.dart:700-706`) e tiene conto di `userEdited` sia in Dart sia in SQL.

`credits_repository.dart` usa `dueSql`.

**Fatto quando:**
- il test di accordo copre ogni modo × `userEdited`;
- i test di caratterizzazione restano verdi, tranne `userEdited` senza album, che non è più dovuto (F-11a, voluto).

#### Passo: «Da revisionare» sulle stesse regole (F-11 b/c/d, D-286)
`review_queries.dart` guarda `lyricsByUser`: un testo scritto a mano non è «senza testo». Le righe stream e il numero di traccia restano fuori dalla revisione. In un commento di una riga si scrive perché (D-286).

**Fatto quando:** nella «lista fissa» del primo passo cambia solo la riga `lyricsByUser`.

#### Passo: Lo stato lo scrive una funzione sola (F-12, D-279, D-285)
In `enrich_parts.dart` si aggiungono:
- l'enum `EnrichStatus {untried, found, nothing}`, che corrisponde ai codici 0/1/2 del DB;
- la funzione pura `statusAfter(prima, esiti) → EnrichStatus?`.

`statusAfter` decide così:
- `found` se c'è almeno un esito `found`;
- `nothing` solo se lo stato di prima è `untried` e **tutte** le parti chieste sono `none`;
- null, cioè stato invariato, se c'è un esito `failed`/`limited` o se lo stato di prima era `found`.

I crediti non contano.

`enrich_writer.dart` (nuovo) ha `writeStatus`: è l'unico punto che scrive `tracks.enrich_status`. Spariscono le scritture di `enrichment_service.dart` 646, 663, 809 e 943. `apply`, e quindi la seconda opinione, scrive `found` solo se ha scritto almeno un campo. Finché esiste, `enrichMany` passa da `statusAfter` con gli esiti che riesce a vedere.

**Fatto quando:**
- il test a tabella di `statusAfter` in `enrich_parts_test.dart` è verde;
- le asserzioni marcate «flips with statusAfter» sono cambiate come previsto;
- `enrich_guards_test.dart:243` è aggiornato;
- un test in `second_opinion_test` verifica che una seconda opinione che non scrive niente lasci lo stato invariato;
- `grep -rn 'enrichStatus: Value' lib --include=*.dart | grep -v '\.g\.dart'` trova solo `enrich_writer.dart`.

### 69b.2 — Motore unico: resolver, copertine, engine, runner, commit per parte (F-10, F-20, F-21)

#### Passo: Metadati e copertine fuori dal servizio (F-20, parte 1)
È un puro spostamento.

`metadata_resolver.dart` contiene `MetadataResolver`:
- la cascata Deezer/iTunes;
- `_deezerLookup` e `_deezerHit`;
- la cache `_albums`.

`cover_fetcher.dart` contiene `CoverFetcher`:
- `fetch` e `apply`;
- `coverForAlbum`, che serve ai CSV.

`EnrichmentService`, `CreditsEnricher` e `import_providers.dart:71` li usano tramite i loro provider.

**Fatto quando:** i test Deezer, crediti e servizio restano verdi senza modifiche, a parte gli import.

#### Passo: `EnrichEngine` e brani in volo (F-10)
`gather`, `commit` e `completeOne` passano in `enrich_engine.dart`, con `enrichEngineProvider`. L'engine non chiama mai `EnrichmentService`. Usano l'engine:
- `EnrichCompleter`;
- `QuietEnricher` (`online_providers.dart:237`);
- la scheda crediti.

L'insieme `inFlight` contiene gli id raccolti e non ancora scritti:
- `gather` su un id in volo dà `skipped`;
- `completeOne` aspetta il commit di quell'id;
- `commit` toglie l'id nel `finally`.

Si corregge il commento di `quiet_enricher.dart:7-8`.

**Fatto quando:** un test fa partire download e background sullo stesso id e verifica che le fonti siano chieste una volta sola.

#### Passo: `EnrichRunner`
`enrich_runner.dart` è l'`EnrichCompleter` di oggi generalizzato. Lavora a blocchi di 10 sopra l'engine e ha due sorgenti di id:
- una **lista fissa**, per il manuale;
- un **cursore** dal segnalibro, per il background (69a.1).

Riceve `mode` e `parts`, e la pausa per inattività (D-104) vale solo con `AskMode.due`. Gestisce `stuck`, `refused` e i conteggi aggiornati / non trovati. Il completer gli delega il lavoro.

**Fatto quando:**
- un test con una lista di 3 brani verifica il progresso «N di M» e i conteggi;
- tutti i test del completer restano verdi.

#### Passo: Commit per parte e meno letture (F-20, F-21)
`_commitOne` si spezza in `_commitMeta`, `_commitLyrics`, `_commitCredits`, `_commitCurio` e `_writeMarks`. Riga, `track_enrich` e crediti si leggono una volta sola per brano.

**Fatto quando:** un test con `QueryInterceptor` conta ≤ 3 letture per brano nel commit, e i test dei blocchi restano verdi.

### 69b.3 — Il manuale sul motore unico e via il vecchio (F-06, F-07, F-08, F-09)

#### Passo: Il lavoro manuale passa al runner (F-06, F-08, D-278)
`EnrichJobNotifier.start(ids)` usa `EnrichRunner(lista, AskMode.retryNone, manualParts(settings))`. `manualParts` comprende:
- metadati;
- testi e sincronizzati;
- curiosità;
- i crediti, solo con «Crediti e dettagli» acceso.

Passano al runner anche:
- «Arricchisci album» (`album_detail_screen.dart:250`);
- «Riprova» (`review_providers.dart:56`). Non rimette lo stato a 0 (non lo faceva nemmeno prima): avvia `start(ids)` in `retryNone`, poi la seconda opinione, che si salta se il lavoro è fallito.

`BatchProgress` diventa `EnrichJobResult` (aggiornati, non trovati, totale, errore). Si aggiornano `enrich_result_listener.dart` e `activity_log_providers.dart:200`. La barra resta «Arricchimento: N di M» (D-282). `ActivityKind.enrich` resta, anche per le righe vecchie del Registro.

**Fatto quando:**
- le asserzioni «flips with the runner» sono cambiate: offline lo stato resta invariato e il manuale chiede le curiosità;
- i test di `enrichment_needs_test`, `enrichment_service_test:111` e `review_actions_test:79` girano sul runner;
- un test sul runner in `retryNone` + `manualParts` verifica che le curiosità vengano chieste e che i crediti dipendano dall'interruttore.

#### Passo: Un solo comando in Impostazioni (D-277, D-284)
«Arricchisci tutta la libreria» (`settings_pages.dart:506`) avvia il lavoro manuale sui brani con una parte dovuta in `retryNone`. Mostra un sottotitolo «N brani da completare, circa M minuti», calcolato in stream da `enrichCounts(manualParts, retryNone)`. La stima di oggi è `ids×3/60` e tiene conto solo del limitatore, quindi va scritta «circa» e rimisurata in 69b.4. Durante il lavoro il comando mostra «Interrompi».

Si tolgono:
- `EnrichCompleteTile` («Completa l'arricchimento»);
- `runNow`/`manual` del completer;
- le loro stringhe ARB.

Le stringhe nuove vanno in it, en, de ed es.

**Fatto quando:**
- un test in `enrich_job_test.dart` verifica che il comando avvii il runner sui brani dovuti, riprovando anche i «niente»;
- un test di unità verifica il conteggio del sottotitolo;
- i test di «Completa» sono tolti: `enrich_completer_test:336`, `enrich_completer_providers_test:249` e `:316`.

#### Passo: Fine scansione e brani ricevuti (F-09, D-288)
Si toglie `_autoEnrich` (`library_providers.dart:130, 137-150`): a fine scansione parte solo il completer. `afterReceive` (`online_providers.dart:302`) usa `autoParts(settings).isNotEmpty`, come i download.

**Fatto quando:**
- un test in `download_enrich_test.dart` verifica `afterReceive` con `autoParts`;
- `grep -rn '_autoEnrich' lib` non trova niente.

#### Passo: «Completamento: in attesa» (F-07)
`EnrichCompleterState.waiting` si accende mentre il runner aspetta l'inattività o un'altra attività. `enrichBackgroundOf` e `activityTitle` (`activity_providers.dart`) mostrano «Completamento: in attesa» al posto di una barra ferma. Stringhe ARB in it, en, de ed es.

**Fatto quando:** un test sull'elemento dell'attività verifica il titolo «in attesa» mentre si aspetta e «X di Y» mentre si lavora.

#### Passo: Via il vecchio batch (F-06)
Si tolgono `enrichMany`, `BatchProgress`, `needsEnrichment` e `CreditsEnricher.isDue`, che `propose` sostituisce con `isDue`. Insieme a loro si tolgono `enrichment_needs_test.dart` ed `enrichment_credits_test:422`; i test di `CreditsEnricher.isDue` passano su `isDue`. Dei 7 bool di `propose` restano solo quelli che anteprima, stream e seconda opinione usano davvero.

**Fatto quando:** `grep -rnE 'enrichMany|BatchProgress|needsEnrichment|_autoEnrich|EnrichCompleteTile|runNow|ignoreMarks' lib test` non trova niente e `flutter analyze` è pulito.

### 69b.4 — Controlli di fase
1. Comando mirato verde e `flutter analyze` pulito; la suite completa la esegue la CI.
2. **Metriche** di `analisi.md` «Rete» (D-290), con comandi ed esiti scritti qui sotto:
   - `enrichment_service.dart` ≤ 450 righe, ogni file nuovo ≤ 400;
   - una sola scrittura di `enrich_status`;
   - zero catch muti nel perimetro (`grep -nE 'on Object|catch \('`, ogni riga controllata);
   - zero riferimenti ai simboli tolti;
   - ≤ 3 letture per brano.
3. **Review di architettura con Opus** sul diff della fase (stato, coda, concorrenza di `inFlight`), più `/code-review high`.
4. **Misura sul Motorola (D-289)**, come in 69a.4:
   - prima si chiede se il telefono è libero; poi `install -r`, 15 minuti di background, DB e log in sola lettura;
   - si confronta con tutte le «Misure di partenza»: brani dovuti, «Da revisionare», giri con lavoro;
   - si prova una volta «Arricchisci tutta la libreria»: una sola barra «Arricchimento: N di M», messaggio finale, riga nel Registro, e il background che dice «in attesa»;
   - si rimisura la stima in minuti;
   - le copie si cancellano con `pulizia.sh`.
5. **Documenti:**
   - `docs/02-architettura.md` §«Arricchimento», righe circa 335–342: `EnrichEngine`, `EnrichRunner`, regola unica, «Riprova» sul runner;
   - `docs/feature-arricchimento.md`, dove descrive i due comandi o `_autoEnrich`;
   - le guide in `docs/guida` che citano «Completa l'arricchimento», controllate con `scripts/check_docs_links.py`.

## Esiti di 69b.4 (2026-10-31)

- **Metriche** (D-290):
  - `wc -l lib/services/online/enrich*.dart …`: `enrichment_service.dart` 163 righe; il file nuovo più lungo è `enrich_runner.dart` con 388. ✔
  - `grep enrichStatus: Value lib`: una sola scrittura di `enrich_status`, `enrich_writer.dart:21`. ✔
  - `grep -nE 'on Object|catch \('` nel perimetro: 18 righe controllate una per una. Ognuna logga (`Error` in `AppLog.e`, il resto in `AppLog.w`) o rilancia; `enrich_engine.dart:120` libera la prenotazione e rilancia. ✔
  - `grep -rnw enrichMany|enrichConfirm…|widen|clearAlbums lib test`: nessun riferimento. I `promote` rimasti sono quelli dello stream, che non c'entra. ✔
  - ≤ 3 letture per brano: il test in `enrich_status_characterization_test.dart:157`. ✔
- **Review:** di architettura con Opus e `/code-review high` sul diff della fase, poi la scheggia; i rilievi sono corretti in 9ef5db0.
- **Motorola** (D-289; musica in pausa, D-296). APK con 69b.1–69b.4 installato con `install -r` alle 16:57; copia di prima in `.backup-motorola/codecore-2026-10-31-1656/`.
  - Brani con una parte dovuta: 1328 prima, 1324 dopo 15 minuti di background, **1317** dopo la prova manuale; solo musica 1242 → 1231. «Da revisionare» (stato 2) fermo a 68. Segnalibro 1182 → 1206.
  - Background: i blocchi di 10 brani si salvano interi (commit alle 17:06:41 e alle 17:16:45). Nel log nessun `[E]`; gli avvisi sono 2 «LRCLIB answered 503» e 3 crediti MusicBrainz falliti, e il giro va avanti.
  - **Ritmo:** circa 1 brano al minuto. Non è il motore: le curiosità usano diverse richieste Wikimedia a brano, e da anonima (`kApiContact` vuoto) l'app ne ha 8 al minuto (`request_budget.dart:17`). In 69a meno brani chiedevano le curiosità.
  - **«Arricchisci tutta la libreria»** (17:19–17:25): mentre lavora il comando dice «Interrompi». Nel pannello c'è una sola barra, «Arricchimento: 10 di 1871», e il background dice «Completamento: in attesa». Fermato da «Annulla», il Registro scrive «Arricchimento: 10 di 1871 · Fermata». ✔
  - **Stima:** il comando prometteva «1871 brani, circa 94 minuti» (3 s a brano). Il ritmo misurato è di 10 brani in 6,5 minuti, circa 40 s a brano, quindi la stima era sbagliata di 13 volte. Ora `enrichMinutes` conta 40 s a brano da anonima e 3 s da identificata (non misurato).

## Rimandati dalla 69b
- Ritmo: con un contatto in `kApiContact` Wikimedia concede 150 richieste al minuto invece di 8. **Fatto il 31/10 (D-298)**, con l'indirizzo del repo; il ritmo nuovo è da misurare.
- `test/jam/jam_gate_test.dart` «concurrent writes» fallisce su Windows anche su master: confronta percorsi interi con nomi di file. Il check non è obbligatorio.
- `propose` chiede ancora testi, Wikipedia e crediti fuori dal motore, con la regola «crediti dovuti» duplicata: va costruito su una lettura del motore che non prenota.
- Un lavoro manuale salta in silenzio un brano che il background tiene in lavorazione (finestra di un solo brano): contarlo a parte o riprovarlo alla fine.
- Il provider del completer tiene in cache il motore (`_built`) e non segue un rebuild di `enrichEngineProvider` (cambio o ripristino del DB).
- `gather`/`commit` sono pubblici ed `EnrichGather` è mutabile, quindi un gather senza commit lascia la prenotazione: `completeOne(bool force)` dovrebbe prendere un `AskMode`.
- `allRefused` è vero anche se l'utente spegne le parti dopo un rifiuto.
- Il conteggio di «Arricchisci tutta la libreria» in `retryNone` arriva di rado a «Libreria completa»: scelta di prodotto, la decide l'utente.
- Fondere `EnrichCompleter` nel suo provider.
