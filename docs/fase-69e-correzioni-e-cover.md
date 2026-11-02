# Fase 69e — Correzioni, cover e ripasso

**Obiettivo:**
- Titolo e artista si correggono da soli quando l'identità è sicura; negli altri casi diventano proposte da accettare nella scheda o nell'elenco «Da confermare».
- Le cover si riconoscono e le curiosità parlano dell'originale.
- La libreria già arricchita si ripassa una volta, e lo stesso riconoscimento vale per i brani online.
- In chiusura si misura sul Motorola e si rimisurano i testi.

**Prerequisiti:**
- Fase 69d chiusa.
- Da leggere: `docs/feature-riconoscimento.md` (Architettura §Flussi 2 e 3, §Dati, §Invarianti; Rischi K-RB-01, K-RB-05, K-RB-06, K-RB-08).
- Decisioni: D-299, D-301…D-304, D-307, D-308, D-314, D-318, D-319, D-320.

**Intoccabili:**
- schema DB v15 e formato del backup (D-280, D-319);
- un brano `userEdited` non cambia mai titolo né artista e non ha proposte aperte (invariante 1);
- testi dell'utente e copertine a mano.

**Comando mirato:** `flutter test test/services/recognition/ test/services/online/ test/services/tags/` più i test widget della scheda del brano e del Registro (i nomi vanno presi da `test/ui/`).

## Task

### 69e.0 — Debiti della 69d (da fare per primi)
1. `needsRecognition` nel gate del motore (oggi `todo.isNotEmpty`), per il ripasso dei già arricchiti (R-176).
2. `_commitRec` unisce il `rec` vecchio: tiene `discarded` se l'identità è la stessa, tiene `was`, e non scrive proposte se la riga fresca è `userEdited`. Valutare di salvare nel `rec` anche titolo e artista di partenza.
3. Un solo lettore degli ID del file: `readFileIds` del recognizer duplica `_loftyIds` di `audio_metadata_tag_reader.dart` e `TagInfo.mbid` si legge ma non si salva. L'`mbid` di `rec` va ai crediti al posto di rifare `recordingsByIsrc`.
4. Un solo valutatore YTM (recognizer ±10 s contro `SecondOpinion` ±3 s), descritto in `02-architettura.md`.
5. L'originale delle cover con il browse `recording?work=<id>&inc=artist-credits` (dà `first-release-date`), non con `work()` e `recording-rels`.
6. `clockMs` più severo (priorità bassa).

### 69e.1 — Correzioni e proposte (R-169, R-170, R-171, R-185, D-318)

#### Passo: `TrackCorrections`
- `TrackEditor.save` prende `markEdited` (di serie true, come oggi).
- Nuovo `TrackCorrections.apply(track, rec, {byUser})`: segue lo stesso percorso della modifica a mano, compreso il file se la modifica a mano lo scrive, con MBID e ISRC (R-185).
- La riga del Registro tiene il valore vecchio.
- Automatica (`sure`, brano non `userEdited`, valori diversi): `byUser: false`, il brano non viene segnato.
- Accettata: `byUser: true`, il brano viene segnato.
- Scartata: `rec.prop = dismissed`, la proposta non torna.

**Fatto quando:** ci sono test per l'automatica, l'accettata, la scartata (riarricchendo non ricompare) e il brano `userEdited` (niente), con lo scrittore finto che riceve MBID e ISRC.

#### Passo: Interfaccia
- Nella scheda del brano: «Proposta: Titolo – Artista» con Accetta e Scarta.
- Nel Registro/Arricchimento: «Da confermare (N)» con «Accetta tutte» (`watchProposals`, `json_extract`; K-RB-08: un JSON malformato si salta e si logga).
- Stringhe ARB in tutte le lingue e semantica per l'accessibilità.

**Fatto quando:**
- ci sono test widget della scheda e dell'elenco, compreso «Accetta tutte», che svuota l'elenco;
- `flutter analyze` è pulito.

### 69e.2 — Cover (R-172, R-173, R-174, D-302, D-303)

#### Passo: Riconoscere la cover e trovare l'originale
- Nuovo `lib/services/recognition/cover_detector.dart`:
  - attributo «cover» della relazione performance di MusicBrainz;
  - parole nel titolo del file (cover, arrangement, piano/orchestral version, remix, «by X» con X diverso dall'artista dell'originale).
