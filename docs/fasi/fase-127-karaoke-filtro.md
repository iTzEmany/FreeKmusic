# Fase 127 — Karaoke col filtro in tempo reale

## Obiettivo
Pulsante microfono in «In riproduzione» e nella vista testi che apre il cursore della voce 0–100 %: il filtro in tempo
reale abbassa la voce su file locali e streaming, su Android, Linux e Windows, anche col crossfade; resta acceso fra un
brano e l'altro, il livello si ricorda, si spegne da solo su episodi e radio. Su macOS e iOS il microfono non c'è
(D-600). Fuori: «Alta qualità» (fase 128), Jam (fase 129), karaoke dal menu del brano (D-584).

## Riferimenti
D-583, D-584, D-586, D-600, D-603; specifica [`../storico/feature/feature-libreria-leggera-karaoke-cerca.md`](../storico/feature/feature-libreria-leggera-karaoke-cerca.md)
§ Stack (filtro Android e desktop), § Architettura D («Controller», «Motore», «UI»), flusso (c), RNF-01, RNF-04, rischi
F-4, F-6. Documenti d'area: `../architettura/riproduzione-e-coda.md`, `../architettura/piattaforme.md`, `../architettura/ui-e-design.md`.

## Mockup
```text
In riproduzione, karaoke acceso      Vista dei testi
+--------------------------------+   +--------------------------------+
|        [ copertina ]           |   | Testo              (Voce 20 %) |
| Cosa mi manchi a fare          |   |   Riga già cantata             |
| Calcutta                       |   |   un'altra riga già cantata    |
|  |<<     ||     >>|    (mic)   |   | > la riga che stai cantando    |
| +----------------------------+ |   |   la riga che viene dopo       |
| | Karaoke                [on]| |   |   e poi il ritornello          |
| | Voce  ===o----------  20 % | |   |   (pillola = riapre cursore)   |
| +----------------------------+ |   | Home   Cerca   Libreria Impost.|
+--------------------------------+   +--------------------------------+
```

## Task
- [ ] 127.1 Verifica di `af`/`lavfi`/`pan` sulla libmpv di Linux e Windows (F-6)
  - File: `integration_test/voice_filter_probe_test.dart` (temporaneo, tolto a fine task se non serve), esito nelle «Note
    di deviazione».
  - Passi:
    1. Su Linux (`xvfb-run`) un player media_kit con `setProperty('af', 'lavfi=[pan=…]')` su un WAV stereo generato:
       nessun errore di mpv nel log; velocità 1,25 insieme al filtro.
    2. Controllare in `media_kit-1.2.6/lib/src/player/native/player/real.dart` (`:829`, `:880`): con
       `PlayerConfiguration.pitch` media_kit scrive `af` (`scaletempo`); se l'app lo usa, il filtro va concatenato.
    3. Windows: lo stesso test in un run `workflow_dispatch` su `windows-latest`, o sulla macchina Windows dell'utente.
  - Comando mirato: `flutter test integration_test/voice_filter_probe_test.dart -d linux` (dentro `xvfb-run`)
  - Fatto quando: per Linux e Windows c'è una riga «funziona/non funziona» con la stringa del filtro usata; se Windows
    non ha `lavfi`, sul Windows `voiceFilter` resta `null` (il microfono non compare, come su macOS).

- [ ] 127.2 Filtro Android nella copia di `just_audio` (R-243, D-603, F-4) — `/code-review high`
  - File: `third_party/just_audio/` (copia di 0.10.6, con LICENSE MIT), `third_party/just_audio/MODIFICHE.md`,
    `pubspec.yaml` (`dependency_overrides`), Java: sottoclasse di `DefaultRenderersFactory` + `AudioProcessor` Media3
    (lato L−R attenuato, medio passa-basso ~150 Hz che tiene basso e cassa), metodo `setVoiceLevel` sul canale;
    Dart: `VoiceFilter` accanto a `Equalizer` (`lib/services/audio/equalizer.dart`), `AudioBackend.voiceFilter`
    (`audio_backend.dart:49`), `AndroidVoiceFilter` in `just_audio_backend.dart`.
  - Passi: 1. test JVM del processore nella copia: a 100 % uscita = ingresso (bypass esatto), a 0 % L = R su un segnale
    stereo; 2. innesto nel `AudioPlayer.java`; 3. `MODIFICHE.md`; 4. gapless invariato (`setNext`, una sola `ExoPlayer`).
  - Comando mirato: `flutter analyze`, test JVM con Gradle della copia, `flutter test test/services/audio/gapless_handler_test.dart test/services/audio/equalizer_test.dart`, `flutter build apk --debug` (con `JAVA_HOME`)
  - Fatto quando: test verdi; `diff -r` con il pacchetto originale = solo le righe di `MODIFICHE.md`; sul Mi A3 il
    livello cambia senza errori nel log e l'equalizzatore agisce ancora; `perf_device.py --playback` col filtro acceso
    entro +10 % di CPU (RNF-01).

