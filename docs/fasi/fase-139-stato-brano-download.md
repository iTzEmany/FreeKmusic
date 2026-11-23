# Fase 139 — Stato vivo del brano e download

## Obiettivo
Menu ⋮ e player sanno sempre se un brano è online, salvato in streaming o scaricato, e si aggiornano da soli (anche quando il download cambia l'id). Un solo `DownloadBar` mostra l'avanzamento ovunque; scaricare salva anche in libreria (nessun «scaricato non salvato»); nelle pagine online il pulsante è «Aggiungi alla libreria» e «Aggiungi alla playlist» passa nel menu ⋮. Fuori: default `stream`, import con «scarica anche», album completo (tutti fase 140).

## Riferimenti
D-695, D-696, D-697, D-665 (contesto), D-662, D-699. Rilievi F-16, F-17, F-21, F-23 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); `scansione-streaming.md` (menu ⋮, download, incongruenze), `scansione-ui.md` (punto 13); rete.md riga 139. Mockup: `mockup/player-download.html` in `../refactor/grande-revisione/mockup/`. Aree: `../architettura/online.md`, `ui-e-design.md`, `libreria-e-dati.md`. **Area a rischio** (query su `tracks`, righe ombra, promozione/demozione): review `/code-review high`.

## Task
- [x] 139.1 Test di caratterizzazione (rete.md, riga 139)
  - File: `test/ui/track_actions_test.dart`, `test/services/online/download_index_test.dart`, `test/providers/download_promotion_test.dart`, `test/services/stream/stream_promoter_test.dart` (id tenuto o nuovo dopo il download), golden `desktop_100_now_playing*.png` come base.
  - Passi: 1) fissare il comportamento di oggi: voci del menu per brano locale, online non salvato, salvato, scaricato; id dopo il download (in cache/non in cache); 2) verdi; 3) commit di soli test.
  - Comando mirato: `flutter test test/ui/track_actions_test.dart test/services/online/download_index_test.dart test/providers/download_promotion_test.dart test/services/stream/stream_promoter_test.dart`
  - Fatto quando: verdi senza modifiche a `lib/`; commit separato.
- [x] 139.2 `trackStateProvider` (F-16; D-695)
  - File: `lib/providers/track_state_providers.dart` (nuovo: stato `online | savedStream | downloaded` per brano, derivato da riga in DB, `savedStreamKeysProvider`, `downloadIndexProvider`, `onlineEntries.bound`), `lib/providers/player_providers.dart` (~1025-1040, `liveCurrentTrackProvider` tiene l'id negativo dopo il download), `lib/data/repositories/track_kinds.dart` (`libraryRowSql`), `test/providers/track_state_test.dart` (nuovo).
  - Passi: 1) il provider legge la riga reale (kind 0 = scaricato/locale, kind 2 con `saved=1` = salvato in streaming, altrimenti online) e osserva download e `bound`; 2) `liveCurrentTrackProvider` usa l'id nuovo dopo il download (la riga viene sostituita o promossa); 3) test: transizioni online → salvato → scaricato → libera spazio (`demoteToStream`) → salvato.
  - Comando mirato: `flutter test test/providers/track_state_test.dart test/providers/download_promotion_test.dart test/providers/play_online_test.dart`
  - Fatto quando: il test delle transizioni passa; nessuna regressione nei test di 139.1.
