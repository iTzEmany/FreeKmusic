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

## Esiti
