# Fase 8 — Jam sulla rete locale

**Obiettivo:** due dispositivi sulla stessa rete ascoltano insieme da una **coda condivisa**. Ognuno aggiunge
brani dalla *propria* libreria; i file restano dove sono e vengono letti in streaming da chi deve riprodurli.
**Prerequisiti:** Fase 6 (scoperta, offerta/accettazione, server HTTP con `Range`, servizio Android).
Solo rete locale, nessun server esterno, nessuna sincronia tra due uscite audio.

## Decisioni prese (con l'utente)
| Tema | Decisione |
|---|---|
| Modalità | Ascolto remoto + coda condivisa (A+B). **Niente riproduzione sincronizzata su due dispositivi (C scartata).** |
| Ruoli | **Host** = chi accetta la Jam: tiene lo stato autoritativo. **Ospite** = chi la richiede. |
| Uscita audio | **Un solo dispositivo suona** alla volta. Di default l'**host**. Si può cambiare il dispositivo di uscita (host ↔ ospite) in qualsiasi momento: nessuna sincronia, l'altro diventa telecomando. |
| Coda | Accesso completo a entrambi: **aggiungere e riordinare** anche i brani aggiunti dall'altro, vedere chi li ha aggiunti. **L'ospite non può rimuovere** i brani dell'host (può togliere solo i propri, mai quello in riproduzione); l'host rimuove tutto. |
| Controlli | L'ospite può play/pausa, seek e volume; **non può cambiare brano direttamente** (niente salto a un brano, né «avanti/indietro»). Solo l'host salta. |
| Privacy | Nessuno vede o sfoglia la libreria dell'altro: nella Jam esistono solo i brani messi in coda. |
| Precarico | Il brano successivo viene scaricato in cache temporanea (cancellata a fine Jam) per non dipendere dalla presenza del proprietario. |
| Limiti | 1 sessione per host, 2 dispositivi (host + 1 ospite) nella prima versione. |

## Architettura
```
Dispositivo A (host)                          Dispositivo B (ospite)
┌───────────────────────┐   richiesta Jam    ┌────────────────────────┐
│ JamHost               │◄───────────────────│ JamGuest               │
│  - JamState (verità)  │   accetta/rifiuta  │  - copia dello stato   │
│  - endpoint /jam/*    │───────────────────►│  - comandi → host      │
│  - serve file propri  │◄──── stato (poll) ─│  - serve file propri   │
└─────────┬─────────────┘                    └──────────┬─────────────┘
          │ output audio: JamOutput (host o ospite)     │
          └──── riproduce locale o stream dal proprietario ┘
```
- **Proprietà dei brani:** ogni `JamItem` ha `ownerDeviceId`. Chi suona il brano lo legge dal file locale se è il
  proprietario, altrimenti scarica in streaming dall'URL del proprietario.
- **Stato condiviso (`JamState`)**: `version`, `items[]`, `currentIndex`, `playing`, `positionMs` + `positionAt`
  (istante di riferimento), `outputDeviceId`, `ended`. L'host è l'unica fonte; ogni modifica incrementa `version`.
- **Trasporto:** HTTP sullo stesso `OfferNode` (porta già annunciata). Aggiornamenti con *long polling*
  (`GET /jam/state?since=<version>`, risponde appena cambia o dopo 25 s): nessuna nuova dipendenza.
- **Sicurezza:** token di sessione generato dall'host, scambiato solo dopo l'accettazione; ogni richiesta lo porta in
  `X-Jam-Token`. Solo indirizzi locali. Streaming di un file solo se l'elemento è **in coda** e il richiedente è
  il partecipante accettato. Rate limit e validazione come per le offerte (estensioni audio, lunghezze, id interi).

