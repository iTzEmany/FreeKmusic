# Refactor «ui-uso-quotidiano» — analisi

Perimetro (richiesta dell'utente del 2026-11-03, elenco alla rinfusa dall'uso quotidiano): Home (scorciatoie e righe), Cerca, Libreria (cambio scheda e ricerca interna), Radio (generi), Statistiche, stato «nessun brano in riproduzione», schede dei brani in streaming, coda di Shuffle+, Tutti i brani, Registro attività, «Da revisionare», «Da confermare». Tipo: **ui**, con tre difetti di comportamento (lag di Libreria, mese delle Statistiche, «Accetta tutte»). Stile di base: quello approvato in `docs/refactor/ui-fluida/` (`mockup/tokens.css`, `lib/ui/theme/tokens.dart`).

## Richieste dell'utente → rilievi
| # | Richiesta | Rilievi |
|---|---|---|
| U1 | Home: Preferiti/Playlist/Radio in riquadri con sfondo, non separati da linee | F-01, F-02, F-18 |
| U2 | Cerca: niente tastiera all'apertura | F-03 (= F-70) |
| U3 | ✕ sempre visibile: svuota, se vuota chiude la tastiera | F-04, F-09 |
| U4 | Cerca: via Preferiti e Recenti, generi in griglia da 3 | F-05, F-06, F-28 |
| U5 | Libreria: lag cambiando scheda | F-60, F-61, F-63 |
| U6 | Radio: generi in griglia da 4 | F-10, F-28 |
| U7 | Statistiche: tocco su una barra → ore del giorno/mese | F-11, F-12 |
| U8 | Statistiche: Anno → Mese riparte da gennaio | F-64 |
| U9 | Mockup «nessun brano in riproduzione» | F-47, F-48 |
| U10 | Cerca solo online; ricerca in libreria dentro Libreria con la lente che diventa barra | F-07, F-08, F-09, F-27 |
| U11 | Skeleton ovunque ci siano caricamenti pesanti | F-51, F-63, F-65, F-66, F-67, F-68 |
| U12 | Skeleton delle schede testo/curiosità/crediti in streaming | F-49, F-50, F-52 |
| U13 | Skeleton dei suggeriti di Shuffle+ in arrivo | F-53, F-54, F-55 |
| U14 | Tutti i brani: icone Play/Shuffle a destra del titolo, ricerca e filtri che si nascondono scorrendo giù, titolo che scorre via | F-13, F-14, F-15, F-16 |
| U15 | Registro attività meno tecnico e più ordinato | F-30…F-38, F-56, F-58 |
| U16 | «Da revisionare» ridisegnato | F-43…F-46 |
| U17 | «Accetta tutte» in un colpo | F-40, F-41, F-42, F-71 |

## Misure di partenza
- Scatti: `scripts/shots.sh` → `test_shots/goldens/` (phone/desktop: library, stats, all_tracks_selection, now_playing, shell_playing…). Mancano scatti di Cerca, Radio, Registro attività, Da revisionare, Da confermare e del player vuoto.
- Velocità: `integration_test/perf_test.dart` (tour con 3000 brani, `lib/core/frame_stats.dart`; `flutter test integration_test/perf_test.dart -d linux` solo per confronto relativo) e `python3 scripts/perf_device.py 0d7ae9df206e --label X --playback` sul telefono (profile). Soglie in `docs/refactor/ui-fluida/misure.md`. **Il tour non passa per le schede della Libreria**: va aggiunto lo scenario Tutto→Playlist→Album→Artisti prima di toccare F-60. Rotture note dei due script: `perf_device.py:226`, `perf_test.dart:67` (fase 38).
- Nessuna misura eseguita in questo giro: i rilievi vengono dalla lettura del codice.

