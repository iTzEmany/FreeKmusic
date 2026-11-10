# Fase 69c — Fondamenta del riconoscimento: impronta, tag e query

**Obiettivo:** i mattoni del riconoscimento del brano, senza ancora cambiare l'arricchimento. L'impronta Chromaprint calcolata in Rust anche su Android, uguale a quella di fpcalc. MBID e ISRC letti dai tag di ogni formato, e i tag non si perdono più per una data strana. Query più pulite, Deezer acceso di serie, stima dei minuti più onesta.

**Prerequisiti:**
- Fase 69b chiusa.
- Da leggere: `docs/feature-riconoscimento.md` (Requisiti, Vincoli, Stack, Architettura §Componenti e §Invarianti, Rischi K-RB-02, K-RB-03, K-RB-07, K-RB-09).
- Decisioni: D-299…D-321 (in particolare D-305, D-309, D-310, D-311, D-313, D-315…D-317, D-320).

**Intoccabili (D-280):** schema DB v15 (nessuna migrazione, nessuna colonna), formato di backup e condivisione, comportamento dell'arricchimento (questa fase non tocca `EnrichEngine`).

**Pacchetti:** solo quelli approvati in D-315 (rusty-chromaprint 0.3.0, symphonia 0.6.1 con le feature elencate in `feature-riconoscimento.md` §Stack). Nessun pacchetto Dart nuovo.

