# Fase 28 — Prestazioni, fluidità, ricerca veloce e ascolto prima di scaricare

**Obiettivo:** nessun rallentamento percepibile anche su un telefono vecchio (riferimento: **Xiaomi Mi A3**,
Snapdragon 665, 4 GB, Android 11) con **3000+ brani**; microanimazioni leggere su ogni azione; ricerca online
che mostra i primi risultati in **meno di 1,5 s**; **ascolto in streaming** di un risultato prima di decidere se
scaricarlo.
**Prerequisiti:** fase 11 (sistema visivo), 14 (download), 17 (anteprima), 27 (temi e sfondi).
**Principio:** si misura prima e dopo, sul Mi A3; nessuna ottimizzazione «a sentimento». Nessun pacchetto nuovo.

## Misure di partenza (2026-10-20, PC di sviluppo, rete di casa)
| Cosa | Oggi | Note |
|---|---|---|
| Ricerca YouTube (yt-dlp, elenco piatto) | 2,5 s | sul telefono in più l'avvio di Python a ogni ricerca (6–7 s percepiti dall'utente) |
| Ricerca YouTube Music «brani» (yt-dlp) | **13,8 s** | apre la pagina di ogni video per avere artista, album e durata |
| Ricerca SoundCloud (yt-dlp, piatta) | 2,8 s | |
| Stessa ricerca YouTube con una richiesta diretta all'API interna (InnerTube, quella che usano yt-dlp e NewPipe) | **1,0 s** | titolo, canale, durata, miniature |
| Stessa ricerca YouTube Music, richiesta diretta | **0,56 s** | 20 brani con artista, album, durata |
| Indirizzo audio diretto per lo streaming (`yt-dlp -g -f bestaudio`) | 2,4 s | valido alcune ore, legato all'IP |
| Miniature dei risultati | la più grande disponibile (fino a 1280×720, 100–200 KB) | mostrate a 80×45 |
| Copertine | una per album, ma salvate **originali fino a 4 MB** | decodificate anche per le miniature |
| Elenchi di brani | ogni elenco legge **righe intere**, con testi, testi sincronizzati e curiosità | 3000 brani ≈ decine di MB di testo a ogni aggiornamento |
| Sfondo con immagine sfocata (fase 27) | `ImageFiltered` calcolato dal motore grafico | costoso su GPU vecchie |

## Decisioni
| Tema | Scelta |
|---|---|
| Misura | Build `--profile` sul Mi A3; `adb shell dumpsys gfxinfo <pkg> framestats` durante scorrimenti scriptati; `am start -W` per l'avvio a freddo; `dumpsys meminfo`. Libreria di prova da 3000 brani in una **cartella separata** (file brevi generati), mai mescolata ai dati veri senza conferma. Traccia ripetibile anche su emulatore (`integration_test` + `traceAction`) nel job manuale della CI |
| Obiettivi | Scorrimento elenchi e griglie: 90° percentile ≤ 16 ms per frame, < 2 % di frame persi; avvio a freddo < 2 s con 3000 brani; ricerca nella libreria < 100 ms; ricerca online: primi risultati < 1,5 s |
| Ricerca online | **Client InnerTube in Dart** (con `dio`) per YouTube e YouTube Music: una richiesta. yt-dlp resta per i download, le playlist e i canali, SoundCloud e come **ripiego automatico** se la richiesta diretta fallisce o cambia formato (rischio R70 in `99-rischi`). Risultati in cache come oggi |
| Miniature | La più piccola adatta (`mqdefault` 320×180, ~15 KB), comparsa in dissolvenza su un segnaposto; si caricano già solo le righe visibili |
| Streaming | «Ascolta» su un risultato: indirizzo diretto via yt-dlp, riprodotto da `just_audio` (ExoPlayer su Android, mpv su desktop) nel lettore d'anteprima della fase 17 o in coda come brano «remoto». Mentre suona si salva in una **cache su disco** (tetto 200 MB, eliminata dopo 7 giorni); «Scarica» riusa il file in cache se il formato scelto è l'originale, altrimenti scarica di nuovo. L'indirizzo si chiede al momento dell'ascolto (scade) |
| Elenchi | Proiezione leggera per elenchi e griglie (id, titolo, artista, album, durata, copertina, preferito, flag): testi e curiosità si leggono solo nella scheda del brano e in «In riproduzione» |
| Copertine | Al salvataggio: lato massimo 800 px, JPEG qualità 85 (~80–150 KB), più una **miniatura 160 px** per elenchi e griglie. Conversione una tantum di quelle esistenti, in background. Limite di memoria per la cache delle immagini sui telefoni con poca RAM |
| Testi e curiosità | Pesano poco: 3000 brani × ~8 KB ≈ 25 MB nel database. Nessun intervento sullo spazio, solo non caricarli negli elenchi (vedi sopra) |
| Microanimazioni | Solo **opacità e trasformazioni** (niente animazioni di dimensioni negli elenchi), 120–220 ms, curva in uscita morbida, `RepaintBoundary` attorno a ciò che si muove, sempre spente da «Riduci animazioni». Catalogo: pressione (scala 0,97), comparsa delle prime 12 righe sfalsata di 20 ms, cambio scheda in dissolvenza, copertina → «In riproduzione» (Hero), mini-player che entra, cuore che pulsa, numero di selezione che entra, dialoghi e fogli |
| Sfondo sfocato | La sfocatura si calcola **una volta** all'importazione dell'immagine e si salva già sfocata; a schermo nessun filtro |
| Pacchetti nuovi | Nessuno (`dio`, `just_audio`, `drift` già presenti) |

