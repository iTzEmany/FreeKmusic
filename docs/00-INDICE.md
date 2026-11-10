# FreeKmusic Flutter — Indice della documentazione

> Dal 10/11/2026 l'app si chiama FreeKmusic (D-539); i documenti storici usano ancora Codecore.

Obiettivo: riscrivere FreeKmusic come app **standalone** (nessun server, nessun backend) con
un'unica codebase Flutter per Android, Windows e Linux. Uso personale, niente complicazioni.

## Documenti di riferimento (leggili all'occorrenza)
| File | Contenuto |
|---|---|
| `01-regole-di-lavoro.md` | Regole obbligatorie per l'agente (stile, test, verifiche) |
| `02-architettura.md` | Struttura cartelle, livelli, flusso dei dati, scelte tecniche |
| `03-modello-dati.md` | Schema DB drift, chiavi, regole sui dati |
| `04-specifiche-da-python.md` | Logica da portare dalla vecchia app (con i difetti corretti) |
| `99-rischi-e-fallback.md` | Cosa può andare storto e il piano B |

## Fasi (una per volta, in ordine)
| Fase | File | Risultato |
|---|---|---|
| 0 | `fase-0-setup.md` | Progetto creato, dipendenze, "hello world" su Linux e Android |
| 1 | `fase-1-dati-e-scansione.md` | DB + scansione cartelle + tag + copertine |
| 2 | `fase-2-player.md` | Motore audio, coda, notifica Android |
| 3 | `fase-3-interfaccia.md` | Libreria, album, ricerca, mini-player, player a schermo intero |
| 4 | `fase-4-funzioni-libreria.md` | Preferiti, playlist, impostazioni, temi, lingue, modifica tag |
| 5 | `fase-5-online.md` | Arricchimento metadati, testi sincronizzati, download YouTube |
| 6 | `fase-6-condivisione-lan.md` | (Opzionale) invio brani tra dispositivi sulla stessa rete |
| 7 | `fase-7-rifinitura.md` | Gapless, import dal vecchio DB, icone, build finali |
| 8 | `fase-8-jam.md` | Jam sulla rete locale: coda condivisa, brani in streaming dal proprietario, uscita audio selezionabile |
| 9 | `fase-9-jam-multi.md` | Jam con più di 2 dispositivi (fino a 5), inviti anche dagli ospiti |
| 10 | `fase-10-jam-sincronia.md` | Riproduzione sincronizzata su più uscite (orologio condiviso, correzione della deriva) |
| 11 | `fase-11-interfaccia-nuova.md` | Interfaccia nuova nero/viola: Home · Cerca · Libreria, player sempre visibile, desktop a tre zone |
| 12 | `fase-12-import-csv.md` | Importare playlist Spotify da CSV di Exportify: abbinamento con la libreria, ricerca su YouTube Music, download in ordine |
| — | `13-idee-future.md` | Idee per dopo la base (raccolta ragionata): le voci tenute sono diventate le fasi 13–26 |
| 13 | `fase-13-backup-export.md` | Backup e ripristino completo, formato portabile dei dati utente, export playlist (M3U8/CSV/JSON), esporta log |
| 14 | `fase-14-download-robusti.md` | yt-dlp aggiornabile in-app, download in parallelo, ritento a scalare, formato senza ricodifica, ISRC, cache, controllo durata |
| 15 | `fase-15-importazione-2.md` | Import M3U/XSPF e CSV generici, «Sincronizza da CSV», album interi, migliorie della fase 12 |
| 16 | `fase-16-ci-test.md` | CI GitHub (analyze, test, build apk/linux/windows), test d'integrazione su telefono, live notturni, golden, 50.000 brani |
| 17 | `fase-17-riproduzione.md` | Velocità, «riprendi da qui», anteprima, equalizzatore, MPRIS/SMTC, controlli Jam in notifica |
| 18 | `fase-18-gapless-crossfade.md` | Gapless (dietro un'opzione) e crossfade, senza toccare la Jam |
| 19 | `fase-19-interfaccia.md` | Selezione multipla, trascinamento su playlist, tema chiaro e accento, tablet, nuove lingue, onboarding |
| 20 | `fase-20-libreria-intelligente.md` | Cronologia, statistiche/recap, ricerca con operatori, playlist intelligenti, etichette |
| 21 | `fase-21-pulizia-tag.md` | Duplicati e fusione, unire/dividere album, scrittura dei tag nei file (atomica, opzionale) |
| 22 | `fase-22-nuove-fonti.md` | SoundCloud, playlist e canali YouTube come sorgente, traduzione dei testi on-device |
| 23 | `fase-23-podcast.md` | Podcast da RSS: iscrizioni, episodi scaricabili, stato «ascoltato» |
| 24 | `fase-24-dispositivi-fidati.md` | Abbinamento dispositivi, TLS con pinning, scanner QR, sincronizzazione playlist in LAN |
| 25 | `fase-25-android-esteso.md` | Widget, tile rapida, Android Auto, Wear OS, modalità in auto |
| 26 | `fase-26-distribuzione.md` | Pacchetti Linux, installer Windows, APK più piccolo, avviso aggiornamenti, F-Droid, macOS/iOS, guida utente |
| 27 | `fase-27-selezione-ordinata-e-tema-libero.md` | Selezione multipla nell'ordine dei tocchi (con numeri) e tema totalmente personalizzabile (colori, sfondo, immagine) |
| 28 | `fase-28-prestazioni-e-fluidita.md` | Zero lag sul Mi A3 con 3000 brani, microanimazioni, ricerca online diretta (< 1,5 s), ascolto in streaming prima di scaricare, copertine leggere |
| 30 | `fase-30-pagina-artista.md` | Card dell'artista nei risultati online e pagina artista «come Spotify» (i tuoi brani, più ascoltati, album e singoli, video, simili), pagina album con «Scarica album» |
| 31 | `fase-31-shuffle-plus.md` | «Shuffle+»: in casuale, ogni N brani uno che non hai, simile alla playlist (radio di YouTube Music), in streaming, da scaricare o aggiungere a una playlist |
| 32 | `fase-32-ricerca-intelligente.md` | Ricerca con due modi (In libreria · Online): online YouTube Music e YouTube insieme, confidenza, stesso brano in una riga, «Altri risultati», intento (artista, album, brano, indirizzo), fonti come filtro; SoundCloud misurato e proposto fuori dalla ricerca |
| 33 | `fase-33-radio.md` | Radio in diretta da Radio Browser: «Vicino a te» (paese e regione), ricerca, generi, «Le mie radio» salvate (schema v12), ascolto dal lettore principale con titolo in onda, Android Auto |
| 34 | `fase-34-nuove-uscite.md` | Nuove uscite degli artisti seguiti (e, a scelta, dei più ascoltati): un controllo al giorno, «Nuove uscite» in Home, notifica Android (schema v13) |
| 35 | `fase-35-secondo-parere-ytm.md` | Secondo parere da YouTube Music in «Da revisionare» (solo se conferma), genere da MusicBrainz, testo dalla scheda «Testo», curiosità da YouTube Music e Discogs, «Riprova» che non perde brani |
| 36 | `fase-36-deezer-ed-exportify.md` | Deezer come fonte di metadati (per ISRC: numero di disco, copertina 1000 px, controllo d'edizione contro i cofanetti), ISRC in libreria (schema v14), MusicBrainz per ISRC; Exportify semi-automatico: «Apri exportify.net», ZIP di «Export All» abbinato a tutte le playlist, anteprima unica, file da Chrome, promemoria |
| 37 | `fase-37-metadati-che-viaggiano.md` | Metadati che viaggiano con il brano condiviso (titolo, artista, album, anno, genere, traccia e disco, ISRC, testo, copertina), il pacchetto vince sui tag del file; tag scritti nei file scaricati e ricevuti (accesi di default, mai l'ISRC), ripiego «Artista - Titolo» dal nome del file, Deezer al ricevente |
| 38 | `fase-38-rete-ui-fluida.md` | Rete di sicurezza del refactor «ui-fluida»: strumenti di misura riparati, scenari nuovi, test di caratterizzazione A–E, misure di partenza sul Mi A3 |
| 39 | `fase-39-fluidita.md` | Fluidità: transizioni senza opacità, apertura del player, swipe, testi sincronizzati, fogli pigri, una scala di movimento; misura contro le soglie |
| 40 | `fase-40-accessibilita-e-token.md` | Accessibilità e token: opzioni di sistema, contrasto, bersagli da 48 dp, etichette e tastiera, focus, scala del testo, spaziature |
| 41 | `fase-41-mattoni-condivisi.md` | Mattoni condivisi: `showMsg`, `promptName`, `CcAppBar`, `AsyncBody`, `showCcSheet`, migrazione a gruppi |
| 42 | `fase-42-livelli-e-tipi.md` | Livelli e tipi: UI solo tramite provider (`TrackOps`, test di architettura), selezione unica, enum dei menu, `track.kind`, build corti, via l'importer Python |
| 43 | `fase-43-nuovo-aspetto.md` | Nuovo aspetto dai mockup approvati: dock unico, Home, Libreria, Album/artista, In riproduzione, Onboarding con scansione |
| 44 | `fase-44-chiusura-ui-fluida.md` | Chiusura di «ui-fluida»: misure finali, metriche di struttura, risultati in `analisi.md`, pulizia |
| 45 | `fase-45-cache-streaming.md` | Streaming, cache e motore: `StreamCache` (LRU in MB), `StreamPreparer`, righe ombra `kind = 2` in cronologia e statistiche, lettore dal file, suggeriti di Shuffle+ sulla cache, via `StreamAddressCache`, cursore e «Svuota» |
| 46 | `fase-46-streaming-ricerca.md` | Streaming dalla ricerca: tap/swipe/menu ⋮ sulle righe online, player in caricamento, album online con Play/Shuffle, «Scarica» e «Aggiungi a playlist» con spostamento dalla cache, via l'anteprima con le cuffie |
| 47 | `fase-47-jam-online.md` | Jam online: brani online accodati da host e ospiti e serviti dalla cache, uscita che scarica da sé, rotta `meta`, schermata del brano, via il FAB |
| 48 | `fase-48-shuffle-tre-stati.md` | Shuffle a 3 stati senza interruttore (salta Shuffle+ quando la coda non lo permette), suggeriti inseriti/tolti subito, Play e shuffle separati in Home |
| 49 | `fase-49-artisti-ospiti.md` | Artisti ospiti: nomi toccabili nel player e nella barra desktop, «Vai all'artista» con foglio di scelta, risoluzione libreria → online |
| 50 | `fase-50-dati-e-fonti-crediti.md` | Dati e fonti dei crediti: schema v15 (`track_credits`, `track_enrich`, `cover_source`, `activity_log`), fixture reali, `DeezerGwClient` con pausa di 24 h, dettagli Deezer, crediti MusicBrainz, `mergeCredits`, interruttore «Crediti e dettagli», crediti salvati e spostati con «Scarica» e doppioni |
| 51 | `fase-51-crediti-a-schermo.md` | Crediti a schermo: ruoli tradotti in 6 lingue, card «Crediti e dettagli» con «Mostra tutto», link e «Aggiorna», sezione in Jam e anteprima, «Compare come», «Nei crediti», crediti in backup, invio e Jam |
| 52 | `fase-52-testo-e-curiosita.md` | Testo e curiosità complete: `LyricsChain` (LRCLIB → NetEase → lyrics.ovh), stato per parte con riprova a 30 giorni, testo dell'utente protetto, `CuriosityService`, «Curiosità automatiche», arricchimento completo dopo il download |
| 53 | `fase-53-completamento-e-registro.md` | Completamento e Registro: `UserActivity`, `EnrichCompleter` piano e subito, «Completa l'arricchimento», voce con Pausa/Riprendi, Registro nel DB per 30 giorni con ogni attività e riga per giro, peso in Memoria, misura sul Mi A3 |
| 54 | `fase-54-copertina-a-mano.md` | Copertina a mano: selettore unico (file, proposte online con la misura, libreria) per brano, album e playlist, copertina d'album da `cover_source`, protezione in ogni scrittore, «Ripristina copertina originale», backup |
| 55 | `fase-55-misura-streaming.md` | Misura dello streaming: cronometri nel preparer e tap → primo suono in `codecore.log`, `scripts/stream_times.py`, prova dell'URL col yt-dlp vero, tabella «Prima» su Linux, Mi A3 e Motorola |
| 56 | `fase-56-partenza-da-url.md` | Partenza dall'URL: righe `--print before_dl` di yt-dlp (desktop e canale Android), `StreamPreparer.start()`/`restart()`, `loadUri` con header e ripiego sul file, URL scaduto e cambio di rete |
| 57 | `fase-57-coda-e-transizioni.md` | Coda e transizioni: URL anticipato dal prefetch, gapless e crossfade da URL verso file, Jam invariata, misura finale (RNF-08…10), rimisura delle soglie della fase 38 |
| 58 | `fase-58-rete-jam-ricerca.md` | Rete del refactor «ui-jam-ricerca»: caratterizzazione di seek, Jam, Ricerca, menu, Home e testo; golden di oggi; misure «Prima» sul Mi A3 |
| 59 | `fase-59-player-e-seek.md` | Player e seek: scheda del testo a tutta larghezza e 5 righe fisse, `RingProgress` con posizione e `onSeek` iniettati, una sola fonte di posizione, `SeekBar` condivisa, barra di nuovo nel player |
| 60 | `fase-60-ricerca-e-dock.md` | Ricerca e dock: ✕ svuota e resta, barra sopra mini player e schede, tastiera aperta = solo la barra, Back con la tastiera, niente rebuild sugli inset |
| 61 | `fase-61-fogli-ovunque.md` | Fogli ovunque: helper sopra `showCcSheet`, ⋮ come unico glifo, timer, «+», ordinamenti e clic destro a foglio, niente `PopupMenuButton` |
| 62 | `fase-62-home-aggiunti.md` | Home «aggiunti da poco»: 20 album, aperto una riga che scorre con quadrati da 84 dp, titolo e artista |
| 63 | `fase-63-jam-come-player.md` | Jam = player: stessa schermata con intestazione Jam (partecipanti, «Termina» con conferma), coda dal pulsante «Coda», precedente e successivo per tutti |
| 64 | `fase-64-chiusura-jam-ricerca.md` | Chiusura ui-jam-ricerca: misure finali contro la 58, metriche di arrivo, «Risultati» in analisi |
| 65 | `fase-65-rilievi-jam.md` | Rilievi della Jam (47.8, 63.5): aggiunte in fila, swipe online dell'ospite, uscita con la coda ritrovata, copertine, «Scarica», «precedente» deciso dall'host, scarto (feature `feature-jam-cassa.md`) |
| 66 | `fase-66-coda-insieme.md` | Coda insieme: modalità scelta dall'host, turno a giro, aggiunte in testa alla propria parte, finestra di 200, suggeriti locali, niente trascinamento |
| 67 | `fase-67-jam-della-cassa.md` | Jam della cassa (Android): uscite A2DP dal nativo, permesso, «È una cassa?», Jam aperta da sé e annunciata in LAN, banner, solo l'host suona, cassa assente |
| 68 | `fase-68-scoperta-e-chiusura-jam.md` | Scoperta con la maschera vera, misure di fluidità, prova a mano con due telefoni e la «cassa» |
| 69 | `fase-69-fondamenta-jam-distanza.md` | Jam a distanza: anti-spam in LAN (2/min, Sospendi, Blocca), `JamGuestLink`, `sodium` con vettori noti, broker e «Prova connessione» |
| 69a | `fase-69a-coda-arricchimento.md` | Refactor «arricchimento-unico» (1/2): il completamento in background riparte (segnalibro, testi «a riposo», contatore, copertine, errori Deezer) ed escono gli errori nascosti |
| 69b | `fase-69b-arricchimento-unico.md` | Refactor «arricchimento-unico» (2/2): regola e stato in un punto, un solo motore per manuale e background, un solo comando in Impostazioni, `EnrichmentService` diviso |
| 69c | `fase-69c-fondamenta-riconoscimento.md` | Riconoscimento del brano (1/3): impronta Chromaprint in Rust uguale a fpcalc, MBID/ISRC dai tag, bug della data, query pulite, Deezer acceso |
| 69d | `fase-69d-cascata-riconoscimento.md` | Riconoscimento del brano (2/3): cascata ISRC/MBID → video id → testo → AcoustID → YTM, il motore arricchisce dall'identità |
| 69e | `fase-69e-correzioni-e-cover.md` | Riconoscimento del brano (3/3): correzioni e proposte, cover → curiosità dell'originale, ripasso, brani online, misura sul Motorola |
| 70 | `fase-70-ponte-jam-distanza.md` | Ponte MQTT cifrato: protocollo, riserva fra broker, ospiti remoti, ingresso con codice o QR, servizio in primo piano |
| 71 | `fase-71-coda-remota.md` | Coda dell'ospite remoto: video id o ricerca titolo + artista, «Coda insieme», copertine e scheda dal video id |
| 72 | `fase-72-bluetooth-e-amici.md` | Annuncio Bluetooth con gettone che ruota, Jam vicine, permessi, amici della Jam |
| 73 | `fase-73-chiusura-jam-distanza.md` | Costo della cifratura sul Mi A3 e prova a mano con due telefoni, uno su 4G |
| 74 | `fase-74-coda-jam-e-rifinitura.md` | Rinviati della coda della Jam (Suggerito, Shuffle+, coda di prima su disco), «Scarica» e posizione nella Jam, rifinitura della Jam a distanza |
| 75 | `fase-75-arricchimento-stream.md` | Testo, curiosità e crediti anche per i brani in streaming, caricati appena il brano corrente è in cache (D-351, refactor «arricchimento-stream») |
| 76 | `fase-76-suggeriti-veloci.md` | Suggeriti di Shuffle+ in coda appena c'è l'indirizzo, non dopo il download (D-352) |
| 77 | `fase-77-rete-e-componenti.md` | Refactor «ui-uso-quotidiano»: rete di sicurezza, misura di partenza, `Skeleton`, `CcSearchField`, niente tastiera automatica in Cerca |
| 78 | `fase-78-home-radio-statistiche.md` | Home a riquadri, Radio (le tue → generi da 4 → vicino a te), Statistiche con mese ricordato e barre toccabili |
| 79 | `fase-79-libreria-e-tutti-i-brani.md` | Libreria senza lag e con la ricerca interna, Tutti i brani con barra che si nasconde |
| 80 | `fase-80-cerca-online-e-generi.md` | Cerca solo online, generi misti libreria + suggeriti (D-355, D-356), stato «in preparazione» di Shuffle+ |
| 81 | `fase-81-player-e-streaming.md` | Player a coda finita, skeleton delle schede in streaming e dei suggeriti in coda |
| 82 | `fase-82-registro-e-revisione.md` | «Accetta tutte» in un colpo (D-361), Registro per giorno con filtri, Da confermare e Da revisionare |
| 83 | `fase-83-chiusura-uso-quotidiano.md` | Misure finali e prova a mano del refactor |
| 84 | `fase-84-broker-e-debito-jam.md` | HiveMQ di riserva, prove a mano rimaste e debito della fase 74 |
| 85 | `fase-85-debito-review-83.md` | Debito della review di architettura della 83 |
| 86 | `fase-86-jam-media.md` | `JamMedia` fuori da `jam_providers.dart` |
| 87 | `fase-87-rete-superfici.md` | Refactor «superfici-e-ricerca»: rete di sicurezza e misure di partenza |
| 88 | `fase-88-ritocchi-rapidi.md` | Suggeriti senza doppioni, Home, play tondo, Ordina per, Cerca |
| 89 | `fase-89-dock-e-sezioni.md` | Dock flottante, sfocatura nel Tema, sezioni che ripartono |
| 90 | `fase-90-intestazioni-che-scorrono.md` | Tutti i brani e isola della Libreria che seguono lo scroll |
| 91 | `fase-91-ordinamenti-e-playlist.md` | Ordinamenti e foglio Nuova playlist / Aggiungi alla playlist |
| 92 | `fase-92-cerca-libreria-e-artisti.md` | Cerca: Nella tua libreria, righe di artisti e album |
| 93 | `fase-93-dati-per-i-filtri.md` | Più generi, nazionalità dell'artista, BPM ed etichetta |
| 94 | `fase-94-playlist-intelligenti.md` | Playlist intelligenti a filtri multipli |
| 95 | `fase-95-artisti-uniti.md` | Artisti con due profili YouTube Music |
| 96 | `fase-96-podcast-scopri.md` | Podcast: Scopri (Apple) e programmi di YouTube Music |
| 97 | `fase-97-chiusura-superfici.md` | Chiusura del refactor «superfici-e-ricerca» |
| 98 | `fase-98-rete-ascolto.md` | Refactor «ascolto-quotidiano»: rete, formattazione di 4 file, script delle misure |
| 99 | `fase-99-debito-artisti.md` | Debito: 429 unico, chiave artista, scaffali, paesi |
| 100 | `fase-100-coda-simili-artista.md` | Coda di simili da Cerca, Play/Shuffle di tutti i brani dell'artista |
| 101 | `fase-101-non-mi-piace.md` | «Non mi piace» brano o artista, player del suggerito |
| 102 | `fase-102-podcast-senza-iscrizione.md` | Podcast senza iscrizione (v19), episodi in «Riprendi» |
| 103 | `fase-103-testi-e-memoria.md` | Testi a mano, sincronia spegnibile, Memoria |
| 104 | `fase-104-daylist.md` | Daylist a fasce orarie |
| 105 | `fase-105-chiusura-ascolto.md` | Chiusura del refactor «ascolto-quotidiano» |
| 106 | `fase-106-testi-traslitterati.md` | Testi traslitterati in alfabeto latino (giapponese, cinese, coreano) |
| 107 | `fase-107-rete-coda-libreria.md` | Refactor «coda-e-libreria»: rete (caratterizzazione della coda, ricerca, titoli) e misure di partenza sul Mi A3 |
| 108 | `fase-108-coda-blocco-utente.md` | «Aggiungi in coda» come blocco in cima alla coda, «Riproduci dopo» tolto, Shuffle+ dopo il blocco |
| 109 | `fase-109-titoli-che-scorrono.md` | Titoli lunghi che scorrono (player, mini player, barra desktop, Jam) |
| 110 | `fase-110-libreria-e-playlist.md` | Statistiche in Impostazioni, «Scaricati senza playlist», ricerca nelle playlist, accenti nella ricerca |
| 111 | `fase-111-pausa-volume-zero.md` | Pausa a volume zero (Android e desktop), interruttore in Riproduzione |
| 112 | `fase-112-link-in-cerca.md` | Link incollati in Cerca: playlist e canali YouTube in una pagina in streaming, album YouTube Music, singolo video che suona subito |
| 113 | `fase-113-chiusura-coda-libreria.md` | Chiusura del refactor «coda-e-libreria» |
| 114 | `fase-114-link-spotify-deezer.md` | Link Spotify e Deezer in Cerca: pagina in streaming con abbinamento in sottofondo (feature `feature-link-e-shazam.md`) |
| 115 | `fase-115-salva-e-condividi.md` | Brani in streaming nelle playlist, «Salva in Libreria», «Aggiorna», «Condividi verso FreeKmusic» (feature `feature-link-e-shazam.md`) |
| 116 | `fase-116-brani-da-shazam.md` | Brani da Shazam in «Da Shazam» (ferma finché manca un testo vero condiviso da Shazam, R-210; feature `feature-link-e-shazam.md`) |

Dopo la **Fase 3** l'app è già usabile come lettore. Le fasi 5 e 6 sono indipendenti tra loro. La fase 8 (Jam) richiede la 6.

**Fasi 13–26** (dopo la base): raggruppate per area, così ogni fase tocca un sottosistema solo. Ordine consigliato
quello della tabella; dipendenze vere: 15 ← 13 + 14 · 18 ← 17 · 20 ← 19 (selezione multipla per le etichette) ·
21 ← 20 (fusione della cronologia) · 23 ← 17 (segnalibro) · 24 ← 13 (formato portabile) · 26 ← 16 (CI).
Le altre si possono spostare. Le versioni di schema (v5…v10) sono assegnate in quest'ordine: se se ne salta una,
si usa la prossima libera. Ogni fase elenca i **pacchetti nuovi da approvare** prima del task che li usa.

## Come lanciare una fase (prompt da incollare)
```
Leggi CLAUDE.md, docs/01-regole-di-lavoro.md, docs/PROGRESS.md e docs/fase-N-<nome>.md.
Esegui i task della fase N in ordine, uno alla volta. Dopo ogni task: flutter analyze,
flutter test, spunta il task in docs/PROGRESS.md. Fermati se un criterio di verifica
non è soddisfatto o se serve un'azione dell'utente (sudo, dispositivo fisico).
```
Per riprendere dopo una pausa: stesso prompt, l'agente riparte dal primo task non spuntato.

## Convenzione dei task
Ogni task ha: **ID**, **File** da creare/modificare, **Passi** numerati, **Verifica** eseguibile.
Un task deve stare in una sola sessione breve; se è troppo grande, spezzalo e annota in PROGRESS.

## Modalità autonoma (`/obiettivo`)
Avvia Claude Code nella radice del progetto (`codecore-music-player/`) e digita:
| Comando | Effetto |
|---|---|
| `/obiettivo` | Esegue la prossima fase non chiusa |
| `/obiettivo fase 2` | Solo quella fase |
| `/obiettivo stato` | Riassunto: task fatti, prossimo, «Tocca a te» |
| `/obiettivo pausa` | Si ferma subito (puoi anche premere Esc e scrivere «stop») |
| `/obiettivo riprendi` | Riparte dal primo task non spuntato |

Cosa fa (skill globale `~/.claude/skills/obiettivo/`, profilo `.claude/obiettivo.md`): una PR per fase in auto-merge,
un commit per task, test mirati in locale e suite completa in CI. Le cose che solo tu puoi fare
(sudo, telefono, ascolto) finiscono in «Tocca a te» nel file `.claude/obiettivi/*.md` senza fermare il resto.
