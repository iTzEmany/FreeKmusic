# Refactor «playlist-aggiungi-e-casuale» — analisi

Tipo: `ui` (con una piccola parte di logica e impostazioni). Data: 2026-11-28.

## Richiesta dell'utente
1. Il «Casuale» premuto in una playlist resta salvato come scelta di quella playlist.
2. Da Cerca, «Aggiungi alla playlist» aggiunge un brano a **più** playlist in un'unica azione.
3. Nello stesso foglio la barra in alto filtra le playlist; se nessuna corrisponde appare «Crea «<testo>»».

Sono **cambi di comportamento** voluti (regola 1 di `/refactor`): vanno nel file decisioni come tali.
Il punto 1 rovescia in parte D-534 («lo stato sta solo in memoria», alternativa scartata: «modalità salvata su disco»).

## Ambito
- `lib/providers/shuffle_plus_providers.dart` (`ListShuffle`, `listKeyOf`), `lib/providers/player_providers.dart`
  (`playMixed`, `_cycleList`), `lib/ui/widgets/shuffle_button.dart`, `lib/ui/screens/playlists/playlist_detail_screen.dart`,
  `lib/data/settings/settings_store.dart` (modello: `playlistSorts`).
- `lib/ui/widgets/playlist_sheet.dart` (foglio unico «Nuova playlist» / «Aggiungi alla playlist», D-405, D-411),
  `lib/ui/screens/playlists/playlist_picker.dart`, `playlist_dialogs.dart`, `lib/ui/widgets/track_actions.dart`,
  `lib/providers/pending_playlist_adds.dart`, `lib/providers/library_add_providers.dart`, `lib/providers/youtube_providers.dart`.
- Chiamanti del foglio: `track_actions.dart`, `bulk_actions.dart`, `album_card.dart`, `album_detail_screen.dart`,
  `online_album_screen.dart`, `suggested_info.dart`, `create_flows.dart`.

Misure di base: non servono misure di prestazione (nessun percorso caldo toccato). Test esistenti: `test/ui/create_flows_test.dart`
(foglio), `test/providers/list_shuffle_test.dart`, `test/ui/shuffle_button_test.dart`, `test/ui/collection_header_test.dart`,
`test/providers/pending_playlist_adds_test.dart`, `test/providers/suggestion_actions_test.dart`.

## Risultati (per priorità)

F-01 · logica · Il «Casuale» di una playlist vive solo in memoria · `shuffle_plus_providers.dart:436-447` · `ListShuffle.build() => ShuffleMode.off`,
commento «in memory, off by default» · a ogni riavvio dell'app la scelta torna spenta: è il fastidio segnalato · impatto H · rischio L · costo S ·
salvare la modalità per playlist nelle impostazioni, come già `playlistSorts` (mappa id → valore).

F-02 · logica · La chiave del «Casuale» è l'hash degli id dei brani · `playlist_detail_screen.dart:380` (`listKeyOf([for (final t in tracks) t.id])`),
`shuffle_plus_providers.dart:450` · aggiungere, togliere o riordinare un brano, o cambiare l'ordinamento, cambia la chiave: la scelta si perde
anche senza riavvio · impatto H · rischio M (la stessa chiave dice anche «questa lista sta suonando», `player_providers.dart:158-163`) · costo S ·
per le playlist la modalità salvata si legge per id della playlist; la chiave per «sta suonando» resta com'è.

F-03 · UI · Un tocco = una playlist, poi il foglio si chiude · `playlist_sheet.dart:78-92` (`_add` chiama `_done` a riga 81) · per mettere un brano
in 3 playlist servono 3 aperture del menu · impatto H · rischio L · costo M · selezione multipla nel foglio con un pulsante di conferma.

