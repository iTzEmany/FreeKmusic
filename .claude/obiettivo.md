# Profilo obiettivo — Codecore (Flutter)

> Letto da `/obiettivo` all'avvio. Ricavato il 2026-10-25 da CLAUDE.md, ci.yml, memorie e git log.

## Documenti da leggere all'avvio
- `CLAUDE.md`, `docs/01-regole-di-lavoro.md`, `docs/PROGRESS.md`, `docs/decisioni.md`, `docs/handoff.md`, `docs/gotchas.md`
- Feature in corso: `docs/feature-riconoscimento.md` (fasi 69c–69e, prima della 70), poi `docs/feature-jam-distanza.md` (fasi 70–73) e solo il `docs/fase-N-*.md` corrente; `docs/feature-streaming-veloce.md`, `docs/feature-streaming.md` e `docs/feature-arricchimento.md` solo se servono

## Modalità
- **PR**: ramo da `origin/master` → PR → `gh pr merge --auto --squash`. **Una PR per fase, un commit per task** (memoria).
- Ramo base: `master` · rami `<tipo>/<descrizione>` · commit Conventional Commits, descrizione in italiano o inglese breve (`feat(45): …`)
- Check obbligatorio: «Analyze and test» (build_runner + gen-l10n senza diff, check_docs_links, analyze, suite completa)

## Verifica
| Livello | Comando | Stima |
|---|---|---|
| mirata | `flutter test <file…>` | 2m |
| statica veloce | `flutter analyze` | 2m |
| codice generato | `dart run build_runner build --delete-conflicting-outputs` (solo tabelle drift) · `flutter gen-l10n` (ARB) | 4m · 1m |
| suite completa (CI; in locale solo se chiesta) | `flutter test` | 6m |
| build | `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH flutter build apk --debug` (senza JAVA_HOME Gradle esce subito) · `flutter build linux` | 8m · 10m |
| perf sul Mi A3 | `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label <l> --playback` | 40m |

## Parallelismo
- Implementer insieme: 3 · comandi pesanti con `sorveglia.sh --pesante` · passi in parallelo solo con disco libero ≥ 20 % (oggi 9 %: in sequenza)

## Pulizia (solo con `pulizia.sh via`)
| Quando | Cosa |
|---|---|
| dopo ogni passo fuso | `build/app/outputs/apk`, `build/perf/*` già riportati in misure.md, log in scratchpad |
| a fine fase | `build/linux` se la fase dopo non lo usa |
| disco ≥ 90 % | `build/app/intermediates`, `build/test_cache`, `build/bench`, `build/perf_library` (la rifà `perf_device.py`), `.dart_tool/flutter_build` (6 GB, cache dei test e delle build, si rifà da sola) |
| mai | `build/metadata_god` (Rust, lungo da rifare), `~/.pub-cache`, file musicali del telefono |

