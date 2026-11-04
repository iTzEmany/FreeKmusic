# Fase 77 — Rete di sicurezza e componenti comuni (refactor «ui-uso-quotidiano»)

**Obiettivo:** fissare con test il comportamento di oggi delle parti che il refactor tocca, registrare la misura di partenza del cambio scheda in Libreria, e creare i due componenti che servono a tutte le fasi dopo: `Skeleton` (al posto degli spinner) e `CcSearchField` (✕ a doppia funzione). In più: niente tastiera automatica aprendo Cerca.

**Prerequisiti:** fase 76 chiusa. Piano e rilievi: `refactor/ui-uso-quotidiano/analisi.md` (sezioni «Scelte», «Arrivo», «Rete»); decisioni D-354…D-371; mockup in `refactor/ui-uso-quotidiano/mockup/` (indice `indice.html`). Nessun pacchetto nuovo (D-367): lo skeleton si fa a mano. Una PR per la fase, un commit per task.

**Regola della fase (e di tutte fino alla 83):** ogni comportamento nuovo prima si fissa con un test rosso sul `master` di oggi; i test elencati in analisi.md «Test che cambiano per scelta» si riscrivono nella stessa PR del cambiamento.

**Comando mirato:** `flutter test test/ui/async_body_test.dart test/theme/contrast_test.dart test/ui/a11y_guidelines_test.dart test/ui/search_dock_test.dart test/ui/search_screen_test.dart test/ui/home_screen_test.dart test/data/library_entries_test.dart test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart` (più i file nuovi).

## Task

### 77.1 — Rete di sicurezza e misura di partenza
- Rileggere i corpi dei test citati in analisi.md «Rete» (il test-strategist ha letto solo i nomi) e aggiungere i test di caratterizzazione mancanti: Home (contenuto e ordine di Riprendi / Più ascoltati / Riscopri; ▶ = tutta la libreria, Shuffle = solo modalità, se non già coperti); Libreria (ordine di ogni scheda e ordinamento, anche dopo Tutto→Playlist→Tutto); Tutti i brani (nuovo `test/ui/all_tracks_screen_test.dart`: selezione, trascinamento, azioni, ▶/Shuffle); chiave `genre-$tag`; ricerche recenti.
- `integration_test/perf_test.dart`: scenario nuovo «Libreria Tutto→Playlist→Album→Artisti». Sistemare prima le rotture note (`perf_test.dart:67`, `scripts/perf_device.py:226`) se ci sono ancora. Misura di partenza su Linux e sul Mi A3 (`python3 scripts/perf_device.py 0d7ae9df206e --label 77-partenza --only "<scenario>"`), scritta qui in «Esiti».

### 77.2 — Componente `Skeleton` (F-51, F-66, F-68, F-69)
- `lib/ui/widgets/skeleton.dart`: varianti lista, riga grande, cella di griglia, scheda, barre (specifica: `refactor/ui-uso-quotidiano/mockup/streaming-skeleton.html` parte c). Blocchi `surface2` (`surface1` dentro le schede), pulsazione d'opacità 0,55→1 in 1,4 s, ferma (0,8) con `disableAnimationsOf`; `ExcludeSemantics` sui blocchi e un solo nodo «Caricamento…» (liveRegion). Stringa nuova negli ARB it/en/de/es.
- `AsyncBody`/`SliverAsyncBody`: skeleton di righe di serie al posto di `CircularProgressIndicator` (`async_body.dart:36`); `PageSkeleton` (`artist_page_sections.dart:93`) diventa un uso di `Skeleton`. Riscrivere «loading shows a spinner».
- Test: un solo «Caricamento…» per TalkBack; animazione ferma con riduci movimento; contrasto in `contrast_test`.

### 77.3 — `CcSearchField` e focus di Cerca (F-03, F-04, F-09, F-16, F-23, U2, U3)
- `lib/ui/widgets/cc_search_field.dart` (forma: `refactor/ui-uso-quotidiano/mockup/cerca.html`): lente, testo, ✕ sempre visibile con tre stati: testo → svuota; vuoto con focus → chiude la tastiera (`unfocus`); vuoto senza focus → attenuata e inerte. Etichette diverse per i due usi («Cancella ricerca», «Chiudi tastiera»).
- Usarlo nel campo del dock (`bottom_bar.dart` `_SearchField`, resta legato a `searchControllerProvider`) e nel campo desktop di Cerca; Libreria e Tutti i brani lo adottano nella fase 79.
- Focus: `focusOnShow` falso quando Cerca si apre dal dock (`ui_providers.dart:56-62`, `bottom_bar.dart:170`); resta vero per Ctrl+F (`app_shell.dart:86-89`). Riscrivere «Cerca brings it back focused».
- Test: tre stati della ✕; aprendo Cerca dal dock nessun focus; Ctrl+F dà il focus.

### 77.4 — Controlli di fase
`flutter analyze` pulito; comando mirato verde; code-review medium; scheggia di passo su 77.2 e 77.3. Sul Mi A3: aprire Cerca (niente tastiera), toccare la barra (tastiera), ✕ con testo e senza.

**Fatto quando:** misura di partenza scritta qui, test di caratterizzazione verdi, nessuno spinner in `AsyncBody`, ✕ a tre stati provata sul telefono.

## Esiti
