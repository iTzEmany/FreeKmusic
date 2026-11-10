# Fase 4 — Preferiti, playlist, impostazioni, temi, lingue, modifica tag

**Obiettivo:** tutte le funzioni "da lettore completo" che non richiedono internet.
**Prerequisiti:** Fase 3. Task indipendenti tra loro salvo dove indicato.

## Task

### 4.1 — Preferiti
**File:** `track_repository.dart` (+ `setFavorite(id, bool)`), `lib/providers/favorites_providers.dart`, `tracks_tab`, `now_playing`
1. Cuore nel `TrackTile` e nel Now Playing: toggle immediato (aggiornamento ottimistico via stream DB).
2. Snackbar "Aggiunto/Rimosso dai preferiti" con azione **Annulla** (`04` §9); una sola alla volta (`ScaffoldMessenger.clearSnackBars()`).
3. Sezione **Preferiti**: stessa lista dei brani con `favoritesOnly: true`, stessi ordinamenti e ricerca.
**Verifica:** test repository (toggle + annulla); manuale: togliere un preferito dalla sezione Preferiti non sposta la coda in riproduzione.

### 4.2 — Playlist
**File:** `playlist_repository.dart`, `lib/ui/screens/playlists/*`
1. Repository: `create(name)`, `rename`, `delete`, `watchAll()` (con conteggio), `watchTracks(playlistId)` ordinati per `position`,
   `addTracks(playlistId, ids)` (ignora duplicati), `removeTrack`, `reorder(playlistId, oldIndex, newIndex)` (ricalcola `position` in transazione).
2. UI: elenco playlist + "Nuova playlist" (dialog con campo nome, non vuoto, max 60 caratteri).
3. Dettaglio playlist: lista con `ReorderableListView`, swipe per rimuovere, "Riproduci", "Casuale".
4. Dal menu ⋯ di un brano: "Aggiungi a playlist…" → bottom sheet con le playlist + "Nuova playlist…".
5. Eliminare un brano dal DB (non succede mai automaticamente) non deve lasciare orfani: usare `ON DELETE CASCADE`.
**Verifica:** test repository: duplicati ignorati, reorder stabile, cascade.

### 4.3 — Menu azioni brano
**File:** `lib/ui/widgets/track_actions_sheet.dart`
Voci: Riproduci dopo, Aggiungi alla coda, Aggiungi a playlist, Preferito, Modifica info, Dettagli, (desktop) Mostra nella cartella.
"Mostra nella cartella": Windows `explorer.exe /select,<path>` (argomento unico, percorso assoluto di `explorer.exe`
da `%WINDIR%`), Linux `xdg-open <cartella>`. Senza shell, argomenti come lista.
"Dettagli": percorso, formato, `QualityBadge`, dimensione, durata, aggiunto il, n. riproduzioni.

### 4.4 — Modifica info brano
**File:** `lib/ui/screens/track_edit_dialog.dart`
Campi: titolo, artista, album, artista album, anno, n. traccia, genere. Salva **solo nel DB**, imposta `userEdited = true`,
ricalcola `albumKey` e ricalcola/mantiene `coverKey`.
⚠️ Correzione rispetto a Python: il valore letterale "Unknown…" è un titolo valido; **non** svuotare i campi in base a sottostringhe.
I valori "ignoti" sono solo `null`/vuoto. Pulsante "Ripristina dai tag del file" (rilegge il file e azzera `userEdited`).
**Verifica:** test: una modifica sopravvive a una nuova scansione (file invariato e file modificato).

### 4.5 — Impostazioni (store + schermata)
**File:** `lib/data/settings/settings_store.dart`, `lib/providers/settings_provider.dart`, `lib/ui/screens/settings/settings_screen.dart`
1. `AppSettings` immutabile con le chiavi di `03` (sezione Impostazioni), `copyWith`, `SettingsNotifier` con scrittura **debounced** 400 ms.
2. Schermata a sezioni (`ListView` di `ListTile`/`SwitchListTile`/`SegmentedButton`):
   - **Aspetto:** tema (4 opzioni), dimensione testo (3), modalità compatta, animazioni ridotte.
   - **Lingua:** Italiano / English / Deutsch / Español.
   - **Libreria:** cartelle musicali (aggiungi/rimuovi), "Riscansiona ora", "Svuota cache copertine".
   - **Online (default spenti):** arricchimento automatico, testi automatici (usate dalla fase 5; qui solo switch).
   - **Info:** versione, licenze (`showLicensePage`), nota "uso personale".
3. Le impostazioni si applicano **subito** (tema, scala testo via `MediaQuery.textScaler`, lingua) senza riavvio.
4. Nessuna impostazione "finta": se una voce non ha ancora effetto, **non mostrarla**.
**Verifica:** cambiare tema/lingua/scala aggiorna l'intera app all'istante; dopo il riavvio i valori persistono.

### 4.6 — Localizzazione (it, en, de, es)
**File:** `l10n.yaml`, `lib/l10n/app_it.arb` (template), `app_en.arb`, `app_de.arb`, `app_es.arb`
1. `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_it.arb`, `output-localization-file: app_localizations.dart`.
2. Estrai **tutte** le stringhe visibili in ARB (chiavi camelCase: `navLibrary`, `navFavorites`, `searchHint`, `sortTitle`, `actionPlay`, …).
   Per tradurre molte voci in blocco, puoi guardare `../codecore/i18n.py` (65 chiavi già tradotte in 4 lingue).
3. Placeholder ICU per i conteggi: `"tracksCount": "{count, plural, one{1 brano} other{{count} brani}}"`.
4. Il `MaterialApp.locale` segue `settings.language`.
**Verifica:** `flutter gen-l10n` senza errori; cambiando lingua **nessun** testo italiano resta nelle altre lingue
(`grep -rn` di stringhe italiane note in `lib/ui` deve dare 0 risultati).

### 4.7 — Brani mancanti e stati di errore
- Brani `missing`: nascosti dalle liste, ma conteggio e voce "Brani non trovati (N)" nelle impostazioni → elenco con
  azioni "Rimuovi dalla libreria" (cancella la riga, **dopo conferma**) e "Ignora".
- Scansione fallita (cartella non raggiungibile): banner non bloccante con "Riprova".
- Permesso negato su Android: schermata dedicata con spiegazione e pulsante "Apri impostazioni".

### 4.8 — Ripresa riproduzione
Collega `playback_persistence` (fase 2.6) alla UI: all'avvio mini-player mostra l'ultimo brano in pausa.

## Definition of Done
- [ ] Test: preferiti, playlist (3 casi), modifica persistente, impostazioni (serializzazione)
- [ ] Nessuna stringa italiana hardcoded in `lib/ui`
- [ ] Tema e lingua cambiano a caldo e persistono
- [ ] `docs/PROGRESS.md` aggiornato
