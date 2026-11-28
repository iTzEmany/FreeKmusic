# Fase 171 — «Continua qui»: manda e prendi

## Obiettivo
Da un dispositivo mio all'altro, in LAN: «Continua su <nome>» dalla partenza o «Continua qui da <nome>» dall'arrivo, e l'arrivo riparte con
brano, posizione, coda, casuale, ripeti, contesto e volume; la partenza va in pausa solo quando l'arrivo suona e mostra «In ascolto su <nome> ·
Riprendi qui». Sull'arrivo «Annulla» per ~10 s. I brani locali che l'arrivo non ha e gli online senza rete si saltano con «N brani saltati»
(il flusso LAN dei mancanti arriva nella fase 172). Idea I-09.

## Riferimenti
Requisiti R-278…R-280, R-282…R-285, R-287, R-289, R-291…R-297 (R-286 solo la parte «brano trovato nella libreria») in
`../feature/feature-continua-qui.md`. Decisioni D-774…D-779 in `../decisioni.md` (come si avvia, cosa passa, brani, dispositivi,
aspetto, architettura). Architettura: `../architettura/sync-backup-jam.md` § «Continua qui (I-09) — progetto». Rischi R95-R97, R99 in
`../99-rischi-e-fallback.md`. Specifica visiva: `../mockups/continua-qui/a-sezione-continua/index.html` (mockup A; icone dal set dell'app).
Codice: `_secureRoutes` e `trustedCaller`/`isMine` (`lib/providers/share_hub.dart:736-766`, `lib/services/share/sync_routes.dart:57-71`),
`LanClient.secureGet/securePost` (`lib/services/share/lan_client.dart:121-129`), `/hello` (`lib/services/share/offer_node.dart:50`),
`TrackRef` (`lib/services/backup/user_data.dart:14`), `track_resolver.dart` (`lib/services/backup/`), handler (`codecore_audio_handler.dart`:
`queueIds` :427, `currentIndex` :429, `userAhead` :430, `restore` :550, `playContext` :1631, `volume` :384), `playback_persistence.dart:57-77`,
`jamProvider` (`jam_providers.dart:1069`), `showUndoSnack` (`lib/ui/widgets/confirm.dart:45`), `devices_sheet.dart`, `now_playing_controls.dart:295`,
`desktop_player_bar.dart:465`.
Vincoli: nessun pacchetto nuovo; nessuna migrazione del DB; nessun cambiamento a rotte esistenti, beacon UDP, Jam, Invia, `/sync` (D-07, D-191).

## Task
- [ ] 171.1 Istantanea e messaggio
  - File: nuovo `lib/services/share/continue_snapshot.dart` (`ContinueSnapshot`: lista di `TrackRef`, indice, posizione, ora di lettura, `userAhead`,
    casuale, ripeti, contesto, volume; `toJson`/`fromJson` con limiti validati: brani ≤ 5000, stringhe limitate, indice dentro la lista;
    `positionAt(now)` = posizione + tempo trascorso se in riproduzione), test nuovo `test/services/share/continue_snapshot_test.dart`.
  - Passi: 1) costruzione dall'handler (online → `streamKey`); 2) andata e ritorno; 3) rifiuto di JSON malformato o oltre i limiti senza eccezioni.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/services/share/continue_snapshot_test.dart`
  - Fatto quando: test verdi (coda di 30 con 3 «in coda», casuale, ripeti uno, volume 40% identici dopo l'andata e ritorno; 800 ms in riproduzione → +0,8 s; in pausa → identica).
- [ ] 171.2 Rotte `/continue` e client
  - File: nuovo `lib/services/share/continue_routes.dart` (`GET /continue/state`, `POST /continue/take`, `POST /continue/release`; chiamante fidato
    e `mine`, altrimenti 403; Jam attiva su questo dispositivo → 409 «jam»; un passaggio alla volta → 409 «occupato»), montaggio in `_secureRoutes`
    (`share_hub.dart`), chiave di capacità nel JSON di `/hello` (`offer_node.dart`), metodi in `lan_client.dart`, test nuovo
    `test/services/share/continue_routes_test.dart` con due nodi in memoria.
  - Passi: 1) rotte e controlli; 2) `take` risponde solo dopo che l'arrivo ha confermato di suonare (callback iniettata); 3) capacità in `/hello`;
    4) test: fidato non mio rifiutato, Jam → 409, due richieste insieme → una «occupato», nodo senza capacità riconosciuto.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/services/share/continue_routes_test.dart test/services/share test/providers/share_hub_test.dart`
  - Fatto quando: test verdi; i test esistenti di share, sync, offerte e Jam verdi senza modifiche (R97); `git diff` non tocca rotte esistenti né `discovery.dart`.
- [ ] 171.3 Applicazione sull'arrivo e pausa della partenza
  - File: nuovo `lib/providers/continue_providers.dart` (`ContinueController`: `sendTo(peer)`, `takeFrom(peer)`, applica l'istantanea, salva lo stato
    di prima per «Annulla», mette in pausa la partenza dopo la conferma, stato «In ascolto su <nome>»), test nuovo `test/providers/continue_controller_test.dart`.
  - Passi: 1) risoluzione con `track_resolver` (relPath → sha256 → titolo|artista) e controllo della durata ±3 s (R95): non trovato o durata diversa
    → saltato in questa fase; online → come i propri, senza rete o flavor senza yt-dlp → saltato; 2) `restore(ids, index, positionAt(now), userAhead:)`
    + casuale/ripeti + contesto + volume; 3) «Annulla» rimette coda, indice, posizione e stato; 4) errori (non raggiungibile, rifiutato, scaduto,
    jam, occupato, versione vecchia) → nessun cambiamento su nessuno dei due; 5) «Riprendi qui»: `takeFrom` se raggiungibile, altrimenti riprende dal proprio punto.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/continue_controller_test.dart test/services/share/continue_routes_test.dart`
  - Fatto quando: test verdi per R-278, R-279, R-283, R-284, R-285, R-287, R-292, R-293, R-294 (con trasporto e orologio finti); omonimi con durata diversa non scelti.