- [x] 139.3 Menu ⋮ vivo e completo (F-16, F-23; D-695, D-696)
  - File: `lib/ui/widgets/track_actions.dart` (~264-290 riga ombra, ~409-439 `showTrackActions` cattura il `Track` una volta, ~426-428), `lib/providers/library_add_providers.dart`, `lib/providers/youtube_providers.dart` (`DownloadsNotifier.add`, ~281), ARB ×6.
  - Passi: 1) il menu osserva `trackStateProvider` e si ricostruisce; 2) brano salvato in streaming: voci complete come un brano locale (preferito, playlist, etichette, vai a, modifica) più «Scarica» o «Libera spazio» secondo lo stato (D-696); 3) riga ombra: mai «Aggiungi alla libreria» e «Scarica» insieme; «Scarica» salva (D-695); 4) il download tiene sempre l'id coerente (non solo se in cache); 5) test di widget del menu per ogni stato.
  - Comando mirato: `flutter test test/ui/track_actions_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: a download finito il menu passa da solo a quello del brano scaricato (test); nessuna riga ombra mostra azioni in conflitto.
- [x] 139.4 `DownloadBar` condiviso (F-17; D-697; mockup `player-download.html`)
  - File: `lib/ui/widgets/download_bar.dart` (nuovo), `lib/ui/screens/now_playing/suggested_info.dart` (~16-113, oggi non osserva `downloadsProvider`), `lib/ui/screens/online/online_song_row.dart` (~125-140, ~325-350), `lib/ui/widgets/track_actions.dart` (~286), `lib/providers/youtube_providers.dart` (`downloadsProvider`), ARB ×6.
  - Passi: 1) widget unico: avanzamento → riga «Scaricato» che sparisce dopo qualche secondo (D-697); 2) sostituisce le tre implementazioni; 3) i pulsanti Scarica/«Aggiungi alla libreria» lasciano il posto alla barra mentre si scarica; 4) test di widget e golden `track_actions`, `now_playing`.
  - Comando mirato: `flutter test test/ui/suggested_info_test.dart test/ui/online_song_row_test.dart test/ui/track_actions_test.dart test/ui/now_playing_test.dart test/ui/architecture_test.dart`
  - Fatto quando: `grep -rn downloadsProvider lib/ui` mostra un solo widget (metrica di rete.md); golden rivisti.
- [x] 139.5 «Aggiungi alla libreria» nelle pagine online (F-21; mockup `player-download.html`)
  - File: `lib/ui/screens/now_playing/suggested_info.dart`, `lib/ui/screens/online/online_song_row.dart`, `lib/ui/widgets/track_actions.dart`, ARB ×6.
  - Passi: 1) il pulsante in vista diventa «Aggiungi alla libreria» (salva senza scaricare, `LibraryAdder`); 2) «Aggiungi alla playlist» resta nel menu ⋮; 3) test di widget.
  - Comando mirato: `flutter test test/ui/suggested_info_test.dart test/ui/online_song_row_test.dart test/ui/architecture_test.dart`
  - Fatto quando: nelle due viste il pulsante è «Aggiungi alla libreria» e il menu ⋮ contiene «Aggiungi alla playlist».
- [x] 139.6 Area e controllo di fine fase
  - Aggiorna `../architettura/online.md` (stato del brano, `DownloadBar`, scaricare = salvare), `ui-e-design.md` (`DownloadBar`), `libreria-e-dati.md` (id dopo il download); «Trappole»: il menu non cattura più il `Track`. Verifica `scripts/guardie.sh` (golden).

## Tocca a te
- Nessuna cosa in questa fase: la prova della barra di download sul Motorola è nella 147.

## Note di deviazione
- 139.2: non usa `onlineEntries.bound` né `libraryRowSql`. `liveCurrentTrackProvider` resta con l'id negativo dopo il download (con l'id vero la review ha mostrato incoerenze: `SuggestedInfo`/`DownloadBar` spariscono, l'equalizzatore sparisce dal menu ⋮, «Elimina dal dispositivo» non toglie il brano dalla coda). Lo stato del brano corrente si legge con la chiave del flusso (`trackStateKey` ricava `source:id` dal path `online:` del brano sintetico). «Libera spazio» ed «Elimina dal dispositivo» invalidano `downloadIndexProvider`.
- 139.4: `downloadsProvider` resta osservato anche in `online_song_row.dart`, `online_results_sections.dart`, `genre_screen.dart` e `suggestions_screen.dart`, per trovare l'`item` (stati «fallito» e «scaricato» della riga), non per disegnare una barra; la barra è una sola (`DownloadBar`). Nel player `SuggestedInfo` tiene montata la barra anche quando il brano è già in libreria, finché la barra mostra «Scaricato».
- 139.3: «Scarica» salva prima di scaricare anche in modalità dispositivo (D-695); un download annullato lascia il brano salvato in streaming. Per un brano online (id negativo) il menu non passa alla riga della libreria. «Libera spazio» dal menu chiede conferma e non c'è per il brano in riproduzione né per un file la cui firma non corrisponde.
