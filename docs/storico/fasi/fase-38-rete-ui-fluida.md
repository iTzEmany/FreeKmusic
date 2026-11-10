# Fase 38 — Rete di sicurezza (refactor «ui-fluida»)

**Obiettivo:** prima di toccare `lib/ui/`, avere (1) gli strumenti di misura che funzionano, (2) i test che fissano il
comportamento di oggi, (3) le misure di partenza. Nessun codice di prodotto cambia in questa fase: solo `scripts/`,
`integration_test/`, `test/` e documenti.

**Prerequisiti:** fasi 1–37 chiuse. Analisi in `docs/refactor/ui-fluida/analisi.md` (sezione «Rete»), decisioni D-01..D-30
in `docs/decisioni.md`. Il refactor va in 7 fasi (D-30): 38 rete · 39 fluidità · 40 accessibilità e token · 41 mattoni ·
42 livelli e tipi · 43 nuovo aspetto · 44 chiusura. Ordine voluto dall'utente: fluidità sul telefono prima (D-09).

**Nomi dei test:** quelli scritti nelle fasi 38–44 sono indicativi; se per quel comportamento esiste già un file in `test/`, si estende quello.

**Principio:** i test di caratterizzazione fissano **anche i difetti noti** (es. il salto dei testi sincronizzati).
Devono passare **oggi**, sul codice com'è. Chi poi cambia il comportamento li aggiorna nello stesso passo.

## Intoccabili (D-07), valgono per tutte le fasi 38–44
- Dati salvati: schema del DB, chiavi delle impostazioni, file di tema e di backup.
- Nessun pacchetto nuovo.
- Protocolli LAN, Jam e sync compatibili con gli APK già installati.

## Dispositivi
- **Mi A3** `0d7ae9df206e`: solo con l'app separata `com.codecore.player.perf` (D-19), build profile.
  `JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14`.
- **Motorola** `ZY22HKD85K`: ha la libreria vera. Nessuna scrittura, nessuna disinstallazione.
- Comandi pesanti (build, perf) sempre con
  `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante <stima> <log> -- <comando>`.

## Come si misura (comando unico)
```
python3 scripts/perf_library.py                                  # una volta: libreria di prova
python3 scripts/perf_device.py 0d7ae9df206e --label <nome> --playback [--no-push] [--runs N] [--no-build] [--apk file]
```
Risultato in `build/perf/<label>.md`. `--no-push` tiene la libreria già scansionata; `--runs` sono gli avvii a freddo (5).

## Soglie di arrivo (dalla «Rete»)
| Metrica | Soglia | Oggi |
|---|---|---|
| Pallino schede, frame > 16,7 ms | ≤ 2 % | 4,6 % |
| Tutti i brani | ≤ 1 % | 1,4 % |
| Album | ≤ 0,6 % | 0,6 % |
| Ricerca «notte» | ≤ 3 %, build p99 ≤ 16 ms | 9,8 %, 51,6 ms |
| Apri album / torna | ≤ 3 % | da misurare (38.2) |
| Fogli | ≤ 3 % | da misurare (38.2) |
| Swipe del mini player | ≤ 2 % | da misurare (38.2) |
| Apertura del player | ≤ 3 %, p99 ≤ 33 ms | 40,8 ms (22/10) |
| Avvio a freddo | ≤ 2400 ms | 2363 ms |
| PSS | ≤ 210 MB | 201 MB |

Struttura (grep su `lib/ui`, `build` con `scripts/build_len.py`): `databaseProvider\|RepositoryProvider` 0 (oggi 74 righe /
44 file) · `SnackBar(` 1 (106) · `AppBar(` 1 (48) · `Duration(milliseconds` ≤ 3, solo nei token (28) · `build` ≤ 120
righe, 0 oltre 150.

## Comportamento invariato (criteri per tutto il refactor)
- La CI resta verde.
- `lib/data`, provider, servizi, Jam e l10n non cambiano (salvo dove una fase lo dice).
- I golden restano identici, salvo nei passi di redesign o dei token (D-20).
- `integration_test` gira prima e dopo il gruppo C (fase 42) e alla chiusura.

## Task

### 38.1 — Strumenti di misura riparati
1. `scripts/perf_device.py:226`: la navigazione è cambiata con Anello e `tap('^Tutti i brani')` dopo la ricerca fallisce
   («nothing on screen matches '^Tutti i brani'»). Aggiornare il percorso alla navigazione di oggi (dock, scheda
   Libreria, voce «Tutti i brani»). Nessuna modifica a `lib/`.
2. `integration_test/perf_test.dart:67`: `find.text('Libreria').last` fallisce su Linux (cerca l'etichetta della shell del
   telefono). Cercare la scheda in modo che valga per shell telefono e desktop.

**Fatto quando:** `python3 scripts/perf_device.py 0d7ae9df206e --label prova --playback --no-push` arriva in fondo e
scrive `build/perf/prova.md` con «In riproduzione», «Lettore dal dock» e «Anello»; `flutter test integration_test/perf_test.dart -d linux`
non fallisce alla riga 67 (comando via `sorveglia.sh`); `flutter analyze` pulito.

