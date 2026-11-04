# Fase 80 — Cerca solo online e generi misti (refactor «ui-uso-quotidiano»)

**Obiettivo:** Cerca diventa solo online, con ricerche recenti e generi in griglia da 3; un genere apre una pagina mista con 2 brani della libreria e 1 suggerito online; nella build senza YouTube Cerca sparisce. Shuffle+ espone lo stato «in preparazione» che serve qui e nella fase 81.

**Prerequisiti:** fase 79 chiusa (la ricerca in libreria sta già in Libreria). Mockup `refactor/ui-uso-quotidiano/mockup/cerca.html`. Decisioni D-355, D-356, D-358, D-359, D-360. Area a rischio: `lib/services/shuffle_plus/shuffle_plus_controller.dart`.

**Comando mirato:** `flutter test test/ui/search_screen_test.dart test/ui/search_dock_test.dart test/ui/search_sources_test.dart test/ui/genre_screen_test.dart test/providers/shuffle_plus_test.dart test/services/shuffle_plus`.

## Task

### 80.1 — Cerca solo online (F-05…F-07, F-22, F-28, U4, U10, D-355, D-358, D-360)
- Via il segmento Libreria/Online (`search_screen.dart:274-297`), `_goOnlineIfNoLocal` (:138-155), i chip Preferiti/Recenti (:240-272) e i parametri di `SearchQuery` rimasti senza usi. Il prefill della Radio (`_applyPrefill` :71-81) continua a funzionare.
- Sotto la barra: Ricerche recenti (✕ con la query nell'etichetta, F-22) e Generi della libreria ordinati per numero di brani, in griglia uniforme da 3 colonne (6 su desktop), celle ≥ 56 dp, testo fino a 2 righe.
- Con `CODECORE_YOUTUBE=false` la scheda Cerca non c'è nel dock né nella barra laterale (D-358).
- Riscrivere i test dei risultati locali. Test nuovi: nessun risultato locale; generi ordinati; Cerca assente senza YouTube.

### 80.2 — Stato «in preparazione» di Shuffle+ (F-53)
- Provider osservabile (es. `shufflePlusPendingProvider`) con il numero di suggeriti in arrivo e gli id del blocco in arricchimento, alimentato da `_suggestOne` / `_block` / `_enriching` (`shuffle_plus_controller.dart:81-86,133-135,357,408-411`), senza cambiare l'ordine né il numero dei suggeriti.
- Test: lo stato riporta 3 in arrivo all'avvio, scende quando entrano, segue il blocco in arricchimento, torna a 0 con Shuffle+ spento.

### 80.3 — Pagina del genere mista (D-356, D-359)
- `GenreScreen`: brani della libreria del genere con un suggerito online ogni 2 (libreria, libreria, suggerito), seme dai brani locali del genere, motore di Shuffle+ (stessi limiti: rete a consumo, Jam, strumento assente → solo libreria con un avviso). Il suggerito ha l'etichetta «Suggerito» con icona online; quelli in arrivo sono righe `Skeleton` (stato della 80.2). Icone ▶ e Shuffle in alto.
- Test: rapporto 2:1; semi presi dai brani del genere; righe skeleton poi riempite; senza rete solo libreria.

### 80.4 — Controlli di fase
`flutter analyze`; comando mirato; golden `search` rigenerato e `genre` nuovo; build lite (`--dart-define=CODECORE_YOUTUBE=false`) che compila senza Cerca; code-review high (Shuffle+); scheggia. Sul Mi A3: Cerca, un genere con suggeriti che arrivano, Radio → Cerca con prefill.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
