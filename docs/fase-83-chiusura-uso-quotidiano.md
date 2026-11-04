# Fase 83 — Chiusura del refactor «ui-uso-quotidiano»

**Obiettivo:** confrontare le misure finali con quelle di partenza (fase 77.1) e chiudere i controlli trasversali.

**Prerequisiti:** fasi 77–82 chiuse. Metriche e soglie: `refactor/ui-uso-quotidiano/analisi.md` «Rete».

## Task

### 83.1 — Misure finali
- Cambio scheda Libreria: `python3 scripts/perf_device.py 0d7ae9df206e --label 83-finale` e `flutter test integration_test/perf_test.dart -d linux`; confronto con la 77.1 (soglia p90 build ≤ 16 ms sul telefono, −50 % su Linux) e con le soglie della fase 38 per gli altri scenari (nessun peggioramento).
- `grep -rn CircularProgressIndicator lib/ui`: restano solo equalizzatore, memoria, sorgenti playlist.
- `flutter test test/theme/contrast_test.dart test/ui/a11y_guidelines_test.dart test/goldens` verdi; overflow a 2,0× su tutte le schermate del perimetro.

### 83.2 — Prova a mano e chiusura
- Giro completo sul Mi A3 seguendo `refactor/ui-uso-quotidiano/mockup/indice.html` schermata per schermata, con TalkBack su Home, Cerca e Registro.
- Handoff aggiornato, `docs/refactor/ui-uso-quotidiano/analisi.md` con lo stato finale dei rilievi, pulizia del disco.

**Fatto quando:** misure scritte qui e dentro le soglie, prova a mano fatta.

## Esiti
