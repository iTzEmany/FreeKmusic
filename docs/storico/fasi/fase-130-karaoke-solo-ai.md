# Fase 130 — Karaoke solo con il modello AI, voce regolabile

## Obiettivo
Il filtro in tempo reale non ha una qualità usabile (prova dell'utente, 17/11): si toglie del tutto e resta solo la
separazione con Spleeter (fase 128). Il cursore «Voce» torna e regola la voce sulla separazione AI:
mix = base + livello × voce. Fuori: desktop (D-620), Jam (D-623).

## Riferimenti
D-618..D-622, D-623..D-627. Documenti d'area: `../../architettura/riproduzione-e-coda.md`, `../../architettura/sync-backup-jam.md`.

## Mockup
```text
Foglio del karaoke (Android)
+--------------------------------+
| Karaoke                   [on] |
| Separazione sul telefono  42 % |
| [##########------------]       |
| Prima volta: scarica 78 MB     |   <- solo se servono dati (modello o brano in streaming) e si è a consumo
| (base pronta)                  |
| Voce  ===o-----------   20 %   |   <- applicato al rilascio, ~1–2 s
+--------------------------------+
Impostazioni › Riproduzione: [x] Mostra il karaoke
```

## Task
- [x] 130.1 Via il filtro in tempo reale e il karaoke nella Jam (D-623, D-624) — review Opus (protocollo Jam, gestore)
  - File: `lib/services/audio/` (`VoiceFilter`, `MirrorVoiceFilter`, `DesktopVoiceFilter`, `withVoiceFilter`), `lib/services/karaoke/karaoke_controller.dart`, `karaoke_send_throttle.dart`, `lib/providers/karaoke_providers.dart`, Jam (`jam_models.dart` campo `kar`, comandi `karaoke`/`karaokeGuests`, `jam_state.dart`, `jam_providers.dart`, `lib/ui/screens/jam/jam_karaoke.dart`), `pubspec.yaml` (via gli override di `just_audio` e `just_audio_media_kit`: tornano i pacchetti di pub.dev), `third_party/just_audio*` (via), CI (via `:just_audio:testDebugUnitTest`), ARB, test.
  - Una versione vecchia che manda `kar` o i comandi karaoke a una nuova: ignorati senza errori (test).
- [x] 130.2 Voce e base separate, mix regolabile, scadenza (D-625, D-626)
  - Kotlin: la separazione scrive due WAV (base = spettro × maschera, voce = spettro × (1 − maschera); base + voce = originale); metodo `mix` {base, voice, level, output} che somma in streaming.
  - Dart: chiavi `karaoke:base:…`, `karaoke:voice:…`, `karaoke:mix:…:<livello>`; i file del karaoke scadono 15 minuti dopo l'ultimo uso (tranne quelli in riproduzione); il cursore «Voce» al rilascio chiede il mix e il gestore ricarica alla stessa posizione; 100 % = originale senza mix.
- [x] 130.3 Impostazione e avviso dei dati (D-627)
  - «Mostra il karaoke» in Impostazioni › Riproduzione (acceso di partenza): spento, il microfono non compare e il karaoke si spegne.
  - Avviso nel foglio quando la separazione consuma dati e la rete è a consumo: primo download del modello (78 MB) o brano in streaming non ancora scaricato per intero (dimensione se nota).

## Tocca a te
- Ascoltare il cursore «Voce» a 0, 50 e 100 % su un brano tuo.

## Note di deviazione
- Prova sul Redmi Note 9 Pro (release, installazione nuova): separazione di 4 min in circa 38 s (circa 1 min 3 s dal tocco con il download del modello), cambio di livello sotto 1 s senza salti di posizione, «Mostra il karaoke» funziona, nessun crash. Fra il 100 % del modello e lo 0 % della separazione passano circa 20 s senza testo: in `prossimi-lavori.md`.
- Trovato fuori fase sullo stesso telefono: su Android 10 la scansione di `Music` fallisce con errno 13 (scoped storage): in `prossimi-lavori.md`.
