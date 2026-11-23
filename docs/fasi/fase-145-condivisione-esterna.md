# Fase 145 — Condivisione esterna

## Obiettivo
«Condividi» apre il foglio di sistema (WhatsApp e simili) con un testo leggibile e un link https a una pagina statica su GitHub Pages che mostra i link YouTube Music e «Apri in FreeKmusic»; se l'app c'è, il link la apre (App Link) e l'app importa lo stesso link. Le playlist lunghe passano a un file m3u8. L'invio ai dispositivi in LAN resta come «Invia a un dispositivo» nel menu ⋮ (D-677). Fuori: song.link/Odesli, cartoline con QR.

## Riferimenti
D-677, D-669, D-670, D-691 (stesso spirito per i servizi esterni), D-662, D-699. Rilievo F-39 in [`../refactor/grande-revisione/analisi.md`](../refactor/grande-revisione/analisi.md); [`../refactor/grande-revisione/ricerca-condivisione-segnalazioni.md`](../refactor/grande-revisione/ricerca-condivisione-segnalazioni.md) (sezione «Condividere»: alternative 1 + 3 + 4); rete.md riga 145. Codice di partenza: `lib/services/share/share_link.dart` (LAN con PIN e QR), `lib/providers/share_hub.dart`, `lib/services/online/shared_text.dart` (`SharedText`, ingresso), `lib/services/export/playlist_exporter.dart` (m3u8). Aree: `../architettura/online.md`, `sync-backup-jam.md`, `piattaforme.md`, `qualita-e-rilascio.md`. Il tasto «Condividi» entra nella testata delle collezioni, creata nella 141.

## Task
- [ ] 145.1 Pacchetto `share_plus` (D-670)
  - File: `pubspec.yaml`, `pubspec.lock`, `docs/architettura/00-panoramica.md` (elenco dei pacchetti, se esiste), `.claude/obiettivo.md` solo se elenca i pacchetti ammessi.
  - Passi: 1) `flutter pub add share_plus` (pacchetto già approvato dall'utente, D-670; verificare la versione compatibile con Flutter 3.47 e con Linux/Windows, leggendo il sorgente in `~/.pub-cache` se l'API non corrisponde); 2) `python3 scripts/deps_report.py` se il progetto lo richiede; 3) `flutter analyze`; 4) un provider/servizio sottile `ExternalShare` per i test (interfaccia, finto).
  - Comando mirato: `flutter pub get` + `flutter analyze`
  - Fatto quando: `share_plus` è in `pubspec.yaml` e l'analisi è pulita; nessun altro pacchetto aggiunto.
- [ ] 145.2 Frammento `#` dei link: codifica e decodifica (F-39)
  - File: `lib/services/share/share_fragment.dart` (nuovo: ID YouTube compressi con gzip e base64url, titolo e tipo), `test/services/share/share_fragment_test.dart` (nuovo).
  - Passi: 1) `encode(items)`/`decode(fragment)` puri; 2) circa 13 caratteri per brano (100 brani ≈ 1,3 KB); 3) test di andata e ritorno e con input malformato (nessuna eccezione non gestita, errore tipizzato).
  - Comando mirato: `flutter test test/services/share/share_fragment_test.dart`
  - Fatto quando: andata e ritorno per 1, 50 e 100 brani; frammento corrotto → errore gestito.
- [ ] 145.3 Proposta all'utente: pagina statica e limite di brani (D-669) — **chiedere prima, non decidere**
  - File: nessuno da scrivere.
  - Passi: 1) scrivere all'utente (testo nel terminale, opzioni numerate): (a) dove vive la pagina: cartella `site/` o `docs/` di questo repo servita da GitHub Pages, oppure un repo a parte; (b) l'indirizzo (`<utente>.github.io/...`, quindi anche il dominio dell'App Link); (c) il limite di brani oltre il quale si passa al file m3u8 (la ricerca indica 50-100; lunghezza massima degli URL su WhatsApp non verificata); 2) registrare la risposta in `../decisioni.md` come D-xxx; 3) 145.4 e 145.7 aspettano la risposta.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: la scelta è in `../decisioni.md` e i task 145.4-145.7 hanno i percorsi e il limite definitivi.
- [ ] 145.4 Testo e link da condividere (F-39; D-677)
  - File: `lib/services/share/external_share_text.dart` (nuovo: testo leggibile con link YouTube Music più link alla pagina con il frammento), `lib/providers/share_hub.dart` (azione «Condividi»), `lib/ui/widgets/collection_header.dart` (icona «Condividi», segue la 141), `lib/ui/widgets/track_actions.dart` (condividi un brano), `lib/ui/screens/library/album_detail_screen.dart` e `lib/ui/screens/playlists/playlist_detail_screen.dart` (menu ⋮: «Invia a un dispositivo» = LAN di oggi), ARB ×6.
  - Passi: 1) brano, album e playlist producono testo e link con `ExternalShare`; 2) per le righe senza link YouTube Music (brani locali) si condivide solo il testo; 3) il tasto «Condividi» apre il foglio di sistema; la LAN passa nel menu ⋮; 4) test: testo con link YouTube Music; link per N brani sotto il limite scelto in 145.3.
  - Comando mirato: `flutter test test/services/share/ test/ui/collection_header_test.dart test/ui/collection_pages_test.dart test/ui/architecture_test.dart test/ui/no_separator_literals_test.dart`
  - Fatto quando: i test passano; il menu ⋮ di album e playlist ha «Invia a un dispositivo».
