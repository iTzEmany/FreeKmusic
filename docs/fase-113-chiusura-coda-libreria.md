# Fase 113 — Chiusura del refactor «coda-e-libreria»

**Obiettivo:** verificare le metriche di arrivo, provare tutto sui telefoni contro i quattro mockup, far rivedere l'architettura della coda e chiudere la documentazione.

**Prerequisiti:** fasi 107–112 chiuse. Mockup approvati (D-498) in `refactor/coda-e-libreria/mockup/`: `titoli.html`, `libreria.html`, `playlist-ricerca.html`, `coda.html`. Area a rischio: tutto il diff 107–112 (review Opus: `PlayQueue`, handler, persistenza, query su `tracks`, Kotlin).

**Comando mirato:** `flutter test test/services/audio test/services/shuffle_plus test/providers/shuffle_plus_test.dart test/providers/queue_provider_test.dart test/jam test/providers/jam_exit_restore_test.dart test/data/track_repository_test.dart test/data/performance_50k_test.dart test/data/migration_test.dart test/services/backup test/ui/marquee_text_test.dart test/ui/a11y_guidelines_test.dart test/ui/button_tap_sweep_test.dart test/ui/architecture_test.dart` (la suite completa la esegue la CI).

## Task

### 113.1 — Metriche di arrivo
Tutte le soglie di `refactor/coda-e-libreria/analisi.md` «Metriche di arrivo», con comandi e valori in Esiti e in `refactor/coda-e-libreria/misure.md`:

| Metrica | Soglia | Comando |
|---|---|---|
| «Riproduci dopo» sparito | 0 righe | `grep -rniE "playNext\|playOnlineNext\|insertNext" lib test` |
| Statistiche fuori dalla Libreria | 0 righe | `grep -rn "StatsScreen" lib/ui/screens/library` |
| Niente testo che scorre nelle liste | 0 righe | `grep -rn MarqueeText lib/ui/widgets/track_row.dart lib/ui/screens/now_playing/queue_sheet.dart` |
| Invarianti del blocco | 0 violazioni su tutti i semi | test a operazioni casuali di `play_queue_test.dart` |
| Comportamento della coda senza aggiunte | impronta identica | `play_queue_characterization_test.dart` senza modifiche dopo la 107 (`git log --follow` sul file: solo il commit della 107) |
| Prestazioni delle query (50k brani) | dentro le soglie già presenti | `flutter test test/data/performance_50k_test.dart` con la lista nuova e la ricerca senza accenti |
| Scatti nello scroll e col player aperto (Mi A3) | ≤ valori della fase 90 (1–2 % dei frame) e ≤ `prima-107` | `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label dopo-113 --playback` |

- Comportamento invariato (analisi): Jam `flutter test test/jam test/providers/jam_*_test.dart test/ui/jam_*_test.dart` verde senza modifiche ai test e `git diff --stat origin/master -- lib/services/jam lib/providers/jam*` vuoto salvo il titolo in `jam_player.dart`; DB e backup `git diff origin/master -- lib/data/db/tables.dart lib/services/backup` vuoto, `schemaVersion` invariato; Statistiche (schermata, `stats_queries`, blocco in Home) invariate.
- Perf: `--label dopo-113` confrontato con `prima-107` (e `marquee-109`) in `misure.md`; con `sorveglia.sh --pesante 40m`.

### 113.2 — Prova sul Mi A3 e sul Redmi contro i mockup (D-498, D-502, D-503)
- Mi A3 (`0d7ae9df206e`) e Redmi Note 9 Pro (`8bbad1cd`), via adb, APK debug, con `~/Downloads/Liked_Songs.csv` (2253 brani) importato come playlist: i quattro mockup schermata per schermata (`titoli.html`, `libreria.html`, `playlist-ricerca.html`, `coda.html`). Differenze evidenti corrette, minori accettate con motivo e riportate all'utente. Etichette TalkBack verificate con uiautomator (memoria «TalkBack senza prove a mano»), movimento ridotto per i titoli.
- Redmi: regole D-502, **mai toccare, leggere o cancellare i file già presenti** (foto, documenti, `/sdcard/Download`); solo l'app e ciò che si mette.
- Anche la pausa a volume zero della 111 (interruttore, tasti, cuffie).

### 113.3 — Pulizia dei telefoni e dei dati di prova
- Mi A3: togliere la playlist importata da `Liked_Songs.csv` e i dati di prova dell'app; mai i file musicali (D-501).
- Redmi: togliere **solo** ciò che si è aggiunto (l'app, i suoi dati, i brani copiati da noi); nessun altro file.
- Sul computer: `build/perf/*` già riportati in `misure.md`, log, APK e screenshot già usati, solo con `~/.claude/skills/obiettivo/scripts/pulizia.sh via <percorsi>`.

### 113.4 — Review di architettura (Opus)
- Sul diff 107–111: `PlayQueue` (invarianti I1/I2, `_settle`, nessuna operazione che li rompa), handler e persistenza (`lastQueueUser`), Shuffle+ (`skip = userAhead`, `_played`), livelli rispettati (nessuna logica di dominio nuova in `lib/ui`; `MarqueeText` e filtro playlist sono presentazione), nessun lavoro pesante sul thread UI, nessun `catch` muto (`AppLog`), bridge Kotlin di 111 (registrazione e deregistrazione del ricevitore). Bug corretti subito con il loro test; debito in `prossimi-lavori.md` (sezione nuova «coda-e-libreria»).

### 113.5 — Documenti
- `docs/02-architettura.md`: sezione della coda aggiornata (blocco dell'utente, invarianti I1/I2, regole di `enqueue`/`next`/`previous`/`jumpTo`/`move`/Svuota, `lastQueueUser`); `MarqueeText` e «Pausa a volume zero» (`VolumeBridge`) nelle sezioni giuste.
- `refactor/coda-e-libreria/analisi.md` «Stato finale» (come quello di `ascolto-quotidiano`); `docs/prossimi-lavori.md` aggiornato; `docs/PROGRESS.md` spuntato; `docs/00-INDICE.md`; `docs/decisioni.md` con le scelte fatte in autonomia durante 107–113; `docs/handoff.md` riscritto (togliere la sezione «Prossimo: refactor coda-e-libreria»).

### 113.6 — Controlli di fase
`flutter analyze`; comando mirato; `python3 scripts/check_docs_links.py`; scheggia di fase sull'app sul telefono.

**Fatto quando:** metriche rispettate (tabella in Esiti), prova sui due telefoni fatta e telefoni ripuliti, review chiusa, documenti aggiornati.

## Da decidere
(nessuno)
