# Fase 51 — Crediti a schermo

**Obiettivo:** crediti e dettagli salvati nella fase 50 si vedono. Nella schermata di riproduzione c'è la card
«Crediti e dettagli» accanto alle Curiosità (dettagli in cima, poi i gruppi, «Mostra tutto» oltre 8 righe,
«Aggiorna»), con i nomi che portano alla pagina artista. La stessa sezione è nella schermata info brano della Jam e
nell'anteprima dell'arricchimento. La pagina artista ha «Compare come», la ricerca locale il gruppo «Nei crediti».
Crediti e dettagli viaggiano nel backup, nell'invio e nella Jam.

**Prerequisiti:** fase 50 chiusa (tabelle v15, `CreditsRepository`, `completeOne` parte crediti). Fase 49
(`ArtistLinkResolver`, `ArtistLinks`), fase 47.4 e 47.6 (rotta `meta`, `JamTrackInfoScreen`), fase 37 (`TrackMeta`).

**Riferimenti:** `docs/feature-arricchimento.md` (R-42…R-48, R-57; RNF-07; componenti «Tabella dei ruoli», «Card e
schermate», «Backup e invio»; invariante 5; rischi K-AR-01, K-AR-02, K-AR-03); decisioni D-99, D-100, D-107, D-118,
D-119, D-120, D-125.

**Intoccabili:** `InfoCard` e le Curiosità di oggi; le query delle liste non leggono `track_credits`/`track_enrich`
(invariante 5); `ArtistLinkResolver` invariato (lo riusa). Un backup o un `TrackMeta` senza i campi nuovi si legge
come oggi. **Nessun pacchetto nuovo.** **Schema invariato (v15).** Nessun editor dei crediti (D-107).

## Task

### 51.1 — Tabella dei ruoli e traduzioni
> Dalla review di fine fase 50: decidere qui se `TrackCredit.mbid` (artista) serve, altrimenti toglierlo (non ha colonna); spostare `TrackDetails` da `deezer_models.dart` a `credits.dart`. La ricerca per nome usa `creditNameKey()`, non `matchKey()`.
**File:** `lib/services/online/credit_roles.dart` (nuovo), `lib/l10n/app_it.arb`, `app_en.arb`, `app_de.arb`,
`app_es.arb`, `app_fr.arb`, `app_pt.arb` (con `scripts/arb_add.py`, poi `flutter gen-l10n`),
`test/services/online/credit_roles_test.dart` (nuovo), `test/l10n/arb_test.dart`
1. Ruolo normalizzato → gruppo (`performers` Interpreti e strumenti / `writers` Autori / `production` Produzione e
   tecnici / `other` Altro) + getter ARB `creditRole…` (ruoli presenti nelle fixture della fase 50 più quelli comuni
   di MusicBrainz: strumenti, voce, produttore, mix, master, programmazione, compositore, paroliere…).
2. Ruolo non in tabella → testo grezzo con `_` → spazio, gruppo `other`.
3. Titoli dei 4 gruppi, «Crediti e dettagli», «Mostra tutto», «Aggiorna», «Compare come», «Nei crediti» nelle 6 lingue.

R-43.
**Fatto quando:** `flutter test test/services/online/credit_roles_test.dart test/l10n/arb_test.dart` verde:
`drumprogrammer` → «Programmazione batteria» in it e una stringa non vuota nelle altre 5; `drum machine drums` → testo
grezzo; `main_artist` → «main artist»; ogni chiave `creditRole…` presente in tutti e 6 gli ARB. `flutter analyze` pulito.

### 51.2 — `CreditsSection` e card nella schermata di riproduzione
**File:** `lib/ui/widgets/credits_section.dart` (nuovo), `lib/ui/screens/now_playing/credits_card.dart` (nuovo),
`lib/ui/screens/now_playing/now_playing_screen.dart` (card accanto a `InfoCard`), `lib/providers/credits_providers.dart`
(nuovo: crediti e dettagli di un brano da `CreditsRepository`, letti a parte, non dagli stream di `tracks`),
`test/ui/credits_card_test.dart` (nuovo)
1. `CreditsSection(credits, details)`: in cima i dettagli in righe brevi (BPM · etichetta · ©; date di uscita e tipo;
   classifica e fan; bollino «esplicito»), poi i gruppi di 51.1 in quest'ordine; oltre **8** righe di crediti si chiude
   con «Mostra tutto». Un nome con più ruoli = una riga con i ruoli uniti.
2. Ogni nome è un link (R-44): tocco → `ArtistLinkResolver.resolve(name)` → pagina di libreria, pagina online, foglio
   di scelta o messaggio, come `ArtistLinks` (fase 49). Bersagli ≥ 48 dp ed etichette di accessibilità (fase 40).
3. Nessun credito e nessun dettaglio → la card non c'è.

