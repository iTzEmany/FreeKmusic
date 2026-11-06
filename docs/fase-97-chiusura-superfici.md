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
- **97.1 Misure (Mi A3)**: 16 scenari su 16 entro soglia (tabella in `refactor/superfici-e-ricerca/analisi.md`, «Stato finale»). Avvio a freddo: mediana 2767 ms su 5 (base 87 2697 ms; la banda 2415–2575 ms del doc è più stretta della base misurata nella 87): pari alla base, accettato. Scansione di 3000 brani 30,7 s contro 14,5: causa i generi scritti brano per brano (fase 93), corretta con `TrackGenreRepository.replaceMany` (desktop 23,7 → 14,3 s, base 14,6). **Motorola: misure all'utente** (comando nel resoconto finale).
- **97.2 Prova a mano (Mi A3)**: nessun crash, log senza errori. Differenze dai mockup:
  - *corrette*: il dock copriva i fogli sul telefono (ora `showCcSheet` apre sempre sul navigatore radice); «Nella tua libreria» stava sotto le righe Artisti e Album (ora in cima, D-399); Impostazioni → Artisti uniti mostrava gli ID di canale delle coppie «diversi» (ora i nomi).
  - *accettate*: «Casuale su tutto» su una riga; sottotitoli con la virgola invece del «·» (regola del progetto); niente striscia A–Z con 69 brani; chip con icone in Tutti i brani; in playlist «Ordina per» sta nel menu a tre puntini (niente etichetta «Artista ↑» accanto al conteggio); nell'editor intelligente «Ordina per» e «Limite» nel corpo, non nel piede; il filtro di Cerca si chiama «Tutte»; nella ricerca podcast niente filtro per fonte (fase 96); Tema senza anteprima Opaco/Sfocato né «Riporta ai valori di serie». Più le differenze già scritte negli Esiti delle fasi 94–96.
  - *non provato sul Mi A3*: pagina artista con profili uniti, editor di una playlist intelligente esistente, Podcast YouTube Music con episodi, backup → ripristino su profilo pulito (coperto dai test di `test/services/backup`). **Motorola: prova all'utente.**
- **97.3 Review di architettura (Opus)**: due bug corretti (un genere con «/» o «;» in una regola perdeva i brani riletti, D-397; la pausa dopo un 429 dei podcast YTM non era condivisa con Cerca) e sei punti economici (indice con IF NOT EXISTS, `rejoin` con un solo elemento, costante del debounce fuori dai token UI, rilettura in pausa durante la riproduzione, test senza richieste ad Apple). Il debito rimasto, con priorità, è in `prossimi-lavori.md` §6.
- **97.4 Documenti**: `02-architettura.md` (sezione «Superfici e ricerca»), `03-modello-dati.md` (v16–v18, backup), `prossimi-lavori.md` (§4 punti 3–4 chiusi, §6 debito); `check_docs_links.py` pulito.
- **97.5 Controlli**: `flutter analyze` pulito; test di UI, golden, dati, provider, libreria, tag, podcast e l10n verdi (2586); build lite (`CODECORE_YOUTUBE=false`) compila; code-review high sul diff della 97: 6 rilievi corretti, 3 nel debito (IF NOT EXISTS per gli indici prima della v15, `watchNames`, rilettura che non finisce con la musica sempre accesa).
- **Scheggia di fase (Mi A3)**: nessun bug. Fogli aperti da dieci punti (Libreria, playlist, azioni del brano, coda, Casuale+, dispositivi, radio, editor intelligente): coprono il dock, Indietro chiude solo il foglio, «Vai all'artista/album» apre la pagina con il dock, un doppio tocco apre un foglio solo. Cerca «Dylan»: «Nella tua libreria» in cima con «Mostra tutti (4)». Regola `genere = R&B/Soul` e la sua negazione corrette. Riscansione senza errori, nessuna rilettura dei generi durante la riproduzione. Log senza errori nuovi.
- **Motorola edge 40 (prova veloce concessa dall'utente)**: app vera aggiornata con `install -r`, dati intatti; fogli sopra il dock e «Nella tua libreria» in cima confermati; nessun crash. Le misure non sono partite: su Android 15 la cartella della libreria di prova creata da `adb push` dentro `Android/data/com.codecore.player.perf` non è leggibile dall'app (`Permission denied`). Da sistemare in `scripts/perf_device.py` prima di rimisurare il Motorola (per esempio copiare con `adb exec-in run-as … tar` in una cartella creata dall'app).
