# Fase 68 — Scoperta e chiusura (feature «Jam: cassa e coda insieme»)

**Obiettivo:** la scoperta funziona anche su reti non /24, la fluidità non peggiora e la feature è provata a mano con due telefoni e la «cassa».

**Prerequisiti:** fasi 65, 66 e 67 chiuse. Requisiti R-117, R-118, RNF-13; decisioni D-206, D-215.

**Comando mirato:** `flutter test test/services/share test/jam`; misure con `python3 scripts/perf_device.py 0d7ae9df206e --label fase68 --only "<scenari>"`.

## Task

### 68.1 — Maschera di rete vera (R-117, D-206, K-JC-07)
`LanDiscovery._targets` calcola il broadcast diretto dalla lunghezza del prefisso: Android dal lato nativo (`LinkProperties`, metodo `netPrefix` su `codecore/audio`), Linux da `ip -o -4 addr show`, Windows senza prefisso → `a.b.c.255` e `a.b.255.255`. Lettura fallita → la /24 di oggi.

**Fatto quando:** test della funzione degli indirizzi (/24, /16, /22, /30) e del parser di `ip` su uscite reali; prova su una rete /16 (UniBA) in «Tocca a te».

### 68.2 — Misure di fluidità (RNF-13)
Sul Mi A3 gli scenari di `perf_device.py` che toccano coda e shell (Apertura player, Fogli, Pallino schede) contro «Dopo» di `docs/refactor/ui-jam-ricerca/misure.md`; uno scenario fuori soglia si conferma con la prova A/B (handoff, «Dispositivi») prima di cercarne la causa.

**Fatto quando:** tabella «Fase 68» in `misure.md` con data e dispositivo; nessuno scenario peggiorato oltre il rumore.

### 68.3 — Prova a mano con due telefoni (R-118) [utente]
Hotspot del Motorola; Motorola host con le cuffie JBL segnate come cassa, Mi A3 ospite. Da provare: rilievi R-88 … R-95 (aggiunte in fila, swipe online, uscita con coda ritrovata, copertine, «Scarica», precedente subito dopo successivo, scarto), «Coda insieme» (turni, aggiunta in testa, suggerito, ritorno a «Coda dell'host»), Jam della cassa (domanda, Jam aperta da sé, banner sul Mi A3, richiesta accettata, solo l'host suona, cuffie spente → «Collega una cassa», riaccese → sblocco; poi cuffie spente, ricollegate al Mi A3 → «Suonare la Jam sulla tua cassa?» → suona solo il Mi A3, R-119).

**Fatto quando:** esiti scritti qui sotto, uno per riga; i KO diventano passi nuovi o vanno in «Rinviato» con il motivo.

**Esiti (29/10, Motorola + Mi A3 sull'hotspot del Motorola, JBL Tune 720BT):**
- UniBA (/16): i telefoni non si vedono, la rete filtra il broadcast (D-206); R-117 non dimostrabile lì.
- Hotspot: scoperta, banner «Unisciti alla Jam di Ema», richiesta e «Accetta» OK (200 di 2302 brani in coda).
- Solo l'host suona, anche con un brano della libreria dell'ospite: OK. «Successivo» dall'ospite: OK.
- L'ospite non cambia la modalità della coda: OK. «Coda insieme»: maniglie sparite su entrambi, brano dell'ospite subito dopo il corrente; ritorno a «Coda dell'host» con le maniglie: OK.
- «Coda dell'host» a Jam piena: l'aggiunta dell'ospite entra dopo il corrente scartando un ereditato: OK.
- **KO 1** «Coda insieme» a Jam piena (200 brani dell'host): l'aggiunta a mano dell'ospite è rifiutata (`JamError.full` con `cur == 0`) senza messaggio, mentre la UI dice «Aggiunto in coda»; ogni posto liberato lo prende il feeder. → 69.3.
- **KO 2** R-114 sul Motorola (Android 15): JBL spente → la Jam continua dall'altoparlante, niente «Collega una cassa». Il ricevitore A2DP registrato `RECEIVER_NOT_EXPORTED` non riceve il broadcast del processo Bluetooth. Corretto in questa PR (`RECEIVER_EXPORTED`, broadcast protetto).
- Con la correzione: JBL spente → «Collega una cassa» su entrambi e play bloccato anche dall'ospite; riaccese → sblocco, la Jam resta in pausa e riparte col play, suona solo il Motorola: OK.
- **KO 3** cassa già collegata all'avvio dell'app → nessuna Jam della cassa: `openSpeakerJam` esce muto finché l'hub non c'è (`_host` null) e `SpeakerJam._opened` resta vero, quindi niente nuovo tentativo. Spegnere e riaccendere la cassa ad app avviata la apre. → 69.1.
- Bluetooth del Mi A3 (Android 11): «È una cassa?» → Sì, Jam della cassa aperta sul Mi A3, banner sul Motorola: OK.
- R-119 a ruoli scambiati (Mi A3 host con le JBL, Motorola ospite): JBL staccate dal Mi A3 → «Collega una cassa» su entrambi; collegate al Motorola → «Suonare la Jam sulla tua cassa?» → Sì → suona solo il Motorola sulle JBL, il Mi A3 tace: OK.
- **KO 4** l'offerta di R-119 si apre sotto la schermata Jam: con la Jam aperta non si vede, compare solo tornando alla Home. → 69.2.
- Richiesta nuova: con la cassa scollegata l'host può continuare sull'altoparlante del telefono (D-263). → 69.3.
- Non provati: R-88 … R-95 e il brano suggerito di «Coda insieme». → 69.4.
- Note: un calo del Wi-Fi del Mi A3 ha ritardato di ~20 s l'ingresso, poi è entrato da solo; avvisi «jam: no cover for …» (404) a ogni brano senza copertina, rumorosi nel log.

### 68.4 — Chiusura
`docs/handoff.md` aggiornato, `docs/prossimi-lavori.md` §2 segnato come fatto per «Cassa Bluetooth e modalità della coda», pulizia del disco (`pulizia.sh`).

**Fatto quando:** documenti aggiornati, nessun file temporaneo rimasto.
