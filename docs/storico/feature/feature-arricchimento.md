# Feature «Arricchimento completo» (con copertine a mano)

Sotto il brano compaiono tutti i dettagli che si possono avere: crediti con ruoli e strumenti (Deezer, MusicBrainz), BPM, etichetta, copyright, date, popolarità. Tutto l'arricchimento dei brani (testo, curiosità, crediti e dettagli) resta salvato nel database, e la libreria esistente si completa da sola in background. La feature porta anche la copertina scelta a mano per brano, album e playlist, e un Registro che tiene ogni attività in background.
Per chi: l'utente, sulla sua libreria (Motorola edge 40, 2196 brani, 1917 con testo, D-04). Perché ora: oggi Deezer dà solo i metadati base, curiosità e crediti non si cercano mai da soli e la libreria resta a metà.

Kickoff del 2026-10-25 (richiesta originale: `docs/prossimi-lavori.md` §2b, più la copertina a mano chiesta durante il kickoff). Decisioni: D-96 e seguenti in `docs/decisioni.md`.
Fasi: vedi `docs/PROGRESS.md` (50 e seguenti).

## Stima del peso (richiesta prima di tutto)
Base: la misura della fase 28 (3000 brani arricchiti ≈ 25–30 MB di testo, ≈ 8 KB per brano) e le prove dal vivo del 2026-10-25 sulle risposte di Deezer e MusicBrainz.

| Parte | Per brano | 2196 brani |
|---|---|---|
| Testo (semplice + sincronizzato) | 5–7 KB | 10–15 MB |
| Curiosità del brano | 1,5–3 KB | 3–6 MB |
| Crediti e dettagli (solo i campi utili) | 1–2 KB | 2–4 MB |
| **Totale** | | **≈ 20–25 MB** |

Bio degli artisti (`ArtistInfos`): una per artista, < 1 MB in tutto. Il testo non si accorcia mai; con questi numeri non serve rinunciare a niente (D-96).

## Requisiti
Priorità: **I** indispensabile · **U** utile · **R** rimandabile. Tutto vale uguale su Android, Linux e Windows.

### Fonti dei crediti e dei dettagli
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-35 | Interruttore nuovo «Crediti e dettagli», con la nota «usa anche un'API non ufficiale di Deezer», separato da «Metadati da Deezer» e spento di serie. Spento: nessuna richiesta per crediti e dettagli | I | Test: interruttore spento → né il client Deezer interno né quello dei crediti MusicBrainz ricevono chiamate | 50 |
| R-36 | Con R-35 acceso il brano si cerca su Deezer (ISRC, poi testo con il controllo di `pickDeezerTrack`) anche se «Metadati da Deezer» è spento. In quel caso nessun metadato si scrive | I | Test: metadati Deezer spenti, crediti accesi → id Deezer trovato e dettagli salvati, titolo/anno/genere invariati | 50 |
| R-37 | Dettagli dall'API pubblica: BPM (solo se > 0), etichetta, data di uscita digitale, tipo di uscita (album, singolo, EP), posizione in classifica del brano (`rank`), fan dell'album, esplicito | I | Test di parsing su JSON reali salvati come fixture: tutti i campi letti; `bpm: 0` → nessun BPM | 50 |
| R-38 | Crediti dall'API interna di Deezer, con sessione anonima (`deezer.getUserData` → `checkForm`, poi `deezer.pageTrack`): `SNG_CONTRIBUTORS` (ruolo → nomi), `COPYRIGHT`, `PHYSICAL_RELEASE_DATE` | I | Test di parsing su fixture reali (Lose Yourself, One More Time); test del client: token scaduto → nuova sessione una volta sola | 50 |
| R-39 | Crediti da MusicBrainz, una chiamata per brano (`/ws/2/recording/{mbid}?inc=artist-rels+work-rels+work-level-rels`): interpreti con strumento o voce, produttori, mix, programmazione, registrazione; dal work compositore, paroliere, autore. Solo relazioni verso artisti; si tiene l'MBID | I | Test di parsing su fixture reali (Get Lucky: 6 strumenti, 2 voci, 2 produttori, 4 autori); le relazioni work→work si scartano | 50 |
| R-40 | Crediti delle due fonti uniti senza doppioni: Deezer prima, MusicBrainz aggiunge solo le coppie persona+ruolo che mancano (nomi confrontati senza maiuscole e accenti) | I | Test: Deezer {composer: A}, MB {composer: A, guitar: B} → A compositore una volta sola, B chitarra | 50 |
| R-41 | API interna di Deezer che non risponde o cambia formato: dopo 3 errori di fila si mettono in pausa solo i crediti Deezer per 24 ore, con una riga nel Registro; MusicBrainz, metadati e testo continuano | I | Test con orologio finto: 3 errori → nessuna chiamata per 24 h, poi di nuovo; 1 riga nel Registro | 50 |

