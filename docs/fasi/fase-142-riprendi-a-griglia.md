# Fase 142 — Home: Riprendi a griglia

## Obiettivo
Il «Riprendi» della home diventa una griglia per macroarea (ultimo brano, podcast, album, playlist, radio, daylist) a 2 colonne sul telefono e 3 su desktop, con riquadri `surface2` raggio 12 e l'icona della macroarea; le nuove uscite vanno in un blocco proprio. La daylist diventa un contesto di riproduzione proprio. Fuori: altre sezioni della home (già sistemate nella 138).

## Riferimenti
D-671, D-689, D-687, D-692, D-693, D-699. Rilievo F-36 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); `scansione-ui.md` (punto 7); rete.md riga 142. Mockup: `mockup/home.html` (griglia a 2 e 3 colonne, riquadri, Nuove uscite) in `../refactor/grande-revisione/mockup/`. Aree: `../architettura/ui-e-design.md`, `riproduzione-e-coda.md`, `libreria-e-dati.md`. Il valore nuovo di `PlayContextKind` finisce in coda all'enum e la serializzazione non cambia (intoccabile: chiavi salvate).

## Task
- [ ] 142.1 `PlayContextKind.daylist` (D-689) — review: `/code-review high` (la coda salvata e l'handler)
  - File: `lib/providers/player_providers.dart` (`enum PlayContextKind`, ~61: nuovo valore **in coda**), `lib/providers/daylist_providers.dart` (~394, oggi parte come `library`), `lib/services/audio/playback_persistence.dart` (serializzazione), `lib/data/db/tables.dart` (`Plays.context`, ~185-200: lettura tollerante di valori sconosciuti), `test/services/audio/playback_persistence_test.dart`.
  - Passi: 1) valore `daylist` aggiunto in fondo; 2) la daylist suona col suo contesto; 3) lettura di un valore sconosciuto da una versione più vecchia → `library`; 4) test: serializzazione stabile (i valori esistenti non cambiano indice) e la daylist suona con `PlayContextKind.daylist`.
  - Comando mirato: `flutter test test/services/audio/playback_persistence_test.dart test/providers/daylist_provider_test.dart`
  - Fatto quando: i test di serializzazione e di contesto passano; nessun indice esistente è cambiato.
- [ ] 142.2 Query «ultimo per macroarea» (F-36; D-671)
  - File: `lib/data/repositories/home_sections.dart` (nuova query; la logica di selezione oggi sta in `lib/ui/screens/home/resume_rows.dart` e in `lib/data/repositories/library_entries.dart`, da portare nel repository per D-24), `lib/data/db/tables.dart` (`Plays.context`/`contextName`, `RadioStations.lastPlayedAt`), `test/data/resume_rows_test.dart`.
  - Passi: 1) una query che restituisce al massimo un elemento per macroarea (ultimo brano, podcast, album, playlist, radio, daylist), dai `Plays` e da `RadioStations.lastPlayedAt`; 2) coda e brani lunghi da riprendere entrano nella griglia (D-671); 3) test con dati di prova: l'ultimo per macroarea, macroaree vuote assenti.
  - Comando mirato: `flutter test test/data/resume_rows_test.dart`
  - Fatto quando: il test restituisce esattamente un elemento per macroarea presente.
- [ ] 142.3 Griglia del Riprendi (F-36; mockup `home.html`)
  - File: `lib/ui/screens/home/resume_rows.dart` (~57-185, mostra oggi 4 righe), `lib/ui/screens/home/home_row.dart` (`HomeBlock(header:)` dalla 138), `lib/providers/` (provider della griglia), ARB ×6.
  - Passi: 1) griglia a 2 colonne sul telefono e 3 su desktop (soglia di larghezza); 2) riquadro `surface2`, raggio 12, icona della macroarea, titolo, sottotitolo; accessibile (≥ 48 dp, etichette); 3) tocco: riprende l'elemento (la daylist con il suo contesto); 4) test sulla larghezza (2 e 3 colonne) e sul tocco.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/home_test.dart test/ui/a11y_guidelines_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: a 400 dp ci sono 2 colonne, a 1200 dp 3 (test sulla larghezza); i riquadri rispettano i 48 dp.
- [ ] 142.4 Nuove uscite in un blocco proprio (D-671; mockup `home.html`)
  - File: `lib/ui/screens/home/resume_rows.dart` (parte «nuove uscite»), `lib/ui/screens/home/home_bottom_rows.dart`, `lib/ui/screens/home/home_blocks.dart`.
  - Passi: 1) le nuove uscite diventano un `HomeBlock` con intestazione dentro, separato dalla griglia; 2) golden `home`; 3) test: il blocco compare solo se ci sono uscite.
  - Comando mirato: `flutter test test/ui/home_screen_test.dart test/ui/home_test.dart` più i golden (`desktop_100_home.png`)
  - Fatto quando: golden `home` rivisto; il blocco non compare senza uscite.
- [ ] 142.5 Area e controllo di fine fase
  - Aggiorna `../architettura/ui-e-design.md` (griglia del Riprendi, Nuove uscite), `riproduzione-e-coda.md` (`PlayContextKind.daylist`, formato stabile), `libreria-e-dati.md` (query «ultimo per macroarea»); «Trappole»: nuovi valori di `PlayContextKind` solo in coda.

## Tocca a te
- Nessuna cosa in questa fase.

## Note di deviazione
