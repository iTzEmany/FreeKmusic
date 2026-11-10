# FreeKmusic (Flutter)

Lettore musicale personale, standalone (nessun backend), per **Android, Linux e Windows**.
Italiano, English, Deutsch, Español.

- Piano di lavoro: [`docs/00-INDICE.md`](docs/00-INDICE.md) · avanzamento: [`docs/PROGRESS.md`](docs/PROGRESS.md)

## Schermate
- **Home** (saluto, «Riprendi», ascoltati/aggiunti di recente, più ascoltati, da riscoprire) · **Cerca** (libreria
  in un colpo solo, generi, ricerche recenti, YouTube sull'invio) · **Libreria** (playlist, album e artisti insieme,
  Preferiti e «Tutti i brani» fissati, ordinamenti, griglia).
- Pagine di album, artista, playlist e Preferiti con Play e Casuale; **Now Playing** con colore dalla copertina,
  testo, info e prossimi brani; coda a sezioni; pulsante **Dispositivi** per Jam e invio.
- Desktop: barra laterale con le playlist, barra player completa, pannello destro (coda / testo), clic destro.
- Temi: **Notte viola** (predefinito) e **Nero puro**.

## Funzioni
- **Libreria**: scansione incrementale di cartelle, tag letti (riscritti solo se lo chiedi), copertine, brani / album / artisti,
  ricerca e ordinamenti, brani mancanti gestiti senza perdere preferiti e playlist.
- **Riproduzione**: coda separata dalla lista, shuffle senza ripetizioni, repeat off/all/one, ripresa all'avvio,
  notifica e tasti cuffie su Android, scorciatoie da tastiera su desktop, timer di spegnimento con fade-out.
- **Preferiti, playlist** (copertina personalizzabile, riordino), modifica info (solo nel DB), temi (Notte viola, Nero puro, Chiaro) con 8 colori d'accento.
- **Online (solo su azione tua o opzioni attive)**: info e copertine da iTunes, testi sincronizzati da LRCLIB,
  curiosità da Wikipedia, ricerca e download da YouTube, YouTube Music e SoundCloud con yt-dlp.
- **Condivisione LAN** telefono ↔ PC senza server esterni: scoperta automatica dei dispositivi, richiesta con accettazione (anche da notifica su Android, anche in background), collegamento manuale con PIN e QR.
- **Jam sulla rete locale**: coda condivisa tra fino a 5 dispositivi (anche un ospite può accettare nuovi arrivati), ognuno aggiunge brani dalla propria libreria (streaming dal proprietario, precarico del successivo), uscita audio selezionabile; l'ospite non può cambiare brano. Più dispositivi possono suonare **insieme, sincronizzati** (orologio condiviso e correzione della deriva). Schermata Condivisione → «Avvia Jam con …». Piano in [`docs/fase-8-jam.md`](docs/fase-8-jam.md).
- **Importa playlist di Spotify da CSV**: scarica il file da **exportify.net** (accedi con Spotify ed esporta la
  playlist), poi in Libreria tocca «+» → «Importa da Exportify (CSV)». I brani già in libreria vengono collegati, gli
  altri cercati su YouTube Music e scaricati, nello stesso ordine; i dubbi finiscono in «Rivedi». Serve `yt-dlp`
  recente (≥ 2025.11, `pip install -U yt-dlp`).
- **Import** di preferiti, testi e playlist dalla vecchia app Python (Impostazioni → «Importa dalla vecchia app»).

