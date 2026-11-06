# Fase 91 — Ordinamenti e foglio playlist (refactor «superfici-e-ricerca»)

**Obiettivo:** più criteri di «Ordina per» in Libreria e dentro le playlist (senza toccare l'ordine manuale) e un unico foglio a schermo intero per «Nuova playlist» e «Aggiungi alla playlist».

**Prerequisiti:** fase 90 chiusa (isola con la riga di Ordina per). Mockup `refactor/superfici-e-ricerca/mockup/libreria.html`, `playlist.html`, `nuova-playlist.html`. Decisioni D-395, D-396, D-397, D-405, D-410, D-411, D-416. Aree a rischio: migrazione drift e `backup_merge` (`code-review high`).

**Comando mirato:** `flutter test test/data/library_entries_test.dart test/data/library_sort_characterization_test.dart test/data/playlist_repository_test.dart test/data/playlist_order_test.dart test/data/backup_merge_test.dart test/services/backup test/ui/library_screen_test.dart test/ui/create_flows_test.dart test/ui/smart_playlists_test.dart test/ui/a11y_guidelines_test.dart test/ui/talkback_labels_test.dart` più i test nuovi (ordinamento playlist, foglio). Test di dettaglio playlist (`playlist_detail`): confermare il nome con `ls test/ui`.

## Task

### 91.1 — Criteri nuovi in Libreria (F-81, D-396, D-410)
- `LibraryEntry` (`library_entries.dart:21-44`) riceve artista, anno, ascolti, durata, numero di brani; comparatore `:127-148` e enum `:8` estesi: Ascoltati di recente, Aggiunti di recente, Titolo A–Z, Artista, Anno, Più ascoltati, Durata, Numero di brani.
- Tasto crescente/decrescente; «Ascoltati di recente» e «Più ascoltati» partono decrescenti; «Numero di brani» solo per playlist e album. Preferenza salvata (`shared_preferences`).
- Foglio «Ordina per» comune (libreria e playlist), ARB it/en/de/es. Test: ogni criterio, verso invertito, pari merito e accenti (resta valido il test della 87), preferenza riletta.

### 91.2 — Ordinamento dentro le playlist (F-82, D-395)
- `playlist_detail_screen.dart:200`: «Ordina per» con i criteri dei brani (`SortOption`, `track_repository.dart:18`, `_orderFor` `:398-418`). Ogni playlist ricorda il suo ordinamento: colonna nuova (o impostazione per playlist) con migrazione drift, `build_runner`, e `backup_merge` + backup/ripristino aggiornati.
- «Ordine personale» = `playlist_tracks.position` invariato, mai riscritto; «Modifica ordine» (`SliverReorderableList`) solo in ordine personale; verso spento lì.
- Test: ordine scelto non tocca `position`; riordino disponibile solo in ordine personale; backup con e senza la colonna (fixture della 87 ripristinata); `playlist_order_test.dart` verde.

### 91.3 — Foglio «Nuova playlist» (F-83, D-405, D-411)
- Foglio a schermo intero dal basso: nome e «Crea» in alto, scorciatoie «Playlist intelligente» e «Importa CSV», sotto le playlist esistenti (il tocco la apre). Sostituisce `NewPlaylistMenu` (`new_playlist_menu.dart:21-57`) e `promptName` (`create_flows.dart:11-16`).
- «Crea» chiude il foglio e apre la playlist nuova. Test: nome vuoto, nome duplicato, scorciatoie; riscrivere `create_flows_test.dart`.

### 91.4 — Foglio per «Aggiungi alla playlist» (D-405, D-411)
- `playlist_dialogs.dart:75-115` (`_AddToPlaylistSheet`) e `create_flows.dart:11` (`createPlaylistFlow`) usano lo stesso foglio: il tocco aggiunge il brano, avvisa e chiude; «già presente» segnalato; le playlist intelligenti non compaiono.
- Test: aggiunta, brano già presente, nuova playlist con il brano dentro, intelligenti assenti.

### 91.5 — Controlli di fase
`flutter analyze`; comando mirato; golden Libreria (foglio Ordina per), playlist e foglio nuovi con `scripts/shots.sh`; review del diff (`code-review high` su migrazione e backup); scheggia (backup della fixture della 87 ripristinato con la colonna nuova; ordine personale intatto dopo cambi di ordinamento); prova sul Motorola (ZY22HKD85K) e sul Mi A3 (0d7ae9df206e) via adb, con ripristino di un backup. Misure `perf_device.py` (Libreria, playlist grande) confrontate con la base della 87 (D-398).

**Fatto quando:** i controlli sopra sono fatti e scritti qui; il backup con la colonna nuova si ripristina.

## Esiti
- **91.1**:
  - otto criteri: Ascoltati di recente, Aggiunti di recente, Titolo A–Z, Artista, Anno, Più ascoltati, Durata, Numero di brani;
  - tasto crescente/decrescente nel foglio comune `sort_sheet.dart`; il verso si vede nella barra (freccia) e nell'etichetta TalkBack;
  - preferenze `librarySort` e `librarySortAscending`;
  - «Numero di brani» non c'è nella scheda Artisti; se era scelto, lì si ripiega su A–Z senza perdere la scelta;
  - Artisti vari, artista sconosciuto e date mancanti vanno in fondo;
  - le somme delle playlist si calcolano in un solo passaggio aggregato, e un brano conta una volta.
- **91.2**:
  - **Scostamento dal documento (D-424)**: niente colonna né migrazione, lo schema resta v15. L'ordinamento di ogni playlist sta nella preferenza `playlistSorts`, che il backup porta in `settings.json`; un ripristino completo da un backup che non la contiene la azzera.
  - L'ordinamento si applica in memoria e in modo stabile, con accenti piegati e mancanti in fondo, e `position` non viene mai riscritto.
  - «Ordine personale» è la voce di serie, con il verso spento; «Modifica ordine» c'è solo lì.
  - Play, shuffle e tocco seguono l'ordine mostrato.
- **91.3–91.4**: un unico foglio a schermo intero, `playlist_sheet.dart`:
  - modalità Nuova: «Crea» apre la playlist nuova, ci sono le scorciatoie «Playlist intelligente» e «Importa CSV», e il tocco su una playlist la apre;
  - modalità Aggiungi: il tocco aggiunge, avvisa e chiude, e «già presente» è segnato sulla riga; le playlist intelligenti non compaiono.
  - Differenza minore dal mockup, accettata: le playlist intelligenti non sono elencate nemmeno in modalità Nuova, perché stanno in una tabella a parte.
- **Review**: `code-review high` (Opus) sulla 91.1, cioè query delle liste e ordinamenti: 10 rilievi, 9 applicati; il decimo era un commento, corretto.
- **Scheggia**:
  - un bug medio corretto con test: un ripristino completo da un backup precedente lasciava gli ordinamenti del dispositivo agganciati ad altre playlist;
  - corretti anche: accenti e mancanti nell'ordinamento delle playlist; tipi sbagliati nelle preferenze, che ora non bloccano l'avvio;
  - 3 mutanti sopravvissuti coperti con test (stabilità su 500 voci; coppie `(trackId, position)` intatte con brani in ordine non alfabetico; marcatore «già presente» sulla riga giusta);
  - sul Mi A3: 8 criteri e verso, ordine personale intatto dopo Titolo crescente e decrescente, fogli corretti; nessuna playlist creata o modificata.
- **Golden**: invariati. Il foglio Ordina per e il foglio playlist non hanno ancora un golden: sono coperti dai widget test e dagli screenshot della scheggia.
- **Misure sul Mi A3**, build profile, % di frame oltre 16,7 ms:
  - Scroll Libreria 0,9 % (base 87: 4,7 %), Lente 1,8–3,8 % (1,9 %), Scroll Tutti i brani 0,9 % (2,3 %).
  - Due giri subito dopo l'installazione avevano dato 7,2 % e 15,6 % su Scroll Libreria, con «1 attività in corso» in background. Bisogna misurare dopo la fine dell'attività.
  - Lo scenario «Libreria Tutto→Playlist→Album→Artisti» con `--only` parte dalla Home e fallisce: si misura solo nel giro completo.
- **Motorola**: rinviato alla fase 97 (D-419, D-420). Sul Mi A3 c'è una playlist «scheggia-46» lasciata da una prova di una fase precedente.
