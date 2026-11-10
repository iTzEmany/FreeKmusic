# Idee future per FreeKmusic

Raccolta ragionata di ciò che si potrebbe aggiungere **dopo la fase 12**. Non è un piano: ogni voce, quando la si
vuole fare, diventa un documento di fase (`fase-N-*.md`) con task e verifiche, come le altre.

Scritta il 2026-10-16, a base completata (fasi 0–12). Punto di partenza: app standalone Flutter per Android,
Linux e Windows; libreria locale, player con coda, playlist, testi, arricchimento web, download da YouTube con
yt-dlp, condivisione LAN, Jam (anche sincronizzata), interfaccia nero/viola, importazione di playlist Spotify da CSV.

## Dove è finita ogni idea (2026-10-16)
Le voci rimaste in questo file sono state divise in fasi per gruppi compatibili (stessa area di codice):
| Fase | Idee |
|---|---|
| 13 | Backup e ripristino · export playlist M3U8/CSV/JSON · esportazione del log |
| 14 | Aggiornamento yt-dlp · download in parallelo · ritento a scalare · formato senza ricodifica · ISRC · cache delle ricerche · controllo «brano sbagliato» · validazioni di rete |
| 15 | Import M3U/XSPF/CSV generici · «Sincronizza da CSV» · import per album · tutte le idee specifiche della fase 12 |
| 16 | CI · test d'integrazione su telefono · live notturni · golden · verifica dipendenze · profilo 50.000 brani |
| 17 | Velocità · segnalibro «riprendi da qui» · anteprima al tocco prolungato · equalizzatore · MPRIS/SMTC · controlli Jam in notifica |
| 18 | Gapless e crossfade |
| 19 | Selezione multipla · trascinare su playlist · tema chiaro/accento · tablet · altre lingue · onboarding |
| 20 | Cronologia · statistiche · ricerca con operatori · playlist intelligenti · etichette |
| 21 | Duplicati · merge/split album · scrittura tag nei file |
| 22 | SoundCloud · playlist e canali YouTube · traduzione testi on-device |
| 23 | Podcast (RSS) |
| 24 | Abbinamento · TLS · scanner QR · sincronizzazione playlist tra dispositivi |
| 25 | Widget e tile Android · Android Auto / Wear OS · modalità in auto |
| 26 | Pacchetti Linux · installer Windows · APK più piccolo · avviso aggiornamenti · F-Droid · macOS/iOS · documentazione utente |

## Come leggere le tabelle
| Colonna | Significato |
|---|---|
| **Valore** | quanto cambia l'uso quotidiano: ★★★ alto · ★★ medio · ★ di nicchia |
| **Costo** | S = un paio di task · M = una fase piccola · L = una fase grande o più |
| **Rischio** | cosa può andare storto (rete, piattaforma, licenze, regressioni) |

---

## Le dieci che farei per prime
Ordinate per «valore ÷ costo», tenendo conto dei difetti già visti sul campo.

| # | Idea | Perché adesso |
|---|---|---|
| 1 | **Backup e ripristino** (DB + impostazioni + copertine in un file) | Oggi playlist, preferiti, testi e importazioni vivono solo nel DB: un telefono perso o una disinstallazione li cancella. Costo basso, rete di sicurezza enorme. |
| 2 | **Export delle playlist** (M3U8 e CSV) e **import M3U/M3U8** | Chiude il cerchio con la fase 12 (entra solo da Exportify); sblocca altri lettori e altri servizi. |
| 3 | **Aggiornamento di yt-dlp in-app su desktop** (e avviso «versione troppo vecchia») | È la causa n. 1 di «non funziona più»: su Linux il `yt-dlp` di sistema era del 2024 e dava «Please sign in». Su Android si aggiorna già da solo. |
| 4 | **Download in parallelo (2–3) con ritento a scalare** | L'importazione di 34 brani è durata ~25 min sul telefono; i 403 transitori si risolvono quasi sempre al secondo giro. |
| 5 | **Gapless** | È l'ultimo vero buco del «lettore serio» (album dal vivo, classica, concept album). Rimandato per rischio sul backend nativo. |
| 6 | **Controlli multimediali di sistema su desktop (MPRIS / SMTC)** | Tasti multimediali e widget del sistema che funzionino a finestra non attiva. Molto atteso, piccolo. |
| 7 | **Selezione multipla nelle liste** (aggiungi a playlist, in coda, elimina, scarica) | Rimandata in fase 11; è il gesto che manca di più quando le playlist crescono. |
| 8 | **Sincronizza playlist da CSV** (rileggi un export aggiornato e applica solo le differenze, anche rimozioni) | Estende naturalmente la fase 12: la playlist Spotify cambia, la tua copia la segue. |
| 9 | **Ricerca duplicati e pulizia libreria** (stesso brano in più cartelle/qualità) | Dopo importazioni e download i doppioni arrivano da soli. `sha256` è già in schema. |
| 10 | **CI su GitHub** (analyze, test, build apk/linux/windows) | Windows non si compila da Linux: senza CI l'app «per Windows» resta una promessa. |

