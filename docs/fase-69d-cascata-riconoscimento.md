# Fase 69d — La cascata del riconoscimento

**Obiettivo:** prima di arricchire, il motore riconosce il brano con la cascata (ISRC/MBID → video id → testo → AcoustID → YouTube Music) e arricchisce dall'identità trovata. Senza identità tutto resta come oggi. Le correzioni di titolo e artista e le cover arrivano nella 69e: qui l'identità serve solo a cercare meglio.

**Prerequisiti:**
- Fase 69c chiusa, con la prova dell'impronta superata.
- Da leggere: `docs/feature-riconoscimento.md` (Architettura completa, Rischi K-RB-01, K-RB-04, K-RB-05, K-RB-06, K-RB-08) e `docs/fase-69b-arricchimento-unico.md` §«Rete».
- Decisioni: D-299…D-321.

**Intoccabili:**
- schema DB v15 e formato del backup (D-280, D-319);
- `fillableFields`, `isDue`, `dueSql`, `statusAfter` (invariante 1 di `feature-riconoscimento.md`);
- con identità assente le chiamate alle fonti sono identiche a oggi (invariante 2);
- un solo punto di scrittura di `track_enrich.details`, che unisce `TrackDetails` e `rec` (`CreditsEnricher.save` oggi lo sovrascrive tutto: trappola segnalata nell'architettura).

**Comando mirato:** `flutter test test/services/online/` più `test/services/recognition/` (cartella nuova). La caratterizzazione del passo 69d.1 si esegue a ogni task.

## Task

Al massimo 4 task per fase, un commit per task.

### 69d.1 — Rete, client e quote (R-164, R-167, K-RB-01)

#### Passo: Caratterizzazione del motore di oggi
- Si scrive solo codice di test. Nuovo `test/services/online/enrich_recognition_characterization_test.dart` con `EnrichRig` (`test/support/enrich_fakes.dart`).
- Il test fissa, per 6 brani tipo (tag puliti, canale come artista, «Artista - Titolo» sotto un canale, OST, cover, senza artista), le query mandate a iTunes, Deezer, LRCLIB e alle curiosità e i campi scritti dal commit.
- Queste attese restano valide per ogni brano senza identità fino alla fine della feature.

**Fatto quando:** il test è verde sul codice di oggi senza toccare `lib/`.

#### Passo: `AcoustIdClient`
- Nuovo `lib/services/online/acoustid_client.dart` su dio:
  - `POST https://api.acoustid.org/v2/lookup` con corpo gzip (`dart:io`) e `Content-Encoding: gzip`;
  - `client=kAcoustIdClient` (`lib/core/app_info.dart`, `Hsn5w6Tjwv`, D-313), `meta=recordings+releases+compress`;
  - al massimo 3 richieste al secondo, con un `RateLimiter` dedicato.
- Le risposte di Test.zip, ridotte ai campi letti, vanno in `test/fixtures/acoustid/`.
- Interruttore «Riconosci dal suono (AcoustID)» nelle impostazioni online, acceso di serie (R-164), con stringhe ARB in tutte le lingue.

**Fatto quando:**
- i test del client sono verdi: parsing, gzip, 3/s con orologio finto, 429/503 → pausa solo di AcoustID;
- con l'interruttore spento non parte nessuna chiamata.

#### Passo: MusicBrainz esteso
`MusicBrainzClient` (`musicbrainz_client.dart:40`) aggiunge `recordingById(mbid)`, `recordingsByIsrc(isrc)` (con `inc=work-rels+isrcs+artist-credits+releases`) e `work(id)` (con `inc=recording-rels`), con la pausa di 1 s e lo User-Agent di oggi.

**Fatto quando:** i test con le risposte in fixture sono verdi, compreso il 503 → nuovo tentativo.

### 69d.2 — `TrackRecognizer`: la cascata (R-161, R-163, R-165, R-168, R-183, R-184)

#### Passo: Tag dubbi e video id
- Nuovo `lib/services/recognition/`:
  - `channel_detector.dart` (R-163): suffissi, parole e elenco dei canali noti; i 37 canali di Test.zip in fixture e 10 artisti veri come «The Music» e «Records» per K-RB-07;
  - `video_id.dart` (R-183): id dal nome del file `[xxxxxxxxxxx]` validato, oppure da `playlist_import_items.videoId` del brano collegato.

**Fatto quando:** i test a tabella sono verdi, con 0 falsi «dubbio» sugli artisti veri.

#### Passo: La cascata
- `TrackRecognizer.recognize(t, {textProbe, cancel})` restituisce `RecogOutcome {rec, lost, asked, limited}`; `rec` porta l'identità (titolo, artista, durata, ISRC, MBID) e fonte, score e `sure`. L'ordine è quello di R-161 e si ferma al primo che riesce:
  1. ISRC/MBID → MusicBrainz (durata ±10 s);
  2. 1b: video id → YouTube Music `next` per `musicVideoType`: sicuro se `ATV` o `OMV`, altrimenti non sicuro;
  3. testo (iTunes, Deezer) solo con tag affidabili;
  4. AcoustID (salvo Opus/WebM, R-184, e con l'interruttore acceso) con soglia ≥ 0,9 e durata ±10 s; si sceglie il recording più vicino al nome del file e ai tag (R-165);
  5. YouTube Music con durata ±10 s e titolo che si sovrappone, sempre non sicuro (D-304).
- Ogni fonte in errore passa alla successiva (R-168).
- La forma della risposta YTM per `musicVideoType` non è verificata (nota dell'architettura): si legge prima con una chiamata registrata.

**Fatto quando:**
- c'è un test per ramo con fonti finte (vedi i criteri di R-161, R-165, R-183, R-184, R-168);
- i casi «Fairytale», «Heathens» e «Happier» scelgono il recording giusto (K-RB-04).

### 69d.3 — Il motore arricchisce dall'identità (R-160, R-175)

#### Passo: Identità nel motore
- `EnrichEngine._gather` (`enrich_engine.dart:128`) chiama `TrackRecognizer` prima delle parti; con l'identità, meta, testi e curiosità si cercano con titolo, artista e durata dell'identità (`curiosities.find` prende l'identità; ISRC dell'identità a `finder.find`).
- Senza identità valgono le stesse chiamate di oggi.
- Il riconoscimento fa parte della stessa prenotazione del brano; niente lavoro pesante nel thread della UI (l'impronta gira nel thread di Rust).

**Fatto quando:**
- la caratterizzazione di 69d.1 è verde per i brani senza identità;
- c'è un test nuovo «identità → query con titolo e artista dell'identità».

#### Passo: Salvataggio e Registro
- `rec` va in `track_enrich.details`, con la forma JSON di `feature-riconoscimento.md` §Dati e un solo punto di scrittura che unisce `TrackDetails`. `decodeDetails` restituisce null se c'è solo `rec`.
- `track_enrich.mbid` si scrive solo se vuoto.
- La riga del Registro dice la fonte (tag, video, testo, AcoustID, YTM).

**Fatto quando:**
- un test di repository salva e rilegge `rec`;
- le righe vecchie senza `rec` si leggono;
- `CreditsEnricher.save` dopo `rec` non lo cancella;
- c'è un test della riga del Registro.

### 69d.4 — Controlli di fase e prova su Test.zip
- Esegui `flutter analyze` pulito e i test mirati verdi.
- Review di architettura con Opus e `/code-review high` sul diff: l'area a rischio è il motore d'arricchimento (K-RB-01).
- Prova su Test.zip con l'app su Linux:
  1. importa i 147 file in una libreria nuova di prova (profilo/DB separato, non quello dell'utente);
  2. lancia «Arricchisci tutta la libreria»;
  3. conta i brani con identità o meta trovati, per fonte, i tempi a brano e gli errori.

  Criterio (scelta dell'utente): **≥ 110/147 riconosciuti** e **0 identità `sure` sbagliate**. Un'identità sbagliata non sicura è ammessa, perché diventerà una proposta nella 69e.
- Fai la scheggia in modalità fase: rete staccata a metà, AcoustID che risponde 503, file Opus, file di 0 byte.
- Annota gli esiti qui sotto e spunta `docs/PROGRESS.md`.

**Fatto quando:**
- c'è la PR con la CI verde;
- il criterio su Test.zip è annotato con i numeri;
- sotto 110 o con un `sure` sbagliato si corregge prima di chiudere, oppure si chiede all'utente.

## Esiti di 69d.4
_(da scrivere)_
