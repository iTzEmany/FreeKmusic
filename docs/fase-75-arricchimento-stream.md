# Fase 75 — Testo, curiosità e crediti dei brani in streaming

**Obiettivo:** i brani in streaming (risultati della ricerca online, suggeriti di Shuffle+, Radio) mostrano testo, curiosità e crediti come i brani della libreria, caricati appena l'ascolto del brano è iniziato e il file è in cache, così lo streaming non rallenta (D-351, che sostituisce i 5 s di D-345/D-346).

**Prerequisiti:** fase 74 chiusa. Analisi, scelte, arrivo e rete in `docs/refactor/arricchimento-stream/analisi.md` (rilievi F-01…F-06). Decisioni D-63, D-75, D-77, D-106, D-161, D-344 … D-350. Intoccabili (D-349): schema del database (nessuna migrazione), righe ombra e «Scarica» (D-77, D-106), Jam (D-71), avvio dello streaming all'indirizzo (R-71). Nessun pacchetto nuovo. Aree a rischio: `lib/services/stream/stream_preparer.dart`, `lib/providers/player_providers.dart` (`liveCurrentTrackProvider`).

**Regola della fase:** ogni comportamento nuovo prima si fissa con un test che fallisce sul `master` attuale, poi si scrive il codice.

**Comando mirato:** `flutter test test/services/stream test/services/audio/online_playback_test.dart test/ui/now_playing_loading_test.dart test/ui/now_playing_test.dart test/ui/info_card_test.dart test/ui/lyrics_card_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart` (più i file di test nuovi della fase).

## Task

### 75.1 — Rete di sicurezza
Test nuovi, rossi sul `master` di oggi (analisi, «Rete»):
- widget: brano in streaming (id negativo) la cui riga ombra ha testo e curiosità → nella schermata del brano ci sono le schede testo, curiosità e crediti con i dati della riga, e non c'è la «Proposta di correzione» (D-348);
- le schede di crediti e curiosità leggono l'id della riga ombra, non l'id negativo della voce (F-02);
- unità: l'arricchimento non parte all'inizio del download né per un brano solo pre-caricato; parte appena il brano corrente in streaming ha la sua riga ombra, anche in pausa (D-351); un brano in cache senza dati viene arricchito, uno già arricchito no; uno rifiutato (`limited`) riprova al prossimo ascolto (D-350). Orologio finto, niente attese vere.

**Fatto quando:** i test nuovi esistono, falliscono per il motivo atteso sul `master` e i test esistenti del comando mirato sono verdi.

### 75.2 — Schede visibili per lo streaming (F-01, F-02, F-05, F-06)
- `now_playing_screen.dart:161`: il filtro `if (!online)` resta solo per `ProposalCard`; `LyricsCard`, `InfoCard`, `CreditsCard` ci sono anche per lo streaming.
- Le schede ricevono l'id della riga ombra: oggi `liveCurrentTrackProvider` (`player_providers.dart:507`) mostra la riga con l'id negativo della voce (che serve a menu e copertina, D-71: non cambiarlo). Dare alle schede l'id della riga (per esempio dalla voce, `entry.trackId`) senza toccare l'id della traccia mostrata.
- Finché la riga ombra non c'è: segnaposto «in arrivo» a altezza fissa (D-347, D-161), niente «Nessun testo» né «Cerca testo». Testo nuovo negli ARB it/en/de/es.
- Pannello «Info» del desktop (`side_panel.dart:55`) come il telefono (D-350).
- Controllare la schermata del testo intero e «Cerca testo» con un brano in streaming: devono leggere e salvare sulla riga ombra; se non lo fanno, correggere qui.

**Fatto quando:** i test widget di 75.1 sono verdi; un brano della libreria mostra le schede di prima (test esistenti verdi).

