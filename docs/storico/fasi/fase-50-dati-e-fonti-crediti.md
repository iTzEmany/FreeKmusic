# Fase 50 — Dati e fonti dei crediti

**Obiettivo:** il database sa tenere crediti, dettagli e stato per parte (schema **v15**, un solo passo di
migrazione); l'app sa leggerli da tre fonti (API interna di Deezer, API pubblica di Deezer, MusicBrainz) e unirli
senza doppioni. Con il nuovo interruttore «Crediti e dettagli» acceso (spento di serie) l'arricchimento di oggi
(«Arricchisci», anteprima, righe ombra dello streaming) salva crediti e dettagli; con «Scarica» e con l'unione dei
doppioni non si perdono. Niente ancora a schermo (fase 51).

**Prerequisiti:** fasi 45–49 chiuse. Fase 36 (`DeezerClient`, `pickDeezerTrack`, cooldown), fase 28
(`CuriosityFinder`, `MusicBrainzClient`), fase 45 (righe ombra `kind = 2`), fase 46.3 (`StreamPromoter`).

**Riferimenti:** `docs/feature-arricchimento.md` (R-35…R-41, R-49; RNF-06, RNF-07; «Architettura», «Dati»,
«Invarianti» 2, 3, 6, 7; rischi K-AR-01, K-AR-02, K-AR-06, K-AR-07); decisioni D-97, D-98, D-105, D-106, D-108,
D-109, D-110, D-121, D-122, D-123, D-124, D-125.

**Intoccabili:** «Arricchisci», `enrichMany`, `needsEnrichment` e `apply` mantengono firma e comportamento di oggi
(K-AR-01); «Metadati da Deezer» invariato; nessun dato di arricchimento scritto nel file musicale (D-110).
**Nessun pacchetto nuovo.** **Schema v15 in questa fase e solo qui:** le fasi 51–54 non cambiano lo schema.
**Nessuna chiamata di rete nei test:** le risposte vere si catturano una volta (50.2) e diventano fixture.

## Task

### 50.1 — Schema v15 e migrazione 14 → 15
**File:** `lib/data/db/tables.dart` (`TrackCredits`, `TrackEnrich`, `ActivityLogRows`, `Tracks.coverSource`),
`lib/data/db/app_database.dart` (`kSchemaVersion = 15`, passo `if (from < 15)`), `lib/data/db/app_database.g.dart`
(rigenerato con `dart run build_runner build --delete-conflicting-outputs`), `test/data/migration_test.dart`
1. `track_credits(track_id → tracks ON DELETE CASCADE, name, name_key, role, source)`, PK `(track_id, name_key, role)`,
   indice su `name_key`.
2. `track_enrich(track_id PK → tracks ON DELETE CASCADE, details TEXT, deezer_id, mbid, meta_none_at,
   lyrics_none_at, synced_none_at, curio_none_at, credits_none_at, lyrics_by_user BOOL DEFAULT 0)`.
3. `tracks.cover_source INT NOT NULL DEFAULT 0` (0 automatica, 1 a mano d'album, 2 a mano del brano; usata dalla
   fase 54).
4. `activity_log(id, at, kind, name, done, total, failed, detail TEXT)`, indice su `at` (usata dalla fase 53).
5. Nello stesso passo, per le righe esistenti: `enrich_status = 2` → riga in `track_enrich` con `meta_none_at` = ora
   della migrazione e `lyrics_none_at` = ora solo se il testo manca (D-103); `user_edited = 1` con testo →
   `lyrics_by_user = 1` (D-121). Nessun altro dato cambia; `enrich_status` resta.
