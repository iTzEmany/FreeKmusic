# Fase 58 — Rete di sicurezza (refactor «ui-jam-ricerca»)

**Obiettivo:** prima di toccare `lib/ui/`, fissare con i test il comportamento di oggi e registrare le misure di partenza.
Nessun codice di prodotto cambia in questa fase: solo `test/`, `scripts/` (se serve) e documenti.
Rilievi di test (D-154): F-19 (Jam e seek), F-27 (Ricerca), F-37 (Home), F-56 (menu) — qui la caratterizzazione; le riscritture di proposito nei passi 59.5, 60.1, 61.1, 62.2, 63.1, 63.3.

**Prerequisiti:** fasi 1–57 chiuse (anche «Streaming veloce», 55–57). Analisi in `docs/refactor/ui-jam-ricerca/analisi.md` (rilievi F-01..F-58, sezione «Rete»),
decisioni D-147..D-162 in `docs/decisioni.md`, mockup approvati in `docs/refactor/ui-jam-ricerca/mockup/`.
Il refactor va in 7 fasi: 58 rete · 59 player e seek · 60 Ricerca e dock · 61 fogli ovunque · 62 Home «aggiunti da poco» · 63 Jam = player · 64 chiusura.

**Nomi dei test:** indicativi; se per quel comportamento esiste già un file in `test/`, si estende quello.

**Principio:** i test di caratterizzazione fissano il comportamento di **oggi**, compresi i difetti che le fasi dopo correggono
(✕ della ricerca che torna indietro, ventaglio che rimpicciolisce, menu fluttuanti). Devono passare sul codice com'è.
Chi poi cambia il comportamento li riscrive nello stesso passo; l'elenco dei test che cambiano di proposito è in analisi «Rete».

## Intoccabili (D-158), valgono per tutte le fasi 58–64
- Protocollo della Jam e formato dei messaggi (compatibili con gli APK installati).
- Dati salvati: schema del DB, chiavi delle impostazioni, file di tema e di backup.
- Scorciatoie (Ctrl+F…), 3 temi × 8 accenti, stile e token di `ui-fluida` (D-21, D-23).
- Nessun pacchetto nuovo.

## Dispositivi
- **Mi A3** `0d7ae9df206e`: misure solo con l'app separata `com.codecore.player.perf` (D-19), build profile, `JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14`. Si può disinstallare con `-k`; mai cancellare i file musicali.
- **Motorola** `ZY22HKD85K`: libreria vera; solo `install -r` e `--real` (sola lettura). Mai disinstallare né `pm clear`.
- Su entrambi: mai toccare rotazione o impostazioni di sistema.
- Comandi pesanti (build, perf, integration test) sempre con `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante <stima> <log> -- <comando>`.

## Task

### 58.1 — Seek di oggi
`test/ui/seek_characterization_test.dart`: angolo → posizione sull'anello, vuoto di 40°, seek solo al rilascio; slider desktop
(`desktop_player_bar.dart`) che durante il trascinamento mostra la posizione del dito; `JamSeekBar` dell'ospite che invia `JamCommand.seek(ms)`.

**Fatto quando:** `flutter test test/ui/seek_characterization_test.dart` verde.

### 58.2 — Jam di oggi
In `test/jam/jam_state_test.dart` separare in casi distinti la parte dell'host di `next`/`jump` (indice, `playing`, versione),
che resta, da quella dell'ospite (`JamError.forbidden`), che la fase 63 cambia. Coprire lo swipe che accoda nella Jam
(`jam_screen_test.dart:215`) e il formato dei messaggi `next`/`jump` (serializzazione invariata).

**Fatto quando:** `flutter test test/jam test/ui/jam_screen_test.dart` verde.

### 58.3 — Ricerca di oggi
Testo conservato chiudendo la tastiera a mano e cambiando scheda; ✕ della pagina desktop che svuota e resta (estendere `app_shell_test.dart` o `search_screen_test.dart`).

**Fatto quando:** `flutter test test/ui/app_shell_test.dart test/ui/search_screen_test.dart` verde.

### 58.4 — Menu di oggi
`test/ui/menus_characterization_test.dart` copre anche timer, ordinamenti (Libreria, Preferiti), clic destro, ⋮ della selezione,
foglio della coda e podcast: per ognuno l'elenco delle voci, nell'ordine, e l'effetto di una voce. Gli elenchi attesi restano
uguali nella fase 61 (cambia solo come si apre e si legge il menu).

**Fatto quando:** `flutter test test/ui/menus_characterization_test.dart` verde e ogni riga della tabella del menu in analisi ha almeno un caso.

### 58.5 — Home e testo di oggi
Ventaglio chiuso con i primi 5; il primo tocco apre, il secondo apre l'album (`cover_fan_test.dart`). In `LyricsCard`, la riga evidenziata segue la posizione (solo se non è già coperta).

**Fatto quando:** `flutter test test/ui/cover_fan_test.dart test/ui/home_test.dart test/ui/now_playing_test.dart` verde.

### 58.6 — Golden di oggi
Aggiungere a `test/goldens/ui_fluida_golden_test.dart` (o `screens_golden_test.dart`): Ricerca al telefono a tastiera chiusa, Home con il ventaglio aperto, foglio ⋮ di un brano.

**Fatto quando:** `flutter test test/goldens` verde con i tre scatti nuovi in `test/goldens/`.

### 58.7 — Misure di partenza
Sul Mi A3 (app perf, via `sorveglia.sh --pesante`):
`python3 scripts/perf_device.py 0d7ae9df206e --label ui-jam-ricerca-prima --only "Ricerca «notte»,Fogli,Swipe mini player,Apertura player,Anello,Pallino schede"`.

**Fatto quando:** esiste `build/perf/ui-jam-ricerca-prima.md` e la tabella «Prima» è in `docs/refactor/ui-jam-ricerca/misure.md` con le soglie della fase 38.

### 58.8 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; i comandi mirati di 58.1–58.6 verdi; nessun file sotto `lib/` cambiato (`git diff --stat origin/master -- lib` vuoto); CI della PR verde.
