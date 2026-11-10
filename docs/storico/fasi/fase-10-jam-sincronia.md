# Fase 10 — Riproduzione sincronizzata nella Jam

**Obiettivo:** più dispositivi della stessa Jam suonano **lo stesso brano nello stesso istante** (scarto
obiettivo ≤ 80 ms su Wi‑Fi, senza Bluetooth). Fino alla Fase 9 suona un solo dispositivo alla volta.
**Prerequisiti:** Fase 8 e 9. Solo rete locale, nessun server esterno.

## Decisioni (da confermare all'avvio dell'obiettivo)
| Tema | Decisione proposta |
|---|---|
| Insieme di uscite | `outputDeviceId` diventa `outputDeviceIds` (insieme, almeno 1). Con una sola uscita il comportamento resta quello della Fase 9. |
| Chi sceglie | Qualunque partecipante attiva/disattiva un'uscita (come oggi `setOutput`); la sincronia è un'opzione per dispositivo. |
| Riferimento temporale | Orologio dell'host («tempo Jam»). Gli altri stimano l'offset con scambi di timestamp stile NTP. |
| Sorgente | Ogni uscita sincronizzata **scarica prima il file intero** nella cache e suona da locale: niente jitter di rete durante l'ascolto. |
| Avvio | L'host fissa `positionAt = adesso + 1,5 s`; le uscite caricano, si mettono in pausa alla posizione e partono a quell'istante. |
| Correzione | Scarto < 25 ms ignorato; 25–120 ms correzione **proporzionale** (velocità = 1 − errore/4 s, max ±2,5 %); > 120 ms seek (tarato sulla misura acustica del 2026-10-15). |
| Bluetooth | Compensazione manuale per dispositivo (ms, anche negativa) nelle impostazioni Jam. Nessuna misura automatica. |

## Architettura
```
host (orologio di riferimento)
  GET /jam/<sid>/time  → { t: epochMs host }       ← ogni partecipante, 8 campioni, tiene il RTT minimo
  stato: outputDeviceIds, positionMs + positionAt (tempo Jam), playing
partecipante-uscita
  JamClock      offset = t_host - (t0 + t1)/2 ; rinnovo ogni 30 s ; mediana mobile
  JamSyncPlayer posizione_attesa(adesso) = positionMs + (jamNow - positionAt) ; confronta con backend.positionPrecise
```
- **`JamClock`** (puro, testabile con orologi finti): stima offset e deriva, espone `jamNowMs()`.
- **`JamSyncController`** (puro): dato stato, `jamNow`, posizione misurata e latenza personale decide
  `play | pause | seek(x) | speed(s)`; nessun I/O. Tutta la logica si prova con scenari a tabella.
- **`AudioBackend`**: nuovi `setSpeed(double)` e `Duration positionPrecise` (mpv `time-pos`, ExoPlayer `currentPosition`).
- **Handshake di pronto**: comando `ready(itemId)` inviato da ogni uscita a file in cache; l'host avvia quando
  tutte le uscite hanno risposto o dopo 8 s (le ritardatarie entrano appena pronte, con seek alla posizione attesa).

## Protocollo (differenze)
| Cosa | Fase 9 | Fase 10 |
|---|---|---|
| Stato | `outputDeviceId` | `outputDeviceIds` (+ `outputDeviceId` ignorato dai vecchi client: primo dell'insieme) |
| Comando | `setOutput(id)` | `setOutputs([ids])`, `ready(itemId)` |
| Rotte | — | `GET /<sid>/time` |
| Versione | 1 | 2 (campo `proto` in `/request`; host rifiuta ospiti vecchi con messaggio chiaro) |

## Task
- **10.1** `JamClock` + rotta `/time` + test (offset noto, RTT asimmetrico, deriva, campioni scartati).
- **10.2** Modello: `outputDeviceIds`, `ready`, compatibilità con la Fase 9; `applyCommand` (permessi, uscita che lascia).
- **10.3** `JamSyncController` puro + test a tabella (avvio programmato, deriva piccola/media/grande, pausa, seek, cambio brano).
- **10.4** `AudioBackend.setSpeed/positionPrecise` per just_audio e media_kit + backend finto con orologio.
- **10.5** Precarico obbligatorio e handshake `ready` (riuso di `JamCache`; limite di spazio, errori).
- **10.6** `JamOutput` multi-uscita: cablaggio di clock, controller, cache; mantenere il percorso a uscita singola.
- **10.7** Interfaccia: selezione multipla delle uscite, indicatore «sincronizzato ±N ms», impostazione latenza (ms).
- **10.8** Simulazione: N dispositivi finti con orologi sfalsati e latenza di rete variabile; verifica dello scarto residuo.
- **10.9** Prova reale: 2 telefoni + PC; misura con file «click» registrato da un terzo dispositivo (correlazione),
  5 minuti di ascolto, cambio brano, seek, uscita che entra a metà brano.
- **10.10** Documentazione (README limiti, architettura, rischi).

## Rischi
| Rischio | Mitigazione |
|---|---|
| Seek/avvio non preciso al campione (ExoPlayer, mpv) | Avvio programmato + correzione continua; target 80 ms, non 1 ms |
| Latenza Bluetooth 100–300 ms e variabile | Compensazione manuale; messaggio che il Bluetooth non è garantito |
| Wi‑Fi con picchi di latenza | Cache prima dell'avvio; campioni di clock con RTT minimo; soglie con isteresi |
| Cambio velocità udibile | ±2 % massimo, rampa; altrimenti seek in un punto silenzioso (non garantito) |
| Android in Doze con schermo spento | Servizio in primo piano già presente (Fase 8); verificare la deriva a schermo spento |
| Orologi che saltano (NTP del sistema) | Usare orologio monotono per le differenze; rinnovo periodico dell'offset |

## Definition of Done
- [x] Test: clock, controller (tabella), modello/permessi, simulazione con orologi sfalsati
- [x] Scarto ≤ 80 ms tra 2 uscite su Wi‑Fi: misura acustica con microfono, regime −9 ms (17 click di fila), transitorio iniziale ≤ 50 ms dopo ~14 s; 5 minuti continui non misurati acusticamente
- [x] Uscita singola identica alla Fase 9 (test invariati); nessun controllo di versione tra ospiti (dispositivi della stessa build)
- [x] `docs/PROGRESS.md`, README e architettura aggiornati
