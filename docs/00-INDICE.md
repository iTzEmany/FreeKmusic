# FreeKmusic Flutter — Indice della documentazione

> Dal 10/11/2026 l'app si chiama FreeKmusic (D-539); i documenti storici usano ancora Codecore.

App musicale **standalone** (nessun backend) in un'unica codebase Flutter per Android, Windows, Linux (e Mac in Release). Uso personale.

## Da leggere per primo
1. [`01-regole-di-lavoro.md`](01-regole-di-lavoro.md): regole obbligatorie (stile, test, verifiche).
2. [`architettura/00-panoramica.md`](architettura/00-panoramica.md): struttura, livelli, flusso dei dati, come si aggiunge una funzione.
3. Il documento dell'area che tocchi (sotto) e, se c'è, il file della fase aperta in [`fasi/`](fasi/README.md).

## Architettura ufficiale (per macroarea)
| File | Contenuto |
|---|---|
| [`architettura/00-panoramica.md`](architettura/00-panoramica.md) | Stack, struttura delle cartelle, livelli, flusso dei dati, checklist per le funzioni nuove |
| [`architettura/libreria-e-dati.md`](architettura/libreria-e-dati.md) | Database drift, schema e migrazioni, scansione, tag, copertine, playlist, chiavi |
| [`architettura/riproduzione-e-coda.md`](architettura/riproduzione-e-coda.md) | Motore audio, coda, shuffle e Shuffle+, gapless e crossfade, notifica |
| [`architettura/online.md`](architettura/online.md) | Ricerca e streaming, download, arricchimento, testi, riconoscimento, link e Shazam, podcast, radio |
| [`architettura/sync-backup-jam.md`](architettura/sync-backup-jam.md) | Condivisione LAN, dispositivi fidati, backup e ripristino, Jam (LAN, cassa, a distanza) |
| [`architettura/piattaforme.md`](architettura/piattaforme.md) | Android, Linux, Windows, Mac: canali nativi, permessi, differenze |
| [`architettura/ui-e-design.md`](architettura/ui-e-design.md) | Token, componenti, schermate, accessibilità, movimento, lingue |
| [`architettura/qualita-e-rilascio.md`](architettura/qualita-e-rilascio.md) | Test, CI, guardie, misure di prestazioni, script, rilascio |

Le **trappole** (cose che hanno già fatto perdere tempo) stanno nella sezione «Trappole» di ogni documento d'area; il vecchio elenco unico è archiviato in [`storico/gotchas.md`](storico/gotchas.md).

## Registri
| File | Contenuto |
|---|---|
| [`decisioni.md`](decisioni.md) | Un solo registro di tutte le scelte (D-xxx), con indice per area in cima e decisioni superate segnate |
| [`prossimi-lavori.md`](prossimi-lavori.md) | Backlog aperto, per area |
| [`99-rischi-e-fallback.md`](99-rischi-e-fallback.md) | Cosa può andare storto e il piano B |
| [`13-idee-future.md`](13-idee-future.md) | Idee raccolte per dopo |
| [`guida/`](guida/README.md) | Guida utente (Markdown; i link e le immagini li controlla `scripts/check_docs_links.py`) |

## Come si pianifica il lavoro nuovo
- Una fase nuova si scrive in [`fasi/fase-N-<nome>.md`](fasi/README.md) (modello nel README della cartella: obiettivo, task, comando mirato, fatto quando).
- L'avanzamento si spunta **nel file della fase** (niente più PROGRESS globale). A fase chiusa il file si sposta in `storico/fasi/` (`git mv`) e si aggiunge la riga alla tabella di [`storico/README.md`](storico/README.md).
- Ogni scelta nuova è una riga in `decisioni.md`; il documento d'area si aggiorna nello stesso passo.
- Modalità autonoma: `/obiettivo` (profilo in `.claude/obiettivo.md`), una PR per fase, un commit per task; la suite completa la esegue la CI.

## Storico
Tutte le fasi 0–116, le feature, i refactor, il vecchio PROGRESS e le vecchie architetture: [`storico/README.md`](storico/README.md). Non si aggiorna più.
