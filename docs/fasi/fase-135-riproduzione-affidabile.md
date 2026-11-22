# Fase 135 — Riproduzione affidabile

## Obiettivo
Chi ha il permesso audio revocato vede un solo avviso con «Concedi» invece di una raffica di «brano non riproducibile»; la coda ripristinata all'avvio non salta e non fa popup; il karaoke resta acceso alla riapertura, separa solo quando un brano suona e propone di spegnersi dopo 20 minuti di non uso; le correzioni non tentano di scrivere sulle righe in streaming. Fuori: tutto il resto della grande revisione (fasi 136-147).

## Riferimenti
D-662, D-663, D-664, D-678, D-679, D-685, D-686, D-699 (cambia D-66, precisa D-629). Rilievi F-01..F-06 e prove L1-L5 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); rete di test in [`../refactor/grande-revisione/rete.md`](../refactor/grande-revisione/rete.md) (riga 135); dettagli in `scansione-dati.md` (punti 7-9) e `scansione-arricchimento.md` (F7, F8). Aree: `../architettura/riproduzione-e-coda.md`, `piattaforme.md`, `libreria-e-dati.md`. **Area a rischio** (handler audio, `TrackCorrections`): review `/code-review high`.

## Task
- [ ] 135.1 Test di caratterizzazione (rete.md, riga 135)
  - File: `test/services/audio/codecore_audio_handler_test.dart` (errore → brano successivo; contatore azzerato dopo un successo), `test/services/audio/playback_persistence_test.dart` (restore senza play), `test/providers/karaoke_auto_test.dart` (oggi separa il brano ripristinato), `test/services/library/track_corrections_test.dart` (comportamento di oggi su righe stream e file non scrivibili).
  - Passi: 1) scrivere i test che fissano il comportamento di oggi, senza toccare `lib/`; 2) farli passare verdi; 3) committarli da soli (i test che D-679 e D-664 faranno cambiare si aggiornano nel commit del cambio, citando la decisione).
  - Comando mirato: `flutter test test/services/audio/codecore_audio_handler_test.dart test/services/audio/playback_persistence_test.dart test/providers/karaoke_auto_test.dart test/services/library/track_corrections_test.dart`
  - Fatto quando: i quattro file sono verdi su `master` senza modifiche a `lib/`; il commit contiene solo test.
- [ ] 135.2 Permesso audio revocato (F-01; D-678) — review: `/code-review high`
  - File: `lib/core/permissions.dart` (`ensureAudioPermission` chiede `audio` e `storage`: su Android 13+ `storage` è sempre negato; aggiungere `audioPermissionGranted()` che non chiede), `lib/services/audio/just_audio_backend.dart` (`load`, righe ~136-150: `fileMissing`/`unplayable`), `lib/services/audio/codecore_audio_handler.dart` (`PlaybackFailureReason`, righe ~770-772), `lib/providers/player_providers.dart` (stato del permesso).
  - Passi: 1) `ensureAudioPermission` chiede solo il permesso audio giusto per la versione di Android (`READ_MEDIA_AUDIO` da 13, `READ_EXTERNAL_STORAGE` prima); 2) nuovo valore `PlaybackFailureReason.permissionDenied` (in coda all'enum); 3) su un errore di apertura di un file locale l'handler controlla il permesso: se manca, ferma la coda (pausa, niente salto) ed emette un solo evento `permissionDenied`; 4) test: permesso negato → coda ferma e un solo avviso; permesso concesso → comportamento di oggi.
  - Comando mirato: `flutter test test/services/audio/codecore_audio_handler_test.dart test/core/` + `flutter analyze`
  - Fatto quando: il test «permesso negato» passa (una sola notifica, nessun `skipToNext`); nessun altro test dell'handler cambia esito.
- [ ] 135.3 «Concedi»: avviso, banner e Impostazioni (F-02; D-678)
  - File: `lib/ui/shell/app_shell.dart` (ascolto dell'evento `permissionDenied`, un solo snackbar con «Concedi»; controllo al ritorno nell'app con `WidgetsBindingObserver`), `lib/ui/screens/home/` (banner fisso in home finché manca il permesso, un widget nuovo `audio_permission_banner.dart`), `lib/ui/screens/settings/settings_pages.dart` (voce in Impostazioni › Libreria), `lib/providers/folder_actions.dart` (azione «Concedi», con ripiego sulle impostazioni di sistema se il permesso è negato per sempre), ARB ×6.
  - Passi: 1) provider `audioPermissionProvider` aggiornato al resume; 2) snackbar, banner e voce di Impostazioni leggono lo stesso provider; 3) tutte le UI passano dai provider (D-24); 4) stringhe con `python3 scripts/arb_add.py` poi `flutter gen-l10n`; 5) test di widget: banner visibile solo senza permesso, «Concedi» chiama l'azione.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart` + `flutter analyze`
  - Fatto quando: i test di widget passano e `flutter gen-l10n` non lascia diff; l'azione «Concedi» è unica (grep).
