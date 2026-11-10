# Identità visiva «Anello» (direzione A) — design

Data: 2026-10-22. Stato: approvato dall'utente il 22/10.
Bozza visiva approvata dall'utente: `anello.html` (sessione di brainstorming del 22/10). Una copia sta in
`docs/superpowers/specs/2026-10-22-identita-anello.html`.

## Perché

Le parole dell'utente: oggi l'app «non ha una identità propria a livello di UI, sembra la "brutta copia" di
Spotify». La vuole con un «carattere libertino, casual ma anche elegante nelle microanimazioni».
La prima tornata (Fanzine, Vinile, Rivista) è stata scartata come troppo stilizzata. Serve qualcosa di
«semplice, non troppo stilizzato, e soprattutto funzionale». L'utente ha scelto la direzione A («Una barra
sola»), che va tenuta «creativa ma semplice», e ha chiesto di mantenere la navigazione in basso.

Il carattere viene dal logo «K in fuga»: un anello aperto con un pallino che scappa dal varco. Questo
segno torna in tre punti che servono davvero, e tutto il resto resta sobrio.

## Obiettivi

1. **Il brano in ascolto dentro l'anello.** Nel mini‑player e nel lettore a schermo intero, la copertina
   è rotonda dentro un anello aperto come quello del logo.
   - Il varco sta in alto a destra.
   - L'arco nel colore d'accento è l'avanzamento, e il pallino in punta segna la posizione.
   - Il resto dell'anello è in `surface3`.
   - Questo anello sostituisce la barra di avanzamento sottile del mini‑player.
2. **Le schede in basso.** Restano quattro: Home, Cerca, Libreria, Memoria, come oggi.
   - La scheda attiva è segnata dal pallino del logo, nel colore d'accento, in alto a destra della sua
     icona.
   - Quando si cambia scheda, il pallino salta con un piccolo arco (~420 ms).
   - Le etichette restano sempre visibili.
3. **Cerca nasce dalla barra.** Toccando «Cerca», la barra delle schede si allarga e diventa il campo di
   ricerca, già a fuoco, con le ricerche recenti che salgono sopra.
   - La ✕ chiude il campo e riporta alla scheda di prima.
   - Il campo resta dove sta il pollice.
4. **Un'unica superficie in basso.** Mini‑player e schede stanno in un solo blocco arrotondato
   (`surface2`, raggio 28) sospeso sopra il contenuto, al posto delle due fasce di oggi.
5. **Il lettore cresce dal blocco.** Toccando il mini‑player, il lettore a schermo intero si apre
   allargandosi dal blocco in basso, invece di salire come un foglio.
   - Ha un anello grande attorno alla copertina.
   - Mentre la musica suona, la copertina ruota piano; si ferma in pausa.
6. **Una Home più corta.** In cima c'è un solo invito grande: «Casuale su tutto», con il numero di brani
   e le ore, in Unbounded, più un disco d'accento con l'icona casuale. Sotto, nell'ordine:
   - scorciatoie con il conteggio (Preferiti, Playlist, Radio);
   - «Riprendi», una lista a righe che dice dove eri rimasto (brano N di M, minuti che mancano) con una
     barretta di avanzamento;
   - «Aggiunti da poco», un ventaglio di 5 copertine che si apre al tocco o al passaggio del mouse e porta
     all'elenco completo.
7. Funziona con **tutti i temi e gli accenti** che ci sono già (Notte, OLED, Chiaro × 8 accenti). Non si
   aggiungono colori nuovi.

## Non obiettivi

- Nessun font nuovo e nessun pacchetto nuovo: Unbounded e Figtree sono già nell'app.
- Non cambiano le funzioni: le schermate interne (album, playlist, artista, radio, podcast, impostazioni)
  restano come sono. Ricevono solo i colori e i caratteri, che già ereditano.
- Il desktop non viene ridisegnato. Vedi «Desktop» qui sotto.
- Nessuna griglia di copertine nuova in Home.

## Anti‑obiettivi (sarebbe un fallimento anche se funziona)

- Sembrare di nuovo Spotify: scaffali orizzontali di card uguali uno sotto l'altro.
- Decorazioni che rallentano: animazioni che bloccano il tocco, o che scattano sul Mi A3.
- Movimento che ignora «Riduci animazioni». Con quell'impostazione:
  - il pallino si sposta senza arco;
  - la ricerca appare senza allargarsi;
  - il lettore si apre senza crescere;
  - la copertina non ruota.
- Etichette in MAIUSCOLO, stringhe «A · B», frecce «→» sui pulsanti. Le intestazioni restano in
  minuscolo normale («Riprendi», «Aggiunti da poco»).

## Vincoli

- Il pacchetto di stato resta quello di oggi; vedi `CLAUDE.md`.
- Si riusano i token esistenti:
  - colori: `CcColors` (`lib/ui/theme/tokens.dart`, `palette.dart`);
  - caratteri: `buildTextTheme`, con `displaySmall` = Unbounded 30/700 per «Casuale su tutto»;
  - movimento: `Motion` / `CcMotion` / `ccDuration`.
- Animazioni solo su opacità e trasformazioni, dentro `RepaintBoundary`.
  - L'anello si ridisegna con un `CustomPainter` che ascolta solo la posizione, così il resto della
    barra non si ricostruisce.
  - Il mini‑player oggi ascolta la posizione: mantenere la stessa frequenza.
- Accessibilità:
  - Le schede restano `Semantics(button, selected, label)`.
  - L'anello espone il valore come oggi la barra (es. «1:12 di 3:20»).
  - Il campo di ricerca ha la sua etichetta.
  - La ✕ si chiama «Chiudi la ricerca».
