# Misure del refactor «ui-fluida»

Mi A3 (`0d7ae9df206e`), build profile, app separata `com.codecore.player.perf` (D-19), riproduzione attiva.
Comando: `python3 scripts/perf_device.py 0d7ae9df206e --label <label> --playback`. File grezzi in `build/perf/<label>.md`.
Gli scenari nuovi della 38.2 (Apri album, Fogli, Swipe mini player, Apertura player) contano solo i frame dei gesti
(da poco prima a 0,8 s dopo); gli altri usano la finestra intera dello scenario.

## Prima (`ui-fluida-prima`, 24/10, fase 38)

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok |
|---|---|---|---|---|---|---|
| Pallino schede | 154 | 5.9 / 20.9 | 10.4 / 18.6 | 5,8 % | ≤ 2 % | no |
| Tutti i brani | 359 | 4.9 / 8.4 | 9.3 / 14.7 | 0,8 % | ≤ 1 % | sì |
| Album | 707 | 3.3 / 4.7 | 7.3 / 14.9 | 1,0 % | ≤ 0,6 % | no |
| Ricerca «notte» | 142 | 4.1 / 57.4 | 7.8 / 13.1 | 3,5 % | ≤ 3 %, build p99 ≤ 16 ms | no |
| Apri album | 86 | 5.5 / 36.3 | 10.2 / 12.4 | 3,5 % | ≤ 3 % | no |
| Fogli | 1916 | 6.7 / 17.3 | 7.7 / 13.5 | 1,7 % | ≤ 3 % | sì |
| Swipe mini player | 357 | 8.5 / 101.3 | 8.6 / 19.4 | 8,7 % | ≤ 2 % | no |
| Apertura player | 538 | 10.8 / 116.0 | 11.2 / 20.4 | 9,5 % | ≤ 3 %, p99 ≤ 33 ms | no |
| In riproduzione | 478 | 8.8 / 69.1 | 7.9 / 16.5 | 7,7 % | non peggiorare | — |
| Lettore dal dock | 1024 | 11.5 / 70.6 | 8.9 / 16.4 | 9,2 % | — | — |
| Anello | 480 | 8.3 / 15.4 | 6.2 / 9.2 | 0,8 % | — | — |

| Altro | Valore | Soglia | ok |
|---|---|---|---|
| Avvio a freddo (mediana di 5) | 2575 ms | ≤ 2400 ms | no |
| Da `main` al primo frame | 740 ms | — | — |
| PSS | 262 MB | ≤ 210 MB | no |

Nota: avvio e PSS sono peggiori della misura del 22/10 (2363 ms, 201 MB) a parità di codice di prodotto. È probabile
che conti la libreria di prova più grande o lo stato del telefono, e la fase 39 lo verifica.

## Struttura (`python3 scripts/build_len.py lib/ui --metrics`, 24/10)

| Metrica | Prima | Arrivo |
|---|---|---|
| `databaseProvider\|RepositoryProvider` | 74 righe / 44 file | 0 |
| `SnackBar(` | 106 righe / 62 file | 1 |
| `AppBar(` | 48 righe / 42 file | 1 |
| `Duration(milliseconds` | 28 righe / 21 file | ≤ 3 (token) |
| `build` > 120 righe | 26 (di 314) | 0 |
| `build` > 150 righe | 15 | 0 |
| `build` più lungo | `library_screen.dart` 271 righe | ≤ 120 |

## Dopo la fase 39 (`fluidita-dopo`, 24/10)

