# Fase 147 — Verifica finale sul telefono e misure

## Obiettivo
Si prova sul telefono dell'utente (Motorola edge 40) ciò che i test non possono provare, si misura che le metriche di arrivo di `rete.md` siano rispettate e si chiude la grande revisione: documenti d'area aggiornati e nessun rilievo F-01..F-41 aperto senza motivo. Fuori: nuove funzioni.

## Riferimenti
D-662..D-699; rilievi e prove L1-L7 in [`../storico/refactor/grande-revisione/analisi.md`](../storico/refactor/grande-revisione/analisi.md); rete di test, metriche e prove su telefono in [`../storico/refactor/grande-revisione/rete.md`](../storico/refactor/grande-revisione/rete.md) (riga 147 e sezione «147»); mockup in `../storico/refactor/grande-revisione/mockup/` (confronto a vista). Profilo e regole sulle prove su telefono: `.claude/obiettivo.md` (`scripts/telefono.py <serial> prepara|sblocca|avvia|testi|tocca|aspetta|foto|audio`, output corto, tetto di circa 60 chiamate per flusso). **Il Motorola ZY22HKD85K è il telefono dell'utente, non di prova**: niente disinstallazioni, niente file toccati, nessuna modifica ai permessi o al volume fatta dall'agente; il log si esporta da Impostazioni › Avanzate › Esporta log. I telefoni di test (Mi A3 `0d7ae9df206e`, Redmi `8bbad1cd`) si usano per le prove distruttive, a volume 0 e ripuliti a fine prova (D-502).

## Task
- [x] 147.1 Proposta all'utente: come mettere la build sul Motorola — **chiedere prima, non decidere**
  - File: nessuno da scrivere.
  - Passi: 1) l'app sul Motorola è la release 1.6.4 firmata con la chiave di D-569: un APK di debug avrebbe firma diversa e richiederebbe la disinstallazione, che è vietata; 2) proporre all'utente (testo nel terminale, opzioni numerate): (a) una Release (tag e versione decisi dall'utente) dalla CI e aggiornamento dall'app (prova anche la fase 132); (b) prova sui soli telefoni di test, e sul Motorola solo il log dell'uso normale; 3) registrare la scelta in `../decisioni.md`.
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: la scelta è registrata; i task 147.3-147.6 sono aggiornati di conseguenza.
- [x] 147.2 Metriche di arrivo (rete.md)
  - File: nessuno in `lib/`; il risultato si scrive nelle «Note di deviazione» di questo file.
  - Passi: 1) eseguire i controlli per fase: coda illeggibile ≤ 3 tentativi e 1 popup (135); client finto ≤ 1 richiesta MB per ISRC e 0 dopo un 503 (136); N non trovati → lista di N (137); `grep -n "color: cc.bg" lib/ui/screens/library/all_tracks_screen.dart` = 0 (138); `grep -rn downloadsProvider lib/ui` un solo widget (139); migrazione su DB con brani locali: 0 righe modificate (140); le 8 pagine con una sola testata (141); 2 colonne sul telefono e 3 su desktop (142); invii solo da un tasto, `grep` sulle chiamate della segnalazione (143); 20 lingue + CEDICT + Spleeter (144); link per N brani sotto il limite scelto (145); stessi insiemi sui due DB, 0 file cancellati (146); 2) riportare l'esito per fase; 3) i test che coprono le metriche si lanciano mirati, non la suite intera.
  - Comando mirato: `flutter analyze` + i test mirati citati nelle fasi 135-146 (la suite completa la esegue la CI)
  - Fatto quando: una riga per fase con esito «ok» o con il motivo dello scarto.
- [ ] 147.3 Prove L1-L3 sul telefono: permesso, daylist, riavvio (D-678, D-679) (dopo il tag v1.7.0, dell'utente)
  - File: nessuno; si usa `scripts/telefono.py` e il log esportato.
  - Passi: 1) **l'utente** toglie il permesso audio dal telefono (Tocca a te): un solo avviso, banner in home e coda ferma; 2) l'utente ridà il permesso: i brani locali e la daylist suonano (L1, L2); 3) con coda illeggibile (permesso tolto) riavviare l'app: 0 popup (L3); 4) leggere il log esportato dall'utente e riportare le righe rilevanti.
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K avvia` e `testi` (output corto)
  - Fatto quando: il log mostra un solo avviso e nessun «Source error» a catena; i brani suonano dopo aver ridato il permesso.
- [ ] 147.4 Prove L4-L6: karaoke, correzioni, arricchimento (D-664, D-685, D-686, D-683) (dopo il tag v1.7.0, dell'utente)
  - File: nessuno.
  - Passi: 1) karaoke ancora acceso dopo il riavvio, nessuna separazione prima del play, promemoria dopo 20 minuti (L4); 2) correzione di una riga stream senza `unsupported` nel log (L5); 3) un giorno di uso normale: pochi 503, nessun riarricchimento delle stesse righe (L6), dal log esportato.
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K aspetta` e lettura del log esportato
  - Fatto quando: le tre prove hanno esito scritto nelle «Note di deviazione».
