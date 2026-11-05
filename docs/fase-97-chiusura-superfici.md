# Fase 97 — Chiusura del refactor «superfici-e-ricerca»

**Obiettivo:** misurare il risultato, provarlo a mano sui due telefoni, far rivedere l'architettura e chiudere la documentazione.

**Prerequisiti:** fasi 87–96 chiuse. Mockup approvati (D-416) in `refactor/superfici-e-ricerca/mockup/`. Decisioni D-397, D-398, D-416. Area a rischio: tutto il diff 87–96 (review Opus).

**Comando mirato:** `flutter test test/ui/app_shell_test.dart test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/home_screen_test.dart test/ui/search_screen_test.dart test/ui/smart_playlists_test.dart test/ui/podcast_screens_test.dart test/ui/button_tap_sweep_test.dart test/ui/a11y_guidelines_test.dart test/ui/talkback_labels_test.dart test/services/backup` (la suite completa la esegue la CI).

## Task

### 97.1 — Misure finali (D-398)
- Stessi scenari della base della 87 su Motorola edge 40 (ZY22HKD85K) e Mi A3 (0d7ae9df206e): `python3 scripts/perf_device.py <id> --label finale --playback --only "…"` (Pallino schede, Tutti i brani, Album, Libreria Tutto→Playlist→Album→Artisti, Ricerca «notte», isola, lente, barra che si ritrae, cambio scheda con reset) e avvio a freddo.
- Soglie: Motorola frame > 16,7 ms ≤ 3 % e build p99 ≤ 16 ms; Mi A3 ≤ 6 % e non peggio della base di oltre un frame; avvio a freddo pari alla base (2415–2575 ms).
- Tabella prima/dopo in Esiti e in `docs/refactor/superfici-e-ricerca/analisi.md` (sezione «Stato finale»). Scenario fuori soglia → correzione prima di chiudere, o decisione esplicita in `docs/decisioni.md`.

### 97.2 — Prova a mano guidata
- Su entrambi i telefoni, via adb (aprire ogni schermata, screenshot letti e poi cancellati): Home, Tutti i brani, Libreria (isola, lente, schede), nuova playlist, playlist con Ordina per, playlist intelligente (esistente e nuova), Cerca (libreria, fonte, artisti/album), artista unito, Podcast (Scopri, YTM), Tema (sfocatura), reset delle schede, dock flottante con l'ultima riga leggibile.
- Confronto con ogni mockup (`mockup/indice.html`); differenze elencate qui, ciascuna «corretta» o «accettata» con motivo. Log senza eccezioni; backup → ripristino su profilo pulito; poi ripulire i telefoni.

### 97.3 — Review di architettura (Opus)
- Review sul diff 87–96 (confini dei livelli, provider, migrazioni, rete e budget, componenti condivisi, test inutili). Bug corretti subito; il resto in una lista di debito in Esiti, con priorità.

### 97.4 — Documentazione
- `docs/02-architettura.md` aggiornato (shell, intestazione/isola, regole con `RuleIn`, dati nuovi, alias artisti, Podcast, Cerca); `docs/prossimi-lavori.md` §4 con i punti 3 e 4 chiusi; `docs/PROGRESS.md` e `docs/00-INDICE.md`. `python3 scripts/check_docs_links.py` pulito.

### 97.5 — Controlli di fase
`flutter analyze`; comando mirato; golden tutti rigenerati (`scripts/shots.sh`) e rivisti; build lite (`CODECORE_YOUTUBE=false`) compila; scheggia in modalità fase sui due telefoni; code-review high sul diff della sola 97.

**Fatto quando:** misure, prova a mano, review e documentazione sono scritte qui e la PR è in auto-merge.

## Esiti