R-42, R-44.
**Fatto quando:** `flutter test test/ui/credits_card_test.dart test/ui/now_playing_test.dart test/ui/info_card_test.dart`
verde: brano con 12 crediti → 8 righe + «Mostra tutto», dopo il tocco 12; dettagli in cima con `bpm` assente → riga senza
BPM; brano senza niente → nessuna card; tocco su un nome in libreria apre la pagina locale, su uno assente quella
online (resolver finto); i test di oggi del player verdi. `flutter analyze` pulito.

### 51.3 — «Aggiorna» nella card
**File:** `lib/ui/screens/now_playing/credits_card.dart`, `lib/providers/credits_providers.dart`,
`test/ui/credits_card_test.dart`
1. «Aggiorna» → `completeOne(trackId, {credits}, force: true)` (ignora crediti presenti e `credits_none_at`) e la
   ricerca delle curiosità del brano con `CuriosityNotifier.fetch` di oggi (la fase 52 la sposta in `completeOne`).
2. Durante la ricerca indicatore nel pulsante; a fine ricerca la card si rilegge; errore di rete → messaggio, dati di
   prima intatti.
3. Con «Crediti e dettagli» spento il pulsante non c'è (interruttore della fase 50).

R-45.
**Fatto quando:** `flutter test test/ui/credits_card_test.dart` verde: brano con `credits_none_at` di ieri → tocco →
una nuova richiesta ai client finti e la card mostra i crediti nuovi; errore → messaggio e crediti di prima; interruttore
spento → nessun pulsante. `flutter analyze` pulito.

### 51.4 — Crediti e dettagli nel backup, nell'invio e nella Jam
> Dalla review di fine fase 50: `CreditsRepository` diventa l'unico scrittore di `track_credits`/`track_enrich` (`moveInto` per `DuplicateRepository._mergeCredits`, `saveIfNone` per backup e invio); l'invariante «crediti e `credits_none_at` mai insieme» in un posto solo.
**File:** `lib/services/backup/user_data.dart` (`TrackUserData.credits`, `details` facoltativi),
`lib/data/repositories/backup_queries.dart`, `lib/data/repositories/backup_merge.dart`,
`lib/services/share/track_meta.dart` (`credits` max 200, `details` facoltativi), `lib/services/share/received_meta.dart`,
`lib/services/jam/jam_host.dart`, `test/services/backup/user_data_test.dart`, `test/data/backup_merge_test.dart`,
`test/services/share/track_meta_test.dart`, `test/services/share/received_meta_test.dart`
1. `user_data.json`: per brano `credits` e `details` solo se presenti; l'unione scrive solo se il brano non ne ha.
2. `TrackMeta`: campi nuovi facoltativi, `fromJson` per chiave (chi non li conosce li ignora, K-AR-03); oltre 200
   crediti si tronca. `received_meta.dart` li salva con `CreditsRepository` solo se il brano non ne ha.
3. La rotta `meta` della Jam (47.4) porta crediti e dettagli dal proprietario.

R-57 (crediti e dettagli; la copertina a mano nel backup è nella fase 54).
**Fatto quando:** `flutter test test/services/backup/user_data_test.dart test/data/backup_merge_test.dart test/services/share/track_meta_test.dart test/services/share/received_meta_test.dart test/services/share/meta_travel_test.dart`
verde: andata e ritorno di `user_data` e `TrackMeta` con crediti e dettagli; `user_data.json` e `TrackMeta` vecchi
(senza i campi) letti senza errori; `TrackMeta` nuovo letto dal `fromJson` di oggi (campi ignorati); 250 crediti → 200;
ricezione su un brano che ha già crediti → invariati. `flutter analyze` pulito.

### 51.5 — Sezione nella Jam e nell'anteprima dell'arricchimento
**File:** `lib/ui/screens/jam/jam_track_info_screen.dart`, `lib/ui/screens/enrich_preview_dialog.dart`
(`EnrichmentProposal` con crediti e dettagli dalla fase 50), `test/ui/jam_track_info_screen_test.dart`,
`test/ui/enrich_preview_dialog_test.dart` (nuovo)
1. `JamTrackInfoScreen` (host e ospiti): `CreditsSection` con i dati locali o, per l'ospite, quelli del `TrackMeta`.
2. `EnrichPreviewDialog`: la proposta mostra crediti e dettagli trovati con `CreditsSection` (sola lettura).

R-46.
**Fatto quando:** `flutter test test/ui/jam_track_info_screen_test.dart test/ui/enrich_preview_dialog_test.dart` verde:
brano con crediti → sezione presente in entrambe le schermate (ospite con `TrackMeta` che ha crediti); senza → assente.
`flutter analyze` pulito.

