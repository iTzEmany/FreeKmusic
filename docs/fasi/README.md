# Fasi aperte

Qui vivono le fasi **non ancora chiuse**, una per file: `fase-N-<nome>.md` (N = numero successivo all'ultima in [`../storico/README.md`](../storico/README.md); lettera finale per le sotto-fasi, come `69a`). Quando una fase è chiusa (PR fusa) si sposta con `git mv` in `../storico/fasi/` e si aggiunge la riga alla tabella dello storico.

L'avanzamento si spunta **nel file della fase**: niente registro globale.

## Modello
```markdown
# Fase N — <titolo>

## Obiettivo
Una o due frasi: cosa cambia per l'utente o per il codice, e cosa resta fuori.

## Riferimenti
Decisioni (D-xxx), documento d'area in `../architettura/`, specifiche in `../storico/feature/` se servono.

## Task
- [ ] N.1 <titolo breve>
  - File: da creare/modificare
  - Passi: numerati
  - Comando mirato: `flutter test <file…>` (più `flutter analyze`)
  - Fatto quando: criterio verificabile (comando o comportamento osservabile)
- [ ] N.2 …

## Tocca a te
Ciò che solo l'utente può fare (sudo, telefono, ascolto).

## Note di deviazione
Una riga per ogni scarto dal piano.
```

Regole: un task sta in una sessione breve (altrimenti spezzalo); la suite completa la esegue la CI; a fine fase aggiorna il documento d'area in `../architettura/` e, se serve, il registro `../decisioni.md`.
