# Refactor «ui-jam-ricerca» — analisi

Perimetro (richiesta dell'utente, 2026-10-27): Jam, seek del player (anello + barra), Ricerca e dock, menu ⋮ in tutte le sezioni, Home «aggiunti da poco». Stile di arrivo: quello approvato nel refactor `ui-fluida` (`docs/refactor/ui-fluida/analisi.md` «Arrivo — UI», `mockup/tokens.css`). I comportamenti di streaming e coda online (fasi 45–48) esistono già.

## Misure di partenza
- Scatti di oggi: `scripts/shots.sh` → `test_shots/goldens/` (phone/desktop: jam, now_playing, shell_playing…). Non c'è uno scatto della Ricerca né della Home.
- Le soglie di velocità restano quelle della fase 38 (`docs/refactor/ui-fluida/misure.md`); questo refactor non tocca liste lunghe né il cambio di brano.

## Rilievi in ordine di priorità
Priorità 1 (impatto alto, costo basso o medio): F-58 (testo del player), F-20, F-21, F-22 (Ricerca); F-31, F-32, F-33 (Home); F-40, F-42, F-46, F-47, F-51 (menu); F-01, F-02, F-04, F-07 (Jam e barra).
Priorità 2: F-08, F-09, F-06, F-14 (seek condiviso); F-11, F-12, F-13, F-16 (Jam); F-23, F-24 (Ricerca); F-34, F-35, F-36, F-38 (Home); F-41, F-43, F-44, F-45, F-48, F-49, F-50, F-52, F-53, F-55 (menu).
Priorità 3: F-03, F-05, F-10, F-15, F-17, F-18, F-25, F-26, F-28, F-29, F-30, F-54, F-57. I test (F-19, F-27, F-37, F-56) vanno nella rete.

## Sintesi per area
- **Jam e seek:** la Jam è una schermata a parte (anello pieno e fermo, barra Material, ✕ ⋮ ≡ su ogni riga). Il seek della Jam c'è già e l'ospite lo può usare: il lavoro vero è staccare anello e barra dalla sorgente del player locale e avere un solo stato di trascinamento.
- **Ricerca:** due cause precise (`dismiss` torna indietro; il campo prende il posto del dock); la correzione è piccola, il rischio è nei rebuild durante l'animazione della tastiera.
- **Home:** il rimpicciolimento nasce dalla scala del ventaglio aperto; mancano nomi, scroll e più di 5 album.
- **Menu:** 12 ⋮ con menu fluttuante, 4 menu che non sono ⋮ da decidere, fogli diversi fra loro: un solo helper li rende uguali.

## Rilievi (dettaglio)

### Jam e seek (F-01..F-19)
- F-01 · layout · La Jam non è il player · jam_screen.dart:105-140, jam_player_card.dart:28 · CustomScrollView con anello 0.4×lato corto (max 240) contro la colonna del player con copertina Expanded e anello 12 dp · due «player» con gerarchie diverse · A · M · M · riusare la colonna del player con copertina più piccola, sopra «Jam», «Esci dalla Jam» e partecipanti, coda sotto.
- F-02 · anello · L'anello della Jam è `live`, pieno e non seekable · jam_player_card.dart:34-39 (`live: true, stroke: 4`) · non mostra la posizione · A · B · S · progresso reale e seek.
- F-03 · anello · Il vuoto di 40° nell'arco è identità (ring_progress.dart:~283), ma con l'arco pieno sembra un difetto · B · B · S · tenerlo; con il progresso reale si legge come «fine».
- F-04 · riuso · RingProgress legge positionProvider/durationProvider e chiama playerController.seek · ring_progress.dart:~92,127,145 · non si può guidare con lo stato della Jam · A · M · M · parametri di posizione, durata e `onSeek` (di serie il player).
- F-05 · riuso · Il seek nella Jam esiste ed è permesso agli ospiti · jam_state.dart:114-119, jam_transport.dart:65 · `JamCommand.seek(ms)` già inviato da JamSeekBar; l'esito `invalid` è ignorato · M · B · S · `onSeek` = `JamCommand.seek`; mostrare l'esito `invalid`.
- F-06 · riuso · Posizione della Jam a scatti: Timer da 500 ms (`CcTiming.poll`) · jam_seek_bar.dart:24-44 · un anello da 12 dp aggiornato a 500 ms scatta · M · M · M · una sola fonte di posizione interpolata (Ticker) per anello, barra e tempi.
- F-07 · barra · La barra orizzontale del player è stata tolta nella fase 43 (a296a08) · now_playing_controls.dart NpSeekRow:24 (solo tempi, qualità, velocità) · il seek sul telefono è solo l'anello · A · M · M · rimettere la barra fra i due tempi.
- F-08 · barra · Stato del trascinamento condiviso solo a metà · ring_progress.dart:~21 `ringDragProvider`; desktop_player_bar.dart:~340 `_dragging` locale · trascinando uno l'altro salta · M · M · S · un solo stato di drag (nome neutro) scritto da anello e barra; seek al rilascio.
- F-09 · barra · Tre Slider di seek con tre `_dragging` (Jam, desktop, futuro player) · jam_seek_bar.dart · M · B · S · un widget `SeekBar(position, duration, onSeek)` condiviso.
- F-10 · token · Letterali nella Jam · jam_player_card.dart:36-72 (stroke 4, 0.4, 120/240, 12, 16, 56/32); jam_parts.dart:~89 avatar `_size 32, _step 22`, colore HSL fuori palette · B · B · S · CcDims e colore avatar dai token.
- F-11 · header · «Termina Jam» rosso in alto a destra, senza conferma (ctrl.end diretto) · jam_screen.dart _JamHeader ~195-230 · chiude la Jam per tutti con un tocco · M · M · S · header come il player; conferma per «Termina» (solo host).
- F-12 · partecipanti · Avatar 32 dp sovrapposti con il nome nel solo Tooltip · jam_parts.dart JamParticipants · al tocco e con TalkBack i nomi non si leggono · M · B · S · fila di avatar + nomi, `Semantics` sull'insieme, «+N» oltre 4.
- F-13 · coda · Righe con ✕ ⋮ ≡ affiancati · jam_parts.dart JamQueueRow ~175-210 · il testo perde ~150 dp su 360 («aggiunto d…») · M · B · M · ⋮ unico (Rimuovi, Salta qui…) e ≡, come la coda del player.
- F-14 · a11y · Anello e barra insieme = due slider per TalkBack · ring_progress.dart:~127-146 (Semantics slider ±5 s) · M · M · S · uno solo annunciato (l'anello), la barra esclusa dalla semantica, o viceversa.
- F-15 · a11y · Tempi della barra Jam in labelSmall 11 sp sotto il minimo 12 dei token; contrasto del rosso in tema chiaro non misurato · B · B · S · token 12 e test di contrasto.
- F-16 · a11y · A testo 200 % «Esci dalla Jam» e il titolo vengono tagliati (Row con maxLines 1) · jam_screen.dart _JamHeader · M · M · S · header su due righe, titolo fino a 2 righe, test a textScaler 2.0.
- F-17 · perf · Il repaint dell'anello è già isolato (RepaintBoundary, Consumer su posizione) · ring_progress.dart:~95-110 · B · B · S · tenerlo; il painter ascolta la fonte di F-06 via `repaint:`.
- F-18 · perf · JamSeekBar fa setState ogni 500 ms anche in pausa e a schermo coperto · jam_seek_bar.dart:28-35 · B · B · S · tick solo se suona e la rotta è visibile.
- F-19 · test · Si rompono jam_screen_test (header, righe), ring_progress_test:148-205, now_playing_test:59,161-213 e i golden jam/now_playing (phone, desktop, light) · M · M · M · test del seek della Jam (ospite → JamCommand.seek), test anello+barra sincroni, golden rigenerati una volta alla fine.

### Ricerca (F-20..F-30)
Oggi (telefono): il tap su Cerca apre il campo nel dock al posto di tab e mini player (bottom_bar.dart:62-130). ✕ = `dismiss()` (ui_providers.dart): svuota, chiude e torna alla sezione di prima. Tastiera chiusa a mano: niente cambia, il dock resta solo campo. Back Android: `close()`, resta su Cerca con i tab. Desktop: campo nella pagina, nessun cambio.
- F-20 · ricerca · ✕ torna alla sezione precedente · ui_providers.dart `dismiss` → `nav.set(_previous)`; app_shell_test:610 lo fissa · l'utente perde la Ricerca · A · B · S · togliere `_previous`: ✕ svuota e chiude la tastiera, resta su Cerca.
- F-21 · ricerca · Il campo sostituisce tab e mini player · bottom_bar.dart:62-130 (AnimatedSwitcher) · durante la ricerca niente tab né player · A · M · M · dock a due strati: campo sopra, mini player + tab sotto.
- F-22 · ricerca · Chiudere la tastiera non cambia il dock · bottom_bar.dart:66 (viewInsets solo come padding) · A · M · S · tab e mini player nascosti solo con la tastiera aperta (inset > 0), anche fuori da semantica e tocco.
- F-23 · perf · `MediaQuery.viewInsetsOf` nel build di ShellDock ricostruisce dock e mini player a ogni frame della tastiera · bottom_bar.dart build · scatti sul Motorola · M · M · S · un widget piccolo che legge gli inset con il resto costante.
- F-24 · ricerca · Back con il campo aperto chiama `close()` (PopScope, app_shell.dart:176) · con il nuovo modello va definito l'ordine: tastiera → campo → pagina · M · M · S · decisione.
- F-25 · ricerca · Un push dalla Ricerca chiude il campo (`_OnPush`, app_shell.dart:129) · B · M · S · resta; con tab sempre visibili serve meno.
- F-26 · coerenza · Su desktop la ✕ della pagina svuota soltanto, quella del dock porta via · app_shell.dart:80, search_screen.dart:173 · B · B · S · stessa semantica (svuota, resta).
- F-27 · test · app_shell_test:610, 630, 645 (ritorno a `_previous`) da riscrivere; da ricontrollare search_sources_test, transitions_characterization_test, shell_keys_test · M · B · S.
- F-28 · a11y · Il tooltip della ✕ dice «Chiudi la ricerca» anche quando non chiuderà più · bottom_bar.dart:203 · B · B · S · «Cancella», visibile solo con del testo.
- F-29 · bug noto · «Testo bianco coi filtri preferiti/recenti» (prossimi-lavori §1) già corretto in d7e5eca · B · B · S · verificarlo sul telefono e toglierlo dalla lista.
- F-30 · bug noto · «Il tasto cerca della tastiera non cerca online» già corretto in d7e5eca (vale con `kEnableYoutube`) · B · B · S · come F-29.

### Home «aggiunti da poco» (F-31..F-38)
Oggi: `recentlyAddedAlbums(limit: 5)` (home_blocks.dart:227) in un ventaglio (`CoverFan`, max 5). Il primo tap o l'hover apre il ventaglio, il secondo apre l'album.
- F-31 · home · Aperto, il ventaglio rimpicciolisce i quadrati · cover_fan.dart `_place`: scala `spread/size`; su 360 dp 84 → ~59 dp (0,70) · il contrario della richiesta · A · M · M · aperto = riga che scorre di lato con quadrati 84 dp fissi.
- F-32 · home · Il nome non si vede (solo senza copertina, `_FanCard`) · A · B · S · titolo (1-2 righe) e artista sotto ogni quadrato aperto.
- F-33 · home · Due tetti a 5 (limit e `_maxCovers`) · home_blocks.dart:227, cover_fan.dart · lo scroll non servirebbe · A · B · S · alzare il limite (decisione: quanti).
- F-34 · design · Il mockup approvato (`ui-fluida/mockup/home.html`) non mostra lo stato aperto · M · M · S · aggiungerlo al mockup.
- F-35 · a11y · Le copertine aperte hanno solo il titolo come etichetta; il ventaglio non si apre da tastiera · cover_fan.dart · M · B · S · «titolo, artista», Enter/Spazio.
- F-36 · perf · Con 15-20 copertine serve una lista lazy con copertine decodificate a misura · M · M · M · ListView.builder + `cacheWidth`, animazione solo sui primi 5.
- F-37 · test · cover_fan_test:11 (`findsOneWidget` sul titolo) si rompe; da ricontrollare home_test, home_screen_test · B · B · S.
- F-38 · desktop · L'hover apre e l'uscita del mouse chiude: con una lista che scorre si chiude durante lo scroll · cover_fan.dart MouseRegion · M · M · S · l'hover apre, si chiude solo con un tocco fuori o un secondo tocco.

### Testo nel player (F-58, aggiunto dall'utente il 2026-10-27)
- F-58 · player · La scheda del testo cambia larghezza e altezza (regressione della fase 39) · larghezza: now_playing_screen.dart:156-168, dalla fase 39 (bf4656d) le schede stanno in un `Column` dentro `RiseIn` senza `crossAxisAlignment`, quindi ognuna prende la larghezza del suo contenuto (prima erano figli diretti della lista e si allargavano); le righe brevi del testo la stringono e la allargano a ogni riga · altezza: · now_playing_cards.dart `_SyncedLines` (~120-125) e `LyricsCard` (61-105) · `to = (from + 5).clamp(0, lines.length)`: sulle ultime righe si vedono 4, poi 3 righe; testo sincronizzato (5 righe + 2 dp ciascuna), testo semplice (`maxLines: 5`, meno se è corto) e «nessun testo» (una riga con pulsante) hanno tre altezze diverse · le schede sotto saltano a fine brano e al cambio di brano · A · B · S · `crossAxisAlignment: CrossAxisAlignment.stretch` sul `Column` delle schede; finestra che a fine brano arretra (`from` al massimo `length - 5`) e corpo ad altezza fissa di 5 righe in tutti e tre i casi, come la scheda Curiosità (`_collapsedLines`).

Il foglio del player (track_actions.dart:~420-490): `showCcSheet` → intestazione con copertina 56, titolo, artista e album, poi gruppi di ListTile; le voci distruttive in `cc.error`; maniglia dal tema.

| file:riga | trigger | ⋮? | voci |
|---|---|---|---|
| widgets/selection_bar.dart:83 | ⋮ barra di selezione | sì | molte |
| widgets/new_playlist_menu.dart:20 | «+» | no | 3 |
| widgets/track_actions.dart:408 | clic destro (desktop) | no | come il foglio |
| now_playing/queue_sheet.dart:289 | ⋮ implicito, dentro un foglio | sì | 1 |
| now_playing/now_playing_controls.dart:324 | timer (luna) | no | 5-6 |
| library/library_screen.dart:227 | ⋮ barra | sì | 4 |
| library/library_toolbar.dart:51 | ordinamento | no | N |
| library/favorites_screen.dart:101 | ordinamento | no | N |
| library/album_detail_screen.dart:212 | ⋯ | sì | ~8 |
| playlists/playlist_detail_screen.dart:236 | ⋯ | sì | ~7 |
| smart/smart_playlist_screen.dart:93 | ⋯ | sì | 3 |
| jam/jam_parts.dart:219 | ⋮ riga della coda | sì | 1-2 |
| podcast/podcast_detail_screen.dart:132, :293 | ⋮ barra, ⋮ episodio | sì | 1-2 |
| cleanup/tag_backups_screen.dart:105 | ⋮ | sì | 2 |
| settings/missing_tracks_screen.dart:98 | ⋮ | sì | 2 |

- F-40 · menu · 12 ⋮/⋯ aprono ancora un menu fluttuante (tabella) · viola la regola «sempre un foglio» · A · M · M · un helper `showCcActionSheet(header?, gruppi, destructive)` sopra `showCcSheet` e ogni ⋮ lo usa.
- F-41 · menu · Il clic destro su desktop è un `showMenu` con le stesse voci del foglio · track_actions.dart:408, track_row:590 · due interfacce per le stesse azioni · M · B · S · decisione: foglio anche qui, o eccezione desktop.
- F-42 · menu · Il ⋮ della selezione multipla costruisce le voci con codice duplicato da track_actions:395 · selection_bar.dart:83 · A · M · S · foglio condiviso con titolo «N selezionati».
- F-43 · menu · Timer di spegnimento a menu fluttuante, mentre la velocità è già un foglio (`SpeedSheet`) · now_playing_controls.dart:324 · M · B · S · decisione: foglio come la velocità.
- F-44 · menu · Ordinamenti a menu fluttuante · library_toolbar.dart:51, favorites_screen.dart:101 · non sono ⋮ · M · B · S · decisione: foglio con la scelta corrente segnata, o eccezione.
- F-45 · menu · «+» nuova playlist (3 voci) a menu fluttuante · new_playlist_menu.dart:20 · M · B · S · decisione: foglio.
- F-46 · menu · Un menu fluttuante dentro il foglio della coda, con una sola voce · queue_sheet.dart:289 · A · M · S · un pulsante diretto per «Suggerimenti recenti».
- F-47 · menu · ⋮ a 1-2 voci nella Jam e nei podcast · jam_parts.dart:219, podcast_detail_screen.dart:132/293 · A · B · S · helper di F-40.
- F-48 · coerenza · Due glifi per la stessa azione: ⋮ (more_vert) in 12 punti, ⋯ (more_horiz) in album, playlist, smart, player e riga larga · M · B · S · decisione: un solo glifo.
- F-49 · coerenza · I fogli differiscono: senza intestazione (playlist _rowMenu, online_album _showMenu, tags_sheet, radio_station_sheet); `useRootNavigator` e `isScrollControlled` variano · M · B · M · l'helper fissa intestazione, SafeArea, scroll e navigatore.
- F-50 · menu · Foglio su foglio: la riga della playlist apre «Rimuovi» + «Altre azioni» che apre un secondo foglio · playlist_detail_screen.dart:260 · M · B · S · «Rimuovi dalla playlist» in cima al foglio del brano.
- F-51 · a11y · `showCcSheet` senza `barrierLabel` localizzato e senza titolo semantico · cc_sheet.dart:6-22 · A · B · S · aggiungerli nell'helper.
- F-52 · a11y · ⋮ invisibile (`Opacity 0`) ma raggiungibile da TalkBack e dal focus quando le azioni sono nascoste · track_row.dart:307 · M · B · S · escluderlo da semantica e focus.
- F-53 · a11y · ⋮ con `ccIconDensity` compatta sotto 48 dp · track_row, jam_parts:221 · M · B · S · minimo 48 dp.
- F-54 · desktop · Il foglio è limitato a 640 dp centrato dal default M3 (app_theme.dart:167) · B · B · S · fissare `maxWidth` nel tema.
- F-55 · desktop · Senza `autofocus` le frecce funzionano solo dopo un Tab (il menu oggi le gestisce) · M · M · S · `autofocus` sulla prima voce.
- F-56 · test · Si riscrive menus_characterization_test (8-10 casi su PopupMenu); cambiano settings_and_playlists_test:70/79/107 e tag_write_options_test:171/183/192 · A · M · M · l'helper di ricerca dei test cerca ListTile nel BottomSheet.
- F-57 · coerenza · Voci distruttive senza colore di errore (missing_tracks «Rimuovi dalla libreria», podcast «Disiscriviti») · B · B · S · `destructive: true` nell'helper.

## Scelte (giro 2, 2026-10-27)
- **Affrontati:** tutti i rilievi F-01..F-57 (D-154). Nessuno rimandato o scartato; F-29 e F-30 sono solo da verificare sul telefono.
- **Decisioni:** D-147..D-158. In breve: niente menu fluttuanti in tutta l'app, anche timer, «+», ordinamenti e clic destro (D-148); ⋮ ovunque (D-149); conferma per «Termina Jam» (D-150); righe della coda della Jam con ⋮ + ≡ (D-151); Home aperta con 20 album in una riga che scorre (D-152); Back sulla Ricerca come nelle altre schede (D-153); Ricerca che resta (D-155); anello + barra con una fonte sola (D-156); helper dei fogli (D-157).
- **Cambi di comportamento voluti:** ✕ della Ricerca non torna indietro; menu sempre a foglio (anche il clic destro); conferma su «Termina Jam»; barra di seek di nuovo nel player; Home aperta che scorre con i nomi.
- **Intoccabili (D-158):** protocollo della Jam, dati e impostazioni, scorciatoie, temi e accenti, stile `ui-fluida`, nessun pacchetto nuovo.

## Arrivo — UI (giro 3, approvato il 2026-10-27)
Nessuna direzione estetica nuova: si applica quella di `ui-fluida` (D-21, token D-23). Mockup approvati in `docs/refactor/ui-jam-ricerca/mockup/`, specifica visiva di `/obiettivo`:
- `jam-player.html`: player con anello 12 dp e barra orizzontale fra i due tempi (chip qualità e velocità sotto, centrati), anello e barra si muovono insieme anche durante il trascinamento. La Jam è il player stesso (D-159): cambia solo l'intestazione («Jam», avatar + nomi, «Termina Jam» in colore errore per l'host con conferma, «Esci dalla Jam» per l'ospite); precedente e successivo per tutti (D-160); testo e curiosità scorrendo; coda condivisa nel foglio di «Coda» con righe ⋮ + ≡; desktop con testo, curiosità e coda nella colonna di destra.
- `ricerca.html`: tastiera aperta = solo la barra sopra la tastiera; tastiera chiusa = barra sopra mini player e schede (Cerca con il pallino); ✕ «Cancella» solo con del testo, svuota e resta; desktop con la barra nella pagina.
- `home-aggiunti.html`: chiuso il ventaglio di oggi; aperto una riga che scorre di lato con 20 album da 84 dp, titolo (2 righe) e artista.
- `fogli.html`: anatomia comune dei fogli (maniglia, intestazione opzionale, gruppi, voci 56 dp, distruttive in rosso in fondo, 85 % di altezza massima, 560 dp su desktop, autofocus, Esc); casi brano, collezione, selezione, ordinamento, timer (blocchi come la velocità), «+».

## Rete (giro 4)
**Comportamento invariato** = ciò che l'utente vede oggi e che non è fra i cambi voluti (D-148..D-161): stesse voci di ogni menu, nello stesso ordine e con lo stesso effetto; stessi comandi e formato dei messaggi della Jam; dove cade il dito sull'anello è dove va il brano; testo della ricerca conservato cambiando scheda; stessi DB, impostazioni e scorciatoie; stesse azioni della coda (swipe, tap, rimozione, brano corrente).

**Test di caratterizzazione, prima di toccare il codice:**
- Seek (`seek_characterization_test`): angolo → posizione e vuoto di 40° dell'anello, seek al rilascio; slider desktop che durante il drag mostra la posizione del dito; `JamSeekBar` dell'ospite che invia `JamCommand.seek(ms)`.
- Jam: in `jam_state_test` separare la parte dell'host di `next`/`jump` (indice, `playing`, versione) da quella dell'ospite che cambia; swipe che accoda nella Jam (`jam_screen_test:215`); formato dei messaggi `next`/`jump` invariato.
- Ricerca: testo conservato con la tastiera chiusa a mano e cambiando scheda; ✕ della pagina desktop che svuota e resta.
- Menu: `menus_characterization_test` deve coprire anche timer, ordinamenti (Libreria, Preferiti), clic destro, ⋮ della selezione, della coda e dei podcast; ciò che manca si aggiunge prima.
- Home: ventaglio chiuso con i primi 5, primo tocco apre, secondo apre l'album.
- Testo: riga evidenziata che segue la posizione in `LyricsCard`, se non è già coperta.
- Golden di oggi da aggiungere: Ricerca a telefono a tastiera chiusa, Home con il ventaglio aperto, foglio ⋮ di un brano.

**Test che cambiano di proposito** (si riscrivono, non si «aggiustano»): `ring_progress_test:148-205`, `now_playing_test:59,161-213`; `jam_state_test:48`, `remote_transport_test` («the buttons go to the Jam», `skipToPrevious`), `jam_screen_test` (intestazione, righe, «Termina»); `app_shell_test:592,610,630,645`; tutto `menus_characterization_test` (cambia solo come si apre e si legge, gli elenchi attesi restano), `settings_and_playlists_test:70/79/107`, `tag_write_options_test:171/183/192`; `cover_fan_test:11`; golden jam, now_playing, home, mini_dock.

**Test nuovi** (uno per comportamento): anello e barra con un solo stato di drag; un solo slider per TalkBack; `RingProgress` con posizione e `onSeek` iniettati; posizione della Jam ferma in pausa; precedente nella Jam (> 3 s `seek(0)`, ≤ 3 s `jump`); ospite che può `next`/`jump`; conferma di «Termina» (annulla non chiude); «Esci dalla Jam»; partecipanti «+N» con semantica; riga della coda con ⋮ + ≡; intestazione a testo 200 %; ✕ della ricerca che svuota e resta; ✕ solo con testo, «Cancella»; tastiera aperta = solo la barra (anche fuori da semantica e tocco); tastiera chiusa = barra + mini player + schede; Back con la tastiera (D-153); uscire da Cerca nasconde la barra; **rebuild di `ShellDock` e del mini player durante l'animazione della tastiera** (probe che conta le build in 10 passi di `viewInsets`); helper dei fogli (intestazione, distruttive in fondo e rosse, autofocus, Esc, `barrierLabel`, 560 dp); «N selezionati»; «Rimuovi dalla playlist» in cima; pulsante diretto nella coda; ⋮ nascosto fuori da semantica e focus; ⋮ ≥ 48 dp; ordinamento con la scelta segnata; regola in `architecture_test`: niente `PopupMenuButton`/`showMenu` nel codice UI; Home aperta con 84 dp fissi, titolo e artista con etichetta, lista lazy, hover desktop, Enter/Spazio; `LyricsCard` con altezza e larghezza uguali per testo sincronizzato, semplice e assente e sulle ultime righe.

**Metriche di arrivo** (comando):
- zero avvisi: `flutter analyze`;
- accessibilità verde: `flutter test test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart test/ui/font_scale_test.dart test/ui/large_text_test.dart`;
- zero menu fluttuanti: `flutter test test/ui/architecture_test.dart` e `grep -rn "PopupMenuButton\|showMenu(" lib/ui` vuoto;
- dock: il test di rebuild sugli inset (ShellDock e mini player non si ricostruiscono a ogni passo);
- golden rigenerati una volta a fine fase: `flutter test --update-goldens test/goldens/<file>`, poi `flutter test test/goldens`;
- sul telefono (non in CI): `scripts/perf_device.py` sul dock e sulla Ricerca, confronto con le soglie della fase 38.

**Comandi mirati per area** (la suite completa la fa la CI; in più `flutter test test/services test/jam` quando si toccano `jam_state.dart` o `codecore_audio_handler.dart`):
- seek e Jam: `flutter test test/ui/ring_progress_test.dart test/ui/now_playing_test.dart test/ui/jam_screen_test.dart test/ui/jam_track_info_screen_test.dart test/jam test/services/audio/remote_transport_test.dart`;
- Ricerca: `flutter test test/ui/app_shell_test.dart test/ui/search_screen_test.dart test/ui/search_sources_test.dart test/ui/shell_keys_test.dart test/ui/transitions_characterization_test.dart`;
- menu: `flutter test test/ui/menus_characterization_test.dart test/ui/track_actions_test.dart test/ui/selection_bar_test.dart test/ui/settings_and_playlists_test.dart test/ui/tag_write_options_test.dart test/ui/architecture_test.dart test/ui/lists_sheets_characterization_test.dart`;
- Home e testo: `flutter test test/ui/cover_fan_test.dart test/ui/home_test.dart test/ui/home_screen_test.dart test/ui/lyrics_screen_test.dart test/ui/now_playing_test.dart`.

## Risultati

Fasi 58–63 (PR #47–#52), tutte fuse su `master`; fase 64 = chiusura. Stato: fatto / in parte / non fatto / tuo.

| Rilievo | Stato | Commit | Nota |
|---|---|---|---|
| F-01 | in parte | d7a528a (#52, fase 63) | la Jam è il player (D-159); senza chip qualità/velocità/shuffle né cuore, senza volume locale su desktop |
| F-02 | fatto | d7a528a (#52, fase 63) | anello con progresso reale e seek (su `RingProgress` iniettato da 59.2) |
| F-03 | fatto | d9dc1d3 (#48, fase 59) | vuoto di 40° tenuto, come deciso |
| F-04 | fatto | d9dc1d3 (#48, fase 59) | posizione, durata e `onSeek` parametri |
| F-05 | fatto | d7a528a (#52, fase 63) | `onSeek` = `JamCommand.seek` |
| F-06 | fatto | d9dc1d3 (#48, fase 59) | una sola fonte di posizione |
| F-07 | fatto | d9dc1d3 (#48, fase 59) | barra di nuovo fra i due tempi |
| F-08, F-09 | fatto | d9dc1d3 (#48, fase 59) | `SeekBar` condivisa e un solo stato di drag |
| F-10 | fatto | d7a528a (#52, fase 63) | token al posto dei letterali |
| F-11 | fatto | d7a528a (#52, fase 63) | conferma «Termina Jam» (D-150) |
| F-12 | fatto | d7a528a (#52, fase 63) | avatar + nomi, «+N», semantica |
| F-13 | fatto | d7a528a (#52, fase 63) | ⋮ + ≡ nel foglio «Coda» (D-151) |
| F-14, F-15 | fatto | d9dc1d3 (#48, fase 59) | un solo slider per TalkBack; tempi a 12 sp |
| F-16 | fatto | d7a528a (#52, fase 63) | intestazione a testo 200 % |
| F-17, F-18 | fatto | d9dc1d3 (#48, fase 59) | repaint isolato tenuto; tick solo se suona |
| F-19 | fatto | 489cae5 (#47, fase 58) + 59–63 | caratterizzazione in 58, riscritture di proposito nelle fasi dei rilievi, golden rigenerati a fine fase |
| F-20, F-26, F-28 | fatto | e359c28 (#49, fase 60) | ✕ «Cancella» svuota e resta, anche su desktop (D-155) |
| F-21, F-22, F-25 | fatto | e359c28 (#49, fase 60) | dock a due strati; il push chiude ancora il campo (come deciso) |
| F-23 | fatto | e359c28 (#49, fase 60) | nessun rebuild durante la tastiera (probe nel test) |
| F-24 | fatto | e359c28 (#49, fase 60) | tastiera → campo → pagina (D-153) |
| F-27 | fatto | 489cae5 (#47, fase 58) + e359c28 (#49, fase 60) | caratterizzazione in 58, riscrittura in 60 |
| F-29, F-30 | fatto | e359c28 (#49, fase 60) | verificati sul Mi A3, nessuna correzione (già in d7e5eca) |
| F-31, F-32, F-36 | fatto | ea5f9ad (#51, fase 62) | riga che scorre, 84 dp fissi, nomi, lista lazy (D-152) |
| F-33 | fatto | ea5f9ad (#51, fase 62) | 20 album |
| F-34 | fatto | ea5f9ad (#51, fase 62) | stato aperto aggiunto al mockup di `ui-fluida` |
| F-35, F-38 | fatto | ea5f9ad (#51, fase 62) | etichette, Enter/Spazio; hover desktop solo apre |
| F-37 | fatto | 489cae5 (#47, fase 58) + ea5f9ad (#51, fase 62) | caratterizzazione in 58, riscrittura in 62 |
| F-39 | non mappato | — | il numero non è nell'analisi (salto di numerazione) |
| F-40, F-47, F-48 | fatto | 7eb133f (#50, fase 61) | helper `showCcActionSheet`; glifo unico ⋮ (grep `more_horiz` vuoto) |
| F-41, F-42, F-50 | fatto | 7eb133f (#50, fase 61) | clic destro a foglio (D-148), «N selezionati», «Rimuovi dalla playlist» in cima |
| F-43, F-44, F-45 | fatto | 7eb133f (#50, fase 61) | timer, ordinamenti e «+» a foglio (D-148); il timer segna solo «A fine brano» |
| F-46, F-52, F-53 | fatto | 7eb133f (#50, fase 61) | pulsante diretto nella coda; ⋮ fuori da semantica/focus; ≥ 48 dp |
| F-49, F-51, F-54, F-55, F-57 | fatto | 7eb133f (#50, fase 61) | intestazione, `barrierLabel`, 560 dp, autofocus, distruttive in rosso nell'helper |
| F-56 | fatto | 489cae5 (#47, fase 58) + 7eb133f (#50, fase 61) | caratterizzazione in 58, helper dei test sul BottomSheet in 61 |
| F-58 | fatto | d9dc1d3 (#48, fase 59) | schede a tutta larghezza, corpo di 5 righe fisso (D-161) |

Non fatto: nessun rilievo. Tuo: la verifica a mano di 63.5 e della parte Motorola di 64.3 (D-169).

### Prima e dopo
Mi A3, quota di frame > 16,7 ms (dettagli e build/raster in `misure.md`, sezioni «Prima» e «Dopo (fase 64)»):

| Scenario | Prima | Dopo | Soglia | ok |
|---|---|---|---|---|
| Pallino schede | 0,9 % | 0,6 % | ≤ 2 % | sì (A/B: master 0,6 e 0,6 %; i 4,1-5,6 % erano rumore del telefono) |
| Tutti i brani | 4,0 % | 0,9 % | ≤ 1 % | sì |
| Album | 0,5 % | 0,1 % | ≤ 0,6 % | sì |
| Ricerca «notte» | 2,8 %, build p99 34,5 | 9,0 % (2,2 % nella seconda run), build p99 21,3 | ≤ 3 %, build p99 ≤ 16 ms | no (build p99, D-176) |
| Swipe mini player | 0,3 % | 0,4 % | ≤ 2 % | sì |
| Fogli | 3,7 % | 2,7 % | ≤ 3 % | sì |
| Apertura player | 2,4 %, build p99 35,1 | 2,0 %, build p99 22,0 | ≤ 3 %, p99 ≤ 33 ms | sì |
| Anello | 0,3 % | 0,4 % | — | — |

### Cambi di comportamento avvenuti
- D-148: niente menu fluttuanti; timer, «+», ordinamenti e clic destro sono fogli.
- D-150: «Termina Jam» chiede conferma (solo host).
- D-151: righe della coda della Jam con ⋮ + ≡ (via ✕).
- D-152: Home «aggiunti da poco» con 20 album; aperta = riga che scorre con nomi.
- D-153: Back con la tastiera la chiude soltanto; a tastiera chiusa come le altre schede.
- D-155: ✕ della Ricerca svuota e resta; barra sopra il dock, tastiera aperta = solo la barra.
- D-159: la Jam è la schermata del player; cambia solo l'intestazione.
- D-160: precedente, successivo e «Salta qui» per tutti; precedente > 3 s torna all'inizio, ≤ 3 s al brano prima.
- D-161: scheda del testo a tutta larghezza e ad altezza fissa di 5 righe.

### Soglie non raggiunte e scarti accettati
- D-176: Ricerca «notte» build p99 26,1 ms sul Mi A3 (Prima 34,5, soglia 16): −24 % ma fuori soglia; il residuo (`smartSearch` e righe nel thread UI) si rimisura in 64.1. Quota > 16,7 ms 2,9 % in soglia; Album 0,9 % è rumore fra i run.
- Jam, scarti accettati: nessun chip qualità/velocità/shuffle né cuore; nessun volume locale su desktop; «precedente» entro 3 s riprende una Jam in pausa.
- 63.5 (due telefoni) e la parte Motorola di 64.3 restano all'utente (D-169: prove su Mi A3 e Linux).
- Fase 61: il timer di spegnimento segna solo «A fine brano».
