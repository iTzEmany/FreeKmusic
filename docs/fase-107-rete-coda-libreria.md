# Fase 107 — Rete del refactor «coda-e-libreria»

**Obiettivo:** fissare con test il comportamento di oggi (coda senza aggiunte, salvataggio senza `lastQueueUser`, ricerca con `LIKE`, titolo lungo con «…») e misurare le prestazioni di partenza sul Mi A3, prima di toccare il prodotto. **Nessun cambio di comportamento e nessun cambio al codice del prodotto** (D-499, D-501).

**Prerequisiti:** refactor «coda-e-libreria» avviato (D-483..D-508). Analisi `refactor/coda-e-libreria/analisi.md`: «Rete (giro 4)» e «Metriche di arrivo». Mockup approvati (D-498) in `refactor/coda-e-libreria/mockup/`: `titoli.html`, `libreria.html`, `playlist-ricerca.html`, `coda.html` (qui servono solo come riferimento). Aree a rischio: coda (`play_queue.dart`, `codecore_audio_handler.dart`), query su `tracks`.

**Comando mirato:** `flutter test test/services/audio/play_queue_characterization_test.dart test/services/audio/playback_persistence_test.dart test/data/track_repository_test.dart test/ui/mini_player_test.dart test/ui/now_playing_test.dart`

**Base verde prima di ogni passo:** `flutter test test/services/audio/play_queue_test.dart test/services/audio/gapless_handler_test.dart test/providers/play_online_test.dart test/providers/play_online_jam_test.dart`

## Task

### 107.1 — Caratterizzazione di `PlayQueue` (Rete, riga B)
- `test/services/audio/play_queue_characterization_test.dart`: passeggiata casuale a semi fissi su `PlayQueue` (5 semi × 200 operazioni: `next`, `previous`, `jumpTo`, shuffle on/off, `move`, `removeAt`, `insertAt`, Svuota; **nessun `append`**). Dopo ogni passo si registra l'impronta di `items` + `currentIndex`; l'impronta completa è incollata nel test (valori generati una volta dal codice di oggi).
- Il file **non cambia più** nelle fasi 108–112: è la metrica «comportamento della coda senza aggiunte, impronta identica» (analisi, Metriche di arrivo).
- «Svuota» + Annulla è già fissato in `play_queue_test.dart:313-358`: non si duplica.

### 107.2 — Salvataggio vecchio senza `lastQueueUser` (Rete, riga B)
- `test/services/audio/playback_persistence_test.dart`: un salvataggio senza la chiave `lastQueueUser` (come quelli già sul telefono e nei backup) si ripristina come oggi: stessa coda, stesso corrente, nessun blocco. Pensato per restare verde dopo 108.3 (assente = 0).

### 107.3 — Ricerca di oggi (Rete, riga F, F-142, D-500)
- `test/data/track_repository_test.dart`: un test che fissa la ricerca SQL di oggi (`track_repository.dart:490-497`, `LIKE`): «e» **non** trova «é». Il test è marcato con un commento «cambia in 110.5 (D-500)»: in 110 si rovescia insieme al codice.

### 107.4 — Titolo lungo con «…» (Rete, riga D, F-133)
- Solo se non è già fissato da `test/ui/mini_player_test.dart` e `test/ui/now_playing_test.dart` (controllare prima con `grep -n "ellipsis\|TextOverflow" test/ui/mini_player_test.dart test/ui/now_playing_test.dart`): un test per ciascuno con un titolo molto lungo, che verifica `maxLines: 1` e `TextOverflow.ellipsis` nel player a schermo intero (`now_playing_screen.dart:603`) e nel mini player (`mini_player.dart:154+`). Cambia in 109 (D-486).

### 107.5 — Misure di partenza sul Mi A3 (D-501)
- APK debug sul Mi A3 (`0d7ae9df206e`), poi: `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH python3 scripts/perf_device.py 0d7ae9df206e --label prima-107 --playback` (stima 40 m; con `sorveglia.sh --pesante 40m <log> -- <comando>`).
- Valori in `refactor/coda-e-libreria/misure.md` (file nuovo): tabella «prima-107» con scatti nello scroll e col player aperto (riferimento: fase 90, 1–2 % dei frame oltre 16,7 ms) e `flutter test test/data/performance_50k_test.dart` (tempi di oggi di query e ricerca). Ripulire il telefono e `build/perf/*` già riportati, mai i file musicali.

### 107.6 — Controlli di fase
`flutter analyze`; base verde e comando mirato; `git diff --stat origin/master -- lib` vuoto (solo test e documenti).

**Fatto quando:** la caratterizzazione è verde sul codice di oggi, `misure.md` ha la colonna «prima-107», nessun file di `lib/` è cambiato.

## Da decidere
(nessuno)
