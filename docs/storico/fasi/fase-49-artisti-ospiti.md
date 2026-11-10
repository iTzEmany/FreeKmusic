# Fase 49 — Artisti ospiti

**Obiettivo:** un brano con più artisti ha un link per ognuno. Nel player e nella barra desktop i nomi sono toccabili
uno per uno («A, B feat. C»); la voce ⋮ «Vai all'artista» apre la pagina con un artista e un foglio di scelta con
più artisti. Il link porta prima alla libreria (artista con lo stesso nome normalizzato), altrimenti alla pagina
online di YouTube Music.

**Prerequisiti:** fasi 45–48 chiuse (in particolare 47.6, `JamTrackInfoScreen`). Fase 30 (pagine artista online,
`lookupYtmArtist`, `pickYtmArtist`), fase 11.8 (link all'artista nel player).

**Riferimenti:** `docs/feature-streaming.md` (R-32, R-33, R-34, R-30; componente «Artisti»); decisioni D-74, D-76.
Fuori perimetro: link agli artisti nel mini player (D-74).

**Intoccabili (D-76):** libreria e playlist; i download di oggi; la fluidità. **Nessun pacchetto nuovo.** **Schema
del DB invariato (D-77).** `extractPrimaryArtist` e `pickYtmArtist` mantengono il comportamento di oggi (li usano
l'abbinamento dell'import e `auto_follow_service.dart`).

## Task

### 49.1 — `splitArtists` e `ArtistLinkResolver`
**File:** `lib/services/online/query_cleaner.dart` (`_artistSplit` → pubblico, `splitArtists(String)` che restituisce
nomi e separatori originali), `lib/services/online/artist_link_resolver.dart` (nuovo), un metodo di sola lettura
in `lib/data/repositories/library_queries.dart` (artista di libreria per chiave `lower(trim(nome))`, la stessa di
`watchArtists`, solo `kind = 0`), `test/services/online/query_cleaner_test.dart`,
`test/services/online/artist_link_resolver_test.dart`
1. `splitArtists(track)`: per un brano online gli `artists` del `YtResult` con i loro `artistIds` quando ci sono;
   per un brano di libreria lo split di `track.artist` con `_artistSplit` (`,`, `&`, `/`, `feat.`/`ft.`).
2. `ArtistLinkResolver.resolve(name, {ytmId})` → `LibraryArtist(ArtistSummary)` | `OnlineArtist(YtmArtistRef)` |
   `Choose(List<YtmArtistRef> primi 3)` | `NotFound`: prima la libreria; poi, se c'è `ytmId`, la pagina online
   diretta; altrimenti la ricerca con `pickYtmArtist` (esatto → pagina, più simili → scelta fra i primi 3, nessuno →
   messaggio). La rete parte solo dal tocco dell'utente.

R-34 (logica), parte di R-32.
**Fatto quando:** `flutter test test/services/online/query_cleaner_test.dart test/services/online/artist_link_resolver_test.dart`
verde: «A, B feat. C» → 3 nomi con i separatori originali; `extractPrimaryArtist` invariato (casi di oggi); risoluzione
con artista in libreria (nessuna rete), con `ytmId` (nessuna ricerca), online esatto, scelta fra 3 (con 5 trovati),
nessuno; una riga `kind = 2` con lo stesso artista non conta come «in libreria». `flutter analyze` pulito.

### 49.2 — Nomi toccabili nel player e nella barra desktop
**File:** `lib/ui/widgets/artist_links.dart` (nuovo), `lib/ui/screens/now_playing/now_playing_screen.dart`
(`_openArtist` → `ArtistLinks`), `lib/ui/shell/desktop_player_bar.dart`, `test/ui/artist_links_test.dart`
1. `ArtistLinks(track)`: una zona toccabile per nome, separatori non toccabili, bersagli ≥ 48 dp in altezza come il resto
   (fase 40), etichette di accessibilità per nome. Tocco → `ArtistLinkResolver` → pagina di libreria
   (`ShellNav.openInLibrary`) o pagina online (`ArtistPageScreen`) o foglio di scelta (`ArtistPickerSheet` di oggi) o
   messaggio.
2. Vale anche per i brani in streaming (oggi `onTap: online ? null : …`). Il mini player non cambia (D-74).

R-32.
**Fatto quando:** `flutter test test/ui/artist_links_test.dart` verde: 3 artisti → 3 zone toccabili, ognuna apre la
pagina giusta (resolver finto); un artista solo → una zona; nel player e nella barra desktop il widget c'è.
`flutter analyze` pulito.

### 49.3 — «Vai all'artista» con foglio di scelta
**File:** `lib/ui/widgets/track_artists_sheet.dart` (nuovo; nome diverso da `ArtistPickerSheet` di oggi, che sceglie fra
artisti di YouTube Music), `lib/ui/widgets/track_actions.dart` (`goToArtist`), `lib/ui/screens/online/online_song_row.dart`
(voce di 46.5), `lib/ui/screens/jam/jam_track_info_screen.dart` e menu ⋮ della riga della Jam, ARB,
`test/ui/track_artists_sheet_test.dart`
1. Un artista → apre la pagina (49.1). Più artisti → foglio con un nome per riga; il tocco su un nome risolve come 49.2.
2. Vale nel menu dei brani (libreria, righe online, brano in streaming) e nella schermata Jam.

R-33.
**Fatto quando:** `flutter test test/ui/track_artists_sheet_test.dart test/ui/track_actions_test.dart` verde: con 2+
artisti «Vai all'artista» apre il foglio con un nome per artista e il tocco su un nome apre la pagina giusta; con un
artista apre subito la pagina; la voce c'è nella schermata Jam. `flutter analyze` pulito.

### 49.4 — Controlli di fase (K-01, K-02)
1. K-01: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
2. K-02: `flutter test test/data/stream_rows_hidden_test.dart` verde.
3. `flutter analyze` pulito; `flutter test` verde.
(K-03, misura sul Mi A3: non prevista in questa fase da «Controlli a ogni fase».)

**Fatto quando:** i comandi dei punti 1–3 sono verdi.

### 49.5 — Prove a mano (utente) [~]
Materiale per l'utente (R-30, K-04). Su **Linux e Mi A3**:
- Brano di libreria «A, B feat. C»: nel player (e nella barra desktop su Linux) tre nomi toccabili; uno in libreria apre
  la pagina di libreria, uno che non c'è apre la pagina online o la scelta fra 3 (R-32, R-34).
- Brano in streaming con più artisti: stessi link, con gli artisti di YouTube Music (R-34).
- Menu ⋮ «Vai all'artista» con più artisti → foglio di scelta; anche dalla schermata Jam (R-33).
- Artista inventato senza risultati online → messaggio (R-34).
- Log senza 403/429 ripetuti dopo le prove (K-04).

**Fatto quando:** l'utente conferma le prove su Linux e Mi A3 (casella `[~]` → `[x]` in PROGRESS).
