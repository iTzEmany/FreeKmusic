# Fase 47 — Jam online

**Obiettivo:** nella Jam host e ospiti mettono in coda anche brani trovati online. Chi trova il brano lo scarica nella
sua cache di streaming e lo serve agli altri come un file della libreria; se esce prima che il brano suoni, il
dispositivo che fa da uscita lo scarica da YouTube per conto suo. Via il pulsante «aggiungi brani»: in Jam lo swipe e
«In coda» vanno nella coda condivisa. Tap su una riga della Jam = schermata del brano per tutti, con copertina, testo e
curiosità chiesti al proprietario.

**Prerequisiti:** fasi 45 e 46 chiuse (`StreamCache`, `StreamPreparer`, `enqueueOnline`, righe online). Fasi 8/10
(Jam: `JamHost`, `JamGuest`, `JamCache`, `JamItem`), fase 37 (`TrackMeta`), 11.15 (`JamScreen`).

**Riferimenti:** `docs/feature-streaming.md` (R-20, R-21, R-22, R-23, R-24, R-30; «Flussi» (c); componente «Jam»;
K-07); decisioni D-71, D-76, D-80, D-81.

**Intoccabili (D-76):** libreria e playlist; i download di oggi; la fluidità. **Nessun pacchetto nuovo.** **Schema
del DB invariato (D-77).** Protocollo Jam: nessuno stato nuovo per gli item (D-80); campi nuovi solo facoltativi
(`videoId`), i client tollerano campi sconosciuti. La compatibilità con APK precedenti non è richiesta (D-71), ma
`ref` dei brani di libreria resta l'id numerico di oggi.

## Task

### 47.1 — `JamItem.videoId` e `ref` con prefisso
**File:** `lib/services/jam/jam_models.dart` (`videoId?` in costruttore, `copyWith`, `toJson`/`fromJson`),
`lib/providers/jam_providers.dart` (`_localFile`), `test/jam/jam_state_test.dart`, `test/jam/jam_host_test.dart`
1. Brani online: `ref = 'yt:<chiave>'` (chiave = `indexKey`), `videoId` visibile a tutti; brani di libreria: `ref`
   numerico come oggi.
2. `_localFile(item)`: `ref` analizzato con prefisso (K-07): `yt:` → `StreamCache.fileFor(chiave)`; numero →
   `TrackRepository.getById` come oggi; altro → null (404 sulla rotta dei file).
3. I file della cache che sono nella coda della Jam sono fissati (`pin`) finché ci restano (invariante 3, D-81);
   `unpin` quando l'item esce dalla coda o la Jam finisce.

R-20 (parte), K-07.
**Fatto quando:** `flutter test test/jam/jam_state_test.dart test/jam/jam_host_test.dart` verde: `JamItem` con
`videoId` va e torna da JSON; JSON senza `videoId` letto (null); `_localFile` con `yt:` dà il file della cache, con un
numero il brano di libreria, con un `ref` sconosciuto null senza eccezioni; un item `yt:` in coda non viene evictato.
`flutter analyze` pulito.

### 47.2 — Accodare brani online nella Jam (host e ospiti)
**File:** `lib/providers/jam_providers.dart` (`addOnline(YtResult)`), `lib/providers/player_providers.dart`
(`enqueueOnline`/`addToQueue` → Jam quando è attiva), `test/jam/jam_integration_test.dart`
1. `addOnline(r)`: `StreamPreparer` scarica nella cache di chi accoda; a file pronto `send(JamCommand.add(JamItem(ref
   'yt:…', videoId, ext, sizeBytes…)))`. Le aggiunte successive dello stesso dispositivo aspettano la precedente, così
   la coda condivisa segue l'ordine delle aggiunte (D-80). Download fallito → messaggio, nessun item.
2. L'host/uscita legge il file con `GET /<sid>/file/<itemId>` dal proprietario e lo mette in `JamCache` come oggi.

R-20.
**Fatto quando:** `flutter test test/jam/jam_integration_test.dart` verde con un caso nuovo (host+ospite in memoria,
downloader finto): l'ospite accoda un brano online, l'item compare quando il file è pronto e l'host lo riproduce
leggendo il file dalla cache dell'ospite; due brani accodati di fila compaiono nell'ordine delle aggiunte anche se il
secondo è pronto prima. `flutter analyze` pulito.