- L'originale si prende dal work di MusicBrainz (`work(id)`); altrimenti dalla ricerca testuale del titolo pulito, scegliendo il più vecchio o il più popolare.
- Il risultato va in `rec.original`.

**Fatto quando:**
- il test a tabella è verde: 10 cover di Test.zip riconosciute, 10 titoli normali no;
- i test con fonti finte coprono il work e la ricerca.

#### Passo: Curiosità ed etichetta
- Per una cover senza pagina propria, le curiosità si cercano con l'identità dell'originale; se la cover ha una pagina sua, restano le sue.
- La scheda disegna «Cover di X – Y» leggendo `rec.original` (ARB). Il testo delle curiosità salvato non cambia (D-320).

**Fatto quando:** ci sono test della scelta delle curiosità (con e senza pagina) e il test widget dell'etichetta.

### 69e.3 — Ripasso e brani online (R-176, R-186, D-301)

#### Passo: Ripasso una volta sola
- `RecogPassIds`: brani con `enrich_status <> 0`, senza `rec` aggiornato (`COALESCE(json_extract(details,'$.rec.v'),0) < kRecogVersion`), con tag dubbi o parti vuote.
- Il segnalibro sta in shared_preferences e il ripasso va in sottofondo con il runner di oggi.
- Riempie solo i buchi.

**Fatto quando:**
- un brano completo con tag affidabili non viene ripassato;
- un brano con il canale come artista viene ripassato una volta sola;
- i campi pieni restano invariati;
- il segnalibro riprende dopo il riavvio.

#### Passo: Brani online
- Gli item `yt:` (coda, streaming, Jam) usano il passo 1b quando la loro scheda si mostra.
- La cover porta le curiosità dell'originale e l'etichetta.

**Fatto quando:** un test con un item `yt:` di una cover è verde.

### 69e.4 — Chiusura della feature (R-181, R-182)
- Esegui `flutter analyze` pulito e i test mirati verdi.
- Review di architettura con Opus e `/code-review high` sul diff dell'intera feature (69c…69e).
- Fai la scheggia in modalità fase sull'app avviata:
  - accetta o scarta di fretta;
  - modifica a mano durante il ripasso;
  - ripristino di un backup (una proposta scartata può tornare una volta, D-319: va bene).
- Rifai la prova su Test.zip (come in 69d.4) con le correzioni: conta automatiche, proposte, sbagliate e cover trovate.
- **Motorola** (copia di sicurezza del DB prima, come in 69b.4, e `install -r`):
  - misura del ritmo con il riconoscimento attivo per 15 minuti;
  - `enrichMinutes` aggiornato al numero misurato (R-181);
  - controlla che non ci siano `[E]` nel log.
- **Testi** (R-182): se LRCLIB risponde, conta i testi trovati su Test.zip prima (master di 69b) e dopo; se non risponde ancora, annotalo in «Rimandati».
- Aggiorna `docs/02-architettura.md` §«Arricchimento» con il riconoscimento, poi `docs/handoff.md` e `docs/PROGRESS.md`.

**Fatto quando:**
- c'è la PR con la CI verde;
- esiti numerici di Test.zip, del Motorola e dei testi sono in questo documento.

### 69e.5 — Titolo ufficiale dal video id (aperto il 2026-11-02)
**Problema.** Il passo 1b (`_fromVideoId` → `_ytmSong` → `InnerTubeClient.songOf`) prende il titolo che YouTube Music dà al video.
- Per un brano audio di studio (ATV) è il nome ufficiale della canzone.
- Per un video ufficiale (OMV) o caricato da chiunque (UGC) è il titolo del video, per esempio «Get Lucky (Official Audio) (feat. Pharrell Williams & Nile Rodgers)».
- L'OMV conta come `sure` (D-312), quindi su un brano **mai arricchito** diventa una correzione automatica: D-333 copre solo i già arricchiti.
- Prova dal vivo del 2/11: la risposta anonima di `next` non porta la «controparte» canzone (ATV) di un OMV, né con `playlistId RDAMVM…`. Il nome ufficiale non arriva da lì.

**Cosa fare.**
- ATV: come oggi, titolo e artisti del video, `sure`.
- OMV e UGC: si cerca la canzone su YouTube Music, solo fra le canzoni (la ricerca del passo 4), con il titolo pulito da `cleanSearchQuery` e l'artista del video.
  - Si prende l'ATV con un artista in comune e la durata entro ±3 s (`ytmMatches`). Trovato → identità con il titolo dell'ATV; resta `sure` solo per un OMV.
  - Non trovato → titolo pulito da `cleanSearchQuery` e identità **non sicura**, quindi una proposta.
