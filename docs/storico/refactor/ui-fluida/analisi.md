# Refactor «ui-fluida» — analisi

Aggiornato: 2026-10-23 · Tipo: struttura + UI · Perimetro: `lib/ui/` (screens 156 file / 26,3k righe, widgets 47 / 5,8k, shell 7 / 1,7k, theme 6 / 1,2k).
Fastidi dell'utente (D-02): aggiungere funzioni costa; lentezza; codice morto e peso; animazioni buggate o a scatti **su Mi A3 e Motorola** in quattro momenti: apertura del player, scorrimento delle liste, fogli e finestre, cambio di pagina o di scheda.
Già fatto, da non rifare: audit dell'aspetto «Anello» (`docs/audit-ui-anello.md`, passi 36.R1–R8) e la fase 28, che ha sistemato liste, miniature e testo per riga (`docs/fase-28-misure.md`).

## Misure di partenza
- **Telefono (Mi A3, fase 28; ultima misura nota):** avvio a freddo 2348 ms, PSS 187 MB. Tutti i brani: build p90/p99 5,4/11,2 ms, raster 10,1/15,1 ms, frame oltre 16,7 ms 0,3 %. Album 0,9 %, Ricerca 2,3 %.
- **Dopo «Anello», 2026-10-22** (`build/perf/anello-mia3.md`):
  - PSS 271 MB;
  - Tutti i brani: 5,3 % dei frame oltre 16,7 ms;
  - Pallino schede: 4,5 %;
  - In riproduzione: build p99 115,6 ms, 3,9 %;
  - Lettore dal dock: p99 40,8 ms, 4,8 %;
  - Anello: 1,6 %.
- **Partenza del refactor, 2026-10-23, HEAD `762bcc2`** (`build/perf/refactor-prima-mia3.md`, Mi A3, build profile):

  | Scenario | build p90/p99 ms | raster p90/p99 ms | oltre 16,7 ms |
  |---|---|---|---|
  | Pallino schede | 7,4 / 26,9 | 10,4 / 16,1 | **4,6 %** |
  | Tutti i brani | 5,5 / 12,0 | 9,1 / 15,9 | 1,4 % |
  | Album | 3,9 / 6,6 | 8,7 / 13,3 | 0,6 % |
  | Ricerca «notte» | 3,8 / **51,6** | 12,8 / 24,7 | **9,8 %** |

  Avvio a freddo: mediana 2363 ms. Da `main` al primo frame: 673 ms. PSS 201 MB.
  Gli scenari del player non sono stati misurati: `perf_device.py --playback` si ferma su `tap('^Tutti i brani')` dopo la ricerca (riga 226), perché la navigazione è cambiata con Anello. Va sistemato nella fase della rete di sicurezza.
- **Mai misurati:** fogli e transizioni di pagina (apri e torna indietro). Sono proprio i punti di cui l'utente si lamenta.
- **Rispetto alla fase 28:** Tutti i brani è passato da 0,3 % a 1,4 %, la ricerca da 2,3 % a 9,8 %, il cambio di scheda è al 4,6 % → **F-45**.
- **Desktop:** nessuna misura. `integration_test/perf_test.dart:67` fallisce su Linux, perché cerca l'etichetta «Libreria» della shell del telefono (log del 2026-10-23).
- **Come misurare (telefono, build profile, app separata `com.codecore.player.perf`):**
  - Preparazione: `python3 scripts/perf_library.py`.
  - Misura: `python3 scripts/perf_device.py <adb-id> --label <nome> --playback [--no-push]`; il risultato va in `build/perf/<label>.md`.
  - Scenari che ci sono già: «In riproduzione», «Lettore dal dock», «Anello», «Tutti i brani», «Album», «Ricerca», «Pallino schede».
  - **Scenari che mancano:** apri album/artista e torna indietro ×3; apri e chiudi i fogli coda, dispositivi e tag ×3; swipe sul mini player ×3.

Formato dei rilievi: `F-NN · area · titolo · dove · prova · danno · impatto/rischio/costo · proposta`. Gli ID non si riusano. Le voci «non verificato» aspettano la misura sul telefono.

## Rilievi in ordine di priorità