## Protocollo (endpoint)
| Metodo | Percorso | Chi lo serve | Scopo |
|---|---|---|---|
| POST | `/jam/request` | host | richiesta di Jam (pending fino alla risposta dell'utente) |
| POST | `/jam/<sid>/respond` | ospite | l'host comunica accetta/rifiuta (con token) |
| GET | `/jam/<sid>/state?since=N` | host | stato corrente (long polling) |
| POST | `/jam/<sid>/cmd` | host | comando: `add`, `remove`, `move`, `play`, `pause`, `seek`, `volume`, `setOutput`, `next`/`jump` (solo host), `end` |
| GET | `/jam/<sid>/file/<itemId>` | proprietario | stream del brano (con `Range`, token, solo se in coda) |
| GET | `/jam/<sid>/cover/<itemId>` | proprietario | copertina (facoltativa) |

Il proprietario di un brano può essere l'host **o** l'ospite: per questo `/file` e `/cover` esistono su entrambi.
L'ospite aggiunge un brano con `cmd add {item metadata, ownerHost, ownerPort}`: l'host non copia il file.

## Task

### 8.1 — Modello e logica pura
**File:** `lib/services/jam/jam_models.dart`, `lib/services/jam/jam_state.dart`, test.
`JamItem`, `JamState`, `JamCommand`, `JamPermissions` (chi può cosa). `applyCommand(state, cmd, from)`
funzione pura: valida permessi (l'ospite non può `next`/`jump`), incrementa `version`, mantiene `currentIndex`
coerente su `remove`/`move`.
I brani aggiunti vanno subito dopo quello in riproduzione, prima della coda ereditata dall'host; a coda piena l'ultimo brano ereditato fa posto.
**Verifica (test):** aggiungi/rimuovi/sposta con indice corrente invariato; ospite rifiutato su `jump`;
`version` monotona; limite elementi (200) e lunghezze.

### 8.2 — Sessione lato host (richiesta, accettazione, stato)
**File:** `lib/services/jam/jam_host.dart`, estensione di `OfferService/OfferNode` per montare `/jam`.
Richiesta in pending (scadenza 5 min), token di sessione, long polling, comandi, un solo ospite.
**Verifica:** test su loopback: richiesta → accetta → stato iniziale; comando non autorizzato → 403; token errato → 401;
ospite secondo → 409; fine sessione chiude tutto.

### 8.3 — Client ospite
**File:** `lib/services/jam/jam_guest.dart`, `lib/services/share/lan_client.dart`.
Invio richiesta, attesa della risposta, loop di long polling con backoff, invio comandi, gestione `ended`.
**Verifica:** test di integrazione host↔ospite su loopback (aggiungi dall'ospite, vedi sull'host e viceversa).

### 8.4 — Riproduzione di elementi remoti
**File:** `lib/services/audio/audio_backend.dart`, `just_audio_backend.dart`, `codecore_audio_handler.dart`.
`AudioBackend.loadUri(Uri, headers)`; il handler accetta elementi con sorgente `local(path)` o `remote(url, token)`;
la coda Jam è separata da `PlayQueue` (non la sporca) e mappa `JamState` → backend. Errore su un elemento
→ messaggio e salto (max 3, come oggi).
**Verifica:** test con backend finto (elemento remoto caricato con gli header giusti); manuale: stream FLAC da PC a telefono.

### 8.5 — Uscita audio e controllo remoto
**File:** `lib/providers/jam_providers.dart`, `lib/services/jam/jam_output.dart`.
`JamOutput` decide chi suona (`outputDeviceId` nello stato). Il dispositivo di uscita applica `playing/position`
(deriva tollerata ≤ 1,5 s, seek solo oltre soglia); l'altro mostra lo stato e invia comandi. Cambio uscita:
`setOutput` → il vecchio si ferma, il nuovo carica l'elemento corrente alla posizione dichiarata.
**Verifica:** test sul solo `JamOutput` (applicazione stato, soglia di deriva, cambio uscita); manuale a due dispositivi.

### 8.6 — Precarico e resilienza
**File:** `lib/services/jam/jam_cache.dart`.
Precarico del brano successivo nella cache temporanea (`<support>/jam_cache`), limite di spazio, pulizia a fine Jam
e all'avvio. Se il proprietario sparisce: usa la cache; altrimenti segna l'elemento «non disponibile» e salta.
**Verifica:** test della cache (limite, pulizia); manuale: spegnere il Wi‑Fi del proprietario a metà brano precaricato.

### 8.7 — Interfaccia
**File:** `lib/ui/screens/jam/*`, voci in Now Playing / Condivisione / menu brano.
- Pulsante **Jam**: elenco «Dispositivi vicini» (riusa la scoperta) → «Avvia Jam con X».
- Dialogo/notifica di richiesta sull'altro dispositivo (Accetta/Rifiuta, anche da notifica Android).
- Schermata Jam: coda condivisa con «aggiunto da», riordino, rimozione, «Aggiungi alla Jam» dal menu del brano,
  selettore **Uscita audio**, pulsanti play/pausa/seek (l'ospite non vede «avanti»), «Termina Jam».
- Stringhe in ARB (it/en/de/es).
**Verifica:** widget test di fumo per schermata, dialogo e menu; nessun overflow a 150% di testo.

### 8.8 — Background Android e rifinitura
Servizio in primo piano già presente (`ReceiveService`): tenerlo attivo durante la Jam con notifica
«Jam con X» e azione «Termina». Gestire schermo spento e chiusura app (la sessione termina e l'altro lo vede).
**Verifica manuale:** Jam di 10 minuti con schermo spento sul telefono; cambio uscita; chiusura improvvisa.

### 8.9 — Documentazione
Aggiornare `README.md` (funzioni e limiti), `docs/PROGRESS.md`, `docs/02-architettura.md` (cartella `services/jam`),
`docs/99-rischi-e-fallback.md` (nuovi rischi).

## Rischi
| Rischio | Mitigazione |
|---|---|
| Proprietario fuori rete a metà brano | Precarico + salto con avviso |
| Doze/chiusura dell'app su Android | Servizio in primo piano; la Jam finisce in modo esplicito |
| Deriva di posizione tra stato e uscita | Soglia 1,5 s, seek solo oltre; nessuna promessa di sincronia |
| Abuso (brani enormi, richieste ripetute) | Limiti dimensione/numero, rate limit, token per sessione |
| Rete con isolamento dei client | Stessi limiti della Fase 6; messaggio chiaro |

## Definition of Done
- [x] Test: modello (8.1), host/ospite su loopback (8.2–8.3), output (8.5), cache (8.6)
- [ ] Jam a due dispositivi reali: aggiunta da entrambi, streaming incrociato, cambio uscita, termina
- [x] L'ospite non può saltare brano (UI e server)
- [x] Nessuna libreria esposta: solo elementi in coda
- [x] `docs/PROGRESS.md` aggiornato
