# Fase 103 — Testi a mano, sincronia spegnibile, Memoria

**Obiettivo:** scrivere o incollare un testo, spegnere la sincronia per un brano, vedere le copertine delle playlist in Memoria e aprire le cartelle nel file manager. **Cambi di comportamento voluti** (D-432, D-441, D-451).

**Prerequisiti:** fase 102 chiusa. Analisi F-108..F-111. Mockup approvati: `refactor/ascolto-quotidiano/mockup/testo.html`, `refactor/ascolto-quotidiano/mockup/memoria.html`. Aree a rischio: backup (`unsyncedLyrics`, `/code-review high`).

**Comando mirato:** `flutter test test/ui/lyrics_editor_test.dart test/services/lyrics/ test/data/settings_store_test.dart test/services/backup/ test/data/memory_queries_test.dart test/services/files/folder_opener_test.dart`

## Task

### 103.1 — Scrivi o incolla un testo (F-110)
- Pulsante «Scrivi o incolla» accanto a «Cerca testo» (`lyrics_view.dart`) e voce «Modifica testo» nel menu della schermata del testo (`lyrics_screen.dart`, D-451). Editor come nel mockup: un testo con tempi LRC (`[mm:ss.xx]`, riconosciuto con `parseLrc`) va in `synced`, altrimenti in `plain`; sempre `setLyrics(..., byUser: true)`; vuoto non salva. Modifica di un testo esistente.
- Test: rilevamento LRC (unità) e widget test `test/ui/lyrics_editor_test.dart` (salva, Annulla, voce del menu).

### 103.2 — «Testo sincronizzato» per brano (F-111, D-432)
- Insieme `unsyncedLyrics` (id dei brani) in `SettingsStore`, portato dal backup in `settings.json`. Interruttore nel menu del testo; spento = testo semplice (da `lyricsPlainText`), il testo sincronizzato resta salvato. «Copia» resta nella barra.
- Test: persistenza in `settings_store_test.dart` e round-trip in `backup_service_test.dart`.

### 103.3 — Copertine delle playlist in Memoria (F-108)
- `autoCoverKey` in `SizeGroup`, riempito da `byPlaylist` (`memory_queries.dart`) come lo calcola `playlist_sheet.dart:203`; `memory_screen.dart:237-241` lo passa al mosaico. Test della query.

### 103.4 — Aprire una cartella (F-109, D-441)
- `FolderOpener` in `lib/services/files/`: Linux `xdg-open` (stile `link_opener.dart`), Windows `explorer`, Android metodo `openFolder` sul canale `codecore/storage` (`StorageBridge.kt`): `ACTION_VIEW` con URI `DocumentsContract` (`content://com.android.externalstorage.documents/document/primary:<rel>`, tipo `vnd.android.document/directory`), volumi SD con il loro id; mai `file://`. Se fallisce: percorso negli appunti e avviso «Non riesco ad aprire la cartella: percorso copiato».
- Righe delle cartelle in `memory_screen.dart:260-269` toccabili con l'aspetto del mockup ed etichetta TalkBack.
- Test `test/services/files/folder_opener_test.dart`: percorso → URI (anche spazi e accenti), ripiego quando il processo o il canale falliscono.

### 103.5 — Controlli di fase
`flutter analyze`; comando mirato; review (`/code-review high` sul backup); scheggia passo e fase; prova sul Mi A3 contro i mockup (testo incollato semplice e LRC, sincronia spenta e riaccesa, Memoria con copertine, apertura di una cartella o ripiego) e su Linux nello schermo virtuale (`xdg-open`). Ripulire il telefono.

**Fatto quando:** i quattro comportamenti funzionano come nei mockup e il backup porta `unsyncedLyrics`.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-471** (103.1): voce «Elimina testo» nel menu; il brano torna com'era e la ricerca automatica riparte; salvare vuoto resta rifiutato.
- **D-472** (103.2): «Testo sincronizzato» spento vale ovunque, card del player compresa; con testo solo semplice l'interruttore non compare.

## Esiti
- 103.1 (2026-11-09): «Scrivi o incolla» e «Modifica testo» con editor (`lyricsFromText`: sincronizzato solo se più di metà delle righe iniziano con un tempo; altrimenti testo integrale), «Elimina testo» con Annulla che rimette tutto com'era (D-471) e ricerca che riparte se l'arricchimento è acceso; salvataggio ed eliminazione in `TrackOps`.
- 103.2: `unsyncedLyrics` in `SettingsStore` e nel backup (azzerato dalla sostituzione totale prima di applicare il file); spento vale nella vista, nella card del player e nella traduzione, con l'avviso «La versione sincronizzata è conservata»; menu del testo pubblico (`LyricsMenuButton`) anche nel pannello laterale desktop.
- 103.3: `autoCoverKey` in Memoria come `playlist_sheet`, anche per playlist con brani mancanti.
- 103.4: `FolderOpener` (Linux `xdg-open` con codice d'uscita, Windows `explorer` se la cartella esiste, Android `DocumentsContract`); ripiego con percorso copiato e avviso.
- Review: Sonnet su testi (8 rilievi: ripristino, ricerca che riparte, traduzione, LRC) e Memoria (6: codice d'uscita, URI Android, TalkBack), scheggia di passo (LRC che perdeva testo, URI di `/storage/emulated/10`): corretti con i test.
- 103.5: `flutter analyze` pulito, test mirati verdi; review di architettura Sonnet (scritture spostate in `TrackOps`, Annulla corretto, menu pubblico per la 106, 3 voci di debito). Prova sul Mi A3: tutti i flussi (cartella interna aperta in DocumentsUI, ripiego su `Android/data`); corretti dopo la prova il bordo dell'editor e la traduzione dopo aver riacceso la sincronia. Su Linux build riuscita, ma l'apertura con `xdg-open` non è stata provata (lancerebbe il file manager sul desktop vero): in «Tocca a te».

