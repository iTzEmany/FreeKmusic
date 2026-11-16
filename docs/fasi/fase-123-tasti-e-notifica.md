# Fase 123 — Tasti multimediali, notifica e licenza

## Obiettivo
I tasti delle cuffie, della tendina e della schermata di blocco funzionano sempre, anche dopo una Jam finita o interrotta;
pausa è sempre pausa; dopo 30 minuti senza musica la notifica Android sparisce (mai con una Jam attiva) e Play riparte
dallo stesso punto. Il progetto passa a GPLv3. Fuori: tempo di chiusura regolabile (D-589).

## Riferimenti
D-589, D-594, D-599, D-608, D-610; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Architettura A (ipotesi H1–H4, correzione, chiusura dopo 30 minuti) e rischio F-1. Documenti d'area:
`../architettura/riproduzione-e-coda.md`, `../architettura/piattaforme.md`, `../architettura/qualita-e-rilascio.md`.

## Mockup
Nessuna schermata nuova: cambia solo il comportamento (tendina e notifica restano come sono).

## Task
- [x] 123.1 Diagnosi sul Mi A3 (R-226, R-227, D-594)
  - File: nessun file di codice; esito nelle «Note di deviazione» di questa fase.
  - Passi:
    1. APK debug di `master` sul Mi A3 (volume 0), cuffie JBL collegate; stato letto con `adb shell dumpsys media_session`.
    2. H1: in pausa `adb shell input keyevent 127` due volte, poi 126, 85, 87, 88; annota se la pausa fa ripartire.
    3. H2/H3: Jam vera con Mi A3 host e un'istanza Linux ospite (`xvfb-run`), chiusa una volta normalmente e una uccidendo
       l'ospite; dopo, keyevent e tasti della tendina: la sessione è attiva? I comandi arrivano al player locale?
    4. H4: in pausa con l'app in background, `adb shell am kill <pkg>`, poi keyevent 126: riparte?
  - Comando mirato: nessuno (solo prove con `scripts/telefono.py` e `adb`).
  - Fatto quando: per H1–H4 c'è una riga «confermata/smentita» con il comando che lo mostra; una causa nuova fuori da
    H1–H4 è annotata e i task 123.2–123.4 sono adattati prima di partire.

- [ ] 123.2 Gestore: comandi pubblicati sempre e sessione viva in Jam (R-226, R-227, F-1, D-610) — `/code-review high`
  - File: `test/services/audio/handler_media_buttons_test.dart` (nuovo), `lib/services/audio/codecore_audio_handler.dart`.
  - Passi:
    1. **Prima** i test, e verificare che falliscano su `master` (annotare quali): `controls` e `systemActions` pubblicati in
       ogni stato, anche dopo `attachRemote(t)` → `attachRemote(null)`; Jam senza brani → staccata con un brano locale →
       `processingState` non è `idle`; `click(MediaButton.media)` mentre uno stream aspetta il file con `_playWhenReady`
       → pausa; `pause()` da fermo lascia `playing == false`.
    2. `click()` ridefinito: `media` → `togglePlayPause()`, `next`/`previous` come oggi.
    3. `attachRemote(null)` ricalcola lo stato da quello locale (`_current == null ? idle : ready`), non da
       `_publishedProcessing`; `_showRemote` non pubblica mai `idle` con la Jam aperta (`ready`, `playing: false`).
    4. Prova sul Mi A3 con una Jam vera e Linux ospite (F-1): durante la Jam la notifica mostra la Jam, dopo i tasti
       comandano il player locale.
  - Comando mirato: `flutter test test/services/audio/handler_media_buttons_test.dart test/services/audio/codecore_audio_handler_test.dart test/services/audio/remote_transport_test.dart test/services/audio/mpris_controls_test.dart` (più `flutter analyze`)
  - Fatto quando: i test nuovi passano (e fallivano prima); sul Mi A3, dopo una Jam chiusa nei due modi, keyevent
    85/87/88 cambiano lo stato del player locale.

