# Fase 105 — Chiusura del refactor «ascolto-quotidiano»

**Obiettivo:** verificare le metriche, provare tutto sul telefono contro i mockup, far rivedere l'architettura e chiudere la documentazione.

**Prerequisiti:** fasi 98–104 chiuse. Mockup approvati (D-453) in `refactor/ascolto-quotidiano/mockup/`. Area a rischio: tutto il diff 98–104 (review Opus: migrazione, backup, coda).

**Comando mirato:** `flutter test test/services/daylist test/services/shuffle_plus test/services/backup test/data/migration_test.dart test/ui/dislike_sheet_test.dart test/ui/lyrics_editor_test.dart test/ui/button_tap_sweep_test.dart test/ui/a11y_guidelines_test.dart test/ui/talkback_labels_test.dart` (la suite completa la esegue la CI).

## Task

### 105.1 — Metriche di arrivo
- Tutte le soglie della tabella «Metriche di arrivo» in `refactor/ascolto-quotidiano/analisi.md`, con i comandi e i valori in Esiti.

### 105.2 — Prova sul Mi A3 contro i mockup (D-455)
- Via adb (`0d7ae9df206e`), APK debug sopra i dati esistenti: ogni mockup schermata per schermata; differenze evidenti corrette, minori accettate con motivo (come D-422), elenco all'utente alla fine. Etichette TalkBack verificate con uiautomator (memoria «TalkBack senza prove a mano»). Ripulire il telefono, mai cancellare i file musicali.

### 105.3 — Review di architettura
- Opus sul diff 98–104: livelli rispettati, nessuna logica di dominio nuova in `lib/ui`, nessun lavoro pesante sul thread UI, nessun `catch` muto. Bug corretti subito; debito in `prossimi-lavori.md` (nuova sezione).

### 105.4 — Documenti
- `analisi.md` «Stato finale»; `prossimi-lavori.md` §6 aggiornato (voci chiuse spuntate); `PROGRESS.md`, `00-INDICE.md`, `handoff.md`.

### 105.5 — Controlli di fase
`flutter analyze`; comando mirato; scheggia fase sull'app sul telefono.

**Fatto quando:** metriche rispettate, prova sul telefono fatta, review chiusa, documenti aggiornati.

## Esiti
