# Fase 152 — Token e componenti comuni

## Obiettivo
Le fondamenta del refactor: un token cambiato (`textMuted`), un'intestazione di sezione ad altezza fissa, una sola tabella azione → icona → testo, stati vuoti uguali ovunque, titoli di sezione standard. Le fasi 153-157 ci poggiano. Il telefono cambia solo dove scritto.

## Riferimenti
D-716, D-730, D-731. Refactor: [`analisi.md`](../refactor/desktop-e-coerenza/analisi.md) (F-01..F-05, F-12, F-13, F-14, F-18, F-19, F-20, F-119), [`scansione-telefono.md`](../refactor/desktop-e-coerenza/scansione-telefono.md). Mockup: [`index.html`](../refactor/desktop-e-coerenza/mockup/index.html) (tabella azioni, token), [`telefono-azioni.html`](../refactor/desktop-e-coerenza/mockup/telefono-azioni.html), `tokens.css` nella stessa cartella. Regole: `../01-regole-di-lavoro.md` (ARB in 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`). Architettura: `../architettura/ui-e-design.md`.
Codice: `lib/ui/theme/tokens.dart` (`textMuted` oggi `0xFFA79DB8`), `lib/ui/widgets/section_header.dart`, `lib/ui/widgets/empty_state.dart`, `lib/ui/widgets/track_actions.dart`, `lib/ui/widgets/bulk_actions.dart`, `lib/ui/widgets/track_row.dart`.

## Task
- [ ] 152.1 Caratterizzazione dei componenti toccati
  - File: `test/ui/section_header_test.dart` (nuovo), `test/ui/track_actions_test.dart`, `test/ui/online_song_row_test.dart`.
  - Passi: 1) `SectionHeader` con e senza `actionLabel`: titolo, «Tutti» che chiama la callback; 2) le azioni del foglio brano (coda, libreria, scarica, condividi) esistono con la semantica di oggi; 3) i test sono su comportamento, non su icone o px.
  - Comando mirato: `flutter test test/ui/section_header_test.dart test/ui/track_actions_test.dart test/ui/online_song_row_test.dart`
  - Fatto quando: verdi senza toccare `lib/`.
- [ ] 152.2 Token `textMuted` (D-730)
  - File: `lib/ui/theme/tokens.dart`, test dei contrasti in `test/ui/a11y_guidelines_test.dart` o un test dei token.
  - Passi: 1) `textMuted` `#A79DB8` → `#B3AAC2`; nessun altro token cambia, fondo sempre indaco, nessuna tinta dalla copertina; 2) test: contrasto di `textMuted` su `surface1/2/3` ≥ 6,8:1 e testo ≥ 13,4:1; 3) controlla che nessun altro punto del codice usi `0xFFA79DB8` a mano.
  - Comando mirato: `flutter test test/ui/a11y_guidelines_test.dart` + `flutter analyze`
  - Fatto quando: `grep -rn A79DB8 lib` è vuoto e i contrasti scritti sono verificati dal test.
- [ ] 152.3 `SectionHeader` ad altezza fissa (F-13, F-14, F-20)
  - File: `lib/ui/widgets/section_header.dart`, `lib/ui/screens/home/home_blocks.dart`, `home_bottom_rows.dart`, `home_row.dart`, `lib/ui/screens/daylist/daylist_card.dart`, `lib/ui/screens/releases/top_artists_card.dart`, ARB (`showAll` resta; nessun testo nuovo se non serve).
  - Passi: 1) altezza fissa (il «Tutti» non alza più l'intestazione: niente `TextButton` da 48 dp che spinge); 2) «Tutti» sempre nell'intestazione dove c'è un elenco completo, mai come riga a sé (la riga di `home_blocks.dart` e il pulsante di `home_bottom_rows.dart` passano a `SectionHeader(actionLabel: l.showAll)`); 3) spazio uguale sopra e sotto ogni blocco: costanti in `tokens.dart` (24 dp telefono, 32 px desktop) al posto di 8/12/16/24 sparsi in `home_row.dart`, `daylist_card.dart`, `top_artists_card.dart`; 4) il filtro di `library_filter_bar.dart` che usa `showAll` non cambia.
  - Comando mirato: `flutter test test/ui/section_header_test.dart test/ui/home_screen_test.dart test/ui/home_test.dart`
  - Fatto quando: un test misura che l'intestazione ha la stessa altezza con e senza «Tutti» e che sopra e sotto c'è lo stesso spazio.
- [ ] 152.4 Tabella azione → icona → testo (F-01..F-05, F-12)
  - File: nuovo `lib/ui/widgets/action_catalog.dart` (costanti), `track_actions.dart`, `bulk_actions.dart`, `track_row.dart`, `lib/ui/screens/online/online_album_screen.dart`, `online_playlist_screen.dart`, `online_song_row.dart`, `lib/ui/screens/library/album_detail_screen.dart`, `lib/ui/screens/jam/jam_queue_sheet.dart`, `now_playing_screen.dart`, `widgets/collection_header.dart`, ARB.
  - Passi: 1) un file con le costanti (icona + chiave ARB) come nella tabella di `mockup/index.html` e `telefono-azioni.html`: coda ≠ libreria (libreria = segnalibro con «+», coda = «riproduci dopo»); Esporta (salva file) ≠ Condividi; ⋮ sempre `moreActions`; `queue_music_rounded` solo per la coda; 2) ogni punto citato da F-01..F-05 e F-12 usa la costante; `ytmAlbumQueue` e simili spariscono dal ARB se restano duplicati; 3) testi nuovi in 6 lingue con `scripts/arb_add.py`, poi `flutter gen-l10n`; 4) un test sulla tabella: le costanti hanno icone tutte diverse.
  - Comando mirato: `flutter test test/ui/track_actions_test.dart test/ui/online_song_row_test.dart test/ui/collection_pages_test.dart test/ui/online_pages_test.dart` + `flutter analyze`
  - Fatto quando: `grep -rn "library_add_rounded\|Icons.queue_rounded" lib` trova solo il catalogo; il test di unicità passa.
