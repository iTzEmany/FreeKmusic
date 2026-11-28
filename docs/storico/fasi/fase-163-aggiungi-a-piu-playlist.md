# Fase 163 — Aggiungi a più playlist

## Obiettivo
Ogni «Aggiungi alla playlist» (Cerca, menu del brano in Libreria, album, selezione multipla, In riproduzione, righe online) mette i brani in
più playlist con un'unica azione; il campo in alto del foglio filtra le playlist e offre «Crea «<testo>»». Il foglio «Nuova playlist» resta com'è.

## Riferimenti
Refactor `../refactor/playlist-aggiungi-e-casuale/analisi.md` (F-03..F-07, «Rete»). Mockup **variante A**:
`../mockups/playlist-aggiungi-e-casuale/variante-a.html` (stati b, c, d e dialogo desktop). Decisioni D-751, D-752, D-753, D-755, D-754 (intoccabili); D-405, D-411 (foglio unico).
Codice: `lib/ui/widgets/playlist_sheet.dart`, `lib/ui/screens/playlists/playlist_picker.dart`, `playlist_dialogs.dart` (`addedToPlaylistText`,
`showAddToPlaylistSheet`), `lib/ui/widgets/track_actions.dart` (:149-162, :841-857), `online_album_screen.dart`, `suggested_info.dart`,
`bulk_actions.dart`, `album_card.dart`, `album_detail_screen.dart`, `create_flows.dart`; `lib/providers/pending_playlist_adds.dart`,
`library_add_providers.dart` (`LibraryAdder.add`), `youtube_providers.dart` (`DownloadsNotifier.add`, `_promoteOrQueue`, `_joinPlaylist`),
`suggestion_actions.dart` (`addToPlaylist`); `playlistsContainingProvider` (contiene **tutti** i brani).

## Task
- [x] 163.1 Etichetta di download con più playlist
  - File: `pending_playlist_adds.dart` (`addToPlaylistTag(List<int>)` → `addto:3,7`; `parseAddToPlaylistTag` → `List<int>`, vuota se non è
    `addto:`; `addto:5` resta valido), `library_add_providers.dart`, `youtube_providers.dart`, `suggestion_actions.dart` (lista di playlist),
    test `pending_playlist_adds_test.dart`, `download_promotion_test.dart`, `suggestion_actions_test.dart`.
  - Passi: 1) formato e lettura; 2) `PendingPlaylistAdds`, `_joinPlaylist` e `LibraryAdder.add` aggiungono a ogni playlist; 3) una sola
    chiamata `add` per brano: niente secondo download, niente richiesta persa in `_promoting`.
  - Comando mirato: `flutter test test/providers/pending_playlist_adds_test.dart test/providers/download_promotion_test.dart test/providers/suggestion_actions_test.dart test/services/stream/stream_promoter_test.dart test/ui/online_song_row_test.dart test/ui/online_album_header_test.dart`
  - Fatto quando: `addto:3,7` porta il brano in entrambe in modalità streaming e dispositivo con un solo download; il test `addto:5` della 162.1 resta verde.
- [x] 163.2 Foglio a scelta multipla con ricerca (mockup A)
  - File: `playlist_sheet.dart`, ARB in `lib/l10n/` (6 lingue: «Cerca o crea una playlist», «Crea «{name}»», «Aggiungi a {n} playlist» con
    plurale, «Già presente», «Aggiunto a {n} playlist», «Nessuna playlist chiamata «{name}»»), test `create_flows_test.dart`.
  - Passi (solo con brani, modalità «aggiungi»): 1) tocco = spunta/toglie; righe che contengono già tutti i brani spuntate e bloccate
    («Già presente», `Checkbox` disattivata); 2) campo con lente e ×, filtro con `filterByText` (maiuscole e accenti ignorati); 3) riga
    «Crea «<testo>»» in cima finché nessun nome è identico (maiuscole ignorate): crea, mette la playlist in cima spuntata, svuota il campo, il
    foglio resta aperto; 4) `FilledButton` a tutta larghezza fisso in fondo «Aggiungi a N playlist», disattivato a 0, che aggiunge a tutte
    (mancanti solo), chiude e mostra «Aggiunto a N playlist» (con una sola: il messaggio di oggi col nome); 5) senza brani («Nuova playlist»):
    nessun cambiamento; 6) TalkBack: righe come caselle con stato, bloccate annunciate come «Già presente».
  - Comando mirato: `flutter test test/ui/create_flows_test.dart` (più `flutter gen-l10n`)
  - Fatto quando: aggiornati i test :118, :139, :154 come da analisi «Rete»; nuovi test per tocco senza chiusura, conferma, riga bloccata,
    riga parziale, filtro, «Crea» (identico vs parziale), messaggio; il test «Nuova playlist non filtra» della 162.1 verde.
- [x] 163.3 `pickPlaylist` a lista e chiamanti
  - File: `playlist_picker.dart` (restituisce `List<PickedPlaylist>`, vuota all'annullo), `playlist_sheet.dart` (modalità scelta multipla senza
    scrivere, usata dai risultati online), `track_actions.dart` (:149, :841), `online_album_screen.dart`, `suggested_info.dart`, gli altri
    chiamanti di `showAddToPlaylistSheet`; test nuovo per `pickPlaylist` e per l'aggiunta di un risultato online a due playlist.
  - Passi: 1) i risultati online scelgono più playlist e fanno **una** `add` con l'etichetta multipla della 163.1; 2) messaggio come 163.2
    (o «…quando è scaricato» di oggi); 3) gli altri ingressi passano già dal foglio della 163.2.
  - Comando mirato: `flutter test test/ui/create_flows_test.dart test/providers/suggestion_actions_test.dart test/ui/online_song_row_test.dart`
  - Fatto quando: da Cerca un brano online entra in due playlist con un'azione; `flutter analyze` pulito.

## Tocca a te
Niente.

## Note di deviazione

- **163.1** `parseAddToPlaylistTag` restituisce una lista: il test `addto:5` della 162.1 ha le attese cambiate da `5`/`null` a `[5]`/vuota, comportamento identico. Solo id decimali positivi, doppioni tolti. Dalla review e dalla scheggia: un secondo tocco sullo stesso brano unisce le sue playlist al download già in coda (`DownloadQueue.mergeTag`) invece di perderle o scaricare due volte; una playlist che fallisce non blocca le altre.
- **163.2** Una playlist creata nel foglio e poi annullata resta vuota (D-752). Il conteggio del pulsante e il messaggio partono dalle playlist davvero scritte; con più playlist e nulla di aggiunto si usa il testo «Erano già tutti in…». Errore di scrittura: le altre playlist sono scritte e compare un messaggio (`playlistAddFailed`).
- **163.3** Con più playlist e download in coda il messaggio è «Aggiunto a N playlist» (nessuna variante plurale di «…quando è scaricato», per non aggiungere una stringa). Non coperti da test dedicati: il menu del brano online in `track_actions.dart` e «In riproduzione» (stessa funzione già provata da `onlineResultActions`).
