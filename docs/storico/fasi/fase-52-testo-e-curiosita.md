# Fase 52 — Testo e curiosità complete

**Obiettivo:** `completeOne` sa cercare ogni parte (metadati, testo, sincronia, curiosità, crediti e dettagli) solo se
accesa, vuota e dovuta. Il testo passa da una catena LRCLIB → NetEase → lyrics.ovh; un «niente» si segna per parte con
la data e si riprova dopo 30 giorni; il testo scritto o scelto dall'utente non si tocca mai. Le curiosità escono dal
provider in un servizio e, con il nuovo interruttore «Curiosità automatiche», si cercano da sole. Dopo un download si
cerca tutto ciò che è acceso.

**Prerequisiti:** fasi 50–51 chiuse (`completeOne` parte crediti, `track_enrich` con `*_none_at` e `lyrics_by_user`,
«Aggiorna»). Fase 28 (`CuriosityFinder`, `CuriosityNotifier`), fase 11 (`LrclibClient`, «Testi automatici»),
fase 45/46 (`QuietEnricher` dopo il download).

**Riferimenti:** `docs/feature-arricchimento.md` (R-50, R-54, R-55, R-56; RNF-06, RNF-07; componenti «Catena del
testo», «`EnrichmentService`», «`CuriosityService`», «Stato per parte», «Download»; flusso (a); invarianti 1–3, 6;
rischi K-AR-01, K-AR-08); decisioni D-101, D-103, D-105, D-111, D-119, D-120, D-121, D-125.

**Intoccabili:** la catena parte da LRCLIB come oggi; `enrichMany`, `needsEnrichment`, `apply` e «Arricchisci»
invariati (K-AR-01); «Testi automatici» e «Arricchimento automatico» con il significato di oggi; il tag del file dopo
il download come oggi. **Nessun pacchetto nuovo.** **Schema invariato (v15).** Nessuna chiave nel codice.

## Task

### 52.1 — `NeteaseLyricsClient` e `LyricsOvhClient`
> Prima di questo task (review di fine fase 50): `WebClient.getJson` distingue 404 (null) da rete/5xx (eccezione), così si toglie `recordingsByIsrc(strict:)` e D-129; poi estrarre `CreditsEnricher` (`fetch`/`save`/`isDue`) da `EnrichmentService`, prima del 52.3.
**File:** `lib/services/online/netease_lyrics_client.dart`, `lib/services/online/lyrics_ovh_client.dart` (nuovi),
`lib/providers/online_providers.dart`, `test/fixtures/lyrics/` (nuova: `netease_search_get_lucky.json`,
`netease_lyric_get_lucky.json`, `lyrics_ovh_get_lucky.json`, `README.md`),
`test/services/online/lyrics_sources_test.dart` (nuovo)
1. Endpoint di NetEase verificati catturando le risposte **una volta** dal vivo (fuori dalla suite) e ridotte ai campi
   letti; esito e indirizzi nel `README.md` delle fixture.
2. `NeteaseLyricsClient.find(title, artist, durationSec)` → candidati con titolo, artista, durata e LRC;
   `LyricsOvhClient.find(artist, title)` → testo semplice. Timeout **8 s** ciascuno, un `WebClient`/`Dio` come gli
   altri client, 429 → `RateLimitedException` (RNF-06).
