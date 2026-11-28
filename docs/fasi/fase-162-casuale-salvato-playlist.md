# Fase 162 — Casuale salvato delle playlist

## Obiettivo
Il «Casuale» di una playlist (normale o intelligente) resta come l'ha lasciato l'utente: dopo un riavvio, dopo aver aggiunto, tolto o riordinato
brani, dopo un cambio di ordinamento. Prima si fissa con test il comportamento che non deve cambiare (anche per le fasi 163 e 164).
Fuori: il «Casuale» delle altre pagine di lista (album, artisti, generi, online, Home) e quello del player restano come oggi (D-534).

## Riferimenti
Refactor `../refactor/playlist-aggiungi-e-casuale/analisi.md` (F-01, F-02, «Scelte», «Rete»). Decisioni D-749, D-750 (supera in parte D-534), D-754 (intoccabili). Architettura: `../architettura/riproduzione-e-coda.md`.
Codice: `ListShuffle`, `listShuffleProvider`, `listKeyOf` (`lib/providers/shuffle_plus_providers.dart:436-453`); `PlayerController.playMixed`,
`_cycleList`, `isPlayingList` (`lib/providers/player_providers.dart`); `_modeOf`, `ShufflePill` (`lib/ui/widgets/shuffle_button.dart`);
`playlist_detail_screen.dart:380` (chiave = hash degli id); `smart_playlist_screen.dart`; modello `playlistSorts` in
`lib/data/settings/settings_store.dart` (:69, :165, :293, :360, :498), `lib/services/share/settings_sync.dart:63`,
`lib/services/backup/restore_service.dart:69, :295`, pulizia alla cancellazione in `playlist_detail_screen.dart:145`.

## Task
- [ ] 162.1 Test di caratterizzazione (nessun codice di prodotto)
  - File: `test/providers/list_shuffle_test.dart`, `test/providers/pending_playlist_adds_test.dart`, `test/ui/create_flows_test.dart`,
    `test/data/settings_store_test.dart`, `test/services/shuffle_plus/genre_mix_test.dart`, `test/ui/smart_playlists_test.dart`.
  - Passi: 1) il «Casuale» di album, artista e lista online sta in memoria con chiave `listKeyOf` e non scrive nelle impostazioni;
    2) `addto:5` porta il brano nella playlist 5; `addto:`, `addto:x`, `foo` non aggiungono niente; 3) in «Nuova playlist» scrivere nel campo
    non filtra la lista; 4) andata e ritorno di `playlistSorts` (se manca); 5) la pagina genere mescola uno ogni 2, al massimo 9;
    6) la pagina di una playlist intelligente mostra solo brani della libreria. Tutti verdi sul codice di oggi.
  - Comando mirato: `flutter test test/providers/list_shuffle_test.dart test/providers/pending_playlist_adds_test.dart test/ui/create_flows_test.dart test/data/settings_store_test.dart test/services/shuffle_plus/genre_mix_test.dart test/ui/smart_playlists_test.dart`
  - Fatto quando: i test nuovi passano senza toccare `lib/`.
- [ ] 162.2 Modalità salvata nelle impostazioni
  - File: `settings_store.dart` (mappa `playlistShuffles`: chiave `'<id>'` per le playlist, `'smart:<id>'` per le intelligenti, valore
    `off|shuffle|plus`), `settings_sync.dart` (esclusa come `playlistSorts`), `restore_service.dart` (azzerata come `playlistSorts`),
    cancellazione di playlist normale e intelligente (togliere la voce, come `:145`), test in `settings_store_test.dart`, `settings_sync_test.dart`,
    `restore_service_test.dart`.
  - Passi: 1) campo, `copyWith`, lettura e scrittura come `playlistSorts`; valore rovinato → nessuna voce (spento); 2) fuori dalla sync;
    3) ripristino completo la toglie; 4) eliminare una playlist toglie la sua voce.
  - Comando mirato: `flutter test test/data/settings_store_test.dart test/services/share/settings_sync_test.dart test/services/backup/restore_service_test.dart test/services/backup/legacy_backup_test.dart`
  - Fatto quando: i quattro comportamenti sono coperti da test verdi.
- [ ] 162.3 Il «Casuale» delle playlist letto e scritto per id
  - File: `shuffle_plus_providers.dart` (una chiave di playlist, es. `PlaylistShuffleKey(id, smart)`, che `ListShuffle` legge e scrive nelle
    impostazioni; le altre chiavi restano in memoria), `player_providers.dart` (`isPlayingList` riconosce la playlist che suona anche con la chiave
    nuova: stesso `_listKey` passato da Play), `playlist_detail_screen.dart`, `smart_playlist_screen.dart` (pill e Play con la stessa chiave nuova),
    test `list_shuffle_test.dart`, `shuffle_button_test.dart` (:261-313, casi playlist), `collection_header_test.dart` (:297-304, casi playlist).
  - Passi: 1) chiave della playlist al posto di `listKeyOf(ids)` nelle due pagine; 2) `ListShuffle.build` per quella chiave legge la mappa,
    `set` la scrive; 3) la playlist che suona: il pulsante agisce sul player come oggi e salva; 4) test: la modalità sopravvive a un nuovo
    container, ad aggiunta, rimozione, riordino e cambio di ordinamento, anche per una intelligente; i casi non-playlist restano invariati.
  - Comando mirato: `flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/ui/collection_header_test.dart test/ui/smart_playlists_test.dart`
  - Fatto quando: test verdi; i test di caratterizzazione della 162.1 restano verdi senza modifiche; `flutter analyze` pulito.

## Tocca a te
Niente.

## Note di deviazione
