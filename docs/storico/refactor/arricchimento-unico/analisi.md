# Refactor «arricchimento-unico» — analisi

**Tipo:** struttura (più un ritocco al centro attività) · **Fasi:** 69a e 69b, prima della 70 · **Data:** 2026-10-30

## Perimetro
Il sottosistema che completa i brani con dati online (metadati, copertina, testi, curiosità, crediti):
- `lib/services/online/`: `enrichment_service.dart` (983 righe), `enrich_completer.dart` (191), `enrich_parts.dart` (56), `credits_enricher.dart` (255), `lyrics_chain.dart` (141), `curiosity_service.dart` (142), `quiet_enricher.dart` (64), `second_opinion.dart` (237);
- `lib/providers/`: `online_providers.dart` (310), `enrich_completer_providers.dart` (277), `startup_providers.dart` (42), `review_providers.dart` (84), `library_providers.dart` (357, solo `_autoEnrich`), `activity_providers.dart` (295), `user_activity_provider.dart` (58);
- `lib/data/repositories/`: `credits_repository.dart` (353, `dueTrackIds`/`enrichCounts`), `review_queries.dart` (56);
- UI che avvia o mostra l'arricchimento: `settings_pages.dart:506` «Arricchisci tutta la libreria», `album_detail_screen.dart:250` «Arricchisci album», `review_screen.dart` «Riprova», `enrich_preview_dialog.dart`, `credits_card.dart:35` «Aggiorna», `enrich_complete_tile.dart` «Completa l'arricchimento», `activity_sheet.dart`.

In totale sono 3901 righe. Fuori dal perimetro restano i client delle fonti (Deezer, iTunes, LRCLIB, NetEase, lyrics.ovh, Wikipedia, MusicBrainz), salvo i punti segnati nei rilievi.

