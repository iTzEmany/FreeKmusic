# Fase 167 — Rete di sicurezza per karaoke e «Casuale su tutto»

## Obiettivo
Fissare con test il comportamento di oggi che le fasi 168 (karaoke) e 169 («Casuale su tutto» mai spento) non devono cambiare.
Nessun codice di prodotto: `lib/` non si tocca.

## Riferimenti
Refactor `../refactor/karaoke-casuale/analisi.md` («Rete», «Direzione»). Decisioni D-765..D-771 (refactor «karaoke-casuale») in `../decisioni.md`
(intoccabili compresi). Architettura: `../architettura/riproduzione-e-coda.md`.
Codice: `playFromSearch` (`lib/providers/player_providers.dart:491-549`), `SimilarQueue` (`lib/services/shuffle_plus/similar_queue.dart:67-181`),
`isKaraokeVideo`/`jamKaraokeVideoId` (`lib/services/karaoke_video/karaoke_video.dart:19-27`), `karaokeResults` (`lib/services/online/karaoke_filter.dart:4-31`),
`karaokeLyricsQuery` (`lib/services/online/query_cleaner.dart:199`), `_cycleList`/`_cycleShuffle`/`toggleShuffle` (`player_providers.dart:620-712`),
`PlaybackPersistence` (`lib/services/**/playback_persistence.dart:64-69, 140-150`).

## Task
- [x] 167.1 Caratterizzazione della sessione dei brani simili e del karaoke
  - File: `test/providers/play_from_search_test.dart`, `test/services/online/karaoke_filter_test.dart`,
    `test/services/karaoke_video/karaoke_video_test.dart`, `test/services/online/query_cleaner_test.dart`.
  - Passi: 1) brano non karaoke dalla Ricerca: id del seme, gruppo, id passati a `_seen`, al filtro «non mi piace» e al registro dei suggeriti;
    2) 429 durante un riempimento → pausa della fonte e fine della sessione (solo se non già fissato); 3) tabella di titoli (maiuscole,
    «Karaoke Version», «karaokes», accenti, «(Instrumental)») con l'esito di oggi di `isKaraokeVideo`, `jamKaraokeVideoId` e del filtro di
    `karaokeResults`; 4) `karaokeLyricsQuery` su «Artista - Brano (Karaoke Version)», titolo senza artista, parentesi quadre.
    Solo ciò che non è già coperto. Tutti verdi sul codice di oggi.
  - Comando mirato: `flutter test test/providers/play_from_search_test.dart test/services/online/karaoke_filter_test.dart test/services/karaoke_video/karaoke_video_test.dart test/services/online/query_cleaner_test.dart`
  - Fatto quando: i test nuovi passano senza toccare `lib/`.
- [x] 167.2 Caratterizzazione del giro del casuale e della coda salvata
  - File: `test/providers/list_shuffle_test.dart`, `test/ui/shuffle_button_test.dart`, `test/services/audio/playback_persistence_test.dart`.
  - Passi: 1) tabella del giro per una lista qualsiasi (non `libraryListKey`): spento → Casuale → Casuale+ → spento; con Casuale+ bloccato
    spento → Casuale → spento; 2) `cycleShuffle` e `toggleShuffle` su una coda non della libreria (pulsante del player intero e barra desktop)
    con gli avvisi di oggi; i test sugli avvisi esistenti (`shuffle_button_test.dart:199-329`) restano intatti; 3) andata e ritorno di
    `lastContextKind`, nome del contesto, id della coda e casuale nelle preferenze.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/services/audio/playback_persistence_test.dart`
  - Fatto quando: i test nuovi passano senza toccare `lib/`.

## Tocca a te
Niente.

## Note di deviazione

- **167.1** Test nuovi in `play_from_search_test` (seme e filtri della sessione online; 429 al primo riempimento), `karaoke_video_test` (tabella dei titoli), `query_cleaner_test` (`karaokeLyricsQuery`); `karaoke_filter_test` già copriva. Le tre regole «è karaoke» differiscono solo su titoli con «reaction(s)», «cover», «live» accanto a «karaoke»: `isKaraokeVideo` e `jamKaraokeVideoId` dicono sì, il filtro di `karaokeResults` scarta. «Karaoké» con l'accento: no per tutte e tre.
- **167.2** Giro del casuale con una chiave che non è né playlist né `libraryListKey` (in riproduzione, non in riproduzione, Casuale+ bloccato, lista online); pulsante del player intero e della barra desktop (stesso widget); andata e ritorno della coda salvata (con il casuale acceso si salva l'ordine mescolato).
- Review saltata: solo test di caratterizzazione, verdi sul codice di oggi; `lib/` non toccata.
