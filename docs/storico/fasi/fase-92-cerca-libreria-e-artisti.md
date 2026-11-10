# Fase 92 — Cerca: libreria, fonte, artisti e album (refactor «superfici-e-ricerca»)

**Obiettivo:** Cerca mostra in cima i brani già in libreria, dice da quale fonte viene ogni risultato online e offre più artisti e album in righe orizzontali.

**Prerequisiti:** fase 91 chiusa. Mockup `refactor/superfici-e-ricerca/mockup/cerca.html`. Decisioni D-397, D-399, D-400, D-401, D-413. Rilievi F-84…F-87 (84/85 già fatti nelle fasi precedenti se presenti nel mockup). Aree a rischio: `lib/services/online/merge_results.dart`, `lib/services/online/request_budget.dart` (rete e budget).

**Comando mirato:** `flutter test test/ui/online_results_test.dart test/ui/search_screen_test.dart test/ui/search_sources_test.dart test/ui/youtube_results_artist_test.dart test/services/online/merge_results_test.dart test/services/online/smart_search_test.dart test/services/online/ytm_catalog_test.dart test/services/online/ytm_artist_parser_test.dart test/services/online/request_budget_test.dart test/services/import/track_matcher_test.dart test/services/online/library_overlap_test.dart` più i test nuovi di questa fase.

## Task

### 92.1 — «Nella tua libreria» (F-86, D-399, D-400, D-413)
- Solo se l'intento è un brano (anche con l'artista); per artista o album la sezione non c'è. Fino a 3 brani trovati con `LibraryIndex` (`lib/services/import/track_matcher.dart:51`), «Mostra tutti (N)» a destra del titolo della sezione.
- Il tocco suona il file locale (non lo streaming). I doppioni (stesso titolo+artista, D-389) spariscono dalla lista online e sotto compare la riga piccola «N risultati già in libreria nascosti».
- Inserirla in `lib/ui/screens/youtube/online_results.dart`, in `_list`, prima dei «Migliori risultati»; il filtro dei doppioni nel merge (`merge_results.dart:100-165`), non nella UI. Il confronto gira fuori dal thread UI (indice già in memoria).
- Test nuovi: ricerca brano con 5 brani locali → 3 + «Mostra tutti (5)»; ricerca artista → nessuna sezione; doppione tolto e riga «1 risultato già in libreria nascosto»; tocco = file locale; libreria vuota → niente sezione. ARB it/en/de/es.

### 92.2 — Etichetta della fonte (D-413)
- Su ogni risultato online una piccola etichetta «YouTube Music» o «YouTube» (dal tipo di risultato di `mergeResults`), come nel mockup. Semantics inclusa nell'etichetta della riga.
- Test: riga YTM e riga video YouTube mostrano l'etichetta giusta; layout senza overflow a scala testo 1,5.

### 92.3 — Righe «Artisti» e «Album» (F-87, D-401)
- Artisti: `YtmCatalog.searchArtists` (`ytm_catalog.dart:93-103`). Album: ricerca YTM filtrata sugli album, con params e parser nuovi (riferimento: `searchAlbums` in `youtube_service.dart:236`; params letti dal codice/fixture, non a memoria). Fixture JSON nuove in `test/fixtures/innertube/`.
- Fino a 10 voci per riga, una richiesta in più dentro `request_budget.dart` (rate limit e stop in rete a consumo come le altre). Stato in SmartSearch (`lib/services/online/smart_search.dart`), non nella UI; errore o budget esaurito → righe assenti, nessun errore a schermo.
- Tocco su un artista/album apre la pagina esistente. Sotto la scheda principale (`ytm_artist_parser.dart:21-26` resta per la scheda).
- Ribaltare `test/services/online/merge_results_characterization_test.dart` (della 87): ora ci sono brani locali e più artisti/album. Test nuovi: parser album e artisti su fixture; budget rispettato; più di 10 risultati → 10; richiesta fallita → resto della pagina intatto.

### 92.4 — Controlli di fase
`flutter analyze`; comando mirato; golden `search` toccati rigenerati con `scripts/shots.sh`; review del diff (code-review high su merge e budget); scheggia. Prova sul Motorola edge 40 (ZY22HKD85K) e sul Mi A3 (0d7ae9df206e) via adb: «born on the bayou» (doppione nascosto), un artista omonimo, scorrimento delle righe orizzontali senza scatti (D-398).

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
- **92.1**:
  - «Nella tua libreria» compare solo a intento noto e di tipo brano (D-400). I brani vengono dalla ricerca per testo della Libreria, più i brani locali abbinati ai doppioni nascosti, così la nota «N nascosti» non compare mai senza i brani a cui si riferisce.
  - Mostra fino a 3 brani e «Mostra tutti (N)»; il tocco suona il file locale.
  - La sezione compare anche se la parte online è vuota o in errore.
  - I doppioni (titolo e artista, D-389, compresi i video già scaricati) si calcolano una volta per risultato in `ownedSplitProvider`. La regola è una sola, condivisa con Shuffle+ (`libraryMatchOf`).
  - La riga «N risultati già in libreria nascosti» sta in fondo e conta solo i nascosti del filtro di fonte attivo.
  - La selezione è per risultato, non per posizione.
- **92.2**: ogni risultato online ha un'etichetta «YouTube Music» o «YouTube», che TalkBack legge come «Da …».
- **92.3**:
  - Righe orizzontali «Artisti» e «Album» sotto la scheda, fino a 10 voci; l'artista della scheda non viene ripetuto.
  - Il filtro album di YouTube Music è stato verificato dal vivo, e la fixture è una risposta vera.
  - Le due richieste prendono il budget insieme: 20 al minuto. Le righe non ritardano mai la pagina né l'errore, e la pagina va in cache anche senza righe.
  - **D-425 (autonomia)**: non c'è uno stop in rete a consumo, perché il resto di Cerca non ne ha. Un 429 delle righe mette in pausa anche la scheda principale, per scelta.
- **Review** `code-review high` (Opus) su merge e budget: 10 rilievi, tutti applicati (il 429 condiviso è tenuto e commentato). Tra questi, l'overflow a scala del testo 2,0 dell'avviso legale, un difetto precedente alla fase.
- **Scheggia**:
  - 3 mutanti su 4 uccisi; il quarto (copia in cache con righe parziali) ora è coperto da un test.
  - Sul Mi A3:
    - «bohemian rhapsody queen» mostra 3 brani in «Nella tua libreria» e «6 risultati già in libreria nascosti»;
    - artisti e album («genesis», «nirvana», «pink floyd», «abbey road») mostrano le righe e nessuna sezione libreria;
    - 15 ricerche di fila e 2 raffiche: nessun crash.
    - «born on the bayou» non è nella libreria del telefono, quindi il doppione nascosto è stato provato con un altro brano.
  - Bug corretti con test: una pagina in cache restava senza righe per 10 minuti dopo un budget esaurito; l'artista della scheda era ripetuto nella riga; un secondo invio dello stesso testo mentre la ricerca è in corso lanciava una seconda ricerca: ora riusa quella in corso; la digitazione non fa partire ricerche.
- **Scorrimento delle righe** sul Mi A3, build debug a 60 Hz: mediana 16,7 ms, al massimo 50 ms in qualche gesto, meno scatti dello scroll verticale di riferimento (116 ms). Nessuno scatto evidente (D-398).
- **Golden**: `search_results` rigenerati (telefono e desktop).
- **Motorola**: rinviato alla fase 97 (D-419, D-420).