- [ ] 135.4 Ripristino senza raffica; limite 3 (F-03; D-679, cambia D-66) — review: `/code-review high`
  - File: `lib/services/audio/codecore_audio_handler.dart` (`_loadCurrent(play:false)` ~530-536, `_failAndSkip` ~1112-1135, `maxConsecutiveErrors` ~93, controllo `>` ~1124), `lib/services/audio/playback_persistence.dart` (`restore`, ~49-75), `lib/ui/shell/app_shell.dart` (~301-306, un popup per errore), `lib/providers/activity_log_providers.dart` (deduplica già presente, ~423).
  - Passi: 1) il ripristino a freddo carica il brano senza salto e senza evento d'errore visibile (nel log sì); 2) il limite diventa 3 davvero (`>=`); 3) gli errori di fila si riuniscono in un solo messaggio «N brani non riproducibili» (ARB ×6, plurale); 4) aggiornare i test di 135.1 toccati dalla deroga, citando D-679 nel commit; 5) test: coda illeggibile → ≤ 3 tentativi, 1 popup (metrica rete.md).
  - Comando mirato: `flutter test test/services/audio/ test/providers/queue_provider_test.dart` + `flutter analyze`
  - Fatto quando: il test «coda illeggibile» conta al massimo 3 tentativi e 1 messaggio; il restore a freddo non avanza.
- [ ] 135.5 Karaoke: separa dopo il play, resta acceso, promemoria (F-05, F-06; D-664, D-685)
  - File: `lib/providers/karaoke_providers.dart` (`karaokeAutoProvider` ~300-440, `pump()` all'avvio; `karaokeInUseProvider` ~185-194), `lib/data/settings/settings_store.dart` (`karaokeOn` ~526, ~622, debounce di 400 ms), `lib/app.dart` (~54, avvio di `karaokeAutoProvider`), `lib/ui/shell/app_shell.dart` (avviso del promemoria), ARB ×6.
  - Passi: 1) `karaokeOn` si scrive subito, senza debounce; 2) `pump()` non separa il brano ripristinato finché non c'è un primo play; 3) timer di 20 minuti con karaoke acceso e `karaokeInUse` falso → un avviso con «Spegni»; 4) test: nessuna separazione prima del play; `karaokeOn` scritto subito (`test/data/settings_store_test.dart`); promemoria con clock finto.
  - Comando mirato: `flutter test test/providers/karaoke_auto_test.dart test/providers/karaoke_providers_test.dart test/data/settings_store_test.dart`
  - Fatto quando: i tre test nuovi passano; con un brano ripristinato e fermo, `separate` non viene chiamato.
- [ ] 135.6 Correzioni e file non scrivibili (F-04; D-686) — review: `/code-review high`
  - File: `lib/services/library/track_corrections.dart` (`_fileWanted` ~218-225, `_fileBlock`, `_prepare`, ~58-60, 244-249), `lib/services/library/track_editor.dart` (~95-98, messaggio dopo il salvataggio), ARB ×6.
  - Passi: 1) `_fileWanted` restituisce falso se `kind == stream`; 2) `_fileBlock` viene valutato prima di `fileIds`; 3) correzioni automatiche su file non scrivibili: solo nel log, non nel Registro; 4) correzioni a mano: il Registro dice perché il file non è cambiato (stream, sola lettura, permesso); 5) test in `test/services/library/track_corrections_test.dart`.
  - Comando mirato: `flutter test test/services/library/ test/providers/track_ops_test.dart`
  - Fatto quando: una correzione su riga stream non produce `unsupported` nel log; con file di sola lettura il Registro riceve la voce solo se la correzione è a mano.
- [ ] 135.7 Area e controllo di fine fase
  - Aggiorna `../architettura/riproduzione-e-coda.md` (motivo `permissionDenied`, politica degli errori D-679, karaoke D-664/D-685; «Trappole»: il limite errori e il restore a freddo), `piattaforme.md` (permesso audio per versione di Android), registro `../decisioni.md` solo se serve una deroga nuova. Prova su telefono rimandata alla 147.

## Tocca a te
- Nessuna cosa in questa fase: la prova sul Motorola (permesso tolto e ridato, riavvio con coda illeggibile) è nella 147. Il permesso `READ_MEDIA_AUDIO` lo concede l'utente dal telefono.

## Note di deviazione
