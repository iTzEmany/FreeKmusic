# Fase 166 — La playlist arriva come playlist

## Obiettivo
Chi riceve una playlist la trova creata, con lo stesso nome (o «Nome (2)»…) e lo stesso ordine, compresi i brani in streaming non salvati (righe
ombra, solo nella playlist) e anche quando i brani sono più di 500. Le versioni vecchie continuano a funzionare in entrambe le direzioni.
Fuori: sync delle playlist fra fidati, invio di album e singolo brano, schema del DB (intoccabili).

## Riferimenti
Refactor `../refactor/invia-playlist-completa/analisi.md` (F-02, F-04, F-05, «Direzione», «Rete»). Decisioni D-760..D-764 (playlist come playlist,
righe ombra, oltre 500, intoccabili, niente mockup). D-524 (righe ombra nelle playlist), D-674. Architettura: `../architettura/sync-backup-jam.md` (regola 6).
Codice: `OfferService.offerPayload` e `POST /` (`lib/services/share/offers.dart:281-316`, :350-400), `StreamOffer` (:116-148), `IncomingOffer` (:152);
`ShareHubNotifier.sendOffer` (:472) e `accept` (`lib/providers/share_hub.dart:542-650`); `buildShareEntries`; `PlaylistSyncRepository.resolver()`;
`TrackRepository.ensureStreamRow` (`track_repository.dart:384`); `PlaylistRepository.createWith`, `addStreamTracks`; dialogo e riga dell'offerta in arrivo
(`lib/ui/screens/share/incoming_offer_dialog.dart`, `incoming_offer_tile.dart`); `DevicesSheet` (passa nome e ordine della playlist).

