# Scansione: input del PC, flatpak, test desktop (giro 1, 24/11/2026)

## A. Versione del flatpak
- Cosa mostra 1.2.0: solo `packaging/flatpak/com.freekmusic.player.metainfo.xml:14` (`<release version="1.2.0" date="2026-10-19"/>`). GNOME Software e `flatpak info` leggono la versione dai `<releases>` del metainfo. Verificato installando il bundle della Release v1.7.0 il 24/11: `flatpak info` → `Version: 1.2.0`, mentre l'app dentro è la 1.7.0 (`kAppVersion`).
- L'updater dell'app non è bloccato: confronta `kAppVersion` (`lib/core/app_info.dart:2`, 1.7.0, a mano) con le Release (`update_providers.dart:26`).
- deb, AppImage, zip, Inno e macOS prendono la versione dal pubspec in CI (`release.yml:171,197`, `scripts/package-*.sh`). Fermi: metainfo e `packaging/fdroid/com.freekmusic.player.yml:19-21`.
- Il file della Release si chiama `freekmusic.flatpak`, senza versione (`release.yml:74`), a differenza di AppImage, deb, exe e zip macOS.

## B. Prove fatte installando il flatpak (24/11)
- Il bundle non porta il runtime: serve `org.freedesktop.Platform//24.08` da Flathub, **a fine vita** («no longer receiving fixes and security updates»).
- Con l'estensione `org.freedesktop.Platform.ffmpeg-full//24.08` installata l'app **non parte**: `bwrap: Can't mkdir /app/lib/ffmpeg: Read-only file system` / `ldconfig failed`. Il manifesto dichiara `add-extensions` con `directory: lib/ffmpeg` ma nessun comando crea `/app/lib/ffmpeg`. Con `autodownload: true`, chi installa da un repository la riceve sempre. Senza l'estensione parte (codec limitati del runtime).
- Dati: AppImage e deb usano `~/.local/share/com.freekmusic.player`, il flatpak `~/.var/app/com.freekmusic.player/data/com.freekmusic.player`. Passando da uno all'altro la libreria «sparisce»; nessun avviso né migrazione.
- Log dell'AppImage: «curiosity lookup failed | MusicBrainzUnavailable (resting until …)» ogni 3 s per minuti: durante la pausa di MusicBrainz le curiosità ritentano invece di aspettare.

## Rilievi
- F-201 · packaging · metainfo flatpak fermo a 1.2.0 · `packaging/flatpak/com.freekmusic.player.metainfo.xml:14` · `flatpak info` → 1.2.0 con la 1.7.0 installata · versione sbagliata in GNOME Software e `flatpak info` · A/B/S · la CI scrive la `<release>` dal pubspec prima di flatpak-builder.
- F-202 · packaging · fdroid fermo a 1.2.0 · `packaging/fdroid/com.freekmusic.player.yml:19-21` · `versionName: 1.2.0` · bozza F-Droid vecchia · B/B/S · stesso script del F-201.
- F-203 · versione · `kAppVersion` a mano · `lib/core/app_info.dart:2` · «keep in sync» senza controllo · updater, UA e backup con versione sbagliata se si dimentica · M/M/S · controllo in CI pubspec = kAppVersion = metainfo.
- F-204 · aggiornamento · il flatpak non si aggiorna da sé · `lib/services/update/update_target.dart:65-66`, `update_tiles.dart:214` · apre il download del bundle nel browser · installazione a mano · M/B/M · mostrare il comando `flatpak install --user <file>` (o un repo flatpak: rimandabile).
- F-212 · packaging · il flatpak non parte con ffmpeg-full · `packaging/flatpak/com.freekmusic.player.yml` (add-extensions, build-commands) · `bwrap: Can't mkdir /app/lib/ffmpeg` · app che non si avvia · A/B/S · `mkdir -p /app/lib/ffmpeg` nei build-commands e prova di avvio del bundle in CI.
- F-213 · packaging · runtime 24.08 a fine vita · manifesto `runtime-version: '24.08'` · avviso EOL all'installazione · niente correzioni di sicurezza · M/M/M · passare a 25.08 (libplacebo e mpv da verificare).
- F-214 · packaging · cartelle dati diverse fra flatpak e AppImage/deb · `~/.var/app/...` contro `~/.local/share/...` · libreria vuota cambiando formato · M/B/S · al primo avvio nel flatpak, se la cartella è vuota e quella vecchia esiste (non leggibile dal sandbox): avviso con il comando di copia; oppure solo una riga nella guida.
- F-215 · arricchimento · curiosità che ritentano durante la pausa di MusicBrainz · log AppImage 24/11 19:16-19:17 · una riga ogni 3 s · richieste e log a vuoto · M/B/S · le curiosità rispettano `resting until` come il resto.
- F-216 · packaging · bundle senza versione nel nome · `release.yml:74` · `freekmusic.flatpak` · non si capisce quale versione si scarica · B/B/S · `freekmusic-<versione>.flatpak`.
- F-205 · desktop · tasti laterali del mouse assenti · `lib/ui/shell/app_shell.dart:68` · nessun `kBackMouseButton` · niente indietro/avanti col mouse · A/B/S · `Listener` nello shell: indietro → `back()`, avanti → pila di avanti per scheda. Da provare che i tasti 8/9 arrivino a Flutter con l'embedder GTK.
- F-206 · desktop · finestra senza memoria e titolo fisso · `linux/runner/my_application.cc:48-56` · sempre 1280x720, titolo «FreeKmusic» · M/B/M · salvare dimensione e posizione; titolo = brano in corso (canale nativo).
- F-207 · desktop · istanze multiple e nessuna associazione ai file · `my_application.cc:148` (`G_APPLICATION_NON_UNIQUE`), `.desktop` senza `MimeType` · due copie sullo stesso DB; «Apri con» un mp3 non funziona · M/M/M · istanza unica con inoltro degli argomenti, `MimeType=audio/*`, `Exec=… %U`.
- F-208 · desktop · niente trascinamento di file né icona nella tray · nessun pacchetto · M/B/M · servono pacchetti nuovi: solo con un sì.
- F-209 · desktop · scorciatoie mancanti · `app_shell.dart:90-135` · ci sono Spazio, Ctrl+←/→, Ctrl+↑/↓, Ctrl+F, Alt+← · mancano Alt+→, `/`, Ctrl+L, Backspace, F5, Ctrl+, (impostazioni), Ctrl+Q, `?` (elenco scorciatoie) · B/B/S.
- F-210 · test · nessuna prova d'integrazione desktop in CI · `.github/workflows/ci.yml:233-262` (solo Android, a mano) · regressioni di tastiera, mouse e layout viste solo a mano · A/B/M · job `integration-linux` su ogni PR (ubuntu-24.04, xvfb-run, pacchetti di build-linux), circa 12-15 min.
- F-211 · test · goldens desktop solo a scala 100/150 · `test/goldens/` · nessuna larghezza intermedia né stati hover/menu · M/B/S · goldens a 1000, 1440 e 1920 px per ogni schermata desktop.

