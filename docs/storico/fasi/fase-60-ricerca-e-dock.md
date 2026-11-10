# Fase 60 — Ricerca e dock (refactor «ui-jam-ricerca»)

**Obiettivo:** premendo Cerca la barra appare sopra il dock; ✕ e tastiera chiusa non riportano alla sezione di prima;
tastiera aperta = solo la barra, tastiera chiusa = barra + mini player + schede su Ricerca.

**Prerequisiti:** fase 59 chiusa. Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`. Decisioni D-153, D-155.
Mockup: `docs/refactor/ui-jam-ricerca/mockup/ricerca.html`.

**Comando mirato:** `flutter test test/ui/app_shell_test.dart test/ui/search_screen_test.dart test/ui/search_sources_test.dart test/ui/shell_keys_test.dart test/ui/transitions_characterization_test.dart`.

## Task

### 60.1 — ✕ svuota e resta (F-20, F-26, F-28)
`SearchBarNotifier.dismiss` (`ui_providers.dart`) non fa più `nav.set(_previous)`: svuota, chiude la tastiera e si resta su Ricerca;
`_previous` sparisce se non serve ad altro. Stessa semantica per la ✕ della pagina desktop (`search_screen.dart`).
La ✕ si vede solo con del testo, tooltip e etichetta «Cancella».

**Fatto quando:** `app_shell_test:592,610,630,645` riscritti di proposito; test nuovi «✕ svuota e resta» e «✕ solo con testo»; comando mirato verde.

### 60.2 — Dock a due strati (F-21, F-22, F-25)
`ShellDock` (`bottom_bar.dart`): la barra di ricerca sta sopra mini player e schede invece di sostituirli. Con la tastiera aperta
(inset > 0) mini player e schede sono nascosti, anche fuori da semantica e tocco. Uscire dalla scheda Ricerca nasconde la barra;
Cerca la riapre con la tastiera. Il push dalla Ricerca (`_OnPush`) resta com'è.

**Fatto quando:** test nuovi «tastiera aperta = solo la barra», «tastiera chiusa = barra + mini player + schede, Cerca col pallino», «uscire da Cerca nasconde la barra»; golden `mini_dock` e della Ricerca (58.6) rigenerati una volta.

### 60.3 — Back con la tastiera (F-24, D-153)
PopScope in `app_shell.dart`: con la tastiera aperta Back chiude solo la tastiera; a tastiera chiusa Back fa come nelle altre schede.

**Fatto quando:** test nuovo con i due casi; comando mirato verde.

### 60.4 — Nessun rebuild durante l'animazione della tastiera (F-23)
`MediaQuery.viewInsetsOf` letto in un widget piccolo; il resto del dock e il mini player sono costanti.

**Fatto quando:** test nuovo con una probe che conta le build di `ShellDock` e del mini player in 10 passi di `viewInsets`: al più 1 build per il cambio aperta/chiusa.

### 60.5 — Bug noti da verificare (F-29, F-30)
Sul Motorola (sola lettura): testo leggibile con filtri preferiti/recenti; il tasto cerca della tastiera cerca anche online. Se ok, toglierli da `docs/prossimi-lavori.md`.

**Fatto quando:** esito scritto in `docs/PROGRESS.md` sotto 60.5; se un bug c'è ancora, un passo di correzione con il suo test.

### 60.6 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; comando mirato e `flutter test test/goldens` verdi; sul Mi A3 `perf_device.py 0d7ae9df206e --label ui-jam-ricerca-57 --only "Ricerca «notte»,Swipe mini player"` entro le soglie della fase 38; review del diff; CI verde.