- [ ] 147.5 Prove L7 e aggiornamento: ripristino «Sostituisci», popup di versione (D-680, D-682) (dopo il tag v1.7.0, dell'utente)
  - File: nessuno.
  - Passi: 1) **prima**: backup completo dell'utente dall'app (Tocca a te); 2) «Sostituisci» con un backup: l'app si riavvia da sola con processo nuovo (verificare il PID prima e dopo con `adb shell pidof`, sola lettura); 3) il popup della nuova versione si apre con un tocco ovunque (con una versione più recente disponibile, da 147.1). **Nota**: la 1.6.4 installata mostra ancora il popup vecchio, quindi questo passo si prova alla release successiva alla 1.7.0 (D-704 lo promette per il tag v1.7.0: qui la correzione).
  - Comando mirato: `python3 scripts/telefono.py ZY22HKD85K tocca` / `testi`
  - Fatto quando: il PID cambia dopo «Sostituisci»; il popup apre il dialogo.
- [ ] 147.6 Prove di streaming, download, condivisione, sync (D-665, D-695, D-697, D-677, D-668) (dopo il tag v1.7.0, dell'utente)
  - File: nessuno.
  - Passi: 1) aggiunte in streaming con i file locali intatti (conteggio dei file di `Music/FreeKmusic` prima e dopo, in sola lettura); 2) barra di download nel player e menu ⋮ che passa a «scaricato»; 3) condivisione su WhatsApp dal telefono (Tocca a te); 4) sync fra due dispositivi dell'utente (Tocca a te) o fra due telefoni di test, con cancellazioni, verificando che nessun file sparisca.
  - Comando mirato: `python3 scripts/telefono.py <serial> foto` (una foto per schermata, letta e poi cancellata con `~/.claude/skills/obiettivo/scripts/pulizia.sh via`)
  - Fatto quando: ogni voce ha esito scritto; il conteggio dei file locali è invariato.
- [x] 147.7 TalkBack con uiautomator (memoria: solo verifiche automatiche)
  - File: nessuno; `test/ui/a11y_guidelines_test.dart` e `test/ui/accessibility_characterization_test.dart` come base.
  - Passi: 1) con `uiautomator` (output corto) verificare etichette e dimensioni delle schermate nuove: testata a icone, griglia del Riprendi, barra di scorrimento, pagina Modelli, segnalazione, `DownloadBar`; 2) niente prove a mano con TalkBack; 3) lanciare i due test di accessibilità.
  - Comando mirato: `flutter test test/ui/a11y_guidelines_test.dart test/ui/accessibility_characterization_test.dart`
  - Fatto quando: nessun controllo sotto 48 dp o senza etichetta nelle schermate nuove.
- [x] 147.8 Pulizia e chiusura (parte documentale; telefoni e rilascio restano all'utente)
  - File: `docs/prossimi-lavori.md` (rilievi rimandati, se ce ne sono), `docs/handoff.md`, `docs/storico/README.md` (righe delle fasi 135-147), `docs/refactor/grande-revisione/` (spostare in `docs/storico/refactor/` con `git mv`).
  - Passi: 1) a volume 0 sui telefoni di test e ripulire tutto ciò che si è messo (D-502); sul Motorola non si tocca nulla; 2) cancellare foto e log già usati con `~/.claude/skills/obiettivo/scripts/pulizia.sh via`; 3) spostare la cartella del refactor nello storico e aggiornare i link; 4) fermare ogni shell in background; 5) proporre all'utente il rilascio (numero di versione e tag decisi da lui).
  - Comando mirato: `python3 scripts/check_docs_links.py`
  - Fatto quando: link verdi; telefoni di test puliti e a volume 0; il Motorola senza modifiche.
