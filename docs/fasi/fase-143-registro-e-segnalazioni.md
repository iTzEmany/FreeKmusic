# Fase 143 — Registro e segnalazioni

## Obiettivo
Nel Registro «Ferma tutto» e «Annulla tutto» agiscono su tutte le importazioni; da ogni voce si può «Segnalare» con i dati già compilati; la schermata di segnalazione è ridisegnata e invia in modo anonimo tramite un Cloudflare Worker che crea una issue GitHub (ripiego: «Copia testo»). L'invio parte solo da un tasto: nessuna telemetria. Fuori: i link di condivisione (145), la riscrittura del log.

## Riferimenti
D-698, D-691, D-669, D-662, D-699. Rilievi F-32, F-40 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); difetti della schermata in `scansione-ui.md` (punti 10, 12); [`../refactor/grande-revisione/ricerca-condivisione-segnalazioni.md`](../refactor/grande-revisione/ricerca-condivisione-segnalazioni.md) (sezione «Segnalazioni anonime»); rete.md riga 143. Mockup: `mockup/segnalazione.html` in `../refactor/grande-revisione/mockup/`. Aree: `../architettura/ui-e-design.md`, `online.md`, `qualita-e-rilascio.md`.

## Task
- [ ] 143.1 «Ferma tutto» e «Annulla tutto» (F-32; D-698)
  - File: `lib/services/import/playlist_import_service.dart` (`pauseChain`/`resumeChain`/`cancelChain`, ~1223-1240: nuovi `pauseAll`, `cancelAll`), `lib/providers/import_providers.dart`, `lib/ui/screens/activity/activity_log_screen.dart`, ARB ×6.
  - Passi: 1) `pauseAll`/`cancelAll` agiscono su tutte le catene in corso; 2) i due pulsanti compaiono solo se c'è almeno un'importazione e si nascondono altrimenti; 3) conferma per «Annulla tutto»; 4) test.
  - Comando mirato: `flutter test test/services/import/playlist_import_service_test.dart test/ui/activity_log_screen_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: con 2 importazioni in corso i due pulsanti fermano/annullano entrambe; senza importazioni non sono visibili.
- [ ] 143.2 «Segnala» dal Registro, precompilato (F-40; D-691; mockup `segnalazione.html`)
  - File: `lib/ui/screens/settings/report_issue_screen.dart` (costruttore con titolo e dettagli tecnici), `lib/ui/screens/activity/activity_log_entry.dart` (`LogDetail`: tasto «Segnala»), `lib/core/issue_report.dart` (~70, ~107), `lib/core/log_export.dart` (redazione), ARB ×6.
  - Passi: 1) `ReportIssueScreen(title:, details:)`; 2) tasto «Segnala» in `LogDetail` con i dati della voce (testi già redatti da `log_export`); 3) test: la schermata si apre precompilata.
  - Comando mirato: `flutter test test/core/issue_report_test.dart test/ui/report_issue_screen_test.dart test/ui/activity_log_screen_test.dart test/ui/architecture_test.dart`
  - Fatto quando: «Segnala» apre la schermata con titolo e dettagli della voce.
- [ ] 143.3 Schermata di segnalazione ridisegnata (F-40; mockup `segnalazione.html`)
  - File: `lib/ui/screens/settings/report_issue_screen.dart` (difetti: riga di pulsanti che sfora ~140-157; anteprima del log senza altezza massima ~200-241; `buildIssue` ricostruito a ogni lettera ~68; nessuna spiegazione del tasto disabilitato; nessun `maxWidth` su desktop; stato `…`; campi alti; icone nei blocchi), `lib/providers/issue_providers.dart`, ARB ×6, golden `report_issue` se esiste.
  - Passi: 1) pulsanti che vanno a capo (`Wrap`); 2) anteprima con altezza massima e scorrimento; 3) `buildIssue` solo all'invio o con debounce; 4) testo che spiega perché il tasto è disabilitato; 5) `maxWidth` su desktop; 6) nota che l'IP è visibile al servizio intermedio; 7) test di widget.
  - Comando mirato: `flutter test test/ui/report_issue_screen_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: nessun overflow a 320 dp e a 1280 dp (test), il tasto disabilitato ha la spiegazione.
