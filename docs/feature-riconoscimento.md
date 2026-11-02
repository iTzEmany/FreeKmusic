# Feature «Riconoscimento del brano»

Prima di arricchire un brano l'app riconosce qual è davvero, con una cascata: ISRC/MBID nei tag → ricerca testuale se i tag sono affidabili → impronta audio AcoustID → YouTube Music. Album, anno, genere, testi e curiosità arrivano dal brano riconosciuto; per cover e arrangiamenti le curiosità parlano del brano originale.
Per chi: chi carica brani scaricati a caso da YouTube (tag sporchi, il canale come artista, colonne sonore, cover). Perché ora: sui 147 brani di un amico (Test.zip) iTunes e Deezer ne trovano 78; AcoustID e YouTube Music recuperano gran parte del resto.

Kickoff del 2026-11-01. Decisioni: D-299 … in `docs/decisioni.md`. Si appoggia sul motore unico di `docs/fase-69b-arricchimento-unico.md` e sui requisiti di `docs/feature-arricchimento.md` (R-35…R-67) senza cambiarne il comportamento quando il riconoscimento non trova niente. Già fuso prima (PR #75): iTunes scarta i risultati con durata oltre ±20 s; «Artista - Titolo» sotto un canale si cerca con l'artista del titolo.
Fasi: vedi `docs/PROGRESS.md` (69c e seguenti, prima della 70).

## La prova di partenza (Test.zip, 147 file: 124 mp3, 23 m4a)
| Fonte | Risultato |
|---|---|
| iTunes da solo | 65 trovati |
| iTunes + Deezer | 78 trovati (69 persi) |
| Tag con il canale come artista | 37 file («7clouds Rock», «Trap City», «The Vibe Guide», «RHINO»…) |
| AcoustID sui 69 persi | 43 giusti (+1 dubbio), 2 sbagliati, 6 impronte senza metadati, 17 senza risposta. Il primo recording non è sempre quello giusto; i titoli arrivano spesso in giapponese o russo. fpcalc: 0,12 s a file per 120 s |
| AcoustID sui 78 trovati | 73 confermati, 0 sbagliati |
| YouTube Music sui 69 persi | 40 giusti; fra le 44 colonne sonore 21 giuste, 11 cover di terzi, 12 sbagliate |
| LRCLIB | errore 502 per tutta la prova: testi da rimisurare (R-182) |
| Tempo sul Motorola | ~6,5 s a brano (prima del riconoscimento) |

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Valgono su Android, Linux e Windows (Windows usa lo stesso codice di Linux ed è provato solo su Linux).
«Identità» = il brano riconosciuto (titolo, artista, durata, ISRC/MBID se ci sono, fonte e punteggio). «Sicura» = da ISRC/MBID dei tag, oppure da AcoustID oltre la soglia (R-165) con titolo coerente.

### Cascata
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-160 | Il motore d'arricchimento riconosce il brano **prima** di cercare meta, testi e curiosità, e cerca tutto con l'identità trovata invece che con i tag grezzi. Senza identità si comporta come oggi | I | Test del motore con fonti finte: identità trovata → meta, testi e curiosità chiesti con titolo e artista dell'identità; nessuna identità → stesse chiamate di oggi || 69d |
| R-161 | Ordine della cascata, ci si ferma al primo che riesce: 1) ISRC o MBID nei tag → MusicBrainz; 1b) video id YouTube noto (R-183) → metadati YouTube Music di quel video; 2) ricerca testuale (iTunes, Deezer) se i tag sono affidabili (R-163); 3) AcoustID se i tag sono dubbi o il passo 2 non ha trovato niente; 4) YouTube Music come ultimo ripiego | I | Test con fonti finte per ogni ramo: tag con ISRC → né testo né AcoustID; video id noto → niente AcoustID; tag affidabili trovati → niente AcoustID; tag dubbi → AcoustID prima del testo; tutto vuoto → YTM || 69d |
| R-162 | Si leggono dai tag anche il MusicBrainz Recording ID (MP3 UFID/TXXX, Vorbis `MUSICBRAINZ_TRACKID`, M4A `----:com.apple.iTunes:MusicBrainz Track Id`) e l'ISRC dei M4A, che oggi manca | I | Test del lettore su file di prova per ogni formato: MBID e ISRC letti || 69c |
| R-163 | Tag «dubbi»: artista vuoto; artista che è un canale (` - Topic`, VEVO, Records, Music, Lyrics, un elenco di canali noti come «7clouds», «Trap City»); titolo «Artista - Titolo» con un artista diverso da quello dei tag; durata incoerente con il risultato. Gli altri sono «affidabili» | I | Test a tabella con i 37 casi di canale di Test.zip (nomi in fixture) e con 10 artisti veri: nessun falso «dubbio» sugli artisti veri || 69d |
| R-164 | Interruttore «Riconosci dal suono (AcoustID)» nelle impostazioni online, acceso di serie; spento, la cascata salta il passo 3. Parte solo l'impronta, mai l'audio (D-306) | I | Test: interruttore spento → nessuna chiamata AcoustID; acceso → chiamata con fingerprint e durata || 69d |
| R-165 | Soglia rigida (D-300): AcoustID score ≥ 0,9 e durata entro ±10 s; fra i recording restituiti si sceglie quello più simile al nome del file e ai tag, non il primo. YouTube Music: durata entro ±10 s e titolo che si sovrappone. Sotto soglia: nessuna identità | I | Test con le risposte AcoustID registrate di Test.zip (fixture): i casi «Fairytale», «Heathens», «Happier» scelgono il recording giusto; score 0,85 → scartato; durata +15 s → scartato || 69d |
| R-166 | Impronta Chromaprint dei primi 120 s, compatibile con fpcalc, calcolata fuori dal thread della UI, su Android, Linux e Windows | I | Test: l'impronta di 3 file di prova (mp3, m4a, ogg) coincide con quella di fpcalc 1.6 salvata in fixture; prova a mano sul Motorola || 69c |
| R-167 | Limiti di frequenza: AcoustID ≤ 3 richieste al secondo, MusicBrainz 1 al secondo, con lo User-Agent di `kApiContact`; un errore di quota mette in pausa solo quella fonte | I | Test con orologio finto: 10 richieste AcoustID in fila → non più di 3 per secondo; 503 di MusicBrainz → pausa e nuovo tentativo || 69d |
| R-168 | Offline, interruttore spento o fonte in errore: la cascata passa al passo successivo e l'arricchimento continua come oggi; nessun errore nuovo per l'utente | I | Test: AcoustID che lancia → si passa a YTM, il brano si arricchisce lo stesso || 69d |
| R-183 | Passo 1b: il video id di un brano scaricato da YouTube (da `playlist_import_items.videoId` del brano collegato o dal nome del file yt-dlp `… [xxxxxxxxxxx].ext`) dà i metadati YouTube Music di quel video; identità sicura se è un brano ufficiale o «Topic» (descrizione «Provided to YouTube by…»), altrimenti proposta (D-312) | I | Test: nome «Adele - Skyfall (Lyrics) [sZrTJesvJeo].mp3» → id estratto; nomi senza id o con parentesi di 11 caratteri non valide → nessun id; risposta finta «Topic» → sicura, video di un canale di testi → proposta || 69d |
| R-184 | File Opus/WebM: niente impronta, la cascata passa da 2 a 4 (D-311) | I | Test: file `.opus` con tag dubbi → nessuna chiamata AcoustID, chiamata YTM || 69d |

