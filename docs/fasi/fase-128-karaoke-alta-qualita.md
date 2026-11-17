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
- [x] 128.1 Passo di prova: Spleeter 2-stem contro MDX-Net (D-605, F-7) — **poi ci si ferma**
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

### Passo di prova 128.1 — risultati (17/11/2026)

**Esito: nessun modello supera il limite di 2 minuti con certezza, ma Spleeter 2-stem ci sta dentro; MDX-Net è escluso (14 e 56 minuti per 4 minuti di brano sul Mi A3). Raccomandazione sotto la tabella.**

Come si è misurato. PC: Linux, 16 core, Python 3.12 + onnxruntime 1.32 CPU, 4 thread, brano sintetico stereo 44,1 kHz di 4 minuti (mix di onda a dente di sega con vibrato, basso, hi-hat, accordi; nessun file dell'utente); il tempo comprende STFT e iSTFT in numpy. Mi A3 (Android 11, non 10 come scritto nella specifica; 3,7 GB di RAM, 8 core, volume 0): app di prova Flutter release con `flutter_onnxruntime` 1.9.0 (ONNX Runtime 1.28 nell'AAR), modello eseguito su blocchi di dimensione fissa con ingressi finti; tempo del blocco = `fromList` + `run` + lettura dell'uscita (tutto il giro del plugin), media dei blocchi dopo uno di riscaldamento. Estrapolazione ai 4 minuti: numero di blocchi × tempo del blocco (Spleeter: blocchi da 512 frame ≈ 11,9 s, 21 blocchi; MDX-Net: blocchi da 256 frame ≈ 5,78 s utili, 42 blocchi). STFT/iSTFT sul telefono non eseguite dal modello: stimate con un FFT 4096 in Dart puro misurato sul telefono (1,43 ms l'uno; 41 mila FFT per 4 minuti = 59 s a un solo thread, circa 15 s su 4 isolate, pochi secondi con codice nativo).

| Modello | Pesi: licenza | ONNX | PC s/min (4 thread) | Mi A3 s/min | Brano di 4 min sul Mi A3 | RAM di picco PC / telefono | Qualità |
|---|---|---|---|---|---|---|---|
| Spleeter 2-stem (solo `accompaniment.onnx`, fp32) | MIT dichiarata dal solo articolo JOSS, non dal README (vedi sotto): usabile con un rischio residuo | 39,3 MB | 1,9 (solo modello 0,6) | 10,4 (modello+plugin 2,06 s per blocco di 11,9 s; solo `run` 7,5) | circa 43 s di ONNX + 15-60 s di FFT = circa 1-1,8 min | solo modello 276 MB; giro Python intero 2,3 GB (STFT di tutto il brano in memoria, evitabile a blocchi) / 330-360 MB | non misurata (niente MUSDB); banda a 11 kHz (F=1024 a 44,1 kHz) |
| MDX-Net UVR_MDXNET_1_9703 (UVR, vocali, base = mix − voce) | MIT dichiarata dal README di UVR, il file LICENSE è stato cancellato (vedi sotto): usabile con un rischio residuo | 29,7 MB | 15,6 | 215 (19,6 s di `run` per blocco di 5,78 s) | circa 14,5 min | solo modello 619 MB, giro intero 1,4 GB / 1,08 GB | non misurata |
| MDX-Net UVR-MDX-NET-Inst_HQ_3 (UVR, strumentale) | come sopra | 66,8 MB | 41,5 (misurato su 4 min: 166 s) | 830 (77 s di `run` per blocco) | circa 56 min | solo modello 1,35 GB, giro intero 3,0 GB / 1,64 GB (con swap) | non misurata; è il migliore dei tre per fama, non verificato da me |
| MDX-Net Kim_Vocal_2 | nessuna licenza (repo e pesi senza file di licenza, nessuna dichiarazione) | 66,8 MB | non misurato | non misurato | — | — | **escluso** per licenza |

Crescita dell'APK release (stessa app senza e con il plugin, `--split-per-abi`, byte esatti):

| ABI | senza plugin | con plugin | crescita |
|---|---|---|---|
| arm64-v8a | 15,49 MB | 44,18 MB | **+28,7 MB** |
| armeabi-v7a | 12,70 MB | 33,04 MB | **+20,3 MB** |
| x86_64 | 16,92 MB | 51,53 MB | **+34,6 MB** |

