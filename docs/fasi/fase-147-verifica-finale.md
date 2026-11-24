# Fase 147 — Verifica finale sul telefono e misure

## Obiettivo
Si prova sul telefono dell'utente (Motorola edge 40) ciò che i test non possono provare, si misura che le metriche di arrivo di `rete.md` siano rispettate e si chiude la grande revisione: documenti d'area aggiornati e nessun rilievo F-01..F-41 aperto senza motivo. Fuori: nuove funzioni.

## Riferimenti
D-662..D-699; rilievi e prove L1-L7 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); rete di test, metriche e prove su telefono in [`../refactor/grande-revisione/rete.md`](../refactor/grande-revisione/rete.md) (riga 147 e sezione «147»); mockup in `../refactor/grande-revisione/mockup/` (confronto a vista). Profilo e regole sulle prove su telefono: `.claude/obiettivo.md` (`scripts/telefono.py <serial> prepara|sblocca|avvia|testi|tocca|aspetta|foto|audio`, output corto, tetto di circa 60 chiamate per flusso). **Il Motorola ZY22HKD85K è il telefono dell'utente, non di prova**: niente disinstallazioni, niente file toccati, nessuna modifica ai permessi o al volume fatta dall'agente; il log si esporta da Impostazioni › Avanzate › Esporta log. I telefoni di test (Mi A3 `0d7ae9df206e`, Redmi `8bbad1cd`) si usano per le prove distruttive, a volume 0 e ripuliti a fine prova (D-502).

## Task
- [ ] 147.1 Proposta all'utente: come mettere la build sul Motorola — **chiedere prima, non decidere**
  - File: nessuno da scrivere.
  - Passi: 1) l'app sul Motorola è la release 1.6.4 firmata con la chiave di D-569: un APK di debug avrebbe firma diversa e richiederebbe la disinstallazione, che è vietata; 2) proporre all'utente (testo nel terminale, opzioni numerate): (a) una Release (tag e versione decisi dall'utente) dalla CI e aggiornamento dall'app (prova anche la fase 132); (b) prova sui soli telefoni di test, e sul Motorola solo il log dell'uso normale; 3) registrare la scelta in `../decisioni.md`.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: la scelta è registrata; i task 147.3-147.6 sono aggiornati di conseguenza.
- [ ] 147.2 Metriche di arrivo (rete.md)
  - File: nessuno in `lib/`; il risultato si scrive nelle «Note di deviazione» di questo file.
  - Passi: 1) eseguire i controlli per fase: coda illeggibile ≤ 3 tentativi e 1 popup (135); client finto ≤ 1 richiesta MB per ISRC e 0 dopo un 503 (136); N non trovati → lista di N (137); `grep -n "color: cc.bg" lib/ui/screens/library/all_tracks_screen.dart` = 0 (138); `grep -rn downloadsProvider lib/ui` un solo widget (139); migrazione su DB con brani locali: 0 righe modificate (140); le 8 pagine con una sola testata (141); 2 colonne sul telefono e 3 su desktop (142); invii solo da un tasto, `grep` sulle chiamate della segnalazione (143); 20 lingue + CEDICT + Spleeter (144); link per N brani sotto il limite scelto (145); stessi insiemi sui due DB, 0 file cancellati (146); 2) riportare l'esito per fase; 3) i test che coprono le metriche si lanciano mirati, non la suite intera.
  - Comando mirato: `flutter analyze` + i test mirati citati nelle fasi 135-146 (la suite completa la esegue la CI)
  - Fatto quando: una riga per fase con esito «ok» o con il motivo dello scarto.
- [ ] 147.3 Prove L1-L3 sul telefono: permesso, daylist, riavvio (D-678, D-679)
  - File: nessuno; si usa `scripts/telefono.py` e il log esportato.
  - Passi: 1) **l'utente** toglie il permesso audio dal telefono (Tocca a te): un solo avviso, banner in home e coda ferma; 2) l'utente ridà il permesso: i brani locali e la daylist suonano (L1, L2); 3) con coda illeggibile (permesso tolto) riavviare l'app: 0 popup (L3); 4) leggere il log esportato dall'utente e riportare le righe rilevanti.
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K avvia` e `testi` (output corto)
  - Fatto quando: il log mostra un solo avviso e nessun «Source error» a catena; i brani suonano dopo aver ridato il permesso.
- [ ] 147.4 Prove L4-L6: karaoke, correzioni, arricchimento (D-664, D-685, D-686, D-683)
  - File: nessuno.
  - Passi: 1) karaoke ancora acceso dopo il riavvio, nessuna separazione prima del play, promemoria dopo 20 minuti (L4); 2) correzione di una riga stream senza `unsupported` nel log (L5); 3) un giorno di uso normale: pochi 503, nessun riarricchimento delle stesse righe (L6), dal log esportato.
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K aspetta` e lettura del log esportato
  - Fatto quando: le tre prove hanno esito scritto nelle «Note di deviazione».
