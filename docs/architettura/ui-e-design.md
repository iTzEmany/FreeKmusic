# Interfaccia e design

## Scopo
Come è fatta la UI (`lib/ui/`): la shell con le schede e il dock, i token di design, i mattoni da riusare, gli avvisi, l'accessibilità, la localizzazione e i test che fanno rispettare tutto questo. Chi aggiunge una schermata parte da qui.

## Mappa del codice

### Shell e navigazione (`lib/ui/shell/`, `lib/providers/nav_providers.dart`)
| File | Simbolo | Ruolo |
|---|---|---|
| `app_shell.dart` | `AppShell`, `_WideShell` | Radice dopo l'onboarding. Quattro schede in un `IndexedStack`, ognuna in `TickerMode(enabled: i == index)` e con un proprio `Navigator`. Scorciatoie da tastiera (`ShellKeys`). |
| `bottom_bar.dart` | `ShellDock`, `DockLayers`, `_Tabs`, `_TabDot` | Dock del telefono: mini player, schede con etichetta e il pallino (il campo di Cerca sta nella pagina, fase 124). |
| `shell_nav.dart` | `ShellNav.open`, `openOnTop`, `popToRoot`, `openInLibrary`, `openInHome`, `showSearch` | Apre le pagine dentro il navigator della scheda, così dock e mini player restano. |
| `desktop_sidebar.dart`, `desktop_player_bar.dart`, `side_panel.dart` | `DesktopSidebar`, `SidePanelView` | Layout largo: colonna a sinistra, barra del player, pannello a destra (coda, testo, info). |
| `shell_keys.dart` | `ShellKeys` | Scorciatoie che reggono il cambio di focus e non rubano lo spazio ai campi di testo. |
| `lib/providers/nav_providers.dart` | `NavTab { home, search, library, memory }`, `navIndexProvider`, `tabNavigatorKeysProvider`, `SidePanel` | Stato della navigazione. |
| `lib/providers/ui_providers.dart` | `searchFocusProvider`, `searchControllerProvider` | Fuoco e testo del campo di Cerca (in cima a `SearchScreen`); il tasto Cerca del dock chiede il fuoco, `_UnfocusOnPush` lo toglie quando da Cerca si apre una pagina. |

### Tema e token (`lib/ui/theme/`)
| File | Simbolo | Ruolo |
|---|---|---|
| `tokens.dart` | `CcColors` (`notte`, `oled`, `chiaro`), `context.cc`, `CcDims`, `CcMotion`, `CcTiming`, `ccDuration`, `ccStyle`, `buildTextTheme` | Unica fonte di colori, misure, durate e stili di testo. Nessun esadecimale fuori da qui. |
| `palette.dart` | `AppThemeId`, `CcAccent` (8 accenti), `contrastRatio` | Combinazioni tema × accento, con contrasto verificato. |
| `custom_theme.dart` | `CustomTheme`, `CustomThemes`, `ThemeBackground`, `hasLowContrastText` | Temi dell'utente: i colori cambiati e quelli che li seguono. L'avviso di contrasto non cambia mai i colori. |
| `app_theme.dart` | `CcPageTransitionsBuilder`, `ccIconDensity` | `ThemeData`, transizioni di pagina, densità compatta su desktop. |
| `theme_background.dart`, `cover_tint.dart` | `AppBackground` | Sfondo scelto e tinta presa dalla copertina. |
| `lib/app.dart` | `AppTextScaler` | Scala del testo di sistema × scala dell'app. Ha `==` e `hashCode`. |

