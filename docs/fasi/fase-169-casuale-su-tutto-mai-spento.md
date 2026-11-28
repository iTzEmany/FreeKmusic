# Fase 169 — «Casuale su tutto» mai spento

## Obiettivo
Il pulsante del casuale della Home («Casuale su tutto», `ShuffleHero`) passa solo tra Casuale e Casuale+. Per la coda che ha avviato il blocco
vale ovunque (player intero, barra desktop, MPRIS) e anche dopo un riavvio. ▶ parte su Casuale. Con Casuale+ impossibile (Jam, libreria
piccola) il pulsante resta su Casuale e spiega il motivo a ogni tocco. Le altre liste girano spento → Casuale → Casuale+ come oggi (D-534).

## Riferimenti
Refactor `../refactor/karaoke-casuale/analisi.md` (F-09..F-15, «Scelte», «Direzione», «Rete»). Decisioni del refactor «karaoke-casuale» in
`../decisioni.md`: «Casuale su tutto» mai spento (supera in parte D-72, D-137, D-369), Casuale+ non possibile, struttura, intoccabili.
Architettura: `../architettura/riproduzione-e-coda.md` («Shuffle e ripetizione»). Prerequisito: fase 167. Indipendente dalla 168.
Attenzione: la fase 162 (refactor «playlist-aggiungi-e-casuale», D-749/D-750) cambia anche `ListShuffle` e `list_shuffle_test.dart`; se è già
fatta, il predefinito di `libraryListKey` va nello stesso percorso di lettura per chiave; se non lo è, la 162 deve tenerne conto (nota nelle
deviazioni di chi arriva secondo).
Codice: `ShuffleHero` (`lib/ui/**/home_blocks.dart:60-88`), `ShuffleModeButton`/`_cycleWithNotice`/`_explained` (`lib/ui/**/shuffle_button.dart:14-52`),
`isPlayingList` (`player_providers.dart:158-163`), `_start` (:239-240), `toggleShuffle` (:620-624), `cycleListShuffle`/`_cycleList` (:629-680),
`cycleShuffle`/`_cycleShuffle` (:683-712), `plusAllowedNow` (:742), `ListShuffle` (`shuffle_plus_providers.dart:440-459`),
`PlaybackPersistence` (:64-69, 140-150), MPRIS (`mpris_controls.dart:198`), `setShuffleMode` del handler (`codecore_audio_handler.dart:2143`).

## Task
- [ ] 169.1 Una sola funzione decide il modo successivo
  - File: nuovo `lib/services/shuffle_plus/next_shuffle_mode.dart` (`nextShuffleMode(current, {required bool plusAllowed, required bool neverOff})`),
    `player_providers.dart` (`_cycleList`, `_cycleShuffle`, ramo di `toggleShuffle`), test a tabella nuovo.
  - Passi: 1) funzione pura; 2) i due cicli la usano con `neverOff: false`; nessun cambio di comportamento.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/services/shuffle_plus`
  - Fatto quando: i test della 167.2 verdi senza modifiche; nessuna transizione di `ShuffleMode` fuori da `nextShuffleMode` in `player_providers.dart`.
- [ ] 169.2 Blocco sulla Home e sulla sua coda
  - File: `player_providers.dart` (coda bloccata = `isPlayingList(libraryListKey)`; `cycleShuffle`, `cycleListShuffle(libraryListKey)` e
    `toggleShuffle` passano `neverOff: true` e non spengono mai), `shuffle_plus_providers.dart` (`ListShuffle`: predefinito Casuale per
    `libraryListKey`, uno spento salvato si legge come Casuale), `shuffle_button.dart` (con blocco attivo l'avviso di Casuale+ bloccato esce a
    ogni tocco), test in `list_shuffle_test.dart`, `shuffle_button_test.dart`, `home_screen_test.dart`, `talkback_labels_test.dart` se l'etichetta cambia.
  - Passi: 1) Home: Casuale ↔ Casuale+; Casuale+ bloccato → resta Casuale con l'avviso a ogni tocco; 2) player intero e barra desktop sulla coda
    della Home: stesso giro; coda di un'altra lista: giro di oggi; una nuova coda toglie il blocco; 3) ▶ della Home parte su Casuale;
    4) aggiornare apposta `home_screen_test.dart` :114-146, :148-170, :199-206, :211-223 e i casi di `list_shuffle_test.dart` :176-278 con
    `libraryListKey` che si aspettano spento.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/list_shuffle_test.dart test/ui/shuffle_button_test.dart test/ui/home_screen_test.dart test/ui/talkback_labels_test.dart`
  - Fatto quando: test verdi; i test della 167.2 sulle altre liste verdi senza modifiche.
- [ ] 169.3 MPRIS segue il blocco
  - File: `mpris_controls.dart` (il setter `Shuffle` chiama `PlayerController` invece di `_h.setShuffleMode`, e ripubblica lo stato se lo
    spegnimento è rifiutato), il punto che costruisce `MprisControls`, test a livello di `PlayerController` in `list_shuffle_test.dart`
    (`mpris_controls_test.dart` salta senza bus D-Bus).
  - Passi: 1) `Shuffle=false` sulla coda della Home non spegne; su un'altra coda spegne e toglie anche Casuale+ come `toggleShuffle`;
    2) test dei due casi.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/providers/list_shuffle_test.dart test/services/audio/mpris_controls_test.dart`
  - Fatto quando: test verdi; `grep -n "setShuffleMode" lib/services/**/mpris_controls.dart` vuoto.
- [ ] 169.4 Il blocco sopravvive al riavvio
  - File: `playback_persistence.dart` (preferenza stringa con la chiave della lista accanto a `lastContextKind`, scritta solo per
    `libraryListKey`, cancellata per ogni altra coda; ripristino), `player_providers.dart` (`_listKey`/`_listKeySource` ripristinati), la
    scorciatoia di `shuffle_plus_providers.dart:455-459` (togliere o aggiornare il commento), `playback_persistence_test.dart`, `list_shuffle_test.dart`.
  - Passi: 1) salvare e ripristinare la chiave; nessun valore nuovo in `PlayContextKind`, nessuna migrazione; 2) test: dopo il ripristino della
    coda della Home il pulsante del player non spegne; la coda ripristinata di un'altra lista sì.
  - Comando mirato: `~/.claude/scripts/isolate.sh flutter test test/services/audio/playback_persistence_test.dart test/providers/list_shuffle_test.dart`
  - Fatto quando: test verdi; `flutter analyze` pulito.
- [ ] 169.5 Documenti e chiusura del refactor
  - File: `../architettura/riproduzione-e-coda.md` («Shuffle e ripetizione»: giro unico, blocco della Home, MPRIS, chiave salvata),
    `../prossimi-lavori.md`, `../handoff.md`.
  - Passi: aggiornare i documenti; confrontare i criteri di «Rete» dell'analisi (comandi mirati verdi, una sola funzione del giro, una sola regola
    karaoke se la 168 è fatta).
  - Comando mirato: `flutter analyze`
  - Fatto quando: documenti aggiornati; criteri di «Rete» rispettati.

## Tocca a te
Niente. A fine fase la prova sul telefono la fa l'agente via `~/.claude/scripts/device.sh`, a volume 0: «Casuale su tutto» dalla Home, il pulsante del player non spegne il casuale; riavvio dell'app e stessa prova.

## Note di deviazione
