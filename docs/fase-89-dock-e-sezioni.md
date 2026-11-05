# Fase 89 — Dock flottante e sezioni che si azzerano (refactor «superfici-e-ricerca»)

**Obiettivo:** il contenuto scorre sotto il dock (che resta leggibile), ogni lista riceve il margine in fondo da un punto solo, la sfocatura è opzionale, e lasciando una scheda la si ritrova allo stato iniziale.

**Prerequisiti:** fase 88 chiusa. Mockup `refactor/superfici-e-ricerca/mockup/home.html` (dock) e `tema-sfocatura.html`. Decisioni D-392, D-398, D-406, D-416. Area a rischio: `lib/ui/shell/app_shell.dart` (review Opus / `code-review high`).

**Comando mirato:** `flutter test test/ui/app_shell_test.dart test/ui/shell_tabs_test.dart test/ui/library_screen_test.dart test/ui/all_tracks_screen_test.dart test/ui/home_screen_test.dart test/ui/search_screen_test.dart test/ui/theme_editor_test.dart test/ui/custom_theme_test.dart test/ui/a11y_guidelines_test.dart test/ui/button_tap_sweep_test.dart` più i test nuovi di 89.1 e 89.3.

## Task

### 89.1 — Altezza del dock esposta e margine in fondo (F-76)
- La shell misura il dock (`tokens.dart:114-118`: `miniPlayerHeight`, `dockMargin`, `dockBottom`) e lo espone (es. `MediaQuery.padding.bottom` ridefinito sotto il corpo, o un `InheritedWidget`): un punto solo.
- Le liste lo usano come padding finale: `library_screen` (:811/892), `all_tracks`, `favorites` (:70), `playlist_detail` (:216), `playlists` (:46), `artist` (:104/169), `album_detail`, `search` (:168), `online_results`, `memory` (:161), `home`, `radio` (:113), `history` (:140), `tags` (:50/115), `stats` (:226), `podcasts` (:111). Con e senza mini-player.
- Test nuovo: l'ultima riga di ogni lista elencata si può scorrere sopra il dock (widget test con mini-player acceso e spento).

### 89.2 — `extendBody` e dock opaco (F-75, D-406)
- `app_shell.dart:198`: `extendBody: true`; dock opaco di serie (nessun blur). Su desktop (`desktop_sidebar.dart`) nessun cambio.
- Test: il corpo arriva fino al bordo basso; il dock non ha `BackdropFilter` di default.

### 89.3 — Interruttore «Dock e intestazioni sfocati» (D-406)
- Impostazione nel Tema (`theme_editor_screen.dart`), con avviso «può rallentare sui telefoni meno potenti», ARB it/en/de/es; backend in `shared_preferences`.
- Con l'interruttore acceso: dock semitrasparente con `BackdropFilter`; spento: nessun blur.
- Test: interruttore salvato e riletto; blur solo se acceso; etichetta TalkBack; riga ≥ 48 dp.

### 89.4 — Sezioni che tornano allo stato iniziale (F-100, D-392)
- `app_shell.dart:134-180` (`select`, `popUntil` :137): all'uscita da una scheda chiudere le pagine sopra e azzerare scroll, ricerca, scheda e filtri. Contatore per scheda nella `ValueKey` + azzeramento esplicito dei provider (`searchControllerProvider` in `search_screen.dart:30`, ricerca della Libreria `library_screen.dart:79`, `_kind`, filtri di Tutti i brani).
- `ShellNav.openInLibrary/openInHome` (`shell_nav.dart:17-40`) coerenti: aprono dopo il reset, non lo scavalcano. `desktop_sidebar.dart:41` allineato.
- Ribaltare `shell_tabs_test.dart` della 87: tornando in una scheda si trova lo stato iniziale. Test nuovi: una scheda per volta; riaprire la stessa scheda attiva fa ancora `popUntil`; Radio → «Cerca questo brano» col prefill; Ctrl+F.

### 89.5 — Controlli di fase
`flutter analyze`; comando mirato; golden Home, Libreria, Tutti i brani, Cerca rigenerati con `scripts/shots.sh`; review del diff (`code-review high`); scheggia (cambi scheda rapidi, rotazione, mini-player in transizione); prova sul Motorola (ZY22HKD85K) e sul Mi A3 (0d7ae9df206e) via adb. Misure `perf_device.py` (cambio scheda con reset, scroll Libreria, scroll Tutti i brani) con e senza sfocatura, confrontate con la base della 87 (D-398).

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
