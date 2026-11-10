# Fase 5 — Funzioni online: arricchimento, testi, YouTube

**Obiettivo:** metadati/copertine/testi da fonti web e download da YouTube, senza i difetti della
versione Python (sovrascritture silenziose, timeout finti, falsi positivi).
**Prerequisiti:** Fase 4. Leggi `04-specifiche-da-python.md` per intero (è la fonte delle regole).
**Principio:** ogni chiamata di rete parte da un'azione dell'utente o da un'opzione esplicitamente attiva.

## Parte A — Arricchimento metadati e testi

### 5.1 — HTTP di base
**File:** `lib/services/online/http_client.dart`
`Dio` condiviso: `connectTimeout 8 s`, `receiveTimeout 15 s`, header `User-Agent: Codecore/1.0 (uso personale)`,
`validateStatus` che non lancia su 404. Wrapper `Future<T?> getJson(...)` che logga e restituisce `null` su errore.
Supporto a un `CancelToken` e a un `RateLimiter(minGap: Duration(seconds: 3))` riusabile.

### 5.2 — `QueryCleaner`
**File:** `lib/services/online/query_cleaner.dart`, `test/services/online/query_cleaner_test.dart`
`cleanSearchQuery`, `extractPrimaryArtist`, `coreTitle` come in `04` §1–3. Test: **tutta** la tabella di `04` §1 + 5 casi tuoi.

### 5.3 — Client iTunes
**File:** `lib/services/online/itunes_client.dart`, test con risposte JSON finte (`test/fixtures/itunes_*.json`)
`Future<ItunesMatch?> search(String title, String artist)` secondo `04` §4 (query in ordine, punteggio, **soglia di accettazione**).
Test: (1) match esatto; (2) stesso titolo ma artista diverso → `null`; (3) nessun risultato → `null`; (4) "Intro" di artista ignoto non prende un altro artista.

### 5.4 — Client LRCLIB + parser LRC
**File:** `lrclib_client.dart`, `lrc_parser.dart` (+ test)
Come `04` §5. `LyricsResult { String? plain; String? synced; }`. Test parser: tag, offset, più timestamp, millisecondi 2/3 cifre.

### 5.5 — Client Wikipedia
**File:** `wikipedia_client.dart` — come `04` §6. Restituisce `Curiosity { String text; Uri source; String lang }`.

### 5.6 — `EnrichmentService`
**File:** `lib/services/online/enrichment_service.dart`
```dart
class EnrichmentProposal { final Track track; final ItunesMatch? meta; final LyricsResult? lyrics;
                           final Curiosity? curiosity; final String? coverUrl; }
Future<EnrichmentProposal> propose(Track t, {CancelToken? cancel});
Future<void> apply(EnrichmentProposal p, {required Set<EnrichField> fields});
Stream<BatchProgress> enrichMany(List<int> ids, {required bool onlyEmptyFields, CancelToken? cancel});
```
Regole (non negoziabili):
1. `propose` **non scrive** nulla; `apply` scrive solo i campi scelti.
2. Mai sovrascrivere `title/artist/album` se `userEdited == true`.
3. Nel batch (`enrichMany`): riempi **solo campi vuoti** (`onlyEmptyFields = true` di default); mai cambiare titolo/artista.
4. `enrichStatus`: 1 se qualcosa trovato, 2 se nulla (non ritentare nel batch finché l'utente non forza).
5. Un solo job alla volta (`enrichmentJobProvider` rifiuta il secondo avvio con messaggio).
6. `CancelToken` rispettato tra una richiesta e l'altra; pulsante Annulla nel progresso.
7. Rate limit 3 s tra brani; su 403/429 interrompi e avvisa ("Servizio non disponibile, riprova più tardi").
8. La copertina scaricata va in `cover_store` (limite 5 MB, solo `https`) e aggiorna `coverKey` per **tutto l'album**
   solo se l'album non ne ha già una (o l'utente sceglie "Sostituisci").
**Test:** `apply` rispetta `userEdited`; batch non tocca campi pieni; secondo job rifiutato.

### 5.7 — UI arricchimento
- Brano → menu "Cerca info sul web": mostra un dialog **anteprima** (campi attuali ↔ proposti, checkbox per campo, miniatura copertina) con "Applica" / "Annulla".
- Album → "Arricchisci album" (batch con barra di progresso e Annulla).
- Impostazioni → "Arricchisci tutta la libreria" (batch, conferma esplicita con stima del tempo: N brani × 3 s).
- Stato in UI: spinner nel punto da cui è partito, risultato in snackbar ("12 aggiornati, 3 non trovati").

