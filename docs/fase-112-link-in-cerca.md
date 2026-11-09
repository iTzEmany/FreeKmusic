# Fase 112 — Link incollati in Cerca

**Obiettivo:** un link incollato in Cerca si ascolta in streaming. Playlist e canali YouTube si aprono in una pagina come quella dell'album, con Play, Shuffle e «Scarica» nel menu. Un album di YouTube Music apre la sua pagina. Un singolo video suona subito, con la coda di simili. **Cambi di comportamento voluti** (D-510, D-512, D-513, D-514, D-527)

**Prerequisiti:** fase 111 chiusa. Analisi F-144, F-145, F-147 (`refactor/coda-e-libreria/analisi.md`, «Rilievi aggiunti»). Nessun mockup (D-510): la pagina segue `lib/ui/screens/online/online_album_screen.dart`. Fuori da questa fase: link Spotify e Deezer (fasi 114–116, `docs/feature-link-e-shazam.md`). La pagina nasce già sul modello comune (D-527), così la 114 aggiunge solo le fonti.

**Comando mirato:** `flutter test test/services/online/youtube_urls_test.dart test/services/online/query_intent_test.dart test/services/online/smart_search_test.dart test/ui/online_playlist_screen_test.dart test/ui/search_sources_test.dart test/ui/online_album_screen_test.dart` (gli ultimi due solo se esistono: `ls test/ui | grep -E "search_sources|online_album"`)

## Task

### 112.1 — Riconoscere i link (F-145)
- `lib/services/online/youtube_urls.dart:30-70`: `classifyYoutubeUrl` riconosce anche `music.youtube.com/browse/MPREb_…` come album (nuovo valore, es. `YoutubeLinkKind.album`) e una funzione pubblica ne restituisce il `browseId`. La regex privata `_ytmAlbumId` di `direct_search_service.dart:10-16` passa lì e l'import la riusa: un solo posto.
- `lib/services/online/query_intent.dart:19`: `QueryKind.album` con il `browseId`; `listing` e `video` restano.
- Test: righe nuove nella tabella di `test/services/online/youtube_urls_test.dart` (album YouTube Music, album con parametri, `browse/` che non è un album → `other`) e in `query_intent_test.dart`.

### 112.2 — Pagina della playlist online (F-144, F-147, D-510, D-512, D-527)
- **Modello comune, da subito (D-527).** `lib/services/online/external_collection.dart` (nuovo): `ExternalCollection {title, coverUrl?, owner?, kind, tracks, declaredTotal?, sourceUrl}`, `ExternalTrack {title, artists, durationMs?, isrc?, key}` e `TrackMatch = pending | ready(YtResult o Track di libreria) | notFound`. `lib/providers/online_collection_providers.dart` (nuovo): `OnlineCollectionRef` (qui solo `youtubeListing(url)`; la 114 aggiunge `external(link)`) e `onlineCollectionProvider.autoDispose.family<CollectionPage, OnlineCollectionRef>`, con `CollectionPage {collection, matches}` (una `TrackMatch` per brano). Per YouTube il provider legge `playlistListingProvider(url)` e produce tutte le righe già `ready`: nessun matcher, nessuna rete in più. I nomi sono quelli della fase 114 (`fase-114-link-spotify-deezer.md`): non cambiarli lì.
- `lib/ui/screens/online/online_playlist_screen.dart` (nuovo): `OnlinePlaylistScreen(OnlineCollectionRef)` legge `onlineCollectionProvider` (che a sua volta legge `playlistListingProvider(url)`, `lib/providers/youtube_providers.dart:35`, già con «Riprova» e senza ritentativi nascosti). Le righe si disegnano per stato di abbinamento: `ready` = `OnlineSongRow`; `pending` e `notFound` li disegna la 114 (qui un solo ramo `ready`, ma lo `switch` è già completo e non ha un caso `default`). Intestazione con copertina (la miniatura del primo brano), titolo e autore della `PlaylistListing`, numero di brani; Play e Shuffle come `online_album_screen.dart:95-99` (`playOnlineListAndOpen`, e in una Jam `_queueAlbum` `:102`: estrarlo in una funzione comune invece di copiarlo); righe `OnlineSongRow` (`online_song_row.dart`); menu ⋮ con «Scarica», che apre `PlaylistSourceSheet.show(context, url)` di oggi, e «Copia link».
- Lista troncata (`truncated`, limite 500 di `listPlaylist`, `youtube_service.dart:250`): una riga in fondo lo dice. Voci non disponibili: non mostrate, come nel foglio di oggi.
- `lib/ui/screens/youtube/online_results.dart:80-90`: il ramo `listingUrl` apre `OnlinePlaylistScreen(OnlineCollectionRef.youtubeListing(listing))` al posto del foglio. Un link a un canale passa da `listingUrl` (`/videos`) e apre la stessa pagina (D-512).
- La lettura resta fuori da `budgetedYtm` (è yt-dlp, non InnerTube). La cache del provider evita una nuova lettura tornando indietro finché la pagina è in pila (F-147).
- Accessibilità: Play e Shuffle con etichette TalkBack, bersagli ≥ 48 dp, titolo con `Semantics(header: true)` come la pagina album.
- Chiavi ARB nuove, se servono (es. «Mostrati i primi 500 brani»), in tutte le lingue di `lib/l10n/`.
- Test `test/ui/online_playlist_screen_test.dart` (e un caso in `test/providers/online_collection_providers_test.dart`: tutte le righe `ready` dalla `PlaylistListing`) con un `YoutubeService` finto: elenco mostrato; Play suona la lista dal primo brano; Shuffle; «Scarica» apre il foglio; errore con «Riprova»; lista troncata con la riga in fondo.

### 112.3 — Album YouTube Music e singolo video (F-145, D-513)
- `online_results.dart:_search`: `QueryKind.album` apre `OnlineAlbumScreen(browseId)` (`online_album_screen.dart:41`, già in streaming, con il download).
- `QueryKind.video`: la ricerca di oggi dell'URL resta. Appena arriva il risultato con lo stesso id del video, si chiama `PlayerController.playFromSearch(online: result)` (`lib/providers/player_providers.dart:442`): brano + coda di simili, come un brano scelto da Cerca. Il risultato resta in elenco. Se nessun risultato ha quell'id, nessun avvio e la ricerca resta com'è.
- Test in `smart_search_test.dart` o in un test del widget dei risultati: un link a un video avvia `playFromSearch` una volta sola, anche se l'elenco si ricostruisce; un link ad album apre la pagina album.

### 112.4 — Controlli di fase
`flutter analyze`; comando mirato; review del diff (Sonnet); scheggia passo e fase. Prova sul Mi A3 via adb: incollare un link a una playlist YouTube, a una playlist YouTube Music, a un canale, a un album YouTube Music e a un video. Verificare che la pagina si apra, che Play e Shuffle suonino in streaming e che «Scarica» apra il foglio di oggi. Poi togliere i download fatti per prova.

**Fatto quando:** nessun link YouTube o YouTube Music incollato in Cerca porta solo al download; playlist, canali, album e video si ascoltano in streaming; i test sono verdi.

## Da decidere
(nessuno)
