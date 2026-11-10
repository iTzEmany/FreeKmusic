# Misure del refactor «coda-e-libreria»

Metrica di arrivo: `analisi.md`, «Metriche di arrivo» (D-501). Si confronta con «prima-107» qui sotto.

## Prima (`prima-107`)

Data: 2026-11-09. Dispositivo: Mi A3 (`0d7ae9df206e`), build profile, app separata `com.codecore.player.perf`, libreria di prova di `scripts/perf_library.py` (3000 brani).
Commit di partenza: `86547bca` (master), con il solo `find` dello script che riprova per 2 s (107.5).
Comando: `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label prima-107 --playback`. File grezzo: `build/perf/prima-107.md`.

Scansione di 3000 brani in 18,4 s. Avvio a freddo: mediana 2920 ms su 5 lanci; da `main` al primo frame 782 ms. Memoria (PSS) 240 MB.

| Scenario | Frame | build p50/p90/p99 ms | raster p50/p90/p99 ms | > 16,7 ms |
|---|---|---|---|---|
| Pallino schede | 81 | 3.1 / 7.3 / 73.7 | 7.1 / 10.7 / 17.3 | 7,4 % |
| Tutti i brani | 547 | 1.6 / 5.4 / 11.9 | 7.5 / 10.9 / 20.3 | 1,6 % |
| Album | 543 | 3.4 / 5.5 / 9.5 | 7.4 / 10.7 / 19.1 | 3,9 % |
| Libreria Tutto→Playlist→Album→Artisti | 238 | 3.5 / 7.6 / 43.5 | 7.6 / 12.1 / 14.5 | 4,6 % |
| Ricerca «notte» | 48 | 2.0 / 5.1 / 8.7 | 4.1 / 6.8 / 8.0 | 0,0 % |
| Scroll Libreria | 555 | 3.4 / 5.7 / 10.1 | 7.5 / 8.8 / 15.5 | 0,9 % |
| Lente Libreria | 153 | 5.8 / 13.4 / 32.2 | 5.1 / 8.5 / 16.8 | 5,2 % |
| Scroll Tutti i brani | 372 | 1.1 / 2.1 / 5.7 | 8.1 / 10.2 / 13.1 | 0,3 % |
| Cambio scheda | 238 | 1.9 / 7.8 / 52.8 | 5.6 / 8.8 / 16.5 | 6,3 % |
| Apri album | 63 | 1.6 / 6.9 / 52.3 | 11.0 / 15.6 / 22.3 | 11,1 % |
| In riproduzione | 164 | 3.5 / 11.3 / 24.3 | 5.9 / 10.3 / 18.7 | 2,4 % |
| Lettore dal dock | 489 | 3.2 / 11.0 / 28.4 | 6.5 / 9.1 / 16.2 | 3,1 % |
| Swipe mini player | 462 | 1.6 / 6.9 / 13.8 | 7.1 / 10.0 / 13.0 | 0,6 % |
| Fogli | 1350 | 4.3 / 12.8 / 26.7 | 5.8 / 8.1 / 14.3 | 4,1 % |
| Apertura player | 462 | 2.3 / 5.0 / 23.2 | 6.1 / 11.1 / 17.4 | 3,0 % |

Note:
- Diversi scenari oggi stanno già sopra l'1–2 % della fase 90 citato in «Metriche di arrivo». Alla 113 il confronto giusto è con questa tabella, stesso telefono e stesso comando.
- Gli scenari con meno di 100 frame (Pallino schede, Ricerca «notte», Apri album) sono rumorosi: un solo frame lento sposta la percentuale di 1–2 punti.

### Query su 50 000 brani

`flutter test test/data/performance_50k_test.dart` sul PC di sviluppo, stesso giorno. Soglie del test tra parentesi, prima del margine.

| Query | ms |
|---|---|
| Ricerca di testo (`LIKE`) | 36 (< 80) |
| Album | 101 (< 150) |
| Artisti | 76 (< 150) |
| Tutti i brani | 806 (< 1500) |
| Tutti i brani per artista | 820 (< 1500) |
| `liteEntries` (import) | 118 (< 400) |
| Generi | 35 (< 150) |
| Apertura del DB + prime query della Home | 103 (< 1000) |

## Dopo la 109 (`marquee-109`)

Data: 2026-11-10. Stesso dispositivo e comando con `--label marquee-109`; commit `156929eb` (fasi 108, 2b e 109). File grezzo: `build/perf/marquee-109.md`.

Scansione di 3000 brani in 16,8 s. Avvio a freddo: mediana 3124 ms su 5 (2721–3645). Memoria (PSS) 270 MB.

| Scenario | > 16,7 ms prima-107 | > 16,7 ms marquee-109 |
|---|---|---|
| Tutti i brani | 1,6 % | 0,9 % |
| Scroll Libreria | 0,9 % | 0,6 % |
| Scroll Tutti i brani | 0,3 % | 0,5 % |
| Lente Libreria | 5,2 % | 1,4 % |
| In riproduzione | 2,4 % | 1,8 % |
| Lettore dal dock | 3,1 % | 2,6 % |
| Swipe mini player | 0,6 % | 1,8 % |
| Fogli | 4,1 % | 1,9 % |
| Apertura player | 3,0 % | 2,2 % |

Scroll e player aperto non peggiorano. Lo swipe del mini player sale a 1,8 % (il titolo lungo ora scorre lì, con `RepaintBoundary`), dentro la soglia della fase 90 (1–2 %). Memoria +30 MB rispetto a prima-107, con in mezzo anche la fase 108.