### Titolo e artista
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-169 | Con identità sicura, titolo e artista si correggono da soli; con identità non sicura (testo con tag dubbi, YouTube Music sempre: D-304) diventano una **proposta**. I campi modificati a mano non si toccano mai (D-299) | I | Test: identità da ISRC → titolo corretto; identità YTM → proposta, titolo invariato; brano con titolo modificato a mano → né correzione né proposta || 69e |
| R-170 | Proposte nella scheda del brano (Accetta/Scarta) e in un elenco «Da confermare (N)» nel Registro/Arricchimento con «Accetta tutte» (D-307) | I | Test widget: proposta visibile nella scheda e nell'elenco; «Accetta tutte» applica tutte e svuota l'elenco || 69e |
| R-171 | Una correzione (automatica o accettata) segue lo stesso percorso della modifica a mano di oggi; il valore vecchio va nel Registro per tornare indietro; una proposta scartata non torna più (D-308) | I | Test: correzione → riga nel Registro con il valore vecchio; scarto → riarricchendo la proposta non ricompare || 69e |

### Cover e arrangiamenti
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-172 | Riconoscere le cover: attributo «cover» della relazione performance di MusicBrainz quando c'è un MBID; parole nel titolo del file (cover, arrangement, piano/orchestral version, remix, «by X» con X diverso dall'artista dell'originale) (D-303) | I | Test a tabella: 10 titoli di cover di Test.zip (es. «Believer (Romy Wave Cover)») riconosciuti, 10 titoli normali no; risposta MusicBrainz finta con «cover» → cover || 69e |
| R-173 | L'originale di una cover: dal work di MusicBrainz, altrimenti ricerca testuale del titolo pulito scegliendo il risultato più vecchio o più popolare. Salvato in `track_enrich.details` (niente migrazione, schema v15) (D-302) | I | Test con fonti finte: cover con work → originale dal work; senza → dalla ricerca; dati salvati nel JSON e riletti || 69e |
| R-174 | Le curiosità di una cover parlano del brano originale, con in testa «Cover di Titolo – Artista»; se la cover ha curiosità sue (pagina propria), restano le sue con la stessa nota. La scheda mostra «Cover di X – Y». I video non si scartano | I | Test: cover senza pagina → curiosità dell'originale con la nota; cover con pagina → le sue con la nota; widget della scheda con l'etichetta || 69e |

### Dati, Registro e ripasso
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-175 | L'identità si salva in `track_enrich` (`mbid` e `details` JSON: fonte, score, titolo/artista riconosciuti, originale se cover), senza colonne nuove; il Registro dice da dove viene (tag, testo, AcoustID, YTM) | I | Test di repository: salva e rilegge; vecchie righe senza i campi nuovi si leggono ancora; riga del Registro con la fonte || 69d |
| R-176 | Ripasso una volta, in sottofondo, dei brani già arricchiti senza identità che hanno tag dubbi o parti vuote (meta o curiosità); riempie solo i buchi, non sovrascrive ciò che c'è (D-301) | I | Test: brano completo con tag affidabili → non ripassato; brano con canale come artista → ripassato una volta sola; campi già pieni invariati || 69e |
| R-185 | Con una correzione applicata (R-171) anche MBID e ISRC riconosciuti vanno nei tag del file, se la modifica a mano scrive il file (D-314) | U | Test con scrittore finto: correzione → MBID e ISRC passati allo scrittore; modifica a mano che non scrive il file → niente || 69e |
| R-186 | Brani online (coda, streaming, Jam): stesso passo 1b dal loro video id; scheda e curiosità dall'identità, cover compresa (D-314) | U | Test: item `yt:` di una cover → scheda con «Cover di X – Y» e curiosità dell'originale || 69e |

### Fonti e pulizia (rimandati del 2026-11-01, D-305)
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-177 | Un tag data come «20151119» non fa più saltare tutti i tag del file: si legge l'anno (2015) o si ignora solo la data | I | Test del lettore con un file di prova con quel tag: titolo, artista e album letti, anno 2015 || 69c |
| R-178 | Rumore nei titoli tolto da `cleanSearchQuery`: emoji, «[Copyright Free]» e altre parentesi quadre, «No.19», «"by X"», sul modello delle regole di Web Scrobbler (`metadata-filter`) | I | Test a tabella con i titoli rumorosi di Test.zip: query pulita attesa per ognuno; i test esistenti di `query_cleaner` restano verdi || 69c |
| R-179 | Deezer cerca anche con la query pulita, come iTunes | I | Test con client finto: la query mandata a Deezer è quella di `cleanSearchQuery` || 69c |
| R-180 | Deezer per i metadati acceso di serie (`deezerMeta` default true); chi l'ha spento resta spento (D-309) | I | Test delle impostazioni: chiave assente → true; false salvato → false || 69c |
| R-181 | Stima `enrichMinutes` a 7 s/brano; rimisurata sul Motorola a fine feature col riconoscimento attivo (D-310) | I | Test della formula; misura a mano annotata nella fase di chiusura || 69e |
| R-182 | Rimisura dei testi su Test.zip quando LRCLIB torna su: quanti testi trovati prima e dopo il riconoscimento | U | Resoconto nella fase di chiusura con i numeri || 69e |

## Requisiti non funzionali
- **RNF-18** Nessun lavoro pesante nel thread della UI: decodifica e impronta in un isolate o nel thread di Rust.
- **RNF-19** Il riconoscimento aggiunge al massimo ~1 s a brano in media oltre all'attesa delle quote (fpcalc: 0,12 s per 120 s su PC).
- **RNF-20** Nessuna migrazione: schema drift v15 e formato del backup invariati (D-280).

## Deviazioni dal piano
- `needsRecognition` (ripasso dei brani già arricchiti senza parti dovute, D-301/R-176) non c'è nella 69d: il gate del motore resta «almeno una parte dovuta». È il primo passo della 69e.

