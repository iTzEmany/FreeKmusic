# Fase 120 — «Test (Windows)» verde

## Obiettivo
Il job «Test (Windows)» della CI (e, di conseguenza, la build «Windows», che dipende da lui) torna verde senza `continue-on-error`, senza saltare test e senza abbassare asserzioni o timeout. Solo test: il codice del prodotto non cambia.

## Riferimenti
R-238 «Test (Windows) e build Windows verdi». Documento d'area: `../architettura/qualita-e-rilascio.md`.

## Task
- [x] 120.1 I `DislikeStore` dei test non scrivono più su `/nonexistent`
  - File: `test/support/suggestion_gate_fake.dart`, `test/services/shuffle_plus/suggestion_gate_test.dart`, `test/providers/artist_all_songs_provider_test.dart`, `test/ui/online_results_rows_test.dart`
  - Passi: `writeDelay` di un giorno, così il blocco non programma mai la scrittura.
  - Comando mirato: `flutter test test/providers/shuffle_plus_test.dart test/services/shuffle_plus` (più `flutter analyze`)
  - Fatto quando: «Test (Windows)» e «Windows» verdi su una run di `workflow_dispatch`.

## Tocca a te
Niente.

## Note di deviazione
- Causa radice: `testGate()` (e tre `DislikeStore` sparsi nei test) puntavano a `File('/nonexistent/dislikes.json')`. Su Linux la cartella non si può creare e la scrittura ritardata (1 s dopo `blockTrack`/`blockArtist`) falliva in silenzio; su Windows `/nonexistent` è `C:\nonexistent`, scrivibile, quindi il file veniva creato e **riletto dai test successivi**: i loro `filter.allows` davano falso per tutte le righe della radio (`pool.take` le scartava), nessun suggerimento, e l'helper `until` scadeva a 30 s (la catena di 21 test). Diagnosi dai log della CI con la tabella dei motivi di scarto per riga (`allow=false`). Non era un problema di orologio né del controller.