### Dove si vedono
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-42 | Schermata di riproduzione: card «Crediti e dettagli» accanto alle Curiosità. In cima i dettagli in righe brevi (BPM · etichetta · ©, date, tipo, classifica e fan, bollino esplicito), poi i gruppi Interpreti e strumenti, Autori, Produzione e tecnici, Altro. Oltre 8 righe di crediti si chiude con «Mostra tutto». Senza crediti né dettagli la card non c'è | I | Widget test: brano con 12 crediti → 8 righe + «Mostra tutto»; brano senza niente → nessuna card | 51 |
| R-43 | Ruoli e strumenti tradotti in tutte le lingue dell'app (it, en, de, es, fr, pt), da una tabella chiave → stringa ARB; un ruolo non in tabella si mostra com'è (trattini bassi → spazi) | I | Test: `drumprogrammer` → «Programmazione batteria» in it; `drum machine drums` → testo grezzo | 51 |
| R-44 | I nomi nei crediti sono link alla pagina artista: in libreria se c'è, altrimenti online, con lo stesso risolutore degli artisti ospiti (fase 49) | I | Widget test: tap su un nome in libreria apre la pagina locale, su uno assente quella online | 51 |
| R-45 | Pulsante «Aggiorna» nella card: rifà subito la ricerca di crediti, dettagli e curiosità di quel brano, ignorando l'attesa di 30 giorni (R-54) | I | Test: tap → una nuova richiesta anche con un «niente» di ieri | 51 |
| R-46 | Crediti e dettagli anche nella schermata info brano della Jam (host e ospiti) e nella finestra di anteprima dell'arricchimento | I | Widget test delle due schermate con un brano che ha crediti | 51 |
| R-47 | Pagina artista: sezione «Compare come» con i brani di libreria in cui il nome compare nei crediti, a gruppi per ruolo; non c'è se non ne ha | I | Test: artista produttore di 2 brani e autore di 1 → 2 gruppi | 51 |
| R-48 | Ricerca locale: i brani in cui il testo cercato è un nome nei crediti compaiono in un gruppo «Nei crediti», sotto i risultati normali e senza doppioni | I | Test: cercare «Pharrell» trova Get Lucky (credito) nel gruppo, non due volte | 51 |

### Salvataggio e completamento
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-49 | Crediti e dettagli si salvano nel database con il brano, anche sulla riga ombra dei brani in streaming (D-77): con «Scarica» restano | I | Test: brano in streaming con crediti → «Scarica» → il brano di libreria ha gli stessi crediti | 50 |
| R-50 | Dopo un download si cercano e si salvano in automatico tutte le parti accese: metadati («Arricchimento automatico»), testo («Testi automatici»), curiosità del brano e bio dell'artista (interruttore nuovo «Curiosità automatiche», spento di serie), crediti e dettagli (R-35) | I | Test: download con tutto acceso → il brano ha testo, curiosità, crediti; con curiosità spente → nessuna richiesta a Wikipedia | 52 |
| R-51 | Completamento in background della libreria: gira da solo mentre l'app è aperta (anche in riproduzione), su qualsiasi rete, finché ogni brano ha tutte le parti accese; cerca solo le parti accese e mancanti; riparte dal punto in cui era al riavvio | I | Test: 3 brani incompleti, app «riavviata» dopo il primo → riprende dal secondo; con tutti completi non fa richieste | 53 |
| R-52 | Il completamento va piano e cede il passo: un brano alla volta entro i limiti di ogni fonte, in pausa mentre si scorre, si cerca o si scarica, e riprende 5 s dopo l'ultima di queste attività | I | Test con orologio finto: un download in corso → nessun brano lavorato finché non finisce + 5 s | 53 |
| R-53 | Un solo comando, «Arricchisci tutta la libreria» (D-277), nelle impostazioni dell'arricchimento: lavora i brani con una parte dovuta in `AskMode.retryNone` (salta i completi, riprova anche i «niente» recenti), con metadati, testi e curiosità sempre e i crediti solo con «Crediti e dettagli»; il sottotitolo dice «N brani da completare, circa M minuti» o «Libreria completa» (comando disabilitato); mentre gira mostra «Interrompi». Non aspetta l'utente a riposo | I | Test: comando su 5 brani, 2 completi e 1 «niente» di ieri → 3 lavorati; a libreria completa il comando è disabilitato | 53, 69b |
| R-54 | Una parte per cui la fonte non trova niente (testo, curiosità, crediti, metadati) si segna «cercato, niente» con la data, per parte; il completamento la riprova da solo dopo 30 giorni | I | Test con orologio finto: «niente» il giorno 0 → non riprovato al giorno 29, riprovato al 31 | 52 |
| R-55 | Testo: LRCLIB, poi NetEase (sincronizzato, accettato solo con titolo e artista uguali dopo la pulizia e durata entro ±3 s), poi lyrics.ovh (semplice). Un testo semplice si salva subito; la versione sincronizzata si riprova dopo 30 giorni | I | Test con client finti: LRCLIB vuoto, NetEase con durata sbagliata → si usa lyrics.ovh; dopo 31 giorni si richiede la versione sincronizzata | 52 |
| R-56 | Si riempiono solo le parti vuote; ciò che l'utente ha modificato a mano (`userEdited`, testo scritto o scelto da lui, copertina a mano) non si tocca mai | I | Test: brano con testo modificato a mano → il completamento non chiama i client del testo | 52 |
| R-57 | Crediti e dettagli viaggiano ovunque viaggi già il testo: backup, invio ad altri dispositivi, Jam. Un backup vecchio senza questi campi si ripristina come oggi | I | Test di andata e ritorno di `user_data` e `TrackMeta` con crediti; ripristino di un backup v-precedente senza errori | 51 |
| R-58 | Pagina Memoria: riga «Arricchimento: N MB» con il dettaglio testi, curiosità, crediti; nessun pulsante per cancellare | I | Test della query delle dimensioni su un DB con dati noti | 53 |

