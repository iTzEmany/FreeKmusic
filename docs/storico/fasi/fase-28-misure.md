# Fase 28 — misure prima e dopo

Come si misura (28.1) e cosa è cambiato (28.10). Il telefono di riferimento è il **Mi A3** (Snapdragon 665,
3,7 GB, Android 11, 60 Hz: **16,7 ms** a frame); prima che fosse disponibile alcune misure sono state fatte sul
Motorola edge 40, segnate come tali.

## Strumenti
- **App vera** — `scripts/perf_device.py <id-adb> --real --apk <apk>` misura `com.codecore.player` con la libreria vera senza toccare i dati (APK con `--dart-define=CODECORE_PERF_REAL=true`: registra solo i frame; niente `pm clear`, push, riproduzione; cancella `perf/events.jsonl` alla fine).
- **Telefono** — `scripts/perf_library.py` crea in `build/perf_library/` 3000 brani da 1 s in 300 album
  (copertina `cover.jpg` 1200×1200 per album, ~50 MB). `scripts/perf_device.py <id-adb> --label <nome>`
  compila la build *profile* come **app separata** `com.codecore.player.perf` (`CODECORE_PERF=1`, dati suoi:
  la libreria vera non si tocca), le passa la libreria, aspetta la scansione e l'«arricchimento» finto
  (testi, testi sincronizzati e curiosità su ogni brano, ~6 KB), poi misura: avvio a freddo (`am start -W`
  ×5 e tempo da `main` al primo frame), memoria (PSS), e i frame mentre scorre «Tutti i brani», «Album»,
  la ricerca e, con `--playback`, «In riproduzione». Tabella in `build/perf/<nome>.md`.
  I frame li misura l'app stessa (`FrameTiming`, `lib/services/perf/perf_probe.dart`, compilato solo nella
  build perf): `dumpsys gfxinfo` non vede i frame di Flutter, che disegna su una superficie sua.
- **Emulatore / CI** — `integration_test/perf_test.dart` (in `scripts/integration.sh`, job manuale
  «integration» della CI): stesso giro su 3000 brani arricchiti, tempi dei frame stampati (`perf28 …`).
  In debug i numeri valgono solo come confronto tra loro.
- **PC** — `test/data/performance_lists_test.dart` (3000 brani arricchiti) e `performance_50k_test.dart`;
  `CODECORE_PERF_MARGIN=1` per i numeri veri.

## Prima (2026-10-20/21, commit con tag `perf-prima`; Mi A3: Android 11, 3,7 GB, schermo a 60 Hz)
| Cosa | Valore | Dove |
|---|---|---|
| «Tutti i brani», un aggiornamento dell'elenco, 3000 brani arricchiti | 19 ms, **29,7 MB di testo** nelle righe | PC |
| 50 000 brani: ricerca / album / artisti / tutti i brani / per artista | 32 / 83 / 71 / 832 / 805 ms | PC |
| Ricerca YouTube · YouTube Music (già con 28.4) | 1,0–1,3 s · 1,1–1,7 s | Motorola, LTE |
| Scansione di 3000 brani (300 copertine da 1200 px) | 17,1 s | Mi A3 |
| Avvio a freddo (`am start -W`, mediana di 5) · da `main` al primo frame | **2521 ms** · 681 ms | Mi A3 |
| Memoria (PSS totale) dopo il giro | 231 MB | Mi A3 |
| «Tutti i brani»: frame, build p50/p90/p99, raster p50/p90/p99, oltre 16,7 ms | 353 · 1,3/5,8/13,6 · 6,9/10,4/18,6 · **2,3 %** | Mi A3 |
| «Album» (griglia) | 680 · 1,2/5,7/14,8 · 6,4/8,2/13,2 · 1,0 % | Mi A3 |
| Ricerca «notte» (scrittura e scorrimento) | 89 · 2,2/6,2/32,5 · 4,9/7,5/28,5 · **4,5 %** | Mi A3 |

Ogni scrittura nella tabella dei brani (un download, un arricchimento) fa ripartire le query degli elenchi
aperti: con le righe intere sono ~30 MB di testo copiati a ogni brano scaricato durante un'importazione.

