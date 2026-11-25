# Fase 153 — Home del telefono

## Obiettivo
«Riprendi» diventa l'anello aperto di copertine, «Nuove uscite» ha un'anteprima, la pagina Playlist perde i due pulsanti flottanti, Home e Libreria usano le stesse scorciatoie e le stesse righe playlist. Il desktop usa solo il provider del Riprendi (il resto della home da PC è nella 157).

## Riferimenti
D-716, D-725, D-721 (gesti invariati). Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-15, F-16, F-17, F-21, F-22, F-23), [`scansione-telefono.md`](../refactor/desktop-e-coerenza/scansione-telefono.md) («Dati disponibili»). Mockup: [`telefono-home.html`](../refactor/desktop-e-coerenza/mockup/telefono-home.html), [`telefono-coerenza.html`](../refactor/desktop-e-coerenza/mockup/telefono-coerenza.html), [`desktop-home.html`](../refactor/desktop-e-coerenza/mockup/desktop-home.html) (solo il Riprendi). Dopo la 152: `SectionHeader` e `EmptyState` comuni. Architettura: `../architettura/ui-e-design.md`.
Codice: `lib/ui/screens/home/resume_rows.dart`, `home_blocks.dart`, `home_screen.dart`, `lib/providers/resume_providers.dart` (`resumeItemsProvider`, `lastPlaysProvider`), `lib/data/repositories/home_sections.dart` (`lastPerArea`), `lib/ui/screens/playlists/playlists_screen.dart`, `lib/ui/screens/library/library_island.dart`, `lib/ui/screens/releases/new_releases_screen.dart`, `lib/ui/widgets/cover_image.dart`, `playlist_cover.dart`, `artist_avatar.dart`.

## Task
- [x] 153.1 Caratterizzazione
  - File: `test/ui/home_screen_test.dart`, `test/ui/playlists_screen_test.dart` (nuovo), `test/providers/resume_providers_test.dart`, `test/ui/phone_gestures_d721_test.dart` (già dalla 150).
  - Passi: la pagina Playlist apre una playlist al tocco; `resumeItemsProvider` di oggi (una voce per area) fissato; Daylist doppia nota.
  - Comando mirato: `flutter test test/ui/playlists_screen_test.dart test/providers/resume_providers_test.dart`
  - Fatto quando: verdi sul codice di oggi.
- [x] 153.2 Dati del Riprendi (D-725)
  - File: `lib/providers/resume_providers.dart`, `lib/data/repositories/home_sections.dart`.
  - Passi: 1) nuova lista di 6-8 ultimi ascolti **distinti e misti** (brani, album, playlist, radio, daylist) dalla cronologia (`lastPlaysProvider`, `recentEntriesProvider`), il più recente primo; 2) niente voce Daylist se c'è la card Daylist (F-17); 3) `lastPerArea` resta se serve ad altro, altrimenti lo si toglie con i suoi test; 4) lo stesso provider serve telefono e desktop.
  - Comando mirato: `flutter test test/providers/resume_providers_test.dart test/data/home_sections_test.dart`
  - Fatto quando: test: 8 ascolti di aree diverse danno 8 voci distinte nell'ordine; due ascolti della stessa cosa una voce; niente Daylist doppio.
- [x] 153.3 Anello aperto del Riprendi (F-21)
  - File: `lib/ui/screens/home/resume_rows.dart` (o un file accanto), ARB (testo «Riprendi», etichette per i lettori di schermo; 6 lingue con `scripts/arb_add.py`).
  - Passi: 1) il più recente grande al centro con «Riprendi», gli altri sull'arco aperto, copertine reali (`CoverImage`, `PlaylistCover`, `ArtistAvatar`, favicon radio); 2) un tocco riprende da lì (stessa azione di oggi, test di 153.1/150.1); 3) con pochi ascolti l'anello degrada (1 voce: solo il centro) senza buchi; 4) `Semantics` per ogni voce, bersagli ≥ 48 dp.
  - Comando mirato: `flutter test test/ui/resume_rows_test.dart test/ui/home_screen_test.dart test/ui/a11y_guidelines_test.dart`
  - Fatto quando: test con 0, 1, 3 e 8 voci; il tocco su un'estremità riprende quella voce.
- [x] 153.4 «Nuove uscite» con anteprima (F-22)
  - File: `lib/ui/screens/home/home_blocks.dart`, ARB se serve.
  - Passi: 1) scaffale con alcune uscite recenti (`recentReleasesProvider(days)`: copertina, titolo, artista) e `SectionHeader(actionLabel: showAll)` che apre `NewReleasesScreen`; 2) senza uscite il blocco non compare come oggi; contatore `newReleasesCountProvider` mantenuto.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/new_releases_screen_test.dart` (usa il test esistente di quella schermata se ha un altro nome)
  - Fatto quando: con 3 uscite l'anteprima mostra 3 copertine e «Tutti» apre la pagina completa.
- [x] 153.5 Pagina Playlist senza FAB; scorciatoie e righe uguali (F-23, F-15, F-16)
  - File: `lib/ui/screens/playlists/playlists_screen.dart`, `lib/ui/screens/library/library_island.dart`, `lib/ui/screens/home/home_blocks.dart`, `lib/ui/shell/desktop_sidebar.dart` (solo verifica).
  - Passi: 1) via «Importa da Exportify» e «Nuova playlist» da `PlaylistsScreen`; restano il «+» della Libreria e della barra laterale; l'import Exportify resta raggiungibile da lì (test); 2) un solo widget per le scorciatoie, usato da Home e Libreria (tile con icona e sottotitolo, conteggio nella stessa forma); 3) righe playlist: quella della Libreria («Playlist di N brani») anche in `PlaylistsScreen`.
  - Comando mirato: `flutter test test/ui/playlists_screen_test.dart test/ui/library_screen_test.dart test/ui/settings_and_playlists_test.dart`
  - Fatto quando: la pagina non ha FAB; Home e Libreria mostrano le stesse scorciatoie; test che l'import è ancora raggiungibile.
- [x] 153.6 Goldens, guardie, documenti
  - Passi: `flutter test --update-goldens test/goldens` una volta (Linux), `scripts/guardie.sh`, `flutter analyze`; aggiorna `ui-e-design.md`.
  - Comando mirato: `flutter test test/goldens test/ui/phone_gestures_d721_test.dart`
  - Fatto quando: gesti D-721 e goldens verdi.

## Tocca a te
- [ ] Guardare la home sul Mi A3 a 360 dp (la verifica a schermo è nella 161).

## Note di deviazione
- 153.2: `lastPerArea` sostituita da `recentResumeItems` (stessi ingressi più `daylist` e `limit`); dei brani entrano solo l'ultimo per tipo di contesto e quelli da riprendere, perché `watchLastPlayPerContext` dà una riga per tipo (una cronologia completa vorrebbe una query nuova: non fatta). Nessuna chiave ARB nuova per l'anello (riusati `homeResume` e le etichette delle aree).
- 153.5: il mockup `telefono-home.html` ha riquadri con titolo e sottotitolo **senza icona**: Home e Libreria seguono il mockup invece della frase «tile con icona» del task. Il widget unico è `LibraryShortcuts` (non `library_island.dart`, che ha solo le schede). L'import Exportify resta nel «+» (coperto da `create_flows_test` e `menus_characterization_test`). Il tocco su una copertina dello scaffale apre l'elenco completo.
- 153.6: golden rigenerati sulla pila delle fasi UI (D-745); il controllo a schermo sul Mi A3 è nella prova dal vivo dopo la 157 (D-746).