## Comodità del PC oggi
| Comodità | Oggi | Dove |
|---|---|---|
| Tasti laterali del mouse | no | — |
| Alt+← indietro | sì | `app_shell.dart:130` |
| Spazio, Ctrl+←/→, tasti multimediali, Ctrl+↑/↓, Ctrl+F | sì | `app_shell.dart:90-129` |
| Esc chiude | in parte | `library_screen.dart:280`, `app_shell.dart:134` |
| Tasto destro | sulle righe brano e radio (apre il foglio, non un menu al puntatore) | `track_row.dart:527,690` |
| Hover e tooltip | in parte | `desktop_sidebar.dart:249,281`, `desktop_player_bar.dart:137` |
| Trascinare brani su una playlist della barra laterale | sì | `track_drag.dart:41` |
| Trascinare in coda / file dentro l'app | no | — |
| Selezione con Ctrl/Shift | sì | `track_row.dart:650-662` |
| Doppio clic | no (il clic singolo suona) | — |
| Finestra ricordata, tray, hotkey globali, titolo col brano | no | `my_application.cc` |
| MPRIS / SMTC | sì | `services/audio/mpris_*.dart`, `smtc_controls.dart` |
| Istanza unica, «Apri con» | no | `my_application.cc:148` |

## Test desktop oggi
- ~30 test widget con superfici desktop in `test/ui/` (`xl_layout_test`, `shell_keys_test`, `shell_nav_test`, `shell_tabs_test`); goldens `desktop_100_*` (~30) e `desktop_150_*` (~10).
- `integration_test/` (app_flow, playback, playlist, import, perf) gira solo su emulatore Android, a mano.
- Proposta: `integration_test/desktop_flow_test.dart` con `AppUnderTest` che visita ogni schermata dalla barra laterale, prova Ctrl+F, Alt+←, Spazio, il tasto laterale (`PointerDownEvent(buttons: kBackMouseButton)`), il tasto destro, e ridimensiona a 800, 840, 1440; in CI con `xvfb-run -a flutter test integration_test/… -d linux`.

## Non verificato
- Se i tasti 8/9 del mouse arrivano a Flutter con l'embedder GTK (solo `libflutter_linux_gtk.so` nell'SDK): prova a mano o in Xvfb.
- Tasto destro su card di album, artista e playlist; ordine del Tab; runner di Windows e macOS.
- Riproduzione nel flatpak senza ffmpeg-full (codec AAC).
