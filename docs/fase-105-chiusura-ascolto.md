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
- 105.1 (2026-11-09): metriche di arrivo tutte rispettate, con comandi e valori in `docs/refactor/ascolto-quotidiano/analisi.md` «Stato finale». La formattazione ha voluto un commit a parte: 162 file toccati dalle fasi 98–104 a larghezza 80, con le graffe negli `if` che vanno a capo. `perf_device.py --only Album` gira da solo: Album build p99 9,8 ms, 1,5 % di frame oltre 16,7 ms.
- 105.2: prova sul Mi A3 contro i mockup, con uiautomator per TalkBack.
  - Corretti:
    - «Impossibile riprodurre» mostrava titolo e motivo scambiati (dalla fase 4; con lui anche i due numeri di `enrichResult`);
    - le cartelle di Memoria si chiamavano «0/Music» e «files/Music»;
    - l'editor del testo accettava `[99:99.99]` come tempo;
    - nella coda la riga di un suggerito esponeva a TalkBack una virgola isolata.
  - Differenze minori accettate:
    - nella daylist con una libreria piccola compaiono «15 brani» e la nota al posto dei 50 del mockup (D-473);
    - il ⋮ di un suggerito della daylist apre solo «Non mi piace»;
    - «Togli» al posto di «Rimuovi» nella pagina «Non mi piace», per coerenza con il resto dell'app.
  - Il confronto visivo non è stato completo schermata per schermata: il contesto della prova è stato compattato a metà. Senza differenze annotate restano artista, coda da Cerca, player del suggerito, testo, Riprendi e Memoria; le loro parti ci sono tutte.
  - Telefono ripulito, salvo il testo di prova rimasto su «Blue In Green».
  - Visto ma rinviato in `prossimi-lavori.md`: circa 77 s di «Caricamento…» dopo un'interruzione di rete (risoluzione yt-dlp, preesistente) e tre etichette TalkBack minori.
- 105.3: review di architettura Opus sul diff 98–104.
  - Corretti con i test:
    - `daylist.json` viene cancellata dalla sostituzione totale del backup, e il suo nome ora sta in un posto solo;
    - il «Non mi piace» dalla daylist passa da `SuggestionActions.dislikeResult`, quindi toglie dalla coda e scrive nel registro;
    - `keyOfStreamPath` toglie il frammento `#cc-ep=`, così l'episodio YouTube Music dello stesso video in due show suona;
    - `episodeUnheardByHand` riattiva il segnalibro.
  - Debito in `prossimi-lavori.md` §6: daylist non salvata con la radio spenta per sempre, avviso «Meno di 15 brani» solo per la fascia in corso, libreria copiata verso l'isolate.
- 105.4: `analisi.md` «Stato finale», `prossimi-lavori.md` §6 (voci chiuse spuntate, debito nuovo), PROGRESS, handoff.
- 105.5: `flutter analyze` pulito, comando mirato verde (256 test), scheggia di fase sul telefono (vedi 105.2).
