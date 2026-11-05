# Fase 94 — Playlist intelligenti: editor a filtri (refactor «superfici-e-ricerca»)

**Obiettivo:** nodo «uno tra», campi nuovi nel linguaggio delle regole ed editor visuale a filtri che scrive la stessa stringa canonica; le playlist esistenti restano identiche.

**Prerequisiti:** fase 93 chiusa (generi multipli, nazionalità, BPM/etichetta). Mockup `refactor/superfici-e-ricerca/mockup/playlist-intelligente.html`. Decisioni D-390, D-393, D-394, D-397, D-412. Rilievi F-91, F-92, F-93. Area a rischio: `lib/services/library/rules/` (parser, AST, SQL).

**Comando mirato:** `flutter test test/services/library/rule_parser_test.dart test/services/library/rule_sql_test.dart test/services/library/rule_rewrite_test.dart test/services/library/rule_corpus_test.dart test/data/smart_playlist_test.dart test/data/smart_search_test.dart test/ui/smart_playlists_test.dart test/ui/search_operators_test.dart` più i test nuovi.

## Task

### 94.1 — Nodo «uno tra» (F-92, D-393)
- `RuleIn(campo, valori)` in `lib/services/library/rules/rule_ast.dart`: confronto esatto (normalizzato) contro i valori scelti da elenco. Sintassi `artista:"A","B"`.
- Parser (`rule_parser.dart`) e `toSql` (`rule_sql.dart:18`) retrocompatibili: `artista:Queen` resta sottostringa (LIKE) e trova ancora «Queens of the Stone Age». `formatRules` idempotente.
- Test: il corpus della 87 (`rule_corpus_test.dart`) dà gli stessi id e `formatRules(parseRules(s)) == s`; nuovi: virgolette con virgole e accenti nei valori, `RuleIn` + `NOT`, `RuleIn` con un solo valore, valore vuoto → errore di parsing chiaro.

### 94.2 — Campi nuovi (F-93, D-412)
- `ultimoascolto`, `artistaalbum`, `nazionalita`, `etichetta`, `bpm`, `bitrate`, `con-testo`; `genere` considera tutti i generi della 93; «Mai ascoltati» (nessun ascolto). Date nel formato di oggi (`-Nd`/`>Nd`).
- Nuovi campi su colonne/tabelle esistenti (`lastPlayedAt`, `albumArtist`, `bitrateKbps`, `lyricsPlain/Synced`) e dati della 93, con join/`EXISTS` e indici dove serve. La ricerca (`hasOperators`, `rule_parser.dart:230`) li capisce senza regressioni.
- Test: una regola per campo su un DB fisso con risultati attesi; brano senza dato escluso; sort e limite invariati.

### 94.3 — Editor visuale (F-91, D-393, D-394, D-412)
- Sostituisce il TextField (`smart_playlist_editor.dart:186-195`) e i modelli (`:37-52`). Tutte/Almeno una in cima; filtri come schede con valori multipli da elenco (ricerca e conteggi), Includi/Escludi; «Aggiungi filtro» per gruppi (Musica, Ascolto, File, Tag); numeri da…a; date «Negli ultimi N giorni»/«Da più di N giorni».
- Conteggio dal vivo fisso in fondo con Ordina per e Limite; «Salva» con nome e almeno un filtro completo; «Avanzate» mostra il testo in sola lettura.
- Le playlist esistenti si aprono compilate. Regola non rappresentabile (es. OR annidati): l'editor lo dice e la mostra in Avanzate senza perderla né riscriverla.
- Test (widget): creare, modificare, aprire una playlist esistente → stessa stringa dopo «Salva» senza modifiche; regola non rappresentabile conservata; «Salva» disabilitato senza filtro completo; Semantics e bersagli ≥ 48 dp (`a11y_guidelines_test.dart`, `talkback_labels_test.dart`). ARB it/en/de/es.

### 94.4 — Conteggi per valore
- Conteggio per ogni valore degli elenchi (artisti, generi, nazioni, etichette) e conteggio dal vivo con debounce, calcolati con query SQL aggregate fuori dal thread UI, annullabili. Test: conteggi su DB fisso; una query più nuova annulla la precedente.

### 94.5 — Controlli di fase
`flutter analyze`; comando mirato; golden dell'editor rigenerati (`scripts/shots.sh`); code-review high sulle regole (`lib/services/library/rules/`); scheggia. Motorola edge 40 (ZY22HKD85K) e Mi A3 (0d7ae9df206e) via adb: aprire una playlist intelligente esistente (stessi brani di prima), crearne una con più artisti, conteggio dal vivo senza scatti.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