**Comando mirato:**
- task 69c.1 e 69c.2: `cargo test --manifest-path third_party/metadata_god/rust/Cargo.toml` più `flutter test test/services/tags/`;
- task 69c.3: `flutter test test/services/online/query_cleaner_test.dart test/services/online/deezer_client_test.dart test/services/online/metadata_resolver_test.dart test/data/settings_store_test.dart` (i nomi esatti dei file vanno presi da `test/`; se un file non c'è, si crea).

## Task

Al massimo 4 task per fase, un commit per task. I passi vanno nell'ordine scritto; ognuno ha il suo «Fatto quando» e lascia il codice funzionante.

### 69c.1 — Prova dell'impronta (R-166, D-315, D-316)

Il resto della feature parte solo se questa prova passa.

#### Passo: Strumenti
- Installa `flutter_rust_bridge_codegen` 2.11.1: `cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked`. Sul PC c'è la 2.13.0, che non va bene con `flutter_rust_bridge =2.11.1`.
- Scarica fpcalc 1.6.x statico per Linux dalle release di `acoustid/chromaprint` (GitHub) nello scratchpad. Non entra nel repo né nell'app.

**Fatto quando:** `flutter_rust_bridge_codegen --version` stampa 2.11.1 e `fpcalc -version` risponde.

#### Passo: `fingerprint(path)` in Rust
- In `third_party/metadata_god/rust/Cargo.toml` aggiungi rusty-chromaprint e symphonia, solo con le feature di D-315.
- Nuovo `rust/src/api/fingerprint.rs`, con la funzione `fingerprint(path) -> {fingerprint: String, duration_s: u32}`:
  - decodifica con symphonia;
  - mixa a mono e ricampiona a 11025 Hz;
  - usa i primi 120 s e il preset test2;
  - comprime e codifica l'impronta come fpcalc (base64 URL-safe);
  - riporta la durata del file intero.
- Opus/WebM e i formati non supportati restituiscono un errore tipizzato, non un panic.
- Rigenera i binding.

**Fatto quando:**
- `cargo test` è verde con i test Rust su audio generato (passo successivo);
- un'impronta vuota (issue #22) è trattata come errore.

#### Passo: Confronto con fpcalc
- Fixture in `third_party/metadata_god/rust/tests/fixtures/`: 5 file **generati** con ffmpeg (toni, rumore, sweep di 30–130 s in mp3, m4a, ogg, flac, wav) e, accanto a ognuno, l'impronta di fpcalc.
- Il test Rust confronta le impronte decompresse. Soglia: almeno il 98% dei valori a 32 bit identici, oppure una distanza di Hamming media ≤ 2 bit per valore.
- Poi, fuori dal repo, uno script nello scratchpad su `~/Downloads/Test.zip` (estratto in una cartella nuova dello scratchpad):
  1. impronte Rust e fpcalc dei 147 file;
  2. lookup AcoustID con le due impronte (chiave `kAcoustIdClient`, ≤ 3 req/s);
  3. confronto dei recording e dei punteggi.

**Fatto quando:**
- il test Rust passa la soglia sulle 5 fixture;
- su Test.zip i lookup con l'impronta Rust danno lo stesso primo recording di fpcalc in almeno 140 casi su 147;
- i numeri sono annotati in «Esiti di 69c.1» in questo documento.

Se non passa, si applica D-316:
1. copia di rusty-chromaprint in `third_party/rusty_chromaprint/`, con il MIT annotato;
2. un passo di correzione, con fpcalc e il sorgente di libchromaprint come riferimento;
3. se non basta, /obiettivo si ferma e chiede.

#### Passo: Build e peso
- Esegui `flutter build apk --debug` e `flutter build apk --release`.
- Annota il peso dell'APK prima e dopo per ABI (`unzip -l` su `lib/*/libmetadata_god.so`) e il tempo di `fingerprint` su un brano di 4 minuti.
- Prova sul Motorola: l'impronta di 3 brani della sua libreria coincide con fpcalc sul PC.

**Fatto quando:**
- l'APK si costruisce per tutte le ABI;
- l'aumento del peso è annotato (allarme K-RB-03: più di 3 MB per ABI → chiedi);
- `fingerprint` dura al massimo 1 s sul Motorola per 120 s di audio (RNF-19).

### 69c.2 — Tag: MBID, ISRC e data (R-162, R-177, D-320)

#### Passo: `read_ids(path)` in Rust
- Aggiungi `read_ids(path) -> {mbid: Option<String>, isrc: Option<String>}` con lofty (`ItemKey::MusicBrainzRecordingId`, `ItemKey::Isrc`) per MP3 (UFID e TXXX), Vorbis/FLAC e M4A (`----:com.apple.iTunes:…`).
- Nei test Rust i file generati si etichettano con lofty.
- Verifica che lofty mappi l'UFID; se non lo fa, leggi il frame a mano.

**Fatto quando:** i test Rust leggono MBID e ISRC per ogni formato.

#### Passo: `TagInfo` e il lettore
- In `TagInfo` (`lib/services/tags/tag_reader.dart`) aggiungi `mbid`.
- `AudioMetadataTagReader.read` chiama `read_ids` dopo `Isolate.run`; l'ISRC già letto ha la precedenza, normalizzato con `normalizeIsrc`.
- Quando `readMetadata` lancia, i tag si rileggono con lofty (`metadata_god` `readMetadata`, già nel crate) invece di restituire `TagInfo()` vuoto. L'eccezione resta loggata con `AppLog.w`.
- Fixture: un file generato con TYER/©day «20151119».

**Fatto quando:**
- un test del lettore su quel file legge titolo, artista e album e l'anno 2015;
- MBID e ISRC si leggono da mp3, flac e m4a;
- `flutter test test/services/tags/` è verde.

### 69c.3 — Query e impostazioni (R-178, R-179, R-180, R-181)

#### Passo: Rumore nei titoli
- Porta in `cleanSearchQuery` (`query_cleaner.dart:61`) le regole di Web Scrobbler `metadata-filter` (`YOUTUBE_TRACK_FILTER_RULES`), elencate in `feature-riconoscimento.md` §Stack e Architettura.
- Aggiungi: emoji, «No.19» / «No. 19», «"by X"» (che diventa artista se manca), «[Copyright Free]» e le altre parentesi quadre non di versione.
- Il test a tabella usa i titoli rumorosi di Test.zip (solo il testo del nome, in fixture).

**Fatto quando:**
- i test nuovi sono verdi;
- i test esistenti di `query_cleaner` restano verdi senza cambiare le attese, a meno che il caso sia elencato con il motivo nel commit.

#### Passo: Deezer
- Deezer cerca con la query pulita, come iTunes (R-179).
- `deezerMeta` è vero se la chiave è assente; un `false` salvato resta (R-180, `settings_store.dart:38, :92, :314`).

**Fatto quando:**
- un test con client finto vede la query pulita;
- un test delle impostazioni copre la chiave assente (vero) e il false salvato (falso).

#### Passo: Stima dei minuti
`enrichMinutes` (`online_providers.dart:244`) usa 7 s a brano da identificata, con una costante con nome; da anonima restano 40 s.

**Fatto quando:** un test della formula è verde.

### 69c.4 — Controlli di fase
- Esegui `flutter analyze` pulito e `flutter test` mirato verde; la suite completa la fa la CI.
- Review del diff con `/code-review high`: le aree a rischio sono Rust/FFI e il lettore di tag.
- Fai la scheggia in modalità fase sul lettore di tag con file assurdi (troncati, 0 byte, tag enormi, date strane): nessun crash, nessun file perso.
- Annota gli esiti qui sotto e spunta `docs/PROGRESS.md`.

**Fatto quando:**
- c'è la PR con la CI «Analyze and test» verde;
- gli esiti di 69c.1 (impronte, peso, tempo) sono in questo documento.

## Esiti di 69c.1

Esito della prova: **passata**, senza ricorrere a D-316 (rusty-chromaprint resta dipendenza di crates.io) né a D-325.

- **Strumenti**: `flutter_rust_bridge_codegen` 2.11.1; `fpcalc` 1.6.2 (statico, x86_64) nello scratchpad. Dipendenze: rusty-chromaprint 0.3.0, symphonia 0.6.1 con mp3, aac, isomp4, flac, vorbis, ogg, wav, pcm (`pcm` serve al wav). `crate-type` del crate ora include anche `lib`, altrimenti i test d'integrazione in `rust/tests/` non lo collegano.
- **API**: `fingerprint(path) -> {fingerprint: String, duration_s: u32}` (base64url senza `=`, come fpcalc; primi 120 s; preset test2). Il ricampionamento a 11025 Hz e il mix a mono li fa rusty-chromaprint. Opus/WebM, codec non supportati, file vuoti o corrotti, impronta vuota (issue #22): `Err` con messaggio, mai panic.
- **Fixture** (5 file generati con ffmpeg, 2,4 MB in `rust/tests/fixtures/`, con l'output di fpcalc accanto): valori a 32 bit identici a fpcalc 100% (mp3, flac, wav), 99,68% (ogg), 60,69% (m4a/AAC, distanza di Hamming media 0,54 bit: il decoder AAC arrotonda in modo diverso). Tutte sopra la soglia (≥ 98% o ≤ 2 bit).
- **Test.zip** (147 brani: 124 mp3, 23 m4a; lookup AcoustID con `meta=recordings`): stesso primo recording di fpcalc in **145/147** (target 140). Di questi 117 hanno un recording e 28 non ne hanno per entrambi. Differenza di score fra le due impronte: massima 0,016, media 0,003. Le impronte come testo non sono quasi mai identiche (diversi decoder), ma i risultati sì. I 2 casi che mancano sono formati non supportati (errore, il chiamante passa oltre): un WebM/Opus con estensione `.mp3` (D-311) e un m4a HE-AAC (SBR, che symphonia non decodifica).
- **Peso** di `libmetadata_god.so` (release, prima, dopo): arm64-v8a 1.890.432 B, 3.612.952 B (+1,72 MB); armeabi-v7a 1.259.100 B, 2.470.276 B (+1,21 MB); x86_64 2.082.704 B, 4.281.216 B (+2,20 MB). APK release 224,5 MB, 226,7 MB. Tutto sotto i +3 MB per ABI: D-325 non serve. Il profilo release del crate non è stato toccato.
- **Mi A3** (D-324, binario Rust cross-compilato aarch64, tre brani da 5,4, 4,8 e 3,8 minuti): 0,66-0,70 s per brano (120 s di audio), sul PC 0,17 s; target ≤ 1 s rispettato. Le impronte coincidono byte per byte con quelle del PC.
- Build debug riuscita; `.so` debug (non finiscono nell'APK dell'utente) prima, dopo: arm64-v8a 4,69 MB, 14,48 MB; armeabi-v7a 2,63 MB, 6,65 MB; x86_64 5,54 MB, 23,18 MB (simboli di debug).
- Non fatto in questo task: `flutter test` mirato dell'app (task 69c.2), scheggia, review.

## Esiti di 69c.4
- `flutter analyze` pulito; test mirati verdi (Rust: `cargo test --release`; Dart: tags, tag writer, query cleaner, resolver Deezer, impostazioni, stima dei minuti; più i 921 test di online/providers/ui toccati da `deezerMeta` acceso di serie).
- `/code-review high` sul diff della fase: 10 rilievi, 8 corretti. Il ripiego lofty ora porta tutti i campi (durata compresa). Deezer assegna il punteggio sul testo pulito e riprova con la divisione «Artista - Titolo». «by X» passa dai passi finali comuni. `read_ids` legge senza copertina. L'anno da data intera viene da TYER/TDRC, solo negli mp3. L'MBID si accetta solo se è un UUID. L'impronta si ferma a 120 s esatti, senza decodificare tutto il file. Scartati: la copia esplicita dei campi in `withIds` (stesso stile del resto, rischio basso) e «una init per isolate» (il lettore non gira in isolate).
- Scheggia (1704 file assurdi sulle funzioni Rust, 1683 letture Dart): nessun panic, nessun crash, nessun file modificato; un'ora di audio in meno di 0,1 s. Bug trovati e corretti con il test di regressione:
  - alto: gli mp3 con un tag ID3v2 di 1,5 MB o più (copertina grande) non davano l'impronta;
  - medio: un titolo tutto fra parentesi quadre veniva svuotato;
  - bassi: regex quadratiche su titoli lunghissimi (input limitato a 300 caratteri), un TYER non valido che faceva perdere tutti i tag, anni fuori intervallo;
  - mutanti rafforzati: l'UUID non esadecimale e la precedenza dell'ISRC.
- Doppia inizializzazione della libreria Rust fra lettore e scrittore (trovata in review di 69c.2): ora c'è un solo `ensureMetadataGod()`.
- Limite noto: dopo il taglio a 120 s esatti, Test.zip e il Mi A3 non sono stati rimisurati; le 5 fixture restano sopra la soglia. Si rimisura nella prova Test.zip di 69d.4.
