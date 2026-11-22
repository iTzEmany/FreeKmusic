# Grande revisione (refactor «tutto») — analisi

> Giro 1 del `/refactor`, 22/11/2026. Richiesta originale: [`richiesta.md`](richiesta.md).
> Scansioni di dettaglio: [`scansione-dati.md`](scansione-dati.md), [`scansione-ui.md`](scansione-ui.md), [`scansione-streaming.md`](scansione-streaming.md), [`scansione-arricchimento.md`](scansione-arricchimento.md), [`ricerca-condivisione-segnalazioni.md`](ricerca-condivisione-segnalazioni.md).

## Perimetro e punto di partenza
- **Tipo**: misto. Bug, ritocchi di UI e cambi di comportamento chiesti dall'utente (deroga alla regola «il comportamento non cambia»: ogni cambio va in `decisioni.md`).
- **Versione**: 1.6.4, `master` a c0db2783, schema DB v20 (`kSchemaVersion`), ultima decisione D-661, ultima fase 134.
- **Dispositivo di prova**: Motorola edge 40 (ZY22HKD85K), il telefono dell'utente, app release 1.6.4 (non debuggable). Il log si esporta da Impostazioni › Avanzate › Esporta log; logcat non serve.

## Prove dal log del telefono (12-22/11)
| # | Cosa | Prova | Conclusione |
|---|---|---|---|
| L1 | Brani locali «non riproducibili» | Per `com.freekmusic.player` risulta `READ_MEDIA_AUDIO granted=false` (senza USER_SET). I 2328 file di `Music/FreeKmusic` appartengono a `com.android.shell` (caricati via adb; uid vecchio 10332, app attuale 10452 installata il 12/11). Dal 21/11 15:15 ogni file locale dà «load failed … (0) Source error»; fino al 19/11 «from=file» funzionava. | Il permesso è stato revocato o reimpostato (perché non si sa). L'app non se ne accorge e lo presenta come «brano non riproducibile». |
| L2 | Daylist: primo brano non riproducibile (22/11 13:53) | «Peter Gabriel - Solsbury Hill.mp3»: il file esiste, stesso Source error | Stessa causa di L1. La daylist non c'entra. |
| L3 | Raffica di popup alla riapertura | 21/11 15:15 e 22/11 00:00: all'avvio la coda ripristinata prova un brano ogni ~3 s (Roy Buchanan, d4vd, Nina Simone, Thriller) e ogni tentativo fallisce. | Non è colpa del link Spotify: la coda ripristinata contiene file illeggibili (L1) e a ogni errore l'app passa al brano dopo, con un popup per brano (F-03). |
| L4 | Separazione karaoke all'avvio | 38 volte «separation: karaoke:local:N failed … cannot open the audio», anche subito dopo «avvio» | Il karaoke acceso separa il brano ripristinato anche se non suona (F-05). Quindi alla riapertura il karaoke NON è spento: da riprodurre (F-06). |
| L5 | «Correzione salvata, file non aggiornato» | 14 volte «tags of stream:youtube:… not written: unsupported» e 4 volte «not written: readOnly» | Il titolo nel DB si salva. Il messaggio riguarda il file: righe stream senza file (tentativo inutile) e file di proprietà della shell (scoped storage) (F-04). |
| L6 | Arricchimento | 86 risposte 503 da musicbrainz.org e 6 successi; 37 volte «artist countries: service refused»; 82 volte «enrichment: track 0»; `row=2484` arricchita 6 volte | MusicBrainz senza coda né pausa, righe stream rifatte a ogni ascolto (F-10..F-13). |
| L7 | Backup e ripristino | Nessuna riga nel log | Non verificabile dal log. Si spiega dal codice (F-07). |

## Rilievi in ordine di priorità
Formato: `F-NN · area · titolo · dove · prova · danno · impatto/rischio/costo · proposta`.

