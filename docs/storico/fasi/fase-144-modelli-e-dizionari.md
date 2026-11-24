# Fase 144 — Modelli e dizionari

## Obiettivo
Una pagina nelle Impostazioni elenca tutti i modelli e i dizionari scaricabili (20 lingue di traduzione ML Kit, solo Android; dizionario cinese CEDICT; modello karaoke Spleeter) con dimensione e stato, caselle, «Scarica selezionati», «Elimina» e lo spazio occupato. Fuori: nuovi modelli, cambi ai servizi di traduzione o di separazione.

## Riferimenti
D-673, D-662, D-699. Rilievo F-38 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); rete.md riga 144. Mockup: `mockup/modelli-dizionari.html` in `../refactor/grande-revisione/mockup/` (testi e dimensioni del mockup sono inventati: si ricavano dal codice e dagli ARB veri; CEDICT circa 10 MB e karaoke 2×39 MB vanno verificati sul codice). Codice di partenza: `translationLanguages` in `lib/services/online/lyrics_translator.dart` (~4), `lib/services/online/lyrics_translator_mlkit.dart`, `lib/providers/translation_providers.dart`, `lib/providers/chinese_dictionary_providers.dart`, `lib/services/karaoke/separation_service.dart` (~14-22), tile in `lib/ui/screens/settings/translation_models_tiles.dart` e `chinese_dictionary_tile.dart`. Aree: `../architettura/ui-e-design.md`, `online.md`, `piattaforme.md`.

## Task
- [x] 144.1 Catalogo unico dei modelli (F-38; D-673)
  - File: `lib/providers/model_catalog_providers.dart` (nuovo: elenco di voci `kind`, `id`, nome, dimensione stimata, stato installato, `download()`, `delete()`), `lib/providers/translation_providers.dart`, `lib/providers/chinese_dictionary_providers.dart`, `lib/services/karaoke/separation_service.dart` (stato e cancellazione dei due modelli), `test/providers/model_catalog_test.dart` (nuovo).
  - Passi: 1) un provider che unisce le tre fonti (traduzione solo Android; dizionario; karaoke) con servizi sostituibili nei test; 2) spazio totale occupato = somma delle voci installate; 3) test: elenco con dimensioni e totale; scarica ed elimina con servizi finti.
  - Comando mirato: `flutter test test/providers/model_catalog_test.dart test/providers/translation_models_test.dart test/providers/chinese_dictionary_providers_test.dart`
  - Fatto quando: il catalogo conta 20 lingue (su Android), 1 dizionario e il modello karaoke; il totale cambia dopo un'eliminazione.
- [x] 144.2 Pagina «Modelli e dizionari» (F-38; mockup `modelli-dizionari.html`)
  - File: `lib/ui/screens/settings/models_screen.dart` (nuovo), `lib/ui/screens/settings/settings_pages.dart` (voce che apre la pagina, `SettingsPage` ~74), ARB ×6.
  - Passi: 1) elenco a sezioni con caselle, dimensione e stato per voce; 2) «Scarica selezionati» con conferma della dimensione totale (avviso su rete a consumo, come D-656), «Elimina» per voce o selezione; 3) riepilogo dello spazio occupato; 4) accessibilità (48 dp, etichette); 5) sezione traduzione nascosta fuori da Android; 6) test di widget e stringhe con `scripts/arb_add.py`.
  - Comando mirato: `flutter test test/ui/models_screen_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart test/ui/a11y_guidelines_test.dart` (il primo è il test nuovo)
  - Fatto quando: selezionando 2 voci e premendo «Scarica selezionati» i servizi finti ricevono 2 download; «Elimina» aggiorna il totale.
- [x] 144.3 Le tile di oggi rimandano alla pagina (D-673)
  - File: `lib/ui/screens/settings/translation_models_tiles.dart`, `lib/ui/screens/settings/chinese_dictionary_tile.dart`, `test/ui/chinese_dictionary_tile_test.dart`.
  - Passi: 1) le due tile diventano una sola voce «Modelli e dizionari» con il riepilogo; 2) il download dal testo del brano resta com'è; 3) aggiornare `chinese_dictionary_tile_test.dart` (caratterizzazione di oggi) in modo che il comportamento sia coperto dalla pagina nuova.
  - Comando mirato: `flutter test test/ui/chinese_dictionary_tile_test.dart test/ui/settings_index_test.dart test/ui/architecture_test.dart`
  - Fatto quando: in Impostazioni c'è una sola voce per i modelli; nessun test perso.
- [x] 144.4 Area e controllo di fine fase
  - Aggiorna `../architettura/ui-e-design.md` (pagina Modelli e dizionari), `online.md` (catalogo dei modelli), `piattaforme.md` (traduzione solo Android); «Trappole» se serve.

## Tocca a te
- Nessuna cosa in questa fase.

## Note di deviazione
- Coda `_exclusive` in `SeparationService`: download, delete e `ensureModels` uno alla volta; un delete annulla il download in corso.
- D-707: dopo «Elimina» il karaoke non riscarica i modelli da solo (brano in ascolto e prefetch); flag come file segnaposto accanto alla cartella dei modelli (non SharedPreferences: il servizio non le conosce), tolto da un avvio esplicito o da «Scarica».
- La coda di «Scarica selezionati» sta in `modelQueueProvider` (non nello State della pagina); controllo della rete prima di partire e «Annulla».

## Da allineare (review di architettura della fase 143)
- I 30 test `node --test` del Worker (`tools/report-worker/`) non girano in CI: aggiungere un passo in «Analyze and test» (`ci.yml`; node c'è su ubuntu-latest). Il contratto app↔Worker è duplicato (limiti in `lib/core/issue_report.dart` e `tools/report-worker/src/index.js`, codici in `issue_sender.dart`, repo in `kReleaseRepo` e `wrangler.toml`): un test Dart che legge `index.js` e confronta i limiti con le costanti Dart.
