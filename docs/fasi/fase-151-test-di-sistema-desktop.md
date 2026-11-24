# Fase 151 — Test di sistema desktop

## Obiettivo
Una prova d'integrazione dell'app desktop intera su Linux, sotto Xvfb, a ogni PR con codice (F-210). Resta fuori il check obbligatorio: nasce **non bloccante** (D-733).

## Riferimenti
D-719, D-733. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md), [`rete.md`](../refactor/desktop-e-coerenza/rete.md) (sezione «Integrazione Linux»). `../architettura/qualita-e-rilascio.md` (CI). Codice: `integration_test/support/app_driver.dart` (`AppUnderTest`), `integration_test/app_flow_test.dart` come modello, `lib/ui/shell/app_shell.dart`, `lib/ui/shell/desktop_sidebar.dart`, `lib/ui/shell/shell_keys.dart`, `.github/workflows/ci.yml` (job `build-linux` per i pacchetti apt).

## Task
- [ ] 151.1 Il test `desktop_flow_test.dart`
  - File: `integration_test/desktop_flow_test.dart` (nuovo), `integration_test/support/app_driver.dart` (solo aggiunte).
  - Passi: 1) avvio a 1280×800 con `AppUnderTest` (nessun audio vero: sinusoide del driver, volume basso, nessuna rete come in `no_network_youtube.dart`); 2) giro di tutte le voci della barra laterale (`desktop_sidebar.dart`) senza eccezioni; 3) scansione di una cartella di prova e comparsa dei brani; 4) play e barra del player (titolo, play/pausa); 5) tasto destro su una riga (oggi apre il foglio: si verifica che si apra qualcosa e si chiuda con Esc); 6) Ctrl+clic e Maiusc+clic sulla selezione; 7) scorciatoie di oggi: Spazio, Ctrl+←/→, Ctrl+F, Alt+←; 8) ridimensionamento a 1000 e 1920 px senza overflow. Il test dei tasti laterali del mouse si aggiunge nella 158.
  - Comando mirato: `xvfb-run -a -s "-screen 0 1920x1080x24" flutter test integration_test/desktop_flow_test.dart -d linux` (con `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante`).
  - Fatto quando: il comando passa in locale sotto Xvfb due volte di fila (nessuna prova instabile); `flutter analyze` pulito.
- [ ] 151.2 Job `integration-linux` in CI
  - File: `.github/workflows/ci.yml`.
  - Passi: 1) nuovo job `integration-linux`: `needs: check`, `runs-on: ubuntu-24.04`, `timeout-minutes: 30`, saltato se `needs.check.outputs.docs == 'true'`; 2) apt come `build-linux` più `xvfb`; 3) `flutter-action` con `FLUTTER_VERSION`, `flutter config --enable-linux-desktop`, `flutter pub get`; 4) `xvfb-run -a -s "-screen 0 1920x1080x24" flutter test integration_test/desktop_flow_test.dart -d linux`; 5) **non** aggiungerlo ai check obbligatori di `master` (D-733); 6) riga nuova in `qualita-e-rilascio.md` (tabella dei job: cosa fa, non bloccante).
  - Comando mirato: `python3 -c "import yaml;yaml.safe_load(open('.github/workflows/ci.yml'))"` + PR di prova.
  - Fatto quando: sulla PR il job parte e passa; su una PR di sola documentazione risulta saltato; «Analyze and test» resta l'unico obbligatorio.

## Tocca a te
- [ ] Dopo 2 settimane verdi e stabili: rendere `integration-linux` obbligatorio accanto a «Analyze and test» (protezione di `master`); lo fa l'utente o `/obiettivo` con un tuo sì (D-733).

## Note di deviazione
