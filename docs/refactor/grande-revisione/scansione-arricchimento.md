# Scansione — arricchimento manuale e automatico (22/11, sonnet)

**Sintesi**: ci sono due motori che scrivono gli stessi campi con regole diverse.
- `EnrichEngine` (gather e commit) fa l'automatico e il batch manuale: è giusto.
- Il vecchio `EnrichmentService` (propose e apply) fa l'anteprima, i brani in streaming e la seconda opinione. D-280 prevedeva di portarli sul motore unico e non è mai stato fatto.
- In più `TrackCorrections`: in tutto tre scrittori, nessun punto unico.

## Mappa
| Percorso | Avvio | Scrive | file:riga |
|---|---|---|---|
| Completer di sfondo | dopo uno scan, dopo 2 s di inattività, a ogni switch | solo campi vuoti, segni «niente», status | startup_providers.dart:35, enrich_completer.dart:92, enrich_engine.dart:136,397 |
| Batch manuale «Arricchisci»/«Riprova» | UI (`manualParts`, retryNone) | come sopra | online_providers.dart:333-376 |
| Brano scaricato | `downloadEnricherProvider` | come sopra, poi tag | online_providers.dart:442-454 |
| Riga stream (ascolto, Shuffle+, import) | `streamEnrichTriggerProvider`, `streamEnrichRowProvider` | `EnrichmentService.apply` con TUTTI i campi, title/artist/album compresi; status solo se ha scritto | stream_providers.dart:77-133 |
| Anteprima per brano | dialog | i campi scelti | enrich_preview_dialog.dart:51,130 |
| Seconda opinione | apertura della Revisione | `enrichment.apply` | second_opinion.dart:75,213 |
| Riconoscimento | dentro `_gather` | `rec` più la correzione automatica se sicura | enrich_engine.dart:210-240 |
| Proposte: accetta | UI | `TrackCorrections.apply(byUser)` | track_corrections.dart:42,165 |
| Paesi degli artisti | dopo uno scan, a ogni cambio di rete, switch o Jam | tabella dei paesi | artist_country_providers.dart:28 |

## Rilievi (in ordine di priorità)
- **F1** · MusicBrainz senza coda né cooldown (musicbrainz_client.dart:96-128). Due chiamanti contemporanei partono insieme; dopo un 503 c'è una sola riprova a 2 s, poi al brano successivo si riparte subito. Effetto: 86 risposte 503. Fix: una coda unica nel client (come `RateLimiter.wait`, http_client.dart:158) e un cooldown di 1, 5 e poi 15 minuti dopo ogni 503. S · A
- **F2** · `MusicBrainzUnavailable` non viene contato come `limited` (credits_enricher.dart:63-80, enrich_runner.dart:395-402), quindi il runner continua a chiamare MB. Il finder dei paesi riparte a ogni trigger (37 volte). Fix: mapparlo su `limited`; il finder legge il cooldown. S · A
- **F3** · Le righe stream non vengono mai marcate se non si trova nulla (stream_providers.dart:79,87-100): si rifanno a ogni ascolto (`row=2484` ×6). Il completer tratta anche le righe stream: due stack sulla stessa riga. Fix: lo stream passa da `engine.completeOne(row.id, autoParts)`. M · A
- **F4** · «track 0» nel log: è il `syntheticTrack` con id 0 (synthetic_track.dart:12-14). Non scrive su una riga 0, ma `id <= 0` fa richiedere i crediti MB a ogni ascolto (enrichment_service.dart:100). Si risolve con F3.
- **F5** · Crediti MB a ogni ascolto stream (2 richieste): si risolve con F3.
- **F6** · Circa 8-10 richieste MB per brano. `recordingsByIsrc` viene chiamato fino a 4 volte (recognizer :258, crediti :158, curiosità :163, genreFor); Deezer due volte in `propose` (credits_enricher.dart:108). Nessuna cache. Fix: cache in memoria (anche negativa) con scadenza, riuso del risultato ISRC, intervallo di 1,5 s in background. M · M
- **F7** · Correzioni su righe stream: `_fileWanted` (track_corrections.dart:218-225) non guarda `kind`, quindi `fileIds` legge `stream:` (eccezione Rust) e `_toFile` risponde `unsupported`. Il Registro mostra allora «Correzione salvata, file non aggiornato». Fix: 1 riga `if (t.kind == kStreamKind) return false;`. S · B
- **F8** · File non scrivibili (scoped storage): `fileIds` viene letto prima di `_fileBlock`, e la correzione automatica finisce comunque nel Registro. Fix: `_fileBlock` dentro `_prepare`; per le correzioni automatiche solo il log. S · B
- **F9** · Lo stream scrive title/artist/album senza anteprima (stream_providers.dart:98). Fix: in automatico solo i campi vuoti.
- **F10** · Il completer ignora la rete a consumo e la Jam (al contrario di `artistCountryAllowed`, artist_country_providers.dart:40-44). S · B
- **F11** · `SecondOpinion._mbRestUntil` è un riposo locale che non vede `MusicBrainzUnavailable`: si risolve con F1.
- Lo stream ignora gli switch `autoEnrich`/`autoLyrics`/`autoCuriosities`; `propose` non usa il limiter condiviso né il riconoscimento.
- User-Agent corretto (con contatto). Le 503 restano possibili su una rete mobile condivisa (limite per IP).

## Proposta di arrivo
- **Un solo motore**: l'anteprima resta di sola lettura ma usa lo stesso `EnrichGather`; stream, Shuffle+ e import passano da `completeOne`.
- **Automatico silenzioso**: solo campi vuoti, solo le parti accese in `autoParts`, ritmo lento, solo con app ferma, rete non a consumo e senza Jam.
- **Manuale su richiesta**: tutte le parti, retryNone, anteprima per il singolo brano, sempre con il limitatore; «Accetta» scrive come decisione dell'utente.
- **Client MB**: coda, cache, cooldown, 503 → `limited`.
- **Da togliere**: `id <= 0`, `EnrichField.values` nello stream, `_mbRestUntil`, ISRC ripetuti.
- **Ordine**: F7+F8 → F1+F2 → F3 (comprende F4, F5, F9) → F6 → F10.
