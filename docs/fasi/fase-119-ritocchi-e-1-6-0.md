# Fase 119 — Ritocchi e versione 1.6.0

## Obiettivo
Sette ritocchi di UI (Registro, swipe, selezione, sfocatura, trasparenza dei temi, pulsanti del brano suggerito). Chiude con la versione 1.6.0 e la Release, dopo la fase 118 «Guardrail e correzioni» ([fase-118](../storico/fasi/fase-118-guardrail-e-correzioni.md)), che ha preso i download pubblici (D-559). Viene prima della CI Windows.
Fuori: spostare i download già in `Android/data` (D-547), la selezione multipla delle card di album, playlist e artisti (D-550), un'impostazione per scegliere la cartella dei download.

## Riferimenti
- Decisioni D-547..D-553, D-554 (download), D-555, D-556 (divisione in due fasi), D-559 (download pubblici spostati nella 118). Richieste: `.claude/obiettivi/2026-11-11-richieste-utente.md`.
- Aree: [`piattaforme.md`](../architettura/piattaforme.md), [`riproduzione-e-coda.md`](../architettura/riproduzione-e-coda.md), [`ui-e-design.md`](../architettura/ui-e-design.md).

## Requisiti
| ID | Requisito | Pri | Criterio di accettazione |
|---|---|---|---|
| R-218 | Registro: con un tema che ha un'immagine o un gradiente di sfondo, l'intestazione fissa dei giorni mostra lo stesso sfondo della pagina (D-548) | I | test widget o golden: con `pageBackdrop` attivo l'intestazione non dipinge un riquadro `cc.bg` pieno |
| R-219 | Registro: una voce per ogni brano che non parte (titolo e motivo); se lo stesso brano fallisce più volte di fila, la voce è una sola (D-549) | I | test: due `PlaybackFailure` dello stesso brano di fila danno una sola voce; uno di un altro brano ne dà una seconda |
| R-220 | Lo swipe per mettere in coda funziona in ogni lista di brani, compresi i brani online: daylist (propri e suggeriti), playlist online, Suggeriti e righe online di `LiveTrackRow`. Le varianti coda e scelta restano senza | I | test widget: lo swipe sulla riga della daylist e su una riga online chiama la messa in coda |
| R-221 | Lo swipe per la coda si ferma a circa 3/5 della larghezza della riga: la riga non scorre oltre (comportamento nuovo, non un bug) | I | test widget: trascinando oltre il bordo, lo spostamento della riga non supera il 60 % della larghezza |
| R-222 | Selezione multipla: le righe dei brani (locali e online) mostrano la copertina e la casella di spunta sopra la copertina, non più in una colonna a parte (D-550) | I | test widget: in modalità selezione la copertina c'è e la casella sta sopra di essa |
| R-223 | `LibraryIsland` segue «Dock e intestazioni sfocati» (`blurredChrome`) come il dock, con lo stesso effetto (sfocatura 20 e `surface2` all'alfa 0,78), estratto in un widget comune | I | test widget: con `blurredChrome` attivo c'è un `BackdropFilter`, spento non c'è |
| R-224 | Editor del tema avanzato: Superficie 1, 2 e 3 hanno un cursore di trasparenza (minimo 20 % di opacità); i controlli di contrasto usano il colore composto sopra lo sfondo; le altre voci restano opache (D-551) | I | test: alfa salvata e riletta da `CustomTheme` per le superfici; sotto il 20 % si ferma al 20 %; il testo resta opaco |
| R-226 | Player di un brano suggerito: i tre pulsanti Scarica, Aggiungi a playlist e Non mi piace sono blocchi con superficie (`surface2`), angoli arrotondati (raggio delle card) e 8 px fra l'uno e l'altro, come nel mockup `docs/storico/refactor/ascolto-quotidiano/mockup/player-suggerito.html` (`.tiles button`, alti 64 px) (D-555) | I | test widget: ogni pulsante di `SuggestedInfo` ha uno sfondo `surface2` con bordo arrotondato; golden aggiornato se c'è |
| R-225 | Versione 1.6.0, CHANGELOG, tag `v1.6.0` e Release (D-553) | I | `gh release view v1.6.0` mostra i pacchetti |

## Architettura
- **Registro (R-218, R-219)**: `_DayHeader` non dipinge `cc.bg` quando c'è `pageBackdrop`, ma lo stesso sfondo della pagina (il backdrop ritagliato, per esempio con `pageBackdrop` dietro l'intestazione allineato alla pagina). Gli errori: un nuovo `ActivityKind.playback` (o una voce diretta via `ActivityLogNotifier.add`) che ascolta `playerErrorsProvider`; testo localizzato nelle 6 lingue.
- **Swipe (R-220, R-221)**: `SwipeToQueue` riceve una callback, non un id; `OnlineQueueRow` dentro `LiveTrackRow`, le righe della daylist, `online_playlist_screen` e `suggestions_screen` la usano (`enqueueOnline` per i brani online). Limite: il trascinamento si ferma al 60 % (Dismissible non lo permette: un `GestureDetector` orizzontale con offset limitato, oppure un clamp sul `Dismissible`); la soglia per mettere in coda resta 0,3.
- **Selezione (R-222)**: in `TrackRow` e `OnlineSongRow` la `SelectionBox` va in uno `Stack` sopra `CoverImage`; la colonna di 40 px resta per il numero fuori dalla selezione.
- **Sfocatura (R-223)**: un widget `BlurredChrome` (estratto da `bottom_bar.dart:128-148`) usato dal dock e da `LibraryIsland`.
- **Trasparenza (R-224)**: `CustomTheme.withColor` e `fromJson` tengono l'alfa solo per surface1/2/3 (con limite 0x33); `CcColorPicker(allowAlpha: true)` solo su queste tre voci; contrasto con `Color.alphaBlend(surface, bg)`.