- [ ] 147.5 Prove L7 e aggiornamento: ripristino «Sostituisci», popup di versione (D-680, D-682)
  - File: nessuno.
  - Passi: 1) **prima**: backup completo dell'utente dall'app (Tocca a te); 2) «Sostituisci» con un backup: l'app si riavvia da sola con processo nuovo (verificare il PID prima e dopo con `adb shell pidof`, sola lettura); 3) il popup della nuova versione si apre con un tocco ovunque (con una versione più recente disponibile, da 147.1).
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K tocca` / `testi`
  - Fatto quando: il PID cambia dopo «Sostituisci»; il popup apre il dialogo.
- [ ] 147.6 Prove di streaming, download, condivisione, sync (D-665, D-695, D-697, D-677, D-668)
  - File: nessuno.
  - Passi: 1) aggiunte in streaming con i file locali intatti (conteggio dei file di `Music/FreeKmusic` prima e dopo, in sola lettura); 2) barra di download nel player e menu ⋮ che passa a «scaricato»; 3) condivisione su WhatsApp dal telefono (Tocca a te); 4) sync fra due dispositivi dell'utente (Tocca a te) o fra due telefoni di test, con cancellazioni, verificando che nessun file sparisca.
  - Comando mirato: `python3 scripts/telefono.py <serial> foto` (una foto per schermata, letta e poi cancellata con `~/.claude/skills/obiettivo/scripts/pulizia.sh via`)
  - Fatto quando: ogni voce ha esito scritto; il conteggio dei file locali è invariato.
- [ ] 147.7 TalkBack con uiautomator (memoria: solo verifiche automatiche)
  - File: nessuno; `test/ui/a11y_guidelines_test.dart` e `test/ui/accessibility_characterization_test.dart` come base.
  - Passi: 1) con `uiautomator` (output corto) verificare etichette e dimensioni delle schermate nuove: testata a icone, griglia del Riprendi, barra di scorrimento, pagina Modelli, segnalazione, `DownloadBar`; 2) niente prove a mano con TalkBack; 3) lanciare i due test di accessibilità.
  - Comando mirato: `flutter test test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart`
  - Fatto quando: nessun controllo sotto 48 dp o senza etichetta nelle schermate nuove.
- [ ] 147.8 Pulizia e chiusura
  - File: `docs/prossimi-lavori.md` (rilievi rimandati, se ce ne sono), `docs/handoff.md`, `docs/storico/README.md` (righe delle fasi 135-147), `docs/refactor/grande-revisione/` (spostare in `docs/storico/refactor/` con `git mv`).
  - Passi: 1) a volume 0 sui telefoni di test e ripulire tutto ciò che si è messo (D-502); sul Motorola non si tocca nulla; 2) cancellare foto e log già usati con `~/.claude/skills/obiettivo/scripts/pulizia.sh via`; 3) spostare la cartella del refactor nello storico e aggiornare i link; 4) fermare ogni shell in background; 5) proporre all'utente il rilascio (numero di versione e tag decisi da lui).
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: link verdi; telefoni di test puliti e a volume 0; il Motorola senza modifiche.
- [ ] 147.9 Area e controllo di fine fase
  - Aggiorna i documenti d'area toccati dalle fasi 135-146 se qualcosa è rimasto indietro (`../architettura/00-panoramica.md`, `qualita-e-rilascio.md` con il risultato delle misure); `../decisioni.md` per le scelte prese in 147.1 e nelle proposte di 143, 145, 146.

## Da provare sul telefono (review fase 140)
- `JamSaver` (l'ospite salva un brano dell'host) nella cartella pubblica su Android 11+: verificare che la copia finisca dove la scansione la trova, sul Mi A3 o sul Redmi (solo l'app, mai i file già presenti).

## Tocca a te
- [ ] Telefono collegato (Motorola ZY22HKD85K, e i telefoni di test per le prove distruttive) con debug USB e schermo sbloccabile.
- [ ] Concedere/togliere il permesso `READ_MEDIA_AUDIO` dal telefono quando richiesto (L1/L2); farlo dall'agente non è previsto.
- [ ] Fare un backup completo dall'app prima di «Sostituisci».
- [ ] Provare la condivisione su WhatsApp e il sync fra due dispositivi.
- [ ] Decidere come mettere la build sul Motorola (147.1) e la versione di rilascio.

## Note di deviazione

## Da controllare (review e scheggia della fase 142)
- Riquadro Radio del Riprendi: se la stazione sta già suonando il tocco la riavvia (`playStations`); Android Auto mette il contesto a null (`codecore_audio_handler.dart:525,531`), quindi radio e album avviati dall'auto compaiono come «Brano».
- Riquadro Daylist visibile per 90 giorni anche quando la daylist non può partire (`daylist_providers.dart:374`: ritorno silenzioso): nasconderlo o avvisare.
- Griglia a 3 colonne: la soglia è sulla larghezza del blocco (560 dp); su desktop serve una finestra di circa 1324 dp. La metrica 147.1 va misurata sul blocco, o la soglia rivista.
- Log `discovery: socket error | Network is unreachable` ogni 2 s su Android offline.

## Da controllare (review e scheggia della fase 144)
- Finestra fra `SeparationService.deleteModels` e un `request()` in arrivo (separazione che parte dopo `await _last`): ricontrollare `_activeKey` in ciclo o contare la separazione nella sezione esclusiva; provare sul Mi A3 «Elimina» del karaoke con una separazione in corso.
- Test di contratto app↔Worker: oggi solo i limiti; aggiungere 201 con `url`, 504 incerto, 429 e le chiavi della richiesta (`title`, `body`, `version`).
- Cancellazione di molte lingue di traduzione: ogni `delete` rilegge le 20 lingue da ML Kit; misurare sul Mi A3 e, se pesa, una sola lettura per selezione. Provare la cancellazione reale ML Kit e il ritardo di `isModelReady`.
- Download del dizionario avviato dal testo di un brano cinese con pinyin: la riga CC-CEDICT della pagina deve mostrare «In scaricamento…» e l'avanzamento.

## Da controllare (review e scheggia della fase 145)
- Importazione dal link della pagina: spostare ricerca, `_busy` e `saveToLibrary` da `lib/ui/shell/shared_collection_import.dart` a un provider accanto a `saveToLibrary`, così la UI tiene solo la conferma e i messaggi; valutare `innerTube.songOf(id)` al posto di `yt.search(url)` se ne arrivano i campi necessari.
- «Condividi…» di `online_album_screen.dart` e `online_playlist_screen.dart` copia ancora il link negli appunti: portarlo al foglio di sistema (D-677) con un testo da id ed etichette, poi togliere `shareMenu` dagli ARB. Stesso costruttore per il brano online del menu ⋮ (oggi una `Track` finta).
- Test di contratto fra `kSharePageUrl`, manifest (host e percorsi), `IncomingBridge.kt`, `docs/site/fragment.js` e `index.html` (pacchetto, release, anche `kReleaseRepo`); test che `encodeShareFragment` riproduce i vettori positivi.
- `shortTitle`/`openSearchWith` in un file neutro della shell e taglio per caratteri (`characters.take`), non per unità UTF-16. «Senza titolo» del frammento localizzato dal chiamante.
- Menu ⋮: `shortcut:` sul perché l'host è statico (deve stare sotto il Navigator di radice).
- m3u8 cancellato a fine condivisione; su desktop negli appunti il testo leggibile, non il corpo `#EXTM3U`. CSP della pagina senza `unsafe-inline` (script in `main.js`). In `IncomingBridge.kt` controllo anche del percorso e un tetto a `pendingTexts`.
- Brano singolo da link senza rete: Cerca mostra tre messaggi di rete e resta in errore finché non si preme Riprova.
- Da provare (Mi A3 o Motorola): importazione completa da link con yt-dlp che risponde (sul Mi A3 le ricerche vanno in timeout dopo 45 s); condivisione di una playlist con più di 50 brani in streaming (file m3u8); App Link verificato con l'APK di release (`pm get-app-links`); «Apri in FreeKmusic» toccato dalla pagina in un browser vero; condivisione su WhatsApp (utente).

## Da controllare (review e scheggia della fase 146)
- Parità al millisecondo: due modifiche della stessa playlist con lo stesso `updatedAt` su due dispositivi non convergono (1 caso su 300 nel fuzz a passo 0); serve un criterio di spareggio deterministico (es. uuid del dispositivo).
- Un peer di una versione precedente senza le rotte nuove risponde 404 e fa fallire il sync dei preferiti: degradare a sole playlist.
- `/sync/plays` rimanda ogni volta gli ultimi 20000 ascolti: aggiungere `since` come per i tombstone.
- `hasFile` viene dall'indice dei download in memoria; i cuori su brani che qui sono file non viaggiano.
- Annullare un cuore messo per sbaglio lascia un tombstone `favoriteStream` datato adesso (caso accettato).
- Prova reale (Mi A3 e Redmi come «miei», mai il Motorola): «Sincronizza ora» con aggiunte e rimozioni, conferma, impostazioni scelte, dispositivo non «mio» che porta solo playlist.
