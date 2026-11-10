# Fase 82 — Registro attività, Da confermare e Da revisionare (refactor «ui-uso-quotidiano»)

**Obiettivo:** «Accetta tutte» in un colpo; Registro ordinato per giorno con filtri e testi semplici; Da confermare e Da revisionare ridisegnati.

**Prerequisiti:** fase 77 chiusa. Mockup `refactor/ui-uso-quotidiano/mockup/registro.html`, `refactor/ui-uso-quotidiano/mockup/da-confermare.html`, `refactor/ui-uso-quotidiano/mockup/da-revisionare.html` (le note dei mockup sono specifica: categorie, «Come risolvere», gruppi download). Decisioni D-361, D-365. Area a rischio: `lib/services/library/track_corrections.dart` (scrittura dei tag sui file).

**Comando mirato:** `flutter test test/providers/activity_log_test.dart test/data/activity_log_repository_test.dart test/ui/recognition_ui_test.dart test/services/library/track_corrections_test.dart test/ui/review_screen_test.dart test/providers/review_actions_test.dart test/ui/activity_log_screen_test.dart`.

## Task

### 82.1 — «Accetta tutte» in un colpo (F-40…F-42, F-71, F-72, U17, D-361)
- `acceptAll` (`track_corrections.dart:117-123`): lettura degli id dei file prima, poi una sola `_db.transaction` con save + riga di registro + decisione per tutte le proposte, poi la scrittura dei tag nei file in sottofondo, in sequenza, fuori dalla transazione; un errore su un file va nel registro e non annulla le altre righe. Ritorna N.
- UI: la lista si svuota in un colpo, snackbar «N correzioni accettate · i file si aggiornano in sottofondo» con Annulla, che ripristina tutte le correzioni appena accettate con la stessa operazione di «Ripristina» (D-372).
- Riscrivere `track_corrections_test.dart:349`. Test: una transazione; una sola emissione di `watchProposals`; N restituito; errore di file nel registro con le righe DB intatte.

### 82.2 — Da confermare (F-39)
- Scheda per proposta: copertina, vecchio barrato attenuato → nuovo evidenziato, fonte come etichetta (MusicBrainz, AcoustID, YouTube Music), Accetta / Scarta ≥ 48 dp; «Accetta tutte (N)» in alto; stato vuoto «Tutto confermato».

### 82.3 — Registro attività (F-30…F-38, F-56, F-58, U15, D-365)
- Provider: voci raggruppate per giorno (Oggi, Ieri, «lun 2 nov») e categoria (Download; Libreria = import, invio, scansione, doppioni, uscite, podcast, radio; Arricchimento = arricchimento e secondo parere; Correzioni; Errori = esito fallito; «Fermato» neutro); download dello stesso giorno raggruppati in una voce espandibile.
- Schermata: intestazioni di giorno fisse in alto; filtri scorrevoli con conteggi; riquadro «Da confermare · N» in cima con 2 anteprime; una icona per categoria; titolo breve + una riga di dettaglio + numeri come chip; «Non riuscito» con icona e testo; messaggi per l'utente con «Come risolvere» (passi veri dell'app, da verificare); correzioni da → a su due righe con Ripristina; altezza delle righe libera (niente `itemExtent` 64); «Pulisci registro» nel ⋮ con conferma. Desktop: lista + dettaglio della voce.
- Testi riscritti negli ARB it/en/de/es (F-58).
- Test: gruppi per giorno; filtro per categoria; errori con testo; «Pulisci» chiede conferma; nessun overflow a 2,0×.

### 82.4 — Da revisionare (F-43…F-46, U16)
- Spiegazione breve sotto il titolo; filtri in riga scorrevole con conteggi sui 4 motivi reali di `ReviewReason`; motivi come chip; azione primaria visibile (Cerca / Riprova) e ⋮ per il resto; «Ignora» con testo e Annulla; barra del secondo parere alta 48 con avanzamento e «Ferma»; selezione multipla come oggi; caricamento con `Skeleton`.

### 82.5 — Controlli di fase
`flutter analyze`; comando mirato; golden `activity_log`, `proposals`, `review`; code-review high (`track_corrections`); scheggia. Sul Mi A3: «Accetta tutte» su più proposte (lista vuota subito, tag scritti dopo: verificare un file), Registro con filtri, Da revisionare.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Dalla review della fase 80
- Riquadro «Da confermare · N», schede delle proposte e righe del Registro su `CcTile` (`lib/ui/widgets/cc_tile.dart`); caricamento di Da revisionare con `AsyncBody(rowHeight:)`/`RowsLoading` invece di uno skeleton fatto a mano.

## Dalla review della fase 81
- `Skeleton` ha parametri ancora senza chiamanti (`margin`, `Skeleton.card(title:)`, `label` su card/gridCell/bars): usarli qui dove servono (Registro, Da revisionare), altrimenti la 83 li toglie.

## Esiti
- 2026-11-05 — `flutter analyze` pulito; comando mirato + `test/l10n`, test di architettura e separatori, tutti i golden: 268 test verdi. APK debug costruito.
- Golden nuovi (`test/goldens/activity_golden_test.dart`, ora fissa con `nowMsOverride` di `lib/core/clock.dart`): `activity_log`, `proposals`, `review` a phone e desktop, 100 e 150 %, più `phone_100_light_*`. Corretti dai golden: spazio prima di «Rivedi», larghezza massima di Da confermare su desktop, vuoto nella scheda dei download chiusa.
- Code review Opus di 82.1-82.2 (area a rischio): file bloccati che non arrivavano al Registro; proposta scartata (o rinnovata) durante «Accetta tutte» applicata lo stesso → ricontrollo dentro la transazione; Annulla che scartava tutto → D-372 precisata (Annulla rimette le proposte in Da confermare, Ripristina del Registro le scarta).
- Code review Opus di 82.3: chip «senza risultato» del giro in sottofondo, voce `noAnswer` come «Fermato», «File non aggiornato» col nome del brano e passi secondo il motivo, etichetta TalkBack della correzione, conteggi dei filtri dal DB (`countsByKind`), avviso in Pulisci, selezione desktop per voce. Review di 82.4: Annulla di Ignora fuori schermata, pulsanti della selezione con testo.
- Scheggia (effort high): 61 mutanti, 17 sopravvissuti, ora coperti da test. Bug corretti: Ripristina con file non scritto ora lascia la riga d'errore nel Registro; righe di registro rilette a blocchi di 500 (limite di variabili SQLite); vecchio Annulla chiuso a ogni «Accetta tutte»; riga d'importazione col dettaglio illeggibile contata come nel DB.
- Mi A3: «Accetta tutte (27)» → lista vuota subito, snackbar «27 correzioni accettate. I file si aggiornano in sottofondo.», 27 correzioni nel Registro con da → a e Ripristina (file non toccati: «Scrivi le modifiche nei file» spento, come voluto). Con l'impostazione accesa per la prova, Ripristina ha riscritto il file con i tag di prima (poi impostazione rimessa com'era). Registro: giorni, filtri con conteggi che cambiano la lista, Pulisci chiede conferma. Da revisionare: spiegazione, filtri con conteggi, chip, Ignora + Annulla rimette la riga; «Tutti» coincide col riquadro della Libreria. Nessuna eccezione nel log.
- Lasciato alla fase 83: il pannello di dettaglio desktop di un gruppo di download mostra solo il primo brano; `Skeleton.margin`/`label` ancora senza chiamanti (il Registro è sincrono).
