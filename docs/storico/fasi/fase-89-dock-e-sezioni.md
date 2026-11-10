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
- **89.1–89.2**: lo `Scaffold` del telefono ha `extendBody: true`. L'ingombro reale di dock, mini player e banner arriva al corpo come `MediaQuery.padding.bottom`, e la shell alza anche `viewPadding.bottom` così i FAB degli `Scaffold` interni stanno sopra il dock. Il margine finale si prende in un modo solo: `context.dockInset` / `EdgeInsets.withDock`, usato dalle liste della shell e dalle pagine interne con padding esplicito (Impostazioni, Tema, Equalizzatore, Duplicati, Proposte, Invio/Ricezione, editor delle smart playlist…). Il dock è opaco di serie.
- **89.3**: `blurredChrome` in `AppSettings`, spento di serie. L'interruttore sta in Impostazioni → Aspetto e lingua, accanto ai temi (D-406). Il documento indicava `theme_editor_screen`, ma lì si raggiunge solo modificando un tema personalizzato, quindi è stato spostato. Acceso: dock con `BackdropFilter` (sigma 20) e `surface2` al 78 %.
- **89.4**: la scheda che si lascia riceve un navigatore nuovo (`TabNavigatorKeys.reset`) e azzera ricerca di Cerca e ordinamento di Tutti i brani; quello dei Preferiti resta. La scheda di destinazione resta intatta, così `openInLibrary`, il prefill della Radio e Ctrl+F funzionano. Una pagina **interna** che protegge l'uscita (tema non salvato, sync in corso) blocca il reset. Riselezionare la scheda attiva con una pagina protetta passa da `maybePop` e chiede conferma.
- **Review Opus** (`code-review high` sulla shell): 8 rilievi, 6 applicati:
  - FAB sotto il dock;
  - pagine interne senza margine;
  - `PopScope` scavalcato;
  - reset troppo largo di `trackQueryProvider`;
  - test dell'opacità;
  - un solo punto per il margine.

  Scartati:
  - il rimontaggio del dock quando si cambia l'interruttore (succede di rado, nessun danno);
  - il reset rinviato al ritorno nella scheda: la misura dice che il reset immediato non costa (sotto).
- **Scheggia**:
  - 4 mutanti su 4 uccisi.
  - Sul Mi A3, nessun crash in 100 cambi di scheda casuali, anche con play/pausa.
  - Ultima riga sopra il dock in Libreria, Tutti i brani, playlist, Memoria e Impostazioni; FAB visibili.
  - 2 bug corretti con test: la lente della Libreria sopravviveva al cambio scheda; riselezionare la scheda attiva buttava le modifiche di un tema (difetto già su master).
- **Golden**: 10 rigenerati (Home e Libreria con il contenuto sotto il dock).
- **Misure sul Mi A3**, build profile, % di frame oltre 16,7 ms:

  | Scenario | Base 87 | 89 senza sfocatura | 89 con sfocatura |
  |---|---|---|---|
  | Scroll Libreria | 4,7 % | 0,6–0,7 % | 5,4 % |
  | Scroll Tutti i brani | 2,3 % | 0,6 % | 7,9 % |
  | Cambio scheda (con reset) | 5,5 % | 1,1–3,0 % | 2,5 % |

  Un primo giro dopo l'installazione aveva dato 12,3 % su Scroll Libreria (riscaldamento); le due ripetizioni sono sotto l'1 %. Con la sfocatura il raster p50 passa da circa 6 a circa 10 ms: è il costo previsto, per cui resta spenta di serie con l'avviso.
- **Prova adb sul Mi A3**, fatta dalla scheggia sull'app vera: cambi scheda, reset, ultima riga, FAB, sfocatura accesa e spenta, editor sporco. La rotazione non è stata provata (regole del telefono).
- **Motorola**: rinviato alla fase 97 (D-419, D-420).