3. Risposta valida e vuota → `null`; errore → eccezione (per l'invariante 3).

Parte di R-55.
**Fatto quando:** `flutter test test/services/online/lyrics_sources_test.dart` verde: parsing delle fixture; timeout
oltre 8 s → errore; risposta vuota → `null`; 429 → `RateLimitedException`. `flutter analyze` pulito.

### 52.2 — `LyricsChain`
**File:** `lib/services/online/lyrics_chain.dart` (nuovo), `lib/services/online/enrichment_service.dart` (`propose` usa
la catena al posto di `lrclib`), `lib/ui/screens/lyrics/lyrics_view.dart` (ricerca a mano con la catena),
`test/services/online/lyrics_chain_test.dart` (nuovo)
1. `LyricsChain.find(track, {wantSynced})`: LRCLIB; se manca il sincronizzato → NetEase, accettato **solo** con titolo e
   artista uguali dopo `cleanSearchQuery` e durata entro **±3 s** (K-AR-08); se manca ogni testo → lyrics.ovh (semplice).
2. Restituisce anche se una fonte ha dato errore (per non segnare «niente», invariante 3).

R-55.
**Fatto quando:** `flutter test test/services/online/lyrics_chain_test.dart test/services/online/enrichment_service_test.dart`
verde con client finti: LRCLIB sincronizzato → nessuna chiamata alle altre; LRCLIB vuoto, NetEase con durata +5 s →
lyrics.ovh; NetEase «Get Lucky (Live)» o altro artista → scartato; NetEase giusto → sincronizzato; NetEase in errore e
lyrics.ovh vuoto → esito «errore», non «niente»; i test esistenti di `enrichment_service_test` verdi senza modifiche.
`flutter analyze` pulito.

### 52.3 — `enrich_parts.dart`: stato per parte e attesa di 30 giorni
**File:** `lib/services/online/enrich_parts.dart` (nuovo: `EnrichPart { meta, lyrics, synced, curio, credits }`,
`isDue(part, track, enrich, now)`), `lib/services/online/enrichment_service.dart` (`completeOne` decide con `isDue`),
`test/services/online/enrich_parts_test.dart` (nuovo)
1. `isDue` = parte vuota **e** (mai cercata **o** «niente» da più di 30 giorni); `synced` è dovuta solo se c'è un testo
   semplice non dell'utente e manca il sincronizzato.
2. `completeOne(trackId, parts, {force})`: cerca solo le parti accese e dovute (`force` = tutte le accese vuote, anche
   con «niente» recente); risposta valida e vuota → `*_none_at = now`; trovato → `*_none_at = null`; errore o 429 →
   niente (invariante 3). Una transazione per brano: colonne vuote di `tracks`, `track_credits`, `track_enrich`.
3. Funzione pura con orologio finto.

R-54.
**Fatto quando:** `flutter test test/services/online/enrich_parts_test.dart test/services/online/enrichment_credits_test.dart`
verde con orologio finto: «niente» al giorno 0 → non dovuta al giorno 29, dovuta al 31; testo semplice salvato il giorno
0 → sincronia richiesta al giorno 31 e non al 29; `force` → richiesta anche con «niente» di ieri; errore di rete → nessun
`*_none_at`. `flutter analyze` pulito.

### 52.4 — Testo dell'utente (`lyrics_by_user`) e guardie
**File:** `lib/data/repositories/track_repository.dart` (`setLyrics(..., byUser)` scrive anche
`track_enrich.lyrics_by_user`), `lib/providers/track_ops.dart`, `lib/ui/screens/lyrics/lyrics_view.dart` (risultato
scelto dall'utente → `byUser: true`), `lib/services/online/enrichment_service.dart`, `test/data/track_repository_test.dart`,
`test/services/online/enrich_guards_test.dart` (nuovo)
1. Oggi l'unica scrittura del testo da parte dell'utente è la scelta di un risultato in `lyrics_view.dart`: mette
   `lyrics_by_user = 1`. Ogni futura modifica a mano del testo passa da `setLyrics(byUser: true)`.
2. `completeOne` non chiama i client del testo se `lyrics_by_user = 1`; non scrive titolo/artista/album con
   `userEdited`; non scrive la copertina se `cover_source > 0` (la protezione completa degli altri scrittori è 54.3);
   scrive solo colonne vuote (invariante 1).

R-56.
**Fatto quando:** `flutter test test/data/track_repository_test.dart test/services/online/enrich_guards_test.dart` verde:
brano con testo scelto a mano → nessuna chiamata ai client del testo (neanche per la sincronia); brano `userEdited` →
titolo/artista/album invariati; brano con `cover_source = 2` → nessuna copertina scritta; brano con genere già
pieno → genere invariato. `flutter analyze` pulito.

### 52.5 — `CuriosityService`
**File:** `lib/services/online/curiosity_service.dart` (nuovo: la logica di `CuriosityNotifier.fetch`, cioè finder +
`setCuriosities` + `ArtistInfos.save`), `lib/providers/curiosity_provider.dart` (il notifier la chiama),
`lib/services/online/enrichment_service.dart` (parte `curio` di `completeOne`), `lib/ui/screens/now_playing/credits_card.dart`
(«Aggiorna» passa a `completeOne(force)` anche per le curiosità), `test/services/online/curiosity_service_test.dart` (nuovo),
`test/providers/curiosity_provider_test.dart`
1. Spostamento senza cambi di comportamento: stessi risultati e stessi errori del notifier di oggi; MBID condiviso con
   i crediti (una sola identificazione per brano, K-AR-07).
2. Pagina trovata vuota → `curio_none_at`; errore o 503 → niente.

Parte di R-50 (curiosità senza UI), R-54 (parte `curio`).
**Fatto quando:** `flutter test test/services/online/curiosity_service_test.dart test/providers/curiosity_provider_test.dart test/ui/credits_card_test.dart`
verde: il test di oggi del provider invariato; il servizio salva curiosità del brano e bio dell'artista senza
`ProviderContainer`; «Aggiorna» rifà anche le curiosità. `flutter analyze` pulito.

### 52.6 — «Curiosità automatiche» e arricchimento completo dopo il download
> Dalla review di fine fase 51: `trackCreditsProvider` e `artistCreditedProvider` sono `FutureProvider` invalidati solo da «Aggiorna»; quando i crediti arrivano in background (download, completamento) la card resta vecchia. Passarli a `StreamProvider.autoDispose.family` con un watch filtrato per `trackId` sulle due tabelle (non sugli stream di `tracks`, K-AR-04), togliere `ref.invalidate` in `credits_card.dart`, test «download → la card mostra i crediti».

**File:** `lib/data/settings/settings_store.dart` (`autoCuriosities`, di serie `false`),
`lib/ui/screens/settings/settings_pages.dart`, `lib/ui/screens/onboarding/onboarding_pages.dart` (proposto, D-105),
`lib/providers/online_providers.dart` (`downloadEnricherProvider`: `QuietEnricher` → `completeOne` con le parti
accese; `enabled` include `autoCuriosities` e `creditsDetails`), ARB con `scripts/arb_add.py`,
`test/data/settings_store_test.dart`, `test/services/online/quiet_enricher_test.dart`, `test/providers/download_promotion_test.dart`
1. Parti accese = metadati (`autoEnrich`), testo (`autoLyrics`), curiosità (`autoCuriosities`), crediti e dettagli
   (`creditsDetails`). Metadati e testo in parallelo, poi crediti e curiosità (flusso a).
2. Il tag del file con `DownloadTagger` resta dopo, come oggi (nessun credito nel file, D-110).
3. Interruttore spento = nessuna richiesta per quella parte (invariante 2).

R-50.
**Fatto quando:** `flutter test test/data/settings_store_test.dart test/services/online/quiet_enricher_test.dart test/providers/download_promotion_test.dart test/services/online/download_test.dart`
verde: download con tutto acceso → il brano ha testo, curiosità, crediti; curiosità spente → zero richieste al client
Wikipedia finto; tutto spento → nessuna chiamata (come oggi); `autoCuriosities` di serie `false`. `flutter analyze` pulito.

### 52.7 — Controlli di fase (K-AR-01, K-AR-02, K-AR-03, K-AR-04)
1. K-AR-01: `flutter test test/services/online/enrichment_service_test.dart test/services/online/enrichment_needs_test.dart
   test/services/online/enrichment_deezer_test.dart test/services/online/cover_for_album_test.dart
   test/services/online/curiosity_finder_test.dart test/providers/enrich_job_test.dart test/ui/lyrics_screen_test.dart` verde.
2. Download: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/ test/services/stream/stream_preparer_test.dart` verde.
3. K-AR-02: `flutter test test/services/backup/ test/data/backup_merge_test.dart test/data/duplicate_merge_test.dart
   test/services/stream/stream_promoter_test.dart` verde.
4. K-AR-03: `flutter test test/services/share/ test/ui/jam_track_info_screen_test.dart` verde.
5. K-AR-04/05: `flutter test test/data/stream_rows_hidden_test.dart test/data/playlist_repository_test.dart` verde.
6. RNF-06: `grep -rn "receiveTimeout\|Duration(seconds: 8)" lib/services/online/netease_lyrics_client.dart lib/services/online/lyrics_ovh_client.dart` ≥ 1 per file.
7. `flutter analyze` pulito; `flutter test` verde.

**Fatto quando:** i comandi dei punti 1–7 sono verdi.

### 52.8 — Prove a mano (utente)
Materiale per l'utente (D-125, D-126). Su **Linux e Mi A3** (`0d7ae9df206e`; `-k` ammesso, mai cancellare i file musicali):
- «Curiosità automatiche» c'è, spento; la guida iniziale lo propone (R-50).
- Tutti gli interruttori accesi: download di un brano → testo, curiosità, crediti e dettagli arrivano senza toccare
  niente; con le curiosità spente il brano non ha curiosità (R-50).
- Un brano senza testo su LRCLIB (raro, italiano o vecchio): testo da NetEase sincronizzato e giusto, o da lyrics.ovh
  semplice (R-55); nessun testo di un'altra versione (K-AR-08).
- Un brano con testo scelto a mano: «Aggiorna» e download di nuovo non lo cambiano (R-56).
- Log senza 429 ripetuti né timeout a raffica di NetEase/lyrics.ovh.
Sul **Motorola edge 40** (`ZY22HKD85K`, D-125): prima di installare chiedere all'utente un backup completo dall'app e
annotare dove sta; `adb -s ZY22HKD85K install -r <apk>`; firma diversa → fermarsi, l'utente conferma il backup,
`adb uninstall -k`, installare e ripristinare; mai cancellare file musicali. Poi, con «Crediti e dettagli» e
«Curiosità automatiche» accesi (D-126): un download completo; i testi dei brani modificati a mano invariati.

**Fatto quando:** l'utente conferma le prove su Linux, Mi A3 e Motorola (casella `[ ]` → `[x]` in PROGRESS).