F-04 · logica · Il percorso dei risultati online passa da `pickPlaylist`, che restituisce **una** playlist · `playlist_picker.dart:11`,
`track_actions.dart:149-162` (riga online in coda) e `:841-857` (risultato di Cerca) · anche col foglio multiplo questi chiamanti ne userebbero una sola ·
impatto H · rischio M · costo S · `pickPlaylist` → lista di playlist; i chiamanti aggiungono a ognuna.

F-05 · dati · L'etichetta di download `addto:<id>` porta una sola playlist · `pending_playlist_adds.dart:16-21`; in modalità dispositivo una seconda
richiesta dello stesso brano o si perde (`youtube_providers.dart:317`, `_promoting` già occupato) o accoda un secondo download dello stesso file
(`:342-343`, il controllo dei doppioni vale solo senza etichetta) · con «aggiungi a più playlist» in modalità dispositivo il brano finirebbe in una sola
playlist, o verrebbe scaricato due volte · impatto H · rischio M · costo S · etichetta `addto:<id>,<id>,…` (la forma vecchia `addto:5` resta valida);
`parseAddToPlaylistTag` restituisce una lista e `PendingPlaylistAdds` / `_joinPlaylist` / `LibraryAdder.add` aggiungono a ognuna. Le etichette della coda
di download non sono salvate su disco (verificato: `download_queue.dart` non le serializza), quindi nessuna migrazione.

F-06 · UI · Il campo in alto è solo «nome della nuova playlist» e la lista non si filtra · `playlist_sheet.dart:153-170`, lista intera a `:109` e `:199` ·
con molte playlist bisogna scorrere; il campo e il pulsante «Crea» occupano spazio senza aiutare a trovare · impatto M · rischio L · costo S ·
il campo filtra la lista (stesso confronto di testo delle altre ricerche); la riga «Crea «<testo>»» sostituisce il pulsante «Crea».

F-07 · UI · Lo stesso foglio fa anche «Nuova playlist» (senza brani, con le scorciatoie Smart e CSV) · `playlist_sheet.dart:27-42`, `:173-184`;
chiamanti `create_flows.dart`, `playlist_picker.dart` · cambiare il campo in ricerca tocca anche quel flusso · impatto M · rischio M · costo S ·
decidere se la ricerca vale solo in modalità «aggiungi».

F-08 · funzione nuova (chiesta il 28/11 a scansione chiusa) · Le playlist intelligenti mostrano solo brani della libreria · regole tradotte in SQL
(`lib/services/library/rules/rule_sql.dart`), nessuna valutazione in memoria; i risultati online (`YtResult`) portano solo titolo, artisti, album e
durata (`youtube_service.dart`) · l'utente vuole brani simili che non ha, coerenti coi filtri, «un Casuale+ ancora più filtrato» · impatto H ·
rischio M (rete, motore dei suggerimenti) · costo M · riusare il mix delle pagine genere (`genre_mix.dart`, `genreMixProvider` in
`shuffle_plus_providers.dart:373`): semi dai brani della playlist e un controllo delle regole verificabili nel punto `accept` già presente in
`SuggestionPool.take` (`suggestion_pool.dart:150`, passato da `RadioFill`).

## Sintesi per area
- **Casuale**: la scelta per lista esiste (D-534) ma è effimera due volte: in memoria e legata all'hash dei brani. Basta salvarla per id di
  playlist accanto a `playlistSorts`.
- **Aggiungi a più playlist**: il foglio, `pickPlaylist` e l'etichetta `addto:` sono tutti a playlist singola; il punto delicato è il download in
  modalità dispositivo (F-05).
- **Ricerca nel foglio**: modifica locale a `playlist_sheet.dart`, da tenere separata dal flusso «Nuova playlist».

## Scelte
Diagnosi confermata dall'utente (28/11). Si affrontano **tutti** i risultati F-01..F-07; nessuno rimandato o scartato.

