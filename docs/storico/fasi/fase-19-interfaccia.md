# Fase 19 — Interfaccia: selezione multipla, trascinamento, temi, tablet, lingue, onboarding

**Obiettivo:** chiudere i buchi dell'interfaccia rimandati dalla Fase 11: agire su **molti brani insieme**
(barra azioni), trascinare brani sulle playlist della barra laterale su desktop, un **tema chiaro** e un **colore
d'accento** a scelta, un layout pensato per schermi ≥ 1200 px, due lingue in più (fr, pt) e una **guida al primo
avvio**.
**Prerequisiti:** Fase 11 (shell, `TrackRow`, `trackActions`, token `CcColors`), Fase 4 (ARB), Fase 13 consigliata
(il backup protegge da errori di massa).
**Principio:** nessuna azione di massa tocca i file dell'utente. «Rimuovi» vuol dire sempre e solo righe del DB
(regole 6 e 10 di `01-regole-di-lavoro.md`). Ogni azione di massa distruttiva chiede conferma con il numero di brani.

## Decisioni
| Tema | Scelta |
|---|---|
| Ingresso in selezione | Mobile: pressione lunga su una riga (oggi apre `showTrackActions`: diventa «seleziona», il menu resta su ⋯). Desktop: Ctrl+clic e Maiusc+clic; pressione lunga non cambia. Clic destro resta il menu del brano |
| Stato della selezione | Un `SelectionController` per lista (Notifier con `Set<int>` di id e ancora per Maiusc), **non** globale: cambiare scheda o pagina esce dalla selezione |
| Barra azioni | Sostituisce l'intestazione della pagina (mobile) / compare sopra la lista (desktop): «N selezionati», Seleziona tutto, ✕, e le azioni del contesto |
| Azioni | Riproduci, Riproduci dopo, In coda, Aggiungi a playlist, Preferiti (aggiungi/togli), Aggiungi alla Jam (se attiva), Rimuovi dalla playlist (solo in playlist), Rimuovi dalla libreria (**solo** brani `missing`, come `missing_tracks_screen.dart`), Scarica (solo risultati YouTube) |
| «Nascondi dalla libreria» | Non in questa fase: serve una colonna nuova, arriva con `tracks.ignored` in Fase 21 |
| Trascinamento desktop | `Draggable<List<int>>` dalle righe (la selezione intera se la riga è selezionata), `DragTarget` sulle voci playlist di `DesktopSidebar`; feedback con `ccDragProxy` |
| Temi | `AppThemeId { notte, oled, chiaro }` + accento scelto da 8 colori predefiniti (niente selettore libero: il contrasto non sarebbe verificabile) |
| Contrasto | Ogni combinazione tema × accento passa un test AA (testo ≥ 4,5:1, testo grande e icone ≥ 3:1) |
| Tablet | ≥ 1200 px: pannello destro sempre aperto (320 → 360) e griglie con più colonne; nessuna terza navigazione |
| Lingue nuove | `fr`, `pt` (portoghese europeo); solo ARB, il codice non cambia |
| Onboarding | 4 pagine al primo avvio, saltabile, mai più mostrato (`onboardingDone` in `AppSettings`) |
| Pacchetti nuovi | Nessuno |

## Task