### 47.3 — Proprietario uscito: l'uscita scarica da sé
**File:** `lib/providers/jam_providers.dart` (risoluzione della sorgente di un item con proprietario assente),
`test/jam/jam_edge_test.dart`
1. Item `yt:` con proprietario non più nella Jam → il dispositivo d'uscita passa `videoId` al
   proprio `StreamPreparer` (`YtResult` dai campi dell'item) e suona dalla sua cache (R-21). Gli altri item del
   proprietario uscito (libreria) si tolgono dalla coda; restano solo gli `yt:` non ancora suonati (D-93).
2. Solo gli item non ancora suonati e solo quando servono (il prossimo, come `_precache`): niente riscaricamento di
   tutta la coda (K-07).

R-21.
**Fatto quando:** `flutter test test/jam/jam_edge_test.dart` verde: proprietario uscito → l'uscita risolve il brano
dall'id YouTube e lo scarica nella sua cache (downloader finto chiamato una volta con quel `videoId`); item di
libreria del proprietario uscito → tolti dalla coda (D-93), restano solo gli item YouTube non ancora suonati; solo il prossimo item viene scaricato.
`flutter analyze` pulito.

### 47.4 — Rotta `meta`: copertina, testo e curiosità dal proprietario
**File:** `lib/services/jam/jam_host.dart` (`buildRouter`: `GET /<sid>/meta/<n>`, servita da ogni partecipante come
`/<sid>/file/<n>`), `lib/providers/jam_providers.dart` (`resolveMeta`, richiesta al proprietario con timeout),
`lib/services/share/track_meta.dart` (riuso), `test/jam/jam_host_test.dart`, `test/jam/jam_transport_test.dart`
1. La rotta risponde un `TrackMeta` (fase 37) del brano: per `ref` numerico dalla riga di libreria, per `yt:` dalla
   riga ombra (testo, curiosità, copertina dal `CoverStore`). Item sconosciuto → 404.
2. Il richiedente: timeout come le altre richieste Jam; nessuna risposta, 404 o errore (vecchio APK, proprietario
   uscito) → dati di base dell'item (titolo, artista, album, durata), loggato con `AppLog.w`.

R-24.
**Fatto quando:** `flutter test test/jam/jam_host_test.dart test/jam/jam_transport_test.dart` verde: la rotta dà il
`TrackMeta` di un brano di libreria e di un brano in cache, 404 per un item sconosciuto o un `sid` sbagliato; senza
risposta il richiedente torna i dati di base. `flutter analyze` pulito.

### 47.5 — Via il FAB; swipe e «In coda» nella coda condivisa
**File:** `lib/ui/screens/jam/jam_screen.dart` (via `FloatingActionButton.extended` e `_addTracks`),
`lib/providers/player_providers.dart` (`addToQueue` e `enqueueOnline` in Jam → `jam.addTracks` /
`jam.addOnline`), ARB (testo guida, via `jamAddTracks` se non serve più), `test/ui/jam_screen_test.dart`
1. Con la Jam attiva lo swipe e «In coda» (righe di libreria e online) vanno nella coda condivisa.
2. Coda della Jam vuota: testo guida «Metti in coda dalla libreria o dalla ricerca».

R-22.
**Fatto quando:** `flutter test test/ui/jam_screen_test.dart` verde: nessun `FloatingActionButton` in `JamScreen`;
con la Jam attiva lo swipe su una riga chiama `jam.addTracks` (libreria) e su una riga online `jam.addOnline`; a coda
vuota c'è il testo guida. `grep -n "FloatingActionButton" lib/ui/screens/jam/jam_screen.dart` = 0. `flutter analyze` pulito.

**Dalla review della fase 46:**
- L'instradamento D-89 (tap e «Riproduci dopo» in Jam → coda condivisa) oggi è nella UI, in tre punti:
  `tapOnline`, `_play` dell'album online e «Riproduci dopo» in `track_actions.dart`. Spostalo in
  `PlayerController`, con un `bool Function()? jamActive` come `shufflePlus`, e togli i tre controlli.
- In Jam `enqueueOnline` deve decidere prima di `_idOf`: un id di libreria o negativo non vuol dire niente
  per gli ospiti. Deve tornare quando il brano è accettato, non a download finito, se no «Aggiunto alla
  coda» arriva minuti dopo.
- Una riga ombra (`kind = 2`) va in Jam con `jam.addOnline(streamResultOfRow(…))`, non con `addTracks`:
  il percorso `stream:` non ha estensione e verrebbe saltato. Fino ad allora «Aggiungi alla Jam» non
  compare sulle righe ombra.

### 47.6 — Schermata del brano della Jam
**File:** `lib/ui/screens/jam/jam_track_info_screen.dart` (nuovo), `lib/ui/screens/jam/jam_screen.dart` (tap sulla
riga, menu ⋮ con «Salta qui» solo per l'host), `lib/ui/screens/jam/jam_parts.dart`, ARB,
`test/ui/jam_track_info_screen_test.dart`
1. Tap su una riga della Jam (host e ospiti) → schermata con copertina, titolo, artisti, testo e curiosità (47.4; per
   i brani propri dati locali). Il salto dell'host (`JamCommand.jump`) si sposta dal tap al menu ⋮ della riga e a un
   pulsante «Salta qui» nella schermata, solo per l'host.
2. La schermata è leggera (nessun lavoro nel `build`, dati da un `FutureProvider`).

R-23.
**Fatto quando:** `flutter test test/ui/jam_track_info_screen_test.dart test/ui/jam_screen_test.dart` verde: tap su una
riga → schermata info per host e per ospite; «Salta qui» presente solo per l'host (nella schermata e nel menu ⋮);
con la rotta `meta` che non risponde la schermata mostra i dati di base. `flutter analyze` pulito.

### 47.7 — Controlli di fase (K-01, K-02)
1. K-01: `flutter test test/services/online/download_test.dart test/services/online/album_download_plan_test.dart
   test/services/library/download_tagger_test.dart test/services/import/` verde.
2. K-02: `flutter test test/data/stream_rows_hidden_test.dart` verde.
3. Jam esistente: `flutter test test/jam/` verde.
4. `flutter analyze` pulito; `flutter test` verde.
(K-03, misura sul Mi A3: non prevista in questa fase da «Controlli a ogni fase».)

**Fatto quando:** i comandi dei punti 1–4 sono verdi.

### 47.8 — Prove a mano (utente) [~]
Materiale per l'utente (R-30, K-04). Jam fra **PC Linux e Mi A3** sulla stessa Wi‑Fi (una volta host il PC, una volta
host il telefono):
- L'ospite cerca e accoda un brano online con lo swipe: compare nella coda condivisa quando è pronto e suona sull'uscita
  (R-20); tre brani di fila compaiono nell'ordine (D-80).
- L'ospite accoda un brano online ed esce subito: il brano suona lo stesso dall'uscita (R-21).
- Niente pulsante «aggiungi brani»; a Jam vuota il testo guida; swipe e «In coda» dalla libreria vanno nella Jam (R-22).
- Tap su una riga: schermata con copertina, testo e curiosità, anche per un brano dell'altro dispositivo; «Salta qui»
  solo sull'host (R-23, R-24).
- Log esportato senza 403/429 ripetuti dopo una coda Jam di 15 brani online (K-04).

**Fatto quando:** l'utente conferma le prove su Linux e Mi A3 (casella `[~]` → `[x]` in PROGRESS).

## Debito noto (review della fase 46, da fare dopo la feature)
- Tre modi di dire «questa voce online ora è un brano della libreria»: `PendingPlaylistAdds.replaceStream`, il
  `libraryIdOf`/`_downloadedId` dell'handler al caricamento e `currentQueueId` (con il `gone` di `removeIds`).
  Dopo una promozione riuscita basterebbe `online.idsOf(r)` → `replaceQueueId`, come fa `replaceStream`, e
  tenere `libraryIdOf` solo per le code ripristinate.
- `DownloadsNotifier` fa anche promozioni, `promoteErrors`, playlist e risincronizzazione del player, e i provider
  si importano in cerchio (`player`↔`youtube`, `youtube`↔`stream`, `youtube`↔`pending_playlist_adds`). Seguito:
  un solo `libraryIdOfProvider` accanto a `downloadIndexProvider`, e `addToPlaylistTag` fuori dai provider.
- (Review della fase 47) `libraryToJam` e `jamOnlineFailuresProvider` stanno in `player_providers.dart` ma sono
  logica della Jam e creano il ciclo `player`↔`jam`: spostarli in `jam_providers.dart` (es.
  `JamController.addLibraryIds`), così `PlayerController` vede solo `jamProvider`. Prima che la fase 48 faccia
  crescere `PlayerController`.
- `DownloadIndex` è un'istanza ricreata a ogni `invalidate` (scrittura ora atomica): meglio una sola istanza e un
  contatore di revisione osservato dalle righe.