## Come funziona oggi (sintesi)
Oggi convivono **due motori** dentro `EnrichmentService`:
- **A — propose/apply/`enrichMany`.** Lo usano il job manuale `enrichJobProvider` («Arricchisci» della libreria e dell'album, «Riprova» della revisione, `_autoEnrich` a fine scansione) e, brano per brano, anteprima, stream e seconda opinione. Scrive `tracks.enrich_status` 1/2. Non scrive i segni `track_enrich.*_none_at`, tranne quello dei crediti.
- **B — gather/commit/`completeOne`.** Lo usano il completamento in background `EnrichCompleter` (D-102), i brani scaricati e ricevuti (`QuietEnricher`) e la scheda crediti. Lavora per parti, con gli esiti `found/none/failed/limited/skipped` e i segni «cercato, niente» validi 30 giorni (D-103).

Il background gira **solo ad app aperta**, come deciso in D-102. Con la musica accesa il processo resta vivo grazie al servizio di `audio_service`. Ad app chiusa non fa niente, perché non c'è un WorkManager.

## Misure di partenza
Raccolte il 2026-10-30 dal Motorola edge 40 (DB e `codecore.log` in sola lettura, fatto nella chat di questo refactor). In questa fase **non si rimisurano dal telefono**: un'altra chat lo sta usando per i test.

| Misura | Valore |
|---|---|
| Interruttori | tutti accesi (Arricchisci, Testi, Metadati da Deezer, Crediti e dettagli, Curiosità) |
| Brani musica | 2302 (`enrich_status` 1 = 2261, 2 = 41) |
| Brani con almeno una parte dovuta | **1812** (meta 800, testi 294, curiosità 1713) |
| «Da revisionare» | **1016** (741 senza copertina, 324 senza testo, 169 senza genere, 57 senza anno, 41 «niente trovato») |
| Giri del background nel Registro | quasi tutti `failed=1`; l'ultimo con lavoro il 29/10 (1 brano) |
| Log a ogni avvio | `LRCLIB answered 503: resting 10 min` → dopo 12–15 s `completion: 5 tracks in a row got no answer, round stopped` (16 volte fra il 26 e il 30/10) |
| Primi brani dovuti (ordine per id) | 445, 451, 464, 465, 474: a tutti manca **solo il testo** (in gran parte strumentali) |
| Altro | 26/10 due volte `completion failed \| CircularDependencyError` |

## Rilievi (per priorità)
Formato: `F-NN · area · titolo · dove · prova · danno · impatto · rischio · costo · proposta`.

### Il background non avanza (bug, causa del sintomo)
- **F-01** · coda · Testa della coda sempre uguale · `credits_repository.dart:43` (`ORDER BY t.id`), `enrich_completer.dart:98` (`tried` vive un solo giro) · al giro dopo ripartono gli stessi primi id · un brano irrisolvibile in testa (testo strumentale, copertina morta) blocca ogni giro: 1812 brani in attesa · A · M · S · ordinare chi è stato provato da poco in fondo (data dell'ultimo tentativo per brano) e poi per id.
- **F-02** · errori · LRCLIB a riposo vale `failed`, non `limited` · `lyrics_chain.dart:76-77`, `enrichment_service.dart:459-462` · `if (resting) failed = true` → `_lost(false)` = `failed` · per 10 minuti ogni testo «non risponde» e non entra in `refused` (D-134): il giro muore in 15 s · A · M · S · `LyricsChainResult.limited` quando LRCLIB è a riposo → `PartOutcome.limited`, così testi e sincronizzati escono dal giro e il resto va avanti.
- **F-03** · errori · Il contatore «5 di fila senza risposta» si legge prima del commit · `enrich_completer.dart:126-129` contro `enrichment_service.dart:449` (la meta si decide in `_commitOne`) · un brano per cui Deezer/iTunes hanno risposto conta come muto · basta un brano con meta più testi in errore per alimentare lo stop · A · B · S · flag `answered` in `EnrichGather` (meta chiesta e non `failed` = risposta).
- **F-04** · errori · Timeout di 25 s su tutta la catena dei testi · `enrichment_service.dart:435-443`, `:718` · LRCLIB, NetEase e ovh fanno fino a 7 richieste in fila, ognuna con 8 s di connessione e 15 s di ricezione (`http_client.dart:49-50`) · una catena lenta ma viva diventa `failed` · M · B · S · `timeout: false` per i testi, come già per crediti e curiosità.
- **F-05** · errori · Una copertina che non si scarica lascia la meta `failed` per sempre · `enrichment_service.dart:658-660`, `http_client.dart:121-133` · `getBytes` dà null sia per 404 o file troppo grande sia per un errore di rete · il brano torna in testa a ogni giro (vedi F-01) · M · M · S · `getBytes` distingue rete (lancia) da «non c'è» (null → `none` con segno).

### Due motori per lo stesso lavoro
- **F-06** · struttura · Due motori, solo uno scrive i segni · `enrichment_service.dart:215-260, 750-763, 892-971` contro `:377-549, 575-697` · `enrichMany` non scrive `*_none_at` · dopo «Arricchisci tutta la libreria» il background richiede gli stessi brani alle stesse fonti; la cascata Deezer/iTunes e le regole di riempimento sono scritte due volte · A · M · L · «Arricchisci» (libreria e album), «Riprova» e la fine scansione passano a gather/commit; si tolgono `enrichMany`, `BatchProgress`, `EnrichJobNotifier`/`enrichJobProvider`, `needsEnrichment`, `_autoEnrich`, `ActivityKind.enrich`, `CreditsEnricher.isDue`. `propose`/`apply` restano per anteprima, stream e seconda opinione.
- **F-07** · UI · Due barre nel centro attività, una ferma · `activity_providers.dart:141-153` (job) e `:97` (completer); `user_activity_provider.dart:45` · il completer è «in corso» (`visible`) anche mentre aspetta, e il job manuale è fra i `_busyKinds` · l'utente vede una barra immobile accanto a quella che lavora · M · B · S · una sola barra (va da sé con F-06); mentre aspetta l'utente o un'altra attività, la barra lo dice («in attesa») invece di sembrare bloccata.
- **F-08** · errori · Il manuale scrive «niente trovato» su timeout o fonte rotta · `enrichment_service.dart:225-231` (`guarded` → null), `:235` (`.then((r) => r.lyrics)` butta `failed`), `:941-944` · «Arricchisci» offline o con LRCLIB a 503 mette stato 2 a tutta la selezione; `needsEnrichment` poi la salta senza `force` e la lista di revisione la mostra come «niente trovato» · A · M · S · sparisce con F-06.
- **F-09** · struttura · A fine scansione partono due arricchimenti, con regole diverse · `library_providers.dart:130,137-150` (`_autoEnrich`: solo se Arricchisci o Testi, `enrich_status == 0`, carica tutta la libreria in Dart) e `startup_providers.dart:31` (completer) · `afterReceive` usa una terza regola (`online_providers.dart:302`) · doppio lavoro, e gli interruttori valgono in modo diverso secondo chi parte · M · B · S · solo `autoParts` e solo il completer (con F-06).
- **F-10** · concorrenza · Nessuna esclusione per brano fra download e background · `online_providers.dart:230-240`, `enrich_completer.dart:107`; il commento di `quiet_enricher.dart:7-8` è obsoleto · un brano appena scaricato può essere chiesto due volte alle fonti · M · B · S · insieme `inFlight` nel servizio, che `dueTrackIds`/`gather` saltano.

### Stato e regole duplicate
- **F-11** · regole · «Parte vuota o dovuta» scritta 6 volte, non allineate · `enrich_parts.dart:21-56` (`isDue`), `credits_repository.dart:81-109` (`_dueWhere`, SQL), `enrichment_service.dart:97-114` (`needsEnrichment`), `:931-939` (campi di `enrichMany`), `:700-706` (`_fillable`), `review_queries.dart:11-17, 26-37` · (a) `userEdited` conta solo in `_fillable`: la meta risulta dovuta ma l'album non si può riempire; (b) `lyricsByUser` non lo guardano `needsEnrichment` e la revisione; (c) la revisione ignora il numero di traccia; (d) la revisione esclude le righe stream, `_eligible` le include · le liste non coincidono con il lavoro vero · A · M · M · una regola per parte, in un solo file, con la SQL accanto e un test che verifica che le due dicano lo stesso.
- **F-12** · stato · `enrich_status` scritto in 5 punti con regole diverse, valori magici 0/1/2 · `enrichment_service.dart:646, 663, 809, 943`; `second_opinion.dart:211-225` passa sempre una meta non nulla → stato 1 anche se non ha scritto niente; `_commitOne` scrive 2 guardando solo la meta (testi falliti o curiosità trovata non contano) · «Da revisionare» si appoggia a questo stato, il background ai segni · A · M · M · stato scritto da una sola funzione derivata dagli esiti delle parti (o lista di revisione derivata dai segni), enum al posto di 0/1/2.
- **F-13** · tipi · Gli stessi concetti con nomi diversi e bool a grappolo · `propose` 7 bool (`:215-222`), `gather(force, ignoreMarks)`, `EnrichCompleter.run(now)` · `force` in `isDue` ignora il segno, per le curiosità anche il «già pieno»; `ignoreMarks` e `now` sono la stessa cosa · è facile chiamare la variante sbagliata · M · M · S · enum `AskMode { due, retryNone, force }`.

### Errori nascosti
- **F-14** · errori · `EnrichJobNotifier._run` ha un `on Object` muto · `online_providers.dart:203-207` · nessun `AppLog`, conteggi azzerati, `onFinished` parte lo stesso · un errore di DB interrompe il lotto senza traccia; viola la regola «nessun catch muto» · A · B · S · sparisce con F-06 (fino ad allora: log + flag di errore).
- **F-15** · errori · Giro fallito senza lavoro: nessuna riga nel Registro; commit fallito non segna il giro · `enrich_completer_providers.dart:151-155` (`_log` solo se `worked > 0`), `enrich_completer.dart:182-184` · la barra sparisce senza spiegazione · M · B · S · riga nel Registro anche per un giro fallito a vuoto («fermato: nessuna fonte risponde»); commit fallito → `round.failed`.
- **F-16** · errori · Un 429 di NetEase o lyrics.ovh butta il testo già trovato da LRCLIB · `lyrics_chain.dart:65-66, 103-111` · `fallback` rilancia `RateLimitedException` · testo perso e testi fuori dal giro · M · B · S · dopo LRCLIB il 429 dei ripieghi diventa un flag `limited` e il testo trovato si tiene.
- **F-17** · errori · Errori Deezer diversi da 4 e 800 valgono «non trovato» · `deezer_client.dart:129-130` · `return null` → meta `none` (segno 30 giorni) e `creditsNoneAt` · con Deezer occupato si scrivono segni falsi · M · B · S · codici diversi da 800 → `DeezerNetworkException`.
- **F-18** · errori · Curiosità: artista rifiutato ma testo del brano trovato → `limited` · `enrichment_service.dart:513-516` · il testo viene salvato ma l'esito dice «rifiutato» e la parte esce dal giro · B · B · S · testo del brano presente → `found`, prima di guardare `limited`.
- **F-19** · errori · `CircularDependencyError` in un giro del 26/10 · log, `enrich_completer_providers.dart:154` · la causa non risulta leggendo il codice (nessun ciclo statico attorno a `enrichmentServiceProvider`) · un giro può morire per un errore di programmazione registrato come avviso · M · M · S · test che fa partire un giro dal provider vero con Registro e attività collegati; `on Error` registrato come errore.

### Forma del codice
- **F-20** · struttura · `EnrichmentService` è una classe dio · `enrichment_service.dart:146-972` · fusione Deezer/iTunes, anteprima, scrittura dei campi, copertine, `coverForAlbum` per i CSV, gather/commit e batch nello stesso file; `gather` ~170 righe, `_commitOne` ~120 · ogni modifica a una parte tocca tutte le altre · M · B · M · dopo F-06: estrarre la risoluzione dei metadati e le copertine, e spezzare `_commitOne` in una funzione per parte.
- **F-21** · prestazioni · Le stesse righe lette più volte per brano · `enrichment_service.dart:388, 392, 422, 578, 588, 669` · `getById` 2 volte, `track_enrich` 2, `creditsOf` 2 · 6 o più query per brano nel giro di fondo · B · B · S · `commit` rilegge solo ciò che può essere cambiato nel frattempo.

### Non è un rilievo
- Il lavoro ad app chiusa manca per scelta (D-102). Servirebbe WorkManager, un pacchetto non ammesso.
- Le curiosità salvate da `propose` (`wikipedia.find`) e da `gather` (`CuriosityService`) hanno lo stesso formato `testo\nfonte`. Cambia la ricerca, non il dato.

## Sintesi per area
- **Coda del background:** il sintomo («non lavora mai») nasce da F-01, F-02 e F-03 insieme. Bastano tre correzioni piccole, indipendenti dall'unificazione.
- **Motori:** il motore B è più corretto (esiti, segni, transazioni a blocchi). Il motore A va tolto dai lavori di massa e resta solo dove l'utente sceglie i campi, cioè anteprima, stream e seconda opinione.
- **Stato:** il rischio più grosso è lo stato a due teste (`enrich_status` per la revisione, segni per il background) con le regole copiate in sei punti. Va unificato prima di togliere il motore A, altrimenti la revisione cambia senza volerlo.

## Scelte
Prese con l'utente il 2026-10-30 (giro 2). Decisioni da D-275 a D-283.

**Rilievi.** Si affrontano tutti, da F-01 a F-21 (D-275). Nessuno è rimandato o scartato.

**Soluzioni scelte dove ce n'era più d'una:**
- **F-01.** Un segnalibro in `shared_preferences` tiene l'ultimo id provato. Il giro dopo riparte da lì e, a fine coda, ricomincia dall'inizio (D-276). Non serve nessuna colonna nuova.
- **F-06, F-07 e F-09.** In Impostazioni resta un solo comando, «Arricchisci tutta la libreria». Sotto mostra quanto manca, cioè i brani da completare e la stima in minuti. Il comando avvia subito il completamento e riprova anche le parti segnate «cercato, niente», come vuole D-103 per il comando manuale. La voce «Completa l'arricchimento» confluisce in questo comando (D-277, **cambio di comportamento**).
- **Parti di un lavoro manuale.** Vale per «Arricchisci» della libreria e dell'album e per «Riprova». Si chiede tutto ciò che è permesso: metadati, testi (anche sincronizzati) e curiosità sempre, i crediti solo se «Crediti e dettagli» è acceso. Gli interruttori automatici valgono solo per il background (D-278, **cambio di comportamento**: le curiosità entrano nel manuale).
- **F-12.** `enrich_status` resta 0/1/2 nel DB e lo scrive una sola funzione, partendo dagli esiti delle parti:
  - 1 se qualcosa è stato trovato;
  - 2 solo se tutte le fonti chieste hanno risposto «niente»;
  - invariato se una fonte non ha risposto.

  In Dart diventa un enum (D-279).
- **Riscontro all'utente, come oggi** (D-282):
  - il lavoro manuale mostra la barra «Arricchimento: N di M» sui brani scelti, poi il messaggio finale (aggiornati / non trovati) e una riga nel Registro;
  - il background mostra «Completamento: X di Y», oppure «in attesa» quando aspetta.

**Intoccabili** (D-280):
- D-102: si lavora solo ad app aperta;
- D-103: segno «cercato, niente» valido 30 giorni, riprova subito dal comando manuale;
- D-104: ritmo piano, in pausa mentre l'utente scorre, cerca o scarica;
- lo **schema DB v15**: nessuna migrazione, nessuna colonna nuova;
- il **formato di backup e condivisione**.

Anteprima, stream e seconda opinione non sono intoccabili. Possono passare al motore unico dove ha senso.

**Quanto osare.** Si ristruttura per parti: si sostituisce un pezzo alla volta e il codice resta funzionante dopo ogni passo. Il modulo non si riscrive da capo (D-281).

**Rilascio.** Due fasi, entrambe prima della 70 (D-283):
- **69a**: coda ed errori, cioè F-01…F-05 e F-14…F-19. Corregge il sintomo senza toccare la struttura.
- **69b**: regola unica, stato, motore unico e divisione del servizio, cioè F-06…F-13, F-20 e F-21.

I nomi 69a e 69b servono a non confondere le fasi con i task 69.5 e 69.6 della fase 69.

**Vincoli:**
- nessun pacchetto nuovo;
- nessuna prova sui telefoni durante la pianificazione, perché un'altra chat li sta usando; le misure di confronto si rifanno a fine 69b.

## Arrivo
Disegnata nel giro 3 leggendo il codice. Punti aperti decisi in D-284…D-287: il bottone avvia un lavoro manuale; lo stato diventa 2 solo da 0; la revisione si allinea solo su `lyricsByUser`; il segnalibro avanza su ogni brano provato.

### Architettura dopo la fase 69b
Tutto resta in `lib/services/online/`, senza Riverpod nei servizi.

| File | Responsabilità |
|---|---|
| `enrich_parts.dart` | **Unica fonte delle regole.** Contiene `EnrichPart`, `PartOutcome`, `AskMode {due, retryNone, force}` ed `EnrichStatus {untried, found, nothing}` (codici DB 0/1/2). Ha la regola in Dart `isDue(part, t, enrich, now, mode)` e, accanto, la sua SQL `dueSql`/`eligibleSql`, spostata da `credits_repository.dart:73-109`. Ha anche `fillableFields(t)`, che tiene conto di `userEdited` in Dart e in SQL, e la funzione pura `statusAfter(esiti) → EnrichStatus?`. |
| `enrich_writer.dart` | `writeFields` e `writeStatus`. È l'**unico** punto che scrive `tracks.enrich_status`. |
| `metadata_resolver.dart` | `MetadataResolver`: cascata Deezer/iTunes, `_deezerHit` e cache degli album. Lo usano l'engine, `propose` e `CreditsEnricher`. |
| `cover_fetcher.dart` | `CoverFetcher`: `fetch`, `apply`, `coverForAlbum`. |
| `enrich_engine.dart` | `EnrichEngine`: `gather(id, parts, mode)`, `commit` con una funzione per parte, e `completeOne`. Tiene l'insieme `inFlight`: un id in volo dà `skipped` a `gather`, mentre `completeOne` aspetta il commit di quell'id. |
| `enrich_runner.dart` | `EnrichRunner`: l'attuale `EnrichCompleter` generalizzato. Lavora a blocchi di 10 sopra gather/commit, su una **lista fissa** (lavoro manuale) o su un **cursore** che parte dal segnalibro (background). Gestisce `stuck`, `refused`, la pausa per inattività (solo in `due`) e i conteggi aggiornati / non trovati. |
| `enrichment_service.dart` | Resta solo `propose`/`apply`, per anteprima, stream e seconda opinione: lì l'utente sceglie i campi e si possono riscrivere titolo e artista. Lo stato lo scrive passando da `writeStatus(statusAfter(...))`. |

**Dipendenze ammesse:**
- la UI chiama solo i provider;
- `EnrichJobNotifier` (manuale) ed `EnrichCompleterNotifier` (background) chiamano `EnrichRunner`;
- `EnrichRunner` chiama `EnrichEngine`;
- `EnrichEngine` chiama resolver, copertine, `LyricsChain`, `CreditsEnricher`, `CuriosityService` ed `EnrichWriter`;
- `EnrichmentService` chiama resolver, copertine e writer;
- i repository usano la SQL di `enrich_parts.dart`;
- l'engine non chiama mai `EnrichmentService`.

**Si tolgono:**
- dal servizio: `enrichMany`, `BatchProgress`, `needsEnrichment`;
- fuori dal servizio: `_autoEnrich`, `CreditsEnricher.isDue`, `EnrichCompleteTile`;
- dal completer: `runNow`/`manual`;
- i bool `force`, `ignoreMarks` e `now`.

**Restano:** `ActivityKind.enrich` ed `EnrichJobNotifier`, che passa al runner. Servono per la barra «Arricchimento: N di M» (D-282) e per le righe vecchie del Registro.

### Prima → dopo
| Concetto | Prima | Dopo |
|---|---|---|
| Motore | A `propose/apply/enrichMany` + B `gather/commit` | `EnrichEngine` (B); A solo per anteprima, stream e seconda opinione |
| Job manuale | `EnrichJobNotifier` → `enrichMany` | stesso notifier → `EnrichRunner(lista, retryNone, manualParts)` |
| Background | `ORDER BY t.id`, `tried` per un solo giro | `EnrichRunner(cursore + segnalibro, due, autoParts)` |
| Scrittura dello stato | 5 punti | `statusAfter` + `writeStatus`, con un enum |
| Regola «dovuta» | 6 punti | `isDue` + `dueSql` affiancati, con un test di accordo |
| Bool | `force`, `ignoreMarks`, `now`, 7 bool in `propose` | `AskMode` (`force` solo per «Aggiorna» dei crediti) |
| Barra attività | job + background sempre «in corso» | le stesse due; il background dice «in attesa» |
| Fine scansione | `_autoEnrich` + `completer.start()` | solo il completer |
| Download e ricezione | `afterReceive` con una terza regola | entrambi con `autoParts` + `inFlight` |
| Metadati e copertine | metodi privati del servizio; `getBytes` dà null anche per un errore di rete | `MetadataResolver`, `CoverFetcher`; `getBytes` dà null se il file non c'è e lancia un'eccezione per la rete |
| Commit | `_commitOne` di circa 120 righe, 6 o più query per brano | una funzione per parte, ≤ 3 letture per brano |

### Percorso a piccoli passi
Nei documenti di fase questi passi sono raggruppati in 4 task per fase, perché il profilo di `/obiettivo` ne ammette al massimo 4. I numeri qui sotto sono quelli dei passi:

| Task | Passi |
|---|---|
| 69a.1 | 1, 3 |
| 69a.2 | 2, 4, 5, 6 |
| 69a.3 | 7, 8 |
| 69a.4 (controlli di fase) | — |
| 69b.1 | 1–4 |
| 69b.2 | 5, 6, 7, 13 |
| 69b.3 | 8–12 |
| 69b.4 (controlli di fase) | — |

**Fase 69a: coda ed errori, nessun cambio di struttura.**

| Task | Rilievi | Cosa cambia |
|---|---|---|
| 69a.1 | F-01 | Segnalibro: `dueTrackIds(after:)`; la chiave va in `kDeviceBoundKeys`, così non finisce nel backup |
| 69a.2 | F-02, F-16, F-04 | Catena dei testi: `limited` quando LRCLIB è a riposo o per un 429 dei ripieghi, tenendo il testo già trovato; niente timeout di 25 s |
| 69a.3 | F-03 | `EnrichGather.answered` alimenta il contatore dei brani senza risposta |
| 69a.4 | F-05 | `getBytes` distingue «non c'è» da un errore di rete; si protegge `enrich_preview_dialog._apply` |
| 69a.5 | F-17 | Deezer: un codice diverso da 800 dà `DeezerNetworkException` |
| 69a.6 | F-18 | Curiosità: se c'è il testo del brano l'esito è `found` |
| 69a.7 | F-14 | Job manuale: log, conteggi tenuti, riga «interrotto» nel Registro |
| 69a.8 | F-15, F-19 | Riga nel Registro anche per un giro fallito a vuoto; un commit fallito segna il giro come fallito; `on Error` registrato come errore; test di avvio dal provider vero |

Su F-19: la correzione del ciclo di provider è entrata con #35 il 27/10, dopo i due errori del 26/10. Probabilmente è già risolto, e il task aggiunge solo la copertura dei test.

**Fase 69b: regola, stato, motore unico.** Lo stato e la regola si unificano **prima** di togliere il motore A, così la revisione cambia solo nei casi decisi.

| Task | Rilievi | Cosa cambia |
|---|---|---|
| 69b.1 | — | Test di caratterizzazione: lista «Da revisionare», `enrich_status` dopo `enrichMany` e dopo `commit`, conteggi del job, `dueTrackIds`/`enrichCounts` |
| 69b.2 | F-11a, F-13 | Regola unica (`dueSql`, `fillableFields` con `userEdited`) + `AskMode` |
| 69b.3 | F-11 b/c/d | La revisione guarda `lyricsByUser`; stream e numero di traccia restano fuori, documentati (D-286) |
| 69b.4 | F-12 | `statusAfter` + `writeStatus`; spariscono le 5 scritture sparse |
| 69b.5 | F-20 | Estratti `MetadataResolver` e `CoverFetcher` (puro spostamento) |
| 69b.6 | F-10 | `EnrichEngine` + `inFlight`; completer, `QuietEnricher` e scheda crediti passano all'engine |
| 69b.7 | — | `EnrichRunner`, a cui il completer delega |
| 69b.8 | F-06, F-08 | Il job manuale (libreria, album, «Riprova») passa al runner con `retryNone` e `manualParts` (D-278) |
| 69b.9 | F-07 | Un solo comando in Impostazioni (D-277) con sottotitolo «N brani da completare, circa M minuti»; si tolgono `EnrichCompleteTile` e `runNow`; stringhe ARB it/en/de/es |
| 69b.10 | F-09 | Si toglie `_autoEnrich`; `afterReceive` usa `autoParts` |
| 69b.11 | F-07 | «Completamento: in attesa» |
| 69b.12 | F-06 | Si tolgono `enrichMany`, `BatchProgress`, `needsEnrichment`, `CreditsEnricher.isDue` |
| 69b.13 | F-20, F-21 | Commit per parte, ≤ 3 letture per brano |

### Rischi
- Lo stato potrebbe cambiare la lista di revisione senza volerlo. Per questo il task 69b.1 va prima del 69b.4.
- Con `getBytes` che lancia, un chiamante non protetto si rompe. Oggi c'è solo `enrich_preview_dialog._apply`.
- Un `completeOne` che aspetta un id in volo può restare fermo per un blocco intero.
- Il comando manuale in `retryNone` chiede di nuovo circa 1700 curiosità a ogni uso. Lo frenano `refused` e il limitatore.
- Senza `_autoEnrich`, i brani nuovi di una scansione si arricchiscono al ritmo del background (D-104), non subito.

## Rete
Scritta nel giro 4 con `test-strategist`. Nessun test è stato eseguito durante la pianificazione: i nomi dei test esistenti vengono dal codice.

### Test di caratterizzazione (task 69b.1, prima di toccare il codice)
Il file nuovo è `test/services/online/enrich_status_characterization_test.dart` e usa `EnrichRig`. I test fissano il comportamento di **oggi**, difetti compresi. Ogni asserzione destinata a cambiare porta nel nome il rilievo e il task in cui cambia.

| Caso | Oggi | Cambia in |
|---|---|---|
| `enrichMany`: trovato | 1 | — |
| `enrichMany`: iTunes vuoto | 2 | — |
| `enrichMany`: offline | 2 (F-08) | 69b.8 → resta 0 |
| `enrichMany`: testi `failed` + meta `none` | 2 (F-08) | 69b.8 → resta 0 |
| `commit`: trovata solo la curiosità | 2 (F-12) | 69b.4 → 1 |
| `commit`: testi `failed` + meta `none` | 2 (F-12) | 69b.4 → invariato |
| `commit`: offline | invariato (0) | — |
| `commit`: meta `none`, testi trovati | 2 | 69b.4 → 1 |
| `commit`: brano a 1, poi niente | da leggere scrivendo il test | 69b.4 → resta 1 (D-285) |
| seconda opinione che non scrive niente | 1 (F-12) | 69b.4 → invariato |
| conteggi del job (3 brani: riempito, senza match, già completo) | `updated`/`notFound`/`total` | 69b.8, sul runner, con gli stessi numeri |

Gli altri test:
- **Revisione** (`test/data/review_queries_test.dart`, un test «lista fissa»). Righe di prova: stato 0, 1 senza copertina, 2, stream, `lyricsByUser` senza testo, senza numero di traccia, `userEdited` senza album. Il test asserisce gli id per ogni `ReviewReason`. In 69b.3 cambia solo la riga `lyricsByUser`, che non è più «senza testo» (D-286).
- **Accordo `dueTrackIds`/`enrichCounts` con `isDue`.** Si estendono i test esistenti di `enrich_completer_test.dart` (vicino a :544 e :586) con due casi:
  - `lyricsByUser`;
  - `userEdited` senza album, che cambia in 69b.2 (F-11a).
- **Letture per brano.** In 69b.1 si annota il numero di oggi; dal task 69b.13 c'è un test che lo vincola.

### Test mirati della fase 69a
| Task | Test |
|---|---|
| 69a.1 | `dueTrackIds(after:)`; giro che riparte dal segnalibro e ricomincia a fine coda; chiave in `kDeviceBoundKeys` |
| 69a.2 | in `lyrics_chain_test`: LRCLIB a riposo → `limited`; 429 di un ripiego dopo un testo LRCLIB → testo tenuto. Il test «429 from a fallback is rethrown» (:252) cambia di proposito. Il timeout è solo collegamento, non serve un test |
| 69a.3 | in `enrich_completer_test`: meta risposta + testi in errore non conta come «senza risposta» |
| 69a.4 | `getBytes`: lancia sulla rete, null su 404 → meta `none` con segno; «cover download fails: failed» (`enrich_guards_test:450`) resta |
| 69a.5 | in `enrichment_deezer_test`: codice diverso da 800 → `failed`, nessun segno |
| 69a.6 | in `enrich_guards_test`: artista rifiutato + testo del brano → `found` |
| 69a.7 | in `enrich_job_test`: errore → log, conteggi tenuti, riga «interrotto» |
| 69a.8 | in `enrich_completer_providers_test`: riga di Registro per un giro fallito a vuoto e per un commit fallito |

### Test esistenti che cambiano di proposito nella fase 69b
| Task | Test |
|---|---|
| 69b.4 | `enrich_guards_test:243` «match that fills nothing is nothing, status 2» |
| 69b.8 | `enrichment_needs_test`, `enrichment_service_test:111` e `review_actions_test:79` passano al runner |
| 69b.9 | cadono `enrich_completer_test:336` («now during a round») e i test `runNow`/`manual`; cadono `enrich_completer_providers_test:249` e `:316` («Completa») |
| 69b.12 | cadono `enrichment_needs_test` ed `enrichment_credits_test:422` («enrichMany force…»); i test di `CreditsEnricher.isDue` si spostano su `isDue` |

### Metriche di arrivo (fine 69b)
| Metrica | Comando | Oggi | Soglia |
|---|---|---|---|
| Righe del servizio | `wc -l lib/services/online/enrichment_service.dart` | 983 | ≤ 450 |
| File nuovi | `wc -l lib/services/online/{enrich_engine,enrich_runner,enrich_writer,metadata_resolver,cover_fetcher}.dart` | — | ognuno ≤ 400 |
| Scritture di `enrich_status` | `grep -rn 'enrichStatus: Value' lib --include=*.dart \| grep -v '\.g\.dart'` | 4 | 1 (`enrich_writer.dart`) |
| Catch muti nel perimetro | `grep -nE 'on Object\|catch \(' <file del perimetro>`, controllo a mano di ogni riga | almeno 1 (`online_providers.dart:203`) | 0 |
| Simboli tolti | `grep -rnE 'enrichMany\|BatchProgress\|needsEnrichment\|_autoEnrich\|EnrichCompleteTile\|runNow\|ignoreMarks' lib test` | > 0 | 0 |
| Letture per brano nel commit | test con un `QueryInterceptor` di drift che conta i `SELECT` | ≥ 6 | ≤ 3 |
| Analisi | `flutter analyze` | pulito | pulito |

### Comportamento invariato
Per gli stessi esiti delle fonti devono restare uguali:
- le righe di «Da revisionare»;
- `enrich_status`;
- i campi scritti;
- le richieste alle fonti;
- i segni `*_none_at` (D-103).

Lo schema DB v15 e il formato del backup non cambiano. Fanno eccezione solo i cambi scelti, ciascuno con il suo test:

| Decisione | Cosa cambia | Test |
|---|---|---|
| D-277/D-284 | un solo comando, che riprova anche i «niente» | `enrich_job_test` più un test di unità sul conteggio del sottotitolo (69b.9) |
| D-278 | curiosità nel manuale, crediti solo con l'interruttore | test del runner in `retryNone` con `manualParts` (69b.8) |
| D-279/D-285 | regola dello stato | tabella di `statusAfter` in `enrich_parts_test`, più i casi di caratterizzazione cambiati in 69b.4 |
| D-286 | revisione allineata su `lyricsByUser` | `review_queries_test` (69b.3) |
| D-288 | niente `_autoEnrich` a fine scansione | grep a zero, più `afterReceive` con `autoParts` in `download_enrich_test` (69b.10) |

### Comandi mirati
- Fase 69a: `flutter test test/services/online/{lyrics_chain,enrich_completer,enrich_guards,enrichment_deezer,enrichment_service}_test.dart test/providers/{enrich_job,enrich_completer_providers,enrich_completer_log_cycle}_test.dart`
- Task 69b.1–69b.4: `flutter test test/services/online/{enrich_status_characterization,enrich_parts,enrich_guards,enrichment_needs,second_opinion,enrich_completer}_test.dart test/data/review_queries_test.dart`
- Task 69b.5–69b.13: gli stessi, più `enrichment_credits`, `quiet_enricher`, `download_enrich`, `review_actions` ed `enrich_completer_providers`. La suite completa la esegue la CI.
