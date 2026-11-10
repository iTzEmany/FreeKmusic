# Fase 11 — Interfaccia nuova (nero e viola)

**Obiettivo:** rifare l'interfaccia perché sia **comoda come Spotify** (non uguale) e con un'identità propria
nero/viola. Oggi l'app è Material 3 di serie (`fromSeed`, font di sistema, widget standard) e ha tre difetti
strutturali: (1) aprendo album/artista/playlist spariscono mini-player e barra di navigazione; (2) nomi e
copertine non portano da nessuna parte (niente «Vai all'artista/album»); (3) la navigazione segue le tabelle
del DB invece di cosa fa l'utente (5 schede, niente Home, ricerca solo sui brani, Jam nascosta nelle impostazioni).
**Prerequisiti:** Fasi 3–10. Nessuna modifica allo schema DB, nessun pacchetto nuovo (i font sono asset).

## Decisioni (confermate dall'utente il 2026-10-15)
| Tema | Decisione |
|---|---|
| Temi | Solo scuri: `notte` (Notte viola, **predefinito**) e `oled` (Nero puro). Via `carbon`, `navy`, `light`: un valore salvato fra questi diventa `notte`. |
| Navigazione | 3 schede: **Home · Cerca · Libreria**, etichette sempre visibili. Impostazioni = ingranaggio nell'intestazione di Home. Preferiti = elemento fissato in Libreria. Playlist = filtro della Libreria. |
| YouTube | **Dentro Cerca**, come chip «YouTube» accanto a «Libreria» (solo se `kEnableYoutube`). Niente scheda propria. |
| Jam e invio | **Bottone «Dispositivi»** (mini-player, Now Playing, barra player desktop) → foglio con Jam attiva e dispositivi vicini ([Jam] [Invia]). |
| Font | **Figtree** (testo e interfaccia) + **Unbounded** (solo titoli di pagina e nomi grandi). Entrambi OFL, inclusi in `assets/fonts/` con le licenze. |
| Colore dalla copertina | Calcolato in casa con `dart:ui` (immagine decodificata a 24 px), nessun pacchetto. |
| Contesto di riproduzione | «Da: Album X / Playlist Y / Preferiti / Ricerca» in memoria (non persistito). |
| Rete | Invariato (`01` §9): YouTube cerca **solo all'invio**, le curiosità Wikipedia si cercano solo con un tocco dell'utente. |

## Sistema visivo (token)
Tutti i valori stanno in `lib/ui/theme/tokens.dart` + una `ThemeExtension` (`CcColors`). Nei widget **nessun
esadecimale**: solo `Theme.of(context).colorScheme` / `context.cc` (estensione).

| Token | Notte viola | Nero puro | Uso |
|---|---|---|---|
| `bg` | `#07050C` | `#000000` | sfondo, `surface`, `surfaceContainerLowest` |
| `surface1` «Inchiostro» | `#120E1C` | `#120E1C` | barra in basso, card, mini-player, fogli, dialoghi |
| `surface2` «Prugna» | `#1D1630` | `#1D1630` | ricerca, chip, hover, menu, snackbar |
| `surface3` | `#2A2140` | `#2A2140` | premuto, divisori, placeholder copertina |
| `accent` «Ametista» | `#A06BFF` | = | play, brano corrente, stati attivi, chip selezionato |
| `accentSoft` «Lilla» | `#D9C8FF` | = | link, tag qualità, azione snackbar |
| `onAccent` | `#12081F` | = | icone/testo su Ametista |
| `text` | `#F4F0FA` | = | testo principale |
| `textMuted` «Nebbia» | `#A79DB8` | = | testo secondario (≥ 4.5:1 su bg, surface1, surface2) |
| `textFaint` | `#6E6680` | = | solo disabilitati e testi ≥ 18 px |
| `heroBase` | `#3B1F70` | = | base delle sfumature (senza copertina) |
| `error` | `#FF6B81` | = | errori |

**Tipografia** (sentence case ovunque, mai tutto maiuscolo):
| Ruolo (TextTheme) | Font | Dimensione/peso | Dove |
|---|---|---|---|
| `displaySmall` | Unbounded | 30 / 700, interlinea 1.1 | nome grande di album, playlist, artista (max 2 righe, scende a 24) |
| `headlineSmall` | Unbounded | 24 / 600 | titolo di pagina (Home, Cerca, Libreria, Jam) |
| `titleLarge` | Figtree | 22 / 700 | titolo in Now Playing |
| `titleMedium` | Figtree | 18 / 700 | titoli di sezione («Aggiunti di recente») |
| `bodyLarge` | Figtree | 15 / 600 | titolo nelle righe |
| `bodyMedium` | Figtree | 13 / 400, `textMuted` | sottotitoli, artista |
| `labelSmall` | Figtree | 12 / 500, cifre tabulari | tempi, meta, tag |
| `labelLarge` | Figtree | 14 / 700 | bottoni, chip |

**Forme:** 4 copertine in lista e tag · 8 copertine in griglia, tile Home, menu, snackbar · 12 mini-player e card ·
16 bordo alto di fogli e dialoghi · pillola: bottoni, ricerca, chip · cerchio: artisti, play.
**Spazi:** multipli di 4; margine laterale unico **16**. **Altezze:** riga brano `trackRowExtent` (64 / 52 compatta),
mini-player 56 (+8 di margine), barra in basso 56, barra player desktop 80, barra laterale 240, pannello destro 320.
**Movimento:** 150 ms hover/pressione, 250 ms fogli/chip, 400 ms cambi di colore; tutto a 0 con «Riduci animazioni».
L'unico momento animato curato: mini-player → Now Playing (copertina `Hero` + sfumatura che entra).

## Principi
1. **Il colore lo dà la musica**: la sfumatura dalla copertina c'è solo in Now Playing, Testi e intestazioni di
   album/playlist/artista. Il resto è nero/viola sobrio.
2. **Il player non sparisce mai** (navigatore annidato per scheda).
3. **Un tocco per suonare**: ogni raccolta ha Play (cerchio) e Casuale.
4. **Ogni nome è un link** (artista → pagina artista, album → pagina album).
5. **Una sola riga brano** in tutta l'app (`TrackRow`).
6. **Il desktop non è un telefono allargato**: barra laterale, barra player completa, clic destro, hover.
7. La **qualità audio** (FLAC 24/96, «Hi-Res») è parte dell'identità: tag lilla piccolo, non un riquadro grigio.
8. Le varianti di layout dipendono dalla **larghezza** (≥ 840 = desktop), non dalla piattaforma.

## Regole della fase
- Ogni task: `flutter analyze` + `flutter test` verdi **e** scatti aggiornati con `scripts/shots.sh` (task 11.1):
  apri i PNG con lo strumento di lettura immagini e confrontali con i token prima di spuntare.
- **Prova su telefono** (procedura `.claude/skills/obiettivo/SKILL.md` §6.1: `flutter run` in background,
  hot reload con `kill -USR1`, screenshot con `adb exec-out screencap`, gesti con `adb shell input`): obbligatoria
  dove il task la indica con «Telefono:», facoltativa altrove. Gli scatti da test restano il controllo di ogni
  task; il telefono serve per gesti, navigazione e dati veri. Se il telefono non c'è o è bloccato: salta e
  scrivi la prova in «Tocca a te» (task `[~]`). Mai disinstallare l'app né toccare i dati dell'utente.
- I test UI esistenti (`test/ui/*`) si **aggiornano**, non si cancellano: il loro scopo (testo al 150% senza
  overflow, contrasto, scorciatoie, Jam) resta valido.
- Tutti i testi nuovi negli ARB it/en/de/es. Glossario fisso: Home, Cerca, Libreria, Preferiti, Tutti i brani,
  Dispositivi, Jam, Coda, Prossimi, Testo, Info sul brano, Attività. Un'azione ha lo stesso nome nel bottone e nel
  messaggio: «Aggiungi in coda» → «Aggiunto in coda»; «Riproduci dopo» → «Verrà riprodotto dopo».
- Prestazioni `01` §8 invariate: liste brani con `itemExtent`, copertine con `cacheWidth`, la posizione ricostruisce
  solo i widget slider/tempo.

## Task

### 11.1 — Banco visivo (scatti da test)
**File:** `test_shots/support/shot_harness.dart`, `test_shots/shots_test.dart`, `scripts/shots.sh`, `.gitignore`
1. Cartella `test_shots/` **fuori da `test/`** (non gira con `flutter test`). Riusa `test/support/app_harness.dart`.
2. Font reali: leggi `FontManifest.json` da `rootBundle` e carica ogni famiglia con `FontLoader` (include
   `MaterialIcons`); fallback icone: `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`.
3. Dati realistici nel DB in memoria: ~40 brani (titoli/artisti veri e misti it/en, uno lungo 80 caratteri),
   8 album (uno multi-disco, una compilation), 3 artisti con più album, 2 playlist, 6 preferiti, `playCount`/
   `lastPlayedAt`/`addedAt` vari, un FLAC 24/96, testo sincronizzato e una curiosità su un brano.
4. Copertine: PNG generati in `tester.runAsync` con `ui.PictureRecorder` (sfumature di colori diversi, una
   quasi nera, una quasi bianca), scritti nella `coversDir` temporanea; `precacheImage(FileImage(...))` in
   `runAsync` prima dell'ultimo `pump`.
5. `debugDisableShadows = false` (ombre vere); niente `pumpAndSettle` con animazioni infinite: `pump(500 ms)`.
6. Due misure: telefono 360×800 (dpr 2) e desktop 1280×800 (dpr 1); un `testWidgets` per schermata con
   `expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/<misura>_<schermata>.png'))`.
7. `scripts/shots.sh [filtro]` = `flutter test test_shots --update-goldens [--plain-name filtro]`; stampa i PNG.
   `test_shots/goldens/` in `.gitignore`.
8. In questo task scatta lo **stato attuale** (libreria, album, now playing, impostazioni, jam): è il «prima».
**Verifica:** `scripts/shots.sh` produce i PNG; aprendoli si leggono testi e icone (non quadratini).

### 11.2 — Token, tema e font
**File:** `lib/ui/theme/tokens.dart` (nuovo), `lib/ui/theme/app_theme.dart`, `pubspec.yaml`, `assets/fonts/`,
`lib/main.dart` (licenze), `lib/data/settings/settings_store.dart`, `lib/ui/screens/settings/settings_screen.dart`,
ARB, `test/ui/contrast_test.dart`, `test/data/settings_store_test.dart`
1. Font: dal repository `google/fonts` (cartelle `ofl/figtree`, `ofl/unbounded`) prendi i TTF e `OFL.txt`.
   Preferisci file statici per peso; se esistono solo i variabili `[wght]`, dichiara un file per famiglia e in
   **ogni** stile imposta sia `fontWeight` sia `fontVariations: [FontVariation.weight(w)]` (helper unico).
   Senza rete: annota in «Tocca a te» dove scaricarli e prosegui (il tema ricade sul font di sistema).
   Registra le due OFL con `LicenseRegistry.addLicense`.
2. `AppThemeId { notte, oled }`; nomi salvati sconosciuti/vecchi → `notte`; predefinito `notte`.
3. `buildTheme`: `ColorScheme` scritto a mano dai token (niente `fromSeed`), `fontFamily: 'Figtree'`,
   `TextTheme` della tabella, `ThemeExtension CcColors` (+ `extension on BuildContext { CcColors get cc }`).
4. Temi dei componenti: SnackBar fluttuante (surface2, raggio 8, azione Lilla); BottomSheet (surface1, raggio 16
   in alto, `showDragHandle: true`); Dialog (surface1, raggio 16); InputDecoration (pieno surface2, senza bordo,
   pillola, denso); Filled/Outlined/TextButton a pillola, `labelLarge`; Chip a pillola (selezionato Ametista con
   `onAccent`); Slider (traccia 4, pallino 6, attivo `text`, inattivo `text` 24%, overlay piccolo); ListTile
   (padding 16, icone `textMuted`); PopupMenu (surface2, raggio 8); ProgressIndicator (Ametista su surface3);
   Switch (traccia Ametista quando acceso); Scrollbar (Nebbia 40%, arrotondata); `focusColor` Ametista 24%.
5. Impostazioni → Tema: due campioni (quadrato bg + puntino Ametista + nome) al posto del `SegmentedButton`.
   ARB: «Notte viola», «Nero puro»; rimuovi le stringhe dei temi tolti.
6. `contrast_test`: coppie text/bg, textMuted/bg|surface1|surface2, accent/bg, onAccent/accent, accentSoft/surface1
   ≥ 4.5 per entrambi i temi. Test di migrazione `carbon|navy|light → notte`.
**Verifica:** test verdi; scatti: impostazioni e libreria mostrano Figtree, superfici distinguibili dallo sfondo.

### 11.3 — Componenti base
**File:** `lib/ui/widgets/`: `track_row.dart` (sostituisce `track_tile.dart`), `cover_image.dart`,
`artist_avatar.dart`, `playlist_cover.dart`, `play_buttons.dart`, `section_header.dart`, `now_playing_bars.dart`,
`quality_tag.dart` (sostituisce `quality_badge.dart`), `error_state.dart`, `empty_state.dart`, `confirm.dart`
1. `TrackRow(track, variant)` con varianti `standard`, `album` (numero traccia al posto della copertina, artista
   solo se diverso da quello dell'album), `queue` (maniglia ≡), `pick` (cerchio ＋/✓ a destra).
   - Stretto (< 840): copertina 48 (r4) · titolo `bodyLarge` / «artista · album» `bodyMedium` · cuore pieno
     Ametista 16 **solo se preferito** · ⋮. Niente durata.
   - Largo (≥ 840): colonne # · titolo/artista · album · durata; cuore e ⋯ visibili su hover o se preferito;
     sfondo hover surface2 50%.
   - Corrente: titolo Ametista + `NowPlayingBars` sopra la copertina (scrim 50%); barre ferme in pausa o con
     «Riduci animazioni» (`CustomPainter`, 3 barre).
   - Tocco = suona; pressione lunga = menu azioni; clic destro = menu al puntatore (vedi 11.14).
   - `LiveTrackTile` diventa `LiveTrackRow` (stesso principio: osserva solo l'id corrente).
2. `CoverImage`: raggio dai token, `heroTag` opzionale, placeholder surface3 con nota `textMuted`.
3. `ArtistAvatar`: cerchio con la copertina dell'album più presente; altrimenti monogramma (1–2 iniziali) su
   sfumatura con tinta ricavata dall'hash del nome, limitata a 250–320° (viola–magenta–blu), scura.
4. `PlaylistCover`: copertina personalizzata, altrimenti mosaico 2×2 delle prime 4 copertine distinte
   (1–3 copertine → la prima a tutto riquadro; 0 → icona su surface3). Variante `favorites`: sfumatura
   Ametista → heroBase con cuore bianco.
5. `PlayCircleButton` (56/64/36, Ametista, icona `onAccent`), `ShuffleButton` (icona con puntino se attivo).
6. `QualityTag`: testo `labelSmall` Lilla su Ametista 16%, raggio 4; «Hi-Res» se ≥ 24 bit o > 48 kHz, poi il dettaglio.
7. `ErrorState(message, onRetry)` (l'eccezione va in `AppLog`, mai a schermo); `EmptyState` ristilizzato.
8. `confirm.dart`: `showConfirm(context, title, body, confirmLabel, {destructive})` e
   `showUndoSnack(context, text, onUndo)` (3 s, `persist: false`).
**Verifica:** widget test di `TrackRow` (corrente → barre; preferito → cuore; variante album → numero),
`ArtistAvatar` (monogramma deterministico), `PlaylistCover` (0/1/4 copertine); scatto «componenti».

### 11.4 — Correzioni rapide
**File:** indicati per voce. Una riga in PROGRESS per voce non fatta.
1. Dialogo nome con titolo/etichetta come parametri: rinomina playlist e nome dispositivo non dicono più
   «Nuova playlist» (`playlist_dialogs.dart:46`, `settings_screen.dart:229`).
2. Conferma prima di: eliminare playlist (`playlist_detail_screen.dart:99`), rimuovere cartella, svuotare la
   cache copertine, «Ripristina dal file».
3. Swipe che rimuove (playlist, coda): sfondo con icona + `showUndoSnack`.
4. Coda: chiave stabile per voce, non dipendente dall'indice (`queue_sheet.dart:28`).
5. «Riproduci dopo» → «Verrà riprodotto dopo» (`track_actions_sheet.dart:61`).
6. `Text('$e')` → `ErrorState` + `AppLog.e` (tracks/albums/artists tab, album detail, playlists).
7. Inviate: «N brani · stato» (`send_tab.dart:184`); aperta senza brani iniziali, la selezione parte da
   «Scegli brani» invece di «Tutta la libreria».
8. Volume da tastiera: `Ctrl+↑/↓` invece di `↑/↓` (`app_shell.dart:70`); aggiorna il test delle scorciatoie.
9. YouTube: `Image.network` con `cacheWidth`; prima di cercare non dire «Nessun risultato» ma
   «Cerca un brano o incolla un link».
10. Jam: la posizione si aggiorna in un widget proprio con il suo timer; la schermata non si ricostruisce ogni 500 ms.
11. Ricevi: elenco brani remoti costruito man mano (`CustomScrollView` + `SliverList.builder`).
12. Impostazioni: «Brani non trovati» solo se > 0; via la riga «App per uso personale».
**Verifica:** test verdi (aggiungi test per 1, 2 su playlist, 7); scatti invariati salvo i punti toccati.

### 11.5 — Shell: tre schede e navigatore annidato
**File:** `lib/ui/shell/app_shell.dart`, `lib/ui/shell/shell_nav.dart` (nuovo), `lib/ui/shell/bottom_bar.dart`
(nuovo), `lib/providers/nav_providers.dart`, `test/ui/app_shell_test.dart`
1. Schede `home`, `search`, `library`, ciascuna con il proprio `Navigator` (GlobalKey) dentro `IndexedStack`.
   Album, artista, playlist, Preferiti, Tutti i brani, Impostazioni si aprono **nel navigatore della scheda**.
2. `ShellNav` (helper): `open(context, page)` nella scheda corrente; `openInLibrary(context, page)` chiude le
   rotte del navigatore principale (Now Playing, Testi), passa a Libreria e apre la pagina; toccare la scheda
   attiva torna alla radice; indietro di Android: prima il navigatore annidato, poi Home, poi esce.
3. Mobile: `bottomNavigationBar` = `Column[MiniPlayer, BottomBar]` → le snackbar fluttuanti stanno **sopra** il
   mini-player. `BottomBar` 56 px, sfondo bg 94%, icone `*_rounded` (contorno / piena se selezionata), etichetta
   11/600 sempre visibile, selezionata `text`, altre `textMuted`, nessuna pillola.
4. Now Playing, Testi, dialoghi e fogli restano sul navigatore principale (coprono tutto).
5. Home in questo task è un segnaposto con titolo, ingranaggio (→ Impostazioni) e le scorciatoie Preferiti /
   Tutti i brani; Cerca contiene l'attuale ricerca brani; Libreria l'attuale `LibraryScreen` (rifatte in 11.10–11.13).
   La scheda YouTube sparisce (il widget resta per 11.13). `Ctrl+F` → scheda Cerca con focus.
**Verifica:** test: 3 schede; dopo aver aperto un album il mini-player e la barra sono ancora visibili; indietro
chiude prima l'album. Scatti telefono.
**Telefono:** Libreria → album → artista con mini-player visibile in ogni screenshot; `KEYCODE_BACK` ripetuto
torna indietro di una pagina alla volta, poi a Home, poi esce; tocco sulla scheda attiva torna alla radice.

### 11.6 — Colore dalla copertina
**File:** `lib/ui/theme/cover_tint.dart` (nuovo), `lib/ui/widgets/cover_backdrop.dart` (nuovo), test
1. Funzione pura `Color? tintFromPixels(Uint8List rgba)`: media pesata per saturazione, ignorando pixel quasi
   neri/bianchi; `null` se non c'è colore utile.
2. `heroTint(Color c)`: `lerp` verso `heroBase` al 45%, luminosità HSL limitata a 0.16–0.30 (il testo `text` ha
   sempre contrasto ≥ 7:1).
3. `coverTintProvider` (family per `coverKey`, mantenuto vivo): legge il file da `coverFileProvider`, decodifica
   con `ui.instantiateImageCodec(bytes, targetWidth: 24)`, `toByteData(rawRgba)`; senza copertina → `heroBase`.
4. `CoverBackdrop(coverKey, child)`: sfumatura verticale tinta → bg (60% dell'altezza), transizione 400 ms.
**Verifica:** test di `tintFromPixels` (rosso → tinta rossa-viola nei limiti; tutto nero → null; contrasto ≥ 7).

### 11.7 — Mini-player e foglio Dispositivi
**File:** `lib/ui/widgets/mini_player.dart`, `lib/ui/screens/devices/devices_sheet.dart` (nuovo),
`lib/ui/screens/devices/peer_card.dart` (nuovo), `lib/providers/share_hub.dart` (solo se serve un helper di invio)
1. Mini-player: card con margine 8 e raggio 12, sfondo `heroTint` della copertina (surface1 se manca);
   copertina 40 (r4, `heroTag`) · titolo 14/600 · artista `bodyMedium` · **Dispositivi** · **cuore** · play/pausa.
   Avanzamento 2 px in basso dentro la card. Swipe orizzontale: il contenuto segue il dito, oltre soglia scorre
   via e cambia brano (con animazione); swipe in su o tocco → Now Playing.
2. Modalità Jam (Jam attiva): titolo/artista del brano della Jam, etichetta «Jam · N persone» con puntino
   Ametista, play/pausa invia `JamCommand`, tocco → `JamScreen`.
3. `DevicesSheet`: chiama `hub.enter()` all'apertura e `leave()` alla chiusura (come `ShareScreen`). Sezioni:
   «Jam attiva» (partecipanti, Apri, Esci/Termina) se presente; «Dispositivi vicini»: `PeerCard` (icona
   piattaforma, nome, IP piccolo, bottoni corti [Jam] [Invia]); se la ricezione è spenta e non c'è nessuno:
   spiegazione + interruttore «Rendi visibile questo dispositivo»; in fondo «Collegamento manuale (IP e PIN)» → `ShareScreen`.
4. Aperto con brani preselezionati (`DevicesSheet.show(context, tracks: [...])`), [Invia] li manda subito;
   senza, apre il selettore. «Condividi…» del menu brano e del menu album aprono questo foglio.
**Verifica:** widget test: mini-player con cuore e Dispositivi; il foglio si apre e mostra lo stato «nessun
dispositivo». Scatti: mini-player normale e in modalità Jam, foglio Dispositivi.
**Telefono:** swipe orizzontale sul mini-player (con `input swipe` lento e veloce: sotto soglia torna al posto,
oltre cambia brano), swipe in su apre Now Playing, il foglio Dispositivi si apre e si chiude (non avviare Jam né invii).

### 11.8 — Now Playing
**File:** `lib/ui/screens/now_playing/now_playing_screen.dart` (+ sotto-widget in file separati),
`lib/providers/player_providers.dart` (contesto), chiamanti di `playFromList`
1. `PlayContext(kind, name)` e `playFromList(list, i, {PlayContext? context})`; `playContextProvider` in memoria;
   aggiorna i chiamanti (album, artista, playlist, preferiti, tutti i brani, ricerca, home).
2. Rotta con trascinamento in giù per chiudere (oltre 120 px o velocità alta), `Hero` della copertina dal
   mini-player, sfondo `CoverBackdrop`.
3. In alto: ⌄ · «In riproduzione da» (11, `textMuted`) + nome del contesto (13/600) · ⋯ (menu azioni del brano).
4. Copertina grande (raggio 8, swipe sinistra/destra = brano successivo/precedente).
5. Riga titolo: titolo `titleLarge` a sinistra (1 riga) / artista sotto come link (`ShellNav.openInLibrary` →
   pagina artista, usando la stessa normalizzazione di `watchArtists`) · cuore a destra.
6. Seek con il tema slider; riga tempi: trascorso · `QualityTag` · totale (tocco → rimanente). Cifre tabulari.
7. Comandi: casuale (puntino se attivo) · precedente 36 · `PlayCircleButton` 64 · successivo 36 · ripeti
   (puntino; icona `repeat_one`).
8. Riga in basso: Dispositivi (a sinistra; «Jam» se attiva) · Timer (chip «☾ 23′» col tempo rimanente da
   `endsAt`, «☾ fine brano», menu attuale) · Coda (a destra).
9. Sotto (scorrendo): card **Testo** (5 righe sincronizzate attorno alla corrente; tocco → Testi; senza testo:
   «Cerca testo»), card **Info sul brano** (curiosità 6 righe + «Fonte: Wikipedia» + copia link; senza: bottone
   «Cerca curiosità», nessuna ricerca automatica), card **Prossimi in coda** (3 brani + «Apri coda»).
10. Largo (≥ 900): due colonne, player a sinistra, Testo/Info a destra. Volume su desktop come oggi.
**Verifica:** `now_playing_test` aggiornato (cuore nella riga del titolo, contesto mostrato, tocco artista →
pagina artista nella Libreria). Scatti telefono e desktop, con e senza copertina.
**Telefono:** apertura dal mini-player (Hero), trascina giù per chiudere, swipe sulla copertina, tocco
sull'artista, scorrimento fino alle card Testo/Info/Prossimi; screenshot con copertine chiare e scure della
libreria vera (leggibilità del testo sulla sfumatura).

### 11.9 — Desktop: barra laterale, barra player, pannello destro
**File:** `lib/ui/shell/desktop_sidebar.dart`, `lib/ui/shell/desktop_player_bar.dart`,
`lib/ui/shell/side_panel.dart` (nuovi), `app_shell.dart`
1. Barra laterale 240 (sotto i 1000 px solo icone, 72): Home, Cerca; «La tua libreria» con ＋ (nuova playlist);
   Preferiti fissato; elenco playlist (copertina 40 + nome + «Playlist · N brani»), che aprono nella Libreria.
2. Barra player 80 a tutta larghezza in basso (al posto del mini-player): a sinistra copertina 56 (clic →
   Now Playing), titolo/artista come link, cuore; al centro comandi (play 36) + seek con tempi; a destra
   Testo, Coda, Dispositivi, muto + volume 120 px. Modalità Jam come il mini-player.
3. Pannello destro 320 apribile da Testo/Coda: mostra Coda, Testo o Info (stessi widget di 11.8/11.14).
4. Niente `NavigationRail`. Scorciatoie invariate (con `Ctrl+↑/↓`).
**Verifica:** test a 1280 px: barra laterale + barra player, nessun mini-player; il pannello si apre. Scatti desktop.

### 11.10 — Libreria e «Tutti i brani»
**File:** `lib/ui/screens/library/library_screen.dart`, `all_tracks_screen.dart` (nuovo, dall'attuale
`tracks_tab.dart`), `lib/data/repositories/library_queries.dart` (+ test), `settings_store.dart`
1. Intestazione «Libreria» (`headlineSmall`) + Cerca (→ scheda Cerca) + ＋ (nuova playlist) + ⋯ (Cartelle musicali,
   Aggiorna libreria, Condivisione). Il bottone cartelle esce dalle liste brani e da Preferiti.
2. Chip Playlist · Album · Artisti (nessuno = tutto); chip ordinamento «Recenti | Alfabetico | Aggiunti di recente»;
   interruttore lista/griglia (ricordati in `SettingsStore`).
3. In cima, fissati: **Preferiti** (`PlaylistCover.favorites`, «Playlist · N brani») e **Tutti i brani** («N brani»).
   Poi playlist, album, artisti mescolati e ordinati. Query nuove: recenti = max `lastPlayedAt` per album/artista/
   playlist (tramite i suoi brani), aggiunti = max `addedAt`. Righe 64 con sottotitolo «Album · Artista», «Artista»,
   «Playlist · 12 brani»; artisti tondi. Griglia: 2–3 colonne su telefono, `maxCrossAxisExtent` 180 su desktop.
4. «Tutti i brani»: intestazione con conteggio, ricerca a pillola, chip ordinamento, `ShuffleButton` + `PlayCircleButton`,
   lista di `LiveTrackRow`. Stato vuoto senza cartelle: «Aggiungi la tua cartella musicale» (anche in Libreria).
**Verifica:** test delle query (DB in memoria); widget test: elementi fissati presenti, i chip filtrano. Scatti lista e griglia.

### 11.11 — Pagine di raccolta: album, artista, playlist, Preferiti
**File:** `lib/ui/widgets/collection_header.dart` (nuovo), `album_detail_screen.dart`, `artists_tab.dart` →
`artist_screen.dart`, `playlist_detail_screen.dart`, `favorites_screen.dart` (nuovo), `add_tracks_screen.dart`,
`playlist_dialogs.dart`, `library_queries.dart` / `playlist_repository.dart` (+ test)
1. `CollectionHeader` in un `CustomScrollView`: sfondo `CoverBackdrop`; copertina centrata (60% della larghezza,
   max 280) su telefono, a sinistra (232) su desktop; nome `displaySmall`; riga meta; azioni: a sinistra ⋯, a destra
   `ShuffleButton` + `PlayCircleButton` 56. Barra in alto fissata con il titolo che compare scorrendo.
2. Album: «Artista» come link · «Album · 2019 · 12 brani, 48 min»; righe variante `album`; con più dischi
   intestazioni «Disco 1/2»; ⋯: Aggiungi in coda, Aggiungi a playlist, Condividi (→ Dispositivi), Arricchisci album.
3. Artista: `ArtistAvatar` 160, «N album · M brani», Play/Casuale su tutti i suoi brani (query nuova),
   «Più ascoltati» (top 5 con `playCount` > 0, sezione nascosta se vuota), «Album» in griglia.
4. Playlist: `PlaylistCover`, «Playlist · N brani, durata»; righe `LiveTrackRow` (⋮ con «Rimuovi dalla playlist»);
   ⋯: Modifica ordine (modalità con maniglie ≡ e ✕), Aggiungi brani, Cambia/Rimuovi copertina (la seconda solo se
   c'è), Rinomina, Elimina (con conferma). Vuota: stato vuoto con «Aggiungi brani».
5. Preferiti: stessa intestazione con `PlaylistCover.favorites`, ordinamento, nessun bottone cartelle.
6. Aggiungi brani: righe variante `pick`; barra fissa in basso con «Aggiungi N brani».
7. Foglio «Aggiungi a playlist»: `PlaylistCover` 40 + nome + conteggio; ✓ sulle playlist che contengono già il brano.
**Verifica:** test delle query nuove; widget test di ogni pagina (si costruisce, Play presente, artista toccabile).
Scatti di tutte e quattro, telefono e desktop.

### 11.12 — Home
**File:** `lib/ui/screens/home/home_screen.dart` (nuovo), `library_queries.dart` (+ test)
1. Intestazione: saluto per ora del giorno («Buongiorno/Buon pomeriggio/Buonasera», `headlineSmall`) + indicatore
   Attività (dopo 11.16) + ingranaggio.
2. «Riprendi»: griglia 2 colonne × max 3 righe di tile compatte (copertina 56 a sinistra + nome 13/600, surface1,
   raggio 6): Preferiti sempre prima, poi gli album/playlist ascoltati più di recente.
3. Caroselli orizzontali (card 140, `ListView.builder`): «Ascoltati di recente», «Aggiunti di recente»,
   «I più ascoltati» (brani; il tocco suona quella lista), «Da riscoprire» (album con molti ascolti ma non da 60 giorni).
   Sezioni senza dati nascoste.
4. Libreria vuota: stato vuoto con «Aggiungi la tua cartella musicale» / «Usa la cartella Musica».
**Verifica:** test delle query (recenti, aggiunti, top, da riscoprire); widget test con e senza dati. Scatti.

### 11.13 — Cerca (con YouTube)
**File:** `lib/ui/screens/search/search_screen.dart` (nuovo), `lib/ui/screens/youtube/youtube_results.dart`
(dall'attuale `youtube_screen.dart`), `library_queries.dart` (+ test), `settings_store.dart`
1. Titolo «Cerca», ricerca a pillola (focus con `Ctrl+F` o tocco sulla scheda), chip [Libreria] [YouTube]
   (YouTube solo con `kEnableYoutube`).
2. Libreria (debounce 250 ms, query SQL con `LIMIT`): «Risultato principale» (artista il cui nome inizia con la
   query → altrimenti primo album → altrimenti primo brano), «Brani» (4 + «Mostra tutti»), «Artisti» (cerchi in
   riga), «Album» (card in riga), «Playlist». In fondo: «Cerca «…» su YouTube» → chip YouTube e invio.
3. Query vuota: ricerche recenti (max 10, ✕ per toglierle, in `SettingsStore`) e **Generi** (tile con tinta dal
   nome nell'intervallo viola–blu, dal campo `genre`) → lista brani del genere.
4. YouTube: ricerca **solo all'invio**. Righe: miniatura 80×45 r4 (`cacheWidth`), titolo, «canale · durata», tag
   «In libreria» (✓ Lilla), icona di stato a destra (⬇ → cerchio di avanzamento → ✓ / ⚠ riprova). Avviso legale
   come card chiudibile la prima volta (`ytNoticeSeen`), poi dietro un'icona ⓘ. I download in corso: chip
   «Download (N)» che apre un foglio (sostituito dal centro Attività in 11.16).
**Verifica:** test della ricerca unificata; widget test: sezioni presenti; chip YouTube assente con flag spento;
digitare non lancia la ricerca YouTube. Scatti: vuoto, risultati, YouTube.

### 11.14 — Coda, Testi, menu del brano
**File:** `queue_sheet.dart`, `lyrics_screen.dart` (+ `lyrics_view.dart` riusabile), `track_actions_sheet.dart`
→ `track_actions.dart` (modello unico delle azioni)
1. Coda: titolo «Coda» + «Svuota» (toglie i prossimi); sezioni «In riproduzione» e «Prossimi» (i già ascoltati
   nascosti); righe variante `queue` con maniglia ≡ visibile; swipe con sfondo + annulla; apre già sul brano corrente.
2. Testi: righe ad **altezza variabile** (niente taglio a 2 righe), scorrimento automatico con
   `Scrollable.ensureVisible` (allineamento 0.35); sfondo `CoverBackdrop`; 24/700 a sinistra; passate 55%,
   corrente 100%, future 35% di opacità; tocco = seek; testo semplice 20/500; intestazione con copertina 40 +
   titolo/artista; copia. Il riquadro curiosità esce (ora è in Now Playing). `LyricsView` riusata nel pannello desktop.
3. Azioni del brano: `List<TrackActionGroup> trackActions(context, ref, track)` usato sia dal foglio (mobile,
   pressione lunga, ⋮) sia da `showMenu` al puntatore (clic destro desktop). Intestazione: copertina 56 + titolo +
   «artista · album». Gruppi: Coda (Riproduci dopo, Aggiungi in coda, Aggiungi alla Jam) · Raccolta (Preferiti,
   Aggiungi a playlist) · **Vai a** (Album, Artista) · Modifica (Modifica info, Cerca info sul web) · Altro
   (Condividi → Dispositivi, Dettagli, Mostra nella cartella). «Vai a» usa `ShellNav.openInLibrary`.
4. Dettagli: data localizzata (`DateFormat.yMMMd(locale)`), due colonne.
**Verifica:** `lyrics_screen_test` aggiornato (riga lunga intera); test «Vai all'album» apre l'album nella
Libreria. Scatti: coda, testi, menu.
**Telefono:** riordino della coda con la maniglia, swipe per rimuovere + Annulla (ripristina sempre), testo
sincronizzato che scorre da solo durante la riproduzione, pressione lunga su una riga → menu → «Vai all'album».

### 11.15 — Jam
**File:** `lib/ui/screens/jam/jam_screen.dart` (+ `jam_player_card.dart`, `jam_outputs_sheet.dart`), `test/ui/jam_screen_test.dart`
1. Intestazione: «Jam» (`headlineSmall`) + avatar dei partecipanti (iniziali, tinta dal nome, «host» piccolo) +
   bottone a pillola «Termina» (host, colore errore) / «Esci».
2. Card player (surface1, r12): titolo/artista, seek con tempi (widget con il suo timer), play / successivo (host).
3. Bottone «Uscite e sincronia» → foglio: chip delle uscite (multi), stato «Sincronizzato · scarto N ms», latenza
   −50/+50 ms, volume.
4. La coda condivisa è il contenuto principale: righe con avatar «aggiunto da» (iniziale) al posto del testo;
   ✕ **solo** se si può rimuovere; corrente con barre animate. «Aggiungi brani» come pillola Ametista in basso.
5. Attesa: avatar che pulsano (fermi con «Riduci animazioni») + testo + Annulla. Jam non attiva: stato vuoto, non pagina bianca.
**Verifica:** `jam_screen_test` aggiornato (✕ assente sui brani altrui per l'ospite). Scatti attesa / attiva.

### 11.16 — Centro Attività
**File:** `lib/providers/activity_providers.dart`, `lib/ui/widgets/activity_button.dart`,
`lib/ui/screens/activity/activity_sheet.dart` (nuovi), shell, Home, Libreria, `tracks`/`youtube` (rimozioni)
1. `activityProvider` aggrega: scansione (`scanStateProvider`), arricchimento (`enrichJobProvider`), download
   (`downloadsProvider`), trasferimenti (offerte accettate/aperte dello `shareHub`).
2. `ActivityButton`: compare solo con attività in corso (spinner piccolo + numero), in Home e Libreria; su desktop in alto a destra.
3. Foglio: una riga per attività con testo («Scansione · 1.240/3.400»), avanzamento, Annulla dove esiste; finite in
   «Completate» con «Pulisci».
4. Via: `EnrichJobBanner` dalla shell, barra di scansione dalle liste, chip «Download (N)» di Cerca.
   L'esito dell'arricchimento resta una snackbar.
**Verifica:** test del provider (aggregazione con stati finti); widget test del bottone. Scatto con 3 attività.

### 11.17 — Impostazioni, Condivisione, dialoghi
**File:** `settings_screen.dart`, `share/*`, `enrich_preview_dialog.dart`, `track_edit_dialog.dart`, `missing_tracks_screen.dart`
1. Impostazioni a gruppi (card surface1 r12, titolo `titleMedium` sopra): Aspetto (tema a campioni, testo,
   compatta, riduci animazioni) · Lingua (una riga → dialogo) · Riproduzione · Libreria (cartelle con conferma,
   aggiungi, riscansiona, brani non trovati se > 0, svuota cache con conferma, importa dalla vecchia app) · Rete
   locale (ricevi, nome dispositivo, Condivisione) · Online · Informazioni (versione, licenze).
2. Condivisione: `PeerCard` di 11.7 nell'Invia; Ricevi coerente (bottoni non a tutta larghezza, errori sotto i campi);
   firewall Windows come riquadro informativo (non `MaterialBanner` con azione finta).
3. Anteprima arricchimento: confronto per campo su due colonne (vecchio barrato `textMuted` → nuovo Lilla),
   copertina proposta r8.
4. Modifica info: pagina intera sotto i 600 px (dialogo sopra), Anno e N° traccia affiancati, «Ripristina dal file» con conferma.
5. Brani non trovati: ⋮ per riga (Ignora / Rimuovi dalla libreria) + «Rimuovi tutti» con conferma.
**Verifica:** test aggiornati (`settings_and_playlists_test`, `share_screen_test`). Scatti.

### 11.18 — Rifinitura e controlli finali
1. Swipe a destra su una riga brano = «Aggiungi in coda» (la riga torna al posto, snackbar «Aggiunto in coda»).
2. «Tutti i brani» ordinato per titolo/artista: barra di scorrimento trascinabile con la lettera iniziale.
3. Transizioni di pagina uniformi; «Riduci animazioni» rispettato ovunque (barre, sfumature, Hero, swipe).
4. Focus da tastiera visibile su righe, chip e bottoni (desktop).
5. Testo al 150%: nessun overflow negli scatti di tutte le schermate (estendi `large_text_test`/`font_scale_test`).
6. ARB completi in it/en/de/es; nessuna stringa a mano nei widget.
7. Prestazioni: `test/data/performance_test.dart` verde; liste brani con `itemExtent`.
8. Pulizia: niente file morti (`track_tile.dart`, `quality_badge.dart`, `youtube_screen.dart` come scheda,
   `enrich_job_banner.dart`), `docs/02-architettura.md` aggiornato (shell, navigatori, token), README (schermate).
**Verifica:** suite completa verde, `flutter build apk --debug` e `flutter build linux` riusciti, scatti finali.
**Telefono:** giro completo di tutte le schermate con screenshot (Home, Cerca, Libreria, Tutti i brani con
scorrimento A–Z, album, artista, playlist, Preferiti, Now Playing, coda, testi, Jam solo se è già attiva
(non avviarne una), Impostazioni), swipe a destra = «Aggiunto in coda», scroll fluido sulla libreria vera.

### 11.19 — Prova a mano (utente)
Da mettere in «Tocca a te»: telefono (Mi A3) e Linux; più le prove «Telefono:» saltate nei task precedenti. Navigare Home → album → artista → indietro con il
mini-player sempre visibile; swipe del mini-player; Now Playing (trascina giù, swipe copertina, artista → pagina);
Dispositivi → Jam con il secondo telefono; Cerca con YouTube; clic destro e pannello destro su Linux;
leggibilità al sole (tema Notte viola e Nero puro).

## Fuori da questa fase
Selezione multipla nelle liste, trascinamento brani sulle playlist (desktop), immagini degli artisti da Internet,
temi chiari. Si valutano dopo la prova a mano.

## Rischi
| Rischio | Mitigazione |
|---|---|
| Font variabili: il grassetto non si applica | Helper che imposta `fontWeight` + `FontVariation.weight`; controllo negli scatti di 11.2 |
| Navigatori annidati e tasto indietro Android | Un solo punto di gestione in `ShellNav`; test dedicato in 11.5 |
| Scatti instabili (immagini non caricate, animazioni) | `runAsync` + `precacheImage`; `pump` a tempo fisso; scatti fuori da `flutter test` |
| Colore copertina lento su liste lunghe | Solo dove serve (mini-player, Now Playing, intestazioni), provider in cache, decodifica a 24 px |
| Task troppo grandi (11.8, 11.9, 11.11) | Spezzali in sotto-task annotati in PROGRESS (es. 11.11a album, 11.11b artista…) |

## Definition of Done
- [x] Mini-player e barra sempre visibili navigando su telefono; barra laterale + barra player su desktop
- [x] 3 schede (Home · Cerca · Libreria), YouTube dentro Cerca, Jam/invio dal bottone Dispositivi
- [x] Solo temi Notte viola e Nero puro; Figtree + Unbounded inclusi con licenze; contrasto ≥ 4.5 nei test
- [x] Ogni nome di artista/album porta alla sua pagina; ogni raccolta ha Play e Casuale
- [x] Una sola riga brano; nessun `Text('$e')`; conferme o annulla su tutte le azioni distruttive
- [x] `flutter analyze` pulito, `flutter test` verde, build apk debug e linux riuscite, scatti finali rivisti
- [x] `docs/PROGRESS.md`, `docs/02-architettura.md` e README aggiornati
