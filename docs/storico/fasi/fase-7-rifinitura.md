# Fase 7 — Rifinitura, import dal vecchio DB, build finali

**Obiettivo:** qualità e distribuzione personale. Task indipendenti: falli nell'ordine che preferisci,
saltando quelli che non ti servono.

## Task

### 7.1 — Import dal vecchio database Python
**File:** `lib/services/migration/python_db_importer.dart`, voce in Impostazioni → "Importa dalla vecchia app"
1. L'utente sceglie `codecore_library.db` (SQLite). Apri in sola lettura con `sqlite3` (pacchetto `sqlite3`, già dipendenza transitiva di drift; aggiungilo esplicito).
2. Leggi `tracks` (colonne: `path, title, artist, album, is_favorite, lyrics, curiosities`), `playlists`, `playlist_tracks`.
3. **Abbinamento** brano vecchio → nuovo (i percorsi Windows non coincidono): prima per nome file (basename, case-insensitive),
   poi per `normalize(artist)+normalize(title)`. Ambigui → non abbinare e conta come "non abbinati".
4. Copia solo: `isFavorite`, `lyricsPlain` (dal campo `lyrics`), `curiosities`, e ricrea le playlist (nome + ordine).
5. Mostra un riepilogo: "N preferiti, M playlist, K testi importati, X non abbinati". **Nessuna** modifica al file originale.
**Test:** con un DB SQLite creato in test con 3 brani (uno con basename uguale, uno con artista+titolo, uno senza match).

### 7.2 — Gapless
Sostituisci la gestione "un file alla volta" con la playlist nativa del backend (usa l'API playlist raccomandata dalla versione
installata di `just_audio`: `setAudioSources` o `ConcatenatingAudioSource`). Mantieni `PlayQueue` come fonte di verità e
sincronizza gli indici. Opzione in Impostazioni solo se funziona davvero su entrambi i backend.
**Verifica:** due tracce di un album live (es. dal vivo/continuous mix) senza silenzio percepibile; seek/shuffle/repeat invariati.

### 7.3 — ReplayGain (opzionale)
Leggi `REPLAYGAIN_TRACK_GAIN` (tag FLAC/OGG) o `TXXX:replaygain_track_gain` (ID3) in `TagInfo` → salva in una colonna `replayGainDb`
(migrazione schema v2). Applica come `setVolume(min(1, 10^(gain/20)))`. Opzione "Normalizza volume" (default off).

### 7.4 — Controlli multimediali desktop
- Windows: SMTC; Linux: MPRIS. Usa un pacchetto maintenuto (cerca con `flutter pub search`/pub.dev "audio_service windows/mpris";
  valuta `smtc_windows`, `audio_service_mpris`) **dopo** averne verificato la compatibilità con Flutter 3.47. Se non c'è nulla di affidabile, salta.
- Tasti multimediali della tastiera: `HardwareKeyboard`/`Shortcuts` con `LogicalKeyboardKey.mediaPlayPause`, ecc.

### 7.5 — Prestazioni (verifica con dati veri)
1. Script di test che genera un DB con 20.000 righe sintetiche; misura apertura lista, ricerca, scroll (DevTools → Performance, build profile: `flutter run --profile`).
2. Target: nessun frame > 16 ms in scroll; ricerca < 100 ms; avvio < 2 s.
3. Se manca, aggiungi indici/`cacheExtent` mirati; non ottimizzare "a sensazione".
4. Controlla memoria con 5000 copertine visibili a scroll lungo (`cacheWidth` corretto).

### 7.6 — Accessibilità e dettagli
`Semantics` su pulsanti icona (etichette tradotte), contrasto minimo AA nei 4 temi, bersagli ≥ 48 dp su mobile,
supporto scala testo fino a 150% senza overflow (prova con `fontScale` massimo), `reducedMotion` rispettato ovunque.

### 7.7 — Timer di spegnimento (facoltativo)
Impostabile da Now Playing: 15/30/45/60 minuti o "a fine brano"; fade-out di 5 s con `setVolume` a passi.

### 7.8 — Icona e nome app
`flutter pub add --dev flutter_launcher_icons`, icona 1024×1024 in `assets/icon/`, configura Android/Windows/Linux.
Nome visibile "Codecore" in `AndroidManifest`, `windows/runner/main.cpp` (titolo finestra), `linux/my_application.cc`.

### 7.9 — Build di rilascio
- **Android:** crea keystore personale (`keytool -genkey ...`), `android/key.properties` (**fuori dal repo**, in `.gitignore`),
  `flutter build apk --release --split-per-abi`. Installa con `adb install`.
- **Linux:** `flutter build linux --release` → cartella `build/linux/x64/release/bundle/`; crea un `.desktop` + zip (AppImage opzionale).
  Assicurati che `libmpv` sia presente sul sistema di destinazione (o includila nel bundle).
- **Windows** (su una macchina Windows con Visual Studio 2022 "Sviluppo di applicazioni desktop con C++"):
  `flutter build windows --release` → cartella `build\windows\x64\runner\Release\` da zippare così com'è (include le DLL di media_kit).
- Aggiorna `version:` in `pubspec.yaml` a ogni rilascio.

### 7.10 — Documentazione finale
Aggiorna `README.md`: come installare, come compilare, funzioni, limiti noti, nota legale su YouTube/testi.

## Definition of Done
- [ ] Almeno 7.1 e 7.9 completati
- [ ] Nessun crash in una sessione di 30 minuti su Android e su Linux
- [ ] `docs/PROGRESS.md` aggiornato