### Mattoni condivisi (`lib/ui/widgets/`)
| Mattone | File | Quando usarlo |
|---|---|---|
| `showMsg`, `showMsgOn`, `showQueued`, `CcSnackContent` | `show_msg.dart` | Ogni avviso. |
| `showCcSheet`, `showCcActionSheet`, `CcAction` | `cc_sheet.dart` | Ogni foglio e ogni menu. |
| `showConfirm`, `promptName` | `confirm.dart`, `prompt_name.dart` | Dialoghi di conferma e «scegli un nome». |
| `DownloadBar` | `download_bar.dart` | L'unica barra di avanzamento di un download (`entryKey` = `<source>:<id>`): avanzamento, poi «Scaricato» per qualche secondo (D-697), poi il pulsante `idle`. |
| `CcAppBar` | `cc_app_bar.dart` | Barra della pagina (l'unico `AppBar(`). |
| `AsyncBody<T>`, `RowsLoading`, `LoadError` | `async_body.dart`, `error_state.dart` | Caricamento, vuoto, errore, dati. |
| `Skeleton`, `EmptyState`, `ErrorState` | `skeleton.dart`, `empty_state.dart`, `error_state.dart` | Segnaposto e stati. `EmptyState` ha sempre icona (`icon`, 32 dp, `textMuted`), testo (`message`, `help`) e, se serve, un'azione (`actionLabel`/`onAction`, anche una seconda), tutto in alto a sinistra. |
| `CatalogAction` | `action_catalog.dart` | La tabella azione → icona → testo (vedi «Catalogo azioni»). |
| `CcTile`, `CcSearchField`, `GenreGrid` | `cc_tile.dart`, `cc_search_field.dart`, `genre_grid.dart` | Riquadri e campo di ricerca con attesa breve. |
| `TrackRow`, `TrackArt`, `CoverImage`, `AlbumCard`, `SectionHeader` | file omonimi | Righe, copertine, schede, intestazioni. `SectionHeader` è alto sempre `CcDims.sectionHeaderHeight` (48 dp): il pulsante «Tutti» (`actionLabel`) sta sempre nell'intestazione e non la fa crescere. |
| `MarqueeText` | `marquee_text.dart` | Solo titoli lunghi dei player, mai nelle liste. |
| `RingProgress`, `ProgressFrame`, `ActivityButton`, `SeekBar` | file omonimi | L'anello di avanzamento e i controlli del player. |
| `FocusRingButton`, `ActionButton`, `PressScale` | `focus_ring_button.dart`, `action_button.dart`, `motion.dart` | Pulsanti con anello di focus e feedback al tocco. |
| `EntranceScope`, `EnterOnce`, `RiseIn`, `TabFade` | `motion.dart` | Animazioni d'ingresso dalla scala dei token. |
| `growRoute` | `grow_route.dart` | Il player che cresce dal mini player. |
| `ShrinkingHeader`, `CollectionHeader`, `AlphaScroller`, `SelectionBar` | file omonimi | Intestazioni che scorrono, indice alfabetico, barra di selezione. |
| `ReleaseNotesView`, `ShareCard`, `shareCardMaker` | `release_notes_view.dart`, `share_card.dart`, `share_card_maker.dart` | Le novità di una versione (evidenza, novità, «Correzioni» chiuso, link a GitHub), condivise da `UpdatePage` («Aggiornamento disponibile», foglio a tutto schermo o dialogo a due colonne da `wideBreakpoint`) e `WhatsNewPage` («Aggiornata alla X», una volta dopo l'aggiornamento); la scheda di condivisione (D-712), sempre scura. |
| `createPlaylistFlow`, `createTagFlow` | `create_flows.dart` | L'unico «crea playlist/tag». |
| `KaraokeVideoView`, `karaokeVideoBuilderProvider`, `KaraokeVideoFullscreen` | `widgets/karaoke_video_view.dart`, `widgets/karaoke_video_surface.dart`, `screens/now_playing/karaoke_video_fullscreen.dart` | Riquadro 16:9 del brano karaoke al posto di copertina e anello (`_PlayerCover`) e schermo intero. |

La scrittura passa dagli Ops (`lib/providers/*_ops.dart`: `TrackOps`, `PlaylistOps`, `TagOps`, `FolderOps`, `FollowOps`, `RadioOps`, `PodcastOps`, `RomanizationOps`, `BackupOps`, `CoverOps`); la selezione da `selectionProvider` e `SelectionKey` (`lib/providers/selection_providers.dart`).

### Localizzazione
| Percorso | Ruolo |
|---|---|
| `l10n.yaml` | `arb-dir: lib/l10n`, modello `app_it.arb`, `nullable-getter: false`. |
| `lib/l10n/app_{it,en,de,es,fr,pt}.arb` | Sei lingue. L'italiano è il modello. |
| `lib/l10n/app_localizations*.dart` | Generati da `flutter gen-l10n` e tracciati. La CI rifiuta un diff. |
| `lib/l10n/l10n_ext.dart` | `context.l10n`. |
| `scripts/arb_add.py` | Aggiunge stringhe a tutti gli ARB in un colpo. |

### Test che fanno rispettare le regole
| Test | Regola |
|---|---|
| `test/ui/architecture_test.dart` | `lib/ui` non usa `databaseProvider`, `*RepositoryProvider`, `*QueriesProvider` (D-24); niente `PopupMenuButton` né `showMenu(`: i menu sono fogli; `lib/services` non importa `lib/ui` (eccezioni scritte nel test: `app_icon.dart`, `restore_service.dart`). |
| `test/ui/no_stray_colors_test.dart` | Niente `Color(0x…)` né `Colors.<nome>` fuori da `lib/ui/theme/` (eccezioni: QR in `send_tab.dart` e `jam_remote_sheets.dart`, `color_picker.dart`, `karaoke_video_fullscreen.dart` con lo sfondo nero in ogni tema, `share_card.dart` e `share_card_maker.dart`: la scheda di condivisione è sempre scura, D-712). Il secondo test dice se un'eccezione non serve più. |
| `test/ui/no_separator_literals_test.dart` | Niente ` · `, `•`, `→`, `▾` nei letterali di `lib/` (fuori da `lib/l10n/` e dai parser di YouTube Music). |
| `test/ui/widgets_test.dart` | Niente `showModalBottomSheet` fuori da `cc_sheet.dart` e `car_playlists_sheet.dart`. |
| `test/l10n/arb_test.dart` | Stesse chiavi e segnaposto in tutte le lingue, niente stringhe vuote, apostrofo `’` in francese e portoghese, niente separatori, plurali con «other». |
| `test/ui/a11y_guidelines_test.dart` | Linee guida di accessibilità di Flutter sulle schermate principali, con una mappa di eccezioni che può solo restringersi. |
| `test/ui/talkback_labels_test.dart`, `accessibility_characterization_test.dart`, `button_tap_sweep_test.dart` | Un nodo per controllo, ognuno col suo nome; ogni pulsante risponde al tocco. |
| `test/theme/contrast_test.dart`, `tokens_test.dart` | Contrasto delle combinazioni e valori dei token. |
| `test/goldens/` | Aspetto delle schermate (solo Linux). |
| `scripts/guardie.sh` | Lancia in pochi secondi arb, separatori, architettura, colori (e i golden se il ramo tocca `lib/ui`); è l'hook `pre-push`. |

## Pagina Modelli e dizionari (D-673)

`lib/ui/screens/settings/models_screen.dart`. In Impostazioni → Online e download c'è una sola voce, `ModelsTile`, con il riepilogo («3 installati, 120 MB») che apre `ModelsScreen`. La pagina legge solo `modelCatalogProvider` (D-24): tre sezioni (Traduzione, Dizionario, Karaoke; quelle senza voci non compaiono, quindi fuori da Android restano solo il dizionario), una casella per voce con nome, dimensione e stato, il totale occupato in cima. «Scarica selezionati» agisce sulle voci non installate e chiede conferma con la dimensione totale (su rete a consumo il testo lo dice, D-656, via `networkProbeProvider`); senza rete dice «Serve la connessione» e non parte; la coda è in `modelQueueProvider` (una voce alla volta, un errore per voce con uno snackbar, «Annulla» toglie le voci non partite: quella in corso non si ferma). «Elimina selezionati» e il cestino per voce chiedono conferma. Ogni riga è un `ListTile` con casella (esclusa dalla semantica, un solo stop per riga con stato «selezionato») e cestino come pulsante a sé per TalkBack; il sottotitolo di stato è una live region. Nella coda di «Scarica selezionati» solo la voce corrente dice «In scaricamento…», le altre «In coda»; l'errore del dizionario compare in riga. Un download in corso (anche del dizionario avviato dal testo del brano), una sonda di rete o una cancellazione tengono fermi pulsanti e cestini. La selezione si toglie solo se l'operazione riesce. Se la pagina si chiude la coda va avanti, e riaprendola le righe dicono ancora «In scaricamento…» / «In coda». Se il catalogo non si legge: messaggio con «Riprova» (e nel sottotitolo della voce nelle Impostazioni). Il download dal testo del brano non passa di qui. Test: `test/ui/models_screen_test.dart`.

## Come funziona

### Schede e dock
Le schede sono quattro: Home, Cerca, Libreria, Memoria (`NavTab`). Ognuna ha il suo `Navigator`, quindi una pagina aperta dentro una scheda lascia visibili dock e mini player. Si aprono pagine con `ShellNav.open`, non con un `Navigator.push` sul navigator di radice; dal contesto del `TrackMenuHost` (un solo `ConsumerStatefulWidget` in `home`, vivo quanto l'app, da cui il menu ⋮ prende `context` e `ref`: niente `OverlayEntry` per menu; il `Rect` della riga, catturato all'apertura, arriva a `trackActions(anchor:)` per l'ancora del foglio di condivisione su iPad/desktop) `ShellNav.openOnTop` apre nella scheda attiva, o sulla radice solo se sopra la shell c'è già una route di radice (Now Playing). Toccare di nuovo la scheda attiva torna alla sua radice, ma una pagina che protegge l'uscita (modifiche non salvate, job in corso) chiede prima (`popToRoot`).
- **Icona «Condividi» (145.4)**: `CollectionScaffold(onShare: (Rect?) => …)` mostra l'icona (48 dp, tooltip «Condividi») tra «Scarica» e il menu ⋮; nascosta se `onShare` è null (collezione vuota). Oggi la usano album, playlist e preferiti. Nel menu ⋮ del brano «Condividi» sta nel gruppo «Altro» con `anchor` della riga.

Sul telefono il dock è un blocco unico in fondo: il mini player (se suona qualcosa) e le schede sempre con etichetta. Il corpo gira sotto il dock (`extendBody`): il dock dà alla pagina la sua altezza come `MediaQuery.padding.bottom`, e ogni lista la legge con `context.dockInset` (o `EdgeInsets.withDock(context)`). In Cerca, con la tastiera aperta, il dock si nasconde e il campo resta in cima alla pagina.

**Il pallino**: il punto d'accento in alto a destra dell'icona della scheda attiva (`_TabDot`). Salta alla nuova scheda lungo un piccolo arco; con «Riduci animazioni» la durata è zero e salta e basta. Lo stesso motivo (un punto che segue un anello) compare nel conto alla rovescia degli avvisi (`CcSnackContent`).

Sul desktop e sulle finestre larghe (`CcDims.wideBreakpoint`, 840) la shell diventa `_WideShell`: sidebar a sinistra (compatta sotto 1000 px), barra del player in basso, pannello a destra con coda, testo o info (`SidePanel`); sopra `xlBreakpoint` (1200) il pannello della coda si apre da solo e griglie e scaffali tengono più elementi.

### Righe dei brani, swipe e sfocatura (fase 119)
- **Swipe per la coda** (`SwipeToQueue` in `track_row.dart`): in ogni lista di brani, compresi quelli online, la daylist e i Suggeriti; restano senza le varianti coda e scelta. È un `GestureDetector` orizzontale, non un `Dismissible`. Lo spostamento si ferma al 60 % della riga e mette in coda oltre il 30 %. Un trascinamento che parte dal bordo dello schermo resta al gesto «indietro». Per TalkBack c'è l'azione «Aggiungi alla coda».
- **Selezione**: la `SelectionBox` sta sopra la copertina, con un velo `cc.bg` al 45 %, sia in `TrackRow` sia in `OnlineSongRow`.
- **Sfocatura**: `BlurredChrome` (`lib/ui/widgets/blurred_chrome.dart`) è l'unico effetto vetro, usato dal dock e da `LibraryIsland`. Segue «Dock e intestazioni sfocati»: sfocatura 20, con `surface2` all'alfa del tema × 0,78.
- **Superfici trasparenti**: nell'editor del tema solo Superficie 1, 2 e 3 hanno l'alfa, con minimo 20 % (`hasAlphaToken`, `_fit` in `custom_theme.dart`). Il contrasto si calcola sul colore composto sopra lo sfondo (`Color.alphaBlend`).
- **Registro**: con un tema con immagine o gradiente l'intestazione fissa dei giorni non dipinge `cc.bg` ma sfoca la pagina sotto. Gli errori di riproduzione sono una voce `playbackFailed`, una sola se lo stesso brano fallisce di fila. Il testo del motivo viene da `playbackReasonText`.
- **Registro, importazioni**: in cima alla lista «Ferma tutto» e «Annulla tutto» (D-698) compaiono solo se c'è almeno un'importazione in corso («Ferma tutto» solo se una è `running`; `unfinishedImportsProvider`); agiscono su ogni catena con `pauseAll`/`cancelAll` del servizio, «Annulla tutto» chiede conferma.

### Fogli, dialoghi, menu
Regola dei dialoghi: **dialogo per il testo** (un nome, una conferma), **foglio per le scelte** (elenchi, azioni, selettori). Ogni foglio si apre con `showCcSheet` (sempre sul navigator di radice, così copre dock e sidebar, 250 ms, zero con «Riduci animazioni»). I menu sono `showCcActionSheet` con `CcAction`. Dalla fase 138 un foglio senza `constraints` propri occupa `min(560, larghezza)` (`minWidth` in `showCcSheet`, un solo punto): un foglio con poco contenuto non resta stretto al centro. I campi di ricerca e il nome di una playlist non prendono il focus da soli (D-667): la tastiera si apre solo al tocco; Ctrl+F resta su desktop.

### Token
- **Colori**: `context.cc` (`CcColors`: `bg`, `surface1..3`, `accent`, `accentSoft`, `onAccent`, `text`, `textMuted`, `textFaint`, `heroBase`, `error`, `separator`; nel tema Notte `textMuted` è #B3AAC2, più chiaro di prima per il contrasto del testo secondario). Un tema dell'utente può avere qualsiasi colore, quindi nessun widget ne tiene uno proprio.
- **Misure**: `CcDims` (raggi `rList` 4, `rGrid` 8, `rCard` 12, `rSheet` 16; scala `gap4`…`gap32`; altezze di dock, barra, sidebar; `blockGap` 24 (32 su desktop) tra i blocchi, `blockPad` = metà di `blockGap` dentro il blocco, `sectionHeaderHeight` 48).
- **Catalogo azioni (fase 152)**: `CatalogAction` (`action_catalog.dart`) è l'unica tabella azione → icona → testo; menu, barre e intestazioni prendono icona (`.icon`) ed etichetta (`.label(l10n)`) da lì. Coda `add_to_queue`, libreria `bookmark_add`, playlist `playlist_add`, scarica `download`, condividi `share`, esporta `save_alt` (esportare un file non è condividere), ⋮ = `more` (`moreActions`, «Altre azioni»). `queue_music` è solo di `queuePanel` (la coda come luogo: pannello, coda vuota), mai dell'azione «aggiungi alla coda».
- **Stati vuoti**: `EmptyState` richiede un'icona; per «coda» usa `CatalogAction.queuePanel.icon`.
- **Movimento**: `CcMotion` con una sola scala, 120 (`press`), 180 (`enter`), 250 (`sheet`), 320 (`page`) ms, `easeOutCubic` in entrata e `easeInCubic` in uscita. Le durate passano sempre da `ccDuration(context, d)`, che dà zero con «Riduci animazioni». Si animano trasformazioni e opacità.
- **Attese che non sono movimento**: `CcTiming` (`debounce`, `poll`, `msg` 4 s, `msgAction` 3 s, `msgLong` 5 s…). Non seguono la scala del movimento.
- **Testo**: `buildTextTheme` e `ccStyle` (Figtree e Unbounded, entrambi variabili: il peso va in `fontWeight` e in `fontVariations`). Una dimensione fuori dal tema solo con `.sized()`.
- **Aspetto**: l'anello è l'unico segno grafico che porta lo stato; superfici piatte, niente gradienti né ombre.
- **Riprendi ad anello (D-725, fase 153)**: `ResumeList` (`home/resume_rows.dart`) mostra fino a 8 ascolti **distinti e misti** (brani, podcast, album, playlist, radio, daylist) da `resumeItemsProvider` → `recentResumeItems` (`data/repositories/home_sections.dart`, funzione pura sui provider di cronologia; ha sostituito `lastPerArea`), il più recente primo; la coda che suona è sempre la prima voce; niente voce Daylist quando c'è la sua card (F-17). Il più recente sta grande al centro (96 dp, anello di avanzamento per brani ed episodi, pulsante «Riprendi»), gli altri su un arco aperto (56 dp, `CoverImage`/`PlaylistCover`/`RadioArt`); con 1 voce solo il centro, con 0 il blocco sparisce. Ogni voce è un nodo semantico con ruolo pulsante, bersagli ≥ 48 dp; tocco come prima (brano/podcast/radio suonano, album e playlist aprono la pagina, daylist col suo contesto, ciò che suona va in pausa/riprende). Limite: dei brani entrano solo l'ultimo per tipo di contesto e quelli da riprendere (`watchLastPlayPerContext` dà una riga per tipo). Stesso provider per il desktop. «Nuove uscite» (`NewReleasesBlock` in `home_blocks.dart`) è uno scaffale di al massimo 8 uscite di `recentReleasesProvider(30)` con `SectionHeader(actionLabel: showAll)`; senza uscite il blocco non compare.
- **Scorciatoie uguali (F-15, F-16, fase 153)**: Home e Libreria usano lo stesso `LibraryShortcuts` (`library/library_shortcuts.dart`): riquadri con titolo e sottotitolo (conteggio con l'unità), senza icona come nel mockup `telefono-home.html`; fino a 3 voci su una riga anche a 360 dp. La pagina Playlist non ha più i FAB: «Nuova playlist» e «Importa da Exportify» stanno nel «+» della Libreria e della barra laterale.
- **Superfici della home (D-687)**: ogni sezione è un `HomeBlock(header:)` con l'intestazione dentro la superficie, anche «Aggiunti da poco». Le testate (`ShrinkingHeader`, `CollectionScaffold`/`SliverAppBar`) non hanno un colore proprio: dietro si vede `AppBackground` (immagine del tema compresa). `ShrinkingHeader` ricresce solo in cima alla lista (D-705). L'anteprima dell'editor dei temi usa lo stesso `AppBackground`.
- **Pagine senza `cc.bg` proprio (fase 142)**: `OnlinePageFrame`, testi e editor dei testi, onboarding e barra laterale desktop lasciano il colore al tema (`scaffoldBackgroundColor`, trasparente con l'immagine); restano opachi `ActivityLogScreen` senza backdrop (l'intestazione sticky copre le righe) e la modalità auto. I `SectionHeader` delle pagine a lista restano senza sfondo. Il clic su «Cerca» nella barra laterale (solo desktop) dà focus al campo; il tasto della shell su telefono no (D-667).
- **Testata a icone e barra di scorrimento (D-676, D-694)**: `CollectionScaffold` mette sotto il nome una riga di icone: Riproduci 56 dp tondo in accento (`PlayCircleButton`), Casuale (`ShufflePill(iconOnly: true)`, stessa logica della pillola), Scarica (`downloadTracks`: l'icona c'è solo se tra i brani c'è almeno uno stream, quindi non su una pagina di soli file; il tocco chiama `keepOfflineFlow`) e lo slot `menu` (⋮), con tooltip e nome per il lettore di schermo; «Condividi» arriva con la 145. `scrollerCount` avvolge la pagina in `AlphaScroller` (modalità «per posizione»: la frazione del trascinamento va su `maxScrollExtent`, fumetto «120 / 850», alto quanto il suo testo (min 56 dp), non quanto la lista); con `letters` + `itemExtent` resta la modalità alfabetica. La barra è assente sotto `alphaScrollerMinItems` (100), sottile e quasi invisibile da ferma, visibile mentre si scorre (dissolvenza senza timer, spenta con «Riduci animazioni») e larga con maniglia da 48 dp finché la si tocca. Su desktop, dove la striscia è attiva, la `Scrollbar` Material di `AppScrollBehavior` è spenta sul figlio (`scrollbars: false`): niente doppia barra. La soglia vale anche in modalità alfabetica (141.7: A–Z su una lista corta non serve). La striscia finisce sopra il dock (`bottomInset`, di default `dockInset`) ed è esclusa dalla semantica (TalkBack scorre la lista da sé); l'area di tocco larga sul bordo destro è accettata. `scrollerCount` null o numero non cambia l'albero (niente rimontaggio dello scroll). Il ⋮ della testata è portato ad almeno 48 dp. Deviazione motivata: il tooltip di «Casuale» è `manual` (solo hover) perché il long press è del ciclo Shuffle+.

### Avvisi (D-541)
`showMsg(context, testo, {action, persist})` mostra un solo avviso alla volta (cancella quello corrente e la coda) ed è sicuro dopo un `await`. Con `showMsgOn(messenger, …)` si usa un messenger catturato prima, per avvisi dopo la chiusura di un foglio. Ogni avviso si chiude da solo: 4 s semplice, 3 s con azione, 5 s con azione e `persist: true`. Ha un conto alla rovescia, un anello sottile d'accento che si svuota in senso orario (`CcSnackContent`), escluso da TalkBack e fermo con «Riduci animazioni».

### Segnalazione (`ReportIssueScreen`, fase 143)

- **Anteprima del sync (146.7)**: `SyncPreviewDialog` è uno `StatefulWidget` che restituisce `SyncChoice` (decisione + chiavi delle impostazioni spuntate). Righe di riepilogo una per tipo, `CheckboxListTile` con etichetta e «qui: x, lì: y» (leggibile da TalkBack), il pulsante che cancella lo dice nel testo.

Larghezza massima 600 dp, scelta Bug/Idea senza icone, descrizione da 4 a 6 righe, anteprima delle informazioni tecniche alta al massimo 132 dp con scorrimento (nascosta finché non sono lette). Pulsanti in `Wrap` («Invia» solo con `kReportEndpoint` non vuoto, «Copia testo», «Apri su GitHub»); a campi incompleti una riga spiega perché sono spenti. Si apre vuota dalle Impostazioni o precompilata (`title:`, `details:`) dal tasto «Segnala un problema» di `LogDetail` (voci fallite o fermate, dettagli redatti con `redactLog`). Titolo e dettagli precompilati sono redatti con nome del dispositivo. «Invia» attende le informazioni tecniche se ancora in caricamento; se il log è stato accorciato lo dice (`reportLogShortened`). Dopo l'invio riuscito mostra il link della issue.

### Accessibilità e TalkBack
- Ogni controllo è un solo nodo con il suo nome (`label` o `tooltip`). Le copertine stanno fuori dalla semantica salvo `semanticLabel` (`coverSemantics` in `cover_image.dart`).
- Un `Semantics` con `excludeSemantics: true` (come le schede del dock) **deve avere lo stesso `onTap`** (e `onLongPress`) del figlio, altrimenti il nome c'è ma il doppio tocco non fa nulla.
- Un `GestureDetector` col solo `onSecondaryTapDown` aggiunge un tocco semantico vuoto: `excludeFromSemantics: true`.
- Bersagli a 48 dp sul telefono; densità compatta solo su desktop (`ccIconDensity`).
- Testo: scala di sistema × scala dell'app, tetto 2,0. Il `TextScaler` su misura (`AppTextScaler`) ha `==` e `hashCode`.
- Le animazioni si riducono con «Riduci animazioni» dell'app e con il flag di sistema.
- Il contrasto delle combinazioni tema × accento è verificato da test; nell'editor dei temi `hasLowContrastText` avvisa, senza cambiare i colori.
- Nei test: `tester.semantics.tap(find.semantics.byLabel(...))` e controlla l'effetto.
- Il microfono del karaoke è un solo nodo «Karaoke» con lo stato acceso/spento (`toggled`); il cursore si legge «Voce» e il valore in percentuale.
- Il riquadro del video karaoke è un nodo «Video karaoke», `button` solo quando il video è pronto (tocco: schermo intero; un altro tocco o Indietro: esce).
- Il supporto TalkBack sta sempre nel codice; le verifiche sono automatiche (test e `uiautomator`), non prove a mano.

### Localizzazione
Ogni testo visibile viene da un ARB (`context.l10n.<chiave>`). Italiano è il modello, poi en, de, es, fr, pt. Per aggiungere stringhe: `scripts/arb_add.py` (un file JSON, tutte le lingue insieme), poi `flutter gen-l10n`. Per unire parti di testo non si scrivono separatori nei letterali: si usa `', '`, come `track_row.dart`, o una stringa ARB.

## Invarianti da non rompere
- **La UI non parla con il database.** Solo provider e Ops. Le letture restano live (`StreamProvider`), le scritture passano da un Ops.
- **Nessun colore, `fontSize` o `BorderRadius` letterale** fuori dal tema: `context.cc`, `CcDims`, `buildTextTheme`.
- **Una sola scala di movimento**, sempre con `ccDuration`. Eccezione dichiarata: la dissolvenza fra pagine (`CcPageTransitionsBuilder`); il player sale dal basso.
- **Un solo `showModalBottomSheet`** (in `cc_sheet.dart`; `car_playlists_sheet.dart` è solo esentato da `widgets_test`), **un solo `AppBar(`** (`CcAppBar`, con le varianti `SliverAppBar` e `SelectableAppBar`), **nessun `PopupMenuButton`**.
- **Avvisi sempre da `showMsg`/`showMsgOn`.** Oggi ci sono due eccezioni che costruiscono un `SnackBar` da sé: `lib/ui/widgets/shuffle_button.dart` (spiegazione una tantum del Shuffle+, con `CcSnackContent`) e i tre avvisi globali di `lib/app.dart` (messenger di radice). Non aggiungerne altre.
- **Ogni scheda della shell sta in `TickerMode(enabled: i == index)`.** Nessuna animazione continua deve girare fuori schermo.
- **Il microfono del karaoke compare solo dove c'è il motore** (`karaokeButtonVisibleProvider`: Android, impostazione attiva, mai in una Jam, mai con un video karaoke) ed è spento su episodi, radio e video karaoke.
- **La UI non crea mai un player video**: legge `karaokeVideoProvider` e costruisce la superficie con `karaokeVideoBuilderProvider` (i test lo sostituiscono: nei test non c'è libmpv).
- **Ogni stringa visibile in tutti e sei gli ARB**, senza separatori nei letterali.
- **Selezione solo da `selectionProvider`**, con chiavi `SelectionKey` (le chiavi con parametro sono `'<tipo>:<id>'`).
- **Nessun valore instabile in `MediaQuery`, `Theme` o `InheritedWidget`**: ogni oggetto su misura ha `==` e `hashCode`.
- **Le liste lunghe usano `ListView.builder`/`SliverList`** con altezza fissa; le copertine `cacheWidth`; nessun `setState` globale per la posizione di riproduzione.
- **Dopo ogni `await` in un `State`**: controlla `mounted`; annulla timer, controller e sottoscrizioni in `dispose`.

## Come si estende
1. **Nuova schermata**: un file in `lib/ui/screens/<area>/`; si apre con `ShellNav.open(context, page)`; barra con `CcAppBar`; corpo con `AsyncBody` (o `RowsLoading`/`Skeleton`, `EmptyState`, `LoadError`); in fondo alle liste il margine del dock (`.withDock(context)` o `context.dockInset`).
2. **Nuova azione di scrittura**: un metodo nell'Ops del dominio (con undo e «solo quelli che cambiano» se serve), mai nel widget. La UI la chiama dal provider.
3. **Nuovo menu o scelta**: `showCcActionSheet` con `CcAction`; un testo libero va in un dialogo (`promptName`, `showConfirm`).
4. **Nuovo avviso**: `showMsg(context, l.chiave)`. Con un'azione «Annulla»/«Riprova» e `persist: true` se deve durare 5 s.
5. **Nuovo colore**: se manca un ruolo, si aggiunge a `CcColors` e a `CcToken`/`palette.dart` (con le combinazioni verificate), non nel widget.
6. **Nuova durata di animazione**: dalla scala `CcMotion` o, se è un'attesa, da `CcTiming`; sempre `ccDuration` per il movimento.
7. **Nuova stringa**: scrivila in un JSON e lancia `scripts/arb_add.py`, poi `flutter gen-l10n`; lancia `test/l10n/arb_test.dart`.
8. **Nuovo controllo toccabile**: `tooltip` o `label`, un solo nodo semantico; se usi `excludeSemantics` ripeti `onTap`; aggiungi un caso a `talkback_labels_test.dart` se il nome conta.
9. **Nuovo widget riusabile**: in `lib/ui/widgets/`, piccolo (build ≤ circa 120 righe; `scripts/build_len.py` le misura), con la sua durata dai token.
10. **Cambio d'aspetto voluto**: rigenera solo i golden che cambiano (vedi `qualita-e-rilascio.md`).
11. Prima del push lancia `scripts/guardie.sh`.

## Trappole
- **Testate con `color: cc.bg`** coprono l'immagine di sfondo del tema (F-26): una testata non dipinge un colore opaco e non è flottante: ricresce solo quando la lista torna in cima (D-705), così nessuna riga le passa sotto. Un `Colors.transparent` fisso su `Scaffold`/`SliverAppBar` invece toglie lo sfondo nei temi senza immagine: si lascia il colore del tema.
- **Un `TextScaler` su misura deve avere `==` e `hashCode`.** Senza, ogni rebuild passa a `MediaQuery` un valore «diverso» e ogni `Text` rifà il layout (Pallino schede dal 3 % al 12 % sul Mi A3, fase 40). Vale per ogni valore in `MediaQuery`, `Theme` o `InheritedWidget`.
- **`IndexedStack`/`Offstage` non fermano i ticker** delle schede nascoste: la rotella dell'`ActivityButton` girava fuori schermo (~100 frame/s a schermo fermo). Per questo `TickerMode` e un `RepaintBoundary` sulla rotella. Effetto: le animazioni d'ingresso di una scheda partono quando la si apre (nei test servono un paio di `pump` dopo il tocco).
- **Le notifiche di scroll dei fogli e delle route sopra la shell non arrivano a un listener in `AppShell`**: ciò che deve vedere ogni scroll sta in `MaterialApp.builder`, sopra il Navigator.
- **`Semantics(excludeSemantics: true)` toglie anche il tocco del figlio**: dai al `Semantics` lo stesso `onTap` e `onLongPress` (`uiautomator dump` lo mostra `clickable="false"`).
- **`SemanticsData.hasFlag` è deprecato**: `flutter analyze` dà un info che fa fallire il check; usa `getSemanticsData().flagsCollection.<flag>`.
- **`MarqueeText` e `pumpAndSettle`**: un titolo lungo scorre in un ciclo infinito, quindi un test con un brano dal titolo lungo in riproduzione va in timeout. Usa `pump(durata)`.
- **Snackbar e `pumpAndSettle` (D-541)**: l'anello si anima per tutta la durata, quindi `pumpAndSettle` dopo un avviso aspetta 3–8 s e un `expect` sul testo fallisce. Dopo un avviso: `await tester.pump(); await tester.pump(const Duration(milliseconds: 600));`.
- **Il riquadro del video karaoke in `loading` ha un `CircularProgressIndicator`**: `pumpAndSettle` va in timeout, usa `pump(durata)`.
- **Lo schermo intero del video cambia orientamento e barre solo su Android** e li ripristina in `dispose` (verticale, barre visibili, senza forzare edge-to-edge); si chiude da solo se il video va a `none` o `failed`.
- **Il filtro di Cerca ha quattro blocchi** (`SourceFilter`): i primi tre guardano le righe presenti, il quarto fa una richiesta nuova; la riga dei blocchi resta anche senza risultati dopo una scelta (`_filterTouched`).
- **Un `StreamProvider<void>` non notifica oltre il primo evento**: emetti un contatore `int`.
- **Un `ref.listen` su uno stato che emette due valori di fila** vede solo l'ultimo; e un provider derivato letto dentro il listener può avere ancora il valore vecchio: leggi la fonte diretta.
- **Un `FutureProvider` di Riverpod 3 ritenta da solo fino a 10 volte** (backoff 200 ms…6,4 s) su ogni eccezione che non sia `Error`: un provider che spende budget prima della richiesta lo consuma a ogni tentativo. I provider di rete del catalogo hanno `retry: (_, _) => null`.
- **Un debounce che si riavvia a ogni evento non scatta mai** se le scritture continuano: per «al più ogni N ms» il timer non si riavvia (`debounce ??= Timer(...)`).
- **Toccando gli ARB**, `test/l10n` va nei test mirati: francese e portoghese vogliono l'apostrofo `’` (quello dritto è un escape ICU) e una stringa uguale all'italiano (per esempio «No») va in `_sameAsItalian` di `arb_test.dart`. `flutter test -d linux` rigenera `app_localizations*.dart`: non committarli a metà.
- **Niente ` · `, `•`, `→`, `▾` nei letterali di `lib/`** (lo vieta `no_separator_literals_test.dart`, che i test mirati di solito non includono): usa `', '`.
- **Mai `dart format` su una cartella o su file che non hai toccato**: il progetto non è tutto formattato (un `dart format lib` ha toccato 481 file). Solo sui file del proprio diff, a larghezza 80 (non 120); se il formatter spezza un `if` senza graffe, aggiungi le graffe (`curly_braces_in_flow_control_structures`).
- **I test con `implements PlayerController` e `noSuchMethod`** rispondono `null` anche ai campi nuovi: un `ValueNotifier` aggiunto al controller rompe i test UI che aprono il foglio della coda. Aggiungi il campo agli spy.
- **Prima di correggere un «bug» trovato a mano, cerca in `docs/decisioni.md`**: «✕ di Ricerca chiude la tastiera» era D-155.

## Decisioni chiave
| ID | Significato |
|---|---|
| [D-20](../decisioni.md) | I golden si rigenerano solo quando un cambio d'aspetto è voluto e scritto nel passo. |
| [D-23](../decisioni.md) | Token di arrivo: colori, `textFaint`, scala di movimento. |
| [D-24](../decisioni.md) | La UI passa solo dai provider; test di architettura. |
| [D-48](../decisioni.md) | Densità compatta solo su desktop. |
| [D-381](../decisioni.md) | Etichette TalkBack dopo il giro sul telefono della fase 83. |
| [D-382](../decisioni.md) | Dissolvenza fra pagine; scheletri solo dopo 150 ms. |
| [D-541](../decisioni.md) | Ogni avviso si chiude da solo e mostra un conto alla rovescia. |
