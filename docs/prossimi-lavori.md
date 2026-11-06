# Prossimi lavori (27 ott 2026)

Ogni comando va lanciato in una sessione nuova aperta in questa cartella; i blocchi si incollano così come sono.

## Stato al 27 ott
- Release `v1.3.0`: il tag non è ancora su `origin` (`git push origin v1.3.0`, oppure aspettare).
- Soglie di velocità della fase 38: rimisurate nella 57.5 (28/10, D-175), chiuso. Le stesse voci restano fuori come in D-57.
- Crossfade sul Mi A3 (Android 11): dopo alcuni cambi `AudioEffect: set/get parameter error` e il cambio ripiega sul caricamento normale (gap ~530 ms). Da capire con un log del player (fase 57, «Note»).
- Kickoff già fatti: streaming e coda online (#16), arricchimento completo (#26), streaming veloce (#36, fasi 55-59). Refactor ui Jam/Ricerca pianificato (#38, fasi 63-64). I piani stanno in `docs/`.

## 2. Idea: Jam a distanza (da discutere, dopo il refactor della Jam)

### Il problema
Oggi la Jam funziona solo sulla stessa rete: la scoperta è un broadcast UDP in LAN (`lib/services/share/discovery.dart`) e l'host fa da server HTTP (`JamHost.buildRouter`) che gli ospiti interrogano di continuo (`JamGuest._loop`). Su reti diverse (un amico col 4G, l'host sul Wi-Fi di casa) l'host non è raggiungibile: NAT del router e, sul 4G, NAT dell'operatore (CGNAT). La Jam in LAN resta com'è.