### 5.8 — Schermata testi
**File:** `lib/ui/screens/lyrics/lyrics_screen.dart`
- Da Now Playing (pulsante "Testo"). Se non ci sono testi → "Cerca testo" (LRCLIB) con anteprima.
- Se `lyricsSynced` presente: lista di righe, riga corrente evidenziata e **centrata** con scroll animato
  (`Scrollable.ensureVisible`/`ScrollController.animateTo`), tap su una riga = seek a quel punto.
  Calcolo riga corrente con ricerca binaria su posizione (non scorrere tutta la lista a ogni tick).
- Altrimenti testo semplice scorrevole. Pulsante "Copia".
- `reducedMotion` → niente animazioni di scroll.
- Sezione "Curiosità" (Wikipedia) con link alla fonte e dicitura "Fonte: Wikipedia (CC BY-SA)".

## Parte B — Download da YouTube

> ⚠️ Aspetti legali: scaricare da YouTube viola i suoi Termini d'uso e può violare il copyright.
> Questa funzione è per uso strettamente personale ed è **esclusa** da qualunque build destinata al Play Store.
> Metti il codice dietro `const bool kEnableYoutube = true;` in `lib/core/constants.dart` così si può spegnere in un punto solo.

### 5.9 — `YoutubeService`
**File:** `lib/services/online/youtube_service.dart`
Con `youtube_explode_dart` (controlla l'API reale nel sorgente installato):
1. `Future<List<YtResult>> search(String query)` — se l'input è un URL YouTube valido, risolvi direttamente il video.
   **Correzione:** considera URL solo se `Uri.tryParse` ha host `youtube.com`, `www.youtube.com`, `m.youtube.com` o `youtu.be`.
2. `Stream<DownloadProgress> download(YtResult r, Directory outDir, {CancelToken})`:
   - manifest → stream **solo audio**, preferisci container `mp4` (m4a), bitrate più alto; altrimenti `webm`/opus.
   - scrivi su `<nome>.part`, poi `rename` a fine download (mai file parziali con nome definitivo).
   - nome = `sanitizeFileName("<artista> - <titolo>")` (`04` §7); se esiste già, aggiungi ` (2)`, ` (3)`… — **non** sovrascrivere.
   - annullamento reale: chiudi la subscription, cancella il `.part`.
3. Errori comprensibili: video non disponibile, età/regione, rete assente, "YouTube ha cambiato qualcosa: aggiorna l'app/pacchetto".
**Test:** funzione di naming con collisioni; non testare la rete.

### 5.10 — Coda di download
**File:** `lib/services/online/download_queue.dart`
Coda **sequenziale** (un download alla volta) con stati `queued/downloading/done/failed/cancelled`, annulla singolo, "svuota completati".
Al completamento: scansione del **singolo file** (riusa `LibraryScanner` con una lista di path) e, se `autoEnrich` è attivo, `propose`+`apply` solo campi vuoti.
Se l'app viene chiusa: annulla il job attivo e cancella i `.part`.

### 5.11 — Schermata YouTube
**File:** `lib/ui/screens/youtube/youtube_screen.dart`
Campo ricerca/URL, risultati (miniatura, titolo, canale, durata) con "Scarica"; **ignora** Invio mentre una ricerca è in corso;
risultati di una ricerca vecchia non sovrascrivono quelli nuovi (id progressivo della richiesta).
Mostra "Già in libreria" confrontando per **nome file esatto sanificato** o per id video salvato in un piccolo indice `downloads.json`
(non per prefisso del titolo). Coda con progresso (aggiornamento UI limitato a 5 Hz).
Cartella di destinazione: Android → `getExternalStorageDirectory()/Music` (aggiungila automaticamente alle cartelle scansionate);
desktop → prima cartella musicale configurata.

## Definition of Done
- [ ] Test: query cleaner, iTunes (4 casi), LRC, enrichment (3 regole), naming download
- [ ] Nessun dato utente sovrascritto senza anteprima (verifica manuale su un brano con titolo modificato)
- [ ] Download annullabile davvero; nessun `.part` rimasto dopo chiusura
- [ ] `kEnableYoutube=false` rimuove ogni traccia della funzione dalla UI
- [ ] `docs/PROGRESS.md` aggiornato
