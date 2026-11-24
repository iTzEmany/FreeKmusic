# Fase 148 — Video karaoke nella Jam

## Obiettivo
Durante una Jam, quando il brano corrente è un video karaoke (D-634, D-646: YouTube con «karaoke» nel titolo), ogni dispositivo della Jam (host, ospiti in LAN, ospiti a distanza, uscite) mostra il video al posto della copertina, allineato alla posizione della Jam. Nessuna modifica al protocollo: lo stato porta già `videoId`, titolo, `positionMs`/`positionAt` e `playing`. Fuori: testi sotto il video, karaoke col modello AI nella Jam (resta tolto, D-623).

## Riferimenti
D-710 (scelte dell'utente, 24/11), D-623, D-631..D-639, D-646, D-647, D-649, D-656, D-661. Architettura: `../architettura/online.md` («Video karaoke»), `../architettura/sync-backup-jam.md` («Jam»).
Codice: `KaraokeVideoController` (`lib/services/karaoke_video/karaoke_video_controller.dart`), `karaokeVideoProvider` (`lib/providers/karaoke_video_providers.dart`), `KaraokeVideoView` (`lib/ui/widgets/karaoke_video_view.dart`), `KaraokeVideoFullscreen` (`lib/ui/screens/now_playing/karaoke_video_fullscreen.dart`), `JamCover` (`lib/ui/screens/jam/jam_parts.dart`), `JamPlayerView` (`lib/ui/screens/jam/jam_player.dart`), `JamState.positionAtTime` e `JamController.jamNowMs`.

## Task
- [ ] 148.1 Video della Jam: controller e provider
  - File: `karaoke_video_controller.dart` (ingresso per id del video invece che per `Track`, comportamento invariato), `karaoke_video.dart` (regola per un `JamItem`), `karaoke_video_providers.dart` (nuovo `jamKaraokeVideoProvider`), test in `test/services/karaoke_video/` e `test/providers/`.
  - Passi: 1) il controller riceve uno stream di id del video (il provider del player li ricava dal brano corrente con la regola di oggi); 2) `jamKaraokeVideoId(JamItem)`: `videoId` presente e «karaoke» nel titolo; 3) `jamKaraokeVideoProvider` (vive solo mentre qualcuno lo guarda) crea un secondo controller con id, posizione (`positionAtTime(jamNowMs())`, a passi brevi) e `playing` della Jam, stessa cache e stessa sorgente del player, senza cancello sull'audio della Jam; 4) ciclo di vita dell'app come il player.
  - Comando mirato: `flutter test test/services/karaoke_video/ test/providers/karaoke_video_providers_test.dart`
  - Fatto quando: il video della Jam segue id, posizione e pausa dello stato della Jam; i test di oggi del controller restano verdi.
- [ ] 148.2 Video nella schermata della Jam e a schermo intero
  - File: `karaoke_video_view.dart`, `karaoke_video_fullscreen.dart` (provider come parametro, di serie quello del player), `jam_parts.dart` / `jam_player.dart`, test in `test/ui/`.
  - Passi: 1) con un video karaoke in corso, al posto della copertina dentro l'anello c'è il video della Jam (in caricamento: copertina con l'indicatore, come nel player); 2) tocco → schermo intero come nel player; 3) video fallito → copertina e il messaggio breve di oggi; 4) TalkBack «Video karaoke» come nel player.
  - Comando mirato: `flutter test test/ui/karaoke_video_view_test.dart test/ui/jam_*_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: la schermata della Jam mostra il video per un brano karaoke e la copertina per gli altri.
- [ ] 148.3 Prova fra Mi A3 e Redmi, aggiornamento dalla 1.6.4, documenti, rilascio
  - Passi: 0) sul Redmi: build di debug della 1.6.4 (DB v20) con una libreria grossa (`~/Downloads/Liked_Songs.csv`, preferiti, playlist), poi la build di debug di `master` installata sopra: conteggi, playlist e preferiti identici dopo la migrazione v20 → v24; 1) Jam in LAN fra Mi A3 (host) e Redmi (ospite) con un video karaoke: il video compare su entrambi, segue pausa e salto; 2) documenti d'area aggiornati; 3) dopo il merge, tag `v1.7.0` (la fase entra nella 1.7.0).
  - Fatto quando: la prova ha esito scritto qui sotto; tag creato e release della CI verde.

## Tocca a te
- [ ] Dopo il tag: prove sul Motorola rimandate dalla fase 147 (vedi `fase-147-verifica-finale.md`, «Tocca a te»).

## Note di deviazione