- [ ] 127.3 Filtro desktop nella copia di `just_audio_media_kit` e crossfade (R-243, D-603) — `/code-review high`
  - File: `third_party/just_audio_media_kit/` (copia di 2.1.0), `third_party/just_audio_media_kit/MODIFICHE.md`,
    `pubspec.yaml`, accesso a `setProperty('af', …)` del `Player` privato (`mediakit_player.dart:16`), `VoiceFilter` del
    backend desktop, `MirrorVoiceFilter` in `lib/services/audio/crossfade_engine.dart` (come `MirrorEqualizer`, `:393`),
    `test/services/audio/crossfade_engine_test.dart`.
  - Passi: 1. test prima: il secondo player del crossfade nasce col livello giusto; stringa del filtro per 0, 50, 100 %
    (100 % = nessun filtro); 2. legame fra `AudioPlayer` e player media_kit; 3. `MODIFICHE.md`.
  - Comando mirato: `flutter test test/services/audio/crossfade_engine_test.dart test/services/audio/equalizer_test.dart` (più `flutter analyze`)
  - Fatto quando: test verdi; su Linux (`xvfb-run`) il livello cambia senza errori di mpv, anche durante un crossfade.

- [ ] 127.4 Controller e interfaccia (R-243, R-244, D-584, D-600, RNF-04)
  - File: `lib/services/karaoke/karaoke_controller.dart` (nuovo), `lib/providers/karaoke_providers.dart` (nuovo),
    `lib/data/settings/settings_store.dart` (`karaokeOn`, `karaokeLevel`), microfono e foglio col cursore in
    `lib/ui/screens/now_playing/`, pillola in `lib/ui/screens/lyrics/lyrics_view.dart`, ARB,
    `test/services/karaoke/karaoke_controller_test.dart` (nuovo), `test/ui/now_playing_test.dart`, golden.
  - Passi: 1. test prima: livello salvato e riletto; resta fra due brani; in bypass su episodio e radio senza toccare il
    livello salvato, poi torna; 2. microfono assente se `voiceFilter == null`; accendendo, si apre la vista dei testi
    sincronizzati se ci sono; 3. etichette TalkBack di microfono e cursore.
  - Comando mirato: `flutter test test/services/karaoke/karaoke_controller_test.dart test/ui/now_playing_test.dart test/ui/lyrics_view_test.dart test/goldens/player_golden_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart` (più `flutter analyze`)
  - Fatto quando: test e golden di «In riproduzione» col karaoke acceso verdi; sul Mi A3 e su Linux il cursore cambia il
    livello e su un episodio il filtro si spegne da solo.

## Tocca a te
- Ascolto: sul Mi A3 (alza tu il volume, io lo tengo a 0) e su Linux, un brano stereo a 0 % e a 50 %: la voce si
  abbassa in modo udibile e non ci sono buchi (RNF-01)?
- Solo se la CI non basta per il task 127.1: la stessa prova sulla tua macchina Windows.

## Note di deviazione

**Esito 127.1 (17/11/2026), filtro voce desktop.** Stringa (livello `l`, `k = (1-l)/2`, 4 decimali; 100 % = `af` vuoto):
`lavfi=[asplit[o][m];[m]pan=stereo|c0=-k*c0-k*c1|c1=-k*c0-k*c1,highpass=f=150[h];[o][h]amix=inputs=2:normalize=0]`
(il centro sopra 150 Hz, con il passa-alto, viene sottratto da entrambi i canali; sotto i 150 Hz basso e cassa restano). Un solo
ingresso e una sola uscita, come vuole `lavfi` di mpv; con la velocità `af` diventa `scaletempo:scale=1.25,lavfi=[…]`.
- Linux (mpv 0.37 di sistema, `xvfb-run`, uscita `ao=pcm` su file): **funziona**. Nessun errore di mpv a 0, 50, 100 %, con la
  velocità 1,25 insieme al filtro e da `just_audio` (livello e velocità cambiati in riproduzione). Misura su un WAV
  (1 kHz e 60 Hz al centro, 2 kHz solo a sinistra): 1 kHz 0,30 → 0,156 (50 %) → 0,064 (0 %, circa −13 dB); 60 Hz 0,30 → 0,32 → 0,34 (basso tenuto).
  A 0 % il lato sinistro resta com'è e il destro va in controfase rispetto al lato: uscita stereo, non mono come su Android.
- Windows: **non funziona** (verifica statica, nessun run). `media_kit_libs_windows_audio` 1.0.9 scarica
  `libmpv-win32-audio-build` 2023-09-24 (`mpv-dev-x86_64-20230924-git-652a1dd.7z`, MD5 verificato); nella DLL la riga di
  configurazione di FFmpeg ha `--disable-filters --enable-filter=overlay --enable-filter=equalizer`: mancano `pan`,
  `asplit`, `amix`, `highpass` (nessuna traccia nelle stringhe). Su Windows `voiceFilter` resta `null`: il microfono non
  compare. Un filtro che mpv non riesce a creare ferma la riproduzione («Audio filter initialized failed»), quindi non si prova a metà.
- `af` e `PlayerConfiguration.pitch`: `just_audio_media_kit` usa `pitch: true` (default) e `main.dart` non lo cambia;
  `setRate`/`setPitch` di media_kit (`real.dart:829`, `:880`) sovrascrivono tutto `af` con `scaletempo:scale=…`. Nella copia
  `setSpeed`/`setPitch` riscrivono `af` con `scaletempo` seguito dal filtro (`MODIFICHE.md`).
- Legame `AudioPlayer` e player media_kit: l'`id` di `just_audio` è privato e cambia a ogni reinizializzazione (dopo `stop`), quindi
  si usa un tag nel campo `DarwinLoadControl.preferredPeakBitRate` della configurazione (inutilizzato su desktop): `DesktopVoiceFilter`
  (`lib/services/audio/desktop_voice_filter.dart`). La prova `integration_test/voice_filter_probe_test.dart` resta fino a 127.4.
