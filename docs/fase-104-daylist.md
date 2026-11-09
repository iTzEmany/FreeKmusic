# Fase 104 — Daylist

**Obiettivo:** una playlist che cambia con la fascia oraria, fatta dei brani dell'utente e di suggeriti simili, regolabile per fascia. **Funzione nuova** (D-433, D-439, D-440, D-443, D-444, D-452).

**Prerequisiti:** fasi 100 e 101 chiuse (`RadioFill`, `SuggestionGate`). Analisi F-115 e «Arrivo». Mockup approvati: `refactor/ascolto-quotidiano/mockup/daylist.html`, `refactor/ascolto-quotidiano/mockup/daylist-impostazioni.html`. Aree a rischio: query su `tracks`/`plays` (`/code-review high`).

**Comando mirato:** `flutter test test/services/daylist/ test/providers/daylist_provider_test.dart`

## Task

### 104.1 — Fasce e tabella degli umori (logica pura)
- `lib/services/daylist/daylist_slots.dart`: 8 fasce con inizi di serie 5, 9, 13, 16, 19, 22, 0, 3 (D-443); si modifica solo l'inizio a passi di 1 h, ogni fascia ≥ 1 h; notte e tarda notte spente di serie; quota di suggeriti 30% (25% mattina presto, 20% notte e tarda notte); per fascia generi preferiti ed evitati e umori. Salvate in `shared_preferences` (nel backup tramite `settings.json`).
- `mood_table.dart`: umori energico, allegro, tranquillo, rilassante, malinconico, concentrazione; ~20 generi comuni già associati (quelli del mockup), modifiche dell'utente in `shared_preferences`; genere sconosciuto → nessun umore.
- Test: confini (4:59, 5:00, 8:59, 9:00, 23:59 → 0:00, 3:00), passi di 1 h, tabella di serie e modifiche.

### 104.2 — `DaylistBuilder` (logica pura, D-440, D-452)
- Input iniettati (ascolti, generi, tabella, orologio, casuale, suggeriti). Semi = brani dell'utente più ascoltati nella fascia oraria (`Plays.playedAt`, raggruppamento per ora come `stats_queries.dart:321-337`); brani propri = ascoltati nella fascia + stesso artista o genere dei semi, filtrati per generi e umori della fascia; suggeriti = radio dei semi via `RadioFill` e `SuggestionGate`, filtrati per generi evitati e umori; 50 brani, quota di suggeriti della fascia, almeno 3 generi diversi, nessuna ripetizione; fascia senza storico → generi e umori scelti e brani più ascoltati in assoluto come semi.
- Nota: il filtro di generi e umori va dentro `RadioFill.take` con un predicato `accept(SuggestionCandidate)` applicato prima di contare il suggerito (filtrare a valle brucia righe del pool e il budget di richieste).
- Nome «<Fascia> · <fino a 3 generi>».
- Test `test/services/daylist/daylist_builder_test.dart`: 50 brani, quota, ≥ 3 generi, evitati esclusi anche dai suggeriti, semi, fascia senza storico, nessuna ripetizione.

### 104.3 — Provider e rigenerazione
- `daylistProvider`: costruisce la daylist della fascia corrente fuori dal thread UI (query in `Isolate` o lato DB), si rigenera all'inizio di ogni fascia (timer) e all'avvio se la fascia è cambiata mentre l'app era chiusa; i suggeriti senza rete mancano senza errori (solo brani propri). Richieste di rete solo con le regole di arricchimento e il budget YTM esistenti.
- Test `test/providers/daylist_provider_test.dart` (cambio fascia con orologio finto, avvio dopo un cambio).

### 104.4 — Card in Home e schermata
- Card dopo «Riprendi» e prima di «Più ascoltati» (D-444), «cambia alle HH:00»; fascia spenta → nessuna card. Schermata come nel mockup: titolo, chip dei generi, Play/Shuffle, «Si aggiorna alle HH:00», righe dei suggeriti marcate come oggi. Etichette TalkBack.

### 104.5 — Impostazioni → Daylist
- Elenco delle 8 fasce con orari, interruttore e riassunto; editor della fascia (orario d'inizio, generi da preferire/evitare, umori, quota di suggeriti, ripristino della fascia); pagina della tabella generi → umore con ricerca; ripristino di tutto (con conferma). Come nel mockup.

### 104.6 — Controlli di fase
`flutter analyze`; comando mirato; review (`/code-review high` sulle query); scheggia passo e fase; prova sul Mi A3 contro i mockup (card, schermata, cambio di fascia spostando l'orario d'inizio, impostazioni, senza rete). Ripulire il telefono.

**Fatto quando:** la daylist cambia al cambio di fascia, rispetta quota, generi e umori, e le impostazioni la modificano.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-473** (104.2): la daylist si accorcia; sotto i 15 brani non si crea e la card non compare, con l'avviso nelle impostazioni accanto alla fascia; con meno di 50 brani il dettaglio lo dice sotto il titolo.
- **D-474** (104.3): la daylist si salva fino al cambio di fascia; al cambio la coda in corso non si tocca; ripremendo Play sulla card parte la nuova.

## Esiti
- 104.1–104.2 (2026-11-09): `DaylistConfig` (8 fasce, orario d'inizio modificabile) e `MoodTable` (genere → umori, modificabile); `DaylistBuilder` in due tempi: `plan` in un isolate (pesi per ascolti a 90 giorni, generi preferiti/evitati, umori), `finish` con i suggeriti dalla radio di Shuffle+ (stesse regole e filtri «Non mi piace»; quota 0 % = niente rete). Suggeriti di artisti fuori libreria con i generi del seme (D-481).
- 104.3: `daylistProvider` rigenerato al cambio di fascia (timer + controllo al ritorno dell'app), build vecchie annullate, attesa di assestamento sulle modifiche; `daylist.json` salvata fino alla fascia dopo, legata alla sola fascia corrente, non salvata senza rete quando servono suggeriti; `daylistVisibleProvider` toglie subito i suggeriti bloccati da lista, card e Play.
- 104.4–104.5: card in Home, schermata con righe proprie (menu brano) e suggerite (menu «Non mi piace»), Impostazioni → Daylist con editor della fascia, tabella degli umori con ricerca e ripristino.
- 104.6: `flutter analyze` pulito, test mirati verdi; review Opus sui provider (7 bug) e di architettura, scheggia di passo (suggeriti filtrati via, doppioni, confini) e di fase sul Mi A3 (suggerito bloccato ancora in lista, «R and b soul», menu delle righe, due etichette TalkBack): tutto corretto con i test. Telefono ripulito. Non provati: cambio di fascia ad app chiusa, quote 0 % e 100 % sul telefono (coperti dai test).