### Priorità 1 — impatto alto
- **F-40** · animazioni · Ogni apertura e chiusura di pagina sfuma tutta la pagina di destinazione · `lib/ui/theme/app_theme.dart:13-33,100` (`CcPageTransitionsBuilder` → `FadeUpwardsPageTransitionsBuilder` per tutte le piattaforme) · FadeTransition+Slide = un layer fuori schermo grande quanto la pagina per tutta la transizione · scatti aprendo album/artista e col tasto indietro sui telefoni; sul desktop costa poco, in linea col fatto che lì non è segnalato · A/M/S · transizione senza opacità (solo scorrimento o zoom), confronto prima/dopo
- **F-60** · accessibilità · Le impostazioni dell'app sostituiscono quelle del sistema per animazioni e dimensione del testo · `lib/app.dart:70-72`; `reducedMotion` è falso di default (`settings_store.dart:290`) e i flag del sistema non vengono letti da nessuna parte · chi ha attivato «rimuovi animazioni» o un testo grande in Android o Windows non lo ottiene · A/B/S · `s.reducedMotion || MediaQuery.disableAnimationsOf(context)`; scala del testo = sistema × app
- **F-41** · animazioni · Apertura e chiusura del player: quattro effetti insieme per 550 ms · `lib/ui/widgets/grow_route.dart:28-32`, `mini_player.dart:168`, `now_playing_screen.dart:340-346` · ClipRRect ritagliato a ogni frame, FadeTransition sull'intera pagina, volo Hero della copertina, copertina che ruota; inoltre il primo frame costruisce tutta NowPlaying (non verificato) · è il momento 1 lamentato dall'utente · A/M/M · togliere la sfumatura, costruire le card dopo la fine della transizione, niente rotazione durante il volo. *(Include l'ex F-34.)*
- **F-30** · animazioni · Testi sincronizzati: una Opacity per riga e un setState su tutta la lista a ogni riga · `lib/ui/screens/lyrics/lyrics_view.dart:54-62,132-160` · con 60–100 righe: 100 saveLayer per frame; l'evidenziazione salta di colpo mentre lo scroll anima per 300 ms · pagina testi e pannello del desktop · A/M/M · `ListView.builder`, colore animato al posto di Opacity, si ricostruiscono solo la riga vecchia e quella nuova
- **F-01** · struttura · Manca un helper per gli snackbar: ogni schermata se lo costruisce da sé · `SnackBar(` compare 106 volte in 62 file, con funzioni `say()` locali copiate (es. `backup_section.dart:79`, `duplicates_screen.dart:22`, `radio_actions.dart:41`) · per cambiare stile o durata, o per gestire bene il `context` dopo un `await`, bisogna toccare 62 file · A/B/M · un solo `showMsg(context, text)` in `widgets/`
- **F-02** · struttura · La UI scavalca i provider e parla con repository e DB · 58 file UI importano `app_database.dart`; `ref.read(trackRepositoryProvider)` ×14, `playlistRepositoryProvider` ×11, `tagRepositoryProvider` ×6, `databaseProvider` ×7 (es. `bulk_actions.dart:64,85,106`, `tags_sheet.dart:74`) · `docs/02-architettura.md` dice UI → provider → servizi → dati; un cambio di schema o di firma arriva fino ai widget · A/M/L · un provider `TrackOps` per le azioni sui brani (in blocco, preferiti, tag); i widget chiamano solo quello

- **F-45** · prestazioni · Regressione misurata rispetto alla fase 28: ricerca e cambio di scheda · Mi A3, `build/perf/refactor-prima-mia3.md` · Ricerca «notte»: build p99 51,6 ms, 9,8 % di frame persi (era 2,3 %); Pallino schede 4,6 %; Tutti i brani 1,4 % (era 0,3 %) · la ricerca e il cambio di scheda scattano a ogni uso · A/M/M · profilare la ricerca (risultati ricostruiti a ogni tasto?) e il cambio di scheda (F-44), con lo stesso scenario prima e dopo

### Priorità 2 — impatto medio, costo basso
- **F-42** · prestazioni · Lo swipe sul mini player lo ricostruisce tutto a ogni frame · `lib/ui/widgets/mini_player.dart:41-44` (`setState(() => _dx = …)`), con 5 provider osservati in `:112-140` · scatti nello swipe avanti/indietro · M/B/S · `AnimatedBuilder` + `Transform.translate` su un figlio costruito una volta
- **F-31** · prestazioni · Trascinando giù NowPlaying si fa un setState di tutta la schermata a ogni movimento · `now_playing_screen.dart:~60-70,88-110` · la chiusura a swipe può scattare (non verificato) · M/B/S · `ValueNotifier` + `Transform`
- **F-33** · animazioni · La copertina ruota di continuo a 60 fps mentre suona · `lib/ui/widgets/motion.dart:303,347`, usata in `now_playing_screen.dart:340` · la pagina non è mai ferma: batteria, calore e ogni intoppo si vede; l'Hero atterra su una copertina ruotata (non verificato) · M/B/S · rotazione disattivabile, ferma durante il volo
- **F-44** · animazioni · Il cambio di scheda sfuma tutto il corpo della pagina · `lib/ui/widgets/motion.dart:166-190` (`TabFade`) · un layer fuori schermo per tutta la pagina a ogni scheda · M/B/S · confronto con la sfumatura tolta (scenario «Pallino schede»)
- **F-35** · animazioni · Lo stesso tag Hero `'player-cover'` è usato da 3 widget · `mini_player.dart:22,168`, `desktop_player_bar.dart:123`, `now_playing_screen.dart:346` · se mini player e barra del desktop sono insieme nell'albero, il volo si rompe (non verificato) · M/B/S · controllare la shell; tag separati
- **F-03** · struttura · Query drift scritte dentro i widget · `lyrics_view.dart:107-113`, `export_dialog.dart:113-124,148-150`, `now_playing_cards.dart:176`, `tag_backups_screen.dart:43` · duplicano `TrackRepository` (`track_repository.dart:111` scrive già lyricsPlain); così non si testano senza un widget · M/M/S · `TrackRepository.setLyrics`, `FolderRepository.pathsById`
- **F-06** · struttura · Il dialogo «scegli un nome» è ripetuto 6 volte · `playlist_dialogs.dart:66`, `tags_screen.dart:38`, `tags_sheet.dart:196,287`, `desktop_sidebar.dart:220`, `playlist_picker.dart:32`, `playlists_screen.dart:38` · le regole di validazione sono copiate e una correzione arriva solo ad alcune copie · M/B/S · `promptName()` in `widgets/`
- **F-09** · struttura · Il cablaggio della selezione è ripetuto nelle pagine online · `online_page_frame.dart:119-133`, `online_results.dart:191-193`, `online_results_sections.dart:165` · M/B/S · un `OnlineSelectionScope`
- **F-70** · accessibilità · Bersagli più piccoli di 48 dp · `mini_player.dart:286` (compact, 40 dp), `app_theme.dart:106` (compact globale), `online_queue_row.dart:117`, `duplicate_member_row.dart:124`, `jam_parts.dart:203`, `radio_now.dart:75`, `peer_card.dart:96,105` (36), `alpha_scroller.dart:67` (28 dp) · si sbagliano play, avanti e «altro» nel mini player · M/B/S · compact solo con il puntatore del desktop
- **F-71** · accessibilità · Widget a gesti senza etichetta e senza tastiera · `mini_player.dart:242`, `desktop_player_bar.dart:112`, `album_card.dart:43`, `preview_cover.dart:26` (anteprima solo con pressione lunga) · con TalkBack o con la sola tastiera non si apre il player dal mini player o dalla barra · M/B/S · `InkWell` + `Semantics(button, label)` + un'azione di accessibilità per l'anteprima
- **F-74** · accessibilità · Il focus da tastiera si vede appena · `app_theme.dart:97` (`focusColor` accento al 24 %), 0 `FocusTraversalGroup` · M/B/S · alfa a circa 0,4 e un contorno sui tasti principali
- **F-61** · accessibilità · `textFaint` usato come testo sta sotto 4,5:1 · `tokens.dart:44,68` (scuro 3,74→2,79; chiaro 3,43→2,46 da bg a s3) · M/B/S · schiarire o scurire fino a ≥ 4,5 su s1
- **F-62** · accessibilità · Accento ed errore su surface3 sotto 4,5:1 · `palette.dart:40-47`, `tokens.dart:62,64` (chiaro: 3,46–4,02, tranne viola) · M/B/S · `accentSoft` come testo su s2/s3

### Priorità 3 — impatto medio, costo medio
- **F-43** · prestazioni · Fogli con liste non pigre · `tags_sheet.dart:218,277`, `activity_sheet.dart:183`, `devices_sheet.dart:126`, `artist_picker_sheet.dart:113` (`ListView(shrinkWrap: true)`), `queue_sheet.dart:170` (ReorderableListView ricostruita a ogni evento della coda) · i primi frame dello scorrimento di 250 ms si perdono · M/B/M · `ListView.builder` senza shrinkWrap
- **F-05** · struttura · Metodi build enormi · `library_screen.dart:86` (271 righe), `desktop_sidebar.dart:26` (253), `app_shell.dart:98` (250), `playlist_detail_screen.dart:83` (235), `review_screen.dart:131` (213), `now_playing_screen.dart:226` (200), `jam_screen.dart:68` (191); 14 build superano le 150 righe · aggiungere uno stato vuol dire toccare 270 righe · M/M/M · 3–4 widget privati per sezione
- **F-12** · struttura · Tre sistemi di intestazione · `AppBar(` diretto in 48 file, `CollectionHeader` in 2 · ogni schermata nuova riparte dal vecchio aspetto · M/B/M · `CcAppBar` in `widgets/`
- **F-13** · struttura · Stati di caricamento, vuoto ed errore fatti a mano · 32 `CircularProgressIndicator`, 19 lineari, solo 14 `.when(`, 1 `error_state` · M/B/M · un wrapper `AsyncBody<T>`
- **F-08** · struttura · La selezione è fatta in 3 modi · `Set<int>` locali in `add_tracks_screen.dart:25`, `track_picker_screen.dart:22`, `receive_tab.dart:36`, contro `selectionProvider` · «seleziona tutto» si comporta in modo diverso a seconda della schermata · M/M/M · tutto su `selectionProvider`
- **F-15** · struttura · Logica di business nello State · `now_playing_cards.dart:170-215` (curiosità: pulizia della query, limite di richieste, scrittura nel DB), `receive_tab` (13 setState), `search_screen` (9), `import_preview_dialog` (8) · errori di ciclo di vita e di `mounted`, codice non testabile · M/M/M · AsyncNotifier per le curiosità
- **F-16** · struttura · Le azioni sul brano si biforcano su `isOnlineId(track.id)` · `track_actions.dart:66,107,143`, `online_queue_row.dart:60,118`, `track_row.dart:486`, `memory_screen.dart:457` · un tipo nuovo di brano (episodio) richiede modifiche in tutti questi punti · M/M/M · un `kind` tipizzato
- **F-63** · accessibilità · Un tema personalizzato può dare testo illeggibile · `custom_theme.dart` `resolve` (~169-191) e `fromJson` (:313) non controllano il contrasto; `ensureContrast` c'è solo nell'editor · con bg #808080: muted 2,79, faint 1,86 · M/M/M · in `resolve()` far passare text/muted/faint da `ensureContrast`
- **F-64** · design · Due scale di movimento più valori letterali · `tokens.dart:128-131` (`CcMotion` 150/250/400) contro `motion.dart:10-20` (`Motion` 120/180/160/220/420), più letterali 180/300/450/550/160/200: circa 12 durate · l'app «si muove» in modo disomogeneo · B/B/M · una sola scala (pressione 120, entrata 180, foglio 250, hero 450). *(Include l'ex F-17 per le durate.)*
- **F-73** · accessibilità · Scala del testo senza tetto e mai provata al 200 % · `app.dart:72`, `mini_player.dart:144` (56 dp), `car_mode_screen.dart:59` · possibile overflow (non verificato) · M/M/M · golden a textScale 2,0 per mini player, barra in basso e modalità auto

