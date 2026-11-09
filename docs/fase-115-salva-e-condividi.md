# Fase 115 — Salva in Libreria, «Aggiorna» e «Condividi verso Codecore»

**Obiettivo:** una pagina di link (Spotify, Deezer) si salva in Libreria come playlist normale che suona in streaming e sopravvive a pulizia della cache e backup; «Aggiorna» rilegge l'originale; un link condiviso dal menu «Condividi» di Android apre la pagina. **Cambi di comportamento voluti** (D-518, D-520, D-522, D-524, D-528): **le playlist possono contenere brani in streaming** (righe `kind = 2`), cosa che oggi non succede (`addTracks` le scarta, `watchTracks` legge solo `kind = 0`); la pulizia della cache non cancella le righe che stanno in una playlist; il backup portabile le conserva; `IncomingBridge` accetta anche testo (`text/plain`).

**Prerequisiti:** fase 114 chiusa. Requisiti: R-193, R-198, R-200 (`docs/feature-link-e-shazam.md`, «Dati», «Componenti», Flusso (b)). **Area a rischio K-02** (righe ombra in playlist): rischio 5; rischio 3 (`IncomingBridge` ZIP/CSV). Rischi da sorvegliare per primi (D-528): 5 (pulizia/backup). Schema DB **invariato**.

