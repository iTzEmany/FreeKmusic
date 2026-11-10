# Misure del refactor «ui-jam-ricerca»

Data: 2026-10-28. Dispositivo: Mi A3 (`0d7ae9df206e`), build profile, app separata `com.codecore.player.perf`.
Commit di partenza: `d3c03bb` (ramo `test/58-rete-jam-ricerca`). Senza `--playback`.
Comando: `python3 scripts/perf_device.py 0d7ae9df206e --label ui-jam-ricerca-prima --only "Pallino schede,Tutti i brani,Album,Ricerca «notte»,Fogli,Swipe mini player,Apertura player,Anello"`
(Tutti i brani e Album servono: gli scenari sono concatenati.) File grezzo: `build/perf/ui-jam-ricerca-prima.md`.
Soglie: fase 38 (vedi `docs/refactor/ui-fluida/misure.md`, D-57, D-175).

## Prima (`ui-jam-ricerca-prima`)

PSS 247 MB (soglia ≤ 210 MB, fuori). Scansione 3000 brani in 18,2 s.

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok |
|---|---|---|---|---|---|---|
| Pallino schede | 1646 | 7.1 / 12.5 | 7.3 / 11.9 | 0,9 % | ≤ 2 % | sì |
| Tutti i brani | 453 | 5.8 / 14.6 | 8.7 / 23.7 | 4,0 % | ≤ 1 % | no |
| Album | 1179 | 5.0 / 9.3 | 7.1 / 13.6 | 0,5 % | ≤ 0,6 % | sì |
| Ricerca «notte» | 142 | 4.1 / 34.5 | 7.5 / 14.7 | 2,8 % | ≤ 3 %, build p99 ≤ 16 ms | no (build p99) |
| Swipe mini player | 387 | 4.6 / 14.2 | 7.0 / 10.7 | 0,3 % | ≤ 2 % | sì |
| Fogli | 1258 | 11.7 / 25.2 | 7.2 / 12.2 | 3,7 % | ≤ 3 % | no |
| Apertura player | 412 | 4.7 / 35.1 | 8.3 / 13.2 | 2,4 % | ≤ 3 %, p99 ≤ 33 ms | no (build p99 35,1) |
| Anello | 305 | 9.7 / 13.6 | 5.2 / 8.4 | 0,3 % | — | — |

## Dopo la fase 60 (`ui-jam-ricerca-60`)

Data: 2026-10-28. Commit `0acd0f1` (ramo `refactor/60-ricerca-e-dock`), stesso dispositivo e comando di «Prima» con `--only "Pallino schede,Tutti i brani,Album,Ricerca «notte»,Fogli,Swipe mini player"`. File grezzo: `build/perf/ui-jam-ricerca-60.md`.

PSS 249 MB (Prima 247, +0,8 %; soglia ≤ 210 MB, fuori come prima). Scansione 3000 brani in 17,0 s (Prima 18,2).

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | Confronto con Prima |
|---|---|---|---|---|---|---|---|
| Pallino schede | 1623 | 6.8 / 11.4 | 7.1 / 16.2 | 1,2 % | ≤ 2 % | sì | > 16,7: 0,9 → 1,2 % (+0,3 pt), build p99 migliore |
| Tutti i brani | 455 | 5.6 / 12.4 | 8.1 / 15.3 | 1,1 % | ≤ 1 % | no (di 0,1 pt) | 4,0 → 1,1 %: molto meglio |
| Album | 1179 | 5.0 / 9.1 | 7.6 / 17.7 | 1,6 % | ≤ 0,6 % | no | 0,5 → 1,6 %: PEGGIO (+1,1 pt), raster p99 13,6 → 17,7 |
| Ricerca «notte» | 138 | 6.6 / 31.5 | 6.9 / 12.4 | 3,6 % | ≤ 3 %, build p99 ≤ 16 ms | no (> 3 % e build p99) | build p99 34,5 → 31,5 (-9 %, ancora il doppio della soglia); > 16,7: 2,8 → 3,6 % (+0,8 pt, +29 % relativo): PEGGIO |
| Swipe mini player | 423 | 6.4 / 15.6 | 7.9 / 10.3 | 0,9 % | ≤ 2 % | sì | 0,3 → 0,9 %, build p99 14,2 → 15,6 (+10 %), dentro soglia |
| Fogli | 1350 | 9.1 / 22.8 | 7.1 / 12.0 | 2,7 % | ≤ 3 % | sì | 3,7 → 2,7 %: meglio, ora dentro soglia |