- [ ] 145.5 Playlist lunghe: file m3u8 (F-39)
  - File: `lib/services/export/playlist_exporter.dart` (m3u8 con link YouTube Music per le righe in streaming, dalla 140), `lib/services/share/external_share_text.dart`.
  - Passi: 1) oltre il limite scelto, `ExternalShare` condivide un file m3u8 (cache temporanea, ripulita) invece del link; 2) test: playlist lunga → m3u8, corta → link.
  - Comando mirato: `flutter test test/services/export/playlist_exporter_test.dart test/services/share/`
  - Fatto quando: la scelta fra link e file dipende dal limite (test su N−1, N, N+1).
- [ ] 145.6 Pagina statica per GitHub Pages (F-39; D-669)
  - File: percorso scelto in 145.3 (proposta di partenza: `site/index.html`, un solo file HTML con CSS e JS inline, senza dipendenze esterne), `site/.well-known/assetlinks.json` (modello, vedi 145.7).
  - Passi: 1) la pagina decodifica il frammento (stessa codifica di 145.2, `DecompressionStream`) e mostra i link YouTube Music; 2) pulsante «Apri in FreeKmusic» (link https dell'App Link); 3) nessuna richiesta di rete con i dati del frammento; 4) lingua dell'interfaccia: italiano; 5) prova locale con un server statico.
  - Comando mirato: `python3 scripts/check_docs_links.py` (se la cartella è sotto `docs/`) e prova a mano con `python3 -m http.server` nella cartella della pagina
  - Fatto quando: aprendo `index.html#<frammento di prova>` compaiono i brani; senza frammento un testo neutro.
- [ ] 145.7 App Link: apertura nell'app e importazione (F-39) — review Opus (manifest)
  - File: `android/app/src/main/AndroidManifest.xml` (intent-filter `https` con `autoVerify` sull'indirizzo scelto), `android/app/src/main/kotlin/com/codecore/player/IncomingBridge.kt` (verificare che già inoltri i link), `lib/services/online/shared_text.dart` (riconoscere il link della pagina e decodificare il frammento), `lib/providers/share_hub.dart`, test `test/services/share/share_link_test.dart`.
  - Passi: 1) l'app riceve il link, decodifica con 145.2 e apre il flusso di import/«aggiungi alla libreria» già esistente; 2) il fingerprint SHA-256 del certificato di firma va in `assetlinks.json` (lo fornisce l'utente: la chiave è di D-569); 3) test del riconoscimento del link e del flusso con link malformato.
  - Comando mirato: `flutter test test/services/share/ test/services/online/shared_text_test.dart` + `flutter build apk --debug` (`~/.claude/skills/obiettivo/scripts/sorveglia.sh --pesante 8m`)
  - Fatto quando: il test su un link di prova importa N brani; l'APK di debug compila.
- [ ] 145.8 Area e controllo di fine fase
  - Aggiorna `../architettura/online.md` (condivisione esterna, frammento `#`), `sync-backup-jam.md` (LAN dal menu ⋮), `piattaforme.md` (App Link, `share_plus`), `qualita-e-rilascio.md` (dove vive la pagina e come si pubblica), `00-panoramica.md` (nuovo pacchetto); «Trappole»: il frammento non arriva mai al server.

## Tocca a te
- [ ] Attivare GitHub Pages sul repo (Impostazioni › Pages, ramo e cartella scelti in 145.3).
- [ ] Fornire il fingerprint SHA-256 del certificato di firma di release (chiave di D-569) e pubblicare `assetlinks.json` su Pages (`/.well-known/assetlinks.json`), poi verificare l'App Link sul telefono (`adb shell pm get-app-links <pacchetto>`).
- [ ] Rispondere alla proposta di 145.3.
- [ ] (con la 147) provare la condivisione su WhatsApp dal telefono.

## Note di deviazione

## Da allineare (review di architettura della fase 142)
- Menu ⋮ (`track_actions.dart` ~479-620): prima di aggiungere «Condividi», semplificare con un host persistente unico (un `Consumer` creato una volta nell'overlay radice o nello stato della shell) al posto dell'`OverlayEntry` per ogni menu, di `hostX ?? callerX`, del ramo `const []`, del post-frame e di `onActionDone`. `outer` oggi è l'overlay radice: niente `ShellNav.open` né `RenderBox` della riga come ancora (il foglio di condivisione su iPad/desktop vuole un'ancora).

## Da allineare (review di architettura della fase 143)
- `ci.yml`, passo «Detect documentation-only change»: `docs/*` conta come sola documentazione, quindi una PR che tocca solo `docs/site/` (pagina Pages con JS che decodifica il frammento `#`) salterebbe la CI. Escludere `docs/site/*` da quel `case` o dargli un job a sé.
