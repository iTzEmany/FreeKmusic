# Fase 161 — Verifica finale del refactor

## Obiettivo
Chiudere il refactor «desktop-e-coerenza»: metriche di arrivo contro quelle di partenza, controllo su telefono, su Linux sotto Xvfb schermata per schermata contro i mockup, e sul bundle flatpak nuovo. Nessuna funzione nuova.

## Riferimenti
D-731, D-733, D-734. Refactor: [`rete.md`](../refactor/desktop-e-coerenza/rete.md) («Metriche di arrivo»), [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md), [`mockup/index.html`](../refactor/desktop-e-coerenza/mockup/index.html) (e gli altri file della cartella `mockup/`). Memoria di lavoro: Mi A3 telefono di prova (volume 0, «pausa a volume zero» spenta, mai cancellare i file musicali), **mai toccare il Motorola ZY22HKD85K**. Script: `scripts/shots.sh`, `scripts/telefono.py`, `scripts/perf_library.py`, `scripts/sorveglia.sh`.

## Task
- [ ] 161.1 Metriche di arrivo
  - Passi: 1) `flutter analyze` = 0; 2) `flutter test test/ui/a11y_guidelines_test.dart`: `_known` non cresce (partenza 2 voci, valore scritto nella 150.5) e home e libreria desktop sono dentro; 3) `ls test/goldens/desktop_w*.png | wc -l` ≥ 27; 4) avvio a freddo Linux release sotto Xvfb: ≤ 4,8 s la prima volta e ≤ 2,5 s la seconda (partenza 4,4 s e 2,3 s, +10 %); 5) RSS dopo il giro della libreria (2263 album, copia dei dati reali) ≤ 680 MB (partenza 618 MB, `ps -o rss= -p <pid>`); 6) `integration-linux` verde nell'ultima PR.
  - Comando mirato: i comandi sopra (build e avvio con `sorveglia.sh --pesante`)
  - Fatto quando: tabella «partenza / arrivo / soglia» scritta nelle note di deviazione, tutte entro soglia (o la deviazione motivata).
- [ ] 161.2 Mi A3: schermate e gesti del telefono
  - Passi: installare la build su Mi A3 (`adb install -r`, volume 0); controllare home (anello del Riprendi, Nuove uscite, intestazioni «Tutti», spazi), pagina Playlist senza FAB, player (cuore con un brano in streaming, azioni, ⋮ con «Modalità auto»), album e playlist locali e online (cuore e Condividi); gesti D-721: scorrimento in coda, pressione lunga, doppio tocco, seek ad arco, indietro; TalkBack con `uiautomator`; screenshot letti e subito cancellati. Mai cancellare i file musicali; disinstallare solo con `-k`.
  - Comando mirato: `scripts/telefono.py` (o `adb` a mano)
  - Fatto quando: elenco ok/difetti per schermata nelle note; i difetti aperti diventano una fase 162 o una correzione qui.
- [ ] 161.3 Linux desktop: ogni schermata contro il mockup
  - Passi: sotto Xvfb (1440×900 e 1920×1080, più 1000 px) con una copia dei dati reali, screenshot di ogni schermata della scansione (Home, Cerca, Libreria lista/griglia, Album, Artisti, Tutti i brani, Preferiti, Cronologia, Radio, Impostazioni, Registro, Daylist, player a tutto schermo, menu al clic destro, dialoghi) e confronto con il mockup relativo (`desktop-*.html`); tasto destro, Ctrl/Maiusc, tasti laterali, `?`; screenshot già usati cancellati subito.
  - Comando mirato: `scripts/shots.sh`
  - Fatto quando: per ogni schermata una riga «uguale / differenze accettate / differenza da correggere»; nessuna eccezione nel log (`AppLog`).
- [ ] 161.4 Flatpak: installazione del bundle nuovo
  - Passi: installare il bundle dell'ultima release con `flatpak install --user`, con `codecs-extra` (ffmpeg-full non esiste per il 25.08, nota della 160); `flatpak info` mostra la versione del pubspec; l'app parte, suona un brano AAC, istanza unica e «Apri con» funzionano nel sandbox, avviso di primo avvio e comando dell'aggiornamento (160.3, 160.4), tray e drop (159) se il permesso c'è.
  - Fatto quando: esito scritto per voce.
- [ ] 161.5 Chiusura e archivio
  - File: `docs/refactor/desktop-e-coerenza/` → `docs/storico/refactor/desktop-e-coerenza/` (con `git mv`), `docs/storico/README.md`, `docs/00-INDICE.md`, documenti d'area in `../architettura/`, `docs/decisioni.md` (decisione di chiusura), `scripts/check_docs_links.py`.
  - Passi: 1) ogni fase 150-160 spostata in `docs/storico/fasi/` con la sua riga nella tabella dello storico (solo a PR fusa); 2) `git mv` della cartella del refactor; **i percorsi dei font nei mockup sono relativi**: dopo lo spostamento ricontrollare i `url(...)` di `mockup/*.css` e dei file HTML e correggerli; 3) aggiornare i link che puntavano a `docs/refactor/…` (ricerca con `grep -rn "refactor/desktop-e-coerenza" docs`); 4) `check_docs_links.py` verde.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: nessun link rotto; i mockup si aprono dalla nuova posizione con i font.

## Tocca a te
- [ ] GNOME con e senza estensione AppIndicator: tray e «Chiudi nella barra di sistema».
- [ ] Windows: istanza unica, «Apri con», tray, drop e titolo della finestra su una macchina vera.
- [ ] Decidere se rendere `integration-linux` obbligatorio (D-733, dopo 2 settimane verdi).

## Note di deviazione
