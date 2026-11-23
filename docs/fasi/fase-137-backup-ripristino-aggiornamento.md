# Fase 137 — Backup, ripristino, aggiornamento

## Obiettivo
«Sostituisci» riavvia davvero l'app (Android e desktop); la sezione Backup dice cosa contiene, offre Esporta/Importa playlist e, dopo «Unisci», elenca i brani non trovati con «Salva in streaming»; il popup della nuova versione si apre con un tocco ovunque e un controllo fallito non consuma la giornata. Fuori: formato del backup (invariato), sync fra dispositivi (146).

## Riferimenti
D-680, D-681, D-682, D-662, D-699. Rilievi F-07, F-08, F-09, prova L7 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); `scansione-dati.md` (punti 1, 2, 5); rete.md riga 137. Aree: `../architettura/sync-backup-jam.md`, `piattaforme.md`, `online.md`. **Area a rischio** (backup e ripristino): review `/code-review high`; il canale nativo è codice Android (manifest e processo): review Opus. Il riavvio riusa `DesktopUpdate` (`lib/services/update/desktop_update.dart`).

## Task
- [x] 137.1 Test di caratterizzazione (rete.md, riga 137)
  - File: `test/services/backup/restore_service_test.dart`, `test/data/backup_merge_test.dart`, `test/services/backup/backup_service_test.dart` (le playlist sono nello zip), `test/ui/update_tiles_test.dart`.
  - Passi: 1) fissare il comportamento di oggi (stage del ripristino, merge che salta i brani non riconosciuti, playlist nel backup); 2) verdi; 3) commit di soli test.
  - Comando mirato: `flutter test test/services/backup/ test/data/backup_merge_test.dart test/ui/update_tiles_test.dart`
  - Fatto quando: verdi senza modifiche a `lib/`; commit separato.
- [x] 137.2 Riavvio nativo su Android (F-07; D-680) — review Opus (processo e servizi)
  - File: `android/app/src/main/kotlin/com/codecore/player/RestartChannel.kt` (nuovo: ferma i servizi, `getLaunchIntentForPackage`, `killProcess`), `MainActivity.kt` (registrazione), `lib/services/restart/app_restart.dart` (nuovo: interfaccia Dart con il canale `codecore/restart`).
  - Passi: 1) il canale ferma `audio_service` e gli altri servizi in primo piano; 2) avvia l'intent di lancio con `FLAG_ACTIVITY_NEW_TASK|CLEAR_TASK`; 3) termina il processo; 4) lato Dart un'interfaccia che i test sostituiscono con un finto.
  - Comando mirato: `flutter test test/services/restart/` + `flutter build apk --debug` (con `~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 8m`)
  - Fatto quando: il test lato Dart (canale assente → ripiego «chiudi e riapri») passa e l'APK di debug compila.