## Installare
- **Android**: `flutter build apk --release --split-per-abi` e `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
  Il pacchetto include Python, yt-dlp, QuickJS e ffmpeg (YouTube funziona senza backend; il primo avvio estrae i file ed è più lento).
- **Linux**: `flutter build linux --release`, poi eseguire `build/linux/x64/release/bundle/freekmusic`.
  Servono `libmpv` (`sudo apt install libmpv-dev mpv`). Per YouTube: `yt-dlp` e `ffmpeg` nel PATH (`pip install -U yt-dlp`)
  e un runtime JavaScript (`node`, `deno` o `quickjs`).
- **Linux, pacchetto .deb**: `flutter build linux --release && scripts/package-linux.sh --deb` produce `build/freekmusic_<versione>_amd64.deb` (dipende da `libmpv2`); lo zip resta in `build/freekmusic-linux-x64.zip`. AppImage, Flatpak e l'installer Windows aspettano l'approvazione degli strumenti di build (vedi `docs/PROGRESS.md`, fase 26).
- **Android più leggero**: `flutter build apk --release --split-per-abi` (arm64 ≈ 67 MB) oppure la variante senza YouTube: `CODECORE_LITE=1 flutter build apk --release --split-per-abi --dart-define=CODECORE_YOUTUBE=false` (arm64 ≈ 13 MB).
- **Guida**: [`docs/guida/`](docs/guida/README.md).
- **macOS**: scarica `FreeKmusic-<versione>-macos.zip` dalla release e decomprimilo. L'app non è firmata: al primo avvio apri con tasto destro → Apri, oppure `xattr -dr com.apple.quarantine freekmusic.app`. Le build release di Flutter per macOS sono universali (Apple Silicon e Intel). Non include yt-dlp/ffmpeg.
- **Windows**: su una macchina Windows con Visual Studio 2022 (C++): `flutter build windows --release`
  e zippare `build\windows\x64\runner\Release\`. Per YouTube servono `yt-dlp.exe` e `ffmpeg.exe` nel PATH.

## CI
![CI](https://github.com/UTENTE/REPOSITORY/actions/workflows/ci.yml/badge.svg)
<!-- Sostituisci UTENTE/REPOSITORY con quelli del repository GitHub. -->

Ogni push controlla codice generato, `flutter analyze` e `flutter test`. Un tag `v*` (o «Run workflow» a mano) produce anche gli artefatti **APK** (per ABI), **Linux** (zip) e **Windows** (zip): si scaricano dalla pagina dell'esecuzione, sezione *Artifacts*. Ogni notte i test dal vivo controllano che YouTube Music, iTunes e LRCLIB rispondano ancora; ogni lunedì un rapporto elenca le dipendenze da aggiornare. In locale: `flutter test` (golden compresi, solo Linux) e `scripts/deps_report.sh`.

## Compilare / sviluppare
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # dopo modifiche alle tabelle drift
flutter analyze && flutter test
flutter gen-l10n                                            # dopo modifiche agli ARB
```
Firma Android: crea `android/key.properties` (non versionato) con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`;
senza il file la build release usa la chiave di debug.


## Download (Impostazioni → Download)
- **Download contemporanei** 1–3 (predefinito 2), **limite di velocità** e **qualità originale** (M4A/Opus senza ricodifica; spenta = MP3 256 kbps).
- Un errore di rete o un 403 passeggero viene ritentato da solo (dopo 5, 20 e 60 secondi); un limite di YouTube (429) mette in pausa.
- **yt-dlp (desktop):** l'app usa quello scaricato da lei (`Aggiorna`) prima di quello nel PATH; se è più vecchio di `2025.11.12` mostra un avviso.
- Le ricerche dell'importazione da CSV sono ricordate 30 giorni (**Svuota cache ricerche**); un file di durata molto diversa dal CSV finisce in «Da verificare».

## Interfaccia (fase 19)
- **Selezione multipla:** pressione lunga su un brano (telefono) o Ctrl/Maiusc+clic (PC), poi Riproduci / In coda / Aggiungi a playlist / Preferiti / Rimuovi dalla playlist; sui risultati di YouTube «Scarica». Nessuna azione tocca i tuoi file.
- **Trascinamento (PC):** trascina uno o più brani sulle playlist o sui Preferiti della barra laterale.
- **Aspetto:** tema Chiaro e 8 colori d'accento; su schermi larghi (≥ 1200 px) la coda si apre da sola a destra.
- **Lingue:** italiano, inglese, tedesco, spagnolo, francese e portoghese.
- Al primo avvio una guida in 4 pagine (saltabile) spiega cartelle, funzioni online, download, Jam e condivisione.

## Libreria intelligente (fase 20)
- **Cronologia e statistiche:** Libreria → Cronologia (per giorno, con l'ora) e Statistiche (mese o anno: tempo ascoltato, grafico, ora preferita, brani/artisti/album più ascoltati); la Home mostra «Il tuo mese» da 10 ascolti. Tutto resta sul dispositivo; si può spegnere in Impostazioni → Riproduzione.
- **Ricerca intelligente**: una frase sola trova per titolo, artista, album, genere, anno ed etichette, in qualsiasi ordine e senza badare agli accenti; due chip, «Preferiti» e «Recenti», restringono i risultati. Le regole con operatori (`artista:"pink floyd" -live anno:1970..1979`, `durata>5m`, `tag:live`, `rock OR jazz`) restano per le playlist intelligenti.
- **Playlist intelligenti:** Libreria → + → Nuova playlist intelligente: le stesse regole, l'elenco si aggiorna da solo (ordine, limite, modelli pronti); si può convertire in playlist normale.
- **Etichette tue:** dal menu di un brano o dalla selezione multipla; Libreria → Etichette.

## Pulizia libreria (fase 21)
- **Duplicati:** Impostazioni → Pulizia libreria → Duplicati. Trova lo stesso file in più cartelle («Identici», confronto per SHA-256 solo dei file della stessa dimensione) e lo stesso brano in più qualità («Probabili»: stesso titolo e artista, durata entro 2 s). Ogni gruppo mostra i percorsi, il formato e la dimensione, con il brano proposto (lossless, poi bitrate più alto); preferiti, playlist, ascolti, testi ed etichette passano a quello che tieni e gli altri vengono solo nascosti («Brani nascosti», dove si ripristinano). «Elimina anche i file» chiede due conferme con l'elenco dei percorsi.
- **Album a mano:** menu ⋯ di un album → «Unisci con…»; dalla selezione di brani → «Sposta in un nuovo album…». Con «Annulla» nello snackbar; i file non si toccano.
- **Tag nei file (facoltativo):** Impostazioni → Pulizia libreria → «Scrivi le modifiche nei file» (spenta di default, con avviso). Quando salvi «Modifica info» o unisci/sposti album, spuntando «Scrivi anche nel file» titolo, artista, album, album artist, anno, genere e traccia vengono scritti anche in MP3, FLAC, M4A e OGG. Si lavora su una copia, si rilegge e si confronta, l'originale va in «Backup dei tag» (ultimi 200 o 2 GB, «Ripristina originale») e solo allora il file viene sostituito; copertina e ReplayGain restano. Un campo svuotato nell'app resta com'era nel file. La libreria resta la fonte principale e si aggiorna comunque, anche se il file non può essere scritto (sola lettura, formato non supportato).

## Nuove fonti (fase 22)
- **Cerca online:** tre chip sopra i risultati — **YouTube · YouTube Music · SoundCloud** (si ricorda la scelta). SoundCloud mostra solo brani interi: le anteprime da 30 s e i brani con DRM non si scaricano.
- **Importazione:** Impostazioni → Download → «Cerca anche su SoundCloud se un brano non si trova» (spento di serie): una ricerca in più per le righe che YouTube non trova.
- **Playlist e canali YouTube:** incolla l'indirizzo in Cerca → foglio con i video (tutti spuntati), un nome e «Scarica in una playlist»; i brani arrivano nell'ordine della playlist, con pausa, ripresa e annulla.
- **Traduzione dei testi:** non ancora (aspetta l'approvazione di un pacchetto, vedi `docs/PROGRESS.md`).

## Podcast (fase 23)
- **Libreria → Podcast:** iscriviti incollando l'indirizzo del feed RSS o cercando per nome (elenco pubblico di iTunes); la pagina del podcast elenca gli episodi dal più recente. **Niente aggiornamenti o download da soli**: «Aggiorna» (o aprire un podcast controllato più di 6 ore fa) e «Scarica» partono solo da te.
- Gli episodi scaricati si ascoltano con lo stesso player (coda, notifica, velocità, ripresa dal punto lasciato); da 95 % in poi sono «ascoltati». Non compaiono mai in Tutti i brani, Home, ricerca, playlist o statistiche. Per ogni podcast si può attivare «Elimina gli episodi ascoltati» dopo 1, 7 o 30 giorni (spento di serie; tocca solo i file dell'app).

## Backup e ripristino (fase 13)
- Impostazioni → **Backup**: «Crea backup» salva uno zip con playlist, preferiti, testi, modifiche, impostazioni, database e copertine (**non** la musica, **non** l'identità del dispositivo). «Ripristina da backup» chiede se **sostituire tutto** (solo per un backup di questo dispositivo: al riavvio, con copia di sicurezza `.before-restore`) o **unire** a questa libreria (preferiti, playlist, testi e modifiche sui brani riconosciuti; l'elenco dei non trovati è copiabile; non cancella niente).
- **Esportare una playlist**: menu della playlist → «Esporta…» (M3U8, CSV Exportify, JSON); Libreria → ⋮ → «Esporta tutte le playlist» (zip).

## Dispositivi fidati e sincronia (fase 24, in parte)
- Impostazioni → «Rete locale» → **Dispositivi fidati**: per ogni dispositivo abbinato si vede l'impronta, si può attivare «Accetta automaticamente» e **revocare** (con conferma). Il gruppo compare solo quando c'è almeno un abbinato.
- Le playlist hanno un'identità (`uuid`) e una data di ultima modifica; il confronto tra due dispositivi (la più recente vince, con anteprima e conferma, mai cancellazioni) è pronto e provato nei test. **L'abbinamento con PIN/QR, l'HTTPS con impronta e il pulsante «Sincronizza playlist» non ci sono ancora**: aspettano l'approvazione dei pacchetti dei certificati e dello scanner (vedi `docs/PROGRESS.md`). La Jam resta su HTTP con token.

## Widget, tile, Android Auto (fase 25, Android)
- **Widget** «In riproduzione» 4×1 e 2×2 per la home (copertina, titolo, ⏮ ⏯ ⏭) e **tile** play/pausa nelle impostazioni rapide: anche con l'app chiusa (il primo tocco la riavvia e fa partire il brano dopo ~3 s).
- **Android Auto**: Preferiti · Playlist · Album · Più ascoltati · Ultimi aggiunti, ricerca e avvio dei brani (da provare su Desktop Head Unit o in auto). **Wear OS**: i controlli multimediali di sistema dell'orologio.
- **Modalità in auto**: dal menu di Now Playing, pulsanti grandi e playlist a portata di dito; lo schermo resta acceso solo se lo chiedi.

## Riproduzione (fase 17)
- **Velocità** 0,5×–2× senza cambiare il tono (chip «1×» in Now Playing).
- **Riprendi da qui:** i brani lunghi (≥ 20 min: podcast, audiolibri, DJ set) ripartono da dove li hai lasciati.
- **Anteprima di 20 s:** tieni premuta la copertina (desktop: menu del brano).
- **Equalizzatore** (Android): preset e curva propria, con profili separati per cuffie e altoparlante.
- **Passaggio tra i brani** (Impostazioni → Riproduzione): *Normale*, *Senza pause* (album dal vivo, classica) o *Dissolvenza* da 2 a 12 s, con l'opzione di non sfumare dentro un album.
- **Jam:** notifica e schermata di blocco mostrano il brano della Jam, con pausa/play e, per l'host, «avanti».

## Formati accettati dall'importazione
CSV di **Exportify** (Spotify), **TuneMyMusic**, **Soundiiz**, **Last.fm** o qualunque CSV con una colonna titolo e una artista, e playlist **M3U/M3U8** e **XSPF** (VLC, Poweramp…). Le voci locali si cercano prima nella libreria (per percorso, anche se la cartella è cambiata). Nell'anteprima: **solo collega** (nessun download), **rivedi prima di scaricare**, cartella dedicata, file numerati, copertine, blocchi da 100 per file grandi. Soglie di abbinamento in Impostazioni → Avanzate. «Esporta esito» in «Rivedi» salva un CSV con il motivo di ogni riga non risolta.

## Sincronizzare una playlist
Importando di nuovo un file aggiornato nella stessa playlist si sceglie **Sincronizza**: i brani nuovi vengono importati, quelli spariti dal file escono dalla playlist (restano in libreria e su disco), l'ordine segue il file e i brani aggiunti a mano restano al loro posto accanto al brano che li precedeva.

## Limiti noti
- Jam: massimo 5 partecipanti; la sincronia è misurata sulla posizione del player (scarto tipico 10–30 ms, non acustico), con Bluetooth serve la compensazione manuale della latenza; nessun controllo da notifica di sistema/MPRIS; la richiesta Jam in background Android passa dalla notifica «Accetta/Rifiuta».
- La scrittura dei tag nei file è facoltativa (vedi «Tag nei file») e non cancella i campi; l'equalizzatore c'è solo su Android. Gapless e crossfade non valgono nella Jam.
- Controlli multimediali di sistema (MPRIS / SMTC) non implementati; i tasti multimediali funzionano a finestra attiva.
- Condivisione LAN in HTTP in chiaro (protetta da PIN, solo per reti domestiche).
- Lo scanner QR non è incluso: inserire IP:porta e PIN o incollare il link del QR.
- yt-dlp cambia spesso: su Android viene aggiornato a ogni avvio; su desktop l'app avvisa se è troppo vecchio e lo aggiorna con «Aggiorna» (Impostazioni → Download).

## Note legali
Il download da YouTube e da SoundCloud può violare i termini del servizio e il diritto d'autore: la funzione è pensata per uso strettamente
personale e si disattiva con `kEnableYoutube = false` in `lib/core/constants.dart`. Testi e metadati provengono da servizi
terzi (LRCLIB, iTunes Search API, Wikipedia — CC BY-SA) e restano di proprietà dei rispettivi titolari.
La libreria `youtubedl-android` usata su Android è sotto licenza GPL-3.0.