## Task
- [x] 166.1 Campo `playlist` nell'offerta (mittente) e parse tollerante (ricevente)
  - File: `offers.dart` (classe `OfferPlaylist {key, name, part, parts, order}`; `order` = lista di `{item: id}` o `{stream: key}`; `StreamOffer` con
    `shadow` facoltativo; `IncomingOffer.playlist`), `share_providers.dart` (`buildShareEntries(…, withShadow: true)` fa passare le righe ombra YouTube
    marcate), `share_hub.dart` (`sendOffer(peer, tracks, {playlistName})`), `devices_sheet.dart` e `playlist_detail_screen.dart` (passano il nome), test in
    `offers_test.dart`, `meta_travel_test.dart`.
  - Passi: 1) andata e ritorno del campo; 2) parse: campo assente o rovinato (tipi sbagliati, nome oltre 200, `order` che cita id o chiavi che non sono
    nell'offerta, `part` fuori da 1..`parts`) → `playlist` null e offerta valida come oggi; 3) le righe ombra viaggiano solo con la playlist; 4) un'offerta
    senza playlist ha esattamente i campi di oggi.
  - Comando mirato: `flutter test test/services/share/offers_test.dart test/services/share/meta_travel_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; i test della 165.1 verdi senza modifiche.
- [x] 166.2 Il ricevente crea la playlist
  - File: `share_hub.dart` (`accept`: a fine ricezione, se `o.playlist` c'è, costruisce gli id nell'ordine: file ricevuti dal loro percorso → riga,
    streaming salvati dalla chiave → riga, righe ombra con `ensureStreamRow`, brani già presenti con `PlaylistSyncRepository.resolver()`; poi
    `createWith` con il nome libero e `addStreamTracks` per le righe ombra; elementi non arrivati saltati), eventuale helper puro del nome libero
    («Nome», «Nome (2)»… : riusare uno esistente se c'è), `incoming_offer_dialog.dart`/`incoming_offer_tile.dart` (riga «Playlist «Nome»» sopra il conteggio),
    ARB delle 6 lingue, `../architettura/sync-backup-jam.md` (regola 6 e stringhe di protocollo), test (nuovo `test/providers/share_hub_playlist_test.dart`
    o nel test dell'offerta in arrivo).
  - Passi: 1) playlist creata nell'ordine del mittente con file, salvati e righe ombra; 2) righe ombra non visibili in libreria (`saved = false`); 3) nome
    occupato → «Nome (2)», poi «Nome (3)»; 4) un file non arrivato non blocca la playlist; 5) offerta senza playlist: nessuna playlist creata (come oggi).
  - Comando mirato: `flutter test <test nuovo> test/ui/incoming_offer_test.dart test/services/share/received_meta_test.dart` (più `flutter analyze`)
  - Fatto quando: i cinque casi coperti da test verdi.
- [x] 166.3 Oltre 500 brani: parti raggruppate
  - File: `share_hub.dart` (mittente: parti da 500 con la stessa `key`, inviate in ordine; esito sommato; ricevente: chiede conferma solo per la parte 1;
    le parti successive dello stesso mittente — stesso `fromId`, stesso indirizzo e, se firmate, stessa impronta — entro `offerTtl` sono accettate da sole,
    ognuna dopo che la precedente ha scritto la sua parte; rifiutata o scaduta la prima, rifiutate le altre), `offers.dart` se serve un indice per `key`,
    test (nel test della 166.2 o in `offers_test.dart`).
  - Passi: 1) 1200 brani → 3 offerte da 500/500/200; 2) sul ricevente una sola playlist con i 1200 nell'ordine; 3) una parte da un altro mittente o da un altro
    indirizzo con la stessa `key` non viene accettata da sola; 4) prima parte rifiutata → nessuna playlist, altre parti rifiutate.
  - Comando mirato: `flutter test <test della 166.2> test/services/share/offers_test.dart` (più `flutter analyze`)
  - Fatto quando: i quattro casi coperti da test verdi.
- [ ] 166.4 Prova a due telefoni (Mi A3 e Redmi, volume 0, poi ripulire tutto)
  - Passi: 1) playlist mista (file, streaming salvati, righe ombra) inviata dal Mi A3 al Redmi: playlist creata, ordine giusto, righe ombra non in libreria,
    messaggio con il conteggio; 2) stesso nome già presente → «Nome (2)»; 3) una playlist da oltre 500 brani (anche solo streaming): una conferma sola,
    playlist completa; 4) album e brano singolo come prima.
  - Fatto quando: i quattro punti visti sui telefoni; nessun file musicale già presente toccato (D-502); app e dati di prova tolti a fine prova.

## Tocca a te
Niente (la prova a due telefoni la fa l'agente via adb).

## Note di deviazione

- **166.1** Campo `playlist` facoltativo nell'offerta: `{"key","name","part","parts","order":[{"item":id}|{"stream":key}]}`, `"shadow": true` dentro `streams[]` solo per le righe non salvate. Parse tollerante: campo rovinato (tipi, nome vuoto o oltre 200, key oltre 64, parte fuori da 1..parts, order oltre 500 o con riferimenti fuori dall'offerta) → playlist ignorata, offerta valida; senza playlist valida le righe ombra sono scartate (400 se restano solo quelle). Il mittente taglia il nome a 200; il ricevente toglie caratteri di controllo, invisibili e bidi.
- **166.2** `writeReceivedPlaylist`: per ogni elemento percorso del file, poi riga per chiave, poi `resolver.resolve(titolo, artista, durata)`; la riga ombra si crea solo se non c'è altro. Creazione e brani in una transazione (`createWithStreams`), nome libero «Nome (2)» (`PlaylistRepository.freeName`, riusato da `saveToLibrary`).
- **166.3** Gruppo delle parti per key + mittente (id, indirizzo, impronta). Si accetta da sola solo la parte successiva, entro `parts` e con lo stesso `parts` della prima; una parte 1 ripetuta chiede come offerta normale. Il timer limita solo l'attesa della risposta alla parte 1; poi il gruppo vive finché arrivano parti e scade `offerTtl` dopo l'ultima attività (anche la scadenza del mittente conta dall'ultima attività del gruppo, non dalla creazione). Le parti di un gruppo accettato sono esenti dai limiti 5 al minuto e 5 in attesa; un'eccezione in una parte è registrata e le successive proseguono; il mittente conta come inviati solo i brani delle parti consegnate. `/cancel` della parte 1 chiude il gruppo.