| Risultato | Soluzione scelta | Decisione |
|---|---|---|
| F-01, F-02 | «Casuale» salvato per id di playlist (normali e smart), tre modalità, solo su questo dispositivo, voce cancellata con la playlist | D-749, D-750 |
| F-03 | Spunte + pulsante «Aggiungi a N playlist»; righe già piene spuntate e bloccate | D-751 |
| F-04 | `pickPlaylist` → lista; vale in ogni ingresso «Aggiungi alla playlist» | D-751 |
| F-05 | Etichetta `addto:<id>,<id>,…` | D-753 |
| F-06 | Il campo filtra; riga «Crea «<testo>»» finché nessun nome è identico; crea e spunta, il foglio resta aperto | D-752 |
| F-07 | La ricerca vale solo in modalità «aggiungi»; «Nuova playlist» invariato | D-752 |
| F-08 | Righe online nella pagina della playlist intelligente come le pagine genere; semi dalla playlist + controllo di artista, album, durata; interruttore per playlist acceso di base, salvato nelle impostazioni | D-756, D-757, D-758 |

Obiettivo: comportamento chiesto dall'utente con la modifica più piccola; nessuna riscrittura (audacia: ritocchi mirati).

**Intoccabili**: «Casuale» delle altre pagine di lista e del player; foglio «Nuova playlist»; schema del DB; nessun pacchetto nuovo;
chiave «questa lista sta suonando» (`listKeyOf`) invariata.

**Cambi di comportamento voluti**: Casuale delle playlist persistente (supera in parte D-534); foglio «Aggiungi» a scelta multipla
che non si chiude al tocco; campo in alto che filtra.

## Direzione
Stile: quello già approvato nel refactor «desktop-e-coerenza» (token in `lib/ui/theme/tokens.dart`, D-723..D-732); nessuna direzione nuova.

- **Foglio «Aggiungi alla playlist»**: variante A, `docs/mockups/playlist-aggiungi-e-casuale/variante-a.html` (approvata il 28/11, D-755).
  Stati: (b) appena aperto con 2 scelte e 1 bloccata, (c) «rock» filtrato con «Crea «rock»», (d) nessuna corrispondenza con suggerimento vuoto;
  desktop come dialogo di 480 px. Componenti di casa: `ListTile` di oggi a 64 px, `Checkbox` del tema, `FilledButton` a tutta larghezza.
- **Righe suggerite nella playlist intelligente**: nessun mockup nuovo; la specifica visiva è la pagina genere di oggi
  (`lib/ui/screens/search/genre_screen.dart`: stesse righe online, stessi segnaposto mentre arrivano, stesse scritte di «mix spento»).
- **Interruttore nell'editor**: `SwitchListTile` come gli altri interruttori dell'editor.
- **Casuale**: nessun cambio visivo.

Struttura: nessuna architettura nuova. Una mappa e un insieme nelle impostazioni (accanto a `playlistSorts`); una funzione pura
«il risultato online rispetta le regole verificabili?» accanto alle regole (`lib/services/library/rules/`); `genreMix` riceve le tracce e un `accept`
opzionale; un provider per il mix della playlist intelligente gemello di `genreMixProvider`.

## Rete
Copertura di oggi: «Casuale» per lista in `test/providers/list_shuffle_test.dart`, `test/ui/shuffle_button_test.dart` (:261-313),
`test/ui/collection_header_test.dart` (:297-304); impostazioni in `test/data/settings_store_test.dart`, `test/services/share/settings_sync_test.dart`,
`test/services/backup/restore_service_test.dart` (:979, :1028-1051), `legacy_backup_test.dart` (:91-110); foglio solo in `test/ui/create_flows_test.dart`;
etichetta `addto:` in `test/providers/pending_playlist_adds_test.dart` (:43, :55, :120-208). Nessun test per `pickPlaylist`, `bulk_actions`,
`album_card`, `suggested_info`, né per la pulizia di `playlistSorts` alla cancellazione di una playlist. Nessun golden copre il foglio.

