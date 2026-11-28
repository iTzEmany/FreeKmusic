# Fase 168 — Dopo un video karaoke la coda si riempie solo di karaoke

## Obiettivo
Quando il brano scelto dalla Ricerca, dal filtro Karaoke, da un link o da Shazam è un video karaoke (D-634), i brani aggiunti in automatico
sono le versioni karaoke dei brani simili alla **canzone originale**; un simile senza karaoke corrispondente è scartato; se l'originale non si
trova suona solo il brano scelto. I brani non karaoke si comportano come oggi.
Fuori: karaoke avviati da cronologia, playlist o coda (nessuna sessione, come oggi); Jam (D-89).

## Riferimenti
Refactor `../refactor/karaoke-casuale/analisi.md` (F-01..F-08, «Scelte», «Direzione», «Rete»). Decisioni D-765..D-771 (refactor «karaoke-casuale») in
`../decisioni.md`: coda solo karaoke, ritmo delle ricerche, struttura, intoccabili. Architettura: `../architettura/riproduzione-e-coda.md`.
Prerequisito: fase 167. Indipendente dalla 169.
Codice: `playFromSearch` (`player_providers.dart:491-549`, seme a :511-513, `SimilarQueue` a :522), `_similarId` (:553);
`SimilarQueue` (`similar_queue.dart`: `start` :67-80, `_take` :139-181, catch :178-181); `RadioFill.take` (`radio_fill.dart:43-74`, `accept`
sincrono, non adatto alla ricerca); `similarFill` (`shuffle_plus_providers.dart:337-365`); `karaokeResults` (`karaoke_filter.dart:17-31`);
ricerca karaoke di oggi (`online_results.dart:241-250`, `smart_search.dart:125-126, 285, 297, 318`); `karaokeLyricsQuery` (`query_cleaner.dart:199`);
`SeedResolver.resolve` (`seed_resolver.dart:23-47`), `decide()` (`track_matcher.dart`); `SourceCooldown` (`source_cooldown.dart`).

## Task
- [x] 168.1 Una sola regola «è karaoke» sul titolo
  - File: `lib/services/online/karaoke_filter.dart` (o `karaoke_video.dart`) con il predicato, `karaoke_video.dart` (`isKaraokeVideo`,
    `jamKaraokeVideoId`), `karaoke_filter.dart` (regex di :4), test del predicato.
  - Passi: 1) un predicato sul titolo che riproduce l'esito della tabella della 167.1 (se le tre regole di oggi differiscono su un titolo,
    tenere quella di `isKaraokeVideo` e scriverlo nelle note di deviazione); 2) le tre copie lo usano.
  - Comando mirato: `flutter test test/services/online test/services/karaoke_video`
  - Fatto quando: `grep -rn "contains('karaoke')" lib/` dà un solo risultato; i test della 167.1 verdi senza modifiche.
- [x] 168.2 Sostituzione facoltativa nella sessione dei simili (non ancora collegata)
  - File: `similar_queue.dart`, nuovo `test/services/shuffle_plus/similar_queue_swap_test.dart`, `test/providers/play_from_search_test.dart`
    (`sessionFor` :113-120 con `swap` facoltativo).
  - Passi: 1) parametro `Future<YtResult?> Function(YtResult)? swap`; in `_take` la sostituzione avviene prima di `_seen`, `fill.filter.allows`,
    `register` e `onSuggested`; null = scartato; `pool.positionsOf` resta sull'originale; 2) con `swap`: primo gruppo da 3, tetto di chiamate a
    `swap` per gruppo = 2 × brani del gruppo; 3) un `YtException` 429 da `swap` → `SourceCooldown.trip` (fonte video) e `fill.gate.trip()`,
    sessione chiusa come gli altri 429; altri errori di `swap` loggati con `AppLog` e il brano scartato; 4) test: sostituzione, scarto, id
    sostituito ovunque a valle, gruppo da 3, tetto, 429, `swap == null` identico a oggi.
  - Comando mirato: `flutter test test/services/shuffle_plus test/providers/play_from_search_test.dart`
  - Fatto quando: test nuovi verdi; i test della 167.1 verdi senza modifiche.
