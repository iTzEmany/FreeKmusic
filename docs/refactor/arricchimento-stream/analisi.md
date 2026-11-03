# Refactor «arricchimento-stream» — analisi

## Perimetro
Brani in streaming (risultati della ricerca online, suggeriti di Shuffle+, Radio, D-75): testo, curiosità e crediti nella schermata del brano (telefono) e nel pannello laterale (desktop). Tipo: struttura, con un cambio di comportamento chiesto dall'utente (le schede compaiono anche per lo streaming; l'arricchimento parte qualche secondo dopo l'avvio).

Segnalazione dell'utente (3/11): «quando ascolto in streaming una canzone cercata online, o una online fra i suggeriti di Shuffle+, non ci sono testo, curiosità e crediti. Li vorrei, caricati qualche secondo dopo per non rallentare lo streaming».

Misure di partenza: nessuna misura dal vivo in questo giro; la diagnosi è sul codice (righe sotto). La riga di log `stream timing key=… url=… downloaded=…` (`stream_preparer.dart:525`) dà già i tempi d'avvio da confrontare a fine lavoro.

## Flusso di oggi
1. Play di un risultato online → voce della coda con id **negativo** (`online_entries.dart:10`).
2. `StreamPreparer._run` (`stream_preparer.dart:421`) lancia **subito**, insieme al download, `enrich(result, rowId)` (`stream_providers.dart:63`): `propose` interroga le fonti (testo, Wikipedia, Deezer/MusicBrainz) e, quando la riga ombra (`kind = 2`, D-77) esiste, scrive testo, curiosità e crediti su quella riga.
3. `liveCurrentTrackProvider` (`player_providers.dart:481`) mostra la riga ombra appena c'è, ma con l'id negativo della voce (`copyWith(id: id)`, riga 507).
4. La schermata del brano nasconde le schede se il brano è `online` (`now_playing_screen.dart:161`), e un brano con id negativo o `kind = 2` è sempre `online` (`track_kind.dart:11`).

## Rilievi (in ordine di priorità)

F-01 · UI · Le schede sono nascoste per ogni brano in streaming · `lib/ui/screens/now_playing/now_playing_screen.dart:161` · `if (!online) ...[ LyricsCard, ProposalCard, InfoCard, CreditsCard ]` · testo, curiosità e crediti già salvati sulla riga ombra non si vedono mai · impatto A · rischio B · costo S · mostrare le schede anche per lo streaming. La condizione viene dalla fase 31 (`d91b331`, 22/10), quando i suggeriti online non avevano una riga nel database; con le righe ombra (D-77, 25/10) è rimasta indietro.

