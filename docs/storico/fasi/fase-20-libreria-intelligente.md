# Fase 20 — Libreria intelligente: cronologia, statistiche, regole, playlist intelligenti, etichette

**Obiettivo:** sapere **cosa** si è ascoltato e **quando** (cronologia per evento), vederlo in un **recap**
mensile/annuale, cercare con **operatori** («artista:», «anno:1990..1999»…), creare **playlist intelligenti** che si
aggiornano da sole e assegnare **etichette** proprie ai brani.
**Prerequisiti:** Fase 11 (Home, Cerca, Libreria), Fase 19 (selezione multipla, per le etichette in massa).
**Principio:** un **solo** linguaggio di regole: lo stesso parser e lo stesso traduttore in SQL servono la ricerca
con operatori e le playlist intelligenti. Tutto resta sul dispositivo: nessun invio di dati, nessuno scrobbling.

## Decisioni
| Tema | Scelta |
|---|---|
| Schema | **v7** (dopo la v6 della Fase 17). Se una fase precedente con schema non è stata fatta, usa la prossima versione libera e adatta il test di migrazione |
| Tabelle nuove | `plays`, `smart_playlists`, `user_tags`, `track_tags` (vedi 20.1) |
| Quando è un ascolto | Stessa soglia di oggi (`_onPosition` di `CodecoreAudioHandler`: metà brano o 30 s). La riga `plays` nasce lì; `ms_played` si aggiorna al cambio brano/stop |
| Storico precedente | `playCount`/`lastPlayedAt` restano (Home li usa); la cronologia parte da zero (non si inventano eventi) |
| Linguaggio | `campo:valore`, `campo:a..b`, `campo>x`/`<x`, parole libere (titolo/artista/album come oggi), `-` per negare, `OR` maiuscolo tra due termini; parole chiave `preferiti`, `mai-ascoltati` |
| Campi | `artista`, `album`, `anno`, `genere`, `tag`, `durata`, `aggiunto` (giorni: `aggiunto<30g`), `ascolti`, `formato`, `cartella`; alias inglesi (`artist`, `year`, …) |
| SQL | AST → `WHERE` con soli `Variable` (mai concatenare testo dell'utente), `LIKE … ESCAPE '\'` come `TrackRepository._escapeLike` |
| Playlist intelligenti | Regole salvate come testo nel linguaggio (+ ordinamento e limite opzionali), elenco calcolato dal vivo con `watch()`; non hanno righe in `playlist_tracks` |
| Grafici | Disegnati a mano (`CustomPaint`/barre con `Container`), colori dai token. Nessun pacchetto |
| Pacchetti nuovi | Nessuno |

## Task

### 20.1 — Tabelle (schema v7)
**File:** `lib/data/db/tables.dart`, `lib/data/db/app_database.dart` (+ `build_runner`), `test/data/migration_test.dart`
```dart
@TableIndex(name: 'plays_track', columns: {#trackId})
@TableIndex(name: 'plays_at', columns: {#playedAt})
class Plays extends Table {
  IntColumn id (autoIncrement); IntColumn trackId (references Tracks, cascade);
  IntColumn playedAt;            // epoch ms dell'inizio
  IntColumn msPlayed (default 0);
  IntColumn context (nullable);  // PlayContextKind.index
  TextColumn contextName (nullable);
}
class SmartPlaylists extends Table {
  IntColumn id (autoIncrement); TextColumn name; TextColumn rules;   // testo del linguaggio
  TextColumn sort (nullable); IntColumn limitCount (nullable); IntColumn createdAt;
}
class UserTags extends Table { IntColumn id (autoIncrement); TextColumn name (unique, nocase); IntColumn color (nullable); }
class TrackTags extends Table {
  IntColumn trackId (references Tracks, cascade); IntColumn tagId (references UserTags, cascade);
  primaryKey {trackId, tagId}
}
```
Migrazione `if (from < 7)`: `createTable` × 4 + indici. Nessun dato esistente toccato.
**Test:** migrazione v6 → v7 (dati intatti, tabelle vuote presenti), cascade alla cancellazione di un brano.

### 20.2 — Registrare gli ascolti
**File:** `lib/services/audio/codecore_audio_handler.dart`, `lib/data/repositories/play_history_repository.dart`,
`lib/main.dart` (provider), `test/services/audio/codecore_audio_handler_test.dart`, `test/data/play_history_test.dart`
1. `PlayHistoryRepository.start(trackId, at, context) → int playId` e `finish(playId, msPlayed)`.
2. Dove oggi `_onPosition` chiama `_tracks.registerPlay`, chiamare anche `start` (stesso `catchError` con `AppLog.w`).
   Il contesto arriva dall'handler: aggiungere un `PlayContext? context` impostato dal `PlayerController` insieme a
   `onContext` (oggi solo in memoria in `playContextProvider`).
3. `finish` al cambio brano, stop, fine coda e `dispose`: `msPlayed` = tempo di riproduzione effettivo (somma degli
   intervalli in `playing`, non la posizione: i seek non contano).
4. La Jam **non** registra ascolti (usa il proprio `AudioBackend`, non l'handler): annotarlo.
**Test:** con backend finto: 40 s di play → una riga con `msPlayed` ≈ 40 000; seek avanti non gonfia il tempo;
brano saltato a 10 s → nessuna riga.

### 20.3 — Cronologia
**File:** `lib/ui/screens/history/history_screen.dart`, `play_history_repository.dart`, Libreria (voce «Cronologia»), ARB
1. `watchHistory({int limit, int? beforePlayedAt})` con join su `tracks`, paginazione a blocchi da 200.
2. Lista raggruppata per giorno («Oggi», «Ieri», data), riga = `TrackRow` + ora; `ListView.builder` con intestazioni
   come elementi a altezza fissa.
3. Azioni: menu del brano; «Cancella cronologia» (conferma) — cancella **solo** `plays`, non `playCount`.
4. Impostazione «Registra la cronologia di ascolto» (default **on**, solo locale); spenta → nessuna riga nuova.
**Verifica:** widget test con 3 giorni di dati finti; test del repository (paginazione, cancellazione).

### 20.4 — Statistiche e recap
**File:** `lib/data/repositories/stats_queries.dart`, `lib/ui/screens/stats/stats_screen.dart`,
`lib/ui/screens/stats/stats_charts.dart`, ARB, `test/data/stats_queries_test.dart`
1. Query aggregate (SQL, `GROUP BY`): minuti totali, brani distinti, top 10 brani/artisti/album, minuti per giorno
   del mese o per mese dell'anno, ora del giorno preferita, primo ascolto del periodo. Periodo = mese o anno.
2. Artista e album raggruppati con `albumKey` e `artistKey` come in `library_queries.dart` (non per nome grezzo).
3. Schermata con selettore Mese/Anno e frecce ‹ ›; barre disegnate a mano; nessun dato → stato vuoto.
4. Home: scheda «Il tuo mese» solo se ci sono ≥ 10 ascolti nel mese corrente.
**Test:** dati sintetici su due mesi: totali, top, confini del mese (fuso locale), artisti con accenti diversi uniti.

### 20.5 — Linguaggio delle regole: parser e AST (logica pura)
**File:** `lib/services/library/rules/rule_parser.dart`, `rule_ast.dart`, `test/services/library/rule_parser_test.dart`
1. `RuleExpr parseRules(String text)`: tokenizer con virgolette (`artista:"pink floyd"`), negazione `-`, `OR`,
   intervalli `a..b`, confronti `> < >= <=`, unità di durata (`s`, `m`) e di tempo (`g`, `sett`, `mesi`).
2. Errori non bloccanti: un termine non valido diventa testo libero e il parser restituisce `warnings`
   (la UI li mostra sotto la casella, la ricerca non si rompe mai mentre si digita).
3. `String formatRules(RuleExpr e)` (inverso, per salvare regole canoniche).
**Test:** ≥ 20 casi: ogni campo, alias inglesi, virgolette, negazione, OR, intervalli aperti (`anno:..1980`), unità,
termine invalido → warning, giro `parse → format → parse` identico.

### 20.6 — Dalle regole all'SQL
**File:** `lib/services/library/rules/rule_sql.dart`, `lib/data/repositories/track_repository.dart`,
`test/services/library/rule_sql_test.dart`
1. `({String where, List<Variable> vars}) toSql(RuleExpr e, {required int nowMs})`; testo libero = stessa logica di
   `watchTracks` (title/artist/album `LIKE`). `tag:` → `EXISTS (SELECT 1 FROM track_tags …)`; `mai-ascoltati` →
   `play_count = 0`; `aggiunto<30g` → `added_at > ?`.
2. Sempre `missing = 0` (e, dopo la Fase 21, `ignored = 0`).
3. `TrackRepository.watchByRules(RuleExpr e, {SortOption sort, int? limit})` con `customSelect(...).watch()` e
   `readsFrom: {tracks, trackTags}`.
**Test:** DB in memoria con 30 brani: ogni operatore restituisce gli id attesi; un valore con `%`, `_`, `'` non
rompe la query (nessuna iniezione).

### 20.7 — Ricerca con operatori
**File:** `lib/data/repositories/library_search.dart`, `lib/ui/screens/search/search_screen.dart`, ARB
1. Se il testo contiene almeno un operatore, la sezione brani usa `watchByRules`; artisti/album/playlist si filtrano
   solo sul testo libero (come oggi). Senza operatori nulla cambia (stessi test di `library_search_test.dart`).
2. Suggerimenti sotto la casella: chip «artista:», «anno:», «genere:», «tag:», «preferiti»; avvisi del parser.
3. Debounce 250 ms come oggi; nessun filtro in memoria sui brani.
**Verifica:** test di `searchLibrary` con e senza operatori; widget test: digitare `anno:1990..1999` mostra solo
brani di quegli anni.

### 20.8 — Playlist intelligenti
**File:** `lib/data/repositories/smart_playlist_repository.dart`, `lib/ui/screens/playlists/smart_playlist_editor.dart`,
`playlists_screen.dart`, `playlist_detail_screen.dart`, `library_screen.dart`, ARB (+ test repository)
1. CRUD su `smart_playlists`; `watchTracks(id)` = `watchByRules` con ordinamento e limite salvati.
2. Editor: nome, casella regole con anteprima dal vivo («37 brani»), ordinamento (incluso «a caso», stabile per
   sessione), limite. Modelli pronti: «Mai ascoltati», «Aggiunti di recente», «I più ascoltati», «Anni '90».
3. Nella Libreria compaiono accanto alle playlist con un'icona diversa; pagina = `CollectionScaffold` in sola lettura
   (niente riordino né «Aggiungi brani»), con «Converti in playlist normale» (copia l'elenco attuale).
4. Riproduzione: snapshot dell'elenco al momento del tocco (la coda resta separata, regola 6).
**Test:** repository; regole che cambiano risultato quando un brano diventa preferito (stream si aggiorna).

### 20.9 — Etichette utente
**File:** `lib/data/repositories/tag_repository.dart`, `lib/ui/screens/tags/tags_sheet.dart`, `track_actions.dart`,
`lib/ui/widgets/bulk_actions.dart` (Fase 19), Libreria, ARB (+ test)
1. Crea/rinomina/elimina etichetta (eliminare toglie solo le associazioni); colore opzionale da 8 token.
2. Menu del brano → «Etichette…» (foglio con caselle); barra di selezione → «Aggiungi etichetta» / «Togli etichetta».
3. Libreria: sezione «Etichette» con conteggi; tocco = elenco dei brani (`tag:<nome>`).
4. Le etichette sono dati utente: non si cancellano mai automaticamente (regola 6).
**Test:** assegnazione in massa in una transazione, rinomina che non rompe le regole salvate (le regole citano il
nome: alla rinomina si aggiornano anche le `smart_playlists` che lo usano).

### 20.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es/fr/pt per tutte le stringhe nuove; guida al linguaggio (foglio «?» accanto alla casella di ricerca).
2. Prestazioni: 20 000 brani + 100 000 righe `plays` sintetiche → recap annuale < 300 ms, ricerca con operatori
   < 80 ms (estendere `test/data/performance_test.dart`).
3. `docs/02-architettura.md` (cartella `services/library/rules`), `docs/03-modello-dati.md` (schema v7),
   `docs/99-rischi-e-fallback.md` (R46–R48), README.
**Tocca a te (telefono + Linux):** una settimana d'uso normale → cronologia e recap sensati; tre playlist
intelligenti; ricerca `artista:"…" -live anno:2000..`; etichette in massa da selezione.

## Fuori da questa fase
Scrobbling e invii a servizi esterni (esclusi), recap condivisibile come immagine, regole annidate con parentesi
(solo `OR` tra due termini), statistiche della Jam.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R46 | `plays` cresce senza limite (anni di ascolti) | Indici su `played_at`/`track_id`; query aggregate in SQL; «Cancella cronologia»; il backup (Fase 13) la include |
| R47 | Regole tradotte male in SQL o testo dell'utente iniettato | Solo `Variable`, test con caratteri speciali, parser che non lancia mai durante la digitazione |
| R48 | Playlist intelligenti lente con molte regole su librerie grandi | `watch` con `readsFrom` minimi, limite opzionale, misura su 20 000 brani in 20.10 |

## Definition of Done
- [ ] Ogni ascolto valido crea una riga `plays` con tempo effettivo; cronologia per giorno; recap mese/anno
- [ ] Un solo linguaggio di regole usato da ricerca e playlist intelligenti, con test di parser e SQL
- [ ] Playlist intelligenti che si aggiornano da sole; etichette assegnabili anche in massa
- [ ] Migrazione v7 testata; `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