## Come convive con le funzioni esistenti
- Senza identità tutto resta come oggi: stesse fonti, stesso ordine, stessi «none» a 30 giorni.
- `fillableFields` continua a riempire solo i campi vuoti; titolo e artista cambiano solo per R-169/R-171.
- Le modifiche a mano, i testi messi dall'utente (`lyrics_by_user`) e le copertine a mano non si toccano.
- Jam, streaming e download non cambiano.

## Vincoli
- **Servizi solo gratuiti.** AcoustID è gratis solo per uso non commerciale: l'app è personale, open source, non commerciale. Chiave dell'applicazione `Hsn5w6Tjwv` nel sorgente (`lib/core/app_info.dart`, `kAcoustIdClient`, accanto a `kApiContact`), come fanno Picard e beets (D-313). La chiave utente non entra mai nel repo.
- **Quote:** AcoustID ≤ 3 richieste/s; MusicBrainz 1 richiesta/s per IP con User-Agent `Codecore/<versione> ( kApiContact )`; quelle di iTunes, Deezer, YTM e Wikimedia restano come oggi (`RateLimiter`, `WindowLimiter`, pause per servizio).
- **Dati:** nessuna migrazione, schema drift v15 e formato del backup invariati (D-280): l'identità va in `track_enrich.mbid` e `details`.
- **Piattaforme:** Android, Linux, Windows; l'impronta deve funzionare su tutte e tre (niente fpcalc, che esiste solo per desktop). Windows si compila solo su una macchina Windows: lì si prova a mano o in CI.
- **Formati per l'impronta:** mp3, m4a/aac, flac, ogg/vorbis, wav; Opus/WebM no (D-311).
- **Privacy:** parte solo l'impronta e la durata, mai l'audio; interruttore acceso di serie (D-306).
- **Pacchetti:** nessun pacchetto Dart nuovo; dipendenze Rust nuove nel crate `third_party/metadata_god` solo con l'approvazione del giro 4.