F-02 · struttura · Le schede leggerebbero l'id sbagliato · `credits_card.dart:56` (`trackCreditsProvider(widget.track.id)`), `now_playing_cards.dart:196` (`curiosityProvider(widget.track.id)`), `player_providers.dart:507` · il brano mostrato ha l'id negativo della voce, non quello della riga ombra · togliendo solo F-01, crediti e curiosità «a richiesta» cercherebbero e salverebbero sull'id negativo: vuoti, o scritti nel posto sbagliato · impatto A · rischio M · costo S · le schede ricevono l'id della riga ombra (o niente finché la riga non c'è).

F-03 · velocità · L'arricchimento parte insieme al download, anche per i brani solo pre-caricati · `stream_preparer.dart:422` · `if (enrich != null && !j.enriching) { … unawaited(enrich!(j.result, j.rowId.future)) }` all'inizio di `_run` · le richieste a testo/Wikipedia/Deezer/MusicBrainz competono con l'avvio dello streaming; ogni brano pre-caricato della coda (fino alla finestra della coda) fa partire il suo arricchimento anche se non verrà mai ascoltato · impatto M · rischio M · costo S · far partire l'arricchimento qualche secondo dopo che il brano è iniziato davvero (o dopo che il file è in cache), non all'inizio del download.

F-04 · comportamento · Un brano già in cache non viene più arricchito · `stream_preparer.dart:246` (`_cached`) · se il file c'è, `_run` non gira e `enrich` non parte; se il primo tentativo era stato rifiutato (`proposal.limited`, `stream_providers.dart:65`: «try again later») o l'app era stata chiusa, il «più tardi» non arriva mai · impatto M · rischio B · costo S · lo stesso innesco ritardato di F-03 vale anche per i brani già in cache, e salta i brani già arricchiti.

F-05 · UI · Pannello «Info» del desktop con lo stesso id negativo · `lib/ui/shell/side_panel.dart:55` (`InfoCard(track: track)`) · qui non c'è il filtro di F-01, ma la curiosità a richiesta lavora sull'id negativo (F-02) · impatto M · rischio B · costo S · stesso rimedio di F-02.

F-06 · UI · Prima che la riga ombra esista non c'è niente da mostrare · `player_providers.dart:496` (traccia sintetica finché il download non finisce) · nei primi secondi le schede sarebbero vuote o «nessun testo» con il pulsante «Cerca testo», che non avrebbe dove salvare · impatto M · rischio B · costo S · finché la riga non c'è, schede in attesa (segnaposto) invece di «nessun testo».

## Sintesi per area
- **UI**: un filtro rimasto dalla fase 31 nasconde tutto (F-01); il resto della UI legge l'id della voce invece di quello della riga (F-02, F-05, F-06).
- **Struttura/velocità**: l'arricchimento dello streaming esiste e salva già sulla riga ombra (D-63, D-75, D-106), ma parte troppo presto e per troppi brani (F-03) e non riparte sui brani in cache (F-04).

## Test esistenti toccati
`test/services/audio/online_playback_test.dart:402` (la riga ombra arriva in `liveCurrentTrackProvider` dopo l'arricchimento), `test/services/stream/stream_preparer_test.dart`, `test/ui/info_card_test.dart`, `test/ui/now_playing_loading_test.dart`, `test/ui/lyrics_card_test.dart`. Nessuno controlla che le schede si vedano per un brano in streaming: F-01 è passato inosservato per questo.

## Da verificare nel giro 4
- La schermata del testo intero (`LyricsScreen`) e «Cerca testo» con un brano in streaming: su quale id scrivono.
- La Jam: un ospite che ascolta un brano online vede già testo e curiosità chiesti al proprietario (D-71); non va toccato.

## Scelte
- Si affrontano tutti i rilievi F-01…F-06 (D-344). Nessuno rimandato o scartato.
- Arricchimento ~5 s dopo l'avvio del brano che suona, annullato se lo salti prima (D-345, D-346); segnaposto «in arrivo» nelle schede (D-347); niente «Proposta di correzione» per lo streaming (D-348).
- Intoccabili (D-349): schema del database, righe ombra e «Scarica», Jam (D-71), avvio dello streaming all'indirizzo (R-71). Solo ritocchi mirati.
- Pannello «Info» del desktop come il telefono; brani in cache già arricchiti non si rifanno, i rifiutati (`limited`) riprovano al prossimo ascolto (D-350).

## Arrivo
- **Chi fa partire l'arricchimento**: non più `StreamPreparer._run` all'inizio del download, ma un innesco legato al brano corrente: quando il brano che suona è in streaming e sta suonando da 5 s (posizione ≥ 5 s, o 5 s di riproduzione), si arricchisce la sua riga ombra; un cambio di brano prima annulla il timer. Lo stesso innesco copre i brani già in cache (F-04). `enrich` resta la funzione di oggi (`stream_providers.dart:63`), chiamata con la riga già pronta.
- **Cosa leggono le schede**: l'id della riga ombra, non l'id negativo della voce. Finché la riga non c'è, segnaposto (D-347).
- Prima → dopo:

| Cosa | Prima | Dopo |
|---|---|---|
| Schede nella schermata del brano | nascoste se `online` | visibili per lo streaming (senza `ProposalCard`) |
| Id usato da crediti e curiosità | id negativo della voce | id della riga ombra |
| Avvio dell'arricchimento | all'inizio del download, anche i pre-caricati | 5 s dopo l'avvio del brano che suona |
| Brano già in cache | mai arricchito | arricchito se manca, come sopra |

Niente mockup: il cambio visivo è il ritorno di schede che esistono già, più un segnaposto della stessa altezza.

## Rete
- **Test che falliscono sul `master` di oggi** (regola della fase 74): (a) widget: brano in streaming con riga ombra che ha testo e curiosità → le schede testo, curiosità e crediti ci sono e mostrano i dati della riga; (b) le schede di crediti e curiosità leggono l'id della riga ombra; (c) unità: l'arricchimento non parte all'inizio del download né per un pre-caricato; parte 5 s dopo l'avvio; un salto prima dei 5 s lo annulla; un brano in cache senza dati viene arricchito, uno già arricchito no.
- **Caratterizzazione da tenere verde**: `test/services/audio/online_playback_test.dart` (riga ombra in `liveCurrentTrackProvider`), `test/services/stream/stream_preparer_test.dart`, `test/ui/now_playing_loading_test.dart`, `test/ui/info_card_test.dart`, `test/ui/lyrics_card_test.dart`, i brani della libreria con le schede di oggi.
- **Comportamento invariato**: brani della libreria identici; la Jam identica; lo streaming parte quando parte oggi (riga `stream timing` con `url=` non peggiore, a parità di rete).
- **Metriche di arrivo**: `flutter analyze` pulito; comando mirato verde; prova dal vivo su Linux: ricerca online e un suggerito di Shuffle+ → testo, curiosità e crediti compaiono dopo ~5–15 s; nel log nessuna riga d'arricchimento prima dei 5 s.
