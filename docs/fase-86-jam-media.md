# Fase 86 — `JamMedia` fuori da `jam_providers.dart`

**Obiettivo:** togliere da `JamController` la parte che risolve file, metadati e copertine della Jam, con la sua cache. Il comportamento non cambia. Era il primo dei prossimi obiettivi nell'handoff della fase 85.

## Task
- **86.1** Nuova classe `JamMedia` in `lib/providers/jam_media.dart`:
  - prende i provider con `Ref Function()`, come `JamLocalQueue`;
  - legge lo stato del controller con quattro closure: id, stato, host e file dell'ospite;
  - possiede la cache della Jam, i pin, le chiavi scaricate senza successo, il client HTTP e `JamRemoteMeta`;
  - espone `resolve`, `localFile`, `localMeta`, `localCover`, `fetchCover`, `fetchMeta`, `precache`, `syncPins` e `dispose`.
- **86.2** Il controller costruisce `JamMedia` e gli delega queste chiamate. `fetchCover` e `fetchMeta` restano anche sul controller, così chi le usa non cambia. `jam_providers.dart` scende da 1271 a 1073 righe.
- **86.3** Nuovi test unitari in `test/providers/jam_media_test.dart`:
  - `remoteUri`;
  - la copia locale nella Jam sincronizzata;
  - le tracce tenute da `precache`;
  - i pin;
  - `dispose`;
  - la copertina per un ospite remoto.

  Erano buchi già presenti prima della fase, trovati dalla scheggia. Ora si coprono con un test piccolo perché `JamMedia` si costruisce da sola.

**Controlli:**
- La review Sonnet (effort high) ha confrontato il codice spostato riga per riga con master. Nessun cambio di comportamento. L'unica differenza è che `_remoteMeta.clear()` ora gira più tardi nella chiusura della Jam, e va bene così.
- L'import circolare con `jam_providers.dart` (per `JamRole` e `JamUiState`) resta: Dart lo accetta, e toglierlo vorrebbe dire spostare `JamUiState`.
- Scheggia in modalità passo: 6 mutanti, 0 bug. 5 sopravvivevano, e ora ognuno ha il suo test.

**Fatto quando:** la PR è fusa con «Analyze and test» verde.
