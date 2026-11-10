# Fase 6 — Condivisione sulla rete locale (OPZIONALE)

**Obiettivo:** inviare brani/album da un dispositivo all'altro (telefono ↔ PC) sulla stessa rete Wi-Fi,
in modo semplice e **sicuro per default**. Nessun mDNS, nessun ZIP, nessun protocollo complicato.
**Prerequisiti:** Fase 3 (meglio dopo la 4). Salta questa fase se basta copiare i file con USB/Syncthing.

## Design (semplice)
- **Chi condivide** apre "Condividi": parte un server HTTP su una porta casuale, **solo finché la schermata è aperta**,
  e mostra `IP:porta` + **PIN a 6 cifre** + QR code con `http://IP:porta/?pin=...`.
- **Chi riceve** inserisce IP:porta e PIN (o scansiona il QR sul telefono), vede la lista, sceglie i brani, scarica.
- Trasporto: HTTP in chiaro su LAN domestica (accettato per uso personale; il PIN evita accessi casuali).

## Endpoint (server)
| Metodo | Percorso | Risposta |
|---|---|---|
| GET | `/hello` | `{app:"codecore", name:"<nome dispositivo>", v:1}` (senza PIN) |
| GET | `/manifest` | `[{id, title, artist, album, sizeBytes, durationMs, ext}]` — richiede header `X-Pin` |
| GET | `/file/{id}` | stream del file con `Content-Length` e supporto `Range` — richiede `X-Pin` |
| GET | `/cover/{id}` | immagine copertina (se presente) — richiede `X-Pin` |

Regole di sicurezza (obbligatorie):
1. Il client **non** passa mai percorsi: solo `id` → il server risolve il percorso dal DB.
2. Solo i brani esplicitamente **selezionati** per la condivisione (o tutta la libreria se l'utente sceglie "Tutta").
3. PIN errato → 401; dopo 5 errori dallo stesso IP → blocco 60 s.
4. Il server si ferma alla chiusura della schermata o dopo 10 minuti di inattività.
5. Bind su `0.0.0.0` solo mentre è attivo; log di ogni richiesta (IP, id, esito).
6. Nessun upload dal client al server (sola lettura).

## Task

### 6.1 — Server
**File:** `lib/services/share/lan_server.dart`
Pacchetti: `flutter pub add shelf shelf_router qr_flutter network_info_plus`.
Implementa gli endpoint sopra. `start(selection) → ({String host, int port, String pin})`, `stop()`.
`Range` con validazione completa (`start<=end<size`, 416 altrimenti).
**Test:** router con handler finti: PIN errato → 401; id inesistente → 404; range invalido → 416; nessun path traversal possibile (l'id è intero).

### 6.2 — Client
**File:** `lib/services/share/lan_client.dart`
`Future<RemoteInfo> hello(host, port)`, `Future<List<RemoteTrack>> manifest(...)`, `Stream<DownloadProgress> download(RemoteTrack, Directory out)`:
scrive su `.part`, verifica `Content-Length` finale, `rename`; nome con `sanitizeFileName`, mai sovrascrivere (suffisso ` (2)`).
Cartella destinazione: `<musica>/Ricevuti`. Dopo il download → scansione del file.
**Test:** download con server locale di test in-process.

### 6.3 — UI
**File:** `lib/ui/screens/share/*`
- Tab "Invia": selezione brani/album (riusa la modalità selezione multipla della lista), pulsante "Avvia condivisione" → schermata con IP, PIN, QR, pulsante "Ferma".
- Tab "Ricevi": campo IP:porta + PIN (o scanner QR su mobile con `mobile_scanner`, opzionale), lista remota con checkbox, "Scarica selezionati", progresso per file e totale, Annulla.
- Android: richiedi `Permission.nearbyWifiDevices` **non** necessario (niente mDNS). Manifest: `INTERNET`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`.
- Windows: avvisa che il firewall può chiedere il permesso alla prima condivisione.

### 6.4 — Integrazione
Menu brano/album: "Condividi…". Le impostazioni mostrano il nome dispositivo (modificabile; default = hostname).

## Verifica manuale (due dispositivi)
- [ ] PC → telefono: album da 10 brani, tutti riproducibili sul telefono
- [ ] PIN sbagliato rifiutato; dopo 5 errori blocco temporaneo
- [ ] Chiudendo la schermata il server non risponde più (`curl` dal PC fallisce)
- [ ] Annullamento a metà non lascia file `.part`

## Definition of Done
- [ ] Test server/client verdi
- [ ] Nessun endpoint accetta percorsi dal client
- [ ] `docs/PROGRESS.md` aggiornato