### Registro delle attività
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-59 | Il Registro si salva nel database e tiene gli ultimi 30 giorni; «Svuota» resta | I | Test: righe di 31 giorni fa sparite all'avvio; dopo il riavvio le altre ci sono | 53 |
| R-60 | Ogni processo in background lascia una riga quando finisce, si ferma o va in pausa: download, importazioni, trasferimenti, secondo parere (come oggi), più scansione, arricchimento a mano e in background, pulizie, nuove uscite, aggiornamento dei podcast e download degli episodi, radio | I | Test: ogni valore di `ActivityKind` produce una riga del Registro alla fine | 53 |
| R-61 | Il completamento lascia una riga per giro (a ogni pausa o fine): «Arricchimento: 120 brani completati, 8 senza testo»; toccandola si vede l'elenco dei brani aggiornati e di quelli senza risultato, per parte | I | Widget test: tap sulla riga → elenco con i due gruppi | 53 |
| R-62 | Mentre gira, il completamento compare nel centro Attività con l'avanzamento (completi / totale) e i pulsanti Pausa e Riprendi | I | Widget test: voce `enrichBackground` con «1530 / 2196» e Pausa | 53 |

### Copertina a mano
| ID | Requisito | Priorità | Criterio di accettazione (verificabile) | Fase |
|---|---|---|---|---|
| R-63 | «Cambia copertina» per brano, album e playlist, con un selettore unico: file dal dispositivo, proposte online, copertina di un altro brano o album della libreria (per la playlist le proposte sono le copertine dei suoi brani). Niente indirizzi web | I | Widget test: il selettore ha le tre fonti per brano e album; per la playlist propone le copertine dei suoi brani | 54 |
| R-64 | Le proposte online (Deezer e iTunes, più edizioni) si cercano solo quando l'utente apre il selettore, anche con «Metadati da Deezer» spento, e mostrano la misura in pixel | I | Test: nessuna richiesta prima dell'apertura; ogni proposta ha larghezza × altezza | 54 |
| R-65 | La copertina di un album vale per l'album e per ogni suo brano, tranne quelli con una copertina a mano propria | I | Test: album di 3 brani, uno con copertina a mano → cambiano gli altri 2 | 54 |
| R-66 | Una copertina a mano non la cambiano né la scansione né l'arricchimento; «Ripristina copertina originale» la toglie e torna quella del file o dell'arricchimento. Nel file musicale non si scrive | I | Test: scansione e arricchimento dopo il cambio → stessa `coverKey`; il file non cambia (hash uguale) | 54 |
| R-67 | Le copertine a mano sono nel backup e un ripristino le rimette | I | Test di andata e ritorno del backup con una copertina a mano | 54 |

## Requisiti non funzionali
| ID | Requisito | Misura |
|---|---|---|
| RNF-04 | Peso nel database contenuto | ≤ 30 MB in più per 2196 brani completi (stima 20–25 MB); misura con la query di R-58 |
| RNF-05 | Il completamento non toglie fluidità: lavoro di rete e DB fuori dal thread UI, scritture a blocchi | `scripts/perf_device.py` sul Mi A3 con il completamento attivo: entro le soglie della fase 38/44, tolleranza di un frame (come RNF-01) |
| RNF-06 | Rispetto delle fonti | MusicBrainz ≤ 1 richiesta/s con User-Agent e attesa se «busy»; Deezer con il cooldown di oggi; NetEase e lyrics.ovh con timeout 8 s; nessuna chiave nel codice |
| RNF-07 | Le funzioni di oggi restano invariate | test esistenti di arricchimento, download, backup, Jam e copertine delle playlist verdi |