Esito (D-170: oltre soglia ≤ 10 % accettato, peggio blocca):
- Swipe mini player: dentro soglia (0,9 % ≤ 2 %), nessun blocco.
- Ricerca «notte»: build p99 31,5 ms resta oltre 16 ms ma è migliorato del 9 % rispetto a Prima (34,5): non peggiora. La quota di frame > 16,7 ms invece sale da 2,8 a 3,6 % ed esce dalla soglia ≤ 3 %: peggio rispetto a Prima, quindi blocca secondo D-170. Campione piccolo (138 frame: 5 frame lenti contro 4).
- Album peggiora (0,5 → 1,6 %, oltre soglia 0,6 %) in raster, non in build: blocca secondo D-170.
- Tutti i brani resta 0,1 pt sopra soglia ma migliora molto (4,0 → 1,1 %): non è un peggioramento, accettato come miglioramento parziale.
- Pallino schede +0,3 pt (dentro soglia). Fogli passa in soglia.
### Dopo la correzione 60.6 (`ui-jam-ricerca-60b`, 9aae22d)

Stesso comando con `--only "Pallino schede,Tutti i brani,Album,Ricerca «notte»"`. File grezzo: `build/perf/ui-jam-ricerca-60b.md`. PSS 224 MB (Prima 247, -60: 249), scansione 16,9 s.

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | Prima | -60 |
|---|---|---|---|---|---|---|---|---|
| Pallino schede | 1626 | 6.9 / 12.1 | 13.4 / 20.4 | 5,4 % | ≤ 2 % | no | 0,9 % | 1,2 % |
| Tutti i brani | 463 | 5.3 / 13.2 | 8.3 / 15.4 | 0,6 % | ≤ 1 % | sì | 4,0 % | 1,1 % |
| Album | 1183 | 4.0 / 6.8 | 6.8 / 13.0 | 0,6 % | ≤ 0,6 % | sì | 0,5 % | 1,6 % |
| Ricerca «notte» | 143 | 5.2 / 27.5 | 7.6 / 14.6 | 4,9 % | ≤ 3 %, build p99 ≤ 16 ms | no | 2,8 %, build p99 34,5 | 3,6 %, build p99 31,5 |

Esito: Album rientra (0,6 %, uguale alla soglia; Prima 0,5) e Tutti i brani rientra. Ricerca «notte»: build p99 27,5 ms (meglio di Prima -20 % e di -60 -13 %) ma ancora sopra 16 ms, e i frame > 16,7 ms salgono a 4,9 % (7 su 143; Prima 2,8, -60 3,6): peggio di Prima, blocca secondo D-170. Pallino schede 5,4 % è un peggioramento forte (Prima 0,9) dovuto al raster (p90 13,4, p99 20,4) mentre il build è invariato: scenario che non tocca la ricerca, possibile rumore del telefono o effetto del lavoro in isolate; da riconfermare con una seconda misura prima di attribuirlo al codice.
### Dopo la review (`ui-jam-ricerca-60c`, bbf2879)

Stesso comando di `-60b` con `--only "Pallino schede,Tutti i brani,Album,Ricerca «notte»"`. File grezzo: `build/perf/ui-jam-ricerca-60c.md`. PSS 221 MB (Prima 247), scansione 17,4 s. Nota: in `-60b` il precaricamento al focus non era attivo (non partiva); in `-60c` lo è.

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | Prima | -60 | -60b |
|---|---|---|---|---|---|---|---|---|---|
| Pallino schede | 1707 | 6.1 / 9.9 | 7.1 / 10.5 | 0,5 % | ≤ 2 % | sì | 0,9 % | 1,2 % | 5,4 % |
| Tutti i brani | 460 | 6.0 / 13.7 | 8.2 / 11.8 | 0,9 % | ≤ 1 % | sì | 4,0 % | 1,1 % | 0,6 % |
| Album | 1180 | 4.5 / 9.6 | 7.3 / 16.0 | 0,9 % | ≤ 0,6 % | no (+0,3 pt) | 0,5 % | 1,6 % | 0,6 % |
| Ricerca «notte» | 139 | 6.4 / 26.1 | 7.1 / 16.1 | 2,9 % | ≤ 3 %, build p99 ≤ 16 ms | no (solo build p99) | 2,8 %, p99 34,5 | 3,6 %, p99 31,5 | 4,9 %, p99 27,5 |