- Coerenza della versione, per tutte e tre: un titolo che nomina una versione che il file non nomina (Live, Remaster, Edit, Extended, Remix) non è `sure`. Si riusa la regola delle versioni di `_Hay`.
- Lo stesso vale per i brani online (`recognizeOnline`).

**Fatto quando.**
- Ci sono fixture (risposte vere salvate una volta) e test:
  - l'OMV di «Get Lucky» con l'ATV trovato → «Get Lucky», `sure`;
  - un OMV senza ATV → titolo pulito, proposta;
  - un UGC «… (Lyrics)» → mai `sure`;
  - un ATV «Seven Nation Army (Live)» per un file senza «Live» → proposta.
- Il conteggio di Test.zip non peggiora: 0 correzioni automatiche sbagliate.

**Esito:** fatto in `_ytmSong`/`_fromVideoId` (test con i fake del recognizer, nessuna fixture dal vivo); la prova su Test.zip non è stata rifatta.

## Esiti di 69e.4
Prova del 2026-11-02 su Linux (HEAD a5b089c), come in 69d.4: sotto xvfb, profilo e DB separati, motore, rete e impronta Rust veri, percorso `enrichJobProvider.startDue()`. I 147 file sono gli stessi di 69d.4.

| Voce | 69d.4 | 69e.4 |
|---|---|---|
| Riconosciuti | 124/147 | **126/147** |
| Per fonte | AcoustID 81 · video id 13 · testo 24 · YTM 6 | AcoustID 81 (65 sicure, 16 no) · video id 13 (sicure) · testo 24 (non sicure) · YTM 8 · tag 0 |
| Non riconosciuti | 23 | 21 (nessuno perso) |
| Correzioni automatiche (`prop` auto, righe `correction` nel Registro) | non c'erano | **77** (AcoustID 65, video id 12) |
| Proposte aperte (`prop` open) | non c'erano | **35** |
| Correzioni automatiche sbagliate | 1 `sure` sbagliata (poi corretta) | **0** (controllate a vista contro nome del file e tag) |
| Cover (`rec.cover`) | non c'erano | 4 trovate, **0 con originale** |
| Meta nuova · curiosità | 71 · 37 | 71 · 38 |
| Testi (R-182) | 6 | **11** (4 testo semplice, 8 sincronizzati, 1 in entrambi) |
| Tempo | 34 min · 13,9 s a brano (mediana 13,1, p90 20,6) | 29 min · 11,8 s a brano (mediana 11,5, p90 16,6) |
| `[E]` · avvisi | 0 · 9 | 0 · 10 |

**Correzioni automatiche.** Sono tutte coerenti con file e tag: nomi caricati da canali («Rammstein Official», «retrovgnamusic», «Am Project - Topic») portati al titolo e all'artista veri, artisti mancanti riempiti. Per esempio:
- «Soap&Skin - Me and the Devil (Lyrics)» / The Vibe Guide → «Me and the Devil» / Soap&Skin;
- «Super Mario World OST - Swimming» / retrovgnamusic → «Swimming» / 近藤浩治;
- «Una storia disonesta» / nessuno → Stefano Rosso;
- «Devil in Disguise» / nessuno → Marino, con durata uguale al file (104,0 s contro 104,5 s).

**Proposte aperte (35).** «Happier» (Marshmello) con identità dei Guster resta una proposta e non si applica più da sola: la correzione di 69d è tenuta. Restano proposte anche i remix al posto dell'originale (Here, Blue, Ola), «Bad Romance» → Club Mix di Liam C, i risultati YTM di altri artisti e le musiche di giochi e anime con titolo giapponese. Nessuna di queste ha cambiato il titolo.

