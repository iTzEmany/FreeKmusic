# Fase 24 — Dispositivi fidati, cifratura e sincronizzazione delle playlist

**Obiettivo:** abbinare una volta sola i propri dispositivi (PC ↔ telefono) con un PIN, poi scambiarsi brani senza
PIN e su canale **cifrato** (TLS con certificato autofirmato e impronta verificata), leggere il PIN/invito con la
fotocamera e **sincronizzare le playlist** tra i propri dispositivi sulla rete di casa.
**Prerequisiti:** Fase 6 v2 (scoperta + offerte, `OfferNode`, `share_hub.dart`), Fase 8–10 (Jam), Fase 13 (formato
portabile JSON dei dati utente e identità del brano per percorso relativo + titolo/artista/durata).
**Principio:** nessun server centrale, nessuna fiducia implicita. Un dispositivo diventa fidato solo dopo un PIN
confermato dall'utente su **entrambi** i lati. L'endpoint resta acceso solo quando oggi è acceso (schermata di
condivisione, «Ricevi dalla rete locale», Jam): la sincronizzazione non apre nuove finestre di ascolto.

## Decisioni
| Tema | Scelta |
|---|---|
| Identità | Ogni dispositivo genera al primo uso una coppia di chiavi + **certificato X.509 autofirmato** (validità 20 anni, CN = `deviceId` di `SettingsStore`). Chiave e certificato in `<appSupportDir>/identity/` (mai nel backup di fase 13) |
| Impronta | SHA-256 del certificato DER, mostrata come 4 gruppi di 4 caratteri (es. `A1F3-…`) |
| Abbinamento | Sul canale attuale (HTTP + PIN a 6 cifre): A chiede, B mostra PIN e impronta di A, l'utente digita il PIN su A; si scambiano le impronte. Entrambi salvano l'altro come fidato. Errori: stesso blocco di `LanGuard` (5 tentativi → 60 s) |
| Fidati | Elenco in `shared_preferences` (`trustedDevices`: id, nome, impronta, data). Revoca dalle Impostazioni → l'altro torna «sconosciuto» |
| Offerte dai fidati | Nessun PIN; dialogo di accettazione ancora mostrato. Opzione per dispositivo «Accetta automaticamente» (spenta di default) |
| TLS | `OfferNode` serve **HTTPS** (`HttpServer.bindSecure` + `shelf_io.serveRequests`) per `/hello`, `/offer`, `/pair`, `/sync`. Client `dio` con `badCertificateCallback` che accetta **solo** l'impronta salvata per quel `deviceId`; dispositivi non fidati: canale cifrato ma non autenticato (si mostra «non verificato») |
| Jam | **Resta HTTP con token**: lo streaming passa da ExoPlayer (Android) e mpv (desktop), che non accettano certificati autofirmati con pinning. Le rotte `/jam` restano su un secondo socket HTTP; il beacon annuncia entrambe le porte. Dichiararlo nell'interfaccia della Jam |
| Compatibilità | `/hello` v3 con `tls: true`, `httpPort`, `fingerprint`. Un dispositivo v2 (senza TLS) continua a funzionare in HTTP con PIN come oggi |
| QR | Scanner solo **Android** (`mobile_scanner`, permesso fotocamera chiesto al tocco); il QR contiene `codecore://pair?h=<ip>&p=<porta>&pin=<pin>&fp=<impronta>`. Desktop: si digita come oggi |
| Sync playlist | Solo tra fidati. «Ultima modifica vince» **per playlist** (non per brano), con anteprima e conferma. Cancellazioni **non** propagate in questa fase (una playlist cancellata su A riappare se B ce l'ha: si avvisa) |
| Schema | **v10**: `playlists.uuid` (unico, generato per le esistenti in migrazione) e `playlists.updated_at`. Se una fase precedente con schema non è stata fatta, usa la prossima versione libera e adatta il test di migrazione |
| Pacchetti nuovi | Generazione del certificato: `basic_utils` (o `pointycastle` diretto) **(da approvare con l'utente prima del task 24.2)**; `mobile_scanner` **(da approvare con l'utente prima del task 24.7)** |

## Task

### 24.1 — Verifiche preliminari
1. In un programma di prova fuori da `lib/` (cartella `scratch/`, non committata): genera chiave RSA 2048 o EC P-256 e
   certificato autofirmato con il pacchetto candidato, caricalo in `SecurityContext.useCertificateChainBytes` /
   `usePrivateKeyBytes`, apri `HttpServer.bindSecure` e collegati con `dio` + `badCertificateCallback` confrontando
   l'impronta. Misura il tempo di generazione **su Android** (Mi A3): se > 3 s va in isolate e si mostra un'attesa.
2. Controlla nel sorgente di `shelf` (`shelf_io.serveRequests`) come servire un `HttpServer` già aperto.
3. Conferma che ExoPlayer/mpv **non** accettano il certificato autofirmato (prova `loadUri` su HTTPS): annota l'esito.
4. `mobile_scanner`: verifica minSdk/compileSdk compatibili con `android/app/build.gradle.kts` e che il pacchetto
   non rompa la build Linux/Windows (plugin solo Android).
**Fermati** se un pacchetto non è approvato o se la generazione dei certificati non funziona su una piattaforma.
**Verifica:** note in PROGRESS (pacchetto scelto, tempi, esito ExoPlayer/mpv).

### 24.2 — Identità del dispositivo
**File:** `lib/services/share/device_identity.dart`, `test/services/share/device_identity_test.dart`
1. `DeviceIdentity.loadOrCreate(Directory dir)`: crea una volta (in `Isolate.run`) e rilegge chiave + certificato PEM.
2. `fingerprint` (SHA-256 del DER, pacchetto `crypto`), `formatFingerprint` per la UI.
3. `SecurityContext context()` per il server.
4. File corrotti → si rigenera **e** si avvisa che i dispositivi fidati vanno riabbinati (log + flag in stato).
**Test:** creazione e rilettura stabile, impronta costante, file corrotto → nuova identità.

### 24.3 — Elenco dei dispositivi fidati
**File:** `lib/services/share/trusted_devices.dart`, `settings_store.dart`, `lib/providers/share_providers.dart` (+ test)
1. `TrustedDevice {id, name, fingerprint, pairedAt, autoAccept}`; `TrustedDevices` con `add`, `revoke`, `byId`,
   `matches(id, fingerprint)`; persistenza JSON in `shared_preferences` (`trustedDevices`).
2. `trustedDevicesProvider` (Notifier).
**Test:** aggiunta, revoca, impronta diversa per lo stesso id → non fidato.

### 24.4 — HTTPS su `OfferNode` (Jam esclusa)
**File:** `offers.dart` (`OfferNode`), `share_hub.dart`, `discovery.dart`, `lan_client.dart` (+ test)
1. `OfferNode.start()` apre due socket: HTTPS (`/hello`, `/offer`, nuovi `/pair`, `/sync`) e HTTP solo per `/jam`
   (le `extraRoutes` di oggi). Stesso middleware `_localOnly` su entrambi.
2. `/hello` v3: `tls`, `httpPort` (Jam), `fingerprint`. Beacon di `LanDiscovery`: aggiunge `tls` e `jamPort`
   (nessun segreto: l'impronta non è un segreto ma si conferma solo con il PIN).
3. Client (`lan_client.dart`, invii di `share_hub.dart`): `https://` se il peer annuncia `tls`; `dio` con
   `badCertificateCallback` che accetta l'impronta salvata per quel `deviceId`, oppure qualunque per un peer non
   fidato (stato «non verificato»). Impronta diversa da quella salvata → **rifiuto** e avviso «L'identità di <nome> è
   cambiata: riabbinalo».
4. Jam: `jam_providers.dart` usa `jamPort` (HTTP) come oggi.
**Test:** con server su loopback: fidato con impronta giusta OK, impronta sbagliata rifiutata, peer v2 in HTTP OK.

### 24.5 — Abbinamento con PIN
**File:** `lib/services/share/pairing.dart`, rotte `/pair` in `offers.dart` (o file nuovo montato da `OfferNode`),
`share_hub.dart` (+ test)
1. `POST /pair/request` (da A, con id/nome/impronta) → su B dialogo «<A> vuole abbinarsi» con PIN a 6 cifre e
   impronta di A; scadenza 2 minuti.
2. `POST /pair/confirm` con il PIN digitato su A (confronto a tempo costante, blocco di `LanGuard`) → B restituisce
   la propria impronta; entrambi salvano il fidato **solo** dopo che anche B ha toccato «Conferma» (impronta di A
   mostrata sullo schermo di B).
3. Rate limit come le offerte; solo indirizzi locali.
**Test:** PIN giusto → fidati da entrambe le parti; PIN sbagliato 5 volte → blocco; scadenza; B rifiuta.

### 24.6 — Offerte dai fidati
**File:** `offers.dart`, `share_hub.dart`, `incoming_offer_dialog.dart` (+ test)
1. Offerta da un fidato verificato (impronta TLS del chiamante o firma del corpo con la chiave del dispositivo):
   etichetta «Fidato» nel dialogo e nella notifica Android; con `autoAccept` parte subito (notifica «Ricevo da <nome>»).
2. Le regole di validazione di oggi (estensioni, ≤ 500 brani, nomi sanificati) restano identiche anche per i fidati.
**Test:** offerta da fidato con `autoAccept` accettata senza dialogo; da non fidato invariata.

### 24.7 — Scanner QR (Android)
**File:** `lib/ui/screens/share/qr_scan_screen.dart`, `send_tab.dart`, `receive_tab.dart`, `devices_sheet.dart`, ARB
1. Il QR mostrato oggi (`qr_flutter`) contiene il link `codecore://pair?...` (o quello di oggi con `?pin=` per il
   collegamento manuale).
2. Pulsante «Scansiona codice» solo su Android; permesso fotocamera chiesto al tocco, rifiuto → messaggio con
   «Apri impostazioni» (`permission_handler`).
3. Lettura → abbinamento (24.5) o collegamento manuale precompilato.
**Verifica:** widget test con scanner finto (parsing del link, link non Codecore ignorato).

### 24.8 — Schema v10: playlist con `uuid` e `updated_at`
**File:** `tables.dart`, `app_database.dart` (+ `build_runner`), `playlist_repository.dart`, test di migrazione,
`docs/03-modello-dati.md`
1. Migrazione: aggiunge le colonne, genera un `uuid` casuale (v4, `Random.secure`) e `updated_at = created_at` per
   ogni playlist esistente.
2. Ogni scrittura in `PlaylistRepository` (`create`, `rename`, `setCover`, `addTracks`, `placeImported`,
   `removeTrack`, `reorder`) aggiorna `updated_at` nella stessa transazione.
**Test:** migrazione v9 → v10 con uuid unici; ogni metodo aggiorna `updated_at`.

### 24.9 — Sincronizzazione delle playlist
**File:** `lib/services/share/playlist_sync.dart` (logica pura), rotte `/sync`, `share_hub.dart`,
`lib/ui/screens/share/sync_preview_dialog.dart`, ARB (+ test)
1. `GET /sync/playlists` (solo fidati): elenco playlist nel **formato portabile di fase 13** (uuid, nome,
   `updated_at`, brani con identità portabile).
2. `SyncPlan plan(local, remote)`: per `uuid` → nuova da remoto / remoto più recente (sostituisce) / locale più
   recente (invariata, sarà l'altro a prenderla) / uguale. Brani risolti con lo stesso abbinamento del ripristino di
   fase 13; brani assenti in locale elencati come «mancanti».
3. Anteprima: «3 nuove · 2 aggiornate · 14 brani mancanti» con elenco; «Applica» scrive in una transazione;
   «Chiedi i brani mancanti» crea un'offerta inversa (B invia ad A) con il meccanismo di 24.6.
4. Avvio solo da azione dell'utente («Sincronizza playlist» nella scheda del dispositivo fidato).
**Test:** `plan` con 8 casi (nuova, più recente da entrambi i lati, uguale, brani mancanti, rinomina, riordino).

### 24.10 — Rifinitura, documentazione e prova a mano
1. Impostazioni → «Dispositivi fidati»: elenco, impronta, «Accetta automaticamente», «Revoca»; impronta propria.
2. ARB it/en/de/es; `docs/02-architettura.md` (identità, TLS, Jam in HTTP), `docs/03-modello-dati.md` (v10,
   chiave `trustedDevices`), `docs/99-rischi-e-fallback.md` (R59–R62), README.
**Tocca a te (PC + telefono, stessa Wi‑Fi):** abbinamento con PIN e con QR, invio senza PIN, revoca e nuovo PIN
richiesto, «Accetta automaticamente», sync di una playlist modificata su entrambi i lati (vince la più recente),
brani mancanti richiesti e ricevuti, Jam ancora funzionante, telefono con versione vecchia (v2) che invia al PC.

## Fuori da questa fase
Propagazione delle cancellazioni (servono «lapidi»), sincronia di preferiti/testi/modifiche (solo playlist qui),
sincronizzazione automatica in background, TLS per lo streaming della Jam (servirebbe un proxy locale), relay fuori
dalla LAN (escluso: «nessun server»).

## Rischi
| # | Rischio | Mitigazione |
|---|---|---|
| R59 | Generazione dei certificati lenta o non disponibile su una piattaforma | Verifica in 24.1, generazione una volta in isolate; ripiego: HTTP + PIN come oggi |
| R60 | Identità persa (reinstallazione, file corrotto) → fidati rotti | Messaggio «identità cambiata: riabbina», revoca semplice, mai accettare un'impronta diversa in silenzio |
| R61 | ExoPlayer/mpv non leggono HTTPS autofirmato | La Jam resta su HTTP con token (dichiarato), su un socket separato |
| R62 | Sync che sovrascrive una playlist curata | «Ultima modifica vince» solo con anteprima e conferma; nessuna cancellazione propagata |

## Definition of Done
- [ ] Abbinamento con PIN (e QR su Android) confermato su entrambi i dispositivi; revoca funzionante
- [ ] Offerte, abbinamento e sync su HTTPS con impronta verificata; dispositivi v2 ancora compatibili
- [ ] Jam invariata (HTTP con token), dichiarato nei documenti
- [ ] Sync playlist con anteprima, «ultima modifica vince», brani mancanti richiedibili
- [ ] Test: identità, fidati, TLS con impronta giusta/sbagliata, abbinamento, migrazione v10, `plan`
- [ ] `flutter analyze` pulito, `flutter test` verde, `docs/PROGRESS.md` aggiornato
