# Fase 66 — Coda insieme (feature «Jam: cassa e coda insieme»)

**Obiettivo:** l'host sceglie fra «Coda dell'host» (di oggi) e «Coda insieme»: i brani di tutti si alternano a giro, ognuno porta la sua coda, chi resta senza brani riceve un suggerito locale.

**Prerequisiti:** fase 65 chiusa (caratterizzazione della coda verde, coda dell'ospite salvata all'ingresso). Requisiti R-96 … R-106; decisioni D-179, D-184 … D-188, D-192 … D-194, D-207 … D-210, D-213 … D-215. Area a rischio: protocollo Jam.

**Comando mirato:** `flutter test test/jam test/ui/jam_screen_test.dart test/ui/jam_parts_test.dart test/ui/queue_reorder_test.dart`; in più `flutter test test/data` quando si tocca `LibraryQueries`.

## Task

### 66.1 — Modalità nello stato della Jam (R-96, R-106, D-213)
`JamState.mode` (`host` di serie, `together`; chiave JSON `mode`, assente = `host`), `JamItem.suggested` (`sug`), comando `setMode` accettato solo dall'host (`forbidden` dagli ospiti). Nessun cambio di ordine qui.

**Fatto quando:** test di (de)serializzazione con e senza i campi; test `setMode` da host (version + 1) e da ospite (rifiutato); i test di 65.1 verdi senza modifiche.

### 66.2 — Ordine a turno (R-97, R-98, D-187, D-214)
`lib/services/jam/jam_turns.dart`: `togetherOrder(items, currentIndex, participantOrder)` puro: dopo il corrente alterna a giro le sottosequenze di ciascuno (ognuna nel suo ordine), partendo da chi viene dopo il proprietario del corrente; chi non ha più brani salta il turno. Nel reducer, con `mode = together`: un'aggiunta va in testa alla parte del mittente, poi `togetherOrder`; anche dopo `remove`, `setMode(together)`, ingresso e uscita di un membro.

**Fatto quando:** test a tabella con 2 e 3 partecipanti, code di lunghezze diverse, aggiunte con parte vuota e piena mentre suona un brano proprio e di un altro (esempi di D-179); invariante 2 come proprietà su 200 sequenze casuali (seme fisso).

### 66.3 — Riga della modalità e niente trascinamento (R-96, R-103, D-188, D-207)
In cima al foglio «Coda condivisa» una riga con due scelte («Coda dell'host» / «Coda insieme»): attiva per l'host, solo da leggere per gli ospiti, con `Semantics`. In `together` niente maniglie di trascinamento e `move` rifiutato dal reducer. Stringhe nelle ARB it/en/de/es.

**Fatto quando:** test widget per host e ospite; test del reducer (`move` in `together` → rifiutato); golden del foglio rigenerato solo per la riga nuova.

### 66.4 — Parte di ognuno e feeder (R-99, R-100, R-101, D-186, D-192, D-194, K-JC-02)
`lib/services/jam/jam_part_feeder.dart`: su ogni dispositivo, con `mode = together`, la parte locale = coda salvata all'ingresso (host: la coda ereditata) più le aggiunte non ancora mandate; il feeder manda il prossimo brano quando nella Jam ne ha meno di `ceil(200 / partecipanti)` in arrivo. Ogni item porta una chiave di parte: il feeder non rimanda una chiave già nella Jam o già suonata (invariante 3). Aggiunte, rimozioni e «Riproduci dopo» dell'ospite cambiano la sua parte; uscendo (65.3) ritrova la parte non suonata (D-209).

**Fatto quando:** simulazione con host e due ospiti in memoria (`jam_multi_sim_test`): code da 300 brani, 500 brani suonati, nessuna chiave persa né doppia, mai più di 200 item; test del ripristino della parte all'uscita.

### 66.5 — Suggeriti locali (R-102, D-185, D-208)
`lib/services/jam/jam_suggestion.dart`: scelta pesata per genere (frequenza nella coda di prima), esclusi i brani già suonati nella Jam, ripiego su un brano a caso della libreria; query in `LibraryQueries` (`lower(trim(genre))` lato SQLite, vedi `docs/gotchas.md`). Il feeder la usa quando la parte è vuota e non ha brani in arrivo; l'item ha `suggested = true` e nella coda si vede «Suggerito».

**Fatto quando:** test della scelta con seme fisso (pesi, esclusione, ripiego, libreria vuota → nessun suggerito); test host+ospite: la parte vuota riceve un suggerito al suo turno.

### 66.6 — Ritorno, ingresso e uscita (R-91, R-104, R-105, D-193, D-210, D-221)
`setMode(host)` lascia gli item dove sono e ferma i feeder; da lì le aggiunte vanno in fila come R-88. Durante `together` chi entra va in fondo al giro; chi esce lo lascia, i suoi brani di libreria si tolgono e quelli online restano al loro posto (D-93). In entrambe le modalità, se esce l'unico ospite la Jam resta aperta con il solo host, che continua la coda (D-221): `JamHost.removeMember` non chiama più `endSession()` quando `_members` è vuoto.

**Fatto quando:** test del reducer e della simulazione per i tre casi; test host + un ospite in memoria: l'ospite esce con un brano online non suonato → la Jam resta attiva sull'host, il brano è in coda e l'host lo prepara da sé.

### 66.7 — Controlli di fase
`flutter analyze`, comando mirato, suite completa in CI, `/code-review high`, scheggia in modalità passo su 66.2 e 66.4 e in modalità fase (Linux + Mi A3 da soli non bastano per la Jam: prova a mano in 68.3), review di architettura Opus.

**Fatto quando:** tutto verde; colonna Fase di R-96 … R-106 compilata.
