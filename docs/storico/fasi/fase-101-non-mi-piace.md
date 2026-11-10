# Fase 101 — «Non mi piace» brano o artista, e player del suggerito

**Obiettivo:** chiedere se non piace il brano o l'artista, conservarlo per sempre (anche nel backup), applicarlo a ogni fonte di suggeriti, e sistemare il player di un suggerito. **Cambi di comportamento voluti** (D-436..D-438, D-445, D-446).

**Prerequisiti:** fase 100 chiusa. Analisi F-112, F-113, F-114 e «Arrivo». Mockup approvati: `refactor/ascolto-quotidiano/mockup/non-mi-piace.html`, `refactor/ascolto-quotidiano/mockup/player-suggerito.html`. Aree a rischio: backup (`/code-review high`).

**Comando mirato:** `flutter test test/services/shuffle_plus/ test/providers/suggestion_actions_test.dart test/services/backup/ test/ui/dislike_sheet_test.dart`

## Task

### 101.1 — `DislikeStore` (F-113, D-438)
- File JSON a parte (accanto a `suggestions.json`) con due insiemi: brani (videoId, più titolo e artista per la pagina) e artisti (`artistKey`, più il nome mostrato). Nessun taglio. Al primo avvio i «non mi piace» presenti in `SuggestionLog` vi passano una volta sola. `SuggestionLog.clear` non lo tocca.
- Nel backup come file nuovo (aggiunta: un backup vecchio senza il file si ripristina come oggi, test della 98.4).
- Test `test/services/shuffle_plus/dislike_store_test.dart` (migrazione una volta sola, nessun taglio, backup).

