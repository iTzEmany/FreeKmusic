# Fase 14 — Download più robusti e più veloci

**Obiettivo:** togliere le cause principali di «non funziona più» e di importazioni lente: yt-dlp vecchio sul
desktop, coda sequenziale, 403 transitori, ricodifiche inutili, ricerche ripetute. A fine fase un'importazione di
34 brani sul telefono dura sensibilmente meno di ~25 min e un 403 non lascia righe «con errori» da sistemare a mano.
**Prerequisiti:** Fase 5 (yt-dlp, `DownloadQueue`), Fase 12 (motore d'importazione). Consigliata la 13 (export log).
**Principio:** la rete parte solo da un'azione dell'utente. Il **controllo di versione** di yt-dlp è locale
(`yt-dlp --version`); lo **scaricamento** di un nuovo yt-dlp avviene solo toccando «Aggiorna».

> ⚠️ Come in Fase 5 parte B: scaricare da YouTube viola i suoi Termini d'uso. Uso strettamente personale.

## Decisioni
| Tema | Scelta |
|---|---|
| yt-dlp sul desktop | Ordine di ricerca: `<appSupport>/bin/yt-dlp[.exe]` (scaricato dall'app) → cartella dell'eseguibile dell'app (installer Windows, fase 26) → `/app/bin` (Flatpak, fase 26) → `yt-dlp` nel PATH. Stesso ordine per `ffmpeg`. Versione minima `kMinYtDlpVersion = '2025.11.12'` (prima: niente `--js-runtimes`, vedi R19) |
| Aggiornamento | Binario ufficiale dall'ultima release di `github.com/yt-dlp/yt-dlp` (`yt-dlp_linux`, `yt-dlp_linux_aarch64`, `yt-dlp.exe`), verificato con `SHA2-256SUMS` della stessa release; il precedente resta come `.old` |
| yt-dlp su Android | Invariato: `MainActivity.updateOnce()` aggiorna già al primo uso per sessione. Si mostra solo la versione |
| Parallelismo | Impostazione «Download contemporanei» 1–3, predefinito **2**. Le **ricerche** restano una alla volta con 1,5 s di pausa (R20) |
| Limite di banda | Impostazione 0 (nessuno) / 500 KB/s / 1 MB/s / 2 MB/s → `--limit-rate` (desktop e canale Android) |
| Ritento | A scalare **solo** su errori transitori (`network`, `changed`/403): 3 tentativi dopo 5 s, 20 s, 60 s (± 20 %). `rateLimited` non si ritenta: pausa come oggi. Sostituisce il ritento singolo di fase 12 (`_retried`) |
| Formato | «MP3 256 kbps» (oggi) o «Originale, senza ricodifica» (Opus/M4A così com'è); predefinito MP3 finché 14.1 non conferma tag e riproduzione |
| ISRC | Primo tentativo per le righe con ISRC: ricerca su YouTube Music per ISRC; accettato **solo** se `decide` dà `sure` |
| Cache ricerche | `<appSupport>/search_cache.json`, chiave = tipo + query normalizzata, scadenza 30 giorni, max 2.000 voci; solo per l'importazione |
| Controllo durata | Dopo il download: durata reale del file vs `Duration (ms)` del CSV; scarto > 10 s → riga «da verificare» (file tenuto) |
| Limiti | CSV ≤ 5 MB e ≤ 10.000 righe; ricerca yt-dlp con timeout 45 s e processo terminato |
| Pacchetti nuovi | Nessuno (`dio`, `crypto` ci sono già) |

## Task

### 14.1 — Verifiche preliminari
1. **Linux:** asset dell'ultima release di yt-dlp (`curl -s https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest`):
   nomi esatti dei binari, presenza di `SHA2-256SUMS`, formato di `yt-dlp --version` (es. `2026.08.19`).
2. `--limit-rate 500K` su un download vero: la velocità si abbassa? Annota.
3. ISRC: per 5 righe di `test/fixtures/Just_a_mood.csv` prova
   `yt-dlp -J --playlist-items 1-3 "https://music.youtube.com/search?q=<ISRC>#songs"`: quante restituiscono il brano
   giusto al primo posto? Se meno di 3 su 5, **14.8 si salta** (annota in PROGRESS).
4. Formato originale: scarica un brano con `-f bestaudio -x` (senza `--audio-format`): estensione ottenuta
   (`.opus`/`.m4a`), lettura con `AudioMetadataTagReader` (durata, titolo) e riproduzione su Linux (mpv) e Mi A3 (ExoPlayer).
5. Android: `YoutubeDL.getInstance().version(context)` (controlla il nome nel sorgente della libreria
   `youtubedl-android` 0.18.1) per mostrare la versione.
**Verifica:** note in PROGRESS. Se il formato originale non si riproduce o non ha durata su una piattaforma,
**fermati e riporta** (14.7 resta solo MP3).

### 14.2 — Versione di yt-dlp e avviso «troppo vecchio»
**File:** `lib/services/online/yt_dlp_version.dart`, `yt_dlp_process_service.dart`, `youtube_service.dart`,
`android_yt_dlp_service.dart`, `MainActivity.kt`, `test/services/online/yt_dlp_version_test.dart`
1. `YtDlpVersion? parseYtDlpVersion(String out)` (`AAAA.MM.GG` con eventuale `.N`), `compareTo`.
2. `Future<String?> YoutubeService.toolVersion()`; desktop: `<exe> --version`; Android: metodo `version` sul canale.
3. Nuovo `YtErrorKind.toolOutdated`; all'avvio su desktop (in background, non nel thread UI) se la versione è
   < `kMinYtDlpVersion` → banner in Cerca e nel Centro Attività «yt-dlp è troppo vecchio» con «Aggiorna».
**Test:** parsing di `2024.04.09`, `2026.08.19`, `2026.08.19.1`, testo non valido; confronto con la minima.

### 14.3 — Aggiornamento di yt-dlp in-app (desktop)
**File:** `lib/services/online/yt_dlp_updater.dart`, `lib/providers/youtube_providers.dart`,
`test/services/online/yt_dlp_updater_test.dart`
1. `YtDlpUpdater(WebClient web, String binDir)` (interfaccia di `http_client.dart`; per i byte del binario aggiungi un metodo di download o usa `DioWebClient` con lo stesso `User-Agent`): `latest()` legge la release (dio, timeout 8/15 s, `User-Agent`
   dell'app), sceglie l'asset per piattaforma/architettura, scarica in `<bin>/yt-dlp.download`, verifica SHA-256
   contro `SHA2-256SUMS`, `chmod +x` su Linux, sposta il vecchio in `.old`, rinomina in modo atomico.
2. Hash diverso → file scaricato rimosso (è nostro), errore chiaro, vecchio binario intatto.
3. `youtubeServiceProvider`: `YtDlpProcessService(executable: <bin>/yt-dlp se esiste>)`; dopo l'aggiornamento il
   provider si invalida. Impostazioni → «Download» → riga «yt-dlp <versione> · Aggiorna».
**Test:** con server finto (adattatore dio): asset giusto per Linux x64/arm64 e Windows; hash sbagliato → errore e
nessun file sostituito; scrittura atomica.

### 14.4 — Download in parallelo
**File:** `lib/services/online/download_queue.dart`, `youtube_providers.dart`, `settings_store.dart`,
`test/services/online/download_test.dart`
1. `DownloadQueue(maxParallel:)`; `_pump` avvia fino a N `_runOne`; `maxParallel` modificabile a caldo.
2. `_removeStalePartFiles` oggi gira a ogni `resolveDownloadFolder` (cioè a ogni download): con più download attivi
   cancellerebbe file in corso → spostalo a **una volta all'avvio della coda** (prima del primo download).
3. Impostazione `downloadParallel` (1–3, predefinito 2) nella nuova sezione «Download» delle Impostazioni
   (`lib/ui/screens/settings/downloads_section.dart`, `settings_screen.dart` è già lungo).
**Test:** downloader finto con completer: mai più di N in corso; annullare uno non ferma gli altri; ordine di avvio
= ordine di arrivo; `maxParallel` cambiato a metà.

### 14.5 — Limite di banda
**File:** `yt_dlp_process_service.dart`, `android_yt_dlp_service.dart`, `MainActivity.kt`, `settings_store.dart`
1. `download(..., {int? rateLimitKBps})` sull'interfaccia `YoutubeService`; desktop `--limit-rate <n>K`; Android argomento
   `rateLimit` → `req.addOption("--limit-rate", "${n}K")`.
2. Impostazione `downloadRateLimitKBps` (0 = nessuno) nella sezione «Download».
**Test:** argomenti costruiti (estrai `buildDownloadArgs` puro e testalo). **Tocca a te:** download sul Mi A3 con 500 KB/s.

### 14.6 — Ritento a scalare
**File:** `lib/services/online/retry_policy.dart`, `download_queue.dart`, `playlist_import_service.dart`,
`activity_sheet.dart`, `test/services/online/retry_policy_test.dart`
1. `RetryPolicy({attempts: 3, delays: [5 s, 20 s, 60 s], jitter: 0.2})`, `Duration? nextDelay(int attempt, YtErrorKind k)`
   (null = non ritentare). Generatore casuale e attesa iniettabili (niente orologio reale nei test).
2. `DownloadItem.attempt` e stato `waitingRetry` con `retryAt`; la coda rimette l'elemento dopo l'attesa.
   `onSettled` arriva solo all'esito **definitivo**.
3. Togli `_retried` da `PlaylistImportService._onSettled` (ora lo fa la coda per tutti i download).
4. Centro Attività: «Nuovo tentativo tra 20 s (2/3)».
**Test:** `network` → 3 ritenti e poi `failed`; `rateLimited` → nessun ritento; `unavailable` → nessun ritento;
annullato durante l'attesa → `cancelled`; test esistenti del servizio d'importazione aggiornati.

### 14.7 — Formato: MP3 o originale senza ricodifica
**File:** `yt_dlp_process_service.dart`, `android_yt_dlp_service.dart` (`convert` esiste già nel canale),
`settings_store.dart`, sezione «Download», ARB
1. Impostazione `downloadFormat`: `mp3` | `original`. Originale: `-f bestaudio[ext=m4a]/bestaudio -x` senza
   `--audio-format` (ffmpeg rimuxa senza ricodificare); senza ffmpeg resta il contenitore scaricato (`.webm`/`.m4a`,
   già tra le estensioni scansionate).
2. `uniquePath` oggi riceve l'estensione prima del download: per `original` cerca l'uscita con `_findOutput`.
**Test:** argomenti per i due formati (desktop e mappa del canale). Solo se 14.1 punto 4 è positivo.

### 14.8 — Ricerca per ISRC come primo tentativo
**File:** `playlist_import_service.dart` (`_find`), `test/services/import/playlist_import_service_test.dart`
1. Riga con `isrc`: `searchSongs(isrc, limit: 3)` → `decide`; solo `sure` viene accettato, altrimenti il flusso attuale
   (titolo+artista) riparte **senza** contare quei risultati (un ISRC sbagliato non deve alzare il punteggio).
2. 1,5 s di pausa anche dopo la ricerca per ISRC.
**Test:** ISRC che dà `sure` → una sola ricerca; ISRC che dà `review` → ricerca per titolo; riga senza ISRC → invariata.

### 14.9 — Cache delle ricerche
**File:** `lib/services/online/search_cache.dart`, `lib/services/online/cached_youtube_service.dart`,
`import_providers.dart`, `test/services/online/search_cache_test.dart`
1. `SearchCache(File f, {ttl: 30 giorni, max: 2000})`: `get/put`, scrittura con debounce, voci più vecchie scartate
   (LRU per `usedAt`); file illeggibile → cache vuota + `AppLog.w`.
2. `CachedYoutubeService implements YoutubeService` (decoratore) usato **solo** da `playlistImportServiceProvider`; la
   ricerca interattiva di Cerca resta sempre fresca. Chiave: `songs|<query>|<limit>`, `plain|<query>`.
3. Impostazioni → «Download» → «Svuota cache ricerche (N voci)».
**Test:** colpo/mancato, scadenza, limite di voci, file corrotto; reimport della stessa playlist con servizio finto →
zero chiamate di rete.

### 14.10 — Controllo della durata a fine download
**File:** `playlist_import_service.dart` (`_finishDownload`), `import_review_screen.dart`, ARB (+ test)
1. Dopo la scansione, `track.durationMs` vs `row.durationMs`: scarto > 10 s → stato `review` con il candidato scaricato
   in testa (già in libreria, «Tieni questo») e nota «durata diversa: 3:58 invece di 3:12». Il file **non** si cancella.
2. Il brano entra comunque nella playlist (l'utente può toglierlo).
**Test:** scarto 4 s → `downloaded`; scarto 40 s → `review` con nota; durata CSV ignota → `downloaded`.

### 14.11 — Validazioni: CSV troppo grandi e ricerche bloccate
**File:** `import_intro_sheet.dart`, `exportify_reader.dart`, `yt_dlp_process_service.dart`, `android_yt_dlp_service.dart`,
`MainActivity.kt`, ARB (+ test)
1. Prima di `readAsBytes`: `File.length()` > 5 MB → messaggio nel foglio («file troppo grande per una playlist»);
   più di 10.000 righe → `FormatException` dedicata.
2. Ricerche desktop con `Process.start` + `timeout(45 s)` → `kill` → `YtErrorKind.network`. Android: `processId` anche
   per `search` e `cancel` al timeout lato Dart.
**Test:** lettore con 10.001 righe sintetiche → errore; ricerca con un `yt-dlp` finto che dorme (script in
`test/support/`, solo Linux, `skip` altrove) → timeout e processo terminato.

### 14.12 — ~~(Opzionale) Impronta audio con Chromaprint~~ — SCARTATO
**Scartato il 2026-10-19 su richiesta dell'utente: niente chiave API personale (AcoustID). Non va implementato.**
**Punto di stop: chiedi all'utente prima di iniziare.** Senza un servizio esterno l'impronta non dice «quale brano è»:
serve AcoustID, che richiede una **chiave API** (vietata nel codice, regola 9). Proposta da far approvare:
1. Solo desktop, solo se `fpcalc` è nel PATH; chiave AcoustID **inserita dall'utente** nelle Impostazioni, opzione
   spenta di default.
2. Dopo il download: `fpcalc -json` → lookup AcoustID → se il MBID/titolo non corrisponde alla riga del CSV → `review`.
Se l'utente non approva: segna `[x]` con nota «non fatto per scelta» in PROGRESS.

### 14.13 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es completi.
2. `docs/02-architettura.md` (coda parallela, ritento, cache, aggiornatore), `docs/99-rischi-e-fallback.md` (R27–R30;
   aggiorna R19 e R21), README (sezione «Download»).
3. Misura: importazione di `Just_a_mood.csv` sul PC con 1 e con 2 download contemporanei (tempo totale in PROGRESS).
**Tocca a te (Linux + Mi A3):** yt-dlp di sistema vecchio → avviso → «Aggiorna» → ricerca funziona; importazione di
34 brani con 2 download contemporanei; un 403 recuperato da solo; reimport con cache (nessuna ricerca).

## Fuori da questa fase
Aggiornamento di yt-dlp su Windows con firma GPG, scelta della qualità per bitrate, download di video, SoundCloud e
playlist YouTube come sorgente (fase 22), importazione da altri formati (fase 15).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R27 | Binario yt-dlp scaricato compromesso o troncato | Solo HTTPS da GitHub, SHA-256 da `SHA2-256SUMS` della stessa release, rinomina atomica, `.old` per tornare indietro |
| R28 | Più download insieme → più 403/429 | Predefinito 2, massimo 3; ricerche sempre sequenziali; ritento a scalare con jitter; `rateLimited` mette in pausa |
| R29 | Formato originale non leggibile da tag reader o player | Verifica in 14.1; predefinito MP3; il DB tiene comunque i tag del CSV |
| R30 | Cache con risultati vecchi (video rimosso) | Scadenza 30 giorni; un download fallito per `unavailable` cancella la voce di cache della riga |

## Definition of Done
- [ ] Avviso «yt-dlp troppo vecchio» e aggiornamento in-app verificato con hash sul desktop
- [ ] 2–3 download contemporanei, limite di banda, ritento a scalare (solo errori transitori)
- [ ] Formato «originale» disponibile se 14.1 l'ha confermato
- [ ] ISRC come primo tentativo (se 14.1 l'ha confermato), cache delle ricerche, controllo della durata
- [ ] CSV troppo grandi rifiutati con messaggio; ricerche con timeout
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
