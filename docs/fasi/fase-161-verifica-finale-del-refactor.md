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

### 161.1 Metriche di arrivo (25/11, build release Linux sotto Xvfb)
| Metrica | Partenza | Arrivo | Soglia | Esito |
|---|---|---|---|---|
| `flutter analyze` | 0 | 11 errori, tutti in `test/services/audio/online_playback_test.dart` (file in modifica nello stesso worktree da un altro agente, `git status` lo dà modificato); 0 nel resto del codice | 0 | da rifare a file chiuso |
| `_known` in `a11y_guidelines_test` | 2 | 1 (chip velocità del player telefono); test verde (27 prove, home e libreria desktop dentro) | ≤ 1 | ok |
| Golden `desktop_w*.png` | 0 | 27 | ≥ 27 | ok |
| Avvio a freddo, prima volta (HOME nuovo) | 4,4 s | 1,0 s alla comparsa della finestra | ≤ 4,8 s | ok (nota 1) |
| Avvio, seconda volta (3 prove) | 2,3 s | 0,51 / 0,51 / 0,51 s, mediana 0,51 s | ≤ 2,5 s | ok (nota 1) |
| Avvio con i dati reali (copia 381 MB) | n.d. | 4,0 s | n.d. | informativo |
| RSS dopo Album (fino in fondo), Artisti, Tutti i brani | 618 MB | 656 MB a metà Album, 740 MB a fine Album, 761 MB dopo Artisti, 778 MB dopo Tutti i brani | ≤ 680 MB | **fuori soglia (+26 %)** (nota 2) |
| `integration-linux` | assente | verde in #245 (run 45562703856, check+integration success); nelle run 158 push e 159 il job è saltato (check rosso a monte / run ancora in corso) | verde | ok sull'ultima run utile, non verificabile sull'ultimo master |

Note: 1) il tempo è «finestra visibile» (`xdotool search --sync --onlyvisible`), non il primo frame con contenuto; la partenza di 4,4/2,3 s era con ogni probabilità misurata fino alla home disegnata, quindi i numeri non sono confrontabili uno a uno (con i dati reali la finestra arriva a 4,0 s). 2) L'RSS cresce con lo scorrimento e si assesta (oltre 700 MB già a fine Album); la partenza di 618 MB potrebbe essere stata presa in un altro punto del giro. Nel DB reale 1354 file copertina sono identici (stessa «Let It Be» per album e artisti diversi): è un dato, non un difetto di queste fasi, ma può falsare confronto e memoria. Da decidere: alzare la soglia o indagare la cache delle miniature.

### 161.3 Linux desktop contro i mockup (1440×900 con i dati reali; 1920×1080 e 1000/980 px solo Home/Libreria)
Nessuna eccezione nel log di `AppLog` (0 righe `[E]`, solo avvisi di MusicBrainz 503 e `user-dirs.dirs` per il HOME finto); nessun overflow in stdout. Mockup a 1440 confrontati rendendoli con Chrome headless (cartella ora in `docs/storico/refactor/…`).
| Schermata | Esito |
|---|---|
| Home 1440 | differenze accettate: mancano Riprendi ad anello, Nuove uscite, Più ascoltati, Da riscoprire, Il tuo mese (storico vuoto, sezioni online/senza dati); griglia a 12 colonne, riga Preferiti/Playlist/Radio, card Daylist, «Aggiunti da poco» come nel mockup |
| Home 1920 | uguale (colonna centrata, bordi larghi) |
| Home 1000 | **differenza da correggere (media)**: a 1000 px esatti la barra laterale resta a 240 e lo scaffale «Aggiunti da poco» si schiaccia (copertine sovrapposte, senza titoli); riprodotto 2 volte. Sotto i 1000 (980 px) barra a 72 px e scaffale ok |
| Cerca | differenze accettate: solo «Top 20 per genere» (nessuna ricerca recente/online provata) |
| Libreria griglia (Tutto) | uguale (testata fissa, tab, S/M/L, chip) |
| Libreria lista | uguale |
| Libreria Album/Artisti | uguale; **lieve (bassa)**: nella tab Album la riga di chip «Tutti / Sul dispositivo / In streaming» è larga un terzo di pagina ciascuno (chip stirati) |
| Album | uguale (album sconosciuto, cuore, condividi, tabella) |
| Tutti i brani | uguale (tabella, intestazioni, riga al passaggio con cuore e ⋮, selezione con Ctrl/Maiusc con cerchi numerati e barra «3 selezionati») |
| Preferiti | uguale (stato vuoto) |
| Cronologia | uguale (stato vuoto) |
| Radio | differenza accettata: foglio «Scegli la regione» al primo uso, scaffali in caricamento (rete) |
| Impostazioni | uguale (elenco a sinistra, contenuto a destra) |
| Registro | uguale (elenco + dettaglio a due pannelli) |
| Daylist | differenze accettate; **bassa**: i brani «Suggerito» (online) usano righe senza colonne e con ⋮, non righe di tabella |
| Player a tutto schermo | **differenza da correggere (alta, da confermare con l'intento della 157.3)**: è il layout «Prima» del mockup (pagina a tutto schermo senza barra laterale e barra del player, pannelli Testo/Curiosità/Crediti/Prossimi aperti di default), non la «modalità» del «Dopo» (shell visibile, schede Testo/Coda/Info, pannello Coda con timer). Il pannello destro doveva essere chiuso di default (157.3) ma a 1440 è aperto |
| ⋮ del player | **differenza da correggere (media)**: apre il foglio centrato da 480 px stile telefono (con primo voce evidenziata, lista che esce dal bordo), non un menu al puntatore |
| Menu al clic destro (con 3 selezionati) | **differenza da correggere (media)**: menu compatto ok ma mancano «Riproduci ora / Riproduci dopo», i suggerimenti dei tasti (Invio, Ctrl+…) e il sottomenu di «Aggiungi a playlist» (oggi voce con «…»); non provato su riga singola |
| Dialogo «Nuova playlist» (da +) | differenza accettata: popover ancorato al +, un po' stretto; non confrontato punto per punto con il mockup |
| Foglio «?» scorciatoie | uguale/ok |
| Tasti laterali 8/9 | ok (indietro e avanti funzionano) |
| Tasto destro, Ctrl/Maiusc+clic | ok (selezione intervallo e menu) |
| **Doppio clic su una riga di Daylist** | **difetto (media)**: due avvii ravvicinati danno «Loading interrupted» ×3, segnati «3 brani non riproducibili» e la coda salta oltre i primi 3 brani locali; un clic singolo su Riproduci funziona. Da riprovare su Tutti i brani |

Priorità da correggere: alta, player a tutto schermo e pannello aperto di default; media, scaffale Home a 1000 px, doppio clic che salta i brani, ⋮ del player come foglio telefono, voci del menu al clic destro, RSS oltre soglia; bassa, chip stirati nella tab Album, righe «Suggerito» della Daylist. Non verificato: dialoghi Modifica info e Aggiungi a playlist, menu su riga singola, Cerca con risultati, Radio con rete, 1920 e 1000 oltre Home/Libreria, riproduzione con audio reale (solo 20 s a volume 5 %), Karaoke, 161.2, 161.4.
