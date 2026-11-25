# Fase 154 — Player e collezioni

## Obiettivo
Il cuore c'è sempre (anche per i brani in streaming), i tre player hanno lo stesso insieme base di azioni, album e playlist online hanno la stessa testata delle locali con il cuore accanto a Condividi. Gesti del telefono invariati (D-721).

## Riferimenti
D-716, D-724, D-726, D-732, D-708. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-06..F-11), [`scansione-telefono.md`](../refactor/desktop-e-coerenza/scansione-telefono.md). Mockup: [`telefono-player.html`](../refactor/desktop-e-coerenza/mockup/telefono-player.html), [`telefono-collezioni.html`](../refactor/desktop-e-coerenza/mockup/telefono-collezioni.html). Dopo la 152 (catalogo azioni). Architettura: `../architettura/riproduzione-e-coda.md`, `../architettura/ui-e-design.md`, `../architettura/online.md`.
Codice: `lib/ui/screens/now_playing/now_playing_screen.dart` (`_TitleRow`), `now_playing_controls.dart`, `lib/ui/widgets/mini_player.dart`, `lib/ui/shell/desktop_player_bar.dart`, `lib/ui/widgets/collection_header.dart` (`CollectionScaffold`, `CollectionHeader`), `lib/providers/favorite_collections_providers.dart` (`isFavoriteCollectionProvider`, `toggleFavoriteCollectionProvider`), `lib/ui/widgets/favorite_actions.dart`, `lib/ui/screens/online/online_album_screen.dart`, `online_playlist_screen.dart`, `lib/ui/screens/library/album_detail_screen.dart`, `lib/ui/screens/playlists/playlist_detail_screen.dart`.

## Task
- [x] 154.1 Caratterizzazione delle collezioni
  - File: `test/ui/collection_header_test.dart`, `test/ui/online_album_header_test.dart`, `test/ui/online_playlist_screen_test.dart`.
  - Passi: fissare le azioni delle testate di oggi (locali e online: Play, Casuale, scarica, ⋮, «Copia link» della playlist online) e il cuore nel ⋮ delle locali; la caratterizzazione del cuore del player è già in 150.1.
  - Comando mirato: `flutter test test/ui/collection_header_test.dart test/ui/online_album_header_test.dart test/ui/online_playlist_screen_test.dart`
  - Fatto quando: verdi sul codice di oggi.
- [x] 154.2 Cuore sempre presente nel player (F-08)
  - File: `now_playing_screen.dart` (condizione a `:661`), `desktop_player_bar.dart` (`:180`).
  - Passi: 1) togliere la condizione «solo se non online»: il cuore compare anche per i brani in streaming, come già nel `mini_player.dart`; 2) stesso comportamento (preferito, «Annulla») di un brano locale; il toggle di un brano online usa il percorso del mini player.
  - Comando mirato: `flutter test test/ui/now_playing_test.dart test/ui/mini_player_test.dart test/ui/desktop_player_bar_test.dart`
  - Fatto quando: test per il brano online: cuore presente nel player grande e nella barra desktop, il tocco alterna il preferito.
- [x] 154.3 Insieme base di azioni uguale (F-09, F-10, D-732)
  - File: `now_playing_controls.dart` (`:296-325`), `now_playing_screen.dart` (⋮ «Altre azioni»), `desktop_player_bar.dart` (`:422-462`), `mini_player.dart`, ARB.
  - Passi: 1) insieme base in vista nel player grande: Dispositivi, Karaoke, Timer, Coda; «Modalità auto» passa nel ⋮ (D-732); 2) la barra desktop ha gli stessi (timer e karaoke compaiono), più velocità, testi, volume come oggi; 3) tutte icone con tooltip, oppure testo su tutte: si segue `telefono-player.html`; 4) icone dal catalogo della 152; 5) testi nuovi in 6 lingue (`scripts/arb_add.py`).
  - Comando mirato: `flutter test test/ui/now_playing_test.dart test/ui/desktop_player_bar_test.dart test/ui/now_playing_stream_cards_test.dart`
  - Fatto quando: test: stessi quattro comandi nel player grande e nella barra; «Modalità auto» raggiungibile dal ⋮ e non in vista.