## Regole extra del progetto
- **App desktop su Linux (prove, misure, scheggia): sempre su uno schermo virtuale, mai sullo schermo dell'utente** (lavora sull'unico monitor, 27/10). Comando: `HOME=<scratch>/home env -u WAYLAND_DISPLAY GDK_BACKEND=x11 xvfb-run -a -s "-screen 0 1280x800x24" <comando>`; `xdotool` e screenshot solo dentro quel `xvfb-run` (il suo `DISPLAY`). Mai `wpctl`/volume generale del PC; l'audio esce dalle casse vere: volume basso dall'app. Integration test su Linux: stesso `xvfb-run`.
- Aree a rischio (`/code-review high`): audio handler (`codecore_audio_handler.dart`), query su `tracks` (righe ombra K-02), protocollo Jam; dalla fase 50: migrazione v15, backup e ripristino, `EnrichmentService` (arricchimento di oggi), query delle liste e della ricerca, chi scrive le copertine; dalla fase 65: ordine della coda della Jam (`jam_state.dart`, `jam_turns.dart`, `jam_part_feeder.dart`), lato nativo Bluetooth e permessi del manifest (fase 67); dalla fase 69: protocollo e crittografia della Jam a distanza (`lib/services/jam/remote/`, review Opus del protocollo), `admitRequest`/`JamGate`, `JamSecretStore` e regole di backup, `JamBeaconBridge.kt`, servizio in primo piano; dalla fase 69c: riconoscimento del brano (`EnrichEngine._gather` col riconoscimento, `lib/services/recognition/`, unico punto di scrittura di `track_enrich.details`, `TrackCorrections`/`TrackEditor.save(markEdited)`), Rust/FFI di `third_party/metadata_god` (impronta, `read_ids`, cargokit Android), lettore di tag
- Nessun pacchetto nuovo (fasi 45–54); dalla fase 69 solo `sodium` e `mqtt_client` (D-251, D-252). Schema DB: v15 nella fase 50; v16 nella fase 93 (tabelle `track_genres` e `artist_countries`, D-390); v17 nella fase 95 (tabelle `artist_aliases` e `artist_not_same`, D-402, D-414); v18 nella fase 96 (fonte dei podcast YouTube Music, D-404); ogni volta in un solo passo; poi invariato
- Chiamate dal vivo a Deezer, MusicBrainz, NetEase, lyrics.ovh solo per salvare le risposte di test (fixture), mai nella suite
- **Misure sul telefono** (`perf_device.py`, 15–40 min col turno dei comandi pesanti): si lanciano dopo i test mirati dell'ondata, mai mentre lavorano gli implementer, che resterebbero in coda dietro di loro.
- Telefono Mi A3 (`0d7ae9df206e`): **di test**, ci si fa quello che si vuole (installare sopra, creare, cambiare e cancellare dati e brani); Jam e prove fra dispositivi solo con altri dispositivi di test e istanze Linux avviate dall'agente (D-91)
- Telefono Redmi Note 9 Pro (`8bbad1cd`): **di test solo per l'app** (D-502): installarla, cancellarne i dati, copiare brani di prova; **mai** toccare, leggere o cancellare i file già presenti (foto, documenti in `/sdcard/Download`); a fine prova togliere ciò che si è messo. Playlist di prova: `~/Downloads/Liked_Songs.csv` (Exportify, 2253 brani, D-503)
- Motorola edge 40 (`ZY22HKD85K`, libreria vera) nelle fasi 50–54 e 55–57 (D-125, D-126, D-146): APK debug e prove con i brani presenti; prima chiedi all'utente un backup completo dall'app; firma diversa → fermati, backup confermato, poi `uninstall -k` e ripristino; mai cancellare file musicali

## Risparmio di token (dalla fase 51: 27,7M, metà nella chat principale)
- **Chat principale**: fuori dalle aree a rischio leggi solo `git diff --stat` e l'esito del reviewer, mai il diff intero. Niente log lunghi in chat: la CI rossa va subito a `github-ci` con il numero della PR. Raggruppa i controlli in una sola chiamata Bash. A fine fase aggiorna `docs/handoff.md` e chiudi l'obiettivo, invece di proseguire fino alla compattazione.
- **Task**: sotto la mezz'ora di lavoro (una sezione di schermata, un gruppo di ricerca, testi ARB) si accorpa al task vicino della stessa ondata. Al massimo 3–4 task per fase.
- **Scheggia**: in modalità passo con effort `medium`, `high` solo nelle aree a rischio qui sopra. In modalità fase solo se la fase tocca aree a rischio. Per una fase di sola UI la saltiamo: la prova a vista è già nel passo «tuo» (es. 51.9).
- **Review**: `/code-review high` solo sulle aree a rischio. La review di architettura di fine fase la fa Sonnet con effort high se la fase non tocca schema, backup o protocollo Jam; Opus negli altri casi.
- **Test mirati di ogni task UI**: aggiungi sempre `test/ui/no_separator_literals_test.dart` e `test/ui/architecture_test.dart`, perché girano in pochi secondi (la CI era rossa in #30 per un `' · '`).
- **Prompt degli implementer**: dai i simboli esatti da codegraph (file, nome, riga) e i test da scrivere, così l'agente non esplora da solo.

## Stime misurate
- `sorveglia.sh`: la stima vuole l'unità (`6m`); un numero nudo vale secondi (2026-10-25). `pr-attendi.sh` invece vuole i minuti come numero nudo (`15`): `15m` stampa l'uso ed esce con 2 (2026-10-26)
- 54.8 (36 file di test mirati, 773 test) ~ 2m20 (2026-10-26)
- `flutter test test/services/audio/ test/providers/` ~ 1m30 (2026-10-25)
- Toccando `lib/ui`: lancia sempre anche `test/ui/architecture_test.dart` (la UI non usa repository né `databaseProvider`; CI rossa in #19)