## Rischi
| Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|
| Superfici trasparenti rendono illeggibili testi su sfondi con immagine | minimo 20 %, contrasto calcolato sul colore composto | avviso di contrasto che non scatta con un'immagine chiara |
| Regressioni dello swipe (gesto di sistema «indietro», scroll verticale) | si tiene il bordo `edge` attuale e la soglia 0,3; test widget | swipe che parte scorrendo in verticale |

## Task
- [ ] 119.1 Ritocchi UI: Registro (sfondo ed errori di streaming), swipe ovunque fino a 3/5, spunta sopra la copertina, sfocatura dell'isola, trasparenza delle superfici, pulsanti del brano suggerito (R-218..R-224, R-226)
  - File: `activity_log_screen.dart`, `activity_log_providers.dart`, `activity_providers.dart`, `track_row.dart` (`SwipeToQueue`, `TrackRow`), `online_song_row.dart`, `online_queue_row.dart`, `daylist_screen.dart`, `online_playlist_screen.dart`, `suggestions_screen.dart`, `bottom_bar.dart`, `library_island.dart`, nuovo widget comune per la sfocatura, `theme_editor_screen.dart`, `custom_theme.dart`, `lib/ui/screens/now_playing/suggested_info.dart` (`_Tile`), ARB (6 lingue) per la voce di errore
  - Passi: uno per requisito, ognuno col suo test widget; lo swipe con un limite al 60 % e la soglia 0,3 invariata
  - Comando mirato: `flutter test <test toccati> test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` + golden se cambiano (`scripts/guardie.sh`)
  - Fatto quando: i criteri di R-218..R-224 e R-226 verdi; prova a vista sul Mi A3 (swipe in daylist e Cerca, selezione, isola sfocata, tema con superfici trasparenti, un brano che non parte con la rete spenta nel Registro)
- [ ] 119.2 Rilascio 1.6.0 (R-225)
  - File: `pubspec.yaml` (1.6.0+8), `CHANGELOG.md`, documenti d'area (`sync-backup-jam.md`, `piattaforme.md`, `ui-e-design.md`), `prossimi-lavori.md`
  - Passi: dopo il merge della PR della fase 119 (117 e 118 già fuse): tag `v1.6.0` su master e Release dal workflow esistente (come D-544)
  - Fatto quando: `gh release view v1.6.0` con APK, Linux, Windows, macOS

## Tocca a te
- A fine fase, sul Motorola: aggiorna FreeKmusic con l'APK della Release 1.6.0 (stessa firma) e rifai «Unisci» col backup di Codecore (fase 117). Controlla temi, statistiche, copertine, tag, playlist smart e podcast. Poi puoi disinstallare Codecore: i file rimasti nella sua cartella `Android/data` verranno cancellati (D-547).

## Note di deviazione
