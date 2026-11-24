# Desktop e coerenza (refactor «ui») — analisi

> Giro 1 del `/refactor`, 24/11/2026. Richiesta originale: [`richiesta.md`](richiesta.md).
> Scansioni di dettaglio: [`scansione-telefono.md`](scansione-telefono.md) (F-01..F-20), [`scansione-desktop.md`](scansione-desktop.md) (F-101..F-120), [`scansione-input-flatpak-test.md`](scansione-input-flatpak-test.md) (F-201..F-216).

## Perimetro e punto di partenza
- **Tipo**: ui, più due punti di piattaforma (pacchetto flatpak, input del PC) e i test di sistema della UI desktop. I punti chiesti dall'utente sono cambi di comportamento voluti: ognuno va in `decisioni.md`.
- **Base**: versione 1.7.0+14, `master` a dd4f3e05, ultima decisione D-713, fasi aperte 147-149.
- **Telefono**: Mi A3 (prova, 720x1560, 2 px per dp). **Desktop**: Linux, release 1.7.0 su Xvfb (1440x900, 1920x1080, 900-1000 px) con una copia dei dati reali (2423 brani).
- **Misure di partenza desktop** (rendering software): avvio a freddo 4,4 s la prima volta e 2,3 s la seconda; RSS 434 MB all'avvio, 618 MB dopo la libreria; nessuna eccezione nel log.
- **Flatpak** (prova del 24/11 sul PC dell'utente): `flatpak info` dice 1.2.0 con la 1.7.0 installata; con `ffmpeg-full` l'app non parte; runtime 24.08 a fine vita.
- **Test desktop oggi**: ~30 test widget a superficie desktop, goldens a scala 100/150; nessuna prova d'integrazione desktop (solo Android, a mano).

## Rilievi in ordine di priorità
Formato: `F-NN · area · titolo · dove · prova · danno · impatto/rischio/costo · proposta`. Il dettaglio sta nelle scansioni; qui la riga breve.

### Priorità 1 — rotto o falso
- **F-212** · flatpak · non parte con `ffmpeg-full` (`Can't mkdir /app/lib/ffmpeg`) · A/B/S · `mkdir -p /app/lib/ffmpeg` nel manifesto e prova d'avvio del bundle in CI.
- **F-201** · flatpak · metainfo fermo a 1.2.0 (`metainfo.xml:14`) · A/B/S · `<release>` scritta dalla CI dal pubspec. Con F-203 (controllo pubspec = `kAppVersion` = metainfo in CI), F-202 (fdroid) e F-216 (nome del file senza versione).
- **F-08** · player · cuore nascosto per i brani in streaming nel player grande e nella barra desktop (`now_playing_screen.dart:661`, `desktop_player_bar.dart:180`); nel mini c'è · A/M/S · togliere la condizione (è il «non posso mettere like dal player grande»).
- **F-102** · desktop · tasto destro inerte sulle righe online (`online_song_row.dart:225`) · A/B/S.
- **F-205** · desktop · tasti laterali del mouse assenti · A/B/S · indietro/avanti nello shell; da provare che i tasti 8/9 arrivino a Flutter con GTK.

### Priorità 2 — chiesto dall'utente (telefono)
- **F-01** · icone coda e libreria quasi uguali (`queue_rounded` / `library_add_rounded`) · A/B/S.
- **F-20** · home · spazio sopra 20-34 dp, sotto 8-12 dp; «Tutti» alza l'intestazione di 14 dp (`section_header.dart:26,34`) · M/B/S · intestazione ad altezza fissa, spazio uguale sopra e sotto. Con F-14 (margini fra blocchi 8/12/16/24).
- **F-21** · home · «Riprendi» piatto: icone generiche, nessuna copertina, max 6 voci, doppione Daylist (`resume_rows.dart`, F-17) · A/B/M · copertine degli ultimi ascolti in un anello aperto (dati: `resumeItemsProvider`, `lastPlaysProvider`).
- **F-22** · home · «Nuove uscite» = una riga «Tutti» (`home_blocks.dart:~210`) · A/B/M · anteprima di alcuni artisti e uscite, «Tutti» nell'intestazione (`SectionHeader`, dati `recentReleasesProvider`).
- **F-23** · home · la pagina Playlist ha i pulsanti «Importa da Exportify» e «Nuova playlist» (`playlists_screen.dart:28-39`) · M/B/S · solo elenco da aprire (restano «+» in Libreria e barra laterale).
- **F-07** · album e playlist · cuore dei preferiti solo nel ⋮ e solo per le collezioni locali · A/B/M · cuore accanto a Condividi in `CollectionScaffold`; da estendere alle pagine online (F-06, F-11).

### Priorità 3 — incongruenze dello stesso tipo
- **F-06 / F-11** · album e playlist online con un'intestazione diversa e senza Condividi in vista · A/M/M.
- **F-09** · mini, player grande e barra desktop con azioni diverse (timer e karaoke assenti sul desktop) · M/B/M.
- **F-02, F-03, F-04, F-05, F-12** · stessa azione con icone o testi diversi; stessa icona con significati diversi (`queue_music_rounded` vale 5 cose) · M/B/S · una tabella azione → icona → testo.
- **F-13** · «Tutti» in tre forme · M/B/S.
- **F-15, F-16** · scorciatoie e righe playlist con due design · M/B/S-M.
- **F-10** · etichette solo su alcuni tasti del player · B/B/S.
- **F-18, F-19** · stati vuoti e titoli di sezione fuori standard · B/B/S.
- **F-215** · curiosità che ritentano ogni 3 s durante la pausa di MusicBrainz · M/B/S (fuori dalla UI, trovato nel log).

### Priorità 4 — schermate desktop
- **F-101 / F-103** · menu e fogli da telefono (foglio dal basso anche col tasto destro) · A/M/M · menu sotto il puntatore, dialoghi e popover.
- **F-104 / F-105** · liste a colonna unica larghe 1170 px; Tutti i brani senza intestazioni ordinabili · A/B/M · tabella dei brani unica.
- **F-107** · home a blocchi sfalsati e metà vuota · A/B/M.
- **F-111** · player a tutto schermo con schede vuote e anello come barra di posizione · A/M/M.
- **F-115** · focus da tastiera invisibile · A/B/M.
- **F-106, F-108, F-109, F-110, F-112, F-113, F-114, F-116, F-117, F-118, F-119, F-120** · margini, libreria, testate, pannello che si apre da solo, impostazioni da telefono, scaffali, tooltip, contrasto, indicatore attività, vuoti, selezione · M/B/S-M.

### Priorità 5 — comodità del PC e pacchetto
- **F-209** · scorciatoie mancanti (Alt+→, `/`, Ctrl+L, Ctrl+,, Ctrl+Q, `?`) · B/B/S.
- **F-206** · finestra non ricorda dimensione e posizione; titolo fisso · M/B/M.
- **F-207** · istanze multiple sullo stesso DB, nessun «Apri con» · M/M/M.
- **F-208** · trascinare file nell'app, icona nella tray · M/B/M · **pacchetti nuovi**: solo con un sì.
- **F-213** · runtime flatpak 24.08 a fine vita · M/M/M.
- **F-214** · cartelle dati diverse fra flatpak e AppImage/deb · M/B/S.
- **F-204** · il flatpak non si aggiorna dall'app · M/B/M.

### Priorità 6 — test di sistema desktop
- **F-210** · nessuna prova d'integrazione desktop in CI · A/B/M · `integration_test/desktop_flow_test.dart` su Linux con `xvfb-run` a ogni PR (~12-15 min): ogni schermata, scorciatoie, tasti del mouse, tasto destro, ridimensionamento.
- **F-211** · goldens desktop solo a scala 100/150 · M/B/S · goldens a 1000, 1440 e 1920 px per schermata.

## Sintesi per area
- **Telefono**: le richieste sono tutte fondate. Il cuore del player grande c'è, ma sparisce coi brani in streaming (F-08). Il resto è uniformità: icone, intestazioni, «Tutti», blocchi della home.
- **Desktop**: la struttura c'è (barra laterale, pannelli, barra del player). Sono rimasti da telefono i fogli e i menu, le liste a colonna unica, la home, il player e il focus.
- **Pacchetto**: il flatpak ha un difetto che lo blocca (F-212) e mente sulla versione (F-201). Le altre versioni sono già generate dal pubspec.
- **Test**: nessuna prova automatica dell'app desktop intera; è la lacuna che spiega le regressioni viste solo a mano.

## Scelte (giro 2)
Decisioni D-714..D-722.
- **Entrano tutti i rilievi** F-01..F-23, F-101..F-120, F-201..F-216, salvo quelli già chiusi dalla PR #231 (F-201, F-203, F-212, F-216; F-202 fdroid resta: bozza non pubblicata, si aggiorna col controllo di versione).
- **Audacia** (D-720): una variante da PC per schermata sopra la stessa logica; il telefono cambia solo nei punti scelti.
- **Intoccabili** (D-721): schema del DB (nessuna migrazione), backup, sync, Jam; gesti e navigazione del telefono. Tema, colori e scorciatoie esistenti possono cambiare.
- **Vincoli**: pacchetti nuovi solo per F-208 (trascinamento di file, tray), da verificare nel giro 3; i dati per il cuore delle collezioni ci sono già (`favorite_collections_providers.dart`).
- **Test** (D-719): integrazione Linux sotto `xvfb-run` a ogni PR, goldens desktop a 1000, 1440, 1920 px.
- **Rimandati / scartati**: nessuno.

## Arrivo (giro 3)
Decisioni D-723..D-732. Specifica visiva: [`mockup/index.html`](mockup/index.html), approvata (D-731).
- **Direzione** «Copertine al centro» (D-723, D-730): fondo sempre indaco scuro `#07050C`, superfici `#120E1C/#1D1630/#2A2140`, viola solo su play, selezione, stato e focus; le copertine portano il colore. Unico token cambiato: `textMuted` → `#B3AAC2`. Token in `mockup/tokens.css` (stessi nomi di `CcColors`/`CcDims`), contrasti verificati (testo ≥ 13,4:1, secondario ≥ 6,8:1, tenue ≥ 5,1:1).
- **Ritmo**: sezioni 24 dp sopra e sotto sul telefono, 32 px sul desktop; intestazione di sezione ad altezza fissa con «Tutti» sempre lì.
- **Desktop** (D-720): variante da PC per schermata, griglia a 12 colonne, larghezza massima 1136 px e margini 32 px uguali per tutte le pagine, testo minimo 13 px, bersagli 36 px, anello di focus 2 px.
- **Pacchetti** (D-727, D-728): `window_manager`, `tray_manager ^0.8.3`, `desktop_drop` dopo l'aggiornamento di Flutter all'ultima 3.47.x; istanza unica e «Apri con» nel runner.
- **Mockup per area**: home (telefono-home, desktop-home); player (telefono-player, desktop-player); collezioni (telefono-collezioni, desktop-collezioni); azioni e icone (telefono-azioni, index); coerenza (telefono-coerenza); libreria, brani, cerca, menu e dialoghi, impostazioni, ascolto, altro (desktop-*). I file `*-extra.css` e `icons-*.svg` dei tre gruppi vanno uniti a `mockup.css`/`icons.svg` solo se si ritoccano i mockup: per `/obiettivo` valgono così.

## Rete (giro 4)
Dettaglio in [`rete.md`](rete.md) (D-733, D-734): caratterizzazione prima di ogni area, goldens desktop a 1000/1440/1920 px, `integration_test/desktop_flow_test.dart` sotto Xvfb a ogni PR (facoltativo per 2 settimane, poi obbligatorio), soglie su avvio, memoria e accessibilità.
