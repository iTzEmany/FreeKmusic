# Fase 172 — «Continua qui»: brani mancanti via LAN e suggerimento

## Obiettivo
I brani locali che l'arrivo non ha si suonano in streaming dalla partenza via LAN (HTTP con gettone, come la Jam); se la partenza sparisce,
quei brani si saltano. La partenza Android che serve brani tiene una notifica «Condivido brani con <nome>». Banner «Sul <nome> sta suonando
<brano> · Continua qui» quando un dispositivo mio suona. Chiude l'idea I-09.

## Riferimenti
Requisiti R-281, R-286 (flusso LAN), R-288, R-290 in `../feature/feature-continua-qui.md`. Decisioni D-774…D-779 in
`../decisioni.md`. Architettura: `../architettura/sync-backup-jam.md` § «Continua qui (I-09) — progetto». Rischi R96-R98. Specifica visiva:
`../mockups/continua-qui/a-sezione-continua/index.html` (pillola sopra il mini player e la barra del desktop, notifica). Prerequisito: fase 171.
Codice: `/jam/<sid>/file/<n>` e `_ownedItem` (`lib/services/jam/jam_host.dart:680-740`), `remoteUri`/`_headers` (`lib/providers/jam_media.dart:66-85`),
`AudioBackend.loadUri` (`lib/services/audio/audio_backend.dart:35`), `ReceiveService` e canale `codecore/share`
(`android/app/src/main/kotlin/com/codecore/player/ReceiveService.kt`, `MainActivity.kt:128-137`, `_startJamService` in `share_hub.dart:166`),
scoperta (`lib/services/share/discovery.dart`), impostazioni (`lib/data/settings/settings_store.dart`).

## Task
- [ ] 172.1 Flusso LAN dei brani mancanti
  - File: `continue_routes.dart` (rotta HTTP `GET /continue/<gettone>/file/<n>` sul nodo HTTP, gettone casuale per passaggio e arrivo
    nell'intestazione; vale solo per i brani dell'istantanea; scade quando la partenza riprende a suonare o dopo 12 h), istantanea con
    l'indirizzo e il gettone, `continue_providers.dart` (mancanti → `loadUri` con l'intestazione; errore di rete sul brano → saltato e contato),
    test in `continue_routes_test.dart` e `continue_controller_test.dart`.
  - Passi: 1) rotta e gettone; 2) brani mancanti o con durata diversa (R95) presi dalla partenza; 3) partenza tolta a metà → i successivi LAN saltati,
    locali e online suonano; 4) gettone sbagliato o scaduto → 403.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/services/share/continue_routes_test.dart test/providers/continue_controller_test.dart test/services/jam`
  - Fatto quando: test verdi; i test della Jam verdi senza modifiche.
- [ ] 172.2 Notifica Android della partenza
  - File: `continue_providers.dart` (avvio e arresto di `ReceiveService` con «Condivido brani con <nome>» finché il gettone vale e l'arrivo ha brani
    suoi), ARB, test del canale con un `MethodChannel` finto.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/continue_controller_test.dart`
  - Fatto quando: test verdi (avvio al primo brano servito, arresto alla scadenza o a coda finita); nessuna modifica a `ReceiveService.kt`.
- [ ] 172.3 Suggerimento
  - File: `continue_providers.dart` (con l'app in primo piano, ogni 10 s `GET /continue/state` ai dispositivi miei visti dalla scoperta; fermo in
    sottofondo), pillola sopra mini player e barra del desktop, chiave «Suggerisci di continuare qui» (accesa di base) in `settings_store.dart` e
    voce nelle impostazioni, ARB, test widget in `continue_ui_test.dart`.
  - Passi: 1) controllo periodico con orologio finto; 2) banner solo se suona ora; X → non torna per lo stesso brano, torna per il successivo;
    3) interruttore spento → nessun controllo né banner; 4) semantiche.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/ui/continue_ui_test.dart test/providers/continue_controller_test.dart test/ui/talkback_labels_test.dart`
  - Fatto quando: test verdi; nessun controllo con l'app in sottofondo.
- [ ] 172.4 Prova a due telefoni
  - Mi A3 e Redmi via `~/.claude/scripts/device.sh` (volume 0, solo l'app), più Linux: manda e prendi nei versi telefono↔PC e telefono↔telefono
    con brani mancanti sull'arrivo; partenza in pausa e schermo spento 10 min mentre l'arrivo suona i brani LAN (R98); ritardo misurato ≤ 1 s (R96);
    Jam e «Invia a un dispositivo» ancora funzionanti (R97). Pulizia alla fine.
  - Fatto quando: esiti scritti qui sotto con i numeri misurati; nessuna regressione.

## Criteri di fine fase
- Test mirati verdi e CI verde (suite completa).
- 172.4 fatta; I-09 segnata «fatta» in `../ideas.md`.

## Deviazioni