---

## 1. Riproduzione e audio
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Gapless (e crossfade opzionale) | ★★★ | L | Richiede di riscrivere la coda sul backend nativo (ExoPlayer `ConcatenatingMediaSource` / mpv playlist). Rischio alto: la Jam sincronizzata dipende dal modello attuale. Fare dietro un flag. |
| Equalizzatore (preset + 10 bande) | ★★ | M | Android: `AudioEffect`; desktop: filtro mpv. Salvare per uscita (cuffie / altoparlante). |
| Velocità di riproduzione (0,5×–2×) con mantenimento del tono | ★★ | S | Utile per podcast/audiolibri; già c'è il controllo di velocità interno alla Jam. |
| Segnalibro «riprendi da qui» per tracce lunghe | ★★ | S | Per audiolibri, DJ set, registrazioni: ricorda la posizione per brano oltre una soglia (es. 20 min). |
| MPRIS (Linux) e SMTC (Windows) | ★★★ | M | Controlli e metadati nel sistema, anche a finestra non attiva. Dietro l'interfaccia `AudioBackend`/handler esistente. |
| Controlli della Jam nella notifica/lock screen | ★★ | M | Oggi la Jam non ha i controlli di notifica (rimandato in 8.8). |
| Android Auto / Wear OS | ★ | L | Richiede browsing tree di `audio_service`; testare in auto reale. |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
| Anteprima al tocco prolungato sulla copertina | ★ | S | Ascolta 20 s senza cambiare la coda. |

## 2. Libreria e metadati
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Ricerca duplicati (hash, titolo+artista+durata) e fusione | ★★★ | M | Mostrare sempre un'anteprima; mai cancellare file senza conferma esplicita. |
| Scrittura dei tag nei file (copia temporanea + `rename` atomico) | ★★ | M | Decisione v1: «solo DB». Se si riapre: mai in-place; backup del file; solo per formati noti (MP3/FLAC/M4A). Vedi R10. |
| Playlist intelligenti (regole: genere, anno, mai ascoltati, aggiunti di recente) | ★★★ | M | Query salvate sul DB: riuso di `library_queries`. |
|  |  |  |  |
| Statistiche di ascolto («recap» mensile/annuale) | ★★ | M | I dati ci sono già (`playCount`, `lastPlayedAt`); manca la cronologia per evento. |
| Cronologia di ascolto con data/ora | ★★ | S | Nuova tabella `plays`; base per statistiche e scrobbling. |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
| Merge/split manuale di album | ★★ | S | Utile dopo importazioni con tag da CSV diversi. |
| Etichette personalizzate (tag utente) | ★ | M | Filtri e playlist intelligenti. |

