# Fase 85 — Debito della review di architettura della fase 83

**Obiettivo:** chiudere i rilievi rimasti dalla review di architettura della fase 83. Nessuna funzione nuova. Cambiano solo due comportamenti visibili:
- «In riproduzione da» segue anche Android Auto;
- nei selettori una ricerca fallita mostra l'errore.

Erano già chiusi nella fase 83:
- l'altezza delle righe dei selettori a testo 2×;
- il filtro del foglio della coda;
- il commento sull'enum del contesto.

## Task
- **85.1** Contesto e attesa delle schede in streaming:
  - `playContextProvider` segue il contesto dell'handler (un `ValueListenable`). Spariscono `PlayContextNotifier`, `onContext` e la semina in `main`. Così `playFromMediaId` di Android Auto aggiorna anche «In riproduzione da».
  - Il tetto dei 60 s delle schede in streaming esce dall'handler e va in `shadowWaitProvider`.
- **85.2** Selettori:
  - `add_tracks_screen` e `track_picker_screen` usano `keepWhileLoading` + `AsyncBody`, così una ricerca fallita non tiene più i risultati vecchi in silenzio.
  - Nuovo test a tappeto: ogni nodo-pulsante delle schermate principali ha l'azione di tocco.
- **85.3** Shuffle+:
  - `libraryIndexProvider` passa in `library_providers.dart`, documentato.
  - La regola «Shuffle+ spento» sta in un posto solo.

**Fatto quando:** la PR è fusa con «Analyze and test» verde.

## Esiti