## Rilievi in ordine di priorità
Priorità 1 (impatto alto, costo basso o medio): F-64, F-03, F-04, F-60, F-61, F-40/F-71, F-01, F-06, F-10, F-14, F-49, F-66/F-67.
Priorità 2: F-13, F-15, F-11, F-12, F-30, F-31, F-33, F-39, F-43, F-47, F-53, F-55, F-08, F-09, F-63, F-65, F-35.
Priorità 3: F-02, F-05, F-16, F-17, F-18…F-29, F-32, F-34, F-36…F-38, F-42, F-44…F-46, F-48, F-51, F-52, F-54, F-56…F-59, F-68, F-72, F-73.
Rischio più alto: F-07 (Cerca solo online, cambia il prodotto; con `kEnableYoutube` falso Cerca resterebbe vuota), F-40 (scritture dei tag su file).

## Sintesi per area
- **Home, Cerca, Radio:** lavori piccoli e di sola UI. La tastiera nasce da `focusOnShow = true` nel provider del dock; la ✕ sparisce a campo vuoto. Esistono tre campi di ricerca quasi uguali: conviene un solo `CcSearchField`, da usare anche in Libreria e Tutti i brani.
- **Libreria e Tutti i brani:** il lag viene dal ricalcolo sincrono di `buildLibraryEntries` (ordinamento con `normalize` a ogni confronto) a ogni cambio scheda, non dalle liste, che sono già lazy. In Tutti i brani header, ricerca e filtri sono fissi (~250 dp): vanno nascosti in base alla direzione dello scroll senza passare agli sliver (`AlphaScroller` dipende da indice×altezza).
- **Statistiche:** il bug del mese è una riga (`_setYear` usa l'inizio del periodo, che per l'anno è il 1° gennaio). Le barre sono un unico `CustomPaint` senza tocco: con 31 barre ogni colonna è larga ~10 dp, quindi la selezione va fatta per posizione orizzontale.
- **Caricamenti:** `AsyncBody` mostra di serie uno spinner (8 usi) e `PageSkeleton` è statico e quasi invisibile. Basta un widget `Skeleton` condiviso, usato di serie da `AsyncBody`, per coprire buona parte delle schermate.
- **Player:** a coda finita il mini player sparisce e il dock salta. Le schede in streaming mostrano 480 dp di testo e poi saltano. Shuffle+ non espone lo stato «in preparazione», quindi va aggiunto un provider prima di poter mostrare lo skeleton.
- **Registro, Da revisionare, Da confermare:** lista piatta senza giorni né filtri, frasi tecniche, 5 icone per 12 tipi. «Accetta tutte» fa una transazione e una scrittura su file per ogni brano, e lo stream riemette N volte.

## Rilievi (dettaglio)
Formato compatto: `F-NN titolo (dove) · impatto·rischio·costo · proposta`.

