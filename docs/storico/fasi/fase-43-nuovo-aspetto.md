# Fase 43 — Nuovo aspetto (refactor «ui-fluida»)

**Obiettivo:** realizzare i mockup approvati il 2026-10-23 (D-22, D-25..D-28) su un'app già fluida, accessibile e
strutturata. Direzione D-21: base «Anello vivo» (l'anello è l'unico segno grafico e porta lo stato), player ordinato
come «Disco», liste sobrie come «Quaderno»; superfici piatte, niente gradiente, niente ombre. Non si copia la struttura
né la UI di Spotify (D-08).

**Prerequisiti:** fasi 38–42 chiuse. Token già in `tokens.dart` (fase 40).

**Specifica visiva (approvata, non si reinventa):** `docs/refactor/ui-fluida/mockup/` — `now-playing.html`,
`home.html`, `libreria.html`, `album-artista.html`, `onboarding.html`, `tokens.css`. In caso di dubbio vale il mockup;
se il mockup è ambiguo o impossibile, si ferma il passo e si chiede (nuova riga in `docs/decisioni.md`).

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

## Cambi di aspetto voluti (qui)
Sono i soli passi in cui i golden si rigenerano (D-20): **ogni passo dice quali golden cambiano** e il commit li
elenca. Comportamento (azioni, dati, rotte, impostazioni) invariato; `lib/data`, servizi, Jam e l10n non cambiano, salvo
le stringhe nuove strettamente necessarie (it/en/de/es).

## Regole di costo (da D-08/D-23)
Solo `transform` e scale per muovere; niente gradienti, blur o ombre; anello 12 dp nel player (è anche il seek, si
trascina), 3 dp nel mini player, 2 dp sulla riga del brano in riproduzione e su «Riprendi»; avanzamento come cornice
quadrata sulle miniature quadrate (D-25). Dopo ogni passo che tocca una schermata misurata si riesegue il suo scenario
(`python3 scripts/perf_device.py 0d7ae9df206e --label <passo> --playback --no-push`, via `sorveglia.sh`) e **non deve
superare le soglie** della fase 38.

## Test in locale
Il test della schermata toccata, i suoi golden (`flutter test test/golden --update-goldens` solo nel passo, poi `git diff --stat test/golden`), `test/ui/a11y_guidelines_test.dart` e, a textScale 2,0, mini player e dock.

## Task

### 43.1 — Un solo dock ovunque (D-27)
Mini player + 4 schede con il pallino, **uguale in tutte le schermate** (quello di Home/Libreria del mockup). Anello 3 dp nel mini player. Il mockup del player va allineato a questo dock, non il contrario.

**Fatto quando:** `flutter test test/ui/app_shell_test.dart test/ui/mini_player_test.dart test/ui/a11y_guidelines_test.dart` verde; golden «mini player + dock» rigenerato e confrontato col mockup; scenari «Pallino schede» ≤ 2 % e «Swipe mini player» ≤ 2 %.

### 43.2 — Home (`home.html`)
Grande invito (Unbounded 28), «Riprendi» con anello 2 dp, «Casuale su tutto», «Aggiunti da poco», sezioni come nel mockup. Desktop e telefono come i mockup.

**Fatto quando:** `flutter test test/ui/home_test.dart` verde; golden Home (telefono e desktop) rigenerati e vagliati con `git diff --stat test/golden` (solo Home); nessun overflow a textScale 2,0.

### 43.3 — Libreria (`libreria.html`, D-26, D-28)
1. **Filtri** a blocchi simmetrici (come `SegmentedBlocks`), senza icone, tutti visibili scorrendo in verticale, mai una striscia che scorre di lato.
2. **Scorciatoie**: telefono, griglia a **2 colonne** con etichette su una riga e il **nono blocco a tutta larghezza**; desktop, 9 blocchi su una riga. Senza icone.
3. Righe del brano a «Quaderno» (separatore 1 dp in s2, niente tessere), anello 2 dp sul brano in riproduzione.

**Fatto quando:** `flutter test test/ui/library_screen_test.dart` verde, con test nuovi: su 360 px le scorciatoie sono 2 colonne e il nono occupa tutta la riga; su 1600 px sono 9 in una riga; nessun `ListView` con `scrollDirection: Axis.horizontal` nei filtri; golden Libreria rigenerati; «Tutti i brani» ≤ 1 %.

