# Fase 9 — Jam con più di 2 dispositivi

**Obiettivo:** una Jam con host + fino a 4 ospiti (tetto 5 partecipanti). Parte dalla Fase 8; stessa
topologia a stella (l'host tiene lo stato), nessun server esterno.

## Decisioni (con l'utente)
| Tema | Decisione |
|---|---|
| Inviti | Può accettare **anche un ospite**: il nuovo arrivato chiede a un ospite, che inoltra l'invito all'host; da lì il nuovo parla direttamente con l'host. |
| Permessi | Invariati: tutti aggiungono e riordinano; ciascuno rimuove i propri brani (non quello in riproduzione); solo l'host salta, termina e rimuove i brani altrui. |
| Uscita | Un solo dispositivo suona, scelto tra tutti i partecipanti. |
| Ospite che esce | I suoi brani **spariscono subito** dalla coda. Se non restano ospiti, la Jam finisce. Se esce l'host, finisce per tutti (niente migrazione). |
| Sincronia | **Prevista, non implementata** (vedi Fase 10): lo stato porta già `positionMs`+`positionAt` e la lista partecipanti; l'uscita singola `outputDeviceId` diventerà un insieme. |

## Protocollo (differenze dalla Fase 8)
- `JamState.participants`: elenco `{id, name, host, port}`; per l'host `host` è vuoto («l'indirizzo con cui mi hai raggiunto»).
  Serve a chi riproduce per trovare il proprietario di ogni brano (anche un altro ospite).
- Credenziali per partecipante: `token` (identità: stato, comandi, invito) e `fileToken` condiviso da tutta la sessione
  (intestazione `x-jam-file`, serve solo per scaricare i file in coda).
- `POST /jam/<sid>/invite` (host): un ospite autenticato inoltra una richiesta accettata → l'host crea il partecipante
  e restituisce `token`+`fileToken`. `GET /jam/request/<id>` restituisce anche `base` (indirizzo dell'host) quando
  l'accettazione è avvenuta tramite un ospite.
- `POST /jam/<sid>/leave`: toglie solo chi esce (e i suoi brani).
- Vitalità: l'host scarta il partecipante che non si fa vivo per 75 s.

## Task
- **9.1** Modello: `JamParticipant`, `participants` in `JamState` (+ test JSON, `setOutput` verso qualunque partecipante).
- **9.2** Host a N: membri con token propri, `fileToken`, invito, `leave`/scarto per membro, tetto, rimozione brani di chi esce.
- **9.3** Client: credenziali separate, `invite()` per l'ospite che accetta, `join` verso `base`.
- **9.4** Controller: URL del proprietario dall'elenco partecipanti, accettazione da ospite, timer di scarto.
- **9.5** UI: titolo con i partecipanti, selettore di uscita a più voci, nomi in coda dall'elenco.
- **9.6** Prova su dispositivi reali (PC + 2 telefoni): 3 partecipanti, invito via ospite, uscita di un ospite.
- **9.7** Documentazione.

## Fase 10 (prevista) — riproduzione sincronizzata
Più uscite contemporanee: sincronizzazione degli orologi (scambio di timestamp stile NTP sull'endpoint dello stato),
`outputDeviceIds` come insieme, avvio programmato (`startAt` nel futuro) e correzione della deriva con soglia.
Vincoli noti: latenza diversa per dispositivo (Bluetooth), mpv/ExoPlayer senza seek sample-accurate. Da pianificare a parte.