### Home, Cerca, Libreria, Radio, Statistiche, Tutti i brani (F-01..F-29)
- F-01 Home scorciatoie Preferiti/Playlist/Radio: un Container con Border.symmetric + BorderSide sinistro per tile (home_blocks.dart:126-146, _Shortcut :176-200, IntrinsicHeight) · A·B·S · tre riquadri surface1 rCard con gap8.
- F-02 Home righe con Divider (home_row.dart:92-97, Positioned bottom:-6 left:64) in Riprendi/Più ascoltati/Riscopri (resume_rows.dart:114-144, home_bottom_rows.dart:49-121) · M·B·S · riquadro per blocco senza linee.
- F-03 Cerca tastiera automatica: _SearchFieldState.initState requestFocus se focusOnShow (bottom_bar.dart:170-173), focusOnShow=true in open() (ui_providers.dart:56-58) · A·M·S · focus solo al tocco; Ctrl+F resta (app_shell.dart:86-89). [= F-70]
- F-04 ✕ solo con testo nel dock (bottom_bar.dart:197-206), campo desktop svuota ma non chiude (search_screen.dart:227) · M·B·S · ✕ sempre: testo→svuota, vuoto→unfocus; due etichette.
- F-05 Chip Preferiti/Recenti (search_screen.dart:240-272, stati _favorites/_recent) · B·B·S · togliere + parametri SearchQuery se inutilizzati.
- F-06 Generi Cerca Wrap a larghezza testo, ~40 dp (search_screen.dart:361-376, _GenrePill :383-410) · M·B·S · griglia 3 colonne, altezza ≥48, maxLines 2.
- F-07 Cerca solo online: segmento Libreria/Online (:274-297, solo se kEnableYoutube), _goOnlineIfNoLocal (:138,144-155), _LibraryResults · A·M·L · cambio di comportamento; attenzione kEnableYoutube=false (build lite?) e prefill radio _applyPrefill :71-81; i generi aprono GenreScreen (libreria!).
- F-08 Libreria: lente = scorciatoia a Cerca (library_screen.dart:216-222), header Row titolo+Activity+lente+NewPlaylist+⋮ (:195-262) · M·B·M · stato _searching, animazione titolo/icone fuori, campo da sinistra, contenuto in fade/filtrato.
- F-09 Tre campi di ricerca quasi uguali senza widget comune: all_tracks_screen.dart:190-203, search_screen.dart:219-232, bottom_bar.dart:180-206 (_SearchField legato al dock) · B·B·M · CcSearchField condiviso con ✕ doppia.
- F-10 Radio generi ChoiceChip in Wrap, 24 tag kRadioGenreTags (radio_sections.dart:240-278) · M·B·S · griglia 4 colonne (~80 dp a 360: etichette a capo), tenere ValueKey('genre-$tag').
- F-11 Statistiche barre non toccabili: un solo Semantics image su CustomPaint (stats_charts.dart:20-36, stats_screen.dart:196-203) · A·M·M · tocco/trascinamento per posizione orizzontale → barra evidenziata + «giorno · ore»; semanticsBuilder per TalkBack.
- F-12 Barre: slot ~10 dp a 31 giorni, labelBand 18 fisso, TextPainter senza textScaler (stats_charts.dart:64,80,93) · M·M·M · selezione per posizione, etichette ogni N, scala testo.
- F-13 Tutti i brani: Column fissa ScanStatus+header+TextField+SegmentedBlocks+Expanded(ListView+AlphaScroller) ~250 dp fissi (all_tracks_screen.dart:190-262) · A·M·M · nascondi/mostra su direzione scroll senza sliver (AlphaScroller usa indice×extent).
- F-14 Tutti i brani: PlayPill/ShufflePill in Wrap sotto il titolo (:82-92) · M·B·S · due IconButton 48 dp a destra del titolo.
- F-15 Titolo/conteggio fissi (:64-80); l'utente vuole che scorrano via · M·B·M · titolo nella stessa animazione o come primo elemento.
- F-16 Campo Tutti i brani senza ✕ (:194-202) · M·B·S · CcSearchField.
- F-17 Query di Tutti i brani condivisa con Cerca (trackQueryProvider(false)), svuotata solo in initState (:108-114) · M·M·S · svuotare in dispose o provider distinto.
- F-18 Scorciatoie Home: TalkBack legge «Preferiti», «12» separati · M·B·S · Semantics label unica.
- F-19 HomeRow Semantics(button) senza label unica (home_row.dart:41-43) · M·B·S · MergeSemantics.
- F-20 CoverFan fontSize 13/12 letterali (cover_fan.dart:72,77) · B·B·S · stili del tema.
- F-21 HomeRow letterali 4/6/64/52 (home_row.dart:60-96) · B·B·S · token, spariscono con F-02.
- F-22 Ricerche recenti: dieci «Rimuovi ricerca» uguali (search_screen.dart:333-350) · M·B·S · tooltip con la query.
- F-23 Due onSubmitted (search_screen.dart:219-232 desktop, bottom_bar.dart:189-192 dock) · M·M·M · documentare/unificare.
- F-24 textFaint 0xFF887F99 su surface3 ~3,6:1 stimato (tokens.dart:46) · M·M·S · misurare, alzare luminosità.
- F-25 Animazioni nuove devono rispettare disableAnimationsOf (tokens.dart:165) · M·B·S.
- F-26 Header Libreria con 4 icone (192 dp): a testo 200 % il titolo sparisce (library_screen.dart:205-260) · M·B·S.
- F-27 Con la barra aperta in Libreria nascondere le altre 3 icone, ✕ chiude · M·B·S.
- F-28 Etichette generi lunghe/tradotte nelle griglie fisse (radio_sections.dart:265, search_screen g.name) · M·B·S · maxLines 2 centrato, test de/es.
- F-29 Titoli di sezione senza Semantics(header) · B·B·S.