- [x] 137.3 Riavvio su desktop e dialogo (F-07; D-680)
  - File: `lib/services/update/desktop_update.dart` (righe ~42, ~60: `Process.start` staccato + `exit(0)`, da riusare per rilanciare l'eseguibile o l'AppImage), `lib/services/restart/app_restart.dart`, `lib/ui/screens/settings/backup_section.dart` (~107-117, oggi `SystemNavigator.pop()`), `lib/providers/backup_ops.dart` (~46), `lib/main.dart` (~117, `applyPendingRestore`), ARB ×6 («L'app si riavvia»).
  - Passi: 1) dopo `stageFullRestore` il dialogo dice che l'app si riavvia e chiama `AppRestart`; 2) Android: canale di 137.2; desktop: rilancio di `Platform.resolvedExecutable` o `$APPIMAGE`; 3) se il riavvio non è possibile (Flatpak, errore) il dialogo ripiega sul testo «chiudi e riapri»; 4) test con esecutore di processi finto.
  - Comando mirato: `flutter test test/services/update/desktop_update_test.dart test/services/restart/ test/providers/backup_providers_test.dart test/ui/architecture_test.dart`
  - Fatto quando: dopo «Sostituisci» viene chiamato il riavvio (test sull'effetto: processo finto avviato con gli argomenti giusti); il ripiego compare se fallisce.
- [x] 137.4 Sezione Backup: cosa contiene, Esporta/Importa playlist (F-08; D-681)
  - File: `lib/ui/screens/settings/backup_section.dart` (~20-30), `lib/ui/screens/playlists/export_dialog.dart` e `lib/ui/screens/import/import_flow.dart` (da richiamare dalla sezione), `lib/ui/screens/playlists/playlists_screen.dart` (~28), ARB ×6.
  - Passi: 1) testo che elenca cosa porta il backup (libreria, playlist, preferiti, impostazioni, ...); 2) due voci «Esporta playlist» e «Importa playlist» che aprono i flussi esistenti (un solo punto di ingresso, senza duplicare la logica); 3) test di widget.
  - Comando mirato: `flutter test test/ui/settings_and_playlists_test.dart test/ui/restore_dialog_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: la sezione Backup mostra le due voci e il testo, ognuna apre il flusso esistente.
- [x] 137.5 «Unisci»: elenco dei non trovati con «Salva in streaming» (F-08; D-681) — review: `/code-review high`
  - File: `lib/data/repositories/backup_merge.dart`, `backup_merge_tables.dart`, `lib/providers/backup_ops.dart` (~60-80), `lib/services/backup/track_resolver.dart`, `lib/ui/screens/settings/restore_dialog.dart`, `lib/providers/library_add_providers.dart` (`LibraryAdder.add/saveNow` per salvare in streaming), ARB ×6.
  - Passi: 1) `mergeBackup` restituisce i non trovati con titolo, artista e, se c'è, `videoId`; 2) dopo «Unisci» il dialogo li elenca; 3) «Salva in streaming» per riga o per tutti, via `LibraryAdder`; 4) «Cerca online» per quelli senza `videoId`; 5) test: N non trovati → lista di N.
  - Comando mirato: `flutter test test/data/backup_merge_test.dart test/data/backup_merge_tables_test.dart test/services/backup/ test/providers/backup_ops_romanization_test.dart`
  - Fatto quando: un backup con N brani non trovati produce una lista di N; le playlist già presenti restano com'erano.
- [x] 137.6 Popup della nuova versione (F-09; D-682)
  - File: `lib/ui/screens/settings/update_tiles.dart` (~33-46, `updateSnackBar`), `lib/providers/update_providers.dart` (~49-58, `lastUpdateCheckDay`), `lib/app.dart`.
  - Passi: 1) tocco sul corpo dello snackbar apre `UpdateDialog` (stessa azione di «Aggiorna»); 2) `lastUpdateCheckDay` si scrive dopo un controllo riuscito; 3) test di widget e di provider.
  - Comando mirato: `flutter test test/ui/update_tiles_test.dart test/providers/update_providers_test.dart`
  - Fatto quando: il test «tocco ovunque» apre il dialogo; con un controllo fallito `lastUpdateCheckDay` non cambia.
- [x] 137.7 Area e controllo di fine fase
  - Aggiorna `../architettura/sync-backup-jam.md` (riavvio dopo «Sostituisci», lista dei non trovati), `piattaforme.md` (canale `codecore/restart`), `online.md` (popup aggiornamento); «Trappole»: `SystemNavigator.pop()` non chiude il processo. Rilascio intermedio 1.6.5 fuori piano (D-699).

## Tocca a te
- Nessuna cosa in questa fase: la prova di «Sostituisci» con processo nuovo e del popup è nella 147. Prima di quella prova sul Motorola serve un backup completo fatto dall'utente dall'app.

## Note di deviazione
- 137.2: riavvio Android da `RestartActivity` nel processo `:restart` (schema ProcessPhoenix), non `startActivity`+kill nello stesso processo (review Opus: app chiusa sui telefoni veloci); nessuno `stopService`. `applyPendingRestore` sposta anche `-journal` col DB vecchio.
- 137.5: niente «Salva in streaming»: il backup non porta un videoId per i brani locali e un brano in streaming si ricrea sempre; restano «Cerca online» (copia prima l'elenco) e «Copia elenco». I non trovati comprendono le voci delle playlist.
- 137.3: `BackupOps.restartAfterRestore` chiude il DB prima del riavvio (Windows: rename di un file aperto).