- [ ] 152.5 `EmptyState` ovunque e titoli di sezione (F-18, F-19, F-119 parte comune)
  - File: `lib/ui/widgets/empty_state.dart` (il parametro `icon` oggi è ignorato: lo si usa), `lib/ui/screens/lyrics/lyrics_screen.dart`, `lib/ui/screens/cleanup/album_merge_dialog.dart`, `lib/ui/screens/settings/merged_artists_screen.dart`, `lib/ui/screens/jam/speaker_sheets.dart`, `lib/ui/screens/smart/smart_filter_widgets.dart`, `lib/ui/screens/online/merged_profiles.dart`.
  - Passi: 1) `EmptyState` mostra icona, testo e azione opzionale (stesso aspetto telefono/desktop); 2) i `Center(Text)` vuoti diventano `EmptyState`; 3) i titoli di sezione fuori standard usano `SectionHeader` o una variante compatta nello stesso file; 4) le pagine desktop vuote (Cronologia, Etichette, Artisti seguiti, Preferiti) si completano nella 157.
  - Comando mirato: `flutter test test/ui/` per i file toccati (`lyrics`, `merge`, `settings`) + `flutter analyze`
  - Fatto quando: `grep -rn "Center(child: Text" lib/ui/screens/lyrics lib/ui/screens/cleanup` non trova più stati vuoti; un test verifica icona + testo + azione di `EmptyState`.
- [ ] 152.6 Goldens, guardie, documenti
  - Passi: 1) `flutter test --update-goldens test/goldens` (solo Linux), controlla a occhio il diff di ogni PNG cambiato, una sola rigenerazione per la fase; 2) `scripts/guardie.sh`; 3) `ui-e-design.md`: token, `SectionHeader`, catalogo azioni.
  - Comando mirato: `flutter test test/goldens` + `scripts/guardie.sh`
  - Fatto quando: goldens verdi dopo la rigenerazione, guardie verdi.

## Tocca a te
Niente.

## Note di deviazione
