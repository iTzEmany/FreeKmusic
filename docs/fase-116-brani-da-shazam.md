# Fase 116 — Brani da Shazam

**Obiettivo:** un brano riconosciuto in Shazam e condiviso verso Codecore va in cima alla playlist «Da Shazam» (creata da sola), senza doppioni, ascoltabile in streaming e, se l'utente lo chiede, scaricato; un testo che non si capisce apre Cerca. **Cambi di comportamento voluti** (D-515, D-516, D-519, D-522, D-524, D-529): una condivisione `text/plain` di Shazam non apre più Cerca come testo generico; compare la playlist «Da Shazam» (con uuid in preferenze), solo Android; un'impostazione nuova «Scarica i brani da Shazam» (spenta di serie).

**Prerequisiti:** fase 115 chiusa. **Un testo vero condiviso da Shazam (R-210)** salvato in `test/fixtures/shazam/`: dall'utente, o dal Mi A3 con Shazam installato (da verificare che si possa senza account). Se manca, `/obiettivo` lo mette in «Tocca a te» (chiedendo all'utente di condividere un brano da Shazam verso un'app qualsiasi e incollare il testo) e **ferma la fase**: niente lettore scritto «a occhio». Requisiti: R-201..R-205, R-209, R-210 (`docs/feature-link-e-shazam.md`, Flusso (c)). Rischio 8 (testo diverso per lingua o versione).

**Comando mirato:** `flutter test test/services/online/shared_text_test.dart test/providers/shazam_providers_test.dart test/ui/shazam_snackbar_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

## Task

### 116.1 — Lettore del testo e «Da Shazam» (R-201..R-205, R-206, R-209, R-210)
- `lib/services/online/shared_text.dart`: ramo `ShazamShare(title, artist, shazamUrl?)`, **prima** del link (un testo con `shazam.com` non è un link da aprire). Ordine: (1) una frase modello per lingua, una regex per fixture vera (es. «… scoprire <titolo> di <artista>.» / «… discover <title> by <artist>.», da confermare); (2) se c'è `shazam.com/track/<id>/<slug>` e la frase non torna: lo slug non basta → `PlainShare` (R-209). Mai rete per capire il testo, mai una riga inventata. Ogni fixture nuova = una riga nella tabella del test.
- `lib/providers/shazam_providers.dart` (nuovo): `ShazamInbox.add(ShazamShare)`: `CollectionMatcher` su un brano; non trovato → avviso «Non trovato su YouTube Music: <titolo>» con «Cerca» (Cerca con titolo e artista, R-205), nessuna riga. Trovato → playlist da `settings.shazamPlaylistUuid`; manca o cancellata → creata «Da Shazam» e salvato l'uuid. Doppione (R-203): stesso track id **o** stessa `libraryTitleKey(titolo)|matchKey(artista)` → resta dov'è, avviso «già in Da Shazam». Altrimenti `PlaylistRepository.addAtTop` (della 115.1, con `ensureStreamRow`). Poi avviso «Aggiunto a Da Shazam: <brano>» con «Ascolta» (`playFromSearch`, R-202) e, se `shazamAutoDownload`, `downloadsProvider.add(r)` (R-204). Senza rete: avviso con «Riprova» che ripete `add` (R-206).
- `lib/data/settings/settings_store.dart` + `settings_providers.dart` + schermata impostazioni (sezione Download o YouTube): `readShazamAutoDownload()`/`write…` (di serie `false`), `readShazamPlaylistUuid()`/`write…`; voce visibile **solo su Android** (D-522). `app_shell.dart`: il testo condiviso passa da `routeSharedText`; `ShazamShare` → `ShazamInbox.add`. ARB in tutte le lingue; avvisi con etichette TalkBack.
- Fixture: `test/fixtures/shazam/*.txt` (testi veri).
- Test: `test/services/online/shared_text_test.dart` (fixture vere; testo non capito → `PlainShare`), `test/providers/shazam_providers_test.dart` (playlist creata e ritrovata per uuid, cancellata → ricreata, brano in cima, doppione per id e per titolo+artista, non trovato → nessuna riga, download solo con l'impostazione), `test/ui/shazam_snackbar_test.dart` (avviso e «Ascolta» → `playFromSearch`; «Cerca» → Cerca con la query; «Riprova»).
- Comando: `flutter test test/services/online/shared_text_test.dart test/providers/shazam_providers_test.dart test/ui/shazam_snackbar_test.dart`

### 116.2 — Controlli di fase
`flutter analyze`; comando mirato; review del diff (Sonnet); scheggia passo e fase. Mi A3 (`0d7ae9df206e`): lo stesso `am start` con i testi delle fixture (e, se Shazam c'è, una condivisione vera): primo brano → «Da Shazam» creata; stesso brano due volte → una riga; impostazione accesa → download; testo qualsiasi → Cerca; «Svuota» la cache → «Da Shazam» intera. Poi togliere playlist, download e preferenze di prova.

**Fatto quando:** un brano condiviso da Shazam finisce in cima a «Da Shazam» senza doppioni, ascoltabile e, se chiesto, scaricato; un testo non capito apre Cerca; il lettore è scritto su testi veri; i test sono verdi.

## Da decidere
(nessuno)
