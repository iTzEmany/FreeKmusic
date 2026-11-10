# Specifiche da portare dalla vecchia app Python

Qui c'è la **logica** da riprodurre in Dart, già con i difetti noti corretti. Riferimenti nel vecchio
codice (solo lettura): `../codecore/online/metadata_enricher.py`, `../codecore/online/youtube.py`,
`../codecore/audio/library.py`, `../codecore/audio/cover_manager.py`. Se divergono da questo file, vale questo file.

## 1. `cleanSearchQuery(rawTitle, rawArtist) → (title, artist)`
Pura, testabile, in `lib/services/online/query_cleaner.dart`. Passi, in ordine:
1. Rimuovi estensione audio finale (`.mp3 .m4a .flac .wav .ogg .aac .wma`, case-insensitive).
2. Rimuovi prefissi `mix `, `audio `, `video `, `mashup ` (inizio stringa, case-insensitive).
3. Rimuovi numerazione iniziale: regex `^\d{1,3}[\s._-]+`.
4. Artista "generico" se: vuoto, contiene `sconosciuto`/`unknown`, termina con ` official`, `vevo`, ` - topic`.
5. Rimuovi rumore tra parentesi `()[]{}` che contiene una di:
   `official, video, audio, remaster, hd, 4k, hq, lyric, visualizer, clip, deluxe, bonus`
   e le frasi libere `official video`, `official audio`, `remastered`, `lyric video`, `4k remaster`.
