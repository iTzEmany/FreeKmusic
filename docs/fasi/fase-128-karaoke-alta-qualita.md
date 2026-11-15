# Fase 128 — Karaoke «Alta qualità» (separazione AI)

## Obiettivo
«Alta qualità» nel foglio del karaoke separa la voce dal brano in ascolto con un modello AI sul dispositivo, con
avanzamento; la base va nella smart cache e sostituisce il filtro; per lo streaming si elabora dopo che il file è in
cache. **La fase parte solo se il passo di prova trova un modello usabile e l'utente lo sceglie** (D-605). Fuori:
elaborazione automatica dei preferiti (D-585), macOS e iOS (D-600).

## Riferimenti
D-585, D-601, D-602, D-604, D-605, D-616; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Stack (motore AI, modello), § Architettura D («Alta qualità»), rischio F-7. Documenti d'area:
`../architettura/riproduzione-e-coda.md`, `../architettura/piattaforme.md`.

## Mockup
```text
In riproduzione, foglio del karaoke con «Alta qualità»
+--------------------------------+
| Karaoke                   [on] |
| Voce  ===o-----------   20 %   |
| +----------------------------+ |
| | Alta qualità        42 %   | |
| | [##########------------]   | |
| | Separazione sul telefono,  | |
| | circa 3 minuti. Intanto    | |
| | suona il filtro.           | |
| +----------------------------+ |
| (base pronta: cursore          |
|  Base <---o---> Originale)     |
+--------------------------------+
```

## Task
- [ ] 128.1 Passo di prova: Spleeter 2-stem contro MDX-Net (D-605, F-7) — **poi ci si ferma**
  - File: nessun file del prodotto; script di prova nello scratchpad o in un ramo da buttare; numeri nelle «Note di
    deviazione».
  - Passi:
    1. Licenza dei pesi di ciascun modello (fonte e testo); senza licenza usabile il modello è escluso.
    2. Modelli in ONNX con `flutter_onnxruntime` 1.9.0 in un'app di prova: sul PC (Linux) e sul Mi A3 misurare tempo per
       minuto di audio, picco di memoria, peso del modello, su un brano di 4 minuti.
    3. Crescita dell'APK release con il plugin (per ABI): decide se il motore è un componente scaricato a parte (D-602).
    4. Tabella con i numeri e una raccomandazione.
  - Comando mirato: nessuno della suite; misure sul Mi A3 e sul PC.
  - Fatto quando: la tabella è scritta e **la fase si ferma**: l'utente sceglie il modello con i numeri. Se nessun modello
    ha una licenza usabile o tutti superano 2 minuti per un brano di 4 minuti sul Mi A3, R-245 si rimanda, resta il filtro e
    la fase si chiude qui.

- [ ] 128.2 Servizio di separazione (R-245, D-602, D-604)
  - File: `pubspec.yaml` (`flutter_onnxruntime: 1.9.0`, o componente scaricato se 128.1 lo chiede),
    `lib/services/karaoke/separation_service.dart` (nuovo), decodifica in PCM (Android `MediaCodec` in Kotlin; desktop da
    verificare), `test/services/karaoke/separation_service_test.dart` (nuovo).
  - Passi: 1. test prima con un separatore finto: avanzamento, base scritta in `StreamCache` con chiave
    `karaoke:<chiave stream>` o `karaoke:local:<id>:<mtime>`, errore → ripiego al filtro; 2. modello scaricato alla
    prima richiesta come `yt_dlp_updater.dart` (cartella dati, versione, sha256); 3. inferenza fuori dal thread UI.
  - Comando mirato: `flutter test test/services/karaoke/separation_service_test.dart test/services/stream/stream_cache_test.dart` (più `flutter analyze`), `flutter build apk --debug`
  - Fatto quando: test verdi; sul Mi A3 la base di un brano locale finisce in cache e il tempo misurato è annotato.

- [ ] 128.3 Gestore e interfaccia (R-245, D-585) — `/code-review high`
  - File: `lib/services/audio/codecore_audio_handler.dart` (`karaokeSource(Track)` consultato in `_nextFile`/`_loadCurrent`),
    `lib/services/karaoke/karaoke_controller.dart`, foglio del karaoke in `lib/ui/screens/now_playing/`, ARB, test in
    `test/services/audio/` e `test/ui/now_playing_test.dart`.
  - Passi: 1. test prima: con la base pronta il gestore la carica alla stessa posizione e il filtro va in bypass; brano
    in streaming non ancora in cache → «Alta qualità» aspetta il file; 2. riga con avanzamento; con la base attiva il
    cursore diventa Base/Originale.
  - Comando mirato: `flutter test <test nuovi del gestore> test/services/audio/online_playback_test.dart test/ui/now_playing_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; sul Mi A3 «Alta qualità» su un brano locale passa alla base a metà brano senza salti di
    posizione.

## Tocca a te
- Dopo il task 128.1: scegliere il modello con i numeri della tabella (o rimandare «Alta qualità»). Senza la tua scelta
  la fase non va avanti.
- A fase chiusa: ascoltare una base separata e dire se la qualità vale l'attesa.

## Note di deviazione