- [x] 143.4 Proposta all'utente: dove vive il codice del Worker (D-669) — **chiedere prima, non decidere**
  - File: nessuno da scrivere. Documenti letti: `analisi.md` (sezione «Arrivo», «Servizi esterni»), `ricerca-condivisione-segnalazioni.md`.
  - Passi: 1) scrivere all'utente (testo nel terminale, opzioni numerate): (a) cartella `tools/report-worker/` in questo repo, (b) repo a parte, (c) Web3Forms al posto del Worker (D-669 lo ammette come ripiego più semplice); con pro e contro (deploy, segreti, CI, manutenzione); 2) registrare la risposta in `../decisioni.md` come D-xxx; 3) non procedere a 143.5 e 143.6 senza risposta.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: la scelta dell'utente è in `../decisioni.md` e 143.5/143.6 sono aggiornati col percorso scelto.
- [ ] 143.5 Invio anonimo dall'app, ripiego «Copia testo» (F-40; D-691)
  - File: `lib/core/issue_report.dart` (~107, oggi URL di issue GitHub), `lib/services/online/http_client.dart` (client), `lib/providers/issue_providers.dart`, `lib/ui/screens/settings/report_issue_screen.dart`, `lib/core/constants.dart` (indirizzo del Worker, vuoto finché l'utente non lo crea), ARB ×6.
  - Passi: 1) `IssueSender` con interfaccia, implementazione HTTP verso l'indirizzo configurato e client finto nei test; 2) se l'indirizzo è vuoto o l'invio fallisce: «Copia testo» (e l'apertura della issue GitHub di oggi resta come terza via); 3) l'invio parte solo dal tasto «Invia»; limite di lunghezza lato app; 4) test con client finto (il Worker non si chiama mai da `flutter test`).
  - Comando mirato: `flutter test test/core/issue_report_test.dart test/ui/report_issue_screen_test.dart test/ui/architecture_test.dart`
  - Fatto quando: client finto: invio riuscito, invio fallito → «Copia testo»; `grep` mostra che l'unica chiamata di rete della segnalazione parte dal tasto.
- [ ] 143.6 Codice del Worker (D-669, D-691) — dopo la risposta a 143.4 e l'account dell'utente
  - File: dal percorso scelto in 143.4 (proposta di partenza: `tools/report-worker/src/index.js`, `wrangler.toml`, `README` breve solo se l'utente lo vuole).
  - Passi: 1) il Worker riceve JSON (titolo, corpo, versione), valida la lunghezza, applica massimo 5 invii l'ora per IP, non inoltra l'IP; 2) crea la issue GitHub con etichetta `da-triage` usando il token solo come segreto del Worker; 3) risposta con l'indirizzo della issue; 4) test locale del Worker con `wrangler dev` o una prova unitaria sul gestore (senza token reali); 5) il deploy lo fa l'utente (Tocca a te).
  - Comando mirato: da definire con il percorso scelto (es. `node --test tools/report-worker/`); `python3 scripts/check_docs_links.py`
  - Fatto quando: la prova locale crea la issue su un repo di prova con token di prova, oppure il gestore passa i test unitari su validazione e limite.
- [ ] 143.7 Area e controllo di fine fase
  - Aggiorna `../architettura/ui-e-design.md` (schermata di segnalazione, Ferma/Annulla tutto), `online.md` (servizio esterno del Worker, eccezione a «nessun backend»), `qualita-e-rilascio.md` (dove vive il Worker e come si pubblica); «Trappole»: l'invio parte solo da un tasto.

## Tocca a te
- [ ] Creare l'account Cloudflare (piano free) e il token GitHub fine-grained con solo `issues:write` sul repo, da salvare come segreto del Worker (D-669); creare l'etichetta `da-triage` nel repo.
- [ ] Rispondere alla proposta di 143.4 (dove vive il Worker) e, dopo 143.6, pubblicare il Worker (`wrangler login` e `wrangler deploy`), poi comunicare l'indirizzo per `lib/core/constants.dart`.

## Note di deviazione

## Da allineare (review di architettura della fase 141)
- `demoteToStream` (`track_repository.dart:220`) e `rekeyStream` (`:274`) scartano l'id restituito da `mergeStreamRow`: `_shadowId` e le voci online possono restare legati a una riga cancellata. `replaceQueueId` dell'audio handler chiami da sé `online?.rebindRow(old, new)` (come `removeTracks` con `unbindRows`) e lo si invochi da tutti i percorsi di fusione (oggi sparsi fra handler, `stream_providers.dart:129`, `youtube_providers.dart:255`).
