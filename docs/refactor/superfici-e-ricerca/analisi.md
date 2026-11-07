# Refactor «superfici-e-ricerca» — analisi

Perimetro (richiesta dell'utente del 2026-11-05): dock e intestazione della Libreria flottanti (`docs/prossimi-lavori.md` §4, punti 3 e 4), Tutti i brani, Home, Cerca, Suggeriti, playlist intelligenti, ordinamento in Libreria e nelle playlist, creazione playlist, artisti con due profili YouTube Music, Podcast. Tipo: **tutto** (ui + logica). Molti punti sono **cambi di comportamento scelti dall'utente** (regola 1 di `/refactor`): ognuno va in `docs/decisioni.md`.
Stile di base: quello di `docs/refactor/ui-fluida/` (`mockup/tokens.css`, `lib/ui/theme/tokens.dart`) e `docs/refactor/ui-uso-quotidiano/mockup/base.css`. Note grezze della scansione di playlist intelligenti e podcast: `scansione-smart-podcast.md`.

## Misure di partenza
- Velocità: strumenti e soglie del refactor `ui-fluida` (`docs/refactor/ui-fluida/misure.md`, `integration_test/perf_test.dart`, `scripts/perf_device.py`). Si rimisura sul Mi A3 lo scroll di Tutti i brani e della Libreria prima e dopo il dock/l'isola (§4 di prossimi-lavori).
- Ricerca: oggi 1 sola scheda artista/album per ricerca (`cards.first`), 0 brani locali tra i risultati.
- Playlist intelligenti: 10 campi, 1 valore per regola, editor a testo libero.
- Podcast: ricerca per nome (iTunes, limit 10), nessuna navigazione.

## Rilievi in ordine di priorità
Formato: `F-NN · area · titolo · dove · prova · danno · impatto · rischio · costo · proposta`.

- F-88 · suggeriti · confronto con la libreria troppo rigido · `lib/services/.../track_matcher.dart:114-127` (`LibraryIndex.find`), regex `:8-21`, `query_cleaner.dart:188` · durata obbligatoria entro 5 s; suffissi «anniversary/deluxe/expanded/version/live» non tagliati; artista = primo nome dello split · brani già posseduti suggeriti (caso «Born on the Bayou») · A · M · S · a titolo+artista uguali è già posseduto qualunque sia la durata (D-389); più suffissi tagliati, artista confrontato per insieme di parole; test col caso reale.
- F-86 · cerca · i brani in libreria non compaiono fra i migliori risultati · `online_results.dart:255-318`, `merge_results.dart:100-165` · `mergeResults` fonde solo YTM + video YouTube · l'utente non vede che ha già il brano · A · B · M · sezione in cima «Nella tua libreria» (solo per ricerche di brani) con `LibraryIndex`, e i doppioni tolti dalla lista online.
- F-87 · cerca · un solo artista/album · `ytm_artist_parser.dart:21-26` (`cards.first`), `smart_search.dart:311-313` · `YtmCatalog.searchArtists` (`ytm_catalog.dart:93-103`) e `searchAlbums` (`youtube_service.dart:236`) esistono ma non sono usati qui · l'artista giusto spesso non è il primo · A · B · M · righe orizzontali «Artisti» e «Album» con più risultati, nel budget delle richieste (`request_budget.dart`).
- F-91 · smart · editor delle regole a testo libero · `lib/ui/screens/smart/smart_playlist_editor.dart:186-195` (TextField), modelli `:37-52` · bisogna scrivere `artista:A OR artista:B` · poco intuitivo, errori di sintassi · A · B · M · editor visuale a filtri (campo, condizione, valori scelti da un elenco) che produce la stessa stringa canonica: nessuna migrazione dei dati.
- F-92 · smart · un valore per regola, confronto a sottostringa · `lib/services/library/rules/rule_ast.dart` (`RuleContains`), `rule_sql.dart:18` (LIKE %x%) · «più artisti» = tanti OR; «Queen» trova anche «Queens of the Stone Age» · A · M · M · nodo «uno tra» (`RuleIn`) con confronto esatto quando il valore viene da un elenco; parser retrocompatibile.
- F-78 · tutti-brani · l'intestazione sparisce di colpo · `all_tracks_screen.dart:136-165` (`_onScroll` sulla direzione, animazione di 180 ms), `:269` `SizeTransition` · nasconde tutto insieme e non segue il dito · A · M · M · riga conteggio/tempo/shuffle/play fissa; ricerca+filtri in `SliverAppBar(floating: true, snap: false)` in un `CustomScrollView` con `SliverFixedExtentList`; `AlphaScroller` (offset = indice × altezza) sottrae l'altezza della barra.
- F-75 · dock · il contenuto si taglia dove inizia il dock · `lib/ui/shell/app_shell.dart:198` (`bottomNavigationBar`), nessun `extendBody` in `lib/` · stacco netto, il dock non sembra flottante · A · M · M · `extendBody: true`.
- F-76 · dock · manca un margine in fondo comune · `tokens.dart:114-118` (solo `miniPlayerHeight`, `dockMargin`, `dockBottom`); ~17 liste senza padding finale (library_screen:811/892, all_tracks, favorites:70, playlist_detail:216, playlists:46, artist:104/169, album_detail, search:168, online_results, memory:161, home, radio:113, history:140, tags:50/115, stats:226, podcasts:111) · con F-75 l'ultima riga finirebbe sotto il dock · A · M · M · altezza del dock misurata nella shell ed esposta (es. `MediaQuery.padding.bottom`), così le liste la ricevono senza codice per schermata.
- F-97 · podcast · solo ricerca per nome · `podcast_service.dart:183` (iTunes Search, `limit 10`, niente paese né genere), `podcasts_screen.dart` · non si scopre niente di nuovo · A · B · M · «Scopri»: generi Apple (`…/MZStoreServices.woa/ws/genres?id=26`), classifiche per genere e paese (`itunes.apple.com/it/rss/toppodcasts/limit=N/genre=ID/json`), ricerca con `country` e `genreId`; nessuna chiave, nessun pacchetto nuovo (prove con curl del 2026-11-05).
- F-79 · home · Registro attività a tre tocchi, Impostazioni che scorre via · `home_screen.dart:43-56` (header dentro la ListView `:95`), `activity_sheet.dart:83` · funzione nascosta · M · B · S · riga fissa in alto con Registro accanto a Impostazioni.
- F-80 · libreria · «Recenti» e «Aggiunti di recente» si confondono · `library_entries.dart:8` (`recent, alpha, added`), comparatore `:127-148`; `app_it.arb:694,697` · «Recenti» = ultimo ascolto, «Aggiunti di recente» = data di aggiunta: stessa parola, significati diversi · M · B · S · nomi chiari («Ascoltati di recente», «Aggiunti di recente») negli ARB it/en/de/es.
- F-84 · cerca · riga dell'info quasi vuota · `online_results.dart:195`, `_ActivityRowBar` `:395-430`; titolo «Cerca» su una riga sua (`search_screen.dart:107-121`) · 48 dp sprecati sopra i filtri · M · B · S · icona info nella riga del titolo, accanto a «Cerca»; la riga sparisce.
- F-85 · cerca · filtri alti 64 dp con icona · `online_results_sections.dart:23-61` (`SourceFilterChips`), `segmented_blocks.dart:48` · occupano spazio per niente · M · B · S · solo testo, chip compatti (bersaglio di tocco ≥ 48 dp).
- F-83 · playlist · creazione in tre passi (foglio, dialog, nome) · `new_playlist_menu.dart:21-57`, `create_flows.dart:11-16` (`promptName`) · `createPlaylistFlow` serve anche «Aggiungi alla playlist» (`playlist_dialogs.dart:93`) · M · M · M · foglio a schermo intero dal basso: nome in alto, playlist esistenti sotto (come `_AddToPlaylistSheet`, `playlist_dialogs.dart:75-115`).
- F-82 · playlist · niente ordinamento dentro una playlist · `playlist_detail_screen.dart:200` (solo `SliverReorderableList`), ordine = `playlist_tracks.position` · M · B · M · «Ordina per» con i criteri dei brani (`SortOption`, `track_repository.dart:18`, `_orderFor` `:398-418`); da decidere se l'ordine scelto è solo una vista o riscrive l'ordine manuale.
- F-81 · libreria · pochi criteri di ordinamento · `LibraryEntry` (`library_entries.dart:21-44`) espone solo ultimo ascolto, data di aggiunta, titolo · M · B · M · nuovi criteri (numero di brani, durata, anno, artista, ascolti) con i campi in `LibraryEntry`.
- F-93 · smart · campi già nel DB ma non usabili nelle regole · `tables.dart`: `lastPlayedAt`, `lyricsPlain/Synced`, `bitrateKbps`, `albumArtist`, `plays`, `track_credits` · M · B · S · esporli nell'editor visuale.
- F-77 · libreria · intestazione piena e fissa sopra la lista · `library_screen.dart:248-262` (`_Veil`: ScanStatus, `_KindTabs`, `LibraryToolbar`), `:333-556` (`_LibraryHeader`, lente animata della fase 83: `_lensShift`, `_measure`, `TweenAnimationBuilder` `:433`) · niente effetto flottante · A · **A** · L · isola unica (ricerca, schede, Ordina per, vista) che galleggia sulla lista; l'animazione della lente va riscritta dentro l'isola. La Libreria non ha la striscia A–Z (c'è solo in Tutti i brani).
- F-89 · artisti · due profili YTM dello stesso artista non si uniscono · `tables.dart:337-359` (`FollowedArtists`, PK `ytmId`), `ytm_artist_resolver.dart:35-45` · album divisi fra due pagine (Luca Carocci, Marco Castello) · M · M · L · tabella di alias (profilo → profilo principale), pagina artista che unisce gli album dei profili (doppioni tolti per titolo e anno), voce «Unisci con…»; da includere nel backup.
- F-90 · artisti · doppione mai rilevato · `ytm_artist_resolver.dart:43` (`same.length > 1` → «Scegli») · nessun avviso · B · B · S · se due profili hanno lo stesso nome normalizzato e nessun alias: «Sembrano lo stesso artista: unire?» (dipende da F-89).
- F-94 · dati · nazionalità e lingua non esistono · nessuna colonna; `artist_infos` ha solo la biografia · «per nazionalità» impossibile oggi · A · M · L · tabella dei dati dell'artista (paese) riempita in background da MusicBrainz (`area`/`country`) e Wikidata (P27), client già presenti; il filtro compare solo quando c'è il dato.
- F-95 · dati · un solo genere per brano · `audio_metadata_tag_reader.dart:99` (`genres.first`) · i generi secondari si perdono · M · M · M · salvare tutti i generi (tabella brano-genere) con una nuova scansione dei tag.
- F-96 · dati · niente stelle, niente flag «scaricato da online»; BPM ed etichetta solo nel JSON di `track_enrich.details` · B · B · M · aggiungere solo ciò che l'utente vuole nei filtri.
- F-98 · podcast · classifiche Apple instabili · `rss.marketingtools.apple.com` 502, `rss.applemarketingtools.com` muto il 2026-11-05 · M · M · S · solo l'endpoint vecchio `itunes.apple.com/.../rss`, cache di qualche ora, errore gentile; fyyd (senza chiave, 110 categorie) come eventuale riserva. Podcast Index richiede una chiave: scartato.
- F-99 · tutti-brani · play senza riquadro tondo · `all_tracks_screen.dart:92-96` (`IconButton` semplice) · altrove c'è `PlayCircleButton` (`lib/ui/widgets/play_buttons.dart:8-43`); la Home ne ha una copia a mano (`home_blocks.dart:63-81`) · incoerenza visiva · M · B · S · `PlayCircleButton` qui e nella Home (via il duplicato).
- F-100 · shell · le sezioni non tornano allo stato iniziale · `app_shell.dart:134-180` (un `Navigator` per scheda in `IndexedStack`; `select` cambia solo l'indice; ritoccare la scheda attiva fa solo `popUntil` `:137`, desktop `desktop_sidebar.dart:41`) · restano pagine aperte, scroll, testo di ricerca (`library_screen.dart:79`, `searchControllerProvider` `search_screen.dart:30`), scheda della Libreria (`_kind`), filtri · tornando in una sezione la si ritrova a metà · A · M · M · all'uscita da una scheda: chiudere le pagine sopra e azzerare scroll, ricerca, scheda e filtri (contatore per scheda nella `ValueKey` + azzeramento esplicito dei provider); `ShellNav.openInLibrary/openInHome` (`shell_nav.dart:17-40`) resta coerente.
- F-101 · home · «Casuale su tutto» troppo vicino a play e shuffle · `home_blocks.dart:26-98` (`ShuffleHero`: titolo in `FittedBox` su una riga, sottotitolo senza `maxLines`, `SizedBox(width: 12)` letterale) · affollato · M · B · S · titolo su due righe, un po' più d'aria fra play e shuffle (token di spaziatura).
- F-102 · podcast · YouTube Music come seconda fonte (D-387) · il client (`innertube_client.dart`) non ha niente sui podcast; prova del 2026-11-05: la ricerca col filtro podcast restituisce programmi (`MPSPP…`), la pagina del programma 40 episodi con `videoId` (`MUSIC_VIDEO_TYPE_PODCAST_EPISODE`), formati solo audio presenti con yt-dlp (139/249/250); il player WEB_REMIX dice `UNPLAYABLE`. Pagina dei generi non trovata (`FEmusic_podcasts` e `FEmusic_non_music_audio` → 404) · A · M · M · ricerca e pagina del programma da YTM, riproduzione/scaricamento con la stessa via di yt-dlp; generi dalla lista Apple finché non si trova la pagina YTM (da cercare nel primo passo della fase).

## Sintesi per area
- **Superfici (F-75–78)**: dock flottante e margine in fondo comune vanno insieme e toccano ~17 liste; Tutti i brani si sistema con una barra che segue lo scroll; l'isola della Libreria è il pezzo più rischioso perché riscrive l'animazione della lente della fase 83.
- **Cerca e suggeriti (F-84–88)**: brani locali in cima e più artisti/album riusano codice che esiste già (`LibraryIndex`, `searchArtists`); i suggeriti doppi vengono da un confronto troppo rigido su durata, suffissi e artista.
- **Playlist e libreria (F-79–83, F-91–96)**: l'editor visuale a filtri non richiede migrazioni se produce la stessa stringa delle regole; «più valori» e confronto esatto richiedono un nodo nuovo; nazionalità e generi multipli richiedono dati nuovi (rete e nuova scansione).
- **Artisti e podcast (F-89, F-90, F-97, F-98)**: unione di profili = tabella nuova + pagina che unisce; podcast navigabili con le API Apple gratuite.

## Scelte (giro 2, 2026-11-05)
- **Affrontati: tutti i rilievi F-75…F-102**, con questi limiti dei dati (D-390): nazionalità dell'artista, più generi per brano, BPM ed etichetta sì; stelle e flag «scaricato da online» no (F-96 in parte scartato).
- **Cambi di comportamento scelti dall'utente**: isola della Libreria con la lente rifatta (D-391, D-407); sezioni che tornano allo stato iniziale (D-392); confronto con la libreria senza durata a titolo+artista uguali (D-389); sezione «Nella tua libreria» in Cerca (D-399, D-400); più artisti e album (D-401); unione dei profili YTM (D-402); Podcast con Scopri e YouTube Music (D-403, D-404); foglio unico per nuova playlist e aggiungi alla playlist (D-405); interruttore della sfocatura nel Tema (D-406); editor a filtri (D-393, D-394); ordinamenti (D-395, D-396); Home (D-388).
- **Quanto osare**: ristrutturazione per parti; riscrittura solo dell'intestazione della Libreria e dell'editor delle playlist intelligenti.
- **Intoccabili (D-397)**: backup vecchi ripristinabili; playlist intelligenti esistenti con gli stessi brani (stessa stringa canonica, D-393); ordine manuale delle playlist; Jam, Shuffle+ e player invariati; nessun pacchetto nuovo.
- **Fluidità (D-398)**: nessuno scatto sul Motorola edge 40; Mi A3 con tolleranza più leggera, ma l'obiettivo resta non farlo scattare.
- **Stile (D-408)**: quello di `ui-fluida`.

## Arrivo — UI e logica (giro 3, 2026-11-05)
Stile di `ui-fluida` (D-408). I mockup approvati (D-416) sono la specifica visiva; le note numerate di ogni file valgono come dettaglio. Indice: `mockup/indice.html`.
| Mockup | Rilievi | Decisioni |
|---|---|---|
| `home.html` | F-75, F-76, F-79, F-100, F-101 | D-388, D-392, D-406 |
| `tutti-i-brani.html` | F-78, F-99 | D-407 |
| `libreria.html` | F-77, F-80, F-81 | D-391, D-396, D-406, D-407, D-409, D-410 |
| `nuova-playlist.html` | F-83 | D-405, D-411 |
| `playlist.html` | F-82 | D-395, D-396, D-410 |
| `playlist-intelligente.html` | F-91…F-95 | D-390, D-393, D-394, D-412 |
| `cerca.html` | F-84…F-87 | D-399…D-401, D-413 |
| `artista-unione.html` | F-89, F-90 | D-402, D-414 |
| `podcast.html` | F-97, F-98, F-102 | D-403, D-404, D-415 |
| `tema-sfocatura.html` | — | D-406 |
Senza mockup: F-88 (confronto con la libreria, D-389), F-94/F-95 come dati raccolti in background.

**Struttura di arrivo (in breve)**
- Shell: `extendBody` + altezza del dock misurata ed esposta alle liste (un punto solo); reset delle schede all'uscita (`app_shell.dart` `select`, contatore nella chiave della scheda + azzeramento dei provider di ricerca/filtri).
- Scroll che segue il dito: un solo componente condiviso (intestazione che si ritrae di quanto si scorre) usato da Tutti i brani e dall'isola della Libreria; `AlphaScroller` tiene conto dell'altezza visibile.
- Regole: nodo «uno tra» in `rule_ast.dart` + parser e `toSql` retrocompatibili; l'editor visuale costruisce l'AST e scrive con `formatRules`; campi nuovi come colonne/tabelle drift (nazionalità dell'artista, generi del brano) con migrazione e backup.
- Ricerca: `LibraryIndex` riusato per «Nella tua libreria» e per togliere i doppioni; `searchArtists` + ricerca album filtrata per le righe orizzontali, nel `request_budget`.
- Artisti: tabella di alias dei profili YTM (+ backup), pagina che unisce le discografie.
- Podcast: client Apple (generi, classifiche, ricerca con paese/genere) e client YTM (ricerca programmi, pagina programma, episodi) dietro un'unica ricerca; episodi YTM scaricati con la via yt-dlp esistente.

## Rete (giro 4, 2026-11-05)
**Test che proteggono già** (da non rompere): `test/ui/app_shell_test.dart`, `library_screen_test.dart`, `all_tracks_screen_test.dart`, `alpha_scroller_test.dart`, `home_screen_test.dart`, `search_screen_test.dart`, `online_results_test.dart`; `test/services/online/merge_results_test.dart`, `smart_search_test.dart`, `ytm_artist_resolver_test.dart`; `test/services/import/track_matcher_test.dart` (gruppo `LibraryIndex`); `test/services/library/rule_parser_test.dart`, `rule_sql_test.dart`, `rule_rewrite_test.dart`; `test/data/smart_playlist_test.dart`, `playlist_repository_test.dart`, `library_entries_test.dart`; `test/ui/smart_playlists_test.dart`, `create_flows_test.dart`, `podcast_screens_test.dart`; `test/services/podcast/*`; `test/services/backup/restore_service_test.dart`; `test/ui/button_tap_sweep_test.dart`, `a11y_guidelines_test.dart`, `talkback_labels_test.dart`. Da **riscrivere** perché fissano ciò che cambia per scelta: la barra di Tutti i brani (F-78), `suggestion_pool_test.dart` e `library_overlap_test.dart` sulla regola dei 5 s (D-389), la lente della Libreria (D-391).

**Test di caratterizzazione prima di toccare il codice** (fase 87):
1. `test/services/library/rule_corpus_test.dart`: ~25 regole reali su un DB fisso → stessi id; `formatRules(parseRules(s)) == s` sul corpus; `artista:Queen` trova anche «Queens of the Stone Age» per le stringhe vecchie (D-393, D-397).
2. `test/services/backup/legacy_backup_test.dart` + fixture in `test/fixtures/backup/` (schema v14 e penultimo): playlist, regole, ordine manuale, artisti seguiti e impostazioni intatti; schema più nuovo rifiutato.
3. `test/data/playlist_order_test.dart`: l'ordine manuale resta dopo riordino, rimozione, undo, ripristino.
4. `test/services/import/library_index_characterization_test.dart` + `test/services/shuffle_plus/suggestion_pool_bayou_test.dart`: Born On The Bayou (315 222 / 231 000 ms) oggi non trovato → si ribalta nella fase 88 (D-389).
5. `test/ui/shell_tabs_test.dart`: oggi cambiando scheda restano pagine, scroll, scheda della Libreria e ricerca → si ribalta nella fase 89 (D-392).
6. `test/services/online/merge_results_characterization_test.dart`: niente brani locali, una sola scheda artista/album.
7. `test/data/library_sort_characterization_test.dart`: ordine di `LibrarySort` (pari merito, accenti).
8. `test/ui/alpha_scroller_offset_test.dart`: salto = indice × altezza riga, con barra visibile e nascosta.

**Golden prima** (`test/goldens/screens_golden_test.dart`, `scripts/shots.sh`): Libreria nelle schede Playlist/Album/Artisti e con la lente aperta, Tutti i brani scrollato, Cerca con risultati, editor smart, Podcast, Home a scala 2.0.

**Metriche di arrivo**
| Metrica | Soglia | Comando |
|---|---|---|
| Fluidità Motorola edge 40 | frame > 16,7 ms ≤ 3 %, build p99 ≤ 16 ms (nessuno scatto, D-398) | `python3 scripts/perf_device.py ZY22HKD85K --label X --playback --only "…"` |
| Fluidità Mi A3 | ≤ 6 % e non peggio della base di oltre un frame per scenario | `python3 scripts/perf_device.py 0d7ae9df206e --label X --playback --only "…"` |
| Scenari | esistenti: Pallino schede, Tutti i brani, Album, Libreria Tutto→Playlist→Album→Artisti, Ricerca «notte»; **nuovi** (fase 87): scroll Libreria con isola, lente aperta/chiusa, scroll Tutti i brani con barra che si ritrae, cambio scheda con reset | idem + `integration_test/perf_test.dart` (Linux, solo confronto relativo) |
| Avvio a freddo | pari alla base (oggi 2415–2575 ms) | `perf_device.py` |
| Qualità | `flutter analyze` pulito; a11y, tap-sweep e TalkBack estesi alle superfici nuove (isola, foglio nuova playlist, editor, Scopri; bersagli ≥ 48 dp) | test mirati della fase |

Base: misura `base` su `origin/master` all'inizio della fase 87 su entrambi i telefoni; confronto finale nella fase 97.
**Comportamento invariato** vuol dire: i test che proteggono restano verdi (salvo quelli riscritti per una decisione elencata), il corpus delle regole dà gli stessi id, i backup della fixture si ripristinano, l'ordine manuale resta, Jam/Shuffle+/player senza test cambiati.

## Suggeriti: come funziona oggi (risposta all'utente)
Fonte: radio di YouTube Music (`shuffle_plus_controller.dart:531`, `radio.page(seed.videoId)`) partendo da brani della libreria. Esclusione dei brani già posseduti (`suggestion_pool.dart:27-39`): video già scaricato, oppure `LibraryIndex.find` = stesso titolo normalizzato (tolti remaster/feat/edit) + stesso primo artista normalizzato + durata entro 5 s. Indice rifatto quando cambia il numero dei brani o ogni 5 minuti (`library_providers.dart:408-421`). **Verificato sul Motorola (2 534 brani, D-389):** in libreria «Born On The Bayou» di *Bayou Country (Expanded Edition)* dura 5:15; il suggerito (stream `CNgUBQSpP7s`, *The Singles Collection*) dura 3:51. Titolo e artista coincidono, la durata differisce di 84 s: è la regola dei 5 s a farlo passare. Le versioni live hanno il suffisso nel titolo («- Live In Stockholm»), quindi restano distinte anche senza la durata.

## Stato finale (fase 97, 2026-11-06)
Fasi 87–97 chiuse (PR #113–#122 e la PR della 97). Misure sul Mi A3 (0d7ae9df206e), build profile, `scripts/perf_device.py --label finale --playback`, secondo giro (il primo fa da riscaldamento):

| Scenario | Base 87 (frame > 16,7 ms) | Finale | build p99 base → finale (ms) |
|---|---|---|---|
| Pallino schede | 5,9 % | 1,0 % | 11,0 → 11,5 |
| Tutti i brani | 2,0 % | 1,2 % | 12,1 → 10,9 |
| Album | 4,2 % | 1,1 % | 13,2 → 12,2 |
| Libreria Tutto→Playlist→Album→Artisti | 4,9 % | 2,1 % | 12,9 → 16,7 |
| Ricerca «notte» | 0,2 % | 0,6 % | 8,1 → 12,4 |
| Scroll Libreria | 4,7 % | 1,3 % | 10,0 → 12,1 |
| Lente Libreria | 1,9 % | 1,8 % | 10,4 → 14,0 |
| Scroll Tutti i brani | 2,3 % | 1,4 % | 8,7 → 12,0 |
| Cambio scheda | 5,5 % | 2,0 % | 13,9 → 13,2 |
| Apri album | 2,1 % | 3,6 % | 17,3 → 23,7 |
| In riproduzione | 1,7 % | 1,1 % | 17,2 → 16,3 |
| Lettore dal dock | 1,1 % | 2,0 % | 15,8 → 20,4 |
| Swipe mini player | 1,6 % | 2,9 % | 15,0 → 17,2 |
| Fogli | 4,1 % | 4,0 % | 24,7 → 23,5 |
| Apertura player | 2,3 % | 2,5 % | 19,3 → 24,1 |
| Anello | 0,7 % | 0,8 % | 16,4 → 16,5 |

Tutti gli scenari sotto il 6 %; «Apri album» è sopra la base (+1,5 punti, circa 6 frame su 413) ma nel primo giro era 2,1 %: rumore. Avvio a freddo: mediana 2767 ms su 5 (base 87: 2697 ms), da `main` al primo frame 648 ms (base 685), PSS 246 MB (base 245). Scansione di 3000 brani: era salita a 30,7 s (base 14,5) per i generi scritti brano per brano (fase 93); corretta nella 97 (`TrackGenreRepository.replaceMany`, desktop 23,7 → 14,3 s). Motorola edge 40 (2026-11-07, dopo le correzioni del raster): tutti gli scenari ≤ 0,5 % di frame > 16,7 ms, raster p99 ≤ 8,6 ms, avvio a freddo 1101 ms (dettagli in `docs/fase-97-chiusura-superfici.md`).