## Fuori perimetro
- Crediti scritti nei tag del file (D-110) e copertina a mano scritta nel file (D-117).
- Editor dei crediti: solo «Aggiorna» (D-107).
- Testi da Deezer (anonimi non arrivano), Musixmatch, Genius e altre fonti con chiave o bloccate (D-111).
- Copertina da indirizzo web (D-114).
- Completamento ad app chiusa (D-102).

## Architettura
Approvata il 2026-10-25 (D-121…D-124). Idea guida: **un solo motore per brano** (`EnrichmentService`) che sa cercare ogni parte (metadati, testo, curiosità, crediti e dettagli) solo se accesa e mancante; il download, il comando «Arricchisci tutta la libreria» e il completamento in background lo chiamano tutti allo stesso modo e cambiano solo il ritmo. Dalla 69b il «motore per brano» è `EnrichEngine` (gather/commit a parti) guidato da `EnrichRunner`; `EnrichmentService` resta per `propose`/`apply` (anteprima e secondo parere). Crediti, dettagli e stato per parte stanno in **tabelle accanto a `tracks`**, così le liste e la ricerca non li leggono e le loro scritture non rinfrescano le viste della libreria.

### Componenti
| Componente | Nuovo / cambia | Responsabilità | File |
|---|---|---|---|
| `DeezerGwClient` | nuovo | Sessione anonima (`deezer.getUserData` → `checkForm` + cookie `sid`), poi `deezer.pageTrack(SNG_ID)` → `SNG_CONTRIBUTORS`, `COPYRIGHT`, `PHYSICAL_RELEASE_DATE`. Token scaduto → una nuova sessione, una volta (R-38). Interruttore a 3 errori di fila → pausa di 24 h salvata in `shared_preferences` (sopravvive al riavvio), una riga nel Registro (R-41). Usa un suo `Dio` con POST (come `InnerTubeClient`): `WebClient` ha solo GET | `lib/services/online/deezer_gw_client.dart` |
| `DeezerClient` | cambia poco | Dettagli pubblici (R-37): `rank`, `explicit_lyrics`, `bpm` dal brano; `label`, `fans`, `record_type`, `release_date` dall'album (già letto da `_deezerLookup`). Il BPM non c'è nei risultati di `/search`: serve `/track/{id}` quando l'id arriva dalla ricerca a testo (da verificare sulle fixture) | `deezer_client.dart`, `deezer_models.dart` |
| `MusicBrainzClient` | cambia | `recordingCredits(mbid)` = una chiamata `/recording/{mbid}?inc=artist-rels+work-rels+work-level-rels` (R-39). L'MBID viene da `CuriosityFinder._identify` (già cercato per le curiosità) o da `recordingsByIsrc`; nessuna ricerca in più. Il distacco di 1,1 s e il nuovo tentativo su 503 ci sono già: l'istanza resta una sola (`musicBrainzClientProvider`) per curiosità e crediti | `musicbrainz_client.dart` |
| `TrackCredit` + `mergeCredits` | nuovo | Modello `(name, nameKey, role, source)`; parser Deezer e MusicBrainz; unione pura senza doppioni, Deezer prima, chiave `creditNameKey(nome)+ruolo` (R-40). Test su fixture reali in `test/fixtures/deezer`, `test/fixtures/musicbrainz` | `lib/services/online/credits.dart` |
| Tabella dei ruoli | nuovo | Ruolo normalizzato → gruppo (Interpreti e strumenti / Autori / Produzione e tecnici / Altro) + getter ARB `creditRole…` nelle 6 lingue; sconosciuto = testo grezzo con `_` → spazio (R-43) | `lib/services/online/credit_roles.dart`, `lib/l10n/app_*.arb` |
| Catena del testo | nuovo | `LyricsChain.find`: LRCLIB → `NeteaseLyricsClient` (sincronizzato; accettato solo con titolo e artista uguali dopo `cleanSearchQuery` e durata ±3 s) → `LyricsOvhClient` (semplice). Timeout 8 s ciascuno (RNF-06). Endpoint NetEase da verificare con fixture | `lib/services/online/lyrics_chain.dart`, `netease_lyrics_client.dart`, `lyrics_ovh_client.dart` |
| `EnrichmentService` | cambia | `propose` usa `LyricsChain` al posto di `lrclib` e, con «Crediti e dettagli» acceso, cerca id Deezer (ISRC → testo con `pickDeezerTrack`) **anche con «Metadati da Deezer» spento**, senza scrivere metadati (R-36). `apply` scrive anche crediti, dettagli e lo stato per parte. Nuovo `completeOne(trackId, parts, {force})`: la funzione che usano download e background. Dalla 69b `enrichMany`, `needsEnrichment` e `BatchProgress` non esistono più: il lavoro manuale passa dal runner e `completeOne` vive in `EnrichEngine` | `enrichment_service.dart` |
| `CuriosityService` | nuovo (spostato) | La logica di `CuriosityNotifier.fetch` (finder + `setCuriosities` + `ArtistInfos.save`) esce dal provider in un servizio, così il background la usa senza UI; il notifier la chiama | `lib/services/online/curiosity_service.dart`, `lib/providers/curiosity_provider.dart` |
| Stato per parte | nuovo | «Cercato, niente» con la data per metadati, testo, sincronia, curiosità, crediti; `isDue(part, now)` = vuota e (mai cercata o «niente» da > 30 giorni) (R-54, R-55). Funzione pura testata con orologio finto | `lib/services/online/enrich_parts.dart` |
| `EnrichCompleter` | nuovo | Il giro in background (R-51…R-53), dalla 69b un involucro sottile di `EnrichRunner` con `MarkCursor` (segnalibro `enrichMark`): prende gli id a pezzi di 20 con la regola unica `dueSql`, un brano alla volta, scritture a blocchi di 10 brani. `AskMode.due` aspetta l'utente a riposo; `retryNone` (comando manuale) non aspetta e riprova i «niente»; `force` è per la card dei crediti. Mentre aspetta l'attività dice «Completamento: in attesa». Pausa/Riprendi (un `CancelToken` ferma il brano in corso), riga di fine giro nel Registro | `lib/services/online/enrich_completer.dart`, `lib/providers/enrich_completer_providers.dart` |
| `UserActivity` | nuovo | Segnale «l'utente sta facendo qualcosa»: oggi non esiste. Un `NotificationListener<ScrollNotification>` alla radice della shell (`lib/ui/shell/`), il testo delle ricerche (campo della ricerca locale e online) e i download/import/trasferimenti in corso (`activityProvider.running`) aggiornano `lastActivityAt`; il completer lavora solo se sono passati 5 s e niente è in corso (R-52) | `lib/providers/user_activity_provider.dart` |
| Download | cambia | `downloadEnricherProvider` (`QuietEnricher`) chiama `completeOne` con tutte le parti accese (R-50); `enabled` include «Curiosità automatiche» e «Crediti e dettagli»; il tag del file resta dopo, come oggi | `lib/providers/online_providers.dart` |
| Impostazioni | cambia | `AppSettings`: `creditsDetails` (R-35), `autoCuriosities` (R-50), entrambi `false`; tile «Arricchisci tutta la libreria» | `lib/data/settings/settings_store.dart`, `lib/ui/screens/settings/settings_pages.dart` |
| Card e schermate | nuovo / cambia | `CreditsCard` accanto a `InfoCard` (dettagli in righe, gruppi, «Mostra tutto» oltre 8, «Aggiorna»), nomi con `ArtistLinkResolver` (R-42, R-44, R-45); la stessa sezione in `JamTrackInfoScreen` e `EnrichPreviewDialog` (R-46); «Compare come» nella pagina artista (R-47); gruppo «Nei crediti» nella ricerca (R-48) | `lib/ui/screens/now_playing/credits_card.dart`, `jam_track_info_screen.dart`, `enrich_preview_dialog.dart`, `lib/ui/screens/library/artist_screen.dart`, ricerca locale |
| Registro | cambia | `ActivityLogNotifier` scrive in una tabella invece che in una lista da 500; all'avvio cancella le righe di oltre 30 giorni; «Svuota» = `DELETE`. Oggi solo download, episodi, trasferimenti, import e secondo parere finiscono nel Registro: scan, enrich, cleanup e releases stanno solo in `running`, quindi serve una regola «c'era, non c'è più → riga». `ActivityKind` guadagna `podcastRefresh`, `radio`, `enrichBackground` (R-60) | `lib/providers/activity_log_providers.dart`, `activity_providers.dart`, `lib/ui/screens/activity/*` |
| Selettore copertina | nuovo | Foglio unico per brano, album e playlist: file (il codice di `_pickCover` della playlist si sposta qui), proposte online Deezer/iTunes con misura (cercate solo all'apertura, anche con Deezer spento), copertina di un altro brano/album (R-63, R-64). Salva con `CoverStore.saveFromBytes` e una chiave nuova per ogni scelta (`manual:…:<µs>`, come le playlist) | `lib/ui/widgets/cover_picker_sheet.dart`, `lib/providers/cover_ops.dart` |
| Protezione copertina | cambia | Ogni scrittore di copertine salta le righe con copertina a mano: `TrackRepository.setCoverForAlbum` (filtro `cover_source = 0`), upsert del `LibraryScanner` (righe 191–231), `EnrichmentService._applyCover`, `received_meta.dart`, `StreamPromoter`. `DownloadTagger.coverOf` non scrive mai una copertina a mano nel file (R-66) | file elencati |
| Memoria | cambia | `MemoryQueries.enrichmentBytes()`: `SUM(length(...))` di testi, curiosità, `artist_infos.body`, crediti e dettagli; riga nella pagina Memoria (R-58) | `lib/data/repositories/memory_queries.dart`, `lib/ui/screens/memory/memory_screen.dart` |
| Backup e invio | cambia | `TrackUserData` e `TrackMeta` con `credits`, `details`, `coverSource` facoltativi; merge in `backup_merge.dart` (R-57, R-67) | `lib/services/backup/user_data.dart`, `lib/data/repositories/backup_merge.dart`, `lib/services/share/track_meta.dart` |

### Flussi
**(a) Download → arricchimento completo.** Fine download → `afterDownload` → `QuietEnricher.add(id)` → `completeOne(id, parti accese)`: metadati (Deezer/iTunes come oggi) e testo (`LyricsChain`) in parallelo; con «Crediti e dettagli» acceso: id Deezer (dal match dei metadati o da una ricerca propria) → `/track` + `/album` (dettagli) → `DeezerGwClient.pageTrack` (crediti, se non in pausa) e, con l'MBID, `MusicBrainzClient.recordingCredits` → `mergeCredits`; con «Curiosità automatiche»: `CuriosityService` (brano + artista). Una transazione: colonne vuote di `tracks`, `track_credits`, `track_enrich` (dettagli + «niente» per parte). Poi `DownloadTagger` come oggi. Su una riga ombra (`kind = 2`) è uguale: le tabelle sono per `trackId` e restano con «Scarica» (R-49).
**(b) Completamento in background.** All'avvio (dopo la scansione) e a ogni cambio degli interruttori: `EnrichRunner`/`EnrichCompleter` → query «brani `kind IN (0,2)` con almeno una parte accesa e dovuta» (SQL su `tracks` LEFT JOIN `track_enrich`, solo colonne leggere) → per ogni brano: attende `UserActivity` libero 5 s → `completeOne` → ogni 10 brani scrive il blocco in una transazione e aggiorna la voce `enrich` del centro Attività (completi / totale) → fine o pausa: riga del Registro con i conteggi e il dettaglio per parte (R-61). Errore 429 di una fonte = quella fonte salta il brano (cooldown di oggi), le altre vanno avanti; nessuna parte si segna «niente» per un errore di rete.
**(c) Copertina a mano su un album.** Pagina album → «Cambia copertina» → selettore (all'apertura parte la ricerca Deezer/iTunes) → scelta → `CoverStore.saveFromBytes('manual:album:<albumKey>:<µs>')` → `UPDATE tracks SET cover_key = :k, cover_source = 1 WHERE album_key = :a AND cover_source <> 2` (R-65) → la vecchia copertina a mano si cancella, quella originale `sha1(albumKey)` resta su disco. «Ripristina copertina originale» → `cover_source = 0`, `cover_key = sha1(albumKey)` se il file esiste, altrimenti il `_resolveCover` della scansione. Scansione e arricchimento non toccano le righe con `cover_source > 0` (R-66).

### Dati
Schema **v15** (`kSchemaVersion = 15`, passo `if (from < 15)` in `app_database.dart`).

| Cosa | Dove | Note |
|---|---|---|
| Crediti | tabella nuova `track_credits(track_id → tracks ON DELETE CASCADE, name, name_key, role, source)`, PK `(track_id, name_key, role)`, indice su `name_key` | «Compare come» (R-47) e «Nei crediti» (R-48) diventano una query su `name_key`; nessun effetto sulle query delle liste; ≈ 15 righe per brano |
| Dettagli + id + stato per parte | tabella nuova `track_enrich(track_id PK → tracks CASCADE, details TEXT JSON, deezer_id, mbid, meta_none_at, lyrics_none_at, synced_none_at, curio_none_at, credits_none_at, lyrics_by_user BOOL)` | i dettagli sono ≈ 300 byte e servono solo nella card: JSON va bene. `*_none_at` = data dell'ultimo «cercato, niente» (null = mai cercato o trovato: «trovato» si legge dal dato stesso) |
| Copertina a mano | colonna nuova `tracks.cover_source INT DEFAULT 0` (0 = file/arricchimento, 1 = a mano per l'album, 2 = a mano per il brano) | la copertina d'album delle query (`MIN(cover_key)` in `library_queries.dart` righe 79 e 149) passa a preferire `cover_source = 1` e ignorare le righe `= 2`. Un brano nuovo che entra in un album con `cover_source = 1` ne eredita la chiave (scansione) |
| Registro | tabella nuova `activity_log(id, at, kind, name, done, total, failed, detail TEXT JSON)`, indice su `at` | `detail` = gli id dei brani per parte del giro di arricchimento (R-61) |
| Curiosità, testo, bio | come oggi (`tracks.curiosities`, `lyrics_*`, `artist_infos`) | restano colonne pesanti fuori dalle liste (`heavyTrackColumns`) |

- **`enrichStatus` resta** (0/1/2) e dalla 69b si scrive in un punto solo, `EnrichWriter.writeStatus` via `statusAfter`; il 2 «niente trovato» solo se i metadati sono stati chiesti e non è venuto niente. Lo usano «Da revisionare» e i conteggi. Il completamento non lo legge: decide da `track_enrich`. Dopo la scansione non c'è più `_autoEnrich` (D-288): parte solo il completer. La migrazione mette, per le righe con `enrich_status = 2`, `meta_none_at` e `lyrics_none_at` (se il testo manca) alla data della migrazione: si riprovano fra 30 giorni (D-103) invece che mai.
- **Testo «scritto o scelto dall'utente»**: oggi nessuna colonna lo distingue. Da v15 l'editor del testo e la scelta di un risultato mettono `lyrics_by_user = 1`; la migrazione lo mette alle righe `user_edited = 1` con testo. Solo un testo non dell'utente si può completare con la versione sincronizzata (R-55, R-56).
- **Righe esistenti**: nessuna riga in `track_enrich`/`track_credits` = mai cercato; le tabelle si riempiono man mano. Nessun dato esistente cambia.
- **Unione della riga ombra e doppioni**: `TrackRepository.mergeStreamRow` e `DuplicateRepository.merge` oggi spostano testo e curiosità e poi cancellano la riga: devono spostare anche `track_credits` e `track_enrich` **prima** della cancellazione (altrimenti il CASCADE li perde).
- **Backup**: il ripristino completo copia `codecore.sqlite` (le tabelle nuove ci sono; un `.sqlite` v14 si aggiorna con `onUpgrade` all'apertura, da verificare che `_checkStagedDatabase` lo accetti) e la cartella delle copertine (anche quelle a mano, R-67). `user_data.json` (unione) guadagna per brano `credits`, `details`, `coverSource`, `coverKey` facoltativi: un backup vecchio senza questi campi si legge come oggi.
- **`TrackMeta`** (invio e Jam): campi nuovi facoltativi `credits` (max 200) e `details`; chi non li conosce li ignora (`fromJson` legge per chiave).

### Invarianti
1. Si scrive solo una parte vuota; `userEdited` protegge titolo/artista/album come oggi, `lyrics_by_user` il testo, `cover_source > 0` la copertina. Nessun automatismo li cambia.
2. Interruttore spento = nessuna richiesta per quella parte: nessun client di crediti senza `creditsDetails`, nessun Wikipedia senza `autoCuriosities` (o «Arricchisci» a mano), nessun metadato scritto senza `autoEnrich`/«Metadati da Deezer». Le proposte di copertina partono solo dall'apertura del selettore.
3. Un errore di rete o un 429 non segna mai «cercato, niente»: solo una risposta valida e vuota.
4. Rete e DB del completamento fuori dal thread UI (servizi async, transazioni a blocchi); nessuna scrittura per brano su `tracks` più spesso di un blocco ogni 10 brani.
5. Le query delle liste non leggono `track_credits`, `track_enrich`, né le colonne di `heavyTrackColumns`; le liste restano su `kind = 0`.
6. Limiti delle fonti: MusicBrainz una sola istanza, ≥ 1,1 s fra richieste, attesa su 503; Deezer con `cooldown` e `isResting` di oggi; API interna di Deezer in pausa 24 h dopo 3 errori di fila; NetEase e lyrics.ovh con timeout 8 s; nessuna chiave nel codice.
7. Nessun dato di arricchimento né copertina a mano si scrive nel file musicale.
8. Il completamento gira solo ad app aperta e non parte mai mentre l'utente scorre, cerca o scarica (salvo il comando manuale «Arricchisci tutta la libreria», che non aspetta).

### Dove va il codice nuovo
- `lib/services/online/`: `deezer_gw_client.dart`, `credits.dart`, `credit_roles.dart`, `lyrics_chain.dart`, `netease_lyrics_client.dart`, `lyrics_ovh_client.dart`, `curiosity_service.dart`, `enrich_parts.dart`, `enrich_completer.dart`.
- `lib/data/db/tables.dart` (`TrackCredits`, `TrackEnrich`, `ActivityLogRows`, `Tracks.coverSource`), `app_database.dart` (v15); `lib/data/repositories/credits_repository.dart`, `activity_log_repository.dart`.
- `lib/providers/`: `enrich_completer_providers.dart`, `user_activity_provider.dart`, `cover_ops.dart`.
- `lib/ui/screens/now_playing/credits_card.dart`, `lib/ui/widgets/credits_section.dart` (riusata da Jam e anteprima), `lib/ui/widgets/cover_picker_sheet.dart`, `lib/ui/screens/settings/enrich_complete_tile.dart`.
- Test: `test/services/online/` (parser con fixture reali, `mergeCredits`, ruoli, `enrich_parts` e `EnrichCompleter` con orologio finto e client finti, catena del testo), `test/data/` (migrazione 14 → 15, query «Compare come»/«Nei crediti», dimensioni), andata e ritorno di `user_data`/`TrackMeta`.

## Rischi
| ID | Rischio | Prob. | Impatto | Mitigazione | Segnale d'allarme |
|---|---|---|---|---|---|
| K-AR-01 | Regressione dell'arricchimento di oggi: `LyricsChain` al posto di `lrclib`, il nuovo `completeOne` e le pause cambiano «Arricchisci», l'anteprima e il download | M | A | `apply` mantiene firma e comportamento (`enrichMany`/`needsEnrichment` tolti dalla 69b, il lavoro manuale passa dal runner); la catena parte da LRCLIB come oggi; test esistenti di `enrichment_service_test` e `cover_for_album_test` verdi a ogni fase | un test esistente da cambiare; brano scaricato senza testo che prima l'aveva |
| K-AR-02 | Backup e ripristino: `.sqlite` v14 rifiutato o non migrato, crediti persi nell'unione, CASCADE che cancella crediti in `mergeStreamRow`/doppioni | M | A | test di migrazione 14 → 15 su un DB reale; andata e ritorno di `user_data` con e senza campi nuovi; spostamento esplicito delle righe prima della cancellazione | errore al ripristino; brano con crediti che li perde dopo «Scarica» o la pulizia doppioni |
| K-AR-03 | Jam e invio: `TrackMeta` più grande o con un campo che rompe un dispositivo con la versione vecchia | B | M | campi facoltativi con limite; test con un `TrackMeta` vecchio e uno nuovo nei due versi | info brano vuota nella Jam mista |
| K-AR-04 | Fluidità delle liste: ogni scrittura su `tracks` rifà le query in ascolto e ricostruisce `SearchIndex` (2196 brani) nel thread UI; il completamento scrive di continuo | A | A | crediti e stato in tabelle separate (non toccano gli stream di `tracks`); scritture su `tracks` a blocchi di 10; `perf_device.py` sul Mi A3 col completamento attivo (RNF-05) | frame oltre soglia di «Finale»; scatto ogni pochi secondi scorrendo |
| K-AR-05 | Copertine delle playlist e degli album: il selettore unico sostituisce `_pickCover`; il cambio di `MIN(cover_key)` sposta copertine d'album; uno scrittore dimenticato sovrascrive una copertina a mano | M | M | test esistenti delle copertine playlist verdi; test «scansione + arricchimento + ricezione dopo il cambio → stessa `coverKey`»; `grep` di `setCoverForAlbum`/`cover_key` a fine fase | copertina a mano tornata quella vecchia dopo una scansione |
| K-AR-06 | API interna di Deezer (gw-light) cambia o blocca le sessioni anonime | A | M | dietro `DeezerGwClient`; pausa 24 h dopo 3 errori, MusicBrainz e il resto continuano; fixture reali per accorgersi del cambio di formato | righe «crediti Deezer in pausa» ripetute nel Registro |
| K-AR-07 | MusicBrainz «busy» (503) o lento: il giro su 2196 brani dura ore e rallenta anche le curiosità | A | B | una sola istanza col distacco di 1,1 s; una chiamata per brano riusando l'MBID; un 503 non segna «niente» | molti 503 nel log; giro fermo sulla stessa parte |
| K-AR-08 | NetEase dà il testo di un altro brano (cover, remix, live) | M | M | accettato solo con titolo e artista uguali dopo la pulizia e durata ±3 s; test con risultati finti sbagliati; «Aggiorna» per rifare | testo sincronizzato fuori tempo o di un'altra canzone |
| K-AR-09 | DB che cresce oltre la stima o batteria/rete consumate dal giro in background (anche su dati mobili, D-102) | M | M | query di R-58 misurata a fine fase contro RNF-04; un brano alla volta con pause; niente lavoro mentre si scorre, cerca o scarica; Pausa nel centro Attività | «Arricchimento» > 30 MB in Memoria; telefono caldo con l'app ferma in riproduzione |

Rischi che preoccupano di più l'utente (2026-10-25): K-AR-01, K-AR-02, K-AR-04, K-AR-06.

**Controlli a ogni fase** (regressioni prima): test esistenti di arricchimento, download, backup, Jam e copertine playlist verdi (K-AR-01…05); `perf_device.py` sul Mi A3 a fine fase del completamento (K-AR-04); riga «Arricchimento» in Memoria dopo un giro completo sul Motorola (K-AR-09).