6. Verificare che `_checkStagedDatabase` di `lib/services/backup/restore_service.dart` accetti un `.sqlite` v14 (si
   aggiorna con `onUpgrade` all'apertura); se lo rifiuta, correggere qui (K-AR-02).

Base dei dati per le fasi 50–54 (i requisiti si chiudono nei task che usano le tabelle).
**Fatto quando:** `flutter test test/data/migration_test.dart test/services/backup/restore_service_test.dart` verde con
un caso nuovo «v14 → v15»: le 4 strutture esistono; una riga `enrich_status = 2` senza testo ha `meta_none_at` e
`lyrics_none_at`, una con testo solo `meta_none_at`; una riga `user_edited = 1` con testo ha `lyrics_by_user = 1`,
una `user_edited = 1` senza testo no; i dati di `tracks` sono identici prima e dopo; il ripristino di un backup v14
non dà errore. `flutter analyze` pulito.

### 50.2 — Fixture reali di Deezer e MusicBrainz
**File:** `test/fixtures/deezer/gw_user_data.json`, `gw_page_track_lose_yourself.json`,
`gw_page_track_one_more_time.json`, `gw_invalid_token.json`, `track_details.json` (`/track/{id}` con `bpm > 0`),
`track_bpm_zero.json`, `album_details.json` (tutti nuovi), `test/fixtures/deezer/README.md`,
`test/fixtures/musicbrainz/recording_credits_get_lucky.json` (nuovo)
1. Catturare **una volta** dal vivo (curl o uno script nello scratchpad, mai nella suite) le risposte di
   `deezer.getUserData`, `deezer.pageTrack` (Lose Yourself, One More Time), `/track/{id}`, `/album/{id}` e
   `/ws/2/recording/{mbid}?inc=artist-rels+work-rels+work-level-rels` (Get Lucky), con User-Agent e una richiesta
   al secondo (RNF-06).
2. Ridurle ai campi letti da Codecore (come le fixture di oggi), togliere cookie, token e `sid`; una riga per file
   nel `README.md` (data, richiesta, cosa mostra). `gw_invalid_token.json` può essere costruito a mano: dirlo.
3. Verificare sulle fixture se `/search` porta il BPM (architettura: «da verificare»); l'esito in una riga del
   README e in una nota di PROGRESS.

Base dei test di R-37, R-38, R-39 (K-AR-06).
**Fatto quando:** i file esistono, `grep -rn "sid\|checkForm\|api_token" test/fixtures/deezer/*.json` non trova
valori veri di sessione; `flutter analyze` pulito.

### 50.3 — `credits.dart`: modello, parser e `mergeCredits`
**File:** `lib/services/online/credits.dart` (nuovo), `test/services/online/credits_test.dart` (nuovo)
1. `TrackCredit(name, nameKey, role, source)`; `nameKey` = `creditNameKey(name)` (senza maiuscole e accenti); ruolo
   normalizzato in minuscolo.
2. `parseDeezerContributors(Map)`: `SNG_CONTRIBUTORS` (ruolo → lista di nomi), più `COPYRIGHT` e
   `PHYSICAL_RELEASE_DATE` restituiti a parte per i dettagli.
3. `parseMbCredits(Map)`: relazioni del recording verso artisti (strumento o voce dagli `attributes`, produttore,
   mix, programmazione, registrazione) e del work (compositore, paroliere, autore); relazioni work→work e verso
   non-artisti scartate; MBID dell'artista tenuto.
4. `mergeCredits(deezer, mb)`: funzione pura, Deezer prima, MusicBrainz aggiunge solo le coppie `nameKey + role`
   che mancano (D-108).

R-40, parsing di R-38 e R-39.
**Fatto quando:** `flutter test test/services/online/credits_test.dart` verde: Lose Yourself e One More Time dalle
fixture → ruoli e nomi attesi, copyright e data fisica letti; Get Lucky → 6 strumenti, 2 voci, 2 produttori,
4 autori, nessuna relazione work→work; Deezer {composer: A}, MB {composer: «á», guitar: B} → A compositore una
volta, B chitarra. `flutter analyze` pulito.

### 50.4 — `DeezerGwClient`: sessione anonima e pausa di 24 ore
**File:** `lib/services/online/deezer_gw_client.dart` (nuovo), `lib/providers/online_providers.dart` (provider),
`test/services/online/deezer_gw_client_test.dart` (nuovo)
1. Un suo `Dio` con POST (come `InnerTubeClient`): `deezer.getUserData` → `checkForm` + cookie `sid`, poi
   `deezer.pageTrack(SNG_ID)` → `parseDeezerContributors`. Token scaduto/non valido → nuova sessione **una volta**,
   poi errore.
2. Interruttore: 3 errori di fila (rete, formato, token) → pausa di 24 h salvata in `shared_preferences` (resta dopo
   il riavvio, D-124); un successo azzera il contatore. In pausa nessuna chiamata. All'entrata in pausa una riga
   nel Registro (`activityLogProvider`; diventa persistente nella fase 53) tramite un callback `onPaused`.
3. 429 o errore di rete non segnano mai «niente» (invariante 3): restituiscono un errore distinto da «vuoto».
4. Nessuna chiave nel codice (RNF-06).

R-38 (client), R-41.
**Fatto quando:** `flutter test test/services/online/deezer_gw_client_test.dart` verde con `Dio` finto e orologio
finto: sessione + `pageTrack` dalle fixture; token scaduto → una sola nuova sessione, poi errore; 3 errori di fila →
nessuna chiamata per 24 h (anche con un client nuovo che rilegge le preferenze), alla 24ª ora + 1 di nuovo chiamate;
`onPaused` chiamato una volta. `flutter analyze` pulito.

### 50.5 — Dettagli dall'API pubblica di Deezer
**File:** `lib/services/online/deezer_client.dart`, `lib/services/online/deezer_models.dart` (`TrackDetails`:
`bpm?`, `label`, `digitalReleaseDate`, `recordType`, `rank`, `albumFans`, `explicit`, più `copyright` e
`physicalReleaseDate` riempiti da 50.4; `toJson`/`fromJson`), `test/services/online/deezer_client_test.dart`
1. `trackDetails(deezerId)`: `/track/{id}` (BPM, `rank`, `explicit_lyrics`) e `/album/{id}` (`label`, `fans`,
   `record_type`, `release_date`), riusando l'album se `_deezerLookup` l'ha già letto. Stesso `cooldown`/`isResting`
   di oggi (RNF-06).
2. `bpm: 0` o assente → nessun BPM.

R-37.
**Fatto quando:** `flutter test test/services/online/deezer_client_test.dart test/services/online/enrichment_deezer_test.dart`
verde: tutti i campi letti dalle fixture reali; `track_bpm_zero.json` → `bpm == null`; `TrackDetails` fa andata e
ritorno in JSON; i casi esistenti invariati. `flutter analyze` pulito.

### 50.6 — `MusicBrainzClient.recordingCredits`
**File:** `lib/services/online/musicbrainz_client.dart`, `lib/services/online/curiosity_finder.dart` (esporre l'MBID
già trovato da `_identify`), `test/services/online/musicbrainz_credits_test.dart` (nuovo)
1. `recordingCredits(mbid)`: una chiamata `/recording/{mbid}?inc=artist-rels+work-rels+work-level-rels` →
   `parseMbCredits`. Stessa istanza (`musicBrainzClientProvider`), stesso distacco di 1,1 s e nuovo tentativo su 503
   di oggi (RNF-06, K-AR-07).
2. L'MBID viene da `CuriosityFinder` (se già cercato) o da `recordingsByIsrc`; nessuna ricerca in più.
3. 503 dopo il nuovo tentativo → errore (non «vuoto»).

R-39 (client).
**Fatto quando:** `flutter test test/services/online/musicbrainz_credits_test.dart test/services/online/musicbrainz_isrc_test.dart test/services/online/curiosity_finder_test.dart`
verde: fixture Get Lucky → crediti attesi con una sola richiesta; due chiamate di fila distano ≥ 1,1 s (orologio
finto); 503 due volte → errore; i casi esistenti invariati. `flutter analyze` pulito.

### 50.7 — `CreditsRepository` e interruttore «Crediti e dettagli»
**File:** `lib/data/repositories/credits_repository.dart` (nuovo: `creditsOf`, `enrichOf`, `saveCredits`,
`saveEnrich` in una transazione), `lib/data/settings/settings_store.dart` (`creditsDetails`, di serie `false`),
`lib/ui/screens/settings/settings_pages.dart` (tile accanto a «Metadati da Deezer», nota «usa anche un'API non
ufficiale di Deezer»), `lib/ui/screens/onboarding/onboarding_pages.dart` (proposto accanto a «Arricchimento
automatico», D-105), ARB con `scripts/arb_add.py` (6 lingue), `test/data/credits_repository_test.dart` (nuovo),
`test/data/settings_store_test.dart`
1. Il repository scrive `track_credits` (sostituzione per `track_id`) e `track_enrich` (upsert); nessuna scrittura su
   `tracks` (invariante 5, K-AR-04).
2. L'impostazione va nel backup come le altre.

R-35 (impostazione).
**Fatto quando:** `flutter test test/data/credits_repository_test.dart test/data/settings_store_test.dart test/l10n/arb_test.dart`
verde: crediti salvati e riletti, nuova scrittura sostituisce; `saveEnrich` non emette su `watchTracks`;
`creditsDetails` di serie `false`, salvato e riletto. `flutter analyze` pulito.

### 50.8 — Crediti e dettagli nell'arricchimento (`completeOne`, parte crediti)
**File:** `lib/services/online/enrichment_service.dart` (`propose`/`apply` e nuovo `completeOne(trackId, parts,
{force})`), `lib/providers/online_providers.dart` (cablaggio dei client), `test/services/online/enrichment_credits_test.dart` (nuovo)
1. Con `creditsDetails` acceso `propose` cerca l'id Deezer (ISRC, poi testo con `pickDeezerTrack`) **anche con
   «Metadati da Deezer» spento**, senza proporre metadati (R-36); poi `trackDetails`, `DeezerGwClient.pageTrack` (se
   non in pausa) e, con l'MBID, `recordingCredits` → `mergeCredits`.
2. `apply` salva crediti, dettagli, `deezer_id`, `mbid` con `CreditsRepository`; risposta valida e vuota →
   `credits_none_at = ora`; errore di rete/429 → niente (invariante 3). Una fonte che fallisce non ferma le altre.
3. `completeOne` (per ora solo la parte crediti e dettagli; le altre parti arrivano nella fase 52): salta se ci sono
   già crediti o `credits_none_at`, salvo `force`.
4. Interruttore spento → nessuna chiamata a `DeezerGwClient` né a `recordingCredits` (R-35). Firma e comportamento di
   `enrichMany`, `needsEnrichment` e dei rami di oggi invariati (K-AR-01).

R-35, R-36.
**Fatto quando:** `flutter test test/services/online/enrichment_credits_test.dart test/services/online/enrichment_service_test.dart test/services/online/enrichment_needs_test.dart`
verde con client finti: interruttore spento → zero chiamate ai due client dei crediti; metadati Deezer spenti e
crediti accesi → id trovato, dettagli e crediti salvati, titolo/anno/genere invariati; Deezer interna in pausa →
solo MusicBrainz; 503 di MusicBrainz → nessun `credits_none_at`; entrambe vuote → `credits_none_at` messo; i test di
oggi verdi senza modifiche. `flutter analyze` pulito.

### 50.9 — «Scarica» e doppioni non perdono i crediti
**File:** `lib/data/repositories/track_repository.dart` (`mergeStreamRow`),
`lib/data/repositories/duplicate_repository.dart` (`merge`), `test/data/track_repository_test.dart`,
`test/data/duplicate_merge_test.dart`, `test/services/stream/stream_promoter_test.dart`
1. Prima della cancellazione della riga che sparisce, nella stessa transazione: le righe di `track_credits` passano
   al brano che resta se questo non ne ha; `track_enrich` si unisce campo per campo (vince il valore non nullo del
   brano che resta, `lyrics_by_user` = OR). Poi la cancellazione (il CASCADE non trova più niente da perdere).

R-49.
**Fatto quando:** `flutter test test/data/track_repository_test.dart test/data/duplicate_merge_test.dart test/services/stream/stream_promoter_test.dart`
verde con casi nuovi: riga ombra con 3 crediti e dettagli → «Scarica» → il brano di libreria ha gli stessi 3 crediti
e dettagli; doppione con crediti unito in uno senza → crediti spostati; brano che resta con crediti propri → i suoi
restano. `flutter analyze` pulito.

### 50.10 — Controlli di fase (K-AR-01, K-AR-02, K-AR-03, K-AR-04, K-AR-05)
1. K-AR-01 (arricchimento, RNF-07): `flutter test test/services/online/enrichment_service_test.dart
   test/services/online/enrichment_needs_test.dart test/services/online/enrichment_deezer_test.dart
   test/services/online/cover_for_album_test.dart test/services/online/quiet_enricher_test.dart
   test/providers/enrich_job_test.dart test/providers/curiosity_provider_test.dart` verde.
2. Download: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/ test/providers/download_promotion_test.dart` verde.
3. K-AR-02 (backup, unioni): `flutter test test/data/migration_test.dart test/services/backup/
   test/data/backup_merge_test.dart test/data/backup_queries_test.dart test/data/duplicate_merge_test.dart
   test/services/stream/stream_promoter_test.dart` verde.
4. K-AR-03 (Jam e invio): `flutter test test/services/share/track_meta_test.dart test/services/share/meta_travel_test.dart
   test/services/share/received_meta_test.dart test/ui/jam_track_info_screen_test.dart test/jam/` verde.
5. K-AR-04/K-AR-05 (liste, righe ombra, copertine): `flutter test test/data/stream_rows_hidden_test.dart
   test/data/performance_lists_test.dart test/data/playlist_repository_test.dart test/services/library_scanner_test.dart` verde.
6. Invariante 7: `grep -rn "credits\|TrackCredit" lib/services/library/download_tagger.dart lib/services/tags/tag_writer.dart` = 0.
7. `flutter analyze` pulito; `flutter test` verde.
(Misura sul Mi A3: non prevista in questa fase da «Controlli a ogni fase».)

**Fatto quando:** i comandi dei punti 1–7 sono verdi.

### 50.11 — Prove a mano (utente)
Materiale per l'utente (D-125, D-126). Build: `flutter build apk --debug --build-number=5000 --target-platform android-arm64`;
`flutter run -d linux` sul PC.
Su **Linux e Mi A3** (`0d7ae9df206e`; si può disinstallare con `-k`, mai cancellare i file musicali):
- Impostazioni: «Crediti e dettagli» c'è, spento, con la nota sull'API non ufficiale; la guida iniziale lo propone (R-35).
- Acceso, con «Metadati da Deezer» spento: «Arricchisci» su Get Lucky e Lose Yourself → titolo/anno/genere invariati;
  in `codecore.sqlite` (cartella dati dell'app) righe in `track_credits` e `track_enrich` per quei brani (R-36…R-40).
- Un brano in streaming suonato e poi «Scarica»: le righe di `track_credits` sono sul brano di libreria (R-49).
- Log senza errori ripetuti di `deezer_gw` né 503 a raffica di MusicBrainz.
Sul **Motorola edge 40** (`ZY22HKD85K`, libreria vera, D-125):
- Prima di installare: chiedere all'utente un backup completo dall'app e annotare dove sta (nota in PROGRESS).
- `adb -s ZY22HKD85K install -r <apk>`. Firma diversa → fermarsi, l'utente conferma il backup, poi
  `adb uninstall -k` del pacchetto, installazione e ripristino del backup. Mai cancellare file musicali.
- **Migrazione:** all'apertura la libreria c'è tutta (2196 brani, 1917 con testo), playlist, cronologia e copertine
  uguali; i brani modificati a mano con testo hanno `lyrics_by_user = 1` (controllo con `run-as` o con la copia del DB
  del backup); nessun errore nel log (K-AR-02).
- «Crediti e dettagli» acceso su pochi brani con «Arricchisci»: solo parti vuote, niente cambia nei brani modificati a mano (D-126).

**Fatto quando:** l'utente conferma le prove su Linux, Mi A3 e Motorola (casella `[ ]` → `[x]` in PROGRESS).