- [ ] 171.4 Interfaccia come il mockup A
  - File: `devices_sheet.dart` (sezione «Continua» in cima: «Continua su <nome>», «Continua qui da <nome>» con il brano in corso, «non raggiungibile»,
    «Aggiorna l'app per continuare qui», nota «Esci dalla Jam per continuare altrove»), `now_playing_controls.dart`, mini player e
    `desktop_player_bar.dart` («In ascolto su <nome> · Riprendi qui», su due righe nel mini player), avvisi «Continua da <nome> · Annulla» e
    «N brani saltati», ARB in `lib/l10n/` (it/en/de/es/fr/pt), semantiche e annuncio dell'esito, test widget nuovo
    `test/ui/continue_ui_test.dart` e `test/ui/talkback_labels_test.dart`.
  - Passi: 1) sezione e stati; 2) scritta sulla partenza; 3) avvisi; 4) testi in sei lingue, nessuno uguale a «Continua sul telefono» (D-263);
    5) etichette e annuncio («Continua su <nome>: fatto» o l'errore).
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/ui/continue_ui_test.dart test/ui/talkback_labels_test.dart test/ui/devices_sheet_test.dart`
  - Fatto quando: test verdi; `flutter analyze` pulito; confronto a occhio con il mockup A (screenshot a 360 e 1440) senza differenze di struttura.

## Criteri di fine fase
- Tutti i test mirati sopra verdi e CI verde (suite completa).
- Prova automatica a due dispositivi (Linux + un telefono di prova via adb, volume 0): manda e prendi nei due versi, «Annulla», Jam attiva → voce spenta.

## Deviazioni