### 75.3 — Arricchimento all'avvio dell'ascolto (F-03, F-04)
- Togliere il lancio di `enrich` dall'inizio di `StreamPreparer._run` (`stream_preparer.dart:422`).
- Innesco nuovo legato al brano corrente: se è in streaming e la sua riga ombra c'è, si chiama la stessa funzione `enrich` di oggi (`stream_providers.dart:63`) con la riga già pronta; se la riga arriva dopo, parte appena arriva, anche a brano fermo (D-351; in origine 5 s, D-345/D-346).
- Vale anche per un file già in cache (F-04). Si salta un brano già arricchito (leggere come lo segna oggi il motore: `TrackEnrich`, `dueTrackIds`); `limited` non lo segna, quindi riprova al prossimo ascolto (D-350).
- Un solo arricchimento per brano alla volta (niente doppioni se lo riascolti mentre il primo è in corso).

**Fatto quando:** i test di unità di 75.1 sono verdi; `stream_preparer_test.dart` aggiornato dove contava sull'arricchimento all'inizio del download; nel log nessuna riga d'arricchimento prima che il file sia in cache né per i pre-caricati.

### 75.4 — Controlli di fase
`flutter analyze` pulito; comando mirato verde; code-review high (aree a rischio); scheggia; review Opus. Prova dal vivo su Linux e sul Mi A3:
- un brano cercato online e un suggerito di Shuffle+ → testo, curiosità e crediti compaiono appena il file è in cache più il tempo delle fonti, prima c'è il segnaposto; anche col brano messo subito in pausa;
- un pre-caricato della coda mai ascoltato → nessun arricchimento nel log;
- lo streaming parte quando partiva prima (riga `stream timing`, `url=` non peggiore a parità di rete);
- un brano della libreria e la Jam come prima.

Esiti in questo documento, spunte in `PROGRESS.md`, handoff aggiornato, pulizia del disco.

**Fatto quando:** tutti i controlli sopra sono fatti e scritti qui.

## Esiti (2026-11-03, PR #95)
- **D-351** (scelta dell'utente durante il lavoro): niente attesa di 5 s, l'arricchimento parte appena il brano corrente ha la riga ombra (file in cache), anche in pausa. `StreamEnrichTrigger` + `streamEnrichTriggerProvider`; `StreamPreparer` non arricchisce più.
- `flutter analyze` pulito; comando mirato (più i test nuovi, `jam_self_start`, `shuffle_plus`, `stream_cache_tile`): 242 test verdi prima della correzione dal vivo, poi 167 sui file toccati.
- Review Opus delle aree a rischio: 4 rilievi corretti (riga ombra con id positivo; voce che resta sulla riga cancellata dopo «Scarica»; righe già provate dal motore saltate; posizione vecchia, poi superata da D-351). Scheggia di passo: 2 bug bassi del trigger corretti, 6 mutanti coperti da test.
- **Prova dal vivo sul Mi A3** (APK debug):
  - 1° giro: **KO**. Dopo un brano in cache, il tap su un brano nuovo arricchiva di nuovo la riga del precedente (letta da un provider derivato non ancora ricalcolato dentro un `ref.listen`) e mai quella nuova. Corretto leggendo la riga dalla voce della coda, con test di regressione in `online_playback_test.dart`.
  - 2° giro: OK. Primo brano della sessione: `result=ok` e poi `stream enrich row=224` dopo 0,3 s, testo e curiosità dopo ~20 s. Brano A in cache → brano B nuovo: nessun enrich di A, `stream enrich row=225` subito dopo `result=ok` di B. B in pausa subito: arricchito lo stesso.
  - Avvio dello streaming: `url=4402` ms contro 5,8–40 s nelle righe vecchie dello stesso telefono (una misura, Wi-Fi): non peggiore.
  - Brano della libreria: schede come prima, nessun `stream enrich`.
- **Da provare a mano**: un suggerito online di Shuffle+ in coda (nessun enrich finché non suona); il segnaposto «in arrivo» a vista; «Proposta di correzione» su un brano della libreria; Linux non provato dal vivo.
