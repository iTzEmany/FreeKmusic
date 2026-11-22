# Scansione B — interfaccia (22/11, sonnet; percorsi sotto lib/ui/)

1. **Ricerca senza tastiera**:
   - Libreria: il morph è sul posto (library_screen.dart:292), con `autofocus: true` a :330 e `requestFocus` a :259 (Ctrl+F).
   - Scheda Cerca: `requestFocus` in app_shell.dart:160-164 (anche :122).
   - «+» nuova playlist: `autofocus` sul campo nome in playlist_sheet.dart:152 (D-405).
   - Fix S: togliere i 4 focus automatici; Ctrl+F resta solo su desktop.
2. **Tutti i brani**:
   - Le icone stanno nei `BlockItem` di ordinamento (all_tracks_screen.dart:295-307); i filtri Tutti/Dispositivo/Streaming (library_filter_bar.dart:26) non ne hanno.
   - Lo sfondo che spezza viene da `ShrinkingHeader(color: cc.bg)` (all_tracks_screen.dart:271-273 → shrinking_header.dart:34, `ColoredBox` opaco sopra `AppBackground`).
   - Fix S: togliere le icone; colore trasparente con `ClipRect`, oppure condizionale.
3. **Aggiunti da poco**: home_blocks.dart:192-215 non ha superficie. La superficie è `HomeBlock` (home_row.dart:96-110), ma le intestazioni stanno fuori dal blocco ovunque (home_bottom_rows.dart:42,62,113; resume_rows.dart:104). Fix S: parametro `header` in `HomeBlock`, usato in tutte le sezioni.
4. **Anteprima del tema**: `ThemePreview` (theme_editor_screen.dart:395, :417-421) disegna solo colore e sfumatura e non legge mai `imagePath`, blur e dim. Fix M: riusare `AppBackground` (theme_background.dart:51-128).
5. **Card daylist**: l'`InkWell` copre solo la parte sinistra (daylist_card.dart:38-100); `PlayCircleButton` è un fratello. Fix S: `InkWell` su tutta la riga.
6. **Fogli stretti**:
   - Causa: `bottomSheetTheme.constraints = BoxConstraints(maxWidth: 560)` senza `minWidth` (app_theme.dart:151), quindi il foglio si restringe al contenuto.
   - Fix unico S in `showCcSheet` (cc_sheet.dart:11-31): `minWidth: min(560, larghezza schermo)`.
   - Colpiti sicuri: activity_log_screen.dart:95, speed_button.dart:52, duration_choice_sheet.dart:16, speaker_sheets.dart:115, jam_queue_sheet.dart:19, artist_link_open.dart:69.
   - Probabili: car_playlists_sheet, import_intro_sheet, ble_permission, FoldersSheet, shuffle_plus_sheet, merged_profiles, dislike_sheet, track_artists_sheet, jam_outputs_sheet, karaoke_sheet, sort_sheet, import_manual_search_sheet, jam_remote_sheets, followed_artists, cover_picker, activity_sheet, artist_picker, radio_station_sheet, track_actions:665.
   - devices_sheet.dart:35-41 sostituisce i constraints e perde il tetto dei 560 (su desktop il foglio va a tutta larghezza).
7. **Riprendi a griglia**:
   - Oggi resume_rows.dart:57-185 mostra al massimo 4 righe (nuove uscite, coda, brani lunghi da riprendere, album/playlist per `lastPlayedAt`).
   - I dati ci sono: `Plays` (tables.dart:185-200) con `context`/`contextName` e `RadioStations.lastPlayedAt`.
   - Mancano: la query «ultimo per macroarea»; un kind daylist (oggi la daylist parte come `PlayContextKind.library`, daylist_providers.dart:394); da verificare i podcast; il tile della griglia. Costo L.
8. **Intestazione playlist/album**:
   - `collection_header.dart:82-89` (`PlayPill`, `ShufflePill`, menu dentro un `Wrap`) è usato da 8 schermate.
   - Già pronti: «Scarica» = `keepOfflineFlow` (keep_offline_action.dart:10, nei menu di playlist e album); «Condividi album» = `DevicesSheet` (album_detail_screen.dart:263); per la playlist c'è solo «Esporta…».
   - Fix M: varianti a sola icona (con Semantics e tooltip) più due `IconButton`.
9. **Scorrimento rapido**: `AlphaScroller` (alpha_scroller.dart:20) esiste, ma c'è solo in Tutti i brani e solo con ordine Titolo o Artista (all_tracks_screen.dart:208); con l'ordine predefinito non si vede. Fix M: modalità «per posizione» sopra circa 100 elementi; da aggiungere in preferiti, playlist, album/artisti e cronologia.
10. **Registro**:
    - (a) «Come risolvere» (activity_log_entry.dart:400-407) usa la stessa callback del tocco sulla riga: su desktop non fa nulla se la voce è già selezionata, su telefono apre il foglio stretto. Fix S: azione propria, più il fix 6.
    - (b) Esistono `pauseChain`/`resumeChain`/`cancelChain` per una singola importazione (playlist_import_service.dart:1223-1240), ma niente per tutte. Fix M: «Ferma tutto» e «Annulla tutto».
    - (c) `ReportIssueScreen` non accetta precompilazione. Fix S: costruttore con titolo e dettagli tecnici, più un tasto «Segnala» in `LogDetail`.
11. **Selezione nell'importazione**:
    - playlist_source_sheet.dart:160-176 (import da link) ha un solo pulsante che alterna Tutto/Nessuno. Fix S: due pulsanti separati.
    - import_plan_screen.dart:44 ha solo «salta» per riga. Fix: checkbox per riga e le stesse due azioni.
12. **Segnalazione bug** (report_issue_screen.dart):
    - Difetti: riga di pulsanti che sfora (:140-157); anteprima del log senza altezza massima (:200-241); `buildIssue` ricostruito a ogni lettera (:68); nessuna spiegazione del tasto disabilitato; nessun `maxWidth` su desktop; stato `…`; campi alti per contatori più helper; icone nei blocchi.
    - Invio: via URL di issue GitHub (core/issue_report.dart:107).
13. **Scarica da online**:
    - `SuggestedInfo` (now_playing/suggested_info.dart:16-113) non osserva `downloadsProvider`, quindi non mostra l'avanzamento; un widget con l'avanzamento esiste già in online_song_row.dart:125-140,325-350.
    - Il menu ⋮ non cambia perché `liveCurrentTrackProvider` (player_providers.dart:1025-1040) tiene l'id negativo anche dopo il download: `isOnlineId` resta vero e si vede sempre il menu online. In più `showTrackActions` (track_actions.dart:415-421) cattura il `Track` una volta sola.
    - Fix M: un `DownloadBar` condiviso e il menu ricavato dalla riga reale.

**Di passaggio**:
- `CollectionScaffold`/`SliverAppBar` hanno `backgroundColor: cc.bg` fisso (collection_header.dart:93-105): stesso problema dello sfondo nelle pagine album e playlist.
- Tre implementazioni diverse dello stato di download (suggested_info, online_song_row, track_actions).
- Accessibilità: `AlphaScroller` desktop largo 28 dp; `SegmentedBlocks` compatto sotto 48 dp; `LogEntryCard` con `minHeight: 0`.