### Priorità 1 — l'app non suona o mente (bug)
- **F-01** · riproduzione · Permesso audio revocato non rilevato · `core/permissions.dart` (chiesto solo in onboarding e in `folder_actions.dart:14`); `just_audio_backend.dart:136-150`; `codecore_audio_handler.dart:770-772` · L1, L2 · nessun file locale suona e il messaggio è sbagliato · A/M/M · nuovo motivo `permissionDenied`: si ferma la coda, un solo avviso con «Concedi», controllo al ritorno nell'app. Correggere anche `ensureAudioPermission`, che chiede `storage`, sempre negato su Android 13+.
- **F-02** · riproduzione · Non c'è un'azione per riavere il permesso · onboarding e impostazioni · L1 · l'utente non sa cosa fare · A/B/S · voce in Impostazioni › Libreria e avviso sulla home quando manca il permesso.
- **F-03** · riproduzione · Raffica di popup al ripristino · `main.dart:313-326` → `playback_persistence.dart:49-75` → `_loadCurrent(play:false)` (:530-536) → `_failAndSkip` (:1112-1135, `maxConsecutiveErrors=3` con controllo `>`, quindi 4 errori) → `app_shell.dart:301-306` (un popup per errore) · L3 · popup a catena e coda che avanza da sola · A/M/S-M · al ripristino a freddo niente salto e niente popup; errori di fila riuniti in un solo messaggio «N brani non riproducibili». Rivedere D-66.
- **F-04** · correzioni · «Correzione salvata, file non aggiornato» sempre · `track_corrections.dart:58-60, 218-225, 244-249`; `track_editor.dart:95-98` · L5 · sembra che la correzione non funzioni · A/B/S · `_fileWanted` salta `kind == stream`; `_fileBlock` prima di `fileIds`; correzioni automatiche su file non scrivibili solo nel log. Verificare sul telefono che il titolo cambi davvero in libreria.
- **F-05** · karaoke · Separazione all'avvio senza riproduzione · `karaoke_providers.dart:~300-440` (`karaokeAutoProvider`, `pump()` all'avvio) · L4 · batteria e errori a vuoto · M/B/S · separare solo dopo il primo play.
- **F-06** · karaoke · «Si spegne quando chiudo l'app» · `settings_store.dart:526,622` (salvato, ma con un debounce di 400 ms) · L4 dice il contrario · M/B/S · riprodurre sul telefono; scrivere `karaokeOn` subito, senza debounce.

