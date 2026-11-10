# Fase 63 — Jam = player (refactor «ui-jam-ricerca»)

**Obiettivo:** la Jam è la schermata di riproduzione stessa (copertina con anello, barra, controlli, testo e curiosità scorrendo,
coda dal pulsante «Coda»); cambia solo l'intestazione. Precedente e successivo per tutti.

**Prerequisiti:** fasi 59 (seek condiviso) e 61 (fogli) chiuse. Intoccabili e dispositivi: `fase-58-rete-jam-ricerca.md`; il protocollo della Jam
e il formato dei messaggi non cambiano (D-158). Decisioni D-150, D-151, D-156, D-159, D-160.
Mockup: `docs/refactor/ui-jam-ricerca/mockup/jam-player.html`.

**Comando mirato:** `flutter test test/ui/ring_progress_test.dart test/ui/now_playing_test.dart test/ui/jam_screen_test.dart test/ui/jam_track_info_screen_test.dart test/jam test/services/audio/remote_transport_test.dart`;
in più `flutter test test/services test/jam` quando si toccano `jam_state.dart` o `codecore_audio_handler.dart`.

## Task

### 63.1 — Precedente e successivo per tutti (D-160)
`jam_state.dart`: cadono i controlli `isHost` su `next` e `jump` (messaggi invariati). «Precedente» come nel player: oltre 3 s `seek(0)`,
entro 3 s `jump` al brano prima nella coda; vale anche per `skipToPrevious` con `_remote` (`codecore_audio_handler.dart:1141`).

**Fatto quando:** `jam_state_test:48` e `remote_transport_test` riscritti di proposito; test nuovi «ospite può next/jump» e «precedente > 3 s / ≤ 3 s»; la parte dell'host di 58.2 verde senza modifiche.

### 63.2 — La schermata della Jam è il player (F-01, F-02, F-05, F-10)
La Jam usa la stessa schermata di riproduzione: `RingProgress` e `SeekBar` della fase 59 con posizione della Jam e `onSeek` = `JamCommand.seek`
(host e ospiti; l'esito `invalid` mostra un messaggio). Via `jam_player_card.dart` (anello `live`, letterali) e `JamSeekBar`; testo e curiosità scorrendo come nel player.

**Fatto quando:** test nuovi «seek dall'anello nella Jam invia JamCommand.seek», «posizione della Jam ferma in pausa»; golden `jam` (telefono, desktop, chiaro) rigenerati una volta e confrontati con il mockup.

### 63.3 — Intestazione della Jam (F-11, F-12, F-16)
«Jam», fila di avatar + nomi dei partecipanti («+N» oltre 4, `Semantics` sull'insieme, colori dai token), «Termina Jam» (host) con conferma
«Terminare la Jam per tutti?», «Esci dalla Jam» (ospite). Su due righe a testo grande, titolo fino a 2 righe.

**Fatto quando:** test nuovi «Annulla non chiude», «Esci dalla Jam», «+N con semantica», «intestazione a textScaler 2.0 senza tagli»; `jam_screen_test` (intestazione, «Termina») riscritto di proposito.

### 63.4 — Coda condivisa dal pulsante «Coda» (F-13, D-151)
La coda della Jam si apre dal pulsante «Coda» in un foglio come quella del player; righe con ⋮ + ≡, «Rimuovi» e «Salta qui» nel foglio del ⋮; lo swipe che accoda resta (58.2).

**Fatto quando:** test nuovo «riga con ⋮ + ≡»; caso dello swipe di 58.2 verde senza modifiche.

### 63.5 — Prova a mano con due telefoni
Motorola avvia, Mi A3 si unisce: seek dall'anello e dalla barra da entrambi, precedente e successivo dall'ospite, «Termina» con conferma, coda dal pulsante.
Annotare anche i rilievi aperti di 47.8 in `docs/handoff.md` che si vedono in questa prova.

**Fatto quando:** esito scritto in `docs/PROGRESS.md` sotto 63.5.

### 63.6 — Controlli di fase
**Fatto quando:** `flutter analyze` pulito; comando mirato, `flutter test test/services test/jam`, test di accessibilità (vedi 59.6) e `flutter test test/goldens` verdi; review Opus del diff (area a rischio: Jam); CI verde.