## 3. Importazione ed esportazione
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Esporta playlist: M3U8, CSV, JSON | ★★★ | S | Percorsi relativi opzionali; CSV con le stesse colonne di Exportify per il giro inverso. |
| Importa M3U/M3U8/XSPF e CSV generici (TuneMyMusic, Soundiiz, Last.fm) | ★★★ | M | Riuso del motore della fase 12: cambia solo il lettore (`*_reader.dart`). |
| Backup e ripristino completo (zip: DB, impostazioni, copertine, `downloads.json`) | ★★★ | M | Include un numero di versione dello schema; il ripristino passa per le migrazioni. |
| Sincronizzazione playlist tra i propri dispositivi (via LAN) | ★★ | L | Conflitti: «ultima modifica vince» per playlist, con anteprima. Riuso del canale di condivisione. |
| «Sincronizza da CSV» (differenze: aggiunte e rimozioni) | ★★ | M | Usa `isrc`/chiave titolo+artista già salvati negli item. |
|  |  |  |  |
|  |  |  |  |
| Importazione da album intero (cerca l'album, non il singolo) | ★★ | M | Migliora la coerenza di album/copertina; ricerca per `Album Name` + numero tracce. |
|  |  |  |  |
|  |  |  |  |

## 4. Download e fonti online
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Download in parallelo (2–3) con limite di banda | ★★★ | S | La coda è oggi sequenziale (`DownloadQueue`); servono ritento e backoff su 403/429. |
| Ritento a scalare con ripresa dopo errori transitori | ★★★ | S | Fatto un ritento singolo in fase 12: generalizzare con tentativi e pausa crescenti. |
| Aggiornamento di yt-dlp in-app (desktop) e controllo versione all'avvio | ★★★ | M | Scarica il binario ufficiale in una cartella dell'app, verifica la firma/hash, avvisa se < versione minima. |
| Scelta formato/qualità e **nessuna ricodifica** (tenere Opus/M4A) | ★★ | S | MP3 256k da sorgente ~160 kbps Opus è solo più grande. Controllare supporto del lettore tag. |
| Fonti alternative: SoundCloud | ★★ | M | yt-dlp li supporta; il punteggio di `track_matcher` va adattato (niente canale «- Topic»). Filtrare le anteprime da 30 s. |
| Ricerca per ISRC come primo tentativo | ★★ | S | Riduce i «da verificare»; non sempre indicizzato. |
| Cache dei risultati di ricerca per riga (evita rifare 34 ricerche) | ★ | S | Utile quando si reimporta una playlist cambiata poco. |
| Playlist e canali YouTube come sorgente | ★★ | M | Già gestibile con `--flat-playlist`; manca la UI. |
| Podcast (RSS) con episodi scaricabili | ★★ | L | Nuovo dominio (episodi, stato «ascoltato», pulizia automatica). |
|  |  |  |  |
| Traduzione dei testi on-device | ★ | M | ML Kit solo Android; esclusa dalla v1 per non usare endpoint non ufficiali. |
| Rilevamento «brano sbagliato» a download concluso (confronto durata/impronta) | ★★ | L | Impronta audio (Chromaprint) per confermare il brano. |

## 5. Condivisione, Jam e dispositivi
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Cifratura TLS con certificati autofirmati e *pinning* all'abbinamento | ★★ | M | Oggi HTTP in chiaro con PIN: limite accettato per reti domestiche. |
| Abbinamento dispositivi (una volta sola) e fiducia reciproca | ★★ | M | Evita il PIN a ogni invio; elenco dispositivi fidati. |
| Scanner QR (invito/PIN) | ★ | S | Era opzionale nella fase 6; richiede `mobile_scanner` (permesso fotocamera). |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

## 6. Interfaccia e accessibilità
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Selezione multipla nelle liste + barra azioni | ★★★ | M | Rimandata dalla fase 11. |
| Trascinare brani sulle playlist (desktop) | ★★ | M | Rimandata dalla fase 11. |
| Tema chiaro e temi personalizzati (colore d'accento) | ★★ | M | I token ci sono; i contrasti vanno ricontrollati (AA) per ogni tema. |
| Widget Android (in riproduzione, controlli) e tile rapida | ★★ | M | `home_widget`; aggiornamento dallo stato del player. |
| Modalità in auto (pulsanti grandi, niente liste lunghe) | ★ | M | Utile se non si arriva ad Android Auto. |
| Layout tablet/ripiegabili | ★ | M | Il layout a tre zone esiste già ≥ 840 px: verificare ≥ 1200 px. |
|  |  |  |  |
| Ricerca globale con filtri e operatori («artista:», «anno:») | ★★ | M | Estende la ricerca SQL esistente. |
|  |  |  |  |
|  |  |  | |
|  |  |  |  |
| Altre lingue (fr, pt, ru…) | ★ | S | Dopo it/en/de/es: solo ARB; il resto è già pronto. |
| Onboarding al primo avvio | ★ | S | Scelta cartelle, permessi, spiegazione dei download (con avviso legale). |

## 7. Piattaforme, distribuzione e aggiornamenti
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| CI GitHub Actions: analyze + test + build (apk, linux, windows) | ★★★ | M | Windows si compila solo su Windows (R6). Artefatti ad ogni tag. |
| Pacchetti Linux: AppImage / .deb / Flatpak | ★★ | M | `libmpv` come dipendenza; Flatpak limita l'accesso ai processi esterni (yt-dlp). |
| Installer Windows (MSIX o Inno Setup) con yt-dlp e ffmpeg inclusi | ★★ | M | Licenze: yt-dlp è Unlicense, ffmpeg dipende dalla build (LGPL/GPL): verificare quella inclusa. |
| Aggiornamento automatico dell'app (controllo della versione) | ★ | M | Solo uso personale: bastano release firmate e un avviso. |
| Distribuzione F-Droid | ★ | M | Richiede build riproducibile e assenza di blob (la libreria yt-dlp-android è GPL-3.0). |
| macOS / iOS | ★ | L | Fuori dagli obiettivi; il codice è quasi portabile, mancano le prove. |
| Riduzione della dimensione dell'APK (ABI split, rimuovere Python/QuickJS se non serve) | ★★ | M | Oggi ~250 MB in debug, ~65 MB in release arm64. |

## 8. Qualità, sicurezza e manutenzione
| Idea | Valore | Costo | Rischio / note |
|---|---|---|---|
| Test d'integrazione automatici su telefono (`integration_test`) | ★★★ | M | Le prove di fase 6–12 oggi sono manuali con `adb`: scriverle una volta le rende ripetibili. |
| Test «live» opzionali in CI notturna (YouTube Music, iTunes, LRCLIB) | ★★ | S | Già presenti in `test/live/` dietro `CODECORE_LIVE=1`: serve solo pianificarli e leggere l'esito. |
| Golden test delle schermate principali (100 % e 150 %) | ★★ | M | `test_shots/` esiste fuori da `flutter test`: promuoverli a confronto automatico. |
| Esportazione del log per segnalare un problema | ★★ | S | `codecore.log` è già ruotato: aggiungere «Condividi log» (senza dati personali). |
| Verifica periodica delle dipendenze (`flutter pub outdated`, advisory) | ★ | S | 16 pacchetti hanno versioni nuove incompatibili con i vincoli attuali. |
| Rafforzare le validazioni di rete (dimensione massima CSV, timeout per riga) | ★ | S | Un CSV da 100 MB oggi viene letto tutto in memoria. |
| Profilo prestazioni su 50 000 brani | ★ | S | Misurato fino a 20 000 (ricerca ~40 ms). |
| Documentazione utente (una pagina per funzione, con immagini) | ★★ | M | Oggi la guida è nel README e nei documenti di fase. |

---

## Idee specifiche per la fase 12 (importazione da CSV)
Piccoli miglioramenti che nascono dall'uso reale (34 brani, ~25 min su telefono, 2–4 errori 403 per giro):

1. **Anteprima degli abbinamenti prima di scaricare**: tabella «riga del CSV → candidato scelto (canale, durata, punteggio)» con la possibilità di cambiare prima dell'avvio. Oggi si vede solo dopo.
2. **Soglie regolabili** («sicuro» ≥ 0,80, «da verificare» ≥ 0,55) in Impostazioni avanzate, per chi preferisce più revisioni o meno.
3. **Contatore e stima del tempo residuo** nella riga del Centro Attività (oggi solo `fatti/totali`).
4. **Importa in una cartella dedicata** per playlist (opzionale) e **nome file con numero d'ordine** per riprodurre la cartella nel giusto ordine anche fuori dall'app.
5. **Saltare i brani già scaricati con altro nome** (confronto per `videoId` in `downloads.json` oltre che per titolo/artista) — è già usato come ripiego, ma non nell'anteprima.
6. **Copertina dalla riga del CSV**: il CSV non ha immagini, ma `Album Name` + `ISRC` permettono una ricerca iTunes più precisa del solo titolo.
7. **Ricerca per ISRC** come primo tentativo e **cache delle ricerche** per le reimportazioni.
8. **Esito dettagliato esportabile** (quali righe, perché «non trovate») per poterle correggere a mano nel CSV.
9. **Avviso se il CSV contiene più di N brani** (stima in ore) e proposta di dividere in blocchi.
10. **Modalità «solo collega»** (nessun download): crea la playlist con quello che c'è già e basta, utile per verificare la copertura della libreria.

## Cose che non farei (e perché)
- **Aggirare DRM** o usare servizi non ufficiali di Deezer/Tidal/Qobuz/Spotify: account bannati, rotture continue, e fuori dallo spirito «uso personale» con fonti pubbliche.
- **Scrivere i tag in-place** senza copia atomica: un errore a metà scrittura corrompe il file dell'utente.
- **Telemetria o analytics**, anche anonimi: contraddice la regola 9 di `01-regole-di-lavoro.md`.
- **Server centrale** per Jam/sincronizzazione: introdurrebbe un backend da mantenere e dati da proteggere.
- **Scraping fragile come funzione principale** (pagine embed, endpoint interni): va bene come ripiego dichiarato, non come base.
- **Più formati di coda/riproduzione paralleli** (due motori audio permanenti): la Jam ne usa già un secondo; non moltiplicare.

## Dipendenze tra le idee
```
Backup ──► Sync tra dispositivi ──► Pairing + TLS
Export M3U/CSV ──► Import M3U/CSV generici ──► Sincronizza da CSV
Cronologia ascolti ──► Statistiche/recap ──► Playlist intelligenti ──► Scrobbling
Download in parallelo ──► Ritento a scalare ──► Aggiornamento yt-dlp in-app
Gapless ──► Crossfade ──► (rivedere la sincronia della Jam)
CI ──► Test d'integrazione su telefono ──► Pacchetti/installer
```

## Come trasformare un'idea in una fase
1. Scrivere `docs/fase-N-<nome>.md` come le altre: obiettivo, prerequisiti, decisioni, task con **File / Passi / Verifica**, rischi, Definition of Done.
2. Aggiungerla a `docs/00-INDICE.md` e i task a `docs/PROGRESS.md`.
3. Per le funzioni di rete, aggiungere una prova «dal vivo» opzionale in `test/live/` (come `import_live_test.dart`) e annotare nel documento quali parti **non** si possono automatizzare (selettore file di sistema, schermata di blocco…).
