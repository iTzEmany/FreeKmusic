# Fase 165 — «Invia a un dispositivo» con tutti i brani della playlist

## Obiettivo
Dalla playlist partono tutti i brani che possono viaggiare (file e streaming salvati YouTube, D-674), e dopo l'invio l'utente sa quanti sono
partiti e perché gli altri no. Nessun cambio di protocollo in questa fase. Prima si fissa con test il comportamento che non deve cambiare
(anche per la fase 166).
Fuori: la playlist creata sul ricevente, le righe ombra e le parti oltre 500 (fase 166).

## Riferimenti
Refactor `../refactor/invia-playlist-completa/analisi.md` (F-01, F-03, F-06, «Scelte», «Rete»). Decisioni D-759 e D-763 (invio di tutti i
brani, intoccabili). Architettura: `../architettura/sync-backup-jam.md`.
Codice: `playlist_detail_screen.dart:113-114` (filtro `kind != kStreamKind`); `DevicesSheet._send` (`lib/ui/screens/devices/devices_sheet.dart:85-100`);
`SendTab._sendTo` (`lib/ui/screens/share/send_tab.dart:65-81`); `ShareHubNotifier.sendOffer` (`lib/providers/share_hub.dart:472-502`) e
`_offerWanted` (:811-830); `buildShareEntries` (`lib/providers/share_providers.dart:76-112`).

## Task
- [ ] 165.1 Test di caratterizzazione (nessun codice di prodotto)
  - File: `test/services/share/offers_test.dart`, `test/data/stream_rows_hidden_test.dart` (o un nuovo `test/providers/share_entries_test.dart`),
    `test/services/share/received_meta_test.dart`.
  - Passi: 1) `buildShareEntries`: un file passa con `path`; uno streaming salvato YouTube passa con `streamKey` e `path` vuoto; uno salvato SoundCloud,
    una riga ombra e un file mancante non passano; 2) `offerPayload` senza streaming non ha la chiave `streams`; con streaming `items` e `streams` sono
    separati; 3) il `POST /` rifiuta più di 500 elementi fra `items` e `streams` (400); 4) `saveReceivedStreams` salta i brani con il file già presente.
    Solo ciò che non è già coperto. Tutti verdi sul codice di oggi.
  - Comando mirato: `flutter test test/services/share/offers_test.dart test/data/stream_rows_hidden_test.dart test/services/share/received_meta_test.dart`
    (più il file nuovo, se creato)
  - Fatto quando: i test nuovi passano senza toccare `lib/`.
- [ ] 165.2 La playlist passa tutti gli id
  - File: `playlist_detail_screen.dart` (togliere il filtro a :114 e l'import di `kStreamKind` se resta inutile), un test widget del menu
    (es. `test/ui/playlist_detail_send_test.dart` o un file di caratterizzazione esistente dei menu).
  - Passi: 1) `DevicesSheet.show(context, trackIds: [for (final t in tracks) t.id])`; 2) test: una playlist con un file, uno streaming salvato e una
    riga ombra apre il foglio con i tre id (la scelta di cosa viaggia resta a `buildShareEntries`).
  - Comando mirato: `flutter test <file del test>` (più `flutter analyze`)
  - Fatto quando: test verde; i test della 165.1 restano verdi senza modifiche.
- [ ] 165.3 Esito dell'invio e messaggi
  - File: `share_hub.dart` (`sendOffer` restituisce un esito, es. `({int sent, int missing, int unsupported})` o una classe piccola, con un caso
    «niente da inviare» distinto da «non raggiungibile»; `_offerWanted` adattato), `share_providers.dart` (`buildShareEntries` conta gli scartati per
    motivo: file mancante, streaming non YouTube, riga ombra), `devices_sheet.dart`, `send_tab.dart`, ARB delle 6 lingue con `scripts/arb_add.py`
    poi `flutter gen-l10n`, test in `offers_test.dart`/`share_entries_test.dart` e un test widget del foglio.
  - Passi: 1) esito al posto di `bool`; 2) messaggi: tutti partiti → «Inviato a X» come oggi; alcuni scartati → «Inviati N brani su M a X» più il motivo
    più frequente (es. «M−N non disponibili su questo dispositivo»); nessuno → «Nessuno di questi brani si può inviare»; errore di rete → come oggi;
    3) test dei quattro casi.
  - Comando mirato: `flutter test test/services/share/offers_test.dart <test del foglio> <test di buildShareEntries>` (più `flutter analyze`)
  - Fatto quando: i quattro casi coperti da test verdi; l'invio di album e brano singolo dice «Inviato a X» come oggi quando parte tutto.

## Tocca a te
Niente.

## Note di deviazione