Stesso telefono e stesso comando. Lo scorrimento di pagina è al 15 % della larghezza (D-46).

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Prima | Soglia | ok |
|---|---|---|---|---|---|---|---|
| Pallino schede | 129 | 7.2 / 19.8 | 8.6 / 22.5 | 3,9 % | 5,8 % | ≤ 2 % | no |
| Tutti i brani | 355 | 5.5 / 12.0 | 9.0 / 16.8 | 1,1 % | 0,8 % | ≤ 1 % | no (pari) |
| Album | 708 | 3.6 / 6.6 | 9.0 / 13.6 | 0,4 % | 1,0 % | ≤ 0,6 % | sì |
| Ricerca «notte» | 134 | 4.0 / 30.1 | 12.0 / 19.2 | 9,7 % | 3,5 % | ≤ 3 %, build p99 ≤ 16 ms | no |
| Apri album | 69 | 6.0 / 36.5 | 9.5 / 13.9 | 4,3 % | 3,5 % | ≤ 3 % | no |
| Fogli | 1744 | 7.6 / 19.0 | 7.8 / 12.5 | 1,8 % | 1,7 % | ≤ 3 % | sì |
| Swipe mini player | 376 | 5.6 / 148.9 | 8.5 / 17.1 | 8,2 % | 8,7 % | ≤ 2 % | no |
| Apertura player | 548 | 10.6 / 71.9 | 7.5 / 15.5 | 6,8 % | 9,5 % | ≤ 3 %, p99 ≤ 33 ms | no |
| In riproduzione | 562 | 8.5 / 67.3 | 7.9 / 14.9 | 5,5 % | 7,7 % | non peggiorare | sì |
| Lettore dal dock | 907 | 10.3 / 119.1 | 7.9 / 14.5 | 7,9 % | 9,2 % | — | — |
| Anello | 489 | 9.2 / 23.9 | 6.5 / 13.0 | 2,7 % | 0,8 % | — | — |

| Altro | Valore | Prima | Soglia | ok |
|---|---|---|---|---|
| Avvio a freddo (mediana di 5) | 2415 ms | 2575 ms | ≤ 2400 ms | no (quasi) |
| PSS | 271 MB (219 MB in un giro breve) | 262 MB | ≤ 210 MB | no |

Altri giri dello stesso codice danno numeri vicini ma non uguali: con 69–140 frame, un frame vale 0,7–1,4 punti, e
«Ricerca» va dal 4,4 % al 9,7 %. Lo scorrimento a tutta larghezza misurato a parte dava «Apri album» al 10 % (D-46).

**Soglie non raggiunte (D-37: annotate, si prosegue).** I picchi stanno nei frame di **build**, non nel raster:
- Swipe e apertura del player (p99 72–149 ms): il cambio di brano ricostruisce il player e decodifica la copertina.
  Da guardare: `cacheWidth` e `gaplessPlayback` in `track_art.dart`, e le card che dipendono dal brano.
- Ricerca: `smartSearch` gira ancora in modo sincrono dentro il provider (39.10 ha tolto solo le ricostruzioni di troppo).
- Pallino schede: il primo frame di una scheda mai aperta costruisce tutta la pagina.
- Avvio e PSS: la libreria di prova più grande pesa; si rimisurano in fase 44.

Struttura dopo la fase 39: `Duration(milliseconds` 13 righe in 4 file (10 sono i token in `tokens.dart`, D-44);
`build` > 150 righe 16, con `now_playing_screen` cresciuto per le card dopo la transizione.

## Dopo la fase 41 (mattoni condivisi, 24/10)