### Cosa fa Spotify
Due pezzi separati:
1. **Scoperta per vicinanza**: Bluetooth Low Energy (il telefono dell'host «annuncia» la Jam, quelli vicini la vedono). Serve solo a dire «qui c'è una Jam, ecco il codice».
2. **Ponte**: i server di Spotify. Tutti parlano col server, non tra loro. E suona **solo il dispositivo dell'host** (quello collegato alla cassa): gli ospiti fanno da telecomando e mettono in coda.

Il punto 2 è quello che manca a noi: senza un ponte su internet la vicinanza da sola non basta.

### Opzioni per il ponte (senza un nostro backend vero)
| Ponte | Come | Pro | Contro |
|---|---|---|---|
| **Broker MQTT pubblico** (HiveMQ, EMQX, Mosquitto pubblici) | host e ospiti si iscrivono a un canale casuale, si scambiano comandi e stato in JSON | gratis, nessun server nostro, passa da qualsiasi NAT, traffico minimo | nessuna garanzia di servizio; è pubblico → serve cifratura end-to-end con la chiave passata tramite codice/QR/BLE; messaggi piccoli (niente file audio) |
| **ntfy.sh** | uguale, via HTTP/SSE | idem, semplicissimo | limiti di frequenza, stessi contro |
| **WebRTC P2P** (STUN pubblico di Google) | collegamento diretto tra i dispositivi | anche audio, latenza bassa | ~20-30% dei casi fallisce col CGNAT senza un server TURN (che costa); pacchetto pesante |
| **Worker Cloudflare** (piano gratis, WebSocket) | piccolo relay nostro | affidabile, controllato da noi | è un backend da mantenere: va contro «standalone» |
| **Nearby Connections** (Google) | Wi-Fi Direct/Bluetooth tra telefoni vicini, senza internet | niente rete comune né internet | solo Android, niente PC |

**Consiglio**: broker MQTT pubblico con cifratura end-to-end, indirizzo del broker cambiabile nelle impostazioni (se uno smette di funzionare se ne mette un altro, o in futuro un Worker nostro senza cambiare l'app). Il protocollo attuale (`JamCommand`, `JamState` con `version`) è già fatto di messaggi piccoli: si tratta di sostituire il trasporto HTTP con pubblica/iscriviti, non di riscrivere la Jam.

### Cosa cambia nella «Jam a distanza»
- **Suona solo l'host** (scenario cassa Bluetooth). Più uscite sincronizzate e orologio comune (fase 10) restano solo in LAN.
- **I file non passano dal ponte.** Un brano dell'ospite (dalla sua libreria o da una ricerca online) arriva all'host come video id YouTube e l'host lo scarica da sé: è già il meccanismo `selfFetchable` (D-93) usato per i brani online. Per i brani locali senza video id: ricerca per titolo + artista lato host (o lato ospite prima di mandarlo).
- Scheda del brano, testo e curiosità per l'ospite: le ricava da sé dal video id/metadati, come già previsto per la Jam come player (fase 63).

### Come funziona il broker pubblico
Un broker MQTT è una bacheca su internet divisa in canali (topic, per esempio `codecore/jam/k7f3q9x2…`). Chi è iscritto a un canale riceve subito ogni messaggio che qualcuno ci pubblica. Host e ospiti non si parlano direttamente: ognuno apre **in uscita** una connessione al broker (come aprire una pagina web), quindi NAT e 4G non sono un problema. L'host pubblica lo stato (`JamState`), gli ospiti pubblicano i comandi (`JamCommand`). Chiunque conosca il nome del canale può leggere e scrivere, per questo: nome lungo e casuale + messaggi cifrati con una chiave che il broker non vede; senza chiave un estraneo legge solo byte senza senso e i suoi messaggi vengono scartati.

### Scoperta automatica, senza QR
Il QR/codice serve solo come riserva (PC, Bluetooth spento). Decisione: **si entra solo da vicini**, anche gli amici.
- **Bluetooth (come Spotify, chi è vicino)**: l'host annuncia via BLE canale e chiave; chi apre l'app vicino vede «Unisciti alla Jam di X», tocca e parte la richiesta, che l'host accetta come oggi (`JamHost.accept`). La vicinanza fisica fa da prova di fiducia. Solo Android (permessi `BLUETOOTH_ADVERTISE`/`BLUETOOTH_SCAN`); su Linux/Windows l'annuncio BLE è poco supportato da Flutter.
- **Amici memorizzati (solo vicini)**: dopo la prima Jam insieme i due dispositivi si salvano a vicenda. Non vedono la Jam da lontano: servono solo a riconoscersi quando sono vicini via Bluetooth (nome giusto, in cima alla lista, eventualmente ingresso senza conferma se l'host lo attiva). Niente canali personali sul broker.
- Il broker non sa nulla di distanze: la Jam la vede solo chi ha canale e chiave. Con il Bluetooth li riceve solo chi è a portata (~10-30 m); anche per gli amici. Un estraneo lontano può arrivarci solo se qualcuno gli gira il codice.

### Sicurezza in più con il Bluetooth
- **La chiave passa solo via Bluetooth**, mai dal broker. L'annuncio BLE classico ha 31 byte, troppo pochi per canale + chiave: l'annuncio porta un id corto e la chiave si legge con una connessione BLE breve (caratteristica GATT), o con l'annuncio esteso del Bluetooth 5.
- **Gettone che ruota**: l'host cambia il gettone annunciato ogni ~30 s e una richiesta di ingresso vale solo con un gettone recente. Un codice girato in chat o fotografato scade subito.
- **Modalità «solo vicini»** (opzionale, impostazione dell'host): l'host continua a cercare via BLE i telefoni degli ospiti; chi non si sente da qualche minuto viene messo in pausa (non può più mettere in coda) finché non torna a portata. Costa batteria, solo Android, ed entrambi devono avere il Bluetooth acceso.
- **Resta l'ultima parola all'host**: ogni ingresso va accettato, come oggi.
- Limite noto: con un'antenna potente o un «ripetitore» vicino all'host qualcuno può allungare la portata; per un'app musicale tra amici è un rischio accettabile (Spotify non fa di più).
- Scartato: scoperta per posizione (canale ricavato dalla zona GPS) — sul broker pubblico chiunque nella zona vedrebbe la Jam, serve il permesso di posizione e sui PC non funziona.

### Pacchetti nuovi (da approvare, non sono nello stack)
`mqtt_client` (ponte), `cryptography` (AES-GCM end-to-end), uno scanner QR (`mobile_scanner`), e per il BLE `flutter_blue_plus` (scansione) + `flutter_ble_peripheral` (annuncio).

### Decisioni (27 ott)
- Broker MQTT pubblico, con indirizzo cambiabile nelle impostazioni.
- Ospiti a distanza = solo telecomando: suona solo l'host.
- Si entra solo da vicini (Bluetooth), amici compresi; codice/QR come riserva.

### Richieste ripetute (anti-spam)
Oggi in LAN (`jam_host.dart`, `POST /request`): al massimo 5 richieste al minuto per indirizzo IP, una sola richiesta in attesa alla volta, scadenza dopo `jamRequestTtl`. Dopo un rifiuto però si può richiedere subito. Sul broker l'IP non si vede, quindi:
- **Massimo 2 richieste al minuto** per dispositivo (id del mittente, non più per IP). Nessuna pausa automatica dopo un rifiuto.
- Sulla richiesta, oltre ad «Accetta» e «Rifiuta», l'host può:
  - **Sospendi**: le richieste di quel dispositivo vengono scartate in silenzio per un tempo a scelta, con lo stesso selettore del timer di spegnimento (`_SleepChip` in `lib/ui/screens/now_playing/now_playing_controls.dart`, minuti a scelta).
  - **Blocca**: blocco permanente del dispositivo (lista nelle impostazioni per sbloccare).
- Valgono anche in LAN (oggi il limite è 5 al minuto per IP e mancano Sospendi e Blocca).
- Limite: l'id del dispositivo lo dichiara il mittente, quindi uno smanettone può cambiarlo; serve comunque la chiave, che arriva solo via Bluetooth e ruota ogni ~30 s, quindi deve restare vicino. Per gli amici normali basta.

### Cassa Bluetooth e modalità della coda (28 ott, idea dell'utente)
**Due casi.**
- Telefono con una **cassa** Bluetooth collegata (non cuffie né auricolari): annuncia la Jam via BLE e chi è vicino con l'app vede «Unisciti alla Jam di X». Suona solo lui, sulla cassa; gli altri fanno da telecomando e mettono in coda.
- Senza cassa: non annuncia niente, cerca soltanto. Un dispositivo qualsiasi vicino non fa apparire nessuna notifica di Jam; la Jam si avvia a mano da «Dispositivi», come oggi.

**Riconoscere la cassa**: la classe del dispositivo A2DP collegato (Android `BluetoothClass`: altoparlante, cuffie, auricolare, auto) non basta da sola, perché molte casse si presentano come auricolare o senza classe. Proposta: prima stima dalla classe, poi alla prima connessione di un dispositivo nuovo la domanda «È una cassa?», ricordata per quel dispositivo e modificabile nelle impostazioni. Serve un canale nativo Android (`BLUETOOTH_CONNECT`); solo Android, sul PC resta la Jam in LAN.

**Ruoli**: resta come oggi e come Spotify: chi tocca «Jam» chiede di unirsi alla musica dell'altro, chi accetta è l'host e porta la sua coda (`JamController.request`/`acceptRequest`, `jamSeedTracks`). Con la cassa l'host è chi ha la cassa. Da cambiare la scritta sulla scheda del dispositivo: «Unisciti a X» o «Ascolta con X» invece di «Jam».

**Due modalità della coda**
- «Coda dell'host»: la coda è dell'host, gli ospiti aggiungono (oggi, e la modalità della cassa).
- «Coda insieme»: la coda si compone a turno (uno dell'host, uno dell'ospite…) dalle due code, e anche le aggiunte dopo vanno a turno per persona.

**Dove si sceglie** (consiglio): impostazione della Jam decisa dall'host e cambiabile mentre suona (interruttore «Coda insieme» nel foglio della Coda o nell'intestazione), di serie «Coda dell'host». Motivi: chi entra dalla notifica BLE non ha dove scegliere; la voglia di mischiare spesso viene dopo; nessun passaggio in più; la coda è dell'host.
Alternativa: al tocco su «Jam» un foglio con due righe («Ascolta con X», «Coda insieme»); la scelta si vede nella richiesta e l'host la può cambiare dopo.

**Domande aperte per il kickoff**
- Dove si sceglie la modalità: nella Jam (host) o nella richiesta?
- Code di lunghezza diversa: finita una, si continua con l'altra o coi «suggeriti»?
- Conta la coda locale dell'ospite cambiata durante la Jam, o solo quella all'ingresso?
- Con più di due persone il turno vale per tutti?
- Il riordino a mano dell'host rompe il turno?
- In «Coda insieme» senza cassa suonano tutti i telefoni (come oggi) o solo l'host?
- «Sei vicino a una cassa?»: la domanda alla prima connessione va bene, o solo un'impostazione?

### Bozza del comando (quando si decide)
```
/kickoff feature Jam a distanza:
- Oltre alla Jam in LAN (che resta), una Jam che funziona anche su reti diverse: ponte su broker MQTT pubblico con cifratura end-to-end, indirizzo del broker nelle impostazioni.
- Solo telecomando: suona solo l'host.
- Scoperta automatica via Bluetooth per chi è vicino (Android), con gettone che ruota; amici memorizzati riconosciuti quando sono vicini. Codice o QR solo come riserva.
- Anti-spam: massimo 2 richieste al minuto per dispositivo; sulla richiesta «Sospendi» per un tempo a scelta (selettore come il timer di spegnimento) e «Blocca» permanente; anche in LAN.
- Suona solo l'host. Gli ospiti mettono in coda dalla propria libreria o dalla ricerca: all'host arriva il video id e scarica da sé (selfFetchable); se manca, ricerca per titolo e artista.
- Riusare JamCommand/JamState: cambiare il trasporto, non la logica.
- Casi: richieste ripetute, sospensione scaduta, broker irraggiungibile, host in sottofondo, ospite che perde la rete, codice sbagliato o scaduto, messaggi di estranei sul canale.
```

## 3. Build per macOS (29 ott, da fare dopo la chat in corso)
Un APK è solo per Android: per il Mac serve la `.app`. Il Mac non è tra le piattaforme del progetto e da Linux non si compila.
- In CI c'è già il job «macOS / iOS (trial)» (`.github/workflows/ci.yml`, `build-apple`): parte solo a mano (`workflow_dispatch`), fa `flutter build macos --debug` ma non carica il file.
- Da fare: una piccola PR che aggiunge al job il caricamento della `.app` (zip di `build/macos/Build/Products/Debug/*.app` con `actions/upload-artifact`), poi `gh workflow run ci.yml --ref master` e scaricare l'artefatto dalla run.
- La build è di debug e non firmata: al primo avvio macOS la blocca, si apre con tasto destro → Apri (o `xattr -dr com.apple.quarantine <app>`).
- Prompt: «Leggi docs/prossimi-lavori.md §3 e fammi la build per macOS».

## 4. Animazioni e superfici flottanti (4 nov, richiesta dell'utente)
Stile voluto: niente tagli netti né slide laterali; ogni schermata nuova entra a schermo intero con una dissolvenza (ease-in) e i contenuti compaiono appena caricati (skeleton); lo slide resta solo per il player. Solo trasformazioni e opacità (costo a riposo zero), durate dai token, zero con riduci movimento.

| # | Cosa | Oggi | Come | Costo |
|---|---|---|---|---|
| 1 | Ricerca in Libreria che si apre come nel mockup `libreria-ricerca.html` | sembra un cambio di schermata (`AnimatedSwitcher`) | la lente resta lo stesso widget e scivola (`AnimatedAlign`), il campo si allarga attorno a lei, titolo e icone escono con opacità e spostamento, la lista sotto sfuma come strato unico | ~1 h, **già nella fase 83** |
| 2 | Transizione fra schermate (Impostazioni e sottoimpostazioni, e tutte le altre) | slide da sinistra, fluido all'inizio e poi scatta | un `PageTransitionsTheme` unico con dissolvenza ease-in per tutte le route, tranne il player che tiene il suo slide dal basso | ~30 min, un punto solo |
| 3 | Dock (navbar) flottante | lo sfondo della pagina si taglia di netto dove tocca il dock | `extendBody` nella shell: il contenuto scorre sotto il dock ed è visibile dove il dock non copre; le liste ricevono in fondo un margine pari all'altezza del dock (una costante nella shell, non a mano per schermata) | ~1–2 h, tocca tutte le liste lunghe |
| 4 | Intestazione della Libreria flottante | intestazione piena sopra la lista | gli elementi scorrono sotto l'intestazione e restano visibili fuori dalle parti fisse (titolo, schede); va d'accordo con la striscia A–Z | ~1–2 h |
| 5 | Chiusura del player | la copertina passa da tonda a quadrata e poi torna tonda nel mini player | la copertina «in volo» resta tonda per tutta l'animazione (`flightShuttleBuilder` dell'`Hero` con lo stesso ritaglio tondo, o il raggio che interpola da tondo a tondo) | ~30–45 min |

Consiglio: 2 e 5 costano poco e si possono aggiungere alla fase 83 insieme alla 1; 3 e 4 sono un passo a sé (toccano la shell e tutte le liste), da misurare sul Mi A3 dopo (scenario «Libreria Tutto→Playlist→Album→Artisti» e scroll di Tutti i brani).

## 5. Rilievi rinviati dalla fase 88 (6 nov, review Opus e scheggia)
Fuori dal perimetro della fase. Da valutare in una fase futura.
- **Database più nuovo dell'app all'avvio normale**: se si installa sopra un APK più vecchio, drift chiama `onUpgrade(from > to)`, salta le migrazioni e abbassa `user_version`. Al prossimo aggiornamento le migrazioni ripartono su colonne già presenti e l'app va in crash. Rimedio: una guardia `from > to` in `onUpgrade`/`beforeOpen` di `app_database.dart`, con un messaggio chiaro invece del crash. Il ripristino è già protetto (88.5b).
- **Una sola chiave per «stesso brano»**: `LibraryIndex` e `LibraryOverlap` usano `libraryTitleKey` più l'insieme delle parole dell'artista, mentre `TrackResolver`, `SeedIndex.keyOf`, `import_diff` e `playlist_import_service` usano ancora `matchTitleKey` più l'artista principale. Unificarle eviterebbe che la sincronizzazione delle playlist riaggiunga un brano già collegato.
- **Credito annidato troppo largo**: «Prince» contro «Prince Royce», con lo stesso titolo e una durata entro 5 s, risulta posseduto. È raro (serve un titolo generico identico). Rimedio possibile: l'artista più corto deve essere il prefisso dell'altro e avere almeno 2 parole non comuni.
- **Remaster con live**: «Song (Remastered Live)» e «Song - 2011 Remaster - Live» coincidono con «Song», perché `_remasterGroup` e `_remasterTail` in `matchTitleKey` tolgono anche «Live» (comportamento precedente alla fase 88).
- **Parentesi non chiuse**: «Song (Deluxe Edition» e «Song - Deluxe Edition - Remix» non vengono ripuliti, quindi lo stesso brano non viene riconosciuto (falso negativo, innocuo).