Quasi tutto è `libonnxruntime.so` (28,6 MB su arm64, non compresso nell'APK). Ben oltre la soglia di circa 10 MB per ABI di D-616: l'AI non può stare nell'APK di base.

**Licenze dei pesi (fonti e testo).**
- Spleeter (Deezer). Codice: «MIT License, Copyright (c) 2019-present, Deezer SA.» (https://github.com/deezer/spleeter/blob/master/LICENSE). README: «The code of **Spleeter** is MIT-licensed.»: parla solo del codice. L'articolo JOSS del repo (`paper.md`, https://github.com/deezer/spleeter/blob/master/paper.md) dice: «Spleeter source code and pre-trained models are available on github and distributed under a MIT license.» Il dubbio è aperto con l'issue «[Discussion] license for model weights» (deezer/spleeter#898, aperta, 3 commenti di utenti, nessuna risposta dei manutentori; il README chiede anche di non contattarli per questo). Il file ONNX viene da `csukuangfj/sherpa-onnx-spleeter-2stems` (Hugging Face e release `source-separation-models` di k2-fsa/sherpa-onnx, Apache-2.0), conversione dei pesi originali `2stems.tar.gz` (release v1.4.0 di deezer/spleeter). Va dato il credito a Deezer con l'avviso MIT. Il README avverte anche di avere l'autorizzazione dei titolari per l'uso su materiale protetto da copyright (rilevante solo se si distribuiscono basi, qui restano sul dispositivo).
- MDX-Net UVR (modelli addestrati da Anjok07 e Aufr33, scaricati dal repo `TRvlvr/model_repo`, release `all_public_uvr_models`, che non ha licenza). README di UVR (https://github.com/Anjok07/ultimatevocalremovergui): «UVR's core developers trained all of the models provided in this package (except for the Demucs v3 and v4 4-stem models)» e, nella sezione License: «The **Ultimate Vocal Remover GUI** code is MIT-licensed. Please Note: For all third-party application developers who wish to use our models, please honor the MIT license by providing credit to UVR and its developers.» Il file LICENSE («MIT License, Copyright (c) 2022 Anjok07, Aufr33», commit ca61edf1) fu cancellato il 19/12/2022 (commit 63a4cb69) mentre il README lo cita ancora. Quindi: MIT per i modelli dichiarata a parole, senza file; credito a UVR obbligatorio.
- Kim_Vocal_2 (KimberleyJensen): nessuna licenza trovata (repo `kmdx-net_music-source-separation` senza licenza, copie su Hugging Face senza scheda) → escluso.
- Il codice MDX-Net originale (kuielab/mdx-net) è MIT («Copyright (c) 2020 KINoAI»), i suoi pesi non dichiarano nulla.

**Cose che emergono per la fase 128.2.**
1. Con R8 (release) il plugin va in crash in `getInputInfo` (`NoSuchMethodError ... ai/onnxruntime/NodeInfo.<init>`): serve `-keep class ai.onnxruntime.** { *; }` in `android/app/proguard-rules.pro` collegato in `build.gradle.kts`.
2. Un componente «scaricato a parte come yt-dlp» (D-602) non funziona con questo plugin: `libonnxruntime.so` è nell'AAR del plugin, dunque nell'APK. Strade: (a) libreria ONNX Runtime ridotta agli operatori che servono a Spleeter e caricata dal plugin; (b) eseguibile ONNX a parte scaricato ed eseguito come processo (come yt-dlp); (c) accettare +20-29 MB nell'APK. Va scelta con l'utente.
3. Il Mi A3 con le app di uso normale ha circa 1 GB di RAM libera: la prima prova è finita in swap (2 GB pieni) e non ha prodotto numeri in 5 minuti; i numeri sopra sono con le app in cache chiuse (`am kill-all`). Spleeter va eseguito a blocchi (un blocco da 512 frame per volta) e tiene circa 330 MB.
4. Costo del plugin sul telefono, per blocco di Spleeter: `fromList` 0,15 s + `run` 1,49 s + lettura 0,42 s (`asFlattenedList` su 1 M di float): la lettura pesa un quarto; 8 thread non aiutano (1,8 s contro 1,5 s con 4).
5. La Spleeter ONNX usa lo spettrogramma di ampiezza (2×blocchi×512×1024) e solo i primi 1024 bin (fino a circa 11 kHz): sopra, la base va ricostruita dal brano originale oppure resta tagliata. Il post-processing di Spleeter (maschera, Wiener) non è stato replicato: il mio giro PC è un banco di prova dei tempi, la correttezza dell'audio in uscita non è verificata.

**Non misurato.** SDR/qualità (niente MUSDB; un brano sintetico non dice nulla); picco RAM del telefono con l'STFT in Dart; decodifica (MediaCodec) e scrittura del file della base; MDX-Net con sovrapposizione dei blocchi (UVR la usa di default al 25 %: ancora più lento); varianti fp16/int8 di Spleeter (fp16 non accelera sulla CPU del telefono senza istruzioni dedicate, int8 non provato); Windows e Linux dal prodotto (solo il PC come banco).

**Raccomandazione.** Rimandare MDX-Net: anche il più piccolo (UVR_MDXNET_1_9703, 30 MB) impiega circa 14 minuti per 4 minuti di brano sul Mi A3 e 1 GB di RAM; il migliore (Inst_HQ_3) circa un'ora. Spleeter 2-stem è l'unico sotto i 2 minuti (circa 1-1,8 min per 4 minuti, con FFT fuori dal thread UI), con 39 MB di modello e 330 MB di RAM; quindi non scatta la regola di rimando (c'è un modello con licenza usabile e sotto i 2 minuti). Condizioni da far scegliere all'utente: (1) accettare il rischio di licenza dei pesi (MIT dichiarata dall'articolo dei loro autori, non dal README; issue #898 senza risposta); (2) peso del motore: +20-29 MB nell'APK per ABI, oltre la soglia di D-616, quindi o ONNX Runtime ridotto/processo a parte o accettare l'APK più grande; (3) qualità: la qualità di Spleeter 2-stem (banda a 11 kHz) non è stata misurata, da ascoltare in una prova prima della 128.2. Se l'utente non accetta (1) o (2), si rimanda R-245 e resta il filtro.