## Dopo, task per task
| Task | Cosa | Prima → dopo | Dove |
|---|---|---|---|
| 28.2 | «Tutti i brani», 3000 brani arricchiti: testo nelle righe | 29,7 MB → **0,4 MB** | PC |
| 28.2 | Stesso elenco con il database in un isolate a parte, come nell'app | 88 ms → **14 ms** a ogni aggiornamento | PC |
| 28.2 | 50 000 brani: ricerca / album / artisti / tutti i brani / per artista | 32 / 83 / 71 / 832 / 805 → 34 / 79 / 68 / 820 / 785 ms (invariati) | PC |
| 28.3 | Decodificare una copertina per una riga di elenco (132 px): JPEG 1200 px / JPEG 3000 px / PNG 3000 px → miniatura 320 px | 8,6 / 50 / 138 ms → **2,9 ms** | PC |
| 28.2–28.9 | Mi A3, stesso giro del «prima» (tag `perf-prima` → commit delle microanimazioni) | | |
| | Scansione di 3000 brani | 17,1 → **13,2 s** (35,2 s finché la scansione aspettava le miniature: ora vanno in coda) | Mi A3 |
| | Avvio a freddo (mediana di 5) · da `main` al primo frame | 2521 → **2319 ms** · 681 → **619 ms** | Mi A3 |
| | Memoria (PSS) | 231 → **212 MB** | Mi A3 |
| | «Tutti i brani»: build p90/p99 · oltre 16,7 ms | 5,8/13,6 → 5,3/11,7 ms · 2,3 → 2,5 % | Mi A3 |
| | «Album»: build p90/p99 · oltre 16,7 ms | 5,7/14,8 → **3,5/5,1** ms · 1,0 → 0,9 % | Mi A3 |
| | Ricerca «notte»: oltre 16,7 ms | 4,5 → 5,3 % (un frame di ~80 ms quando i risultati compaiono la prima volta; la normalizzazione a ogni tasto, 3 ms → 0,5 ms sul PC, non era la causa) | Mi A3 |

### Dove va l'avvio (Mi A3)
Su ~2,3 s di avvio a freddo, ~1,7 s passano prima di `main` (processo Android, motore Flutter, plugin) e
~250 ms nella **prima chiamata qualsiasi verso Android** (le cartelle dell'app), che aspetta che l'attività sia
pronta: tolto l'`await` dell'orientamento, l'attesa si è spostata sulla chiamata successiva. Il resto di `main`
(servizio audio, impostazioni, widget) fa ~200 ms. L'obiettivo di 2 s non è raggiunto sul Mi A3: la parte nostra
è ~0,6 s.

## Misura finale (28.10, 2026-10-21, Mi A3, build profile, stesso giro del «prima»)
| Cosa | Prima | Dopo |
|---|---|---|
| Scansione di 3000 brani | 17,1 s | **14,0 s** |
| Avvio a freddo (mediana di 5) | 2521 ms | **2348 ms** |
| Da `main` al primo frame | 681 ms | **630 ms** |
| Memoria (PSS) | 231 MB | **187 MB** |
| «Tutti i brani»: build p90/p99 · raster p90/p99 · oltre 16,7 ms | 5,8/13,6 · 10,4/18,6 · 2,3 % | 5,4/11,2 · 10,1/15,1 · **0,3 %** |
| «Album»: build p90/p99 · raster p90/p99 · oltre 16,7 ms | 5,7/14,8 · 8,2/13,2 · 1,0 % | 3,4/6,2 · 8,3/15,0 · **0,9 %** |
| Ricerca «notte»: build p99 · oltre 16,7 ms | 32,5 ms · 4,5 % | 40,1 ms · **2,3 %** |
| Ricerca online YouTube / YouTube Music (Wi‑Fi, build debug) | yt-dlp: 6–7 s / 14 s e oltre | **1,7–2,0 s / 1,6–2,2 s** |
| «Ascolta» YouTube: primo suono | — | ~12 s (indirizzo da yt-dlp in 9,6 s) |

### Obiettivi
| Obiettivo | Esito |
|---|---|
| Scorrimento di elenchi e griglie: p90 ≤ 16 ms, < 2 % di frame persi | **Rispettato** (p90 ≤ 10 ms su UI e raster; 0,3 % e 0,9 %) |
| Avvio a freddo < 2 s con 3000 brani | **Non rispettato: 2,35 s.** ~1,7 s passano prima di `main` (processo, motore Flutter, plugin) e ~250 ms nella prima chiamata verso Android, che aspetta l'attività; la parte dell'app è ~0,6 s. Ridurlo ancora vorrebbe dire mostrare una schermata finta prima dei dati, che non è più veloce davvero |
| Ricerca nella libreria < 100 ms | **Rispettato** (query di 50 000 brani 34 ms sul PC; il filtro di artisti e album 0,5 ms a tasto; sul Mi A3 il frame più lento della scrittura 40 ms) |
| Ricerca online: primi risultati < 1,5 s | **Rispettato sul Motorola** (1,0–1,3 s), **non sul Mi A3** (1,6–2,2 s): la sola stretta di mano TLS con youtube.com misurata con `curl` dal Mi A3 costa 1,1–2,6 s; la risposta, con la maschera dei campi, pesa 2 KB compressa (28 KB prima) |

### Aperti
- «Ascolta» di SoundCloud sul Mi A3: timeout di ExoPlayer sul CDN HLS (R71); ricerca SoundCloud via yt-dlp 36 s sul Mi A3.
- Un frame di 40–80 ms quando i risultati della ricerca nella libreria compaiono la prima volta (da guardare con il profilo di Flutter).

