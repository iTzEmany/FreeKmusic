# Fase 64 — Chiusura (refactor «ui-jam-ricerca»)

**Obiettivo:** dimostrare con i comandi che il refactor ha raggiunto le metriche di arrivo, confrontare le misure con quelle della fase 58 e registrare i risultati.

**Prerequisiti:** fasi 58–63 chiuse. Misure di partenza in `build/perf/ui-jam-ricerca-prima.md` e `docs/refactor/ui-jam-ricerca/misure.md`.
Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`.

**Comportamento invariato:** questa fase non cambia codice di prodotto. Se una misura fallisce, si apre un passo nella fase responsabile
(o si chiede all'utente di accettare la soglia, con una riga in `docs/decisioni.md`).

## Task

### 64.1 — Misure finali sul Mi A3
`python3 scripts/perf_device.py 0d7ae9df206e --label ui-jam-ricerca-dopo --only "Ricerca «notte»,Fogli,Swipe mini player,Apertura player,Anello,Pallino schede"` (app perf, via `sorveglia.sh --pesante`).

**Fatto quando:** esiste `build/perf/ui-jam-ricerca-dopo.md`; in `misure.md` la tabella prima · dopo · soglia · ok/no copre ogni scenario, con le soglie della fase 38.

### 64.2 — Metriche di arrivo
**Fatto quando:** `flutter analyze` senza avvisi; `grep -rn "PopupMenuButton\|showMenu(" lib/ui` e `grep -rn "more_horiz" lib/ui` vuoti;
`flutter test test/ui/architecture_test.dart test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart test/ui/font_scale_test.dart test/ui/large_text_test.dart test/goldens` verde;
il test di rebuild del dock (60.4) verde; `flutter test integration_test -d linux` verde (via `sorveglia.sh`); CI della PR finale verde.

### 64.3 — Prova a mano
Su Mi A3 e Motorola (sola lettura sul Motorola): le quattro richieste dell'utente, cioè Jam come il player con anello e barra, Ricerca (✕, tastiera, dock), ⋮ a foglio in ogni sezione, Home aperta che scorre con i nomi; più la scheda del testo stabile.

**Fatto quando:** esito scritto in `docs/PROGRESS.md` sotto 64.3.

### 64.4 — «Risultati» in `analisi.md`
Nuova sezione «Risultati» in `docs/refactor/ui-jam-ricerca/analisi.md`: per ogni F-01..F-58 stato e commit; tabella prima/dopo; cambi di comportamento avvenuti (D-148, D-150, D-151, D-152, D-153, D-155, D-159, D-160, D-161); soglie non raggiunte e perché.

**Fatto quando:** `grep -n "^## Risultati" docs/refactor/ui-jam-ricerca/analisi.md` la trova e ogni F-NN vi compare; tutte le caselle 58–64 di `docs/PROGRESS.md` spuntate.

### 64.5 — Pulizia del disco
APK profile e scatti che non servono più, solo con `~/.claude/skills/obiettivo/scripts/pulizia.sh via <percorsi>`. Le misure `build/perf/*.md` restano.

**Fatto quando:** `ls build/app/outputs/flutter-apk/app-profile.apk` risponde «No such file».
