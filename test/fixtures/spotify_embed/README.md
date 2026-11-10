Pagine reali di `open.spotify.com/embed/{tipo}/{id}` (2026-11-10), ridotte al solo `<script id="__NEXT_DATA__">` e ai campi che Codecore legge (niente anteprime audio).
Percorso: `props.pageProps.state.data.entity` -> `title`, `coverArt.sources[0].url` (playlist) o `visualIdentity.image[]` (album, artista, brano), `trackList[] {title, subtitle, duration}`; il brano singolo non ha `trackList` ma `artists[].name` e `duration`.
`subtitle` separa gli artisti con una virgola e uno spazio non divisibile (U+00A0).
Nessun campo del totale dichiarato: l'embed taglia a 100 brani (`playlist_big.html`, 100 letti da una playlist di 150).
- `no_track_list.html`: costruita a mano (pagina dell'artista senza `trackList`).