- [x] 154.4 Cuore di collezione in `CollectionScaffold` (F-07, D-724, D-726)
  - File: `lib/ui/widgets/collection_header.dart`, `album_detail_screen.dart` (`:345`), `playlist_detail_screen.dart` (`:233`, `:296`), `favorite_collections_providers.dart`, ARB.
  - Passi: 1) cuore accanto a Condividi nella testata, stato da `isFavoriteCollectionProvider`, toggle da `toggleFavoriteCollectionProvider`, snackbar con «Annulla»; 2) via la voce del ⋮; 3) playlist senza uuid: **cuore nascosto** (D-726, nessuna migrazione); 4) pagine online non in libreria: un tocco salva la collezione (come «Salva in libreria») e la segna preferita; togliere il cuore toglie solo il preferito, la collezione resta (D-724); 5) preferiti e sync invariati (`collection_sync.dart`, tombstone).
  - Comando mirato: `flutter test test/ui/collection_header_test.dart test/data/favorite_collections_test.dart test/ui/collection_pages_test.dart`
  - Fatto quando: test: toggle con «Annulla» ripristina; playlist senza uuid senza cuore; online: tocco = salvata + preferita, secondo tocco = solo preferito tolto.
- [x] 154.5 Testata unica per album e playlist online (F-06, F-11)
  - File: `online_album_screen.dart` (`:274-292`), `online_playlist_screen.dart` (`:344`), `collection_header.dart`, ARB.
  - Passi: 1) le due pagine usano `CollectionScaffold`/`CollectionHeader`: Play, Casuale, cuore, Condividi in vista, ⋮ (`moreActions`); 2) la playlist online ha Condividi (e «Copia link» nel ⋮ come oggi); 3) coda/libreria/«Salva in libreria» dal catalogo di azioni.
  - Comando mirato: `flutter test test/ui/online_album_header_test.dart test/ui/online_playlist_screen_test.dart test/ui/online_pages_test.dart`
  - Fatto quando: test che le due pagine online mostrano lo stesso set di comandi delle locali.
- [x] 154.6 Goldens, guardie, documenti
  - Passi: `flutter test --update-goldens test/goldens` una volta (Linux), `scripts/guardie.sh`, `flutter analyze`; `ui-e-design.md` e, per il cuore online, `online.md`.
  - Comando mirato: `flutter test test/goldens test/ui/phone_gestures_d721_test.dart`
  - Fatto quando: verdi.

## Tocca a te
- [ ] Provare sul Mi A3 il cuore con un brano in streaming (volume 0).

## Note di deviazione
- 154.2: per un brano in streaming il cuore è **spento** finché il brano non ha la sua riga (`currentShadowRowProvider`): prima del legame non c'è nulla da segnare preferito.
- 154.3: «Modalità in auto» è la prima voce del ⋮ «Altre azioni» sul telefono (sul desktop non c'era e non c'è). Il timer ora ha 48 px ed è uscito da `_known` dell'accessibilità. Karaoke e timer nella barra desktop compaiono da 900 px (sotto traboccava, fase 157).
- 154.4: `onFavorite` restituisce se il cambio c'è stato: niente «Aggiunto ai preferiti» quando non si è salvato nulla. Un tocco durante il salvataggio è ignorato. Playlist online: la copia salvata si ritrova riaprendo la pagina grazie a `savedOnlinePlaylist.<url> → uuid` (preferenza del dispositivo, fuori dal backup, controllata contro le playlist visibili): niente copie doppie. Cuore spento finché la playlist esterna ha righe in attesa. `saveToLibrary` restituisce anche l'uuid. Album online: il preferito vale per la chiave dell'album del primo brano (limite per le compilation); se tutti i brani sono già file non c'è nulla da salvare.
- 154.5: le pagine online usano `CollectionHeader`; il Play disattivato della playlist online ora è nascosto come sulle pagine locali; «Copia link» resta nel ⋮.
- 154.6: golden rigenerati sulla pila e controllati di nuovo su master (nessun cambio); la prova a vista sul Mi A3 è nella prova dal vivo dopo la 157 (D-746).