### 38.2 — Scenari nuovi in `perf_device.py`
1. Aggiungere quattro scenari, ognuno ×3 e con il suo nome nel rapporto: **«Apri album»** (apri album/artista e torna
   indietro), **«Fogli»** (apri e chiudi coda, dispositivi e tag), **«Swipe mini player»** (avanti e indietro),
   **«Apertura player»** (dal mini player e dal dock, con build p90/p99).
2. Ogni scenario scrive nel rapporto build/raster p90/p99 e percentuale di frame oltre 16,7 ms, come quelli esistenti.

**Fatto quando:** `python3 scripts/perf_device.py 0d7ae9df206e --label scenari --playback --no-push` produce
`build/perf/scenari.md` con i quattro nomi nuovi e una percentuale per ciascuno (nessun «n/d»).

### 38.3 — Test di caratterizzazione A (transizioni)
`test/ui/transitions_characterization_test.dart`: push e pop di oggi con lo stato che resta; `TabFade` con lo stato delle
schede; swipe del mini player (soglia, ritorno, tap che apre il player); trascinamento che chiude il player; numero di
`Hero` con tag `player-cover` su telefono e su desktop.

**Fatto quando:** `flutter test test/ui/transitions_characterization_test.dart` verde sul codice invariato; `git diff --stat lib/` vuoto.

### 38.4 — Test B (liste e fogli)
`test/ui/lists_sheets_characterization_test.dart`: `LyricsView` sincronizzato (riga giusta con la posizione, tap = seek,
scorrimento automatico, **il salto è fissato come difetto noto**); `QueueSheet` (tap, rimozione, brano corrente); fogli tag,
attività e dispositivi con 30 voci su 360×640. Il caso «con 100 righe non si costruiscono tutte» si scrive come test
atteso-rosso marcato `skip` con motivo «dopo F-30 (39.x)» e si accende nella fase 39.

**Fatto quando:** `flutter test test/ui/lists_sheets_characterization_test.dart` verde; `git diff --stat lib/` vuoto.

### 38.5 — Test C (azioni e strumenti di struttura)
1. `showMsg` e `AsyncBody`: i test si scrivono insieme ai mattoni (fase 41); qui si fissano le **copie di oggi**: le 6
   copie del dialogo del nome a confronto (regole di validazione), selezione di `add_tracks_screen`, `track_picker_screen`
   e `receive_tab`, un test per ognuno dei 9 `PopupMenuButton<String>`, `folders_sheet` e onboarding (nessuna
   scansione dall'onboarding: poi D-12).
2. Azioni su più brani e preferiti contro un DB in memoria; `setLyrics` e `pathsById` si fissano come query di oggi.
3. Tabella id→kind (`isOnlineId`) contro la regola di oggi.
4. `test/ui/architecture_test.dart` con la lista di eccezioni **piena** (tutti i file che oggi usano `databaseProvider` o
   `RepositoryProvider`), così parte verde.

**Fatto quando:** `flutter test test/ui/architecture_test.dart test/ui/selection_characterization_test.dart test/ui/menus_characterization_test.dart test/ui/name_dialogs_characterization_test.dart test/ui/folders_onboarding_characterization_test.dart` verde; `git diff --stat lib/` vuoto.

### 38.6 — Test D (accessibilità) e E (golden nuovi)
1. D: flag di sistema ignorati (fissa il difetto, poi D-14); `a11y_guidelines_test` con `androidTapTargetGuideline`,
   `labeledTapTargetGuideline`, `textContrastGuideline` e lista di eccezioni piena; mini player, dock e car mode al 200 %;
   `contrast_test` esteso a `textFaint` e `accentSoft` (con i valori di oggi).
2. E: golden nuovi di Home desktop, mini player + dock, car mode a 100 e 200 % (generati una volta, D-20).

**Fatto quando:** `flutter test test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart test/theme/contrast_test.dart` e `flutter test test/golden` verdi, golden vecchi identici (`git status test/golden` mostra solo file nuovi).

### 38.7 — Misure di struttura: `scripts/build_len.py`
1. Script che, per ogni widget in `lib/ui`, stampa la lunghezza del metodo `build` e conta le righe sopra 120 e 150.
2. Un comando unico `scripts/ui_metrics.sh` (o un'opzione di `build_len.py`) che stampa anche i grep della tabella
   «Struttura» (`databaseProvider\|RepositoryProvider`, `SnackBar(`, `AppBar(`, `Duration(milliseconds`).

**Fatto quando:** `python3 scripts/build_len.py lib/ui | head` mostra `library_screen.dart` con circa 271 righe; i conteggi coincidono con la tabella (74 righe / 44 file, 106, 48, 28).

### 38.8 — Misure di partenza sul Mi A3
1. Con la rete completa e HEAD pulito: `python3 scripts/perf_device.py 0d7ae9df206e --label ui-fluida-prima --playback`
   (via `sorveglia.sh --pesante`), JAVA_HOME come sopra.
2. Copiare la tabella in `docs/refactor/ui-fluida/misure.md` (colonne: scenario · build p90/p99 · raster p90/p99 · oltre
   16,7 ms · soglia) e le metriche di struttura di 38.7.

**Fatto quando:** esistono `build/perf/ui-fluida-prima.md` e `docs/refactor/ui-fluida/misure.md` con **tutti** gli scenari della tabella delle soglie, avvio a freddo e PSS compresi.