### 43.4 — Album e artista (`album-artista.html`, D-25)
Durata nelle righe album anche sul telefono; album dell'artista a righe se pochi e a griglia se molti; avanzamento come cornice quadrata sulle miniature quadrate. Le pagine online (artista, album) usano lo stesso schema.

**Fatto quando:** `flutter test test/ui/album_screen_test.dart test/ui/artist_screen_test.dart` verde, con test nuovi per «pochi → righe, molti → griglia» (righe fino a 4 album, griglia da 5, D-33); golden rigenerati; «Apri album» ≤ 3 % e «Album» ≤ 0,6 %.

### 43.5 — In riproduzione (`now-playing.html`, D-21, D-23)
Un solo anello spesso (12 dp) attorno alla copertina che è anche il seek (si trascina; niente barra grigia doppione), player piatto senza gradiente, dock del 43.1. Copertina che ruota solo con l'opzione di 39.6. Dopo F-41/F-31 resta senza sfumatura a tutta pagina.

**Fatto quando:** `flutter test test/ui/now_playing_test.dart test/ui/ring_progress_test.dart test/ui/now_playing_reduce_motion_test.dart test/ui/large_text_test.dart` verde, con un test nuovo che il trascinamento sull'anello porta a `seek`; golden rigenerati; «Apertura player» ≤ 3 % e p99 ≤ 33 ms; «In riproduzione» non peggiora rispetto a `fluidita-dopo`.

### 43.6 — Onboarding (`onboarding.html`, D-12)
Pagine come il mockup, con la scansione dopo la scelta della cartella (già unificata in 42.9) e il suo avanzamento visibile.

**Fatto quando:** `flutter test test/ui/onboarding_test.dart` verde, con un test nuovo che dopo «aggiungi cartella» parte la scansione e compare l'avanzamento; golden onboarding rigenerati.

### 43.7 — Resto delle schermate e verifica sul telefono
1. Le schermate non nei mockup restano com'erano, ma ereditano dock, token e righe «Quaderno» dai mattoni (nessun layout nuovo senza mockup, D-08).
2. Prova a mano sul Mi A3 con l'app perf (D-19): schermate dei passi 43.1–43.6 aperte e fotografate; screenshot già letti cancellati con `~/.claude/skills/obiettivo/scripts/pulizia.sh via <percorsi>`.

**Fatto quando:** `flutter analyze` pulito; `flutter test test/ui test/golden` verde; `python3 scripts/perf_device.py 0d7ae9df206e --label nuovo-aspetto --playback` scrive `build/perf/nuovo-aspetto.md` con ogni scenario entro le soglie; Motorola non toccato.

## Dalla review della fase 42
- D-52: `loadErrorState` (log fuori da `build`) e variante sliver di `AsyncBody`.
- `BackupOps` (inspect/replace/merge): oggi `mergeBackupFile` sta in `TrackOps` e `backup_section` chiama `inspectBackup`/`stageFullRestore` sul servizio. `folderPaths` da `TrackOps` a `FolderOps`, `applyReceived` verso lo share, `clearHistory`.
- `SelectionKey` per le chiavi con parametro: costruttori tipo `SelectionKey.playlistOf(id)`, family tipizzata. 9 chiavi stringa in playlist_detail, genre_screen, artist_screen, smart_playlist_screen, album_detail, tags_screen, artist_page_screen, online_album_screen, artist_songs_screen.
- Un widget `NewPlaylistMenu` unico (l'enum `_NewPlaylistAction` è duplicato in desktop_sidebar e library_screen).
- `tags_sheet` usa ancora `showCcSheet<String>` con case stringa: passare a un enum.
- `architecture_test` esteso a `*QueriesProvider` (album_card legge `libraryQueriesProvider`).
- Logica ancora nei widget via servizi, da portare negli Ops: exportify_sync_screen (ciclo di import), tag_backups_screen (restore + stampFile), now_playing_cards (traduzione), sync_flow.
- `TrackKind` senza radio (il documento prometteva anche la radio).