### Registro, revisione, player, streaming, Shuffle+ (F-30..F-59)
- F-30 Registro piatto: una lista cronologica senza intestazioni di giorno né categoria, ora senza data (activity_log_screen.dart:121-202, itemExtent 64; pulizia a 30 giorni) · A·B·M · gruppi «Oggi / Ieri / data».
- F-31 Riga tecnica e troncata: «Arricchimento: 12 brani completati, 3 senza risultato» / «14:32, Completata, Riconosciuti: AcoustID 3, testo 5», 1 riga con ellissi (:150-186,193) · A·B·M · titolo breve + una riga di dettaglio, numeri come chip.
- F-32 5 icone per ~12 tipi; messaggi tecnici in chiaro («yt-dlp non trovato: installalo (pip install -U yt-dlp) e riprova») (:75-84) · M·B·S · icona per categoria, messaggi per l'utente.
- F-33 Nessun filtro per tipo (:117); tipi in activity_providers.dart:19 + 'correction' · A·B·M · chip Tutti / Download / Libreria / Arricchimento / Correzioni / Errori.
- F-34 Errori distinti solo da icona + rosso (:161,177) · M·B·S · etichetta «Non riuscita», filtro Errori.
- F-35 «Pulisci» in AppBar senza conferma, svuota anche i download finiti (:109, activity_log_providers.dart:~248) · M·M·S · nel menu ⋮ con «Annulla».
- F-36 Correzioni «Corretto da X a Y» in 1 riga + Ripristina nel trailing (:88-102) · M·M·S · da → a su due righe.
- F-37 itemExtent 64 fisso: a testo 200 % taglia (:129) · M·B·S · altezza libera.
- F-38 Banner «Da confermare (N)» sembra una voce (:107-114) · B·B·S · card in testa con conteggio.
- F-39 Proposta = ListTile «Da {from} a {to}» + due TextButton nel sottotitolo, niente fonte né copertina (proposals_screen.dart:51-80) · A·B·M · vecchio barrato / nuovo evidenziato, fonte, azioni ≥ 48 dp.
- F-40 «Accetta tutte» cala una a una: for su watchProposals().first, apply per brano = transazione DB + scrittura tag su file; watchProposals (credits_repository.dart:275) riemette dopo ogni brano (track_corrections.dart:117-123, apply :35-72) · A·M·M · una transazione DB unica, file dopo in sottofondo; lista vuota in un colpo. [= F-71]
- F-41 Fattibilità: lettura tag fuori transazione (:37), DB già transazionale (:44-62), _toFile dopo (:68) · transazione unica possibile solo per il DB.
- F-42 acceptAll ritorna n ma la UI lo ignora (proposals_screen.dart:29); il pulsante sparisce mentre gira (proposal_card.dart:121-136) · M·B·S · snackbar «N correzioni accettate».
- F-43 Da revisionare: frase di spiegazione fissa, motivi in bodySmall muted (la riga più importante è la più debole), inset 72 fisso (review_screen.dart:273-385) · A·B·M · motivi come chip, spiegazione sotto il titolo.
- F-44 5 ChoiceChip in Wrap senza conteggi (:243-268) · M·B·S · riga scorrevole con conteggi.
- F-45 Tocco e ⋮ aprono lo stesso foglio; «Ignora» con icona check ambigua; nessuna azione diretta (:92-135,163-189) · M·B·M · azione primaria visibile.
- F-46 Barra «secondo parere»: InkWell sotto 48 dp (:200-241) · B·B·S.
- F-47 Coda finita: mini player sparisce (SizedBox.shrink, mini_player.dart:130) e il dock salta; player aperto = freccia + «Nessun brano in riproduzione» senza azioni (now_playing_screen.dart:286-299); desktop: info vuota (desktop_player_bar.dart:60,197) · M·B·S · stato vuoto con azioni (Riproduci tutto / Shuffle+ / Riprendi l'ultimo).
- F-48 _Empty senza Semantics/liveRegion (now_playing_screen.dart:298) · B·B·S.
- F-49 Streaming: 480 dp di «Il brano è in arrivo…» poi salto (now_playing_screen.dart:171-182, :41; side_panel.dart:55-64) · A·B·M · skeleton con la forma delle schede.
- F-50 Forma delle schede: NpCard surface1 rCard 12 padding 16 titolo titleMedium + gap12 (now_playing_cards.dart:27-62); Testo 5 righe fisse (:104-111); Info due blocchi da 5 righe + Riprova (:221-296,318); Crediti titolo + sezioni + «Aggiorna» (credits_card.dart:62-95); gap 12 fra schede.
- F-51 PageSkeleton (artist_page_sections.dart:93-139) statico, surface1 su bg quasi invisibile, nessuna Semantics · M·B·S · widget Skeleton condiviso in lib/ui/widgets/ con pulsazione (spenta con riduci movimento, motion.dart:28) e un solo «Caricamento…» per TalkBack.
- F-52 Attesa infinita se la riga ombra non arriva (now_playing_screen.dart:165-166) · M·B·S · dopo N s «Non disponibile» + Riprova.
- F-53 Shuffle+: nessun provider espone «in preparazione» (shuffle_plus_controller.dart:81-86,133-135,357,408-411: blockSize 3, _block/_enriching privati) · A·B·M · stato osservabile pending/enriching.
- F-54 suggestions_screen.dart:80 è lo storico, con spinner · B·B·S · righe skeleton 72 dp.
- F-55 Suggeriti entrano con insertAt e poi cambiano titolo/copertina all'arricchimento (shuffle_plus_controller.dart:395, queue_sheet.dart:105-112) · M·B·M · riga skeleton/«in preparazione» fino ad arricchimento fatto.
- F-56 Icona di errore del registro senza etichetta (:160-163) · B·B·S.
- F-57 Includere i nuovi testi muted nel contrast_test esistente · B·B·S.
- F-58 Frasi lunghe e tecniche negli ARB (app_it.arb:3555,3674,3685-3700) · M·B·S · riscrittura breve.
- F-59 Nessun id/percorso in UI: il tecnico sta nelle frasi · nessuna azione oltre F-58.
Tipi del registro: download «Download, Titolo» (Completata/Non riuscita, retry «nuovo tentativo tra 30 s (1/3)»); transfer «Invio a Pixel di Marco, 12 brani»; import «Importazione «Spotify»» (Completata / Abbinamenti pronti: controllali e scarica / Rete non disponibile / YouTube ha chiesto di rallentare / yt-dlp non trovato… / Troppi errori di fila: importazione in pausa); scan «Scansione: 340 di 340» (Fermata); enrich «Arricchimento interrotto da un errore: 8 aggiornati, 2 non trovati»; enrichBackground «Arricchimento: 12 brani completati, 3 senza risultato» (Completamento fermato: nessuna fonte risponde); cleanup «Ricerca duplicati: 120 di 120»; releases «Controllo nuove uscite»; secondOpinion «Secondo parere: 40 di 40»; podcastRefresh «Aggiornamento dei podcast»; radio «Controllo delle radio salvate»; correction «Corretto da A - X a B - Y» + Ripristina. Sottotitolo comune «HH:mm, esito[, Riconosciuti: …]».

### Prestazioni e difetti (F-60..F-74)
- F-60 Libreria: cambio scheda → setState(_kind) rifà buildLibraryEntries nel build (library_screen.dart:143,:176; ordinamento RegExp+normalize per confronto library_entries.dart:55-58) · A·B·S · provider derivato memoizzato per (kind, sort) / chiavi di ordinamento precalcolate.
- F-61 Libreria: _LibraryList riusata senza key fra schede (:160-166), scroll ereditato, decode copertine · M·B·S · ValueKey(_kind) + cacheWidth.
- F-62 Liste già lazy (:525,:605) · nessuna azione.
- F-63 Libreria primo caricamento spinner nudo (:131) · M·B·S · skeleton righe.
- F-64 BUG Statistiche Anno→Mese: _setYear usa containing(_period.start) e start annuo=1 gen (stats_screen.dart:48-50, stats_queries.dart:18) · M·B·S · ricordare _lastMonth (aggiornato da prev/next :120-121), default mese corrente; test widget con now.
- F-65 Statistiche: cambio periodo → StreamProvider.autoDispose per chiave → spinner flash (stats_screen.dart:127, history_providers.dart:19) · M·B·S · tenere il valore precedente + skeleton.
- F-66 AsyncBody default spinner (async_body.dart:36), 8 usi: stats:127, history:110, never_played:51, playlists:41, enrich_round:57, radio_region_sheet:110/129, all_tracks:265 · M·B·S · skeleton righe predefinito.
- F-67 Tutti i brani spinner con 2000 brani (all_tracks_screen.dart:265-267) · A·B·S · skeleton.
- F-68 Spinner: suggestions_screen:80, radio_sections:114/:208 (+ equalizer, memory, playlist_source ok) · B · skeleton per suggestions e radio.
- F-69 Modelli buoni: favorites_screen:132, album_detail_screen:158 (SliverAsyncBody loading: rows).
- F-70 Cerca tastiera automatica: focusOnShow=true iniziale e in open() (ui_providers.dart:57,:62), _SearchFieldState.initState requestFocus post-frame (bottom_bar.dart:169-172); reopen() la evita (:76) · M·M·S · focus solo al tocco del campo; Ctrl+F (app_shell.dart:88) tiene il focus.
- F-71 Accetta tutte: for seriale, una transazione per brano + scrittura tag file (track_corrections.dart:117-123, apply :95-107), watchProposals riemette N volte · A·M·M · una transazione DB unica, poi _toFile in sequenza fuori; UI aggiornata una volta.
- F-72 Accetta tutte senza avanzamento · B·B·S · n/N.
- F-73 Home resume_rows.dart:96 rifà buildLibraryEntries · M·B·S · stessa memoizzazione.
- F-74 Shell IndexedStack ok (app_shell.dart:141).
Misure: integration_test/perf_test.dart (3000 brani, frame_stats) -d linux; scripts/perf_device.py 0d7ae9df206e --label X; misure.md fase 38. Manca scenario Libreria Tutto→Playlist→Album→Artisti. Rotture note perf_device.py:226, perf_test.dart:67.

## Scelte (giro 2, 2026-11-04)
- **Affrontati:** tutte le richieste U1–U17 e i ritocchi di accessibilità delle stesse schermate (D-357). Cambi di comportamento voluti: Cerca solo online (D-355), genere come mix libreria + suggeriti (D-356, D-359, D-360), Cerca nascosta senza YouTube (D-358), «Accetta tutte» in un colpo (D-361), mini player che resta a coda finita (D-364).
- **Nessuna azione:** F-62 (liste già lazy), F-69 (modelli buoni), F-74 (IndexedStack del dock), F-59 (nessun id in UI).
- **Soluzioni scelte:** etichetta sopra la barra toccata (D-362); mese ultimo visto o corrente (D-363); registro per giorno con filtri (D-365).
- **Quanto osare:** ristrutturazione per parti, una schermata per PR (D-366).
- **Intoccabili:** D-367. Stile: quello di `ui-fluida` (D-368).

## Arrivo — UI (giro 3, 2026-11-04)
Stile: quello di `ui-fluida` (D-368), nessun token nuovo salvo lo skeleton. I mockup approvati (D-371) sono la specifica visiva; le note numerate di ogni file valgono come dettaglio.

| Mockup | Schermata | Rilievi | Decisioni |
|---|---|---|---|
| `mockup/home.html` (variante A) | Home | F-01, F-02, F-18, F-19, F-21 | D-369 |
| `mockup/cerca.html` | Cerca solo online, ✕ doppia, recenti, generi 3 colonne, pagina del genere mista | F-03…F-07, F-22, F-23, F-28 | D-355, D-356, D-358…D-360 |
| `mockup/libreria-ricerca.html` | Libreria: lente → barra, risultati raggruppati, skeleton | F-08, F-09, F-26, F-27, F-60, F-61, F-63 | D-355 |
| `mockup/radio.html` | Radio: le tue → generi (4 colonne, 3/2 col con testo grande) → vicino a te | F-10, F-28 | D-370 |
| `mockup/statistiche.html` | Barre toccabili, mese ricordato, niente spinner | F-11, F-12, F-64, F-65 | D-362, D-363 |
| `mockup/tutti-i-brani.html` | Icone ▶/Shuffle a destra del titolo, ricerca e filtri che si nascondono, skeleton | F-13…F-17, F-67 | — |
| `mockup/player-vuoto.html` | Coda finita: mini player, player aperto, barra desktop | F-47, F-48 | D-364 |
| `mockup/streaming-skeleton.html` | Schede in streaming, coda Shuffle+, componente `Skeleton` | F-49…F-55, F-66, F-68 | — |
| `mockup/registro.html` | Registro per giorno con filtri | F-30…F-38, F-56, F-58 | D-365 |
| `mockup/da-confermare.html` | Proposte e «Accetta tutte» in un colpo | F-39…F-42, F-71, F-72 | D-361 |
| `mockup/da-revisionare.html` | Da revisionare | F-43…F-46 | — |

### Componenti nuovi (in `lib/ui/widgets/`)
- **`Skeleton`** (F-51, F-66): varianti lista, riga grande, cella di griglia, scheda, barre; blocchi `surface2` (`surface3` dentro le schede `surface1`), pulsazione d'opacità 0,55→1 in 1,4 s, ferma con `disableAnimationsOf`; un solo nodo semantico «Caricamento…». `AsyncBody`/`SliverAsyncBody` lo usano di serie al posto dello spinner. `PageSkeleton` diventa un suo uso.
- **`CcSearchField`** (F-04, F-09, F-16): campo arrotondato con lente e ✕ sempre visibile (testo → svuota; vuoto con focus → chiude la tastiera; vuoto senza focus → attenuata e inerte). Usato da Cerca (dock e desktop), Libreria e Tutti i brani.
- **Stato «in preparazione» di Shuffle+** (F-53): provider osservabile con il numero di suggeriti in arrivo e il blocco in arricchimento; serve alla coda e alla pagina del genere.

### Cambi oltre la UI (minimi)
- `TrackCorrections.acceptAll`: una transazione DB unica, file dopo in sottofondo, ritorna il numero (D-361).
- Ordinamento della Libreria memoizzato per (scheda, ordinamento) fuori dal `build` (F-60, F-73).
- Mix del genere: brani della libreria del genere + un suggerito online ogni 2, seme dai brani locali; riusa il motore di Shuffle+ (D-356, D-359). Senza YouTube niente Cerca (D-358).
- Registro: raggruppamento per giorno e categorie calcolati nel provider, testi riscritti negli ARB (it/en/de/es).

## Rete (giro 4, 2026-11-04)
Fonte: `test-strategist` sui nomi dei test (i corpi vanno riletti prima di scrivere ogni test).

### Test di caratterizzazione, prima di toccare il codice (fase 77.1)
- **Home:** contenuto e ordine di Riprendi / Più ascoltati / Riscopri (`test/ui/home_screen_test.dart`); ▶ = tutta la libreria in ordine, Shuffle = solo modalità (verificare che i test «Play …» e «shuffle … only changes the mode» lo coprano già).
- **Libreria:** ordine di ogni scheda e di ogni ordinamento anche dopo Tutto→Playlist→Tutto (`test/data/library_entries_test.dart` o `test/ui/library_screen_test.dart`).
- **Tutti i brani:** selezione, trascinamento, azioni sul brano, ▶/Shuffle di oggi (nuovo `test/ui/all_tracks_screen_test.dart`, oggi coperti solo di sponda da selection_lists/track_drag/track_actions).
- **Cerca/Radio:** chiave `genre-$tag` sui generi (D-367); ricerche recenti (oggi senza test).
- Il resto è già coperto: Statistiche (`stats_screen_test`, `stats_queries_test`), schede streaming (`now_playing_stream_cards_test`), Shuffle+ (`test/providers/shuffle_plus_test.dart`, `test/services/shuffle_plus`), registro (`test/providers/activity_log_test.dart`), revisione (`review_screen_test`).

### Test che cambiano per scelta (riscritti nella stessa PR, sennò CI rossa)
`track_corrections_test.dart:349` («accept all applies them one by one», D-361); `async_body_test` «loading shows a spinner» (Skeleton); test dei risultati locali e del segmento Libreria/Online in `search_screen_test` (D-355); `search_dock_test` «Cerca brings it back focused» (F-03); `radio_screen_test` «sections come in order» (D-370); `recognition_ui_test` con il finto `acceptAll`.

### Test nuovi, uno per comportamento
Elencati nel passo che li introduce (fasi 77–82): mese ricordato e mese corrente anche per un anno passato; tocco sulla barra; acceptAll con una transazione, una sola emissione di `watchProposals`, N restituito, errore di file nel registro; focus non richiesto aprendo Cerca; Cerca assente senza YouTube; ✕ a tre stati; Cerca senza risultati locali; mix del genere 2:1 e generi ordinati; lente → barra → risultati raggruppati; ordinamento non ricalcolato al cambio scheda; mini player e player a coda finita; stato «in preparazione» di Shuffle+; Skeleton con un solo «Caricamento…» e fermo con riduci movimento; Tutti i brani con barra che si nasconde e icone; registro per giorno, filtro, «Pulisci» con conferma.

### Metriche di arrivo
| Metrica | Soglia | Comando |
|---|---|---|
| Frame nel cambio scheda Libreria (scenario nuovo «Libreria Tutto→Playlist→Album→Artisti» in `integration_test/perf_test.dart`) | p90 build ≤ 16 ms sul telefono; su Linux almeno −50 % rispetto alla misura di partenza della 77.1 | `python3 scripts/perf_device.py 0d7ae9df206e --label <fase>`; `flutter test integration_test/perf_test.dart -d linux` |
| Contrasto dei colori nuovi (skeleton, ✕ attenuata, etichetta della barra, chip del registro) | ≥ 4,5:1 testo, ≥ 3:1 elementi grafici | `flutter test test/theme/contrast_test.dart` |
| Linee guida di accessibilità (bersagli 48 dp, etichette) sulle schermate toccate | zero violazioni | `flutter test test/ui/a11y_guidelines_test.dart` |
| Overflow a 360 px con testo 2,0× | nessun overflow | test di overflow per schermata (modello: `home_test.dart`) |
| «Accetta tutte» | 1 transazione, 1 emissione dello stream | `flutter test test/services/library/track_corrections_test.dart` |
| Spinner rimasti nelle schermate del perimetro | 0 (`CircularProgressIndicator` solo dove resta per scelta: equalizzatore, memoria, sorgenti playlist) | `grep -rn CircularProgressIndicator lib/ui` |
| Golden nuovi | radio, stats (barra toccata), all_tracks, activity_log, proposals, review, now_playing_empty, genre in phone_100 / desktop_100 / phone_150 | `flutter test test/goldens` (`--update-goldens` e revisione a mano dei PNG) |

### Comportamento invariato vuol dire
Stessi test verdi salvo quelli elencati sopra come «cambiano per scelta»; stessi dati nel DB e nei file (D-367); Jam, player e coda uguali tranne stato vuoto e righe «in preparazione».

### Comandi mirati per gruppo
Statistiche `flutter test test/ui/stats_screen_test.dart test/data/stats_queries_test.dart` · Libreria `flutter test test/ui/library_screen_test.dart test/data/library_entries_test.dart test/data/library_queries_test.dart` · Cerca `flutter test test/ui/search_screen_test.dart test/ui/search_dock_test.dart test/ui/search_sources_test.dart test/ui/genre_screen_test.dart` · Home e Radio `flutter test test/ui/home_screen_test.dart test/ui/home_test.dart test/ui/radio_screen_test.dart test/ui/radio_home_library_test.dart` · Player `flutter test test/ui/mini_player_test.dart test/ui/now_playing_test.dart test/ui/now_playing_stream_cards_test.dart` · Shuffle+ `flutter test test/providers/shuffle_plus_test.dart test/services/shuffle_plus` · Registro `flutter test test/providers/activity_log_test.dart test/ui/recognition_ui_test.dart test/services/library/track_corrections_test.dart test/ui/review_screen_test.dart` · Componenti `flutter test test/ui/async_body_test.dart test/theme/contrast_test.dart test/ui/a11y_guidelines_test.dart` · Golden `flutter test test/goldens`.