## Stack
Verificato il 2026-11-01 (fonti: crates.io API, repo GitHub degli autori, acoustid.org/webservice, musicbrainz.org/doc).
| Pezzo | Versione | Licenza | Note |
|---|---|---|---|
| rusty-chromaprint | 0.3.0 (2024-10-26) | MIT (dichiarata nel Cargo.toml; file assente nel repo, issue #23) | puro Rust (rustfft 6.2, rubato 0.16); «port in corso»; issue #22 «impronta vuota»: da coprire nella prova. Preset `Configuration::preset_test2()` = quello di fpcalc (da confermare con la prova) |
| symphonia | 0.6.1 (2026-08-13) | MPL-2.0 | feature `mp3`, `aac`, `isomp4`, `flac`, `vorbis`, `ogg`, `wav`; Opus non supportato (D-311) |
| flutter_rust_bridge | =2.11.1 (già nel crate e nel pubspec) | MIT | **Trappola:** sul PC c'è `flutter_rust_bridge_codegen` 2.13.0: per rigenerare i binding serve la 2.11.1 (`cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked`), altrimenti i binding non combaciano |
| AcoustID web service | v2 | servizio gratis, non commerciale | `POST https://api.acoustid.org/v2/lookup` (corpo gzip, `Content-Encoding: gzip`), `client`, `duration`, `fingerprint`, `meta=recordings+releases+compress`; ≤ 3 req/s. `releasegroups` non documentato: non usarlo |
| MusicBrainz WS/2 | — | dati CC0 | `/ws/2/isrc/<isrc>`, `/ws/2/recording/<mbid>?inc=work-rels+isrcs+artist-credits+releases`, `/ws/2/work/<id>?inc=recording-rels`; attributo «cover» della relazione performance; 1 req/s per IP |
| fpcalc (solo per la prova e le fixture) | 1.6.x, statico dalle release di `acoustid/chromaprint` | LGPL | **non installato sul PC**: va scaricato nello scratchpad per la prova (non entra nel repo né nell'app) |

Nessun pacchetto Dart nuovo: dio, drift, shared_preferences e `dart:io` (gzip) bastano.

### Comandi in più
```
cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked   # una volta
cd third_party/metadata_god && flutter_rust_bridge_codegen generate    # dopo modifiche a rust/src/api
cargo test --manifest-path third_party/metadata_god/rust/Cargo.toml    # test dell'impronta
flutter build apk --debug                                               # verifica cargokit su Android
```

### Fixture
- Nel repo solo audio **generato** (toni, rumore, sweep di 30–130 s in mp3/m4a/ogg/flac/wav prodotti con ffmpeg) e le impronte fpcalc salvate accanto: niente brani coperti da diritti.
- `~/Downloads/Test.zip` (147 brani) serve solo alla prova e alla misura a mano; non entra nel repo. Le risposte AcoustID/YTM usate nei test si salvano ridotte (solo i campi letti) in `test/fixtures/`.

## Architettura
Si estende il motore unico della fase 69b (`EnrichEngine.gather`/`commit`, `docs/fase-69b-arricchimento-unico.md`, `docs/02-architettura.md`) senza toccarne regole e stato: `isDue`, `dueSql`, `fillableFields`, `statusAfter`, `EnrichRunner` e i conteggi restano come sono. Il riconoscimento è un **passo prima** di `_gather`, non una parte nuova. Il risultato si salva nel JSON `track_enrich.details`, sotto la chiave `rec`. I campi di `TrackDetails` restano al primo livello (schema v15, nessuna colonna). Lo usano meta, testi e curiosità: ricevono una copia del `Track` con titolo, artista, ISRC e durata dell'identità. Le scritture su `tracks` restano sulla riga vera.

**Perché un passo prima e non una `EnrichPart`.** Una parte nuova entrerebbe in `dueSql`, nei conteggi «N brani da fare», in `statusAfter`, in «Da revisionare» e nei segni a 30 giorni. Tutta la libreria già arricchita risulterebbe «da fare», e tutte quelle regole andrebbero riscritte (D-280). Come passo prima, invece, il riconoscimento non cambia nessun conteggio e nessuno stato. Ha un costo solo: un brano senza parti dovute non passa mai dal cursore normale. Per il ripasso una tantum (R-176) serve quindi un cursore a parte, `RecogPassIds`.

### Componenti
| Componente | Cosa fa / cosa cambia | File |
|---|---|---|
| `fingerprint(path)` (Rust, nuovo) | symphonia decodifica i primi 120 s (mp3, aac/isomp4, flac, vorbis/ogg, wav). `rusty_chromaprint::Fingerprinter` con `Configuration::preset_test2()` (ricampiona da sé a 11025 Hz mono), poi compressione dell'impronta. Restituisce `FingerprintOut { compressed: Vec<u8>, decoded_secs: u32 }`. Lo chiama flutter_rust_bridge, nel thread pool di Rust, mai nel thread della UI (RNF-18). Opus/WebM o una decodifica fallita → `Err`. Licenze in `Cargo.toml` (D-315, D-317) | `third_party/metadata_god/rust/src/api/fingerprint.rs`, `api/mod.rs`, binding rigenerati con codegen **2.11.1** |
| `read_ids(path)` (Rust, nuovo) | lofty `ItemKey::MusicBrainzRecordingId` e `ItemKey::Isrc` per tutti i formati: MP3 UFID/TXXX, Vorbis `MUSICBRAINZ_TRACKID`, M4A `----:com.apple.iTunes:…`. `audio_metadata_reader` non legge l'UFID né gli atomi `----` (verificato nel sorgente 1.8.1) | `third_party/metadata_god/rust/src/api/api.rs` |
| `Fingerprinter` (nuovo, interfaccia) e `RustFingerprinter` | `Future<({String fp, int secs})?> of(String path)`: chiama `fingerprint` e codifica in base64url senza `=` in Dart (`dart:convert`, come fpcalc). Null se il formato è escluso (Opus/WebM, R-184) o l'impronta è vuota; una lettura fallita lancia e il recognizer la conta come fonte persa (`lost`). Interfaccia per i test | `lib/services/tags/fingerprinter.dart` |
| `TagInfo` / `AudioMetadataTagReader` | (1) `TagInfo.mbid` nuovo; ISRC e MBID da `read_ids` dopo `Isolate.run` (R-162; gli M4A oggi non hanno ISRC). (2) **Bug della data (R-177)**: quando `readMetadata` lancia (vedi K-RB-09), si rilegge con `MetadataGod.readMetadata` (lofty, già nel crate), che salta solo la data illeggibile. Il resto del lettore non cambia | `lib/services/tags/audio_metadata_tag_reader.dart`, `tag_reader.dart` |
| `TrackIdentity` + `Recognition` (nuovi, puri) | `TrackIdentity { title, artist, ms?, isrc?, mbid?, vid? }`; `src`, `score` e `sure` stanno su `Recognition { v, at, identity?, src, score, sure, prop, was?, original?, cover }`, con `RecogSource { tags, ytid, text, acoustid, ytm }`. `applyTo(Track) → Track` (copia per le ricerche). JSON di §Dati, letti con le stesse difese di `TrackDetails.fromJson` (input non fidato) | `lib/services/recognition/track_identity.dart` |
| Segnali dei tag (nuovi, puri) | `tagsDubious(Track)` (R-163): artista vuoto o generico (`isGenericArtist`, ora pubblico), suffissi ` - Topic`, VEVO, Records, Music, Lyrics, elenco `kKnownChannels` («7clouds», «Trap City», «The Vibe Guide», «RHINO»…), «A - B» con A diverso dall'artista (stessa regola di `cleanSearchQuery`). `coverHint(title, artist) → ({cover, original, remixOnly})` (R-172): parole di cover tra parentesi (cover, remix, arrangement, piano/orchestral version); fuori parentesi solo forme da etichetta («Piano Cover», «- Cover», «X Cover … Remix»); «by X» con almeno due parole prima e X diverso sia dall'artista dei tag sia da quello dell'identità; titolo tagliato a 300 caratteri. Un remix dello stesso artista non è una cover. `videoIdOf(path)`: `… [xxxxxxxxxxx].ext` con 11 caratteri `[A-Za-z0-9_-]`, oppure `stream:youtube:<id>` (R-186) | `lib/services/recognition/channel_detector.dart` (`tagsDubious`), `cover_detector.dart` (`coverHint`) e `video_id.dart` |
| `cleanSearchQuery` | Regole in più, sul modello di `metadata-filter` (R-178): emoji, ogni parentesi quadra, «No.19», «"by X"», «[Copyright Free]». Gli altri test di `query_cleaner` restano verdi | `lib/services/online/query_cleaner.dart` |
| `AcoustIdClient` (nuovo) | `lookup(fp, secs) → List<AcoustIdHit>` (score, recordings con titolo, artisti, durata, id; releases solo per l'anno). `POST /v2/lookup` con un Dio suo, come `InnerTubeClient`, perché `WebClient` fa solo GET: corpo `application/x-www-form-urlencoded` compresso con `gzip` di `dart:io` e `Content-Encoding: gzip`; `client=kAcoustIdClient`, `meta=recordings+releases+compress`; User-Agent `apiUserAgent`. `RateLimiter(minGap: 340 ms)`, cioè ≤ 3 al secondo (R-167). 429/503 → `RateLimitedException` e `_restUntil` di 5 minuti, come `DeezerClient.isResting` | `lib/services/online/acoustid_client.dart`, `lib/core/app_info.dart` (`kAcoustIdClient = 'Hsn5w6Tjwv'`) |
| `MusicBrainzClient` | Resta il passo di 1,1 s tra le richieste. Nuovi: `recordingById(mbid)` con `inc=isrcs+artist-credits+releases+work-rels` (identità più cover: attributo `cover` della relazione `performance` → id del work); `workOriginal(workId)`: browse `recording?work=<id>&inc=artist-credits+work-rels&limit=100`, il recording senza attributo cover con la first-release-date più vecchia (una pagina sola). L'attributo cover si legge solo quando l'identità viene dal MBID dei tag. `recordingsByIsrc` esiste già | `lib/services/online/musicbrainz_client.dart` |
| `InnerTubeClient` | `songOf(videoId)`: endpoint `next` di music.youtube.com come `lyrics` (stesso `_musicPage`). Dalla prima voce prende titolo, artisti, album, durata e `musicVideoType`: `ATV` (Topic) e `OMV` (ufficiale) → identità sicura; `UGC` e gli altri → proposta (R-183). YouTube Music non dà la descrizione «Provided to YouTube by…»: `sure` dipende solo da `musicVideoType`. Parser puro | `lib/services/online/innertube_client.dart`, `ytm_song_parser.dart` (nuovo) |
| `TrackRecognizer` (nuovo) | La cascata (R-161), §Flusso 1. `recognize(Track t, {textProbe, cancel}) → RecogOutcome { rec, lost, asked, limited }`; in più `recognizeOnline(videoId)` (solo 1b e cover, niente scritto, `onlineRecognitionProvider` in memoria; tiene solo i successi). `textProbe` è `resolver.resolve` dell'engine: con tag affidabili la ricerca testuale del passo 2 **è** la ricerca dei metadati di oggi, e la sua risposta torna come `meta` senza una seconda chiamata. Sceglie il recording AcoustID col punteggio a soglia e la somiglianza del titolo (R-165); un recording con parole di versione (live, remix, acoustic…) che il file non nomina non è mai `sure`. Un'impronta illeggibile è una fonte in errore (`lost`), non «niente». Cerca l'originale delle cover (R-173). Legge `useAcoustId()` a ogni brano | `lib/services/recognition/track_recognizer.dart` |
| `EnrichEngine._gather` | Prima delle parti: `rec` salvato di questa versione e usabile (non `discarded`), altrimenti `recognize` quando una parte è dovuta o `needsRecognition`. Con tag affidabili e meta non dovuta niente AcoustID/YTM. `q = rec?.identity?.applyTo(t) ?? t`, poi `resolver.resolve(q, cleanSearchQuery(q.title, q.artist ?? ''), …)`, `chain.find(q, …)` e `curiosities.find(q, …, original: rec?.original)`. Un'identità **appena trovata** chiede le parti vuote anche sopra un segno «niente» recente: `isDue(..., mode: retryNone)`, solo in `AskMode.due`, perché il segno valeva per i tag grezzi. Un'identità scartata non guida più le ricerche. Copertina, album, `fillableFields` e chiave d'album restano sulla riga vera. `EnrichGather.rec` e `recAsked` nuovi; `signal` conta `recAsked` come risposta | `lib/services/online/enrich_engine.dart`, `enrich_gather.dart` |
| `EnrichCommitter` | Nuovo `_commitRec`, prima di `_commitCredits`: unisce `rec` al JSON letto una volta in `commitOne` e lo scrive nell'upsert di `_writeMarks`; mette `mbid` solo se è vuoto. `CreditsEnricher.save` riceve il JSON già unito (`baseDetails`) invece di sovrascriverlo con `TrackDetails` da solo, così le letture per brano restano ≤ 3 (fase 69b). Dopo la transazione, un'identità `sure`, diversa dai tag, su una riga non `userEdited` e non già decisa passa a `TrackCorrections.apply(byUser: false)` (`prop: auto`); non sicura → `open`; correzione fallita → `open`. `track_enrich.mbid` solo se sure e usabile | `lib/services/online/enrich_commit.dart`, `credits_enricher.dart` |
| `details` condiviso | `mergeDetails(raw, {TrackDetails? details, Recognition? rec})` è l'unico modo di scrivere la colonna: tiene le chiavi dell'altro. `decodeDetails` restituisce null quando non c'è nessuna chiave di `TrackDetails`, così una riga con solo `rec` resta «senza dettagli» per `saveIfNone` e per la scheda. `decodeRec(raw)` è nuovo | `lib/data/repositories/credits_repository.dart`, `lib/services/online/credits.dart` |
| `TrackCorrections` (nuovo) | Lo stesso percorso della modifica a mano (D-308). `apply(track, rec, {byUser})`: `TrackEdit` dalla riga con titolo e artista dell'identità → `TrackEditor.save(..., markEdited: byUser)` → `writeToFiles` se la modifica a mano scriverebbe il file (`writeTagsToFiles`, `tagWritableProvider`), con MBID e ISRC nei `TagChanges` (R-185) → riga del Registro `kind: 'correction'`, `detail = {trackId, old: {title, artist}, new: {…}, src}`. Poi `rec.prop = accepted|auto` e `rec.was`. `discard(trackId)` → `prop = discarded`. `revert(logRow)` si fa solo se la riga ha ancora `new`: rimette titolo e artista con `save(markEdited: false)` e ISRC/MBID nel file, poi `discarded`. `detail = {trackId, old:{title,artist,isrc?,mbid?}, new:{title,artist}, src}` (`old` isrc/mbid dal file, vuoto = nessuno); la riga del Registro dura 30 giorni. Tutto in una transazione (`CreditsRepository.setRecDecision`), file dopo; le automatiche non toccano il file del brano in riproduzione e non fanno la copia di backup | `lib/services/library/track_corrections.dart` |
| `TrackEditor.save` | Nuovo parametro `markEdited` (di serie true, come oggi). Una correzione automatica non segna il brano `userEdited`: altrimenti `fillableFields` non riempirebbe più l'album. Una proposta accettata dall'utente sì. `TagChanges` + `isrc`, `mbid`; `Metadata` di `write_metadata` + gli stessi due campi, via lofty | `lib/services/library/track_editor.dart`, `lib/services/tags/tag_writer.dart`, `metadata_god_tag_writer.dart`, `api.rs` |
| `CuriosityService.find` | Parametro `original` in più. Con un originale cerca prima la pagina della cover; se non c'è (`song == null`), cerca con titolo e artista dell'originale. La biografia resta quella dell'artista della cover. La nota «Cover di X – Y» **non** entra nel testo salvato: la scheda la disegna da `rec.original`, così è tradotta (ARB) ed è la stessa per curiosità proprie e dell'originale (R-174) | `lib/services/online/curiosity_service.dart`, scheda del brano e sezione curiosità |
| `RecogPassIds` (nuovo `EnrichIds`) | Ripasso una tantum (R-176): candidati SQL (`recogPassQuery`, in `recog_pass_query.dart`: `enrich_status<>0`, `user_edited=0`, `COALESCE(CASE WHEN json_valid … $.rec.v …,0) < kRecogVersion`, id dopo `recogPassAfter` «v:id»); filtro `needsRecognition` per candidato senza attese; segnalibro fermo al primo brano senza `rec` (`_hold`). A fine giro sano (né `failed`, `silent`, `limited`, `cancel`) i brani senza `rec` si saltano e `recogPassDone = kRecogVersion`. Parte dopo un giro normale pulito anche a libreria completa (`passDue`) e cede solo a un nuovo avvio (`yieldPass`). Ripristino e AcoustID off→on lo azzerano. `EnrichCompleter.run` lo fa partire dopo un giro normale chiuso senza errori, con le stesse parti e `AskMode.due`, quindi con la pausa per inattività. Il filtro vero è `needsRecognition` in Dart, nel gather: un brano che non ne ha bisogno costa una lettura e nessuna chiamata | `lib/services/online/enrich_runner.dart`, `enrich_completer.dart`, `lib/providers/online_providers.dart` |
| Proposte (UI) | La scheda del brano mostra «Proposta: Titolo – Artista», con Accetta e Scarta, e «Cover di X – Y». Nel Registro/Arricchimento c'è «Da confermare (N)» con «Accetta tutte» (R-170). Lettura: `CreditsRepository.watchProposals()`, cioè `json_valid` e `json_extract(e.details,'$.rec.prop') = 'open' AND t.user_edited = 0`. «Accetta tutte» (`ActionButton`) lavora un brano alla volta | `lib/ui/screens/…` (scheda, registro), `lib/l10n/*.arb` |
| Impostazioni e provider | `AppSettings.acoustId` (di serie true) con l'interruttore «Riconosci dal suono (AcoustID)» nelle impostazioni online (R-164); `deezerMeta` di serie true, anche come ripiego di `getBool` (R-180); `enrichMinutes` a 7 s per brano (R-181); `acoustIdClientProvider`, `fingerprinterProvider`, `trackRecognizerProvider`, `trackCorrectionsProvider`; `enrichEngineProvider` riceve `recognizer` e `onSure` | `lib/data/settings/settings_store.dart`, `lib/providers/online_providers.dart`, `settings_pages.dart` |
| Deezer con query pulita | `MetadataResolver.deezerHit(t, c, cancel)`: `DeezerWant` con titolo e artista di `CleanQuery`, l'ISRC dalla copia `q` (R-179). Chi lo chiama da fuori (`CreditsEnricher`) passa `cleanSearchQuery` | `lib/services/online/metadata_resolver.dart`, `credits_enricher.dart` |

### Flussi
1. **Arricchimento in sottofondo di un file YouTube sporco** («Believer (Romy Wave Cover) [xxxxxxxxxxx].mp3», artista «7clouds Rock»).
   - **Ingresso.** `EnrichRunner` → `engine.gather` → nessun `rec` salvato. `needsRecognition` è vero: tag dubbi o almeno una parte vuota, e nessun `rec` di questa versione → `TrackRecognizer.recognize`. Sui limiti: l'engine fa già la pausa di `enrichLimiterProvider` tra un brano e l'altro; ogni client ha la sua quota (AcoustID 340 ms, MusicBrainz 1,1 s, YTM e iTunes come oggi), e chi è in pausa per quota lancia `RateLimitedException`. Un passo che lancia per rete, quota o formato si salta e segna `lost`: si va avanti, nessun errore per l'utente (R-168).
   - **Passo 1, ID nei tag.** `t.isrc`, oppure `read_ids` per ISRC o MBID → MusicBrainz `recordingById`/`recordingsByIsrc` con controllo della durata → identità `tags`, `sure`.
   - **Passo 1b, video id.** Da `DownloadIndex.idForPath(path)` (solo memoria), poi `playlist_import_items.videoId` con `trackId = t.id`, poi `videoIdOf(path)` → `songOf(id)` → identità `ytid`: `sure` se `ATV`/`OMV`, proposta se no.
   - **Passo 2, ricerca testuale.** Solo con tag affidabili: `textProbe` (Deezer e iTunes con la query pulita). Se trova, identità `text` e `meta` già in mano.
   - **Passo 3, AcoustID.** Con tag dubbi o testo da sondare (`dubious` o `textProbe != null`), e solo se il passo 2 non trova niente; con tag affidabili e meta non dovuta si salta (passi 3 e 4), se `useAcoustId()` è vero e il formato non è Opus/WebM: `Fingerprinter.of(path)` (Rust) → `AcoustIdClient.lookup` → si tengono i risultati con score ≥ 0,9 e durata entro ±10 s, e si sceglie il recording più simile a `cleanSearchQuery` e al nome del file (R-165). `sure` se il titolo è coerente.
   - **Passo 4, YouTube Music.** `searchSongs` con la query pulita, durata entro ±10 s, titolo che si sovrappone → identità `ytm`, sempre proposta (D-304).
   - **Cover.** `coverHint`, oppure l'attributo `cover` (solo MBID dei tag) → originale da `workOriginal`, altrimenti ricerca testuale del titolo senza le parole di cover (R-173). Una ricerca dell'originale fallita fa perdere il `rec` (si riprova).
   - **Parti.** Con `q = identity.applyTo(t)` si cercano meta (se non già dal passo 2), testi e curiosità; le parti vuote sono chieste anche sopra un segno «niente». Se il passo 2 non è servito e i metadati trovano qualcosa con tag dubbi, quel risultato diventa un'identità `text` non sicura.
   - **Scrittura.** `commit` scrive i campi vuoti come oggi e `rec` nel JSON. Dopo la transazione, se `sure`, il brano non è `userEdited` e titolo o artista sono diversi → `TrackCorrections.apply(byUser: false)` → Registro con il valore vecchio. Se non è sicura, `prop: open`.
   - **Quando non si salva `rec`.** Se un passo è andato perso (`lost`) e nessuno ha trovato niente, `rec` non si scrive: il brano riprova al giro dopo. Se tutti hanno risposto «niente», `rec = {v, at, src: null}`: non riprova più fino a una nuova `kRecogVersion`, e il resto è come oggi.
2. **Proposta → Accetta / Scarta.**
   - **Mostrare.** La scheda legge `decodeRec` e mostra la proposta solo se `prop == open` e il brano non è `userEdited`. «Da confermare (N)» viene da `watchProposals`.
   - **Accetta.** `TrackCorrections.apply(byUser: true)` → `TrackEditor.save` (segna `userEdited`, come una modifica a mano) → file se la modifica a mano lo scrive, con MBID e ISRC → riga del Registro con `old` → `rec.prop = accepted`, `rec.was = old`. «Accetta tutte» fa la stessa cosa un brano alla volta con `apply(byUser: true)`.
   - **Scarta.** `rec.prop = discarded`. Un nuovo arricchimento, anche manuale con `retryNone`, riusa il `rec` salvato e non riconosce di nuovo: la proposta non torna. Anche un passaggio a una nuova `kRecogVersion` tiene `discarded` quando l'identità trovata è la stessa; un'identità diversa toglie `discarded` (R-171).
   - **Tornare indietro.** Dal Registro, «Ripristina» → `TrackCorrections.revert` → `save` con i valori di `old`.
3. **Cover → originale → curiosità con la nota.** `rec.original = {title, artist, mbid?}` (flusso 1). `_gather` chiama `curiosities.find(q, lang, original: rec.original)`. Se la cover ha una sua pagina, si usa quella; se no, la pagina dell'originale (solo titolo e artista dell'originale nel finder; la biografia resta quella dell'artista della cover). `CuriosityService.save` scrive il testo come oggi. La scheda e la sezione curiosità leggono `rec.original` e mettono in testa «Cover di Titolo – Artista» (ARB), in entrambi i casi. Per i video non si scarta niente (R-174). Per i brani online (R-186): `videoIdOf('stream:youtube:<id>')` → passo 1b; il resto è identico.

### Dati
`track_enrich.details` (testo JSON già esistente). I campi di `TrackDetails` restano al primo livello; si aggiunge una chiave:
```json
{
  "bpm": 120, "label": "…",
  "rec": {
    "v": 2,
    "at": 1767225600000,
    "src": "acoustid",
    "score": 0.97,
    "sure": true,
    "title": "Believer", "artist": "Imagine Dragons", "ms": 204000,
    "isrc": "USUM71700626", "mbid": "…", "vid": "xxxxxxxxxxx",
    "prop": "auto",
    "was": {"title": "Believer (Romy Wave Cover)", "artist": "7clouds Rock"},
    "original": {"title": "Believer", "artist": "Imagine Dragons", "mbid": "…"}
  }
}
```
- `src`: `tags`, `ytid`, `text`, `acoustid` o `ytm`; null se il riconoscimento non ha trovato niente (e allora mancano titolo e artista).
- `prop`: `auto` (corretto da sé), `open` (proposta), `accepted`, `discarded`; null se non c'è niente da cambiare.
- `was`: solo dopo una correzione.
- `original`: solo per le cover; ogni cover ha `"cover": true`; `original` manca se non si trova.
- `v` è `kRecogVersion`: si alza solo per rifare il ripasso con regole nuove.

Righe di oggi: senza `rec` vuol dire «mai riconosciuto»; `TrackDetails.fromJson` ignora le chiavi che non conosce. `track_enrich.mbid` prende il MBID dell'identità solo se è vuoto. I dati utente del backup, condivisione e Jam esportano solo `TrackDetails.toJson()` (`user_data.dart`, `track_meta.dart`): `rec` non viaggia e il formato non cambia (D-280, RNF-20). Il backup completo copia il DB (`VACUUM INTO`) e riporta anche `rec`, comprese le scartate; `recogPass*` sono legati al dispositivo e azzerati al ripristino (accettato, D-301). shared_preferences: `acoustId`, `recogPassAfter`, `recogPassDone`. Registro: `kind: 'correction'` e una riga riassuntiva del ripasso. Nessuna tabella e nessuna colonna drift.

### Invarianti
1. Un brano `userEdited` non cambia mai titolo né artista per il riconoscimento e non ha proposte aperte. `fillableFields`, `isDue`, `dueSql` e `statusAfter` restano identici (R-169, D-299).
2. Senza identità (nessun passo trova, interruttore spento, offline) `_gather` fa le stesse chiamate di oggi, con gli stessi argomenti e nello stesso ordine, e scrive gli stessi segni «niente». Con un recognizer che non trova niente le chiamate delle parti sono identiche; quelle del riconoscimento si aggiungono. Il test di caratterizzazione della 69b resta verde (R-160, R-168).
3. Con il riconoscimento spento (`recognizer == null` nell'engine) non parte nessuna chiamata nuova e nessun `rec` viene scritto. Con `acoustId` spento non c'è nessuna impronta e nessuna chiamata AcoustID (R-164).
4. Una correzione passa solo da `TrackCorrections` → `TrackEditor`: ogni titolo o artista cambiato ha la sua riga `correction` nel Registro, con il valore vecchio (R-171).
5. Una proposta `discarded` non torna più `open` senza un'azione dell'utente, finché l'identità è la stessa; un'identità scartata non guida più le ricerche (R-171).
6. `rec` si scrive solo dentro `commit` (una transazione con i segni) o da `TrackCorrections` (via `CreditsRepository.setRecDecision`) e `moveInto`, sempre con `mergeDetails`: una scrittura di `TrackDetails` non cancella `rec`, e una di `rec` non cancella `TrackDetails`.
7. Impronta, decodifica e lettura degli ID girano in Rust o in un isolate, mai nel thread della UI (RNF-18).
8. Quote: AcoustID ≤ 3 al secondo, MusicBrainz ≤ 1 al secondo, con User-Agent `apiUserAgent`. Un 429/503 mette in pausa solo quella fonte (R-167).
9. Parte solo l'impronta e la durata, mai byte audio (D-306).
10. Il ripasso visita ogni brano al più una volta per `kRecogVersion` e non sovrascrive campi pieni; un brano senza `rec` in un giro sano si salta e il ripasso non lo riprova per questa versione (R-176).
11. Al commit restano ≤ 3 letture per brano (contate con `QueryInterceptor`, fase 69b).

### Test in memoria
- **Ci sono già:** `EnrichRig`, `EnrichWeb` (finto `WebClient` con le risposte per URL: MusicBrainz, iTunes, Deezer), `FakeChain`, `FakeFinder`, `FakeGw` (`test/support/enrich_fakes.dart`), `fake_ytm.dart`, `QueryInterceptor` della 69b, DB drift in memoria.
- **Nuovi:**
  - `FakeFingerprinter`: una mappa da percorso a impronta, oppure lancia.
  - `FakeAcoustId`: risponde con le fixture ridotte di Test.zip in `test/fixtures/acoustid/` e registra le chiamate.
  - `FakeInnerTube.songOf`.
  - `FakeTagWriter`, che registra i `TagChanges`.
  - `DownloadIndex` su un file temporaneo.
  - Orologio e `pause` iniettati in `AcoustIdClient` e `RateLimiter` (R-167).
- **Tabelle pure:** `tag_signals_test` (37 canali + 10 artisti veri, 10 cover + 10 normali, video id), `query_cleaner_test` (titoli rumorosi), `track_identity_test` (JSON avanti e indietro, input malformato), scelta del recording AcoustID («Fairytale», «Heathens», «Happier», 0,85, +15 s).
- **Motore** (`enrich_recognition_test.dart`): un ramo della cascata per test (R-161), invarianti 2, 3, 5 e 6, ripasso (R-176), cover e curiosità (R-173/R-174), proposte e correzioni con il Registro (R-169…R-171, R-185).
- **Lettore:** file generati con ffmpeg ed etichettati con lofty nei test Rust, MBID e ISRC per formato, data «20151119» (R-162, R-177).
- **Rust:** `cargo test` confronta le impronte con quelle di fpcalc 1.6 in fixture (R-166).
- **Widget:** scheda con la proposta e «Cover di», «Da confermare» con «Accetta tutte».

### Dove va il codice nuovo
- `lib/services/recognition/`: `track_recognizer.dart`, `track_identity.dart`, `channel_detector.dart`, `video_id.dart`.
- `lib/services/online/`: `acoustid_client.dart`, `ytm_song_parser.dart`.
- `lib/services/tags/fingerprinter.dart` e `lib/services/library/track_corrections.dart`.
- Rust in `third_party/metadata_god/rust/src/api/` (`fingerprint.rs`, `read_ids` in `api.rs`), più i binding rigenerati in `third_party/metadata_god/lib/src/rust/`.
- Il resto nei file che esistono già (tabella sopra).
- Test in `test/services/online/` e `test/services/tags/`, fixture in `test/fixtures/`, test Rust nel crate.

## Rischi
Rischi scelti dall'utente come prioritari (D-321): K-RB-01, K-RB-02, K-RB-03, K-RB-04/05; ciascuno ha un controllo con comando nei criteri delle fasi. Il rischio che conta di più è il primo: il riconoscimento non deve peggiorare l'arricchimento che oggi funziona. Per questo il primo passo di codice nel motore è la caratterizzazione (invariante 2), prima di qualsiasi ramo nuovo.

| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale d'allarme |
|---|---|---|---|---|---|
| K-RB-01 | Regressione dell'arricchimento di oggi: la copia `q` finisce in una scrittura (album, chiave d'album, copertina sulla riga sbagliata); una scrittura di `TrackDetails` cancella `rec` o viceversa; un'identità sbagliata riempie album e anno di un altro brano | M | A | Chiamate e argomenti di `_gather` senza identità fissati prima del cambio (invariante 2). `q` va solo a resolver, chain e curiosità; `commit` legge di nuovo la riga vera. `mergeDetails` unico punto di scrittura, con il test di andata e ritorno. Soglie rigide (D-300) | Un test esistente di `enrich_*`, `enrichment_*` o `quiet_enricher` cambia senza che il passo lo dica; nella prova su Test.zip un album compare su un brano corretto da tag affidabili |
| K-RB-02 | L'impronta di rusty-chromaprint non coincide con quella di fpcalc 1.6 (preset, ricampionamento, primi 120 s, compressione, issue #22 «impronta vuota») e AcoustID risponde vuoto | M | A | Primo passo della prima fase: confronto in `cargo test` sulle fixture generate e sui 147 brani a mano. Se fallisce si segue D-316 (copia corretta in `third_party/`) | Meno di 40 dei 43 riconoscimenti attesi sui 69 brani persi, oppure un'impronta vuota |
| K-RB-03 | Build Android e APK: symphonia e rusty-chromaprint (rustfft, rubato) via cargokit su 4 ABI; APK più pesante; build Windows provata solo in CI | M | M | Nella prova di D-315: `flutter build apk --debug` e `build linux`, peso prima e dopo annotato; feature minime di symphonia; `opt-level`/`lto` già del crate | APK oltre +3 MB o build cargokit rossa in CI |
| K-RB-04 | AcoustID sceglie il recording sbagliato: titoli in giapponese o russo, compilation, karaoke; il primo risultato non è quello giusto | A | M | Si sceglie fra tutti i recording (somiglianza con nome del file e tag, durata). Un titolo in un'altra scrittura rispetto al nome del file non è «coerente», quindi diventa proposta e non correzione. Ogni correzione ha la sua riga nel Registro con il valore vecchio | Nella prova più di 2 sbagliati su 69, oppure una correzione automatica in un alfabeto diverso da quello del file |
| K-RB-05 | YouTube Music: le cover di terzi passano per l'originale (11 su 44 nelle colonne sonore); `next` cambia forma (`InnerTubeChanged`) | A | M | YTM resta sempre una proposta, tranne il passo 1b con `ATV`/`OMV` (D-304, D-312). `coverHint` sul titolo del file. Parser puro con fixture; `InnerTubeChanged` → il passo si salta | Proposte YTM accettate e poi annullate dal Registro; test del parser rosso dopo un aggiornamento |
| K-RB-06 | Quote e lentezza: MusicBrainz a 1 s, AcoustID, decodifica di 120 s sul Motorola; il ripasso di una libreria grande occupa giorni; 503 a raffica | M | M | AcoustID solo per tag dubbi o testo vuoto; il ripasso con la pausa per inattività e il segnalibro; pausa per fonte; misura di R-181 a fine feature; impronta solo dei primi 120 s | Più di 8 s per brano in media sul Motorola, oppure `RateLimitedException` di AcoustID nel registro dell'app |
| K-RB-07 | «Dubbio» falso su artisti veri («Music», «Records», «Lyrics» nel nome: «The Music», «The Records», «Lyrics Born»; etichette che sono anche artisti) | M | M | Tabella di 10 artisti veri più quelli della libreria di prova. Un brano dubbio va solo ad AcoustID prima che al testo: non viene corretto se non c'è un'identità sicura. `kKnownChannels` sono nomi esatti, non pattern | Correzioni o proposte su brani con tag giusti nella prova a mano; test «nessun falso dubbio» rosso |
| K-RB-08 | `json_extract` su `details` (ripasso e «Da confermare»): righe con JSON malformato o SQLite senza JSON1 | B | M | La SQLite di `sqlite3` 3.x ha JSON1 di serie (≥ 3.38); `json_extract` di un testo malformato dà errore, quindi la query avvolge con `json_valid(e.details)`. In Dart si legge con `decodeRec` difensivo | Una query del ripasso che lancia nei log, oppure «Da confermare» sempre vuoto |
| K-RB-09 | Il bug della data ha un'altra causa. Dal sorgente di `audio_metadata_reader` 1.8.1: `DateTime(20151119)` in `parser.dart:68` (MP3 TYER/TDRC) e in `mp4.dart:289` (©day) esce dall'intervallo di `DateTime` e lancia. `_parse` perde così tutti i tag (`TagInfo()` vuoto). Un pacchetto non si corregge da qui | M | M | Ripiego su lofty (`MetadataGod.readMetadata`) quando la lettura del pacchetto lancia. Test con un file mp3 e uno m4a con quel tag; il ripiego si logga per contare i casi | Un file della prova con titolo uguale al nome del file dopo la nuova scansione; ripieghi lofty più del 5% dei file |

## Fuori perimetro
Niente è fuori perimetro (D-314). Restano **dopo questa feature** (priorità R):
- **R-187** (Fase: Dopo) Invio delle impronte ad AcoustID: campo «Chiave utente AcoustID» nelle impostazioni online (resta sul dispositivo), invio dei brani riconosciuti con certezza o confermati dall'utente. Criterio: test con client finto, nessun invio senza chiave.
- **R-188** (Fase: Dopo) Riconoscimento dal microfono (stile Shazam), solo Android: registra ~15 s, impronta e AcoustID. Criterio: prova a mano con 5 brani suonati da una cassa; AcoustID non è fatto per l'audio preso in una stanza, quindi la misura decide se vale la pena.