### 101.2 — `SuggestionGate`: un solo filtro (F-114, D-437)
- Usato da `SuggestionPool` e quindi da Shuffle+, mix di genere, `RadioFill` (Cerca), daylist; anche il Play/Shuffle dell'artista (100.3) scarta i brani bloccati e non apre la pagina di un artista bloccato ai suggeriti (la sua pagina resta visitabile).
- Regole: artista bloccato → mai. Brano bloccato → ammesso solo se compare nella radio di almeno 2 brani della coda attuale entro le prime 10 posizioni (`RadioFill` passa le posizioni per seme).
- Nota: il gate si aggancia in `SuggestionPool` (`_takeKind`, dove oggi c'è `log.disliked`), così valgono insieme Shuffle+, mix di genere e `RadioFill`; non toccare i tre giri di fetch. La regola dei 2 semi entro le prime 10 posizioni vuole la posizione della riga nella pagina radio, che `SuggestionPool.addPage` oggi perde: aggiungerla a `RadioItem`/pool in questa fase.
- Test `test/services/shuffle_plus/suggestion_gate_test.dart`: artista mai; brano con 1 seme no, 2 semi in posizione 11 no, 2 semi in posizione 10 sì.

### 101.3 — Foglio «Non ti piace il brano o l'artista?» (D-436, D-446)
- Dal menu del brano suggerito (`track_actions.dart:142-146`), dal menu ⋮ del player e dal pulsante del player (101.5). Due scelte + Annulla, testi come nel mockup. Se è il brano in riproduzione si passa al successivo; avviso di 4 s con Annulla che toglie il blocco e fa ripartire il brano.
- Widget test `test/ui/dislike_sheet_test.dart`: le due scelte portano a due azioni diverse; Annulla toglie il blocco e riavvia il brano.

### 101.4 — Impostazioni → «Non mi piace» (D-438)
- Pagina con schede Brani / Artisti, righe con «Togli» (con Annulla), stato vuoto, come nel mockup. Etichette TalkBack.

### 101.5 — Player di un suggerito (F-112, D-445)
- `suggested_info.dart`: intestazione «Suggerito · simile a …» centrata con lo stesso margine `npEdge` del titolo; tre pulsanti uguali (Scarica, Aggiungi a playlist, Non mi piace) come nel mockup; per un brano online non suggerito restano solo i due pulsanti, sempre centrati.

### 101.6 — Controlli di fase
`flutter analyze`; comando mirato; metrica `grep -rln "disliked(" lib` → solo `SuggestionGate` e `DislikeStore`; review (`/code-review high` sul backup); scheggia passo e fase; prova sul Mi A3 contro i mockup (player di un suggerito, foglio, Annulla, pagina; backup e ripristino con un «non mi piace»). Ripulire il telefono.

**Fatto quando:** artista bloccato mai più proposto da nessuna fonte, brano bloccato solo alla soglia, liste nel backup, player centrato.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-468** (101.2): il blocco vale solo per i suggeriti online; i brani propri restano ascoltabili ovunque. Icona di blocco sull'artista nei risultati online e nella sua pagina.
- **D-469** (101.3): bloccando un artista si tolgono dalla coda i suoi suggeriti (Annulla li rimette); i brani messi dall'utente restano.
- Il mockup `non-mi-piace.html` dice «Annulla non lo fa ripartire»: vale D-446 (Annulla toglie il blocco e fa ripartire il brano); testo del mockup corretto.

## Esiti
- 101.1 (2026-11-09): `DislikeStore` (`lib/services/shuffle_plus/dislike_store.dart`, `dislikes.json`): brani e artisti con la data, mai tagliati, scrittura atomica (`.tmp` + rename), file illeggibile o di forma sbagliata conservato come `.bad`, migrazione una volta sola dai «disliked» di `suggestions.json` avviata all'avvio (`app.dart`). Backup: `dislikes.json` nello zip (flush prima), sostituito dal ripristino completo, unito da «Unisci», un backup vecchio senza il file lascia i blocchi attuali. `artistKey`/`matchKey` spostate in `lib/core/artist_key.dart`.
- 101.2: `SuggestionGate` in `SuggestionPool._takeKind` (Shuffle+, mix di genere, `RadioFill`/`SimilarQueue`) con le posizioni per seme tenute dal pool; ricontrollato prima dell'inserimento in Shuffle+ e in `SimilarQueue`; Play/Shuffle dell'artista filtra per riga. Chiave artista vuota mai bloccata. Metrica `grep -rln "disliked(" lib`: nessun file (il gate usa `allows`, lo store `trackBlocked`/`artistBlocked`).
- 101.3: foglio `lib/ui/widgets/dislike_sheet.dart` dal menu del suggerito, dal ⋮ e dal pulsante del player; avviso subito con Annulla (toglie il blocco solo se prima non c'era, rimette le voci tolte anche se dimenticate e fa ripartire il brano). Segno di blocco sull'artista nei risultati online e nella pagina artista (D-468).
- 101.4: Impostazioni → Riproduzione → «Non mi piace» (`dislikes_screen.dart`). Il pulsante resta «Togli» come nel testo della fase (il mockup dice «Rimuovi»).
- 101.5: `suggested_info.dart` centrato con tre pulsanti uguali (due per un online non suggerito).
- Review: Opus sul backup (7 rilievi, corretti), Sonnet su gate e azioni (6, corretti), pagina (8: corretti testi fr/pt, caricamento, test) e foglio (4, corretti); scheggia di passo: 5 bug piccoli riprodotti e corretti con i test, test rinforzati sui mutanti sopravvissuti.
- 101.6: `flutter analyze` pulito, test mirati verdi. Review di architettura: corsa in `SimilarQueue` corretta, documenti aggiornati, 5 voci di debito in `prossimi-lavori.md`. Prova sul Mi A3: tutti i flussi funzionano (anche senza rete, backup e «Unisci»); aggiunti la data nelle righe e il segno di blocco sulle schede artista. Da sapere: l'artista bloccato prende il nome dal brano (es. «Cat Stevens»), la pagina può chiamarsi diversamente («Yusuf / Cat Stevens»), e lì il segno non compare. Telefono ripulito.

