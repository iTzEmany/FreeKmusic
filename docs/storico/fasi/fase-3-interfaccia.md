# Fase 3 — Interfaccia principale

**Obiettivo:** app usabile: libreria (brani/album/artisti), ricerca, ordinamento, mini-player,
player a schermo intero con coda. Layout adattivo telefono/desktop.
**Prerequisiti:** Fasi 1–2. Leggi `01` §8 (prestazioni).

## Layout
- Larghezza ≥ 840 px → `NavigationRail` a sinistra; altrimenti `NavigationBar` in basso.
- Mini-player fisso sopra la barra inferiore (o in fondo al contenuto su desktop), visibile solo se c'è un brano.
- Sezioni: **Libreria** (tab Brani / Album / Artisti), **Preferiti**, **Playlist**, **Impostazioni**
  (+ **YouTube** dalla fase 5). Per ora Preferiti/Playlist/Impostazioni sono segnaposto con titolo.

## Task

### 3.1 — Tema
**File:** `lib/ui/theme/app_theme.dart`
`ThemeData buildTheme(AppThemeId id, double fontScale, bool compact)`; Material 3, `ColorScheme.fromSeed`.
- `oled`: scuro, `surface`/`scaffoldBackground` **#000000**, seed viola/blu.
- `carbon`: scuro grigio carbone (#121212 / #1E1E1E).
- `navy`: scuro blu navy (#10131A / #151822).
- `light`: chiaro.
`compact` → `VisualDensity.compact` e righe brano più basse (48 px invece di 64).
Nessun colore esadecimale sparso nei widget: usa sempre `Theme.of(context).colorScheme`.
**Verifica:** `flutter analyze`.

### 3.2 — Shell adattiva
**File:** `lib/ui/shell/app_shell.dart`
`AppShell` con `IndexedStack` delle sezioni (mantiene lo scroll), navigazione adattiva, `MiniPlayer` in basso.
Stato della sezione corrente in un `StateProvider<int>`.
**Verifica manuale:** ridimensiona la finestra Linux sotto/sopra 840 px: cambia navigazione.

### 3.3 — Widget riusabili
**File:** `lib/ui/widgets/`
- `cover_image.dart`: `CoverImage(coverKey, size, radius)`; `Image.file` con `cacheWidth = size*devicePixelRatio`, `gaplessPlayback: true`,
  placeholder = icona nota musicale su `surfaceContainerHighest`. Se `coverKey == null` → solo placeholder (nessun I/O).
- `track_tile.dart`: `TrackTile(track, isCurrent, isPlaying, onTap, onMore)`: cover 48, titolo (1 riga, ellipsis), "artista • album", durata `m:ss`,
  indicatore "equalizer" statico sul brano corrente, icona cuore (placeholder fino alla fase 4). Altezza fissa (`itemExtent`).
- `quality_badge.dart`: testo piccolo secondo `04` §8.
- `empty_state.dart`: icona + messaggio + azione (es. "Aggiungi cartella").
- `format_utils.dart`: `formatDuration(int ms)`.

### 3.4 — Tab "Brani"
**File:** `lib/ui/screens/library/tracks_tab.dart`
1. Barra superiore: campo di ricerca (debounce 250 ms → `trackQueryProvider`), menu ordinamento (`04` §10), conteggio brani.
2. Lista: `ListView.builder(itemExtent: ...)` su `tracksProvider`. Tap → `PlayerController.playFromList(snapshot, index)`
   dove `snapshot` è la lista **corrente** (id) al momento del tap.
3. Evidenzia il brano corrente osservando **solo** `currentTrackProvider.select((t) => t?.id)` nel tile (non ricostruire l'intera lista).
4. Stato vuoto: se non ci sono cartelle → `EmptyState("Aggiungi la tua cartella musicale")`; durante la scansione mostra una `LinearProgressIndicator`.
5. Pulsante "Aggiorna libreria" (rescan) e gestione cartelle (aggiungi/rimuovi) in un `BottomSheet`/dialog.
**Verifica manuale:** con 5000 brani (genera un DB di prova con uno script di test o una cartella grande) scroll fluido, ricerca reattiva.

### 3.5 — Tab "Album" e dettaglio
**File:** `lib/ui/screens/library/albums_tab.dart`, `album_detail_screen.dart`
- `SliverGrid` con `maxCrossAxisExtent: 180`, card = copertina quadrata + titolo + artista (2 righe max).
- Ordinamento: titolo, artista, anno. Provider `albumsProvider` (query `GROUP BY albumKey`, vedi `03`).
- Dettaglio: header con copertina grande, titolo, artista, anno, n. brani, durata totale; pulsanti "Riproduci" e "Casuale";
  lista brani ordinata per `discNumber, trackNumber, title`.
**Verifica manuale:** due album omonimi di artisti diversi appaiono come **due** card.

### 3.6 — Tab "Artisti"
**File:** `lib/ui/screens/library/artists_tab.dart`
Lista di artisti (`artist` normalizzato, con conteggio brani/album); tap → schermata con i suoi album (riusa la griglia).

### 3.7 — Mini-player
**File:** `lib/ui/widgets/mini_player.dart`
Altezza 64: cover, titolo/artista (1 riga), play/pausa, avanti; `LinearProgressIndicator` sottile alimentato da `positionProvider`
(widget separato che osserva solo la posizione). Tap → apre `NowPlayingScreen` (animazione a scorrimento).
Swipe orizzontale (solo mobile) = avanti/indietro.

### 3.8 — Now Playing (schermo intero)
**File:** `lib/ui/screens/now_playing/now_playing_screen.dart`
- Copertina grande, titolo, artista, `QualityBadge`.
- Slider posizione: durante il trascinamento mostra il valore locale, **seek solo su `onChangeEnd`**; tempi trascorso/rimanente.
- Controlli: shuffle, precedente, play/pausa (grande), successivo, repeat (off/all/one con icona diversa).
- Volume: slider (solo desktop) + muto.
- Pulsante "Coda": `DraggableScrollableSheet` con la coda (`ReorderableListView` per riordinare, swipe per rimuovere).
- Tasto indietro di sistema chiude la schermata (Android).
- Nome-brano lungo: `Text` con `maxLines: 2`, niente `wraplength` calcolati a mano.

### 3.9 — Scorciatoie da tastiera (solo desktop)
`Shortcuts`/`Actions` in `AppShell`: Spazio = play/pausa, `Ctrl+→`/`Ctrl+←` = avanti/indietro, `Ctrl+F` = focus ricerca,
`↑/↓` volume ±5%. Nessuna scorciatoia quando un campo di testo ha il focus (tranne `Ctrl+F`).

### 3.10 — Rimozione schermata di debug
Elimina `debug_library_screen.dart` e imposta `AppShell` come `home`. Verifica che la scelta cartella e la scansione siano raggiungibili dalla UI vera.

## Definition of Done
- [ ] `flutter analyze` pulito, test precedenti ancora verdi
- [ ] Checklist manuale: ricerca, ordinamento, riproduzione da lista/album, mini-player, now playing, coda, resize finestra
- [ ] Scroll fluido con ≥ 5000 brani su Linux
- [ ] L'app è usabile come lettore (Android + Linux)
- [ ] `docs/PROGRESS.md` aggiornato