- [x] 123.3 Copia di `audio_service`: PLAY e PAUSE separati (R-227, D-608) — `/code-review high`
  - File: `third_party/audio_service/` (copia di `~/.pub-cache/hosted/pub.dev/audio_service-0.18.19`, con la sua
    LICENSE), `third_party/audio_service/MODIFICHE.md` (nuovo), `pubspec.yaml` (`dependency_overrides`).
  - Passi:
    1. Copiare il pacchetto; in `AudioService.java` (`onMediaButtonEvent`, oggi `:976-981`) `KEYCODE_MEDIA_PLAY` →
       `onPlay()` e `KEYCODE_MEDIA_PAUSE` → `onPause()`; 85 e `HEADSETHOOK` restano `onClick`.
    2. `MODIFICHE.md`: base, righe cambiate, perché, come riallineare a un aggiornamento.
    3. Controllare che widget e riquadro rapido (`MediaKeys.kt`, mandano 85) restino play/pausa.
  - Comando mirato: `flutter analyze`, `JAVA_HOME=~/.jdks/jbr-17.0.14 PATH=$JAVA_HOME/bin:$PATH flutter build apk --debug`, poi prova sul Mi A3.
  - Fatto quando: `diff -r` fra la copia e il pacchetto originale mostra solo le righe di `MODIFICHE.md`; sul Mi A3
    in pausa keyevent 127 due volte → resta in pausa, 126 → suona, 85 → commuta.

- [ ] 123.4 Chiusura della notifica dopo 30 minuti (R-228, D-589, F-1) — `/code-review high`
  - File: `test/services/audio/handler_idle_park_test.dart` (nuovo), `lib/services/audio/codecore_audio_handler.dart`,
    `lib/main.dart` (`stopServiceWhenIdle: true` solo su Android).
  - Passi:
    1. **Prima** i test con orologio finto: 30 minuti in pausa → `processingState: idle`, coda, brano e posizione intatti e
       ripresa salvata; `play()` dopo → riparte dalla stessa posizione; Jam attiva in pausa per 3 ore → niente; `playing`
       o uno stream in attesa annullano il timer; con `stopServiceWhenIdle: false` (desktop) mai.
    2. `_idleTimer` armato in `_publish` quando `!playing && _remote == null && !_waitingStream`, annullato da `playing`,
       `attachRemote(transport)` e `_goIdle`; allo scadere `_park()` (`_saveResume()`, `idle` senza svuotare niente);
       `_parked` tiene `idle` finché `play()` lo azzera e chiama `_backend.play()`.
  - Comando mirato: `flutter test test/services/audio/handler_idle_park_test.dart test/services/audio/handler_media_buttons_test.dart test/services/audio/playback_persistence_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; sul Mi A3 dopo 31 minuti in pausa `adb shell dumpsys notification` non mostra più la
    notifica dell'app, e Play dall'app e dal riquadro rapido riparte dallo stesso secondo; con una Jam in pausa da 35
    minuti la notifica c'è ancora.

- [x] 123.5 Licenza GPLv3 (D-599)
  - File: `LICENSE` (nuovo, testo integrale: `/usr/share/common-licenses/GPL-3`), `README.md` (riga «Licenza»),
    `lib/ui/screens/settings/settings_pages.dart` (voce accanto a `showLicensePage`, `:492`), ARB in `lib/l10n/` (6 lingue).
  - Passi: 1. copiare il testo; 2. riga nel README; 3. voce «Licenza: GNU GPLv3» in Informazioni; 4. `flutter gen-l10n`.
  - Comando mirato: `flutter test test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: `head -2 LICENSE` dice «GNU GENERAL PUBLIC LICENSE / Version 3»; la voce compare in Informazioni.

## Tocca a te
Niente di obbligatorio. Se hai cuffie Bluetooth diverse dalle JBL, a fase chiusa prova play, pausa e avanti dopo una Jam
e dimmi se qualcosa non risponde.

## Note di deviazione
- 123.1 (16/11, Mi A3, APK master): **H1 confermata** (da pausa 127 e 126 fanno ripartire, 85 alterna; 87/88 da pausa
  avviano). **H2 in altra forma**: durante e dopo la Jam la sessione FreeKmusic è `active=false` (state 0 o 2) e la
  tendina mostra la sessione di un'altra app finché un tasto non la riattiva; i keyevent arrivano comunque. **H3
  smentita** con l'host Linux ucciso (il telefono esce da solo in ~8 s); non provato «ospite ucciso con il telefono
  host». **H4 confermata in altra forma**: dopo `am kill` in pausa, 126 rilancia il processo ma non suona (sessione
  `active=false state=0`): `play()` a freddo deve caricare la ripresa salvata. 123.2 si allarga a questo caso.