### 19.1 — `SelectionController` (logica pura)
**File:** `lib/providers/selection_providers.dart`, `test/providers/selection_test.dart`
1. `class Selection { final Set<int> ids; final int? anchor; bool get active; }` immutabile.
2. Metodi: `toggle(id)`, `selectRange(List<int> visibleIds, id)` (da `anchor` a `id` nell'ordine **visibile**),
   `selectAll(List<int> visibleIds)`, `clear()`, `retainWhere(Set<int> stillVisible)` (un filtro che nasconde righe
   le toglie dalla selezione).
3. Provider `NotifierProvider.autoDispose.family<SelectionNotifier, Selection, String>` con chiave della lista
   (`'all'`, `'album:<key>'`, `'playlist:<id>'`, `'favorites'`, `'search'`, `'youtube'`).
**Test:** toggle, intervallo in avanti e all'indietro, intervallo senza ancora = toggle, `retainWhere`, seleziona tutto.

### 19.2 — `TrackRow` selezionabile
**File:** `lib/ui/widgets/track_row.dart`, `lib/ui/widgets/track_row_selection.dart` (nuovo, per restare ≤ 300 righe)
1. Nuovi parametri `selected` e `selectionMode`. In selezione: casella al posto della copertina/numero (stessa
   larghezza: `itemExtent` invariato), sfondo `accentSoft` al 16 %, tocco = toggle, nessun swipe «In coda».
2. `LiveTrackRow` passa `selected`/`selectionMode` dal provider di 19.1 (ricostruisce solo la riga, `select`).
3. `Semantics(selected: …)` e etichetta «Selezionato».
**Verifica:** widget test: riga in selezione mostra la casella, il tocco chiama il toggle, altezza invariata.

### 19.3 — Barra azioni e modello di azioni di massa
**File:** `lib/ui/widgets/selection_bar.dart`, `lib/ui/widgets/bulk_actions.dart`, ARB
1. `List<TrackActionGroup> bulkActions(context, ref, List<Track> tracks, BulkContext ctx)` riusa `TrackAction` /
   `TrackActionGroup` di `track_actions.dart` (stesso modello, stesse icone).
2. Riproduci / Riproduci dopo / In coda passano dal `PlayerController` con lo snapshot **nell'ordine della lista**,
   non nell'ordine dei clic.
3. Aggiungi a playlist: riusa il dialogo di `playlist_dialogs.dart`; `PlaylistRepository.addTracks` già salta i
   doppioni → snackbar «12 aggiunti, 3 già presenti».
4. Preferiti: se tutti sono preferiti → «Togli dai preferiti», altrimenti «Aggiungi»; una sola transazione
   (`TrackRepository.setFavoriteMany`, nuovo, + test).
5. Rimuovi dalla playlist: conferma «Rimuovere N brani dalla playlist?» con Annulla nello snackbar (ripristina le
   posizioni). Rimuovi dalla libreria: visibile **solo** se tutti i selezionati sono `missing`.
6. `SelectionBar`: «N selezionati», Seleziona tutto, ✕; su mobile al posto dell'AppBar, `PopScope` fa uscire dalla
   selezione col tasto indietro; su desktop Esc esce, Ctrl+A seleziona tutto.
**Test:** `setFavoriteMany`; widget test della barra (conteggio, azioni visibili per contesto, Indietro esce).

### 19.4 — Collegare le liste
**File:** `all_tracks_screen.dart`, `album_detail_screen.dart`, `artist_screen.dart`, `favorites_screen.dart`,
`playlist_detail_screen.dart`, `search_screen.dart`, `youtube_results.dart`
1. Pressione lunga = entra in selezione con quella riga; desktop Ctrl/Maiusc+clic. ⋯ e clic destro restano il menu.
2. Playlist: in selezione il riordino a trascinamento è disattivato (niente conflitto tra gesti).
3. Risultati YouTube: azione «Scarica» (N download in `DownloadQueue`), con l'avviso legale già mostrato una volta.
**Verifica:** `flutter test` (widget test di fumo per «Tutti i brani» e per una playlist in selezione).
**Tocca a te:** telefono: pressione lunga, selezione di 20 brani, «Aggiungi a playlist», Indietro.

### 19.5 — Trascinare brani sulle playlist (desktop)
**File:** `lib/ui/shell/desktop_sidebar.dart`, `lib/ui/widgets/track_drag.dart`, `track_row.dart`
1. Solo con `isDesktop`: le righe sono `Draggable<TrackDragData>` (ids + numero) con `ccDragProxy` e una pastiglia
   «N brani»; se la riga trascinata è selezionata si trascina tutta la selezione.
2. Le voci playlist della barra laterale sono `DragTarget`: evidenziazione al passaggio, al rilascio
   `addTracks` + snackbar. Anche la voce «Preferiti» accetta (imposta preferito).
3. Nessun conflitto con lo scorrimento: trascinamento parte dopo 6 px di movimento (`Draggable`, non `LongPress`).
**Verifica:** widget test con `tester.drag` da una riga alla voce playlist → `addTracks` chiamato con gli id giusti.

### 19.6 — Tema chiaro e colore d'accento
**File:** `lib/ui/theme/tokens.dart`, `lib/ui/theme/app_theme.dart`, `lib/ui/theme/cover_tint.dart`,
`lib/data/settings/settings_store.dart`, `settings_screen.dart`, `theme_swatch.dart`, `test/ui/contrast_test.dart`
1. `CcColors.chiaro` (fondo chiaro, superfici grigio-viola, testo scuro). `AppThemeId.chiaro`; il nome `light`
   (ritirato in fase 11) torna a puntare a `chiaro` invece di cadere su `notte`.
2. `CcAccent` con 8 valori (viola attuale predefinito, blu, verde acqua, verde, ambra, arancio, rosa, rosso), ognuno
   con varianti per tema scuro e chiaro e `onAccent` calcolato. `AppSettings.accent` (stringa, default `viola`).
3. `heroTint`/`CoverBackdrop` nel tema chiaro: tinta schiarita, testo scuro; mantenere il limite ≥ 7:1 di
   `cover_tint_test.dart` anche al chiaro.
4. Impostazioni → Aspetto: tre campioni tema + fila di 8 cerchi d'accento, applicazione a caldo.
**Test:** `contrast_test.dart` itera **tutti** i temi × accenti: testo/fondo, testo/superfici ≥ 4,5; accento su
fondo ≥ 3; `onAccent` su accento ≥ 4,5. Settings store: valore sconosciuto → default.

### 19.7 — Layout ≥ 1200 px (tablet, ripiegabili, finestre larghe)
**File:** `lib/ui/shell/app_shell.dart`, `side_panel.dart`, `album_grid.dart`, `home_screen.dart`
1. Costante `_xlBreakpoint = 1200`: pannello destro aperto di default a 360 px (si chiude ancora a mano),
   griglia album con colonne calcolate dalla larghezza (cella minima 168 px), Home con caroselli più fitti.
2. Ripiegabili: usare `MediaQuery.displayFeatures` — se c'è una cerniera verticale, la barra laterale non la
   attraversa (contenuto a destra della cerniera).
3. Verificare 840, 1000, 1200, 1600 px con gli scatti di `scripts/shots.sh`.
**Verifica:** widget test con `tester.view.physicalSize` a 1280×800 e 1600×1000: nessun overflow, pannello visibile.

### 19.8 — Lingue francese e portoghese
**File:** `lib/l10n/app_fr.arb`, `lib/l10n/app_pt.arb`, `settings_store.dart` (valori ammessi), `settings_screen.dart`
1. Tradurre tutte le chiavi di `app_it.arb` (template). Nomi lingua nativi: «Français», «Português».
2. `flutter gen-l10n`; `supportedLocales` si aggiorna da solo.
3. Controllo che nessuna stringa sia rimasta in italiano: script di test che confronta le chiavi e segnala valori
   identici all'italiano oltre una lista di eccezioni (nomi propri, «Jam», «Codecore»).
**Test:** test delle chiavi (stesso insieme in tutti gli ARB) + `large_text_test.dart` ripetuto in `fr` (testi più lunghi).

### 19.9 — Onboarding al primo avvio
**File:** `lib/ui/screens/onboarding/onboarding_screen.dart` (+ pagine), `app.dart` o `app_shell.dart`, `settings_store.dart`, ARB
1. Si apre se `onboardingDone == false` **e** la libreria è vuota (chi aggiorna l'app non lo vede).
2. Pagine: (1) benvenuto; (2) cartelle musicali (riusa `folders_sheet.dart`) e, su Android, permesso
   `READ_MEDIA_AUDIO` con spiegazione prima della richiesta; (3) funzioni online spente di default
   (arricchimento, testi) con interruttori; (4) download da YouTube: cosa fa, **avviso sui Termini d'uso**
   (stesso testo di `ytNoticeSeen`, che viene segnato come visto), Jam e condivisione in due righe.
3. «Salta» in ogni pagina; alla fine avvia la scansione.
**Verifica:** widget test: primo avvio con libreria vuota mostra la pagina 1; «Salta» imposta `onboardingDone`.

### 19.10 — Rifinitura, documentazione e prova a mano
1. ARB it/en/de/es/fr/pt completi per tutte le stringhe nuove.
2. `docs/02-architettura.md` (selezione, temi, breakpoint 1200), `docs/03-modello-dati.md` (impostazioni
   `accent`, `onboardingDone`, tema `chiaro`), `docs/99-rischi-e-fallback.md` (R44, R45), README.
3. Scatti a 100 % e 150 % di: barra di selezione, tema chiaro, onboarding.
**Tocca a te (Linux + telefono):** selezione e azioni di massa in libreria, album, playlist e risultati YouTube;
trascinamento su playlist della barra laterale; tema chiaro con 2–3 accenti (leggibilità al sole sul telefono);
app in francese; onboarding con una installazione pulita (HOME isolato su Linux).

## Fuori da questa fase
«Nascondi dalla libreria» (Fase 21, con `tracks.ignored`), etichette utente in massa (Fase 20), selettore di colore
libero, temi scaricabili, scorciatoie personalizzabili.

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R44 | Gesti in conflitto (pressione lunga, swipe, trascinamento di riordino, `Draggable` desktop) | Selezione disattiva swipe e riordino; su desktop il trascinamento parte da movimento, non da pressione lunga; widget test per ogni lista |
| R45 | Tema chiaro con contrasto insufficiente (copertine chiare, accento giallo) | Palette chiusa di 8 accenti, test AA su ogni combinazione, `heroTint` limitato anche al chiaro |
| — | Azione di massa sbagliata (rimuovi 300 brani dalla playlist) | Conferma con il numero, Annulla nello snackbar, backup della Fase 13 |

## Definition of Done
- [ ] Selezione multipla in tutte le liste di brani con barra azioni; nessun file toccato
- [ ] Trascinamento su playlist della barra laterale funzionante su desktop
- [ ] Tema chiaro + 8 accenti, test di contrasto AA verdi per tutte le combinazioni
- [ ] Layout ≥ 1200 px senza overflow; fr e pt completi; onboarding al primo avvio
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