- [x] 147.9 Area e controllo di fine fase
  - Aggiorna i documenti d'area toccati dalle fasi 135-146 se qualcosa è rimasto indietro (`../architettura/00-panoramica.md`, `qualita-e-rilascio.md` con il risultato delle misure); `../decisioni.md` per le scelte prese in 147.1 e nelle proposte di 143, 145, 146.

## Tocca a te
- [ ] Telefono collegato (Motorola ZY22HKD85K, e i telefoni di test per le prove distruttive) con debug USB e schermo sbloccabile.
- [ ] Concedere/togliere il permesso `READ_MEDIA_AUDIO` dal telefono quando richiesto (L1/L2); farlo dall'agente non è previsto.
- [ ] Fare un backup completo dall'app prima di «Sostituisci».
- [ ] Provare la condivisione su WhatsApp e il sync fra due dispositivi.
- [x] Decidere come mettere la build sul Motorola (147.1) e la versione di rilascio (D-704: release 1.7.0).
- [ ] Versione già alzata in questa PR (`1.7.0+14`): dopo il merge crea il tag `v1.7.0`.
- [x] Prima del tag: deploy del Worker (`cd tools/report-worker && npx wrangler deploy`) e indirizzo in `kReportEndpoint` (`lib/core/constants.dart`), oppure accettare la 1.7.0 senza invio anonimo delle segnalazioni. Fatto il 24/11: `https://freekmusic-report.itzemany.workers.dev/`.
- [ ] Motorola, a mano: «Apri in FreeKmusic» toccato dalla pagina di condivisione in un browser vero, e App Link verificato con l'APK di release (`adb shell pm get-app-links`, sola lettura).
- [ ] Motorola o Mi A3: importazione completa di una playlist da link con yt-dlp che risponde (sul Mi A3 le ricerche vanno in timeout dopo 45 s).
- [ ] Motorola o Mi A3: condivisione di una playlist con più di 50 brani in streaming (file m3u8) e apertura del file dall'altra parte.
- [ ] Mi A3 o Redmi (solo l'app, mai i file già presenti): `JamSaver`, l'ospite salva un brano dell'host nella cartella pubblica su Android 11+; la copia deve finire dove la scansione la trova.
- [ ] Mi A3 e Redmi come «miei» (mai il Motorola): «Sincronizza ora» con aggiunte e rimozioni, conferma, impostazioni scelte, dispositivo non «mio» che porta solo playlist; nessun file sparisce.
- [ ] Mi A3: «Elimina» del karaoke con una separazione in corso; cancellazione di molte lingue di traduzione ML Kit (misurare la rilettura delle 20 lingue e il ritardo di `isModelReady`).
- [ ] Motorola o Mi A3 con la rete: il download del dizionario avviato dal testo di un brano cinese con pinyin mostra «In scaricamento…» e l'avanzamento.
- [ ] Mi A3 con la rete: accessibilità di barra alfabetica (con più brani), `DownloadBar` e «Scarica» nelle testate, rimasti fuori dal controllo offline (uiautomator, 48 dp ed etichette).
- [ ] Dopo il tag v1.7.0: 147.3-147.6 sul Motorola (permesso L1-L3, karaoke e arricchimento L4-L6, «Sostituisci» e popup di versione L7, streaming/download/WhatsApp/sync).


## Note di deviazione

- **147.2 Metriche di arrivo.** Test mirati eseguiti in un comando (258 test verdi, exit 0): `codecore_audio_handler_test`, `enrich_engine_test`, `musicbrainz_client_queue_test`, `enrichment_credits_test`, `backup_merge_test`, `migration_test`, `collection_pages_more_test`, `collection_header_test`, `resume_episode_row_test`, `report_issue_screen_test`, `model_catalog_test`, `external_share_text_test`, `external_share_test`, `sync_two_devices_test`, `architecture_test`. `flutter analyze` non rieseguito in questo task.
  - 135: ok — `codecore_audio_handler_test`: «five unreadable tracks: three attempts, three errors…, then idle» e «stops the queue and says so once».
  - 136: ok — `enrichment_credits_test` («MusicBrainz by ISRC at most once»), `enrich_engine_test`; dopo un 503, `musicbrainz_client_queue_test` («rests 1, 5, 15, 15 minutes after each 503»).
  - 137: ok — `backup_merge_test` («a track the library lacks is listed as not found», `r.notFound` = lista dei non trovati).
  - 138: ok — `grep -c "color: cc.bg" lib/ui/screens/library/all_tracks_screen.dart` = 0.
  - 139: ok con deviazione già nota (139.4) — `grep -rn downloadsProvider lib/ui` mostra una sola barra (`download_bar.dart`, `DownloadBar`) ma altri 4 file lo osservano solo per trovare l'`item` della riga (`online_song_row`, `online_results_sections`, `genre_screen`, `suggestions_screen`) più `activity_sheet` per `cancel`; la metrica letterale «un solo widget» non regge, quella sostanziale (una sola barra) sì.
  - 140: ok — `migration_test` (v19/v20/v23: «rows otherwise unchanged»); la v19 aggiunge `tracks.saved` lasciando invariate le righe dei brani locali.
  - 141: ok — le 8 pagine che usano `CollectionScaffold(` (playlist, album, smart, preferiti, genere, podcast, artista, tag) con `collection_header_test` e `collection_pages_more_test` («one header with Play, Casuale…»).
  - 142: ok — `resume_episode_row_test` («the grid has $columns columns at $width dp», «a block of $blockWidth dp has $columns columns»); resta la nota sulla soglia dei 560 dp per il blocco (in `../prossimi-lavori.md`, «Riproduzione e coda»).
  - 143: ok — una sola chiamata di invio, `issueSenderProvider...send` in `report_issue_screen.dart:80` dentro `_send`, legato al solo `onPressed` (riga 195); `ReportIssueScreen(` si apre dal Registro e da `enrich_round_screen` senza inviare; `report_issue_screen_test` verde.
  - 144: ok — `model_catalog_test` («Android lists 20 languages, the dictionary and karaoke; elsewhere only the dictionary»).
  - 145: ok — `external_share_text_test` e `external_share_test` verdi; `exceedsShareLimit` = più di `kMaxSharedTracks` (50, D-702) passa a m3u8; `share_fragment_test` round trip a 1 e 50 brani (eseguito in 145, non riletto qui).
  - 146: ok — `sync_two_devices_test` verde (convergono in due giri, il terzo non cambia nulla, nessun file né riga di libreria toccati).

- **Fuori piano.** 8aa0ecaa: protocollo di sync compattato prima del primo rilascio (R3/R4), esito: test di sync verdi e protocollo unico per la 1.7.0. d4a3b7ea: accessibilità (link dell'artista a 48 dp, golden aggiornati; campo di ricerca con un'etichetta sola), esito: i due test di accessibilità verdi.

**147.7 Accessibilità** (solo verifiche automatiche; Mi A3, densità 320, 48 dp = 96 px). I due test (`a11y_guidelines_test`, `accessibility_characterization_test`): 16/16 verdi. Telefono in modo aereo, quindi non raggiungibili: barra dei download (nessun download possibile) e barra alfabetica (Tutti i brani ha 7 brani, non compare).
- Testata album: Riproduci 56 dp, Casuale 48, Condividi 48, ⋮ «Altre azioni» 48, tutti con etichetta. Manca «Scarica» (assente offline, da riprovare con rete). Problema: il link artista «Tinariwen» nella testata misura 71x23 dp: corretto in d4a3b7ea (48 dp, `album_detail_screen.dart`).
- Testata playlist: Riproduci 56, Casuale 48, Condividi 48, ⋮ 48, con etichetta. «Scarica» assente (come sopra). Il campo di filtro (EditText, 328x48 dp) nel dump non aveva né testo né descrizione: corretto in d4a3b7ea (un'etichetta sola per TalkBack; con testo scritto il nome resta, corretto nella correzione pre-merge).
- Griglia del Riprendi (home): riquadri 148x66 dp con etichetta «tipo, titolo, sottotitolo»; Registro/Impostazioni 48; Riproduci/Casuale 48-50. Ok.
- Barra alfabetica: non verificata (non compare). Download bar: non verificata (offline).
- Modelli e dizionari: righe 360x72 dp con etichetta, «Elimina English» 48x48 dp, Indietro 48. Ok (verificate solo le righe della sezione Traduzione; i pulsanti «Scarica/Elimina selezionati (0)» sono disattivati e non esposti come cliccabili).
- Segnala un problema: Difetto/Idea 160x48, campi e «Allega informazioni tecniche» 328x56, «Apri su GitHub» 149x48 con etichetta. Ok.
- Avanzate e info (passato per strada): cursori 48x48 con etichetta. Ok.

## Rinvii di codice
I rilievi rimandati delle review e delle schegge 142, 144, 145 e 146 sono in [`../prossimi-lavori.md`](../prossimi-lavori.md), sezione «Dalla grande revisione (fasi 135-147)»; le prove su telefono sono sopra, in «Tocca a te».