**Comando mirato:** `flutter test test/data/playlist_repository_test.dart test/data/playlist_sync_repository_test.dart test/data/stream_rows_hidden_test.dart test/data/track_repository_test.dart test/services/backup/ test/providers/online_collection_providers_test.dart test/ui/online_playlist_screen_test.dart test/services/android/incoming_files_test.dart test/services/online/shared_text_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

## Task

### 115.1 — Righe in streaming nelle playlist (D-524, rischio 5; **`/code-review high`**)
- `TrackRepository.ensureStreamRow(YtResult)`: crea (o ritrova) la riga ombra `kind = 2`, `path = stream:<indexKey>`, titolo/artista/durata.
- `lib/data/repositories/playlist_repository.dart`: `addStreamTracks` accetta `kind = 2` (`addTracks` resta com'è, `:145`); `addAtTop` (posizione 0 e rinumerazione, una transazione, per la 116); `watchTracks` (`:128`) e conteggio/durata di `watchAll` → `kind IN (0, 2)` **solo per le playlist**; `nameTaken` accanto a `nameOf`.
- `deleteUnplayedStreamRows`: non cancella righe presenti in `playlist_tracks` (`onDelete: cascade`).
- Backup portabile (`backup_queries.dart:23` esclude `kind = 2`): le righe ombra in playlist viaggiano come `TrackRef` con la chiave dello stream; il restore le ricrea con `ensureStreamRow`.
- Export M3U, sync delle playlist fra dispositivi, Android Auto: righe `kind = 2` saltate con un `AppLog.i` (conferma punto per punto: se un punto non regge, si scrive in «Da decidere» e ci si ferma).
- Lo scarico di un brano ombra sposta già le playlist sul brano di libreria (`mergeStreamRow` → `DuplicateRepository.merge`): nessun cambio, solo il test che la posizione resta.
- Le playlist intelligenti, «Tutti i brani», Album e Artisti restano `kind = 0`.
- Test: `test/data/playlist_repository_test.dart` (righe nuove: `addStreamTracks`, `addAtTop`, `watchTracks` con `kind = 2`, conteggio), `test/data/stream_rows_hidden_test.dart` (verde, più un caso: riga ombra in playlist non compare in «Tutti i brani»), `test/data/track_repository_test.dart` (**pulizia della cache con playlist: le righe restano**, quelle fuori playlist senza ascolti no), `test/services/backup/` (**backup → restore: playlist uguale**, stesso ordine, righe ombra ricreate), sync e M3U (righe saltate con log).
- Comando: `flutter test test/data/playlist_repository_test.dart test/data/playlist_sync_repository_test.dart test/data/stream_rows_hidden_test.dart test/data/track_repository_test.dart test/services/backup/`

### 115.2 — «Salva in Libreria» e «Aggiorna» (R-198, R-200)
- `lib/providers/online_collection_providers.dart`: `saveToLibrary`: nome = titolo (con « (2)» se esiste, `nameTaken`), per ogni `ready` nell'ordine della pagina: brano di libreria → il suo id, online → riga ombra (`ensureStreamRow`); solo `ready`; una transazione. L'originale che cambia non tocca la copia.
- `refresh()` («Aggiorna», R-200, solo esterni): rilegge, tiene le righe con la stessa `key` già abbinate, abbina solo le nuove, toglie le sparite dalla pagina (la copia salvata non cambia).
- `online_playlist_screen.dart`: voci «Salva in Libreria» e «Aggiorna» nel menu ⋮ (la seconda solo per gli esterni); ARB in tutte le lingue; etichette TalkBack.
- Test: `test/providers/online_collection_providers_test.dart` (playlist creata con i `ready` nell'ordine della pagina; nome con suffisso se esiste; Aggiorna con un brano in più → **un solo** abbinamento nuovo; brani tolti spariscono dalla pagina e non dalla copia), `test/ui/online_playlist_screen_test.dart` (voci del menu).
- Comando: `flutter test test/providers/online_collection_providers_test.dart test/ui/online_playlist_screen_test.dart`

### 115.3 — Testo condiviso e «Condividi verso Codecore» (R-193, D-522, D-520; rischio 3)
- Kotlin `IncomingBridge.kt`: `ACTION_SEND` con `EXTRA_STREAM` → percorso di oggi, **sempre prioritario** e solo se il tipo è zip/csv o il nome finisce così; altrimenti `EXTRA_TEXT` (+ `EXTRA_SUBJECT`) → `pendingText`, metodo `takeIncomingText`, push `incomingText`. `AndroidManifest.xml`: `intent-filter` **separato** `SEND` + `text/plain`.
- `lib/services/android/incoming_files.dart`: `IncomingFiles.texts()`; `lib/providers/exportify_providers.dart`: `incomingTextProvider`; `app_shell.dart:340` lo ascolta accanto a `incomingPathProvider`.
- `lib/services/online/shared_text.dart` (nuovo, puro): `SharedText routeSharedText(String text, {String? subject})` → `SharedLink(url)` (primo URL YouTube/Spotify/Deezer o breve nel testo) \| `PlainShare(text)`; il ramo `ShazamShare` arriva nella 116. La shell: link → `searchPrefillProvider` + `showSearch` (come incollato, R-193); altro → Cerca con il testo.
- Test: `test/services/android/incoming_files_test.dart` (canale finto: testo e file separati, uno ZIP/CSV segue sempre il percorso di oggi), `test/services/online/shared_text_test.dart` (tabella: link Spotify/Deezer/YouTube/breve in mezzo a testo, nessun link → `PlainShare`).
- Comando: `flutter test test/services/android/incoming_files_test.dart test/services/online/shared_text_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`

### 115.4 — Controlli di fase
`flutter analyze`; comando mirato; **review di architettura Opus** (tocca righe ombra e backup) e `/code-review high` su 115.1; scheggia di passo `high` su 115.1 e di fase. Prova sul Mi A3 (`0d7ae9df206e`): `adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "<link>" com.codecore.player` con un link Spotify breve, uno Deezer e uno YouTube, con l'app chiusa e aperta; condividere lo ZIP Exportify di prova → anteprima d'import come oggi; «Salva in Libreria» → playlist che suona in streaming; «Svuota» la cache di streaming → la playlist è intera; backup e ripristino → playlist uguale; un brano scaricato dalla playlist → resta in posizione; «Aggiorna» su una pagina. A fine prova togliere playlist, download e preferenze di prova, mai i file musicali.

**Fatto quando:** un link condiviso apre la pagina, una pagina salvata è una playlist che suona in streaming e sopravvive a pulizia e backup, «Aggiorna» abbina solo i brani nuovi; ZIP/CSV invariati; i test sono verdi.

## Da decidere
(nessuno)
