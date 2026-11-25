# Rete di sicurezza (giro 4, 24/11/2026)

## Copertura di oggi e buchi
| Area | Test che ci sono | Cosa non è coperto |
|---|---|---|
| Home | `home_screen_test`, `home_test`, `resume_providers_test`, `resume_episode_row_test`, `radio_home_library_test` | tocco su una tile e la sua destinazione; anello del Riprendi (D-725); «Tutti» in ogni intestazione; `playlists_screen` senza test |
| Player e mini | `now_playing_test`, `mini_player_test`, `seek_characterization_test`, `now_playing_stream_cards_test` | cuore con brano online (F-08); stesse azioni nei tre player; «Modalità auto» nel ⋮ (D-732) |
| Barra del player desktop | solo in `app_shell_test`, `empty_player_test` | nessun test dedicato |
| Collezioni | `collection_header_test`, `album_screen_test`, `collection_pages_test`, `collection_pages_more_test`, `online_album_header_test`, `online_playlist_screen_test`, `online_pages_test` | cuore di collezione con «Annulla» (D-724); cuore nascosto senza uuid (D-726) |
| Azioni del brano | `track_actions_test`, `track_sheet_61_test`, `track_row_selection_test` (c'è già Ctrl/Maiusc+clic), `online_song_row_test`, `cc_action_sheet_test` | tasto destro (`kSecondaryButton`); coda presa dalla lista visibile; icone unificate |
| Fogli e dialoghi | `cc_sheet_test`, `sheet_over_dock_test`, `*_characterization_test` | stessa chiamata: foglio sul telefono, dialogo sul desktop, stesso risultato |
| Tabella dei brani | `all_tracks_screen_test`, `alpha_scroller_*` | colonne, ordinamento dall'intestazione, Ctrl/Maiusc nella tabella |
| Shell e scorciatoie | `shell_keys_test`, `app_shell_test`, `shell_nav_test`, `shell_tabs_test`, `focus_test` | mappa completa delle scorciatoie (con Ctrl+L), tasti laterali del mouse, anello di focus |
| Impostazioni e aggiornamento | `settings_*`, `update_tiles_test`, `update_check_test`, `desktop_update_test`, `update_target_test` | «Chiudi nella barra di sistema» (D-729); comando `flatpak install --user` (D-722) |
| Curiosità | `curiosity_provider_test` | nessuna richiesta mentre MusicBrainz è in pausa (F-215) |
| Runner, flatpak | — | istanza unica, «Apri con», runtime 25.08: solo integrazione e build |
| Gesti del telefono (D-721) | scorrimento in coda, pressione lunga, doppio tocco, seek ad arco, trascinamento | anteprima dalla copertina sulle righe online; indietro |

## Test di caratterizzazione, prima di toccare il codice
Un comportamento per test. Si scrivono nella prima fase di ogni area e devono essere verdi sul codice di oggi; quelli di un comportamento nuovo (tasto destro online, cuore online) nascono nella fase che lo introduce.
- `test/ui/home_screen_test.dart`: una tile apre la sua destinazione; «Tutti» raggiungibile dove c'è oggi.
- `test/ui/resume_rows_test.dart` (nuovo): tocco su una voce del Riprendi riprende da lì.
- `test/ui/now_playing_test.dart`: il cuore alterna il preferito con «Annulla» (brano locale).
- `test/ui/desktop_player_bar_test.dart` (nuovo): play/pausa, avanti, indietro, cuore, volume.
- `test/ui/all_tracks_screen_test.dart` (e album, playlist): suonando da una riga la coda è la lista visibile, nell'ordine, con l'indice giusto.
- `test/ui/cc_sheet_test.dart`: valore restituito dal foglio (base per il dialogo desktop).
- `test/ui/shell_keys_test.dart`: mappa tasto → azione di oggi (Spazio, Ctrl+frecce, Ctrl+↑/↓, Ctrl+F, Alt+←, Esc).
- `test/ui/collection_header_test.dart`: azioni dell'intestazione di oggi (play, casuale, scarica, Condividi, ⋮).
- `test/providers/curiosity_provider_test.dart`: comportamento in pausa (fissato, poi corretto da F-215).
- `test/ui/phone_gestures_d721_test.dart` (nuovo, `debugIsDesktopOverride = false`): scorrimento in coda, pressione lunga e tocco in selezione, tocco e doppio tocco, seek ad arco, anteprima dalla copertina, indietro.
- `test/ui/a11y_guidelines_test.dart`: aggiungere home e libreria desktop (`debugIsDesktopOverride = true`, 1280 px).

## Goldens
- Oggi ~150 PNG: `phone_100/150/200` (360×800) e `desktop_100/150` (1280×800), `TolerantComparator` 0,5 %, solo Linux.
- Nuovi: `ShotSize` con 1000, 1440, 1920 px; 9 schermate (home, libreria, tutti i brani, album, playlist, cerca, impostazioni, player, ascolto) × 3 = 27, più 5-6 telefono a 360 dp.
- Baseline congelata prima del restyling; una rigenerazione per fase (`flutter test --update-goldens test/goldens`, solo Linux).

## Integrazione Linux (D-719)
- `integration_test/desktop_flow_test.dart` con `AppUnderTest` (`integration_test/support/app_driver.dart`): avvio a 1280×800, ogni voce della barra laterale, scansione di una cartella, play e barra del player, tasto destro, Ctrl/Maiusc+clic, scorciatoie, tasti laterali del mouse, ridimensionamento a 1000 e 1920. Niente audio vero (sinusoide del driver, volume basso).
- Job `integration-linux` in `ci.yml` (`needs: check`, saltato per le PR di sola documentazione): apt di `build-linux` più `xvfb`, `flutter config --enable-linux-desktop`, `xvfb-run -a -s "-screen 0 1920x1080x24" flutter test integration_test/desktop_flow_test.dart -d linux`. Stima 12-15 min.

## Metriche di arrivo
| Metrica | Partenza | Soglia | Comando |
|---|---|---|---|
| Analisi statica | 0 problemi | 0 | `flutter analyze` |
| Eccezioni di accessibilità | `_known` con 3 voci dopo la 150 (2 + i comandi densi della barra desktop) | non cresce oltre 3; 152 e 157 chiudono la voce della barra | `flutter test test/ui/a11y_guidelines_test.dart` |
| Goldens desktop a 1000/1440/1920 | 0 | ≥ 27 | `ls test/goldens/desktop_w*.png \| wc -l` |
| Avvio a freddo Linux (release, Xvfb) | 4,4 s prima volta, 2,3 s dopo | non peggiora oltre il 10 % | `xvfb-run` + tempo alla finestra (locale o notturno) |
| RSS dopo la libreria (2263 album) | 618 MB | ≤ 680 MB | `ps -o rss= -p <pid>` dopo il giro della libreria |
| Integrazione desktop | assente | verde | job `integration-linux` |

## Comportamento invariato
Stessi test verdi (suite in CI); gesti e navigazione del telefono identici (`phone_gestures_d721_test`); stessi dati (nessuna migrazione, D-721); stessa coda quando si suona da una lista; i soli cambi sono quelli in `decisioni.md` D-714..D-732.