## Task
**28.1 — Misura di partenza** (strumenti e risultati in [fase-28-misure.md](fase-28-misure.md)). Libreria di prova da 3000 brani (script in `scripts/`, cartella separata), build
profile sul Mi A3, scorrimenti scriptati via adb su «Tutti i brani», «Album», ricerca, «In riproduzione»; tabella
dei tempi in `docs/` (frame, avvio, memoria). Stesso giro registrato come traccia `integration_test` per l'emulatore.

**28.2 — Elenchi leggeri.** Proiezione senza testi/curiosità per tutte le query degli elenchi (repository +
provider); scheda del brano e «In riproduzione» leggono la riga intera. Test: le query degli elenchi non leggono
le colonne pesanti; prestazioni 50k invariate o migliori.

**28.3 — Copertine piccole.** Ridimensionamento al salvataggio (800 px) e miniatura 160 px; `CoverImage` sceglie
la miniatura sotto una certa dimensione; conversione in background delle copertine esistenti (ripresa se
interrotta); limite della cache immagini. Test: dimensioni, idempotenza della conversione, nessun I/O sul thread UI.

**28.4 — Ricerca YouTube diretta.** Client InnerTube (YouTube e YouTube Music «brani») in
`lib/services/online/innertube_client.dart`, con analisi difensiva delle risposte (fixture JSON reali in
`test/fixtures/`), ripiego automatico su yt-dlp, log del motivo. Test: fixture, ripiego, cache.

**28.5 — Miniature piccole e in dissolvenza.** Scelta della miniatura minima adatta, dissolvenza, segnaposto.

**28.6 — Ascolta prima di scaricare.** «Ascolta» nei risultati (YouTube, YouTube Music, SoundCloud): indirizzo
diretto, riproduzione nel lettore d'anteprima o in coda, cache su disco con tetto e scadenza, «Scarica» che riusa
la cache quando possibile. Prova sul Mi A3 con rete mobile e Wi‑Fi.

**28.7 — Sfocatura calcolata una volta.** L'immagine di sfondo sfocata si salva già sfocata (e si ricalcola se
cambia la sfocatura); nessun `ImageFiltered` a schermo.

**28.8 — Avvio.** Servizi non necessari all'avvio (condivisione LAN, scoperta, aggiornamenti) inizializzati dopo
il primo frame; misura `am start -W` prima/dopo.

**28.9 — Microanimazioni.** Il catalogo delle Decisioni, una alla volta, con `RepaintBoundary` e verifica dei frame
sul Mi A3 dopo ciascuna; test: con «Riduci animazioni» la durata è zero.

**28.10 — Misura finale.** Stesso giro di 28.1, tabella prima/dopo, obiettivi rispettati o motivati.

**28.11 — Rifinitura, documentazione e prova a mano.** `02-architettura.md`, `99-rischi` (R70 InnerTube), guida.

## Rischi
- **InnerTube** è un'API interna non documentata: può cambiare senza preavviso. Mitigazione: ripiego automatico
  su yt-dlp e analisi difensiva, fixture aggiornabili.
- **Streaming**: gli indirizzi scadono e sono legati all'IP; su rete mobile il primo byte arriva più tardi. Il
  lettore deve mostrare il caricamento e gestire l'errore senza bloccare la coda.
- **Animazioni** su GPU vecchie: ogni animazione si misura sul Mi A3 prima di passare alla successiva.