### Priorità 4 — impatto basso
- **F-32** · prestazioni · Il tick della posizione ricostruisce tutta la riga seek · `now_playing_controls.dart:47`, `desktop_player_bar.dart:342` · B/B/S · Consumer solo su Slider e tempo
- **F-36** · animazioni · Animazioni di layout e implicite per riga · `now_playing_cards.dart:417`, `theme_editor_screen.dart:294`, `track_row_selection.dart:40-54`, `cover_backdrop.dart:29` (gradiente sul 60 % dello schermo) · B/B/S · backdrop con TweenAnimationBuilder dentro RepaintBoundary
- **F-65** · accessibilità · `AnimatedSize` 200 ms ignora il movimento ridotto · `now_playing_cards.dart:418` · B/B/S · `ccDuration`
- **F-66** · design · Curve miste (easeOutCubic, easeOut ×6, easeInOut) · B/B/S · `Motion.curve`
- **F-67** · design · 27 `TextStyle(` e 16 `fontSize:` fuori dal tema; 11 px sotto il minimo di 12 (`bottom_bar.dart:247`, `now_playing_screen.dart:273`, `stats_charts.dart:36`) · B/B/M · stili nel TextTheme
- **F-68** · design · Nessuna scala di spaziature in `CcDims` (305 EdgeInsets liberi, 4 raggi letterali) · B/B/S · costanti `gap*`. *(Include l'ex F-17 per spaziature e colori.)*
- **F-69** · design · Token duplicati: `oled` è uguale a `notte` in 11 campi su 12 · `tokens.dart:34-47` · B/B/S · `notte.copyWith(bg: black)`
- **F-72** · accessibilità · Per le copertine non è stato deciso cosa dice il lettore di schermo · `cover_image.dart:87` · B/B/S · `excludeFromSemantics: true` di default
- **F-07** · struttura · Il flusso «aggiungi cartella» è scritto due volte e le due copie già divergono (dall'onboarding non parte la scansione) · `onboarding_pages.dart:93-103` contro `folders_sheet.dart:22-33` · B/B/S · un solo flusso (il comportamento dell'onboarding va deciso)
- **F-10** · struttura · Le chiavi di selezione sono stringhe nude (`'online'`, `'hidden'`, `'review'`, …) · B/M/S · enum
- **F-11** · struttura · Menu con `PopupMenuButton<String>` ×10 e 23 `case '...'` · un nome sbagliato compila e non fa niente · B/M/M · un enum per menu, come `TrackAction`
- **F-14** · struttura · Finestre miste (showDialog ×40, showCcSheet ×25, un `showModalBottomSheet` crudo) · B/B/S · una regola più una chiamata spostata
- **F-04** · struttura · L'import del vecchio DB Python sta nella UI delle impostazioni · `settings_pages.dart:436` · B/B/S · da togliere se non serve più, altrimenti da spostare in un servizio
- **F-18** · struttura · 8 catch tipizzati senza `AppLog` (l'errore però si mostra all'utente) · B/B/S · `AppLog.w`
- **F-19** · struttura · `radio_sections.dart:142`: il future di `reorder(ids)` viene ignorato · B/B/S · await + messaggio d'errore
- **F-37, F-38, F-39** · prestazioni · Opacity 0/1 nelle righe, Home non pigra, griglie senza itemExtent · costo trascurabile o solo con librerie enormi · nessuna azione per ora (elencati per non ricontrollarli)

## Sintesi per area
- **Animazioni e prestazioni:** le liste sono già a posto (fase 28). Gli scatti stanno nei layer di opacità a tutta pagina (transizioni di pagina, schede, apertura del player) e nei setState a ogni frame (swipe del mini player e del player, testi). Tutto si spiega col fatto che il telefono soffre e il desktop no, ma va confermato con `perf_device.py` prima e dopo.
- **Struttura:** codice morto praticamente zero, nessun catch muto. Il costo di aggiungere funzioni viene dai mattoni condivisi che mancano (snackbar, dialogo del nome, intestazione, selezione, corpo asincrono) e dai widget che scavalcano i provider.
- **Design:** i token sono rispettati bene (0 colori esadecimali fuori dal selettore). I punti deboli sono due scale di movimento con circa 12 durate e alcuni testi a 11 px.
- **Accessibilità:** il contrasto principale va bene. Sono deboli `textFaint`, l'accento su s3 e i temi personalizzati. Il buco più grande sono i flag del sistema ignorati (F-60); poi vengono i bersagli piccoli e i gesti non raggiungibili.
- **Codice morto e peso** (fastidio dell'utente): la scansione non ne ha trovato in `lib/ui`; c'è solo forse F-04, 50–100 righe. Non sono state verificate le chiavi l10n inutilizzate né i metodi morti dentro classi vive.

## Scelte (giro 2, 2026-10-23)
- **Si affrontano:** tutti i rilievi, salvo F-37, F-38 e F-39 (nessuna azione: costo trascurabile, fase 28). F-04 si toglie (D-04). Gli ex F-17 e F-34 sono confluiti in F-64/F-68 e in F-41. Rimandati: nessuno. Scartati: F-37, F-38, F-39.
- **Traguardo e ordine:** prima la fluidità sul telefono, poi l'accessibilità, poi la struttura (D-09). Si lavora per parti, una PR piccola per passo (D-06).
- **Intoccabili (D-07):**
  - dati salvati (schema del DB, chiavi delle impostazioni, file di tema e di backup);
  - nessun pacchetto nuovo;
  - protocolli LAN, Jam e sync compatibili con gli APK già installati.
- **Aspetto (D-08):** l'identità «Anello» va rimarcata senza esagerare e resa accattivante nella semplicità, con pochi effetti costosi (sfumature, gradienti, blur). Non va copiata la struttura né la UI di Spotify. Layout e forme cambiano solo con un mockup approvato.
- **Cambi di comportamento voluti:**
  - sparisce l'import dal vecchio DB Python (D-04);
  - la copertina che ruota diventa un'opzione, spenta di default (D-11);
  - l'onboarding avvia la scansione (D-12);
  - valgono le opzioni di sistema per animazioni e testo (D-14);
  - contrasto corretto (D-17).
- **Soluzioni scelte:**
  - F-40: la transizione la decide la misura (D-10);
  - F-41: via la sfumatura (D-18);
  - F-63: solo un avviso (D-13);
  - F-70: bersagli di 48 dp sul telefono (D-15);
  - F-72: copertine decorative escluse dalla semantica (D-16).
- **Vincoli:**
  - le misure si fanno solo con l'app perf (D-19);
  - i golden si rigenerano solo per cambi di aspetto voluti (D-20).

## Arrivo — UI (giro 3)
Direzione (D-21): base «Anello vivo», player come «Disco», liste come «Quaderno»; superfici piatte, nessun gradiente.
- **L'anello** è l'unico segno grafico e porta lo stato: player (12 dp, è anche il seek), mini player (3 dp), riga del brano in riproduzione (2 dp attorno alla miniatura), «Riprendi». Non va su bottoni, schede, sfondi né titoli.
- **Token** (D-23, file di riferimento `mockup/tokens.css`):
  - colori come oggi, con queste differenze: textFaint #887F99 (scuro) e #6D6280 (chiaro), accento su s2/s3 → accentSoft, oled = notte con bg nero;
  - Unbounded solo per l'invito della Home (28) e i titoli (20); Figtree 15/13/12, con minimo 12;
  - spaziature 4/8/12/16/24/32; raggi 4/8/12/16/28; niente ombre; separatori 1 dp in s2;
  - movimento: 120/180/250/320 ms, easeOutCubic in entrata ed easeInCubic in uscita, solo transform e scale.
- **Da tenere:** il dock unico con il pallino, la ricerca che nasce dalla barra, i 3 temi × 8 accenti, la Home con un grande invito.
- **Mockup** (D-22): In riproduzione, Home, Libreria, Album/artista e Onboarding, in `mockup/`. I mockup approvati sono la specifica visiva di `/obiettivo`.
  - **Approvati il 2026-10-23** (D-25..D-28). Filtri e scorciatoie della Libreria sono blocchi piatti e simmetrici, senza icone; sul telefono le scorciatoie stanno in una griglia a 2 colonne (il nono blocco occupa tutta la riga), sul desktop in una riga da 9. Niente strisce che scorrono di lato. C'è un solo dock (mini player + 4 schede), uguale in tutte le schermate.

## Arrivo — struttura (giro 3, approvata il 2026-10-23, D-24)
La regola dei livelli c'è già (`docs/02-architettura.md`: ui → providers → services/data → core). Il refactor la rende vera e la fa controllare a un test.

| Oggi | Dopo | Rilievi |
|---|---|---|
| 58 file UI usano `databaseProvider` / `*RepositoryProvider`; query drift nei widget | lib/ui legge e scrive **solo tramite provider**; i tipi drift (`Track`, …) restano importabili; `TrackOps` in `lib/providers/` raccoglie le azioni sui brani: in blocco, preferiti, tag, testi (`setLyrics`); `FolderRepository.pathsById`. Un test (`test/ui/architecture_test.dart`) fallisce se in lib/ui compare `databaseProvider` o `RepositoryProvider` | F-02, F-03 |
| 106 SnackBar a mano, 6 dialoghi «nome», 48 AppBar, stati asincroni a mano, un `showModalBottomSheet` crudo | mattoni in `lib/ui/widgets/`: `showMsg`, `promptName`, `CcAppBar`, `AsyncBody<T>`; tutti i fogli passano da `showCcSheet`; regola: dialogo per il testo, foglio per le scelte | F-01, F-06, F-12, F-13, F-14 |
| Selezione in 3 modi, chiavi stringa, menu `<String>`, biforcazione su `isOnlineId` | solo `selectionProvider` con `enum SelectionKey`; un enum per ogni menu (come `TrackAction`); getter `track.kind` calcolato dall'id (lo schema non cambia, D-07); un `OnlineSelectionScope` | F-08, F-09, F-10, F-11, F-16 |
| `CcMotion` e `Motion`, ~12 durate, curve miste; `FadeUpwards` per tutte le pagine; `TabFade` | una sola scala in `tokens.dart` (D-23), `Motion` da motion.dart tolta; transizioni in `app_theme.dart` senza opacità (D-10) | F-64, F-66, F-40, F-44 |
| build da 190–271 righe; logica delle curiosità nello State | widget privati per sezione (nello stesso file o in `parts/`); `curiosityProvider` (AsyncNotifier) | F-05, F-15 |
| Flusso «aggiungi cartella» doppio; import Python nella UI | `addFolderAndScan` in un servizio, usato anche dall'onboarding (D-12); importer tolto (D-04) | F-07, F-04 |

**Percorso a piccoli passi (strangler):**
1. Si crea il mattone nuovo con il suo test, mentre il vecchio resta.
2. Si migrano i file a gruppi (una cartella di `screens/` per commit); dopo ogni gruppo `flutter analyze` e i test toccati verdi.
3. Quando l'ultimo uso del vecchio sparisce, si toglie il vecchio.
4. Per F-02, il test di architettura parte con una lista di eccezioni che si svuota gruppo dopo gruppo, finché la lista è vuota.

Nessuna schermata si riscrive da zero (D-06).

## Rete (giro 4, approvata il 2026-10-23, D-29)
Test già presenti sulle parti toccate: motion, now_playing (grow, reduce motion), app_shell, ring_progress, lyrics_screen, queue_reorder, large_text, anello_text_scale, selezione (4 file), track_actions, onboarding, contrast_test, font_scale, golden `screens_golden_test`.

**Test di caratterizzazione, da scrivere prima di toccare il codice** (fissano il comportamento di oggi, difetti noti compresi):
- **A — transizioni** (`transitions_characterization_test`):
  - push e pop di oggi, con lo stato che resta;
  - TabFade, con lo stato delle schede;
  - swipe del mini player: soglia, ritorno, tap che apre il player;
  - trascinamento che chiude il player;
  - numero di Hero `player-cover` su telefono e desktop.
- **B — liste e fogli:**
  - LyricsView sincronizzato: riga giusta che cambia con la posizione, tap che porta al punto (seek), scorrimento automatico; si fissa anche il salto, che è un difetto noto;
  - con 100 righe non vengono costruite tutte (dopo F-30);
  - QueueSheet: tap, rimozione, brano corrente;
  - fogli tag, attività e dispositivi con 30 voci su 360×640.
- **C — azioni:**
  - `showMsg`: durata, un messaggio alla volta, smontaggio dopo await;
  - azioni su più brani e preferiti contro un DB in memoria, poi su `TrackOps`;
  - `setLyrics` e `pathsById`;
  - `architecture_test`, con la lista di eccezioni;
  - le 6 copie del dialogo del nome: regole a confronto;
  - selezione di add_tracks, track_picker e receive_tab;
  - un test per ognuno dei 9 `PopupMenuButton<String>`;
  - tabella id→kind e `AsyncBody`;
  - `folders_sheet` e onboarding (poi D-12).
- **D — accessibilità:**
  - flag di sistema ignorati (poi D-14);
  - `a11y_guidelines_test` (androidTapTarget, labeledTapTarget, textContrast) con lista di eccezioni;
  - mini player, dock e car mode al 200 %;
  - `contrast_test` esteso a textFaint e accentSoft.
- **E — golden nuovi:** Home desktop, mini player + dock, car mode a 100 e 200 %.

**Metriche di arrivo:**
- Mi A3, solo app perf separata (D-19), comando `scripts/perf_device.py`. Prima vanno sistemati `perf_device.py:226` e `integration_test/perf_test.dart:67`, e vanno aggiunti gli scenari nuovi.

| Metrica | Soglia | Oggi |
|---|---|---|
| Pallino schede, frame > 16,7 ms | ≤ 2 % | 4,6 % |
| Tutti i brani | ≤ 1 % | 1,4 % |
| Album | ≤ 0,6 % | 0,6 % |
| Ricerca «notte» | ≤ 3 %, build p99 ≤ 16 ms | 9,8 %, 51,6 ms |
| Apri album / torna | ≤ 3 % | da misurare |
| Fogli | ≤ 3 % | da misurare |
| Swipe del mini player | ≤ 2 % | da misurare |
| Apertura del player | ≤ 3 %, p99 ≤ 33 ms | 40,8 ms (22/10) |
| Avvio a freddo | ≤ 2400 ms | 2363 ms |
| PSS | ≤ 210 MB | 201 MB |

- Struttura (grep su `lib/ui`), da misurare con `scripts/build_len.py` (da scrivere):

| Cosa | Soglia | Oggi |
|---|---|---|
| `databaseProvider\|RepositoryProvider` | 0 | 74 righe / 44 file |
| `SnackBar(` | 1 | 106 |
| `AppBar(` | 1 | 48 |
| `Duration(milliseconds` | ≤ 3, solo nei token | 28 |
| `build` per widget | ≤ 120 righe, 0 oltre 150 | — |

**Comportamento invariato** vuol dire:
- la CI resta verde;
- `lib/data`, provider, servizi, Jam e l10n non cambiano;
- i golden restano identici, salvo nei passi di redesign o dei token (D-20);
- `integration_test` gira prima e dopo il gruppo C e alla chiusura.

## Risultati

Chiusura della fase 44, 24/10. Numeri completi in `misure.md`, sezione «Finale».

### Stato dei rilievi
Fase 39 (bf4656d, #7):
- F-40 fatto, 39.1 (scorrimento laterale, D-45/D-46) · F-41 fatto, 39.2 · F-44 fatto, 39.3 · F-42 fatto, 39.4
- F-31 fatto, 39.5 · F-33 fatto, 39.6 · F-35 fatto, 39.7 · F-30 fatto, 39.8 · F-43 fatto, 39.9 (D-43)
- F-45 fatto, 39.10 (soglie non raggiunte, vedi sotto) · F-32 fatto, 39.11 · F-36 fatto, 39.12
- F-65 fatto, 39.13 · F-64 fatto, 39.14 (D-44) · F-66 fatto, 39.15

Fase 40 (5cd2538, #8):
- F-60 fatto, 40.1 · F-61 fatto, 40.2 · F-62 fatto, 40.3 · F-63 fatto, 40.4 (solo avviso)
- F-70 fatto, 40.5 · F-71 fatto, 40.6 · F-74 fatto, 40.7 · F-72 fatto, 40.8
- F-73 fatto, 40.9 · F-67 fatto, 40.10 · F-68 fatto, 40.11 · F-69 fatto, 40.12

Fase 41 (96e7f2e, #9):
- F-01 fatto, 41.1 · F-06 fatto, 41.2 · F-12 fatto, 41.3 · F-13 fatto, 41.4 (con eccezioni in D-50/D-52)
- F-14 fatto, 41.5 · F-18 fatto, 41.6 · F-19 fatto, 41.7

Fase 42 (ffdf9fd, #10):
- F-02 e F-03 fatti, 42.1 · F-08 fatto, 42.2 · F-10 fatto, 42.3 · F-09 fatto, 42.4 · F-11 fatto, 42.5
- F-16 fatto, 42.6 · F-15 fatto, 42.7 · F-05 fatto, 42.8 · F-07 fatto, 42.9 · F-04 fatto, 42.10

Fase 43 (a296a08, #11): nuovo aspetto (D-21..D-28), nessun F-NN proprio; chiude le voci di D-52 rimandate (`loadErrorState`, variante sliver di `AsyncBody`).

Altri:
- F-37, F-38, F-39: nessuna azione (costo trascurabile, scartati nel giro 2).
- Ex F-17 e F-34: confluiti in F-64/F-68 e in F-41.

### Prima e dopo
Dettaglio in `misure.md`, «Finale».

| Misura | Prima (fase 38) | Finale | Soglia |
|---|---|---|---|
| Pallino schede | 5,8 % | 4,3 % | ≤ 2 % |
| Ricerca «notte» | 3,5 %, p99 57,4 ms | 4,5 %, p99 35,0 ms | ≤ 3 %, p99 ≤ 16 ms |
| Swipe mini player | 8,7 % | 8,1 % | ≤ 2 % |
| Apertura player | 9,5 %, p99 116,0 ms | 7,4 %, p99 113,8 ms | ≤ 3 %, p99 ≤ 33 ms |
| Avvio a freddo | 2575 ms | 2500 ms | ≤ 2400 ms |
| `databaseProvider\|RepositoryProvider` in `lib/ui` | 74 righe / 44 file | 0 | 0 |

### Cambi di comportamento avvenuti
- D-04: tolto l'import dal vecchio DB Python (pulsante, importer, test, stringhe).
- D-11: la copertina che ruota è un'opzione, spenta di default; ferma durante il volo Hero e con «riduci animazioni».
- D-12: l'onboarding avvia la scansione dopo «aggiungi cartella».
- D-13: tema personalizzato poco leggibile: solo avviso (editor e import), nessuna correzione automatica.
- D-14: animazioni ridotte se lo chiede l'app o il sistema; scala del testo = sistema × app.
- D-15: bersagli ≥ 48 dp sul telefono; compatto solo su desktop (D-48: per piattaforma).
- D-16: copertine decorative escluse dalla semantica; etichetta solo dove sono l'unico contenuto.
- D-17: `textFaint` e accento come testo su s2/s3 corretti a ≥ 4,5:1 (piccolo cambio di aspetto, golden rigenerati).

### Soglie non raggiunte
- Pallino schede (4,3 %), Apri album (7,9 %), Swipe (8,1 %), Apertura player (7,4 %, p99 113,8 ms), Ricerca (4,5 %, p99 35,0 ms): tutte con picchi nei frame di build (cambio di brano, prima apertura di una scheda, `smartSearch` sincrono).
- Album (0,8 % contro 0,6 %) è a un frame dalla soglia; avvio (2500 ms) e PSS (270 MB) restano sopra, come già prima del refactor.
- Annotate secondo D-37/D-41; la fase 44 non cambia codice di prodotto. Tocca all'utente accettarle o aprire un seguito. Dettaglio in `misure.md`.