| Metrica | Prima (fase 38) | Dopo la 41 | Arrivo |
|---|---|---|---|
| `SnackBar(` in `lib/ui` | 106 righe / 62 file | 1 (`show_msg.dart`) | 1 |
| `AppBar(` non `CcAppBar` | 48 | 1 (`cc_app_bar.dart`) + 2 `SliverAppBar` + 4 `SelectableAppBar` (varianti dichiarate) | 1 |
| `showModalBottomSheet` | 1 | 1 (`showCcSheet`) | 1 |
| `CircularProgressIndicator` | 32 | 28 | ≤ 3 (non raggiunto: quasi tutti spinner d'azione dentro bottoni e righe, D-50) |
| `LinearProgressIndicator` | 19 | 19 | — (barre con valore, non stati a mano) |
| `.when(` in `lib/ui` | — | 10 (sliver, caricamento/errore propri) | — |
| dialoghi del nome | 6 copie | 1 (`promptName`) | 1 |
| `build` > 120 / > 150 righe | 26 / 15 | 27 / 16 (di 319) | fase 42 |
| `build` più lungo | `library_screen.dart` 271 | `library_screen.dart` 276 | fase 42 |

`lib/app.dart` ha ancora uno `SnackBar(` (avviso di nuova versione: messenger globale senza context, 8 s): fuori da `lib/ui`, resta.

## Dopo la fase 42 (livelli e tipi, 24/10)

| Metrica | Dopo la 41 | Dopo la 42 | Arrivo |
|---|---|---|---|
| `databaseProvider\|RepositoryProvider` in `lib/ui` | — | 0 (la UI passa dai provider/Ops; `architecture_test` a lista vuota) | 0 |
| `PopupMenuButton<String>` | — | 0 (un enum per menu) | 0 |
| `Set<int> _selected` | — | 0 (`selectionProvider` unico) | 0 |
| `selectionProvider('...')` con chiave stringa | — | 0 (`SelectionKey`) | 0 |
| `SimpleDialog` | — | 0 (`showCcSheet`) | 0 |
| `isOnlineId` in `lib/ui` | — | 0 (`track.trackKind`) | 0 |
| `SnackBar(` in `lib/ui` | 1 (`show_msg.dart`) | 1 (`show_msg.dart`) | 1 |
| `AppBar(` non `CcAppBar` | 1 + 2 `SliverAppBar` + 4 `SelectableAppBar` | invariato (7 righe: `cc_app_bar.dart`, 2 `SliverAppBar`, 4 `SelectableAppBar`) | 1 |
| `showModalBottomSheet` | 1 | 1 (`showCcSheet`) | 1 |
| `CircularProgressIndicator` | 28 | 26 | ≤ 3 (non raggiunto, D-50) |
| `LinearProgressIndicator` | 19 | 19 | — |
| `.when(` in `lib/ui` | 10 | 8 | — |
| dialoghi del nome (`promptName`) | 1 definizione, 7 call site | 1 definizione, 7 righe | 1 |
| `build` > 120 / > 150 righe | 27 / 16 (di 319) | 0 / 0 (di 370) | 0 |
| `build` più lungo | `library_screen.dart` 276 | `exportify_sync_screen.dart` 118 (le `build` sono divise in sezioni private) | < 120 |

`integration_test` su Linux, un file per volta: 5/5 verdi (`playback_test` ora verde dopo be3e937: il driver non registrava media_kit).

## Dopo la fase 43 (`nuovo-aspetto`, 24/10)

Stesso telefono e stesso comando (`--playback`). Giro completo sul codice di 43.1–43.6; le quattro righe con «†»
sono rimisurate (`nuovo-aspetto-2`) dopo le correzioni della review.

| Scenario | > 16,7 ms | build p99 ms | Dopo la 39 | Soglia | ok |
|---|---|---|---|---|---|
| Pallino schede † | 12,1 % | 43.6 | 3,9 % | ≤ 2 % | no |
| Tutti i brani | 1,2 % | 13.1 | 1,1 % | ≤ 1 % | no (pari) |
| Album | 0,8 % | 8.1 | 0,4 % | ≤ 0,6 % | no (pari) |
| Ricerca «notte» | 3,6 % | 71.7 | 9,7 % | ≤ 3 %, build p99 ≤ 16 ms | no |
| Apri album † | 5,7 % | 45.6 | 4,3 % | ≤ 3 % | no |
| Fogli | 2,3 % | 19.6 | 1,8 % | ≤ 3 % | sì |
| Swipe mini player † | 5,5 % | 31.0 | 8,2 % | ≤ 2 % | no |
| Apertura player † | 6,8 % | 44.7 | 6,8 % | ≤ 3 %, p99 ≤ 33 ms | no |
| In riproduzione | 5,9 % | 53.1 | 5,5 % | non peggiorare | sì (pari) |
| Lettore dal dock | 9,1 % | 106.9 | 7,9 % | — | — |
| Anello | 1,7 % | 20.1 | 2,7 % | — | — |

| Altro | Valore | Dopo la 39 | Soglia | ok |
|---|---|---|---|---|
| Avvio a freddo (mediana di 5) | 2493 ms | 2415 ms | ≤ 2400 ms | no |
| PSS | 254 MB (245 MB nel giro breve) | 271 MB | ≤ 210 MB | no |

**Pallino schede non viene dalla fase 43.** Bisezione, solo questo scenario e senza `--playback`: `master` prima
della 43 (ffdf9fd) 12,4 % · 43.1 13,0 % · 43.2 11,5 % · 43.3 9,7 %. Il salto da 3,9 % è entrato fra la fase 40 e la 42;
la 43 lo abbassa un poco. Da bisecare nelle fasi 40–42 (rimando in fase 44).

Soglie non raggiunte (D-41: annotate, si prosegue). Con 70–130 frame un frame vale 0,8–1,4 punti, quindi «Tutti i
brani» e «Album» sono pari. Gli altri picchi sono ancora nei frame di build (cambio di brano, prima apertura di una scheda).

## Finale (`ui-fluida-dopo`, 24/10, fase 44)

Stesso telefono e stesso comando (`--playback`), codice di `wip/fase-44` con il fix dello scaler (261f43e).

| Scenario | Prima | Dopo la 39 | Dopo (finale) | Soglia | ok |
|---|---|---|---|---|---|
| Pallino schede | 5,8 % | 3,9 % | 4,3 % | ≤ 2 % | no |
| Tutti i brani | 0,8 % | 1,1 % | 0,8 % | ≤ 1 % | sì |
| Album | 1,0 % | 0,4 % | 0,8 % | ≤ 0,6 % | no (pari) |
| Ricerca «notte» | 3,5 % · p99 57,4 ms | 9,7 % · p99 30,1 ms | 4,5 % · p99 35,0 ms | ≤ 3 %, build p99 ≤ 16 ms | no |
| Apri album | 3,5 % | 4,3 % | 7,9 % | ≤ 3 % | no |
| Fogli | 1,7 % | 1,8 % | 1,8 % | ≤ 3 % | sì |
| Swipe mini player | 8,7 % | 8,2 % | 8,1 % | ≤ 2 % | no |
| Apertura player | 9,5 % · p99 116,0 ms | 6,8 % · p99 71,9 ms | 7,4 % · p99 113,8 ms | ≤ 3 %, p99 ≤ 33 ms | no |
| Avvio a freddo (mediana di 5) | 2575 ms | 2415 ms | 2500 ms | ≤ 2400 ms | no |
| PSS | 262 MB | 271 MB | 270 MB | ≤ 210 MB | no |

- «Pallino schede» è stato al 12 % dalla fase 40 alla 43 perché `_AppTextScaler` in `lib/app.dart` non aveva `==` (a ogni rebuild ogni `Text` rifaceva il layout). Corretto in 261f43e su `wip/fase-44` (giro `fix-scaler`: 3,2 %); ora 4,3 %.
- Le soglie non raggiunte sono annotate (D-37, D-41). All'utente si chiede di accettarle o di aprire un seguito; la fase 44 non cambia codice di prodotto.
- Restano i picchi nei frame di build: il cambio di brano ricostruisce il player e decodifica la copertina, e la prima apertura di una scheda o pagina costruisce tutto. Le sezioni sopra spiegano il resto.
- Con 63–140 frame un frame vale 0,7–1,6 punti: «Album» (0,8 %) è a un frame dalla soglia, «Apri album» (63 frame) oscilla molto da un giro all'altro.

## Dopo la fase 45 (`streaming-45`, 25/10)

Stesso telefono e stesso comando (`--playback`). «Base oggi» = `origin/master` (6f29398) misurato lo stesso giorno, per separare il rumore dal codice. Tolleranza: un frame per scenario contro «Finale» (D-85).

| Scenario | Finale | Base oggi | Fase 45 (giro 1 · giro 2) | Dopo la correzione | ok |
|---|---|---|---|---|---|
| Pallino schede | 4,3 % | 3,4 % | 3,5 % · 4,3 % | — | sì |
| Tutti i brani | 0,8 % | 2,0 % | 1,4 % · 2,3 % | — | pari alla base di oggi (rumore) |
| Album | 0,8 % | 0,3 % | 0,7 % · 0,6 % | — | sì |
| Ricerca «notte» | 4,5 % · p99 35,0 ms | 3,4 % · p99 41,4 ms | 4,9 % · 2,8 % (p99 35,0 · 30,3 ms) | — | sì |
| Apri album | 7,9 % | 6,9 % | 8,2 % · 5,4 % | — | sì |
| Fogli | 1,8 % | 1,9 % | 2,3 % · 2,9 % | 1,6 % | sì, dopo la correzione |
| Swipe mini player | 8,1 % | 8,4 % | 9,5 % · 10,0 % | 7,8 % (build p99 55 ms, prima 128–148) | sì, dopo la correzione |
| Apertura player | 7,4 % · p99 113,8 ms | 8,2 % · p99 92,3 ms | 7,1 % · 7,3 % (p99 54,9 · 77,8 ms) | — | sì |
| Avvio a freddo (mediana di 5) | 2500 ms | 2557 ms | 2708 · 2418 ms | — | sì (pari alla base) |
| PSS | 270 MB | 268 MB | 269 · 259 MB | — | sì |

- Fogli e Swipe mini player erano oltre la base in entrambi i giri: `_syncPreparer` leggeva a ogni cambio di brano le righe intere (testi e curiosità) dei 30 brani successivi. Ora legge solo le righe `kind = 2`, leggere (78725da); misura `streaming-45-fix1` con `--only`.
- «Tutti i brani» supera «Finale» di 2–4 frame anche su `master` lo stesso giorno: è rumore del telefono, non della fase. Il giro sul ramo è a 1,4–2,3 % contro il 2,0 % della base.
- Report: `build/perf/streaming-45.md`, `streaming-45b.md`, `streaming-45-fix1.md`, `base-45.md`.

## Dopo la fase 46 (`streaming-46`, 25/10)

Stesso telefono e stesso comando (`--playback`). Tolleranza: un frame per scenario contro «Finale» (D-85, D-90).

| Scenario | Finale | Fase 46 | Ripetuto con `--only` | ok |
|---|---|---|---|---|
| Pallino schede | 4,3 % | 1,5 % | — | sì |
| Tutti i brani | 0,8 % | 2,4 % | — | pari alla fase 45 (2,3 %, rumore del telefono) |
| Album | 0,8 % | 1,1 % | — | sì (un frame) |
| Ricerca «notte» | 4,5 % · p99 35,0 ms | 3,5 % · build p99 75,0 ms | — | sì |
| Apri album | 7,9 % | 5,9 % | — | sì |
| Swipe mini player | 8,1 % | 10,5 % (build p99 151,8 ms) | 8,1 % (build p99 31,8 ms) | sì |
| Fogli | 1,8 % | 2,6 % | 2,6 % · 2,5 % · 2,4 % | **no**: 10–14 frame sopra, sotto la soglia del 3 % |
| Apertura player | 7,4 % · p99 113,8 ms | 4,1 % · build p99 49,3 ms | — | sì |
| Avvio a freddo (mediana di 5) | 2500 ms | 2392 ms | — | sì |
| PSS | 270 MB | 269 MB | — | sì |

- «Fogli» resta sopra «Finale» in quattro giri. Per i brani della libreria la fase 46 non aggiunge lavoro né al player né ai fogli (lo spinner compare solo in caricamento, `SwipeToQueue` è lo stesso widget spostato). Il dato non è del tutto confrontabile: con i brani da 1 s in riproduzione uiautomator spesso non trova lo stato «idle», e `perf_device.py` ora rilegge lo schermo in pausa e poi riprende (vedi `docs/gotchas.md`). Resta aperto come seguito: misurare `master` con lo stesso script.
- Report: `build/perf/streaming-46.md`, `streaming-46-only.md`, `streaming-46-fogli.md`, `streaming-46-fogli2.md`.

## Base 30 s (1c5348a) contro la fase 47 (`base30-1c5348a`, `jam-47`, 25/10)

Dalla fase 47 `perf_device.py` usa brani di prova da 30 s (con quelli da 1 s uiautomator non trovava lo stato «idle»): le misure precedenti non sono confrontabili una a una. Nuova base: l'APK di `master` dopo la fase 45 (`1c5348a`) con lo stesso script; poi giri alternati base/ramo sugli scenari dubbi (`rep-*`, `--only`, `--runs 1`).

| Scenario | Base 30 s | Fase 47 | Ripetuti base | Ripetuti fase 47 | ok |
|---|---|---|---|---|---|
| Pallino schede | 4,3 % | 5,7 % | 3,9 · 2,2 % | 4,7 · 2,9 % | sì (rumore) |
| Tutti i brani | 1,4 % | 5,9 % | 0,8 · 1,7 % | 6,7 · 0,8 % | sì (rumore: build p50 1 ms, picchi di raster) |
| Album | 0,8 % | 0,8 % | — | — | sì |
| Ricerca «notte» | 5,2 % | 3,0 % | — | — | sì |
| Apri album | 4,1 % | 6,0 % | — | — | sì (67 frame: 1 frame = 1,5 %) |
| In riproduzione | 1,6 % | 2,7 % | 2,1 · 2,2 % | 2,1 · 1,6 % | sì |
| Lettore dal dock | 2,6 % | 2,4 % | — | — | sì |
| Swipe mini player | 2,9 % | 3,3 % | 2,1 · 1,7 % | 2,3 · 2,9 % | sì |
| Fogli | 3,5 % | 3,6 % | — | — | sì |
| Apertura player | 1,7 % | 4,5 % | 2,8 · 4,5 % | 4,8 · 3,6 % | sì (rumore) |
| Anello | 1,7 % | 0,4 % | — | — | sì |
| Avvio a freddo | 2756 ms | 2697 ms | — | — | sì |
| PSS | 231 MB | 228 MB | — | — | sì |

- Il divario di «Fogli» della fase 46 era un artefatto dei brani da 1 s: con quelli da 30 s base e ramo sono pari.
- Gli scenari sopra un frame al primo giro rientrano negli intervalli della base nei giri alternati: nessuna regressione della fase 47.

## Dopo la fase 48 (`streaming-48`, 25/10)

Stesso telefono e script (brani da 30 s, `--playback`); confronto con la base 30 s (`1c5348a`), tolleranza un frame (D-85, D-90).

| Scenario | Base 30 s | Fase 48 | Ripetuti base | Ripetuti fase 48 | ok |
|---|---|---|---|---|---|
| Pallino schede | 4,3 % | 3,4 % | — | — | sì |
| Tutti i brani | 1,4 % | 1,1 % | 0,8 · 1,1 % | 1,6 · 0,8 % | sì |
| Album | 0,8 % | 3,2 % (695 frame) | 0,5 · 0,6 % | 0,8 · 0,5 % | sì: il primo giro ha contato il doppio dei frame, i ripetuti sono pari |
| Ricerca «notte» | 5,2 % | 3,6 % | — | — | sì |
| Apri album | 4,1 % | 7,2 % | 7,8 · 9,7 % | 7,2 · 5,5 % | sì (rumore; ~70 frame) |
| In riproduzione | 1,6 % | 1,9 % | — | — | sì |
| Lettore dal dock | 2,6 % | 1,7 % | — | — | sì |
| Swipe mini player | 2,9 % | 2,5 % | — | — | sì |
| Fogli | 3,5 % | 2,9 % | — | — | sì |
| Apertura player | 1,7 % | 2,9 % | — | — | sì (rientra nei ripetuti della base della fase 47: 2,8–4,5 %) |
| Anello | 1,7 % | 0,3 % | — | — | sì |
| Avvio a freddo | 2756 ms | 2439 ms | — | — | sì |
| PSS | 231 MB | 229 MB | — | — | sì |

- Report: `build/perf/streaming-48.md`, `r48-*.md` (giri alternati con `--only`; «Album» e «Apri album» richiedono anche «Tutti i brani» nell'elenco, che apre la scheda).

## Dopo la fase 53 (`arricchimento-53`, 26/10)

Stesso telefono e script (brani da 30 s, `--playback`), con il completamento dell'arricchimento acceso in sottofondo (D-133: tag e crediti). Tolleranza un frame per scenario (D-85, D-90): contro «Finale» e, dove «Finale» usava lo script vecchio, contro la base 30 s della fase 47.

| Scenario | Finale | Base 30 s | Fase 53 | Ripetuti (`--only`) | ok |
|---|---|---|---|---|---|
| Pallino schede | 4,3 % | 4,3 % | 3,4 % | — | sì |
| Tutti i brani | 0,8 % | 1,4 % | 0,8 % | 0,3 · 0,7 % | sì |
| Album | 0,8 % | 0,8 % | 1,3 % | 0,2 · 1,1 % | sì (rumore: i ripetuti stanno sotto e sopra «Finale») |
| Ricerca «notte» | 4,5 % | 5,2 % | 0,7 % | — | sì |
| Apri album | 7,9 % | 4,1 % | 1,9 % | 1,3 · 2,5 % | sì |
| In riproduzione | — | 1,6 % | 0,5 % | — | sì |
| Lettore dal dock | — | 2,6 % | 2,0 % | — | sì |
| Swipe mini player | 8,1 % | 2,9 % | 1,5 % | — | sì |
| Fogli | 1,8 % | 3,5 % | 3,2 % | 3,2 · 2,7 % | sì contro la base 30 s; sopra «Finale», misurato con i brani da 1 s (vedi fase 47) |
| Apertura player | 7,4 % | 1,7 % | 1,5 % | — | sì |
| Anello | — | 1,7 % | 2,2 % | 0,0 · 2,5 % | sì (rumore: ~300 frame, i ripetuti stanno sotto e sopra la base) |
| Avvio a freddo | 2500 ms | 2756 ms | 2583 ms | — | sì |
| PSS | 270 MB | 231 MB | 242 MB | — | sì |

- Report: `build/perf/arricchimento-53.md`, `r53-1.md`, `r53-2.md`, `r53-anello-1.md`, `r53-anello-2.md`. Misurato sull'APK costruito prima delle correzioni della review di architettura (rotellina, giro senza rete, elenco del giro pigro): nessuna tocca le liste e i fogli misurati.
- Il completamento era in corso durante gli scenari (pillola «1» nell'intestazione) e si mette in pausa mentre si scorre: nessuno scenario peggiora contro la base.

## Dopo la fase 54 e la correzione delle schede nascoste (27/10)
Mi A3, app perf (`mia3-54-rip`, poi `mia3-54-fix` con `TickerMode` sulle schede nascoste e `RepaintBoundary` sulla rotellina, 12227c7).

| Scenario | 54 (prima) | 54 + correzione | Fase 53 | Entro un frame |
|---|---|---|---|---|
| Tutti i brani | 2,1 · 2,8 % | 0,8 % | 0,3 · 1,4 % | sì |
| Apri album | 2,5 % | 1,6 % | 1,3 · 2,5 % | sì |
| Apertura player | 2,1 % | 3,2 % | 1,5 % | sì (rumore storico 1,5–3 %) |

Motorola, app vera con `--real` (2312 brani veri, schermo a 120 Hz, conteggio contro 16,7 ms): «Pallino schede» da 8 · 17 % a 0,1 %, «Tutti i brani» da 0,2 % a 0,0 %. Causa: la rotellina indeterminata del pulsante Attività e le schede fuori schermo dell'`IndexedStack` che continuavano ad animare ridisegnavano tutto lo schermo a ~100 fps. Resta: la rotellina visibile ridisegna il suo riquadro a 120 fps mentre un'attività gira (~800 frame in 8 s, raster ~8 ms): costo di batteria, seguito possibile.
