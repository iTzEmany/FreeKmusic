# Fase 69a — La coda dell'arricchimento riparte (refactor «arricchimento-unico», parte 1)

**Obiettivo:** il completamento in background (D-102) torna a lavorare. Oggi si ferma in 15 s a ogni avvio:
- LRCLIB a riposo fa sembrare «senza risposta» ogni testo;
- i primi brani per id sono sempre gli stessi;
- il contatore dei brani senza risposta conta anche i brani a cui Deezer o iTunes hanno risposto.

Si correggono anche gli errori nascosti attorno alla coda. La struttura **non cambia**: la fase 69b la unifica. Rilievi F-01…F-05 e F-14…F-19.

**Prerequisiti:** fase 69 chiusa. Da leggere: `docs/refactor/arricchimento-unico/analisi.md`, cioè i rilievi con `file:riga`, «Misure di partenza», «Arrivo» e «Rete». Decisioni: D-102, D-103, D-104, D-134, D-275, D-276, D-280, D-283, D-287, D-289. Intoccabili (D-280):
- schema DB v15;
- formato di backup e condivisione;
- ritmo e pause del completamento.

Nessun pacchetto nuovo.

**Comando mirato:** `flutter test test/services/online/lyrics_chain_test.dart test/services/online/enrich_completer_test.dart test/services/online/enrich_guards_test.dart test/services/online/enrichment_deezer_test.dart test/services/online/enrichment_service_test.dart test/providers/enrich_job_test.dart test/providers/enrich_completer_providers_test.dart test/providers/enrich_completer_log_cycle_test.dart test/data/credits_repository_test.dart` più i file di test toccati dal task.

## Task

Al massimo 4 task per fase (profilo di `/obiettivo`), un commit per task. Ogni task ha i suoi passi, da fare nell'ordine scritto: ogni passo ha il suo «Fatto quando» e lascia il codice funzionante.

### 69a.1 — La coda avanza (F-01, F-03)

#### Passo: Segnalibro della coda (F-01, D-276, D-287)
`dueTrackIds` (`credits_repository.dart:43`, `ORDER BY t.id`) riceve `after`, cioè `t.id > ?`. `EnrichCompleter` parte dal segnalibro e lo sposta su **ogni** brano provato, con o senza risposta. A fine coda fa un solo passaggio dall'inizio, con `tried` per non ripetere i brani del giro. Il segnalibro sta in `SettingsStore` (`shared_preferences`) e la chiave va in `kDeviceBoundKeys`, così non entra nel backup e il formato non cambia. Senza segnalibro (`after = 0`) l'ordine resta quello di oggi.

**Fatto quando:** test in `enrich_completer_test.dart`:
- se il primo brano è sempre `failed`, il giro dopo parte dal secondo;
- a fine coda si riprende dall'inizio.

Test in `credits_repository_test.dart` per `after`. Test in `test/data/settings_store_test.dart`, o in quello del backup: la chiave non sta in `settings.json`.

#### Passo: Il contatore guarda chi ha risposto (F-03)
`EnrichGather.answered` è vero se la meta è stata chiesta e non è `failed`, oppure se una parte è `found` o `none`. `EnrichCompleter` (`enrich_completer.dart:126-129`) conta «senza risposta» solo quando `answered` è falso.

**Fatto quando:**
- un test in `enrich_completer_test.dart` lavora tutti i 6 brani in cui la meta risponde e i testi lanciano;
- il test offline esistente (:260) resta verde.

### 69a.2 — Le fonti che non rispondono non sembrano «niente» (F-02, F-04, F-05, F-16, F-17, F-18)

#### Passo: Catena dei testi: «a riposo» non vuol dire «senza risposta» (F-02, F-16, F-04)
`LyricsChainResult` riceve un flag `limited`. È vero in due casi:
- LRCLIB è a riposo (`lyrics_chain.dart:76-77`);
- NetEase o lyrics.ovh rispondono 429 dopo LRCLIB. Il testo già trovato si tiene e non si rilancia `RateLimitedException` (`:65-66, 103-111`).

In `gather` (`enrichment_service.dart:435-485`) testi e sincronizzati diventano `PartOutcome.limited` ed entrano in `refused` (D-134). Il resto del giro va avanti. I testi si chiamano con `_attempt(..., timeout: false)`, come crediti e curiosità, senza il limite di 25 s su tutta la catena.

**Fatto quando:** test in `lyrics_chain_test.dart`:
- LRCLIB a riposo → `limited`;
- 429 di un ripiego dopo un testo di LRCLIB → testo tenuto e `limited`. Il test «429 from a fallback is rethrown» (:252) cambia di proposito.

Test in `enrich_completer_test.dart`: con LRCLIB a riposo, meta e curiosità dei brani successivi vengono lavorate e il giro non si ferma.

#### Passo: Copertina che non c'è oppure rete giù (F-05)
`getBytes` (`http_client.dart:115-133`) restituisce null solo per «non c'è» (404 o file troppo grande). Per un errore di rete rilancia la `DioException`, salvo l'annullamento. Nel giro di fondo:
- null → meta `none`, con il segno di 30 giorni;
- eccezione → `failed`, senza segno.

Si protegge `enrich_preview_dialog._apply` (:136-140). Gli altri chiamanti catturano già: `cover_picker_providers.dart:36`, `podcast_service.dart:111`, l'import e la seconda opinione. Il task li ricontrolla uno per uno con codegraph.

**Fatto quando:** test:
- 404 → `metaNoneAt` scritto;
- errore di connessione → `failed` senza segno;
- «cover download fails: failed» (`enrich_guards_test.dart:450`) resta verde.