Esito: Ricerca «notte» ha ora la quota di frame lenti dentro soglia (2,9 %, praticamente come Prima 2,8) e build p99 26,1 ms: -24 % rispetto a Prima (34,5) ma ancora oltre i 16 ms. Non peggio di Prima, ma resta fuori soglia come Prima. Album 0,9 % è sopra 0,6 % (Prima 0,5, +0,4 pt; 11 frame su 1180, variazione tra run vista anche in `-60b`/`-60`): peggio di Prima, per D-170 blocca. Pallino schede e Tutti i brani in soglia.

## Dopo (fase 64)

Data: 2026-10-28. Ramo `chore/64-chiusura-jam-ricerca` (= `d7a528a`), stesso dispositivo e comando di «Prima» (`--label ui-jam-ricerca-dopo`, tutti e 8 gli scenari). File grezzo: `build/perf/ui-jam-ricerca-dopo.md`. PSS 252 MB (Prima 247, soglia ≤ 210 MB, fuori come prima), scansione 17,2 s (Prima 18,2).

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | Prima |
|---|---|---|---|---|---|---|---|
| Pallino schede | 1678 | 7.5 / 11.7 | 9.7 / 20.0 | 4,1 % | ≤ 2 % | no | 0,9 % |
| Tutti i brani | 466 | 4.9 / 7.5 | 7.3 / 13.7 | 0,9 % | ≤ 1 % | sì | 4,0 % |
| Album | 1192 | 3.6 / 5.7 | 6.4 / 9.5 | 0,1 % | ≤ 0,6 % | sì | 0,5 % |
| Ricerca «notte» | 134 | 4.7 / 21.3 | 9.4 / 27.7 | 9,0 % | ≤ 3 %, build p99 ≤ 16 ms | no | 2,8 %, build p99 34,5 |
| Swipe mini player | 504 | 5.7 / 13.8 | 7.7 / 12.5 | 0,4 % | ≤ 2 % | sì | 0,3 % |
| Fogli | 1603 | 11.3 / 24.0 | 7.5 / 12.3 | 2,7 % | ≤ 3 % | sì | 3,7 % |
| Apertura player | 451 | 5.9 / 22.0 | 8.3 / 14.4 | 2,0 % | ≤ 3 %, p99 ≤ 33 ms | sì | 2,4 %, build p99 35,1 |
| Anello | 491 | 6.6 / 13.4 | 5.8 / 10.2 | 0,4 % | — | — | 0,3 % |

