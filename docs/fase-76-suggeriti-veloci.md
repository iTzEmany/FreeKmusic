# Fase 76 — Suggeriti di Shuffle+ in coda appena c'è l'indirizzo

**Obiettivo:** i suggeriti online di Shuffle+ compaiono in coda appena il loro indirizzo di streaming è pronto, non dopo il download completo del file; il download finisce in sottofondo.

**Prerequisiti:** fase 75 chiusa (PR #95). Richiesta dell'utente (3/11): «non mi piace il fatto che lo shuffle+ ci metta così tanto a caricare i suggeriti» (D-352). Nessun pacchetto nuovo, nessuna migrazione. Aree a rischio: `lib/services/stream/stream_preparer.dart` (avvio dello streaming, R-71), `lib/services/shuffle_plus/shuffle_plus_controller.dart` (ordine e numero dei suggeriti).

**Oggi:** `ShufflePlusController._suggestOne` (r.342–380) chiama `prepare` = `shufflePlusPrepareProvider` (`shuffle_plus_providers.dart:144`) = `StreamPreparer.ready`, che ritorna solo con il file intero in cache (`stream_preparer.dart:184`). Solo dopo il suggerito entra in coda, e `_suggest` passa al successivo: con due posti liberi si aspettano due download completi in fila.

**Regola della fase:** ogni comportamento nuovo prima si fissa con un test che fallisce sul `master` attuale, poi si scrive il codice.

**Comando mirato:** `flutter test test/providers/shuffle_plus_test.dart test/services/shuffle_plus test/services/stream test/services/audio/online_playback_test.dart` (più i file di test nuovi della fase).

## Task

### 76.1 — Rete di sicurezza
Test nuovi, rossi sul `master` di oggi:
- con un preparer finto che dà l'indirizzo subito e il file dopo 30 s (orologio finto), il suggerito è in coda appena c'è l'indirizzo;
- due posti liberi: i due suggeriti entrano senza aspettare il download completo del primo;
- un indirizzo che fallisce passa al candidato successivo come oggi (`prepareAttempts`), senza contare un errore di riproduzione.

### 76.2 — Indirizzo invece del file
- `shufflePlusPrepareProvider` usa `StreamPreparer.start` (indirizzo, R-71) invece di `ready`; il download del file prosegue nella finestra della coda come per gli altri brani in streaming (pre-caricamento).
- Il suggerito che arriva al suo turno con il file non ancora in cache parte dall'indirizzo come un risultato della ricerca online (stesso percorso, nessun caso nuovo nel player).
- Controllare che un indirizzo scaduto quando il suggerito arriva al turno sia già gestito («Source error» = indirizzo scaduto, `docs/PROGRESS.md` 22/10); se non lo è, correggere qui.
- Arricchimento (D-351): invariato, parte quando il suggerito suona e ha la riga.

### 76.3 — Controlli di fase
`flutter analyze` pulito; comando mirato verde; code-review high (aree a rischio); scheggia. Prova dal vivo sul Mi A3 con Shuffle+ e una lista della libreria: tempo dal primo brano al primo suggerito in coda (log) prima e dopo, a parità di rete; il suggerito suona senza salti; testo e curiosità arrivano quando suona.

**Fatto quando:** tutti i controlli sopra sono fatti e scritti qui.