6. Normalizza virgolette: `" “ ” \`` → rimossi o `'`; `’ ‘` → `'` (l'apostrofo `'` **va preservato**: "Don't").
7. Collassa spazi multipli.
8. Se il titolo contiene un separatore **con spazi** (`" - "`, `" – "`, `" — "`): dividi alla **prima** occorrenza
   in `(parteA, parteB)`; se artista generico o vuoto → `artist = parteA`; `title = parteB`.
   ⚠️ Correzione rispetto a Python: **non** dividere sui trattini senza spazi ("Jay-Z", "Spider-Man").
9. Dall'artista rimuovi il suffisso finale ` official|vevo|topic` (case-insensitive) e normalizza le virgolette.
10. `trim()` su entrambi.

### Test minimi (tabella ingresso → uscita)
| titolo | artista | → titolo | → artista |
|---|---|---|---|
| `01 - Car Radio (Official Video)` | `twenty one pilots` | `Car Radio` | `twenty one pilots` |
| `Queen – Bohemian Rhapsody (Official Video Remastered)` | `` | `Bohemian Rhapsody` | `Queen` |
| `Jay-Z - Empire State of Mind` | `` | `Empire State of Mind` | `Jay-Z` |
| `Don’t Stop Believin’` | `Journey` | `Don't Stop Believin'` | `Journey` |
| `song.mp3` | `Artist - Topic` | `song` | `Artist` |

## 2. `extractPrimaryArtist(artist)`
Divide su `,` `&` `/` oppure ` feat. ` / ` ft. ` (case-insensitive) e prende il primo pezzo (trim). Se vuoto → artista originale.

## 3. `coreTitle(title)`
Rimuove gruppi tra parentesi che contengono `live, unplugged, acoustic, version, session, edit, from the series`; trim.

## 4. Ricerca iTunes (`itunes_client.dart`)
- Endpoint: `https://itunes.apple.com/search?term=<q>&media=music&entity=song&limit=8` (nessuna chiave).
- Query da provare **in ordine**, deduplicate, saltando le vuote; ferma alla prima che restituisce risultati:
  1. `artist title`  2. `primaryArtist title` (se diverso)  3. `artist coreTitle` (se diverso)
  4. `primaryArtist coreTitle`  5. `title`  6. `coreTitle` (se diverso)
- **Punteggio** per ogni risultato (confronto su stringhe minuscole/trim):
  - titolo: uguale +12, uno contiene l'altro +7
  - artista: uguale +10, uno contiene l'altro +5
- **Accettazione (correzione rispetto a Python, che accettava anche punteggio 0)**:
  scarta il risultato se `titleScore == 0`, oppure se l'artista è noto e `artistScore == 0`.
  Se nessuno passa → "non trovato" (**mai** ripiegare su `results[0]`).
- Output: `title, artist, album (senza "(Deluxe|Bonus|Remastered|Expanded|Anniversary ...)"), year (primi 4 char di releaseDate), genre (primaryGenreName), trackNumber, artworkUrl`.
- Copertina: sostituisci `100x100bb` con `600x600bb` nell'URL di `artworkUrl100`. Limite download: 5 MB, solo `https`.
- Pausa minima tra richieste in batch: 3 s. Se HTTP 403/429: interrompi il batch e avvisa.

## 5. Testi LRCLIB (`lrclib_client.dart`)
- Base: `https://lrclib.net/api`. Header `User-Agent: FreeKmusic/1.0 (uso personale)`.
- Tentativi in ordine, `(artist, title)` → `(primaryArtist, title)` → `(artist, coreTitle)` → `(primaryArtist, coreTitle)`:
  1. `GET /get?artist_name=&track_name=&album_name=&duration=` (passa `album_name` e `duration` in secondi se noti; 404 = nessun risultato).
  2. `GET /search?track_name=&artist_name=` e scegli il risultato migliore.
- **Validazione (correzione)**: accetta un risultato solo se l'artista coincide o è contenuto (case-insensitive)
  e, se la durata locale è nota, `|duration_lrclib − duration_locale| ≤ 3 s`. Niente ricerca col solo titolo.
- Salva `plainLyrics` → `lyricsPlain`, `syncedLyrics` → `lyricsSynced` (**i testi sincronizzati si conservano**).

### Parser LRC (`lrc_parser.dart`)
Riga: `[mm:ss.xx]testo` (anche `[mm:ss]`, `[mm:ss.xxx]`, più timestamp per riga). Ignora tag `[ar:]`, `[ti:]`, `[offset:]` (applica `offset` in ms se presente).
Output: lista ordinata di `LrcLine(Duration time, String text)`. Test: riga multipla, millisecondi a 2 e 3 cifre, righe vuote.

## 6. Wikipedia (curiosità) — versione semplificata
- Lingua = lingua app; se nessun risultato prova `en`.
- Ricerca pagina: `https://<lang>.wikipedia.org/w/api.php?action=query&list=search&srsearch=<title> <artist> canzone|song&format=json&srlimit=3`
- Estratto: `action=query&prop=extracts&explaintext=1&exintro=1&redirects=1&titles=<pagina>&format=json`.
- Scarta pagine di disambiguazione (testo che contiene `disambigua` / `may refer to`) e estratti < 80 caratteri.
- Tronca a 1000 caratteri su fine frase. Salva l'URL della pagina insieme al testo (attribuzione CC BY-SA in UI: "Fonte: Wikipedia").
- **Niente** traduzione automatica nella v1.

## 7. `sanitizeFileName(name)` (download e copertine)
1. Rimuovi i caratteri `\ / : * ? " < > | %` e i caratteri di controllo (U+0000–U+001F).
2. Collassa spazi multipli; `trim()`.
3. Rimuovi punti e spazi **finali** (Windows li scarta).
4. Se il nome (senza estensione, case-insensitive) è `CON PRN AUX NUL COM1..9 LPT1..9` → prefisso `_`.
5. Se inizia con `.` → rimuovi i punti iniziali.
6. Tronca a **120** caratteri **prima** di aggiungere l'estensione; se vuoto → `track`.
Test: `a/b:c`, `CON`, `nome. `, 300 caratteri, nome con emoji (deve restare intatto).

## 8. Badge qualità (testo in UI)
- Lossless (`flac`, `wav`, `aiff`, `alac`): `FLAC • 24 bit / 96 kHz` (ometti la parte che manca).
- Lossy: `MP3 • 320 kbps`.
- Dato mancante: **non inventare** valori (la vecchia app mostrava "16 bit / 44.100 Hz" di default): mostra solo il formato.

## 9. Preferiti con "Annulla"
Toggle preferito → `SnackBar` con azione "Annulla" (5 s). Una sola snackbar alla volta; una nuova sostituisce la precedente.
L'annulla ripristina lo stato dell'**ultimo** cambiamento.

## 10. Ordinamenti disponibili
Titolo, Artista, Album, Anno, Aggiunti di recente, Durata. "Predefinito" = ordine di `albumKey, discNumber, trackNumber, title`.
Il criterio resta in uno stato `SortOption` (non perdere l'ordine originale: si ricalcola sempre dalla query).
