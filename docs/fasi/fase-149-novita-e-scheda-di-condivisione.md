# Fase 149 — Novità dell'aggiornamento e scheda di condivisione

## Obiettivo
Chi aggiorna vede cosa c'è di nuovo, scritto per chi usa l'app e non come elenco di PR: una pagina «Aggiornamento disponibile» al posto del dialogo e, una volta sola, «Aggiornata alla X» al primo avvio. «Condividi» manda una scheda (immagine con QR) invece del solo testo. Fuori: novità tradotte (solo italiano, D-711), anteprima prima di condividere (D-712).

## Riferimenti
D-711, D-712, D-677, D-702, D-656, D-541, D-692. Mockup: [`../feature/mockup-aggiornamento-novita.html`](../feature/mockup-aggiornamento-novita.html). Architettura: `../architettura/qualita-e-rilascio.md` (aggiornamento dall'app, release), `../architettura/online.md` (condivisione), `../architettura/ui-e-design.md`.
Codice: `UpdateDialog`, `updateSnackBar`, `updateTiles` (`lib/ui/screens/settings/update_tiles.dart`), `UpdateChecker`/`UpdateInfo.notes` (`lib/services/online/update_checker.dart`), `updateDownloadProvider` (`lib/providers/update_providers.dart`), Impostazioni › Informazioni (`lib/ui/screens/settings/settings_pages.dart`), `ExternalShareActions.share` (`lib/providers/external_share_actions.dart`), `buildShareText` (`lib/services/share/external_share_text.dart`), `ExternalShare.shareFile`, disegno fuori schermo come in `lib/services/theme/background_image.dart`, `qr_flutter` (già nelle dipendenze), `.github/workflows/release.yml` (job `publish`).

## Task
- [ ] 149.1 Novità: formato, lettura e release
  - File: `lib/services/update/release_notes.dart` (nuovo), `release-notes/` (nuova cartella, un file `<versione>.md` per release), `.github/workflows/release.yml`, test in `test/services/update/`.
  - Passi: 1) formato del blocco: `## Novità` con righe `- [evidenza |] <icona> | <titolo> | <testo>` e `## Correzioni` con righe `- <testo>`; icone da un elenco fisso di nomi (mappati su icone Material, nome sconosciuto → icona generica); tutto il resto del corpo (il «What's Changed» di GitHub) ignorato; 2) `parseReleaseNotes(body)` → evidenza (al massimo una), novità, correzioni; vuoto se il blocco manca o è malformato (mai eccezioni); 3) nel job `publish`: `body_path: release-notes/<versione>.md` insieme a `generate_release_notes` (il blocco va in cima) e il job fallisce se il file della versione del tag manca; 4) la regola «prima del tag si scrive `release-notes/<versione>.md`» in `qualita-e-rilascio.md`.
  - Comando mirato: `flutter test test/services/update/release_notes_test.dart`
  - Fatto quando: il corpo della 1.7.0 di oggi (solo «What's Changed») dà novità vuote; un corpo col blocco dà evidenza, righe e correzioni giuste; righe rotte saltate.
- [ ] 149.2 Pagina «Aggiornamento disponibile»
  - File: `update_tiles.dart` (il dialogo diventa la pagina, o un file nuovo `update_page.dart` accanto), widget delle novità condiviso con 149.3, ARB (6 lingue: testi fissi dell'interfaccia; le novità restano in italiano), test in `test/ui/update_tiles_test.dart`.
  - Passi: 1) telefono: foglio a tutto schermo con anello e versione, «dalla X», evidenza con illustrazione, novità con icona, «Correzioni (N)» chiuso, «Tutte le modifiche su GitHub», pulsante fermo in basso «Aggiorna · N MB» con la frase di cosa succede; 2) largo (≥ 840 px): dialogo a due colonne (a sinistra versione e pulsante, a destra le novità); 3) download: il pulsante diventa la barra con «N di M MB» e «Annulla», stessi stati e azioni di oggi (permesso, firma diversa, browser per .deb/Flatpak/zip/macOS); 4) senza blocco: versione + «Correzioni e miglioramenti» + link; 5) «Controlla aggiornamenti» (in controllo, aggiornata, limite, errore) e l'avviso all'avvio aprono la nuova pagina; 6) TalkBack: titolo e sezioni intestazioni, ogni novità una fermata, il pulsante annuncia il peso.
  - Comando mirato: `flutter test test/ui/update_tiles_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: con un `UpdateInfo` col blocco la pagina mostra evidenza, novità e correzioni; con le note di GitHub non compare nessuna riga «feat(…)»; tutti gli stati del download di oggi restano raggiungibili.
- [ ] 149.3 «Aggiornata alla X» al primo avvio e in Impostazioni
  - File: preferenze (`settingsStoreProvider` o equivalente: ultima versione vista e note salvate per versione), avvio dell'app (dove oggi parte il controllo all'avvio), `settings_pages.dart` (Informazioni › «Novità della versione»), backup (le due chiavi escluse), test.
  - Passi: 1) quando un controllo trova una versione nuova, se ne salvano le note (per versione); 2) all'avvio: versione in uso > ultima vista → pagina «Aggiornata alla X» (anello con la spunta, «libreria, playlist e impostazioni sono dove le avevi lasciate», novità, «Inizia», «Tutte le novità» → GitHub), poi ultima vista = in uso; note mancanti (aggiornata da fuori) → una lettura di `releases/tags/v<versione>`, offline o senza blocco → niente pagina; 3) prima installazione (nessuna chiave e nessun dato dell'app) → niente pagina; aggiornamento da una versione senza la chiave → pagina; ripristino da backup → niente pagina; 4) Impostazioni › Informazioni › «Novità della versione» riapre la pagina.
  - Comando mirato: test del provider/servizio nuovo + `flutter test test/ui/` mirati.
  - Fatto quando: i quattro casi (aggiornamento, prima installazione, versione senza chiave, ripristino) danno il risultato scritto; la pagina compare una volta sola.
- [ ] 149.4 Scheda di condivisione
  - File: `lib/ui/widgets/share_card.dart` (nuovo: brano con l'anello, album con la copertina, playlist col mosaico), servizio che la disegna fuori schermo in PNG 1080 × 1350 nella cartella `freekmusic_share` di oggi, `external_share_actions.dart`, `external_share_text.dart` (didascalia corta), test.
  - Passi: 1) scheda: marchio, tipo, copertina (o mosaico delle prime 4), titolo, sottotitolo, «N brani · durata», QR (`qr_flutter`) del link della pagina che lo scanner di oggi apre; sfondo dai colori della copertina come il player; senza copertina l'anello con l'iniziale sull'accento; 2) copertine già caricate prima di disegnare (niente scheda con buchi), tempo massimo e, se scade o il disegno fallisce, il testo di oggi (log con `AppLog`); 3) `shareFile(png, text: didascalia)` con la didascalia corta (nome + link della pagina); 4) invariati: oltre 50 brani il .m3u8, Linux appunti, Windows vecchio appunti; brani solo locali: scheda senza QR e senza link; 5) disegno e I/O fuori dal thread UI dove possibile.
  - Comando mirato: `flutter test test/services/share/ test/providers/external_share_actions_test.dart` + i test della scheda.
  - Fatto quando: per brano, album e playlist si condivide un PNG con la didascalia corta; il QR decodificato è il link della pagina; un errore nel disegno ricade sul testo.
- [ ] 149.5 Prova sui telefoni di test e documenti
  - Passi: 1) Mi A3 e Redmi: pagina delle novità (con un `release-notes` di prova via override di debug) a 360 px e in orizzontale, TalkBack con uiautomator; 2) «Condividi» di brano, album, playlist fino al foglio di sistema (senza inviare); il PNG salvato si apre e il QR si legge con lo scanner dell'altro telefono; 3) documenti d'area aggiornati.
  - Fatto quando: esito scritto qui sotto.

## Tocca a te
- [ ] Prima del tag della prossima versione: scrivere (o approvare) `release-notes/<versione>.md`.

## Note di deviazione