- [x] 168.3 Karaoke collegato in `playFromSearch`
  - File: `player_providers.dart` (`PlayerController`: due funzioni iniettate, es. `karaokeOriginal: Future<RadioSeed?> Function(YtResult)` e
    `karaokeSwap: Future<YtResult?> Function(YtResult)`), `shuffle_plus_providers.dart` (implementazioni accanto a `similarFill`), il provider
    che costruisce `PlayerController`, `test/providers/play_from_search_test.dart`.
  - Passi: 1) brano online karaoke (predicato della 168.1 sul titolo, stessa fonte YouTube di `isKaraokeVideo`): `karaokeOriginal` pulisce con
    `karaokeLyricsQuery(title, channel)`, cerca la canzone su YouTube Music e la accetta con `decide()`; null → nessuna sessione, `_setSimilar(null)`,
    ritorna `false`; altrimenti seme = l'originale e `SimilarQueue` con `swap: karaokeSwap`; 2) `karaokeSwap`: ricerca intelligente `videoOnly`
    «artista titolo karaoke» (cache di 10 min), `karaokeResults`, primo risultato che `decide()` accetta contro titolo e artista del simile,
    altrimenti null; 3) brano non karaoke: tutto come oggi, `karaokeSwap` mai chiamato; 4) test dei tre casi (karaoke con coda di karaoke
    corrispondenti, originale non trovato → `false`, non karaoke).
  - Comando mirato: `flutter test test/services/shuffle_plus test/providers/play_from_search_test.dart test/services/online test/services/karaoke_video`
  - Fatto quando: i tre casi coperti da test verdi; `flutter analyze` pulito; sezione «Shuffle+ e simili» di
    `../architettura/riproduzione-e-coda.md` aggiornata (sessione karaoke, ritmo delle ricerche).

## Tocca a te
Niente. A fine fase la prova sul telefono la fa l'agente via `~/.claude/scripts/device.sh`, a volume 0: dal filtro Karaoke avviare un karaoke noto (es. «Sing King - Adele - Hello (Karaoke Version)») e controllare che la coda si riempia di karaoke di canzoni simili.

## Note di deviazione

- **168.1** `isKaraokeTitle(String)` in `karaoke_filter.dart` (parola «karaoke», maiuscole ignorate), usata da `isKaraokeVideo`, `jamKaraokeVideoId`, `karaokeResults` (che tiene le sue esclusioni «reaction», «cover», «live») e dalla query di `online_results.dart`. Nessun esito cambiato rispetto alla tabella della 167.1.
- **168.2** Parametri nuovi di `SimilarQueue`: `swap`, `cooldown` (per far scattare la pausa della fonte video su un 429), `swapTimeout` (45 s). Con `swap` il gruppo chiede al massimo il doppio dei brani e si ferma a quelli voluti. Primo gruppo da 3 solo all'avvio. Un 429 nei gruppi successivi mette in pausa la fonte senza chiudere la sessione (come gli altri 429). Dalla review e dalla scheggia: niente doppioni dopo la sostituzione (seme, già visti, suggeriti di recente); pausa anche dopo un gruppo corto o un errore della sostituzione; timeout.
- **168.3** `karaoke_session.dart` (`karaokeOriginalSeed`, `karaokeVideoFor`) con ricerca iniettata; `decide()` accettato solo con esito sicuro, l'artista viene dal titolo del karaoke (un karaoke con lo stesso titolo e un altro artista è scartato). Le ricerche karaoke non interrompono il motore, così finiscono nella cache di 10 minuti; effetto: partono anche le righe artista e album della ricerca. Un brano normale con «karaoke» nel titolo (es. «Karaoke» di Drake) prende la strada karaoke e, senza originale, suona da solo (come deciso, D-765).