- Le scorciatoie di oggi restano: Ctrl+F apre Cerca e mette a fuoco il campo, `searchFocusProvider`.
  `ShellNav.showSearch` deve aprire la barra in modalità ricerca.
- Il tasto Indietro di Android, con la ricerca aperta, la chiude prima di uscire dalla scheda.
- I testi nuovi vanno in tutti gli ARB (it, en, de, es, fr, pt), un solo agente alla volta.
- I golden della barra in basso e della Home vanno rigenerati.

## Cosa sparisce dalla Home e dove va

Oggi la Home ha questi scaffali:
- Nuove uscite
- Artisti più ascoltati
- Il tuo mese
- Ascoltati di recente
- Aggiunti di recente
- Brani più ascoltati
- Radio
- Riscopri

Nella nuova Home:

| Oggi | Dopo |
|---|---|
| Ascoltati di recente | dentro «Riprendi» (righe) |
| Aggiunti di recente | ventaglio «Aggiunti da poco» |
| Radio | scorciatoia «Radio» con conteggio |
| Nuove uscite | una riga in cima a «Riprendi» quando ci sono novità (*scelta mia*) |
| Il tuo mese, Artisti più ascoltati, Brani più ascoltati, Riscopri | in fondo, come righe compatte da 3 elementi con «Tutti» (*scelta mia*) |

## Desktop (scelta mia)

Sopra gli 840 px restano la barra laterale e la barra del lettore di oggi, con due ritocchi:
- il pallino del logo segna la voce attiva della barra laterale;
- l'anello sostituisce la copertina quadrata nella barra del lettore.

La Home è la stessa della versione mobile, con una larghezza massima del contenuto. La barra che diventa
ricerca è solo mobile: su desktop Cerca resta com'è.

## Cosa resta al costruttore

- Curve e durate esatte, nei limiti di `Motion`: pallino ~420 ms, ricerca ~450 ms, lettore ~550 ms.
- Struttura del codice: ad esempio un `RingProgress` riusabile in `lib/ui/widgets/` e la nuova barra in
  `lib/ui/shell/bottom_bar.dart`.
- Ordine dei passi. Proposta: anello, poi blocco in basso con pallino, poi ricerca dalla barra, poi Home,
  poi lettore che cresce, poi desktop.

## Decisioni prese dopo la revisione (scelte mie, da controllare)

1. **Cerca resta una scheda.**
   - `SearchScreen` resta la scheda 1. Restano anche `ShellNav.showSearch`, `searchPrefillProvider` e
     Ctrl+F.
   - Il campo di testo però sta nella barra in basso. La pagina perde il suo campo e usa lo stesso
     controller e lo stesso `searchFocusProvider`.
   - Chip «In libreria/Online», filtri Preferiti/Recenti e generi restano nella pagina, in alto.
   - Con il campo aperto il pallino non si vede.
   - La ✕ svuota il campo e torna alla scheda di prima. Anche Indietro chiude prima il campo.
2. **Cercati di recente**: sono le stesse stringhe di oggi (`recentSearches`), con un'icona di ricerca.
   Nessun archivio nuovo. I risultati per artista/album/radio della bozza erano solo illustrativi.
3. **Riprendi**: solo dati che esistono già, nessuna tabella o migrazione nuova. Le righe sono, in ordine:
   - la sessione salvata (fonte della coda e brano N di M, se la fonte è nota);
   - i brani con `resumePositionMs` (podcast, brani lunghi), con i minuti che mancano;
   - poi album e playlist ascoltati di recente (`lastPlayedAt`).

   Al massimo 4 righe.
4. **Blocco in basso**: è una zona riservata in fondo allo `Scaffold` (`bottomNavigationBar`), non
   sovrapposta.
   - Ha margine 10, raggio 28 e `surface2`, e lo sfondo dietro resta `bg`. Così nessuna schermata deve
     calcolare un margine nuovo.
   - Senza brano in ascolto, il blocco contiene solo le schede.
   - Con la tastiera aperta il blocco sale sopra di essa (mostra solo il campo di ricerca).
5. **Anello senza posizione**:
   - radio in diretta e Jam remoto: anello intero senza pallino;
   - nessuna copertina: il segnaposto attuale, rotondo.
6. **Casuale su tutto** fa partire la musica: mescola tutta la libreria locale e parte.
   - È diverso dai pulsanti casuale delle liste: quelli accendono solo la modalità; qui non c'è una
     lista da tenere ferma.
   - I numeri sono il totale dei brani locali e la loro durata, calcolati da un provider leggero fuori
     dal thread UI.
7. **Ventaglio**:
   - fino a 5 copertine, rimpicciolite per stare nella larghezza;
   - con meno elementi ne mostra meno, a 0 la sezione sparisce;
   - al primo tocco si apre, al secondo apre l'album.
8. **Il lettore che cresce**:
   - la rotta del lettore si apre con un ritaglio arrotondato che parte dal rettangolo del blocco;
   - la copertina passa con un `Hero`, se non scatta sul Mi A3, altrimenti senza.
9. **Rotazione della copertina**:
   - continua mentre suona, riparte da 0 a ogni brano;
   - spenta con «Riduci animazioni»;
   - se scatta sul Mi A3, si toglie.
10. **Golden**: si rigenerano quelli che già ci sono, `phone_*` e `desktop_*`, senza aggiungerne altri
    oltre alla nuova Home `phone_100_home`.