Esito: fuori soglia restano Pallino schede (4,1 % contro ≤ 2 %, +3,2 pt rispetto a Prima, raster p90 9,7 / p99 20,0 con build invariato) e Ricerca «notte» (9,0 % contro ≤ 3 % e build p99 21,3 ms contro 16: D-176, ma -38 % rispetto a Prima 34,5; i frame lenti sono 12 su 134 e dominati dal raster p99 27,7). Tutti gli altri scenari sono in soglia e Tutti i brani, Fogli e Apertura player migliorano rispetto a Prima.
Rumore: seconda misura (`ui-jam-ricerca-dopo-b`, `build/perf/ui-jam-ricerca-dopo-b.md`, PSS 243 MB) più rumorosa: Pallino 5,6 %, Tutti i brani 5,3 %, Album 9,6 % (raster p90 12-16 ms in scenari non toccati dalla fase: rumore del telefono), Fogli 3,6 %; Ricerca «notte» 2,2 % ma build p99 22,0 ms (D-176 confermato), Swipe 0,4 %, Apertura 1,6 %, Anello 0,9 %. Pallino schede è fuori soglia in entrambe le run (4,1 e 5,6 %), quindi non è solo rumore; la sua % di frame lenti è dominata dal raster, non dal build. Il 9,0 % di Ricerca nella prima run è rumore di raster (2,2 % nella seconda).
Storia di Pallino schede sullo stesso codice delle schede: Prima 0,9 · -60 1,2 · -60b 5,4 · -60c 0,5 · -61 7,4 · -61b 0,5 · dopo 4,1 · dopo-b 5,6 %. È bimodale: con raster p90 ~7 ms sta in soglia, con raster p90 13-16 ms (telefono caldo o occupato) no, e fra -60b e -60c non è cambiato nulla delle schede. Terza misura (`-dopo-c`, telefono sbloccato, batteria 28,5 °C, nessun cool-down a schermo spento): 4,7 % (1558 frame), raster p90/p99 15,7 / 18,5 ms, build p90/p99 7,1 / 12,5 ms: ancora fuori soglia (≤ 2 %), raster alto come in -60b/-61/dopo-b. Prova A/B (richiesta dell'utente, telefono sbloccato, stessa libreria, solo «Pallino schede», APK alternati): `7eb133f` (prima della fase 62) 1,8 % e 5,1 %; `d7a528a` (master, fase 63) 0,6 % e 0,6 % (raster p90 7,8 / 7,9 ms). File grezzi `build/perf/ab-61-1.md`, `ab-63-1.md`, `ab-61-2.md`, `ab-63-2.md`. Il codice attuale non è peggiore di quello di prima e sta in soglia in entrambe le run: i valori alti erano rumore del telefono. **Pallino schede: in soglia.**

## Dopo la fase 61 (`ui-jam-ricerca-61`, e386916)

Data: 2026-10-28. Ramo `refactor/61-fogli-ovunque`, stesso dispositivo e comando di «Prima» con `--only "Pallino schede,Tutti i brani,Album,Ricerca «notte»,Fogli"`. File grezzo: `build/perf/ui-jam-ricerca-61.md`. PSS 258 MB (Prima 247, -60c 221), scansione 20,7 s (Prima 18,2).

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | Prima | -60c |
|---|---|---|---|---|---|---|---|---|
| Pallino schede | 1697 | 7.5 / 11.6 | 16.1 / 20.1 | 7,4 % | ≤ 2 % | no | 0,9 % | 0,5 % |
| Tutti i brani | 457 | 6.1 / 11.4 | 12.7 / 20.6 | 5,3 % | ≤ 1 % | no | 4,0 % | 0,9 % |
| Album | 1179 | 5.4 / 8.7 | 8.4 / 16.7 | 1,1 % | ≤ 0,6 % | no | 0,5 % | 0,9 % |
| Ricerca «notte» | 135 | 4.8 / 23.7 | 7.2 / 21.4 | 4,4 % | ≤ 3 %, build p99 ≤ 16 ms | no | 2,8 %, p99 34,5 | 2,9 %, p99 26,1 |
| Fogli | 1278 | 10.4 / 25.6 | 7.9 / 12.3 | 3,4 % | ≤ 3 % | no (+0,4 pt) | 3,7 % | 2,7 % (-60) |

Esito: Fogli 3,4 % è sopra la soglia ≤ 3 % (Prima 3,7, -60 2,7): meglio di Prima, peggio di -60. Build p99 25,6 ms (-60: 22,8), raster invariato (p90 7,9). Pallino schede e Tutti i brani hanno raster p90 alto (16,1 e 12,7 ms) in scenari che la fase non tocca, come già visto in `-60b` (Pallino 5,4 %): telefono rumoroso (PSS e scansione più alti del solito), da riconfermare con una seconda misura prima di attribuire la regressione al codice.

### Seconda misura (`ui-jam-ricerca-61b`, 7d43e2a)

Stesso comando; telefono a riposo (batteria 29,8 °C, solo l'app di misura in primo piano). File grezzo: `build/perf/ui-jam-ricerca-61b.md`. PSS 247 MB (come Prima), scansione 15,9 s (-61: 20,7).

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms | Soglia | ok | -61 | Prima |
|---|---|---|---|---|---|---|---|---|
| Pallino schede | 1748 | 6.6 / 11.8 | 6.8 / 11.0 | 0,5 % | ≤ 2 % | sì | 7,4 % | 0,9 % |
| Tutti i brani | 469 | 4.6 / 9.4 | 7.3 / 16.8 | 1,1 % | ≤ 1 % | no (+0,1 pt) | 5,3 % | 4,0 % |
| Album | 1177 | 3.7 / 7.3 | 6.5 / 13.0 | 0,3 % | ≤ 0,6 % | sì | 1,1 % | 0,5 % |
| Ricerca «notte» | 140 | 5.0 / 33.4 | 6.8 / 10.8 | 4,3 % | ≤ 3 %, build p99 ≤ 16 ms | no | 4,4 %, p99 23,7 | 2,8 %, p99 34,5 |
| Fogli | 1430 | 11.8 / 22.2 | 7.4 / 12.4 | 2,9 % | ≤ 3 % | sì | 3,4 % | 3,7 % |

Esito: la misura -61 era rumore del telefono; Fogli rientra (2,9 % ≤ 3 %, Prima 3,7). Ricerca «notte» resta fuori soglia come in Prima (fuori fase 61).

## Fase 68

Data: 2026-10-29. Mi A3 (`0d7ae9df206e`), app perf separata (`com.codecore.player.perf`, libreria già sul telefono). Ramo `feat/68-scoperta-chiusura` (HEAD `7b6d68e`, con il banner della Jam della fase 67 sopra il dock). Comando: `python3 scripts/perf_device.py 0d7ae9df206e --label fase68 --no-push --only "Pallino schede,Fogli,Apertura player,Swipe mini player"`; seconda run `--label fase68-b --no-build --apk <stesso APK>`. File grezzi: `build/perf/fase68.md`, `build/perf/fase68-b.md`. PSS 234 / 219 MB.

| Scenario | Frame | build p90/p99 ms | raster p90/p99 ms | > 16,7 ms (run 1 / run 2) | Soglia | fase 64 (run 1 / `-b`) |
|---|---|---|---|---|---|---|
| Pallino schede | 1655 / 1653 | 6.0 / 10.8 · 6.8 / 11.5 | 7.7 / 17.5 · 14.5 / 19.7 | 1,6 % / 5,6 % | ≤ 2 % | 4,1 % / 5,6 % |
| Swipe mini player | 401 / 390 | 3.8 / 15.5 · 5.7 / 13.8 | 7.2 / 10.8 · 7.3 / 11.6 | 1,0 % / 0,5 % | ≤ 2 % | 0,4 % / 0,4 % |
| Fogli | 1382 / 1326 | 12.9 / 26.2 · 11.3 / 26.0 | 8.5 / 16.1 · 7.7 / 13.6 | 5,1 % / 3,4 % | ≤ 3 % | 2,7 % / 3,6 % |
| Apertura player | 419 / 436 | 5.4 / 20.5 · 6.8 / 19.3 | 8.6 / 15.7 · 9.3 / 17.6 | 2,9 % / 3,0 % | ≤ 3 %, p99 ≤ 33 ms | 2,0 % / 1,6 % |

Esito: nessun peggioramento oltre il rumore. Pallino schede è bimodale come noto (1,6 % con raster p90 7,7; 5,6 % con raster p90 14,5 a build invariato). Swipe e Apertura player in soglia. Fogli supera 3 % in entrambe le run (5,1 e 3,4 %) ma build p90/p99 è uguale alla fase 64 (11,3 / 24,0) e il valore della seconda run coincide con `-b` della fase 64 (3,6 %): non è peggio oltre il rumore.

Prova A/B su Fogli (richiesta di §68.2, telefono sbloccato, stessa libreria, APK alternati A B A B, perf build `--profile` con `CODECORE_PERF`): A = `310ce66` (prima della fase 66), B = `7b6d68e` (fase 68, l'APK delle due run). Fogli > 16,7 ms: A 2,4 % e 3,0 %, B 2,3 % e 4,0 %; build p90/p99 A 8,0 / 23,9 e 11,8 / 23,8, B 8,4 / 22,1 e 12,2 / 26,5; raster p90 7,2-7,8 ovunque. File grezzi `build/perf/ab68-A1.md`, `ab68-B1.md`, `ab68-A2.md`, `ab68-B2.md`. Esito: la variazione tra due run dello stesso APK (A 2,4 contro 3,0; B 2,3 contro 4,0) è più grande della differenza tra A e B: B non è peggio di A. **Fogli: nessun peggioramento dovuto alle fasi 66-68** (il 5,1 % della prima run era rumore del telefono, build p90 12,9 ms come A2).