**Test di caratterizzazione da scrivere prima di toccare il codice** (fissano ciò che deve restare):
1. `list_shuffle_test.dart`: il «Casuale» di album, artista e lista online resta in memoria, chiave `listKeyOf`, mai scritto nelle impostazioni (D-534 per le altre pagine).
2. `pending_playlist_adds_test.dart`: `addto:5` porta il brano nella playlist 5; `addto:`, `addto:x`, `foo` non aggiungono niente (forma vecchia ancora valida).
3. `create_flows_test.dart`: in «Nuova playlist» scrivere nel campo **non** filtra la lista (il resto è già coperto a :38-77).
4. `settings_store_test.dart`: andata e ritorno di `playlistSorts`, se manca (modello per la mappa nuova).
5. Guardia già esistente da tenere: per la playlist che suona il pulsante cambia la coda vera (`list_shuffle_test.dart` :206).

**Test nuovi per passo**: mappa del «Casuale» (andata e ritorno, valore rovinato → spento, voce tolta con la playlist); modalità che sopravvive a
nuovo container, aggiunta, rimozione e riordino, anche per una smart; fuori da sync e azzerata dal ripristino completo; foglio: tocco spunta senza
chiudere, «Aggiungi a N playlist» aggiunge a tutte e chiude col messaggio, riga piena spuntata e bloccata, riga parziale riceve solo i mancanti,
filtro senza maiuscole e accenti, riga «Crea «x»» fino al nome identico che crea, spunta, svuota il campo e resta aperto; `pickPlaylist` restituisce la
lista (vuota/null all'annullo); `addto:3,7` porta il brano in entrambe in modalità streaming e dispositivo con un solo download.

**Test che cambiano apposta** (si aggiornano, non si cancellano): `create_flows_test.dart` :118 (tocco che aggiunge e chiude), :139 (segno →
spunta bloccata), :154 («Crea» → riga «Crea «x»»); casi *playlist* di `shuffle_button_test.dart` :261-313 e `collection_header_test.dart` :297-304
(chiave → id della playlist; i casi non-playlist restano).

**Comportamento invariato significa**: i test di caratterizzazione e quelli esistenti non elencati sopra restano verdi senza modifiche;
`flutter analyze` pulito; nessun golden cambia.

**F-08**: copertura di oggi in `test/services/shuffle_plus/genre_mix_test.dart`, `test/providers/genre_mix_provider_test.dart`,
`test/ui/smart_playlists_test.dart`. Caratterizzazione prima: la pagina genere mescola come oggi (uno ogni 2, massimo 9) e senza `accept` nulla cambia;
la pagina di una playlist intelligente oggi mostra solo brani della libreria (resta così con l'interruttore spento). Test nuovi: controllo delle regole su
`YtResult` (artista, album, durata, esclusioni, regole non verificabili e di libreria ignorate, «una qualsiasi» con regole ignorate); mix della playlist
intelligente con semi dai suoi brani, candidati scartati dal controllo, limite non toccato; interruttore salvato, fuori da sync e ripristino, tolto alla cancellazione.

**Metriche di chiusura** (comando): test mirati verdi —
`flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/ui/collection_header_test.dart test/ui/create_flows_test.dart test/providers/pending_playlist_adds_test.dart test/providers/download_promotion_test.dart test/services/stream/stream_promoter_test.dart test/ui/online_song_row_test.dart test/ui/online_album_header_test.dart test/data/settings_store_test.dart test/services/share/settings_sync_test.dart test/services/backup/restore_service_test.dart test/services/backup/legacy_backup_test.dart test/services/shuffle_plus/genre_mix_test.dart test/providers/genre_mix_provider_test.dart test/ui/smart_playlists_test.dart test/services/library/`;
`flutter analyze` senza problemi; `flutter gen-l10n` senza diff dopo le stringhe nuove (6 lingue). Nessuna misura di prestazione: nessun percorso caldo toccato.