**Da notare:**
- il flag `cover` ha 3 falsi positivi su 4: i due «The Trapper & The Trader» di Inscryption e «TEST ME» (opening di Oshi no Ko) non sono cover; «Distortion World (Arrangement)» sì. Nessun originale è stato trovato, quindi «Cover di» non compare mai in questa prova;
- il Registro ha una riga di scansione `scan 100/147` con `stopped: true` (la riga dell'arricchimento è `147/147`, corretta): l'etichetta «interrotto» è ancora sbagliata per un giro finito, come già annotato in 69d.4;
- la copertina dell'album non è stata contata a parte: sta dentro «meta nuova».

**Testi (R-182).** LRCLIB ha risposto, ma con un solo 503 (`LRCLIB answered 503: resting 3 min`, più `lyrics fallback failed ... 503`): il riposo è di 3 minuti e il giro non ha perso i testi, a differenza di 69d.4 dove il 503 li aveva tolti a tutto il giro. Trovati 11 testi contro 6.

**Avvisi (10, nessun errore):** 5 `InnerTubeChanged` su video senza canzone YTM, 2 impronte illeggibili (`unsupported audio codec` e `unsupported or unreadable audio format`), 1 tag illeggibile in «Paint It, Black», i 2 sul 503 di LRCLIB.

**Master di 69b:** il confronto dei testi «prima» (master di 69b su Test.zip) non è stato rifatto, perché il disco è corto. Il «prima» è il dato di 69d.4 (6 testi).

## Misura sul Motorola (2026-11-02, R-181)
Libreria vera di 2463 brani. Prima di ogni `install -r` c'è la copia di DB e preferenze in `.backup-motorola/codecore-2026-11-02-1058/` (D-292). Musica in pausa e app in primo piano (D-296).

**Prima prova (master 5f6aedd, 11:04–11:20).**
- In 7 minuti il ripasso ha riconosciuto 35 brani (video id 17, tag 18, tutti `sure`), circa 12 s a brano; poi il sottofondo è rimasto fermo fino al giro successivo.
- Ha fatto **9 correzioni automatiche su titoli e artisti già pieni**, spesso peggiorative, e le ha scritte anche nei file:
  - «Get Lucky» → «Get Lucky (Official Audio) (feat. …)»;
  - «Purple Rain» → «Purple Rain (7" Single Edit) (7" Single Edit; 2017 Remaster)»;
  - «Seven Nation Army» → «Seven Nation Army (Live)»;
  - «Kiss (Extended)» → «Kiss»;
  - coartisti tolti.
- È contro «il ripasso riempie solo i buchi». L'app è stata fermata.
- Decisioni dell'utente:
  - **D-333**: su un brano già arricchito (`found`) la correzione automatica riempie solo un artista vuoto o generico; il resto diventa proposta;
  - **D-334**: le 9 correzioni sono state ripristinate dal Registro con «Ripristina» (verificato nel DB: valori originali, `prop = discarded`, nessun brano segnato a mano).

**Seconda prova (APK con D-333, 11:39–11:55).**
- 48 brani riconosciuti fra le 11:42 e le 11:50, circa **10 s a brano** mentre lavora (19 s di media sui 15 minuti, per la pausa fra i giri del sottofondo).
- Fonti in totale: video id 47, tag 27, YTM 8.
- **0 correzioni automatiche, 12 proposte aperte**, quasi tutte brani caricati da canali («The Weeknd - Blinding Lights (Lyrics)» / 7clouds), che ora aspettano «Da confermare».
- **0 `[E]`**. I 24 `[W]` sono di rete: LRCLIB 503 e timeout, NetEase, lyrics.ovh, una richiesta ISRC di MusicBrainz.
- `kEnrichSecondsIdentified` passa da 7 (non misurato) a **12 s**.

**Da notare:** il sottofondo lavora a giri di circa 8 minuti con pause lunghe. Il ripasso dei 2463 brani richiede quindi molte sessioni con l'app aperta.

## Dopo questa feature
- R-187 Invio delle impronte ad AcoustID (chiave utente nelle impostazioni, mai nel repo).
- R-188 Riconoscimento dal microfono (solo Android, da misurare prima).
- Opus nell'impronta, quando symphonia lo supporterà (D-311).
- Dalla review di architettura della 69e:
  - `recog_pass_query.dart` (data) importa `enrich_engine.dart` (services), e la regola del ripasso è scritta tre volte (SQL, `needsRecognition`, gate del motore);
  - `ytmMatches` confronta solo la durata: o va tolto, o va usato anche nel passo 1b;
  - l'attributo «cover» di MusicBrainz si legge solo con il MBID dei tag; una ricerca dell'originale fallita fa perdere tutto il `rec` e rifà l'impronta al giro dopo;
  - debiti `shortcut:`: niente avanzamento del ripasso, una sola pagina da 100 in `workOriginal`, video cancellato uguale a `InnerTubeChanged`, «Walking by X», «Roxy Music» segnato come dubbio, `kKnownChannels` tarato su Test.zip.