### Priorità 2 — backup, ripristino, aggiornamento
- **F-07** · backup · Il ripristino «Sostituisci» non si applica · `backup_ops.dart:46`, `main.dart:117`, `backup_section.dart:107-117` (`SystemNavigator.pop()` chiude solo l'Activity, il processo resta vivo; su desktop si chiude solo il dialogo) · codice · l'utente crede che il ripristino non funzioni · A/M/M · riavvio vero: Android tramite canale nativo (servizi fermati, `getLaunchIntentForPackage`, `killProcess`); desktop riusando `DesktopUpdate` (desktop_update.dart:42,60).
- **F-08** · backup · «Le playlist non ci sono» · `backup_service.dart:150-195` (ci sono già); `mergeBackup` salta i brani locali non riconosciuti · codice · playlist vuote dopo «Unisci» · A/B/S · dire cosa porta il backup; portare in Backup anche «Esporta/Importa playlist» (unico punto); dopo «Unisci» elencare i brani non trovati con «Cerca online / salva in streaming».
- **F-09** · aggiornamento · Toccare il popup della nuova versione non fa nulla · `update_tiles.dart:33-46` (apre `UpdateDialog` solo l'azione «Aggiorna»); `update_providers.dart:55-58` segna il giorno come controllato prima del controllo · codice · M/B/S · tocco su tutto il popup che apre il dialogo di aggiornamento; segnare il giorno solo a controllo riuscito.

### Priorità 3 — arricchimento (manuale ≠ automatico, verificato)
Oggi ci sono tre percorsi, non due: `EnrichEngine` (automatico e batch manuale, corretto), il vecchio `EnrichmentService` (anteprima, stream, seconda opinione, mai portato sul motore unico come voleva D-280) e `TrackCorrections`.
- **F-10** · MusicBrainz senza coda né cooldown · `musicbrainz_client.dart:96-128` · L6 · MB inutilizzabile · A/A/S · coda unica nel client più cooldown di 1, 5 e poi 15 minuti dopo un 503.
- **F-11** · 503 non contato come «limitato» · `credits_enricher.dart:63-80`, `enrich_runner.dart:395-402`, `artist_country_finder.dart:89` · L6 (37 riavvii) · A/A/S · `MusicBrainzUnavailable` → `limited`; il finder dei paesi rispetta il cooldown.
- **F-12** · Righe stream rifatte a ogni ascolto, su un secondo motore · `stream_providers.dart:77-133`; `synthetic_track.dart:12-14` (id 0); `enrichment_service.dart:100` (crediti MB a ogni ascolto) · L6 · richieste inutili; titolo e artista sovrascritti senza anteprima · A/A/M · le righe stream passano da `engine.completeOne(row.id, autoParts)`: segni «niente», status, deduplica, solo campi vuoti, rispetto degli switch automatici.
- **F-13** · Troppe richieste MB per brano (ISRC fino a 4 volte, Deezer 2) · `track_recognizer.dart:258`, `credits_enricher.dart:108,158`, `curiosity_finder.dart:163` · M/M/M · cache in memoria (anche dei «non trovato») con scadenza; riuso del risultato ISRC.
- **F-14** · Il completer ignora rete a consumo e Jam · `startup_providers.dart:35-55` contro `artist_country_providers.dart:40-44` · M/B/S · stesso controllo.
- **F-15** · Brani strumentali · non esiste nessun campo; `lrclib_client.dart` scarta `instrumental: true` · nuovo · M/M/M · salvare il flag (lrclib, con euristiche su genere e titolo come ripiego) e saltare testi, curiosità sul testo e karaoke.

### Priorità 4 — download, menu, «streaming per prima»
- **F-16** · Menu ⋮ che non si aggiorna · `track_actions.dart:409-439` (cattura il `Track`, ascolta solo `downloadIndexProvider`); `player_providers.dart:1025-1040` (l'id resta negativo dopo il download, quindi menu online per sempre) · codice · A/M/M · un `trackStateProvider` vivo (online / salvato / scaricato) per menu e player.
- **F-17** · Nessun avanzamento del download nel player · `suggested_info.dart:16-113` (non osserva `downloadsProvider`); tre implementazioni dello stesso stato (suggested_info, online_song_row:325, track_actions:286) · M/M/M · un `DownloadBar` condiviso che sostituisce i pulsanti.
- **F-18** · Default «streaming per prima» · `StorageMode` (settings_store.dart:34) esiste già (D-596..D-607); oggi un utente nuovo parte `device` (onboarding_pages.dart:~255) · A/M/S · `stream` di default per i nuovi utenti con YouTube attivo; chi aggiorna resta com'è (D-598); `lite` resta `device`.
- **F-19** · Una cartella sola (sorgente e download) · `folders` contro `downloadLocation` (settings_store.dart:73, platform.dart:64), collegate solo da `libraryFolderFor` (youtube_providers.dart:128) · M/M/M · una scelta in onboarding che scrive entrambe.
- **F-20** · Import con «scarica anche» e processi indipendenti · oggi decide la modalità globale (import_providers.dart:63-66) · M/M/M · `ImportOptions.downloadToo` nel dialogo; azione «Scarica» di massa (riusa `keep_offline`) che scarica i brani già arricchiti.
- **F-21** · Online: «Aggiungi alla libreria» al posto di «Aggiungi alla playlist» · `suggested_info.dart`, `online_song_row.dart` · S · «Aggiungi alla playlist» resta nel menu ⋮.
- **F-22** · Album con i brani non salvati · `AlbumDetailScreen` mostra solo la libreria (library_queries.dart:283); `OnlineAlbumScreen` esiste già · M/M/M · salvare il `browseId` dell'album quando si salva da YouTube Music e mostrare sotto i brani in libreria quelli mancanti, ascoltabili e salvabili. Ripiego: ricerca dell'album.
- **F-23** · Incongruenze di stato: riga ombra con «Aggiungi alla libreria» e «Scarica» insieme (track_actions.dart:264-290); il download tiene l'id solo se il file è in cache; «Scarica album» in modalità stream salva soltanto (online_album_screen.dart:72) · M/M/M · da sistemare insieme a F-16.
- **F-24** · Jam: l'ospite non può salvare un brano · jam_queue_sheet.dart (nessuna azione) · M/M/M · brano online: flusso «aggiungi alla libreria»; brano locale dell'host: copia da `JamCache` più scan (se la cache ce l'ha).

### Priorità 5 — UI richiesta (quasi tutto S)
- **F-25** · Barre di ricerca: niente tastiera automatica · `library_screen.dart:259,330`, `app_shell.dart:122,160-164`, `playlist_sheet.dart:152` · S.
- **F-26** · Tutti i brani: icone tolte dai blocchi di ordinamento (`all_tracks_screen.dart:295-307`) e sfondo opaco dell'intestazione (`ShrinkingHeader(color: cc.bg)`, :271-273). Stesso problema in `CollectionScaffold` (collection_header.dart:93-105) · S.
- **F-27** · Home: superficie per «Aggiunti da poco» con l'intestazione dentro; `HomeBlock(header:)` per tutte le sezioni · S.
- **F-28** · Anteprima del tema senza immagine · `theme_editor_screen.dart:395-421` → riusare `AppBackground` · M.
- **F-29** · Card daylist: l'effetto del tocco non copre il tasto play · `daylist_card.dart:38-100` · S.
- **F-30** · Fogli non a tutta larghezza · `app_theme.dart:151` (`maxWidth: 560` senza `minWidth`) → un solo fix in `showCcSheet` (cc_sheet.dart:11-31); elenco di 26 fogli in scansione-ui.md; `devices_sheet.dart:35-41` perde il tetto della larghezza · S.
- **F-31** · Registro: «Come risolvere» fa la stessa cosa del tocco sulla riga (activity_log_entry.dart:400-407) · S.
- **F-32** · Registro: «Ferma tutto» e «Annulla tutto» per le importazioni (oggi si fa solo una alla volta, playlist_import_service.dart:1223-1240) · M.
- **F-33** · Import: «Seleziona tutto» e «Deseleziona tutto» come due pulsanti (playlist_source_sheet.dart:160-176; import_plan_screen.dart:44) · S.
- **F-34** · Pagina playlist e album: Riproduci e Casuale come sole icone, più Condividi e Scarica sulla stessa riga (collection_header.dart:82-89, usato da 8 schermate) · M.
- **F-35** · Barra di scorrimento laterale · `AlphaScroller` esiste ma si vede solo in Tutti i brani ordinati per titolo o artista · M · modalità «per posizione» sopra circa 100 elementi; in libreria, preferiti, playlist, album e artisti.
- **F-36** · «Riprendi» a griglia per macroarea · resume_rows.dart:57-185; dati in `Plays.context` · L · query «ultimo per macroarea», kind daylist (oggi la daylist parte come `library`, daylist_providers.dart:394), riquadri nello stile dell'app.

### Priorità 6 — funzioni nuove
- **F-37** · Preferiti per album e playlist · solo `tracks.isFavorite` · M · tabella `favorite_collections(kind, key)` (migrazione), sezioni in Preferiti, backup e sync.
- **F-38** · Modelli e dizionari da scegliere nelle Impostazioni (richiesta del 22/11, seconda) · oggi: 20 lingue ML Kit (`translationLanguages`, lyrics_translator.dart:4; circa 30 MB ciascuna, solo Android) scaricabili solo dal testo; in Impostazioni solo l'elenco di quelle scaricate con «cancella» (translation_models_tiles.dart); dizionario cinese CEDICT con una voce propria (chinese_dictionary_tile.dart); modello karaoke Spleeter (separation_service.dart:14-22) scaricato al primo uso · M · una pagina «Modelli e dizionari» con l'elenco completo, dimensioni, caselle, «Scarica selezionati», «Elimina» e lo spazio occupato.
- **F-39** · Condivisione verso WhatsApp e simili · oggi non esiste (`share_plus` assente; «Condividi…» è il trasferimento LAN) · M · testo con link YouTube Music più un link https a una pagina statica su GitHub Pages (dati nel frammento `#`, nessun server) che apre l'app se c'è (App Link); file m3u8 per le playlist lunghe.
- **F-40** · Segnalazione bug · `report_issue_screen.dart` (8 difetti elencati in scansione-ui.md §12); invio solo come issue GitHub (issue_report.dart:107) · M · schermata ridisegnata, «Segnala» dal Registro con i dati precompilati, invio anonimo tramite Cloudflare Worker → issue GitHub (0 €, nessun segreto nell'APK) oppure Web3Forms (più semplice). Ripiego senza servizi: email o testo da condividere.
- **F-41** · Sincronizzazione tra i propri dispositivi · base esistente (pairing con PIN, `TrustedDevices`, `/sync/playlists`, `planSync`, `mergeBackup`, MQTT cifrato) · L, rischio A · relazione «dispositivi miei», sync completo in LAN (playlist, preferiti, impostazioni non legate al dispositivo, testi, tag, ascolti), poi tombstone per le cancellazioni, poi MQTT fuori casa.

## Sintesi per area
- **Riproduzione**: i tre bug più visibili (daylist, popup, «non riproducibile») hanno una sola causa, il permesso revocato, che il codice non gestisce. Si corregge con poco codice, ma nell'handler, che è un'area a rischio.
- **Arricchimento**: non è un'impressione, è davvero non ottimizzato. MusicBrainz quasi sempre rifiutato; i brani stream su un motore vecchio che ignora gli switch e si ripete. La strada c'era già (D-280) e non è stata finita.
- **Streaming per prima**: il modello dati c'è già quasi tutto. Il lavoro vero è UI (menu vivo, avanzamento, album completo) e default; nessuna migrazione dei 2384 brani locali.
- **UI**: una dozzina di ritocchi da poco, uno grosso (Riprendi a griglia).
- **Funzioni nuove**: condivisione e segnalazione anonima chiedono un pezzo fuori dall'app (pagina statica, Worker), in tensione con «nessun backend»; il sync è il lavoro più grande e più rischioso.

## Contraddizioni e tensioni nella richiesta
1. **«Il backup non comprende le playlist»**: le comprende già. Spariscono solo con «Unisci» quando i brani locali non si trovano (F-08). Va cambiato il modo in cui si presenta, non il contenuto.
2. **«Correzione salvata, brano non aggiornato»**: il testo vero dice «file non aggiornato» e la correzione nel DB avviene. Il difetto è il messaggio (e il tentativo inutile sulle righe stream), non la correzione (F-04). Da verificare sul telefono.
3. **«Il karaoke si spegne quando chiudo l'app»** contro **«promemoria se non lo uso, per la batteria»**: le due cose si tengono solo se il karaoke resta acceso alla riapertura. Il log mostra che è già acceso all'avvio (separa da solo). Serve riprodurre il caso; la proposta è che resti acceso, separi solo quando si suona, e il promemoria proponga di spegnerlo.
4. **Il «+» della nuova playlist fra le «barre di ricerca»**: lì il campo è il nome della playlist. Senza focus automatico serve un tocco in più prima di scrivere. Va confermato.
5. **«Scarica» e «Aggiungi alla playlist» diventano una barra di download** contro **«Aggiungi alla libreria» al posto di «Aggiungi alla playlist»** e **«tutto in streaming»**: con lo streaming per prima, «Aggiungi alla libreria» non scarica nulla, quindi la barra vale solo per «Scarica». «Aggiungi alla playlist» non sparisce: passa nel menu ⋮.
6. **«Tutto in streaming»** contro **i 2384 brani locali e la regola «chi aggiorna resta com'è» (D-598)**: il default cambia solo per i nuovi utenti. Per chi ha già l'app (tu compreso) ci vuole un interruttore. Inoltre alcune funzioni escludono le righe stream (condivisione LAN, export delle playlist, Android Auto, sync dei file) e nella `lite` lo streaming non c'è.
7. **«Una sola cartella sia sorgente sia download»** contro **Android**: scegliere una cartella qualsiasi come destinazione dei download su Android 11+ passa da MediaStore/SAF. Oggi si scarica in `Music/FreeKmusic`. Una cartella libera costa di più; `Music/FreeKmusic` come default più la scansione della cartella scelta è più semplice.
8. **«Sincronizzazione: stesse identiche cose»** contro **l'invariante «mai cancellare righe dell'utente in automatico»** e il sync attuale che non cancella mai: per avere dispositivi identici le cancellazioni devono viaggiare (tombstone). Va deciso se il sync può cancellare.
9. **«Endpoint unico anonimo per le segnalazioni»** e **«link condivisibili su WhatsApp»** contro **«app standalone, nessun backend»**: servono un Worker (segnalazioni) e una pagina statica (condivisione). Sono gratuiti e senza dati personali, ma sono pezzi fuori dall'app. Va accettata l'eccezione.
10. **Condivisione**: `share_plus` non è fra i pacchetti ammessi. Serve un sì per aggiungerlo, oppure un canale nativo `ACTION_SEND` su Android più gli appunti su desktop.
11. **«Riprendi» a griglia** contro **ciò che oggi c'è nel Riprendi** (nuove uscite, coda, brani lunghi da riprendere): va deciso dove finiscono le nuove uscite.
12. **«Togliere la superficie ai filtri di Tutti i brani»** e **«aggiungerla ad Aggiunti da poco»**: non è una contraddizione (lista contro blocco della home), ma va scelta una regola unica per le superfici, altrimenti tra qualche mese si torna indietro.
13. **Il problema del permesso è legato al tuo telefono**: i file li hai caricati via adb e appartengono alla shell. Anche dopo la correzione, l'app potrà leggerli solo con il permesso concesso, e non potrà scriverci i tag senza «accesso a tutti i file». Non è una contraddizione della richiesta, ma cambia cosa aspettarsi da F-04.

## Proposta di fasi (da confermare al giro 5)
| Fase | Nome | Rilievi | Peso |
|---|---|---|---|
| 135 | Riproduzione affidabile | F-01, F-02, F-03, F-05, F-06, F-04 | M |
| 136 | Arricchimento unico e leggero | F-10..F-15 | L |
| 137 | Backup, ripristino, aggiornamento | F-07, F-08, F-09 | M |
| 138 | Ritocchi di UI | F-25..F-31, F-33 | M |
| 139 | Stato vivo del brano e download | F-16, F-17, F-21, F-23 | M |
| 140 | Streaming per prima | F-18, F-19, F-20, F-22, F-24 | L |
| 141 | Collezioni: intestazione, preferiti, scorrimento | F-34, F-35, F-37 | L |
| 142 | Home: Riprendi a griglia | F-36 | M |
| 143 | Registro e segnalazioni | F-32, F-40 | M |
| 144 | Modelli e dizionari | F-38 | S-M |
| 145 | Condivisione esterna | F-39 | M |
| 146 | Sincronizzazione tra dispositivi | F-41 | L |
| 147 | Verifica finale sul telefono e misure | tutti | S |

## Scelte
Giro 2, 22/11, tutte dell'utente: D-662..D-691 in `docs/decisioni.md`.
- **Affrontati**: tutti i rilievi F-01..F-41, nell'ordine di D-672 (fasi 135→147).
- **Cambi di comportamento**:
  - Streaming per prima per TUTTI (D-665): i file locali restano locali, nessun download automatico, scaricare è sempre una scelta. Brani stream in condivisione LAN, export e Android Auto (D-674).
  - Cartella dei download fissa `Music/FreeKmusic`, dentro la cartella scansionata (D-666).
  - Niente tastiera automatica, nemmeno nel «+» della playlist (D-667).
  - Karaoke acceso alla riapertura con promemoria (D-664, D-685).
  - Errori di caricamento senza raffica (D-679, cambia D-66). Riavvio automatico dopo il ripristino (D-680).
  - Arricchimento: un solo motore; con rete a consumo decide un'impostazione nuova (D-683).
  - Strumentali (D-684). Superfici (D-687). Scorrimento «per posizione» (D-688). Daylist come contesto proprio (D-689).
  - Intestazione a icone in tutte e 8 le collezioni (D-676); «Condividi» = link esterno, LAN nel menu ⋮ (D-677).
  - La Jam permette di salvare i brani (D-690). Il sync propaga le cancellazioni tra i «miei» dispositivi (D-668).
- **Eccezioni alle regole del progetto**:
  - Cloudflare Worker per le segnalazioni anonime e GitHub Pages per i link (D-669, D-691); account e messa online si fanno insieme all'utente.
  - Pacchetto nuovo `share_plus` (D-670).
  - Il sync cancella fra i «miei» dispositivi (D-668).
- **Migrazioni**: ognuna nella sua fase (D-675): 136 strumentale, 140 browseId, 141 preferiti di album e playlist, 146 tombstone.
- **Intoccabili**: chiavi salvate (`artistKey`, `PlayContextKind`: solo valori nuovi in coda); nomi interni `codecore` (D-539); file locali mai cancellati né spostati; versione `lite` senza streaming; nessuna telemetria (gli invii partono solo da un tasto); D-24 (la UI parla solo con i provider); aree a rischio con `/code-review high` (handler audio, query su `tracks`, backup e ripristino, `EnrichEngine`, protocollo Jam).

## Arrivo
Giro 3, 22/11: direzione = stile attuale dell'app (D-692); mockup approvati (D-693) in [`mockup/`](mockup/index.html):
- `home.html` (F-27, F-29, F-36): griglia del Riprendi a 2 colonne sul telefono e 3 su desktop, riquadri `surface2` con raggio 12 e icona della macroarea; Nuove uscite in un blocco proprio; intestazioni dentro le superfici.
- `collezione.html` (F-22, F-26, F-34, F-35): testata a icone (Riproduci 56 px in accento; Casuale, Condividi, Scarica e ⋮ a 48 px), «Altri brani dell'album», scorrimento laterale (D-694: sottile, compare mentre si scorre, si allarga al tocco).
- `modelli-dizionari.html` (F-38). `segnalazione.html` (F-30..F-33, F-40). `player-download.html` (F-16, F-17, F-21; D-695..D-697).
- Testi e dimensioni inventati nei mockup (CEDICT circa 10 MB, karaoke 2×39 MB, testi delle spiegazioni): `/obiettivo` li ricava dal codice e dagli ARB veri.

Struttura di arrivo (nessun cambio di livelli):
- **Arricchimento**: un motore unico, `EnrichEngine`, con due modi (D-683). `EnrichmentService` resta solo come lettura per l'anteprima, poi si toglie. `MusicBrainzClient` con coda, cooldown e cache.
- **Stato del brano**: un provider unico (online / salvato in streaming / scaricato) che leggono menu, player e righe. Un `DownloadBar` condiviso al posto delle tre implementazioni attuali.
- **Riproduzione**: motivo `permissionDenied` e politica degli errori (D-678, D-679) dentro l'handler (area a rischio, `/code-review high`).
- **Riavvio**: un canale nativo `restart` (Android) e il riuso di `DesktopUpdate` (desktop).
- **Fogli**: `minWidth` in `showCcSheet`. Superfici: `HomeBlock(header:)`; `ShrinkingHeader` e `CollectionScaffold` senza colore opaco.
- **Servizi esterni** (D-669): Worker e pagina Pages in `tools/` o in un repo a parte, da decidere nella fase 143/145 con l'utente.

## Rete
Giro 4: test di caratterizzazione per fase, test nuovi, golden, metriche di arrivo e prove sul Motorola in [`rete.md`](rete.md). Schema di oggi v20, migrazioni v21-v24 (D-675).