#### Passo: Codici di errore di Deezer (F-17)
In `deezer_client.dart:129-130` un codice d'errore diverso da 800 («nessun risultato») lancia `DeezerNetworkException` invece di restituire null. I chiamanti la gestiscono già.

**Fatto quando:** test in `enrichment_deezer_test.dart`:
- codice 100 → meta `failed`, nessun segno né `creditsNoneAt`;
- codice 800 → `none` come oggi.

#### Passo: Curiosità trovate per il brano (F-18)
In `enrichment_service.dart:513-516` l'esito è `found` se è stato salvato il testo del brano, prima di guardare `limited`.

**Fatto quando:** test in `enrich_guards_test.dart`: con l'artista rifiutato e il testo del brano trovato, l'esito è `found` e il segno della curiosità viene tolto.

### 69a.3 — Errori visibili (F-14, F-15, F-19)

#### Passo: Il lavoro manuale non fallisce in silenzio (F-14)
In `EnrichJobNotifier._run` (`online_providers.dart:203-207`) l'`on Object` muto viene sostituito:
- `AppLog.e` con lo stack;
- i conteggi raccolti fino a quel punto si tengono;
- il risultato segna l'errore e il Registro riceve una riga «interrotto».

`onFinished` parte solo se il lavoro è finito davvero.

**Fatto quando:** test in `enrich_job_test.dart`: un `enrichMany` che lancia a metà produce il log, i conteggi dei brani già fatti e la riga «interrotto».

#### Passo: Registro ed errori di programmazione (F-15, F-19)
Le correzioni:
- `enrich_completer_providers.dart:151-155` scrive nel Registro anche un giro fallito senza lavoro: «Completamento fermato: nessuna fonte risponde»;
- un commit fallito (`enrich_completer.dart:182-184`) imposta `round.failed`;
- un `Error` (non `Exception`) va in `AppLog.e`, non fra gli avvisi;
- stringhe ARB in it, en, de ed es.

Su F-19: il `CircularDependencyError` del 26/10 è precedente a #35 (27/10), che ha tolto un ciclo fra provider. Il task aggiunge la copertura dei due avvii che mancano, a fine scansione e al cambio di un interruttore. Il test parte dal provider vero, con Registro e attività collegati. `runNow` è già coperto da `enrich_completer_log_cycle_test.dart`.

**Fatto quando:** test in `enrich_completer_providers_test.dart`:
- giro fallito a vuoto → una riga nel Registro;
- commit fallito → giro fallito.

I due test di avvio dal provider vero passano senza errori.

### 69a.4 — Controlli di fase
1. Comando mirato verde e `flutter analyze` pulito. La CI esegue la suite completa.
2. Review del diff con `/code-review high`, perché la coda e gli errori sono un'area a rischio.
3. **Misura sul Motorola (D-289).** Prima si chiede all'utente se il telefono è libero. Poi:
   - `flutter build apk --debug` con `sorveglia.sh --pesante`;
   - `adb install -r` (dati tenuti, mai disinstallare);
   - si apre l'app e la si lascia ferma per circa 15 minuti con la musica accesa;
   - si copiano DB e `codecore.log` solo in lettura.

   Criteri, confrontati con «Misure di partenza» di `analisi.md`:
   - i brani con una parte dovuta sono **meno di 1812**;
   - nel Registro ci sono giri `enrichBackground` con lavoro;
   - nel log non compare più «5 tracks in a row got no answer» subito dopo «LRCLIB answered 503».

   Esiti qui sotto. Le copie si cancellano con `pulizia.sh`.
4. In `docs/02-architettura.md` §«Arricchimento» (riga circa 335): segnalibro, `limited` dei testi, `getBytes`.

## Esiti di 69a.4 (2026-10-30)

- Comando mirato verde e `flutter analyze` pulito. `/code-review high` fatta: 9 rilievi corretti (4650805); il «answered» duplicato è stato scartato perché lo riscrive 69b. La scheggia (modalità passo) ha trovato due bug medi, corretti in e28cd28: il segnalibro restava fermo se ogni lettura lanciava, e un giro che perdeva le scritture non lasciava righe nel Registro. Ha segnalato anche due test mancanti (il passaggio dall'inizio senza ripetizioni e `getBytes` reale), ora aggiunti.
- **Motorola, prima misura** (18:52–19:09, APK con 69a.1–69a.3): **fallita**. Il log diceva «LRCLIB answered 503» e 11 s dopo «5 tracks in a row got no answer». La causa: il blocco di 20 brani si legge prima che i testi siano rifiutati, e i brani dovuti solo per i testi uscivano tutti `skipped` e facevano salire il contatore. Corretto in 8aee0bb: un brano che non chiede niente non conta. Nella stessa misura il segnalibro funzionava (0 → 474) e la riga del giro fallito era nel Registro.
- **Motorola, seconda misura** (19:12–19:28, APK con 8aee0bb, musica in pausa per D-296):
  - brani con una parte dovuta: **1787** (1823 prima dell'installazione; partenza dell'analisi 1812). Solo musica: 1737 → 1710 dopo i 15 minuti. ✔
  - Registro: giro `enrichBackground` con lavoro, fermato con «Pausa» per scrivere la riga: 35 brani aggiornati (crediti 31, curiosità 17, meta 4) e 3 senza risposta. ✔
  - log: un solo «LRCLIB answered 503» all'avvio (19:12:45), nessun «tracks in a row got no answer», nessun `[E]`. Gli avvisi sono 503 di MusicBrainz sui crediti, e il giro è andato avanti. ✔
  - segnalibro 474 → 601 dopo 15 minuti.
- Copie: `.backup-motorola/codecore-data-2026-10-30.tar` (prima della prima installazione) e `.backup-motorola/codecore-2026-10-30-1915/` (prima della seconda), da cancellare con `pulizia.sh` a fine obiettivo.