### 51.6 — «Compare come» nella pagina artista
**File:** `lib/data/repositories/credits_repository.dart` (`creditedTracks(nameKey)`: brani `kind = 0` per
`name_key`, con il ruolo), `lib/ui/screens/library/artist_screen.dart`, `test/data/credits_repository_test.dart`,
`test/ui/artist_screen_test.dart`
1. Query su `track_credits` JOIN `tracks` (`kind = 0`, non mancanti né ignorati), chiave `creditNameKey(nome artista)`.
2. Sezione «Compare come»: un gruppo per ruolo (titolo tradotto con 51.1), brani toccabili come le altre righe; nessun
   brano → nessuna sezione. Solo dalla libreria (D-119).

R-47.
**Fatto quando:** `flutter test test/data/credits_repository_test.dart test/ui/artist_screen_test.dart` verde: artista
produttore di 2 brani e autore di 1 → 2 gruppi con 2 e 1 brano; una riga `kind = 2` con lo stesso credito non conta;
artista senza crediti → nessuna sezione. `flutter analyze` pulito.

### 51.7 — Gruppo «Nei crediti» nella ricerca locale
**File:** `lib/data/repositories/library_search.dart` (gruppo `credited` in `LibrarySearchResults`),
`lib/ui/screens/search/search_screen.dart`, `test/data/library_search_test.dart`, `test/ui/search_screen_test.dart`
1. Il testo cercato confrontato con `name_key` (prefisso, come la ricerca di oggi), solo `kind = 0`; via i brani già
   nei risultati normali.
2. Il gruppo sta sotto i risultati normali; vuoto → assente. La query gira solo alla ricerca, mai nelle liste.

R-48.
**Fatto quando:** `flutter test test/data/library_search_test.dart test/ui/search_screen_test.dart` verde: «Pharrell»
trova Get Lucky (credito) nel gruppo «Nei crediti» e non due volte; un brano con «Pharrell» nell'artista sta solo nei
risultati normali; nessun credito → nessun gruppo. `flutter analyze` pulito.

### 51.8 — Controlli di fase (K-AR-01, K-AR-02, K-AR-03, K-AR-04)
1. K-AR-01: `flutter test test/services/online/enrichment_service_test.dart test/services/online/enrichment_needs_test.dart
   test/services/online/enrichment_deezer_test.dart test/services/online/cover_for_album_test.dart
   test/providers/curiosity_provider_test.dart test/ui/info_card_test.dart` verde.
2. Download: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
3. K-AR-02: `flutter test test/services/backup/ test/data/backup_merge_test.dart test/data/backup_queries_test.dart
   test/data/duplicate_merge_test.dart test/services/stream/stream_promoter_test.dart` verde.
4. K-AR-03: `flutter test test/services/share/ test/ui/jam_track_info_screen_test.dart test/jam/` verde.
5. K-AR-04 e copertine playlist: `flutter test test/data/stream_rows_hidden_test.dart test/data/performance_lists_test.dart
   test/data/library_search_test.dart test/data/playlist_repository_test.dart test/ui/architecture_test.dart` verde.
6. Invariante 5: `grep -rn "track_credits\|track_enrich" lib/data/repositories/library_queries.dart lib/data/repositories/light_tracks.dart lib/data/repositories/library_entries.dart` = 0.
7. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–7 sono verdi.

### 51.9 — Prove a mano (utente)
Materiale per l'utente (D-125). Su **Linux e Mi A3** (`0d7ae9df206e`; `-k` ammesso, mai cancellare i file musicali):
- Get Lucky arricchito con «Crediti e dettagli» acceso: card con BPM, etichetta, ©, date e i gruppi; «Mostra tutto»;
  tocco su Pharrell → pagina di libreria se c'è, altrimenti online (R-42, R-44).
- Lingua dell'app in inglese e in francese: ruoli tradotti, uno sconosciuto grezzo (R-43).
- «Aggiorna» su un brano senza crediti: nuova ricerca, la card compare se trova qualcosa (R-45).
- Jam fra Linux e Mi A3: info brano con i crediti su host e ospite (R-46, R-57); anteprima «Arricchisci» con i crediti.
- Pagina artista di un produttore: «Compare come»; ricerca «Pharrell»: gruppo «Nei crediti» (R-47, R-48).
- Backup su Linux e ripristino in unione sul Mi A3: i crediti ci sono (R-57).
Sul **Motorola edge 40** (`ZY22HKD85K`, D-125): prima di installare chiedere all'utente un backup completo dall'app e
annotare dove sta; `adb -s ZY22HKD85K install -r <apk>`; firma diversa → fermarsi, l'utente conferma il backup,
`adb uninstall -k`, installare e ripristinare; mai cancellare file musicali. Poi: card, «Compare come» e «Nei crediti»
sui brani già arricchiti della libreria vera; scorrimento di Brani e Album fluido come prima.

**Fatto quando:** l'utente conferma le prove su Linux, Mi A3 e Motorola (casella `[ ]` → `[x]` in PROGRESS).
