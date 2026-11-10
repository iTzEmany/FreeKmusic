# FreeKmusic (Flutter) — istruzioni per l'agente

App musicale **standalone** (nessun backend) per uso personale. Un'unica codebase Flutter/Dart
per **Android, Windows e Linux**. Sostituisce la vecchia app Python/CustomTkinter che sta nella
cartella padre (`../codecore/`), usata solo come riferimento di logica.

## Prima di fare qualsiasi cosa
1. Leggi `docs/01-regole-di-lavoro.md` (regole obbligatorie).
2. Leggi `docs/00-INDICE.md`, poi `docs/architettura/00-panoramica.md` e il documento d'area che tocchi
   (`docs/architettura/<area>.md`: libreria-e-dati, riproduzione-e-coda, online, sync-backup-jam, piattaforme,
   ui-e-design, qualita-e-rilascio).
3. Leggi **solo** il file della fase corrente in `docs/fasi/` (`fase-N-*.md`); l'avanzamento si spunta lì dentro.
   Le fasi chiuse, le feature, i refactor e il vecchio PROGRESS stanno in `docs/storico/` (non si aggiorna più).

## Stack (non cambiarlo senza chiedere)
Flutter 3.47 / Dart · `flutter_riverpod` (stato) · `drift` + SQLite (DB) · `just_audio` +
`just_audio_media_kit` (audio) · `audio_service` (notifica Android) · `audio_metadata_reader`
(tag, lettura) · `metadata_god` (`third_party/`, scrittura dei tag solo via `SafeTagWriter`) · `dio` (HTTP) ·
yt-dlp (download e flusso, flavor `full`; su Android anche NewPipeExtractor; catalogo da InnerTube) · `shared_preferences` ·
`mqtt_client` + `sodium` (Jam a distanza, D-251/D-252).

## Comandi
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # dopo modifiche alle tabelle drift
flutter analyze
flutter test
flutter run -d linux            # sviluppo desktop (il più veloce)
flutter build apk --debug       # Android
flutter build linux / windows   # windows solo da una macchina Windows (macOS: zip non firmato dalla CI)
```

## Lingua
- Interfaccia e documentazione: **italiano** (ARB in `lib/l10n/`: it/en/de/es/fr/pt).
- Codice, nomi di classi/variabili, commenti brevi: **inglese**.

## Regole d'oro (riassunto)
- Un task alla volta, dal documento di fase, nell'ordine. Spunta il task nel file della fase (`docs/fasi/`) a fine task.
- Dopo ogni task: `flutter analyze` pulito + test mirati verdi (la suite completa la esegue la CI). Se fallisce, correggi prima di proseguire.
- Non aggiungere pacchetti non elencati. Non inventare API: se un pacchetto non corrisponde a
  quanto scritto nei documenti, leggi il suo sorgente in `~/.pub-cache` e adatta.
- Nessun `catch (_) {}` muto: logga con `AppLog`.
- Nessun lavoro pesante (I/O, DB lungo, rete) nel thread UI.
- Git: si lavora sempre in un ramo da `origin/master` e si entra con una PR in auto-merge (squash), mai con commit diretti su `master`. `master` è protetto e richiede il check «Analyze and test». `/obiettivo` lavora in modalità PR.
- Non toccare file fuori dalla cartella del progetto (la radice del repo, `codecore-music-player/`). Mai modificare la vecchia app Python.

## Modalità autonoma
`/obiettivo` (skill globale in `~/.claude/skills/obiettivo/`, profilo del progetto in `.claude/obiettivo.md`) esegue il piano
da solo, una PR per fase. Vedi `docs/00-INDICE.md`. Avvia Claude Code **nella radice del progetto** (`codecore-music-player/`).
