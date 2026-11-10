# Fase 67 — Jam della cassa (feature «Jam: cassa e coda insieme»)

**Obiettivo:** su Android, quando si collega una cassa Bluetooth il telefono apre e annuncia da sé una Jam in LAN in cui suona solo lui; gli altri la vedono in un banner e chiedono di entrare.

**Prerequisiti:** fase 65 chiusa (la 66 non serve: la Jam della cassa vale in entrambe le modalità). Requisiti R-107 … R-116 e R-119; decisioni D-190, D-191, D-196 … D-203, D-211, D-212, D-215. Aree a rischio: protocollo Jam, lato nativo e manifest. Nessun pacchetto nuovo.

**Comando mirato:** `flutter test test/jam test/services/audio test/services/share test/ui/app_shell_test.dart test/ui/jam_screen_test.dart test/ui/settings_index_test.dart`; build `flutter build apk --debug` quando si tocca il lato nativo (con `sorveglia.sh --pesante`).

## Task

### 67.1 — Uscite Bluetooth dal lato nativo (R-107)
`MainActivity.kt`, canale `codecore/audio`: metodo `bluetoothOutputs` (nome, indirizzo, classe dei dispositivi A2DP collegati, dal proxy `BluetoothProfile.A2DP`) e chiamata verso Dart a ogni collegamento o scollegamento (`BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED` registrato a runtime). Senza permesso: elenco vuoto e un campo `permission: false`, mai un'eccezione. Manifest: `BLUETOOTH` (`maxSdkVersion 30`) e `BLUETOOTH_CONNECT`.

**Fatto quando:** test Dart del lato Dart del canale con un finto `MethodChannel`; build di debug verde; sul Motorola `adb logcat` mostra l'evento collegando le cuffie JBL.

### 67.2 — Permesso e «È una cassa?» (R-108, R-109, D-201, D-202, D-212)
`lib/services/audio/speaker_monitor.dart`: stima dalla classe (tabella di D-212), risposta salvata per indirizzo in shared_preferences, domanda «È una cassa?» per un dispositivo nuovo alla connessione o alla prossima apertura se è ancora collegato. Alla prima uscita Bluetooth vista (`AudioDeviceCallback`, già nel canale, senza permessi) foglio che spiega e chiede `BLUETOOTH_CONNECT`; rifiutato → niente Jam sulla cassa, «Chiesto» salvato.

**Fatto quando:** test della stima per ogni classe; test: domanda una sola volta, risposta riletta al riavvio, app in sottofondo → domanda alla riapertura; test widget dei due fogli.

### 67.3 — Impostazioni «Jam sulla cassa» (R-110, D-203)
Nelle impostazioni della Jam: interruttore acceso di serie, lista dei dispositivi segnati (nome, sì/no, cambio), riga per riattivare il permesso se rifiutato. Stringhe ARB it/en/de/es.

**Fatto quando:** test widget dell'interruttore, della lista e del cambio; `settings_index_test` aggiornato.

### 67.4 — Jam aperta da sé e annunciata (R-111, R-113, R-115, D-196, D-211)
`JamController.openSpeakerJam()` (chiamato da `SpeakerJam` tramite `port.open`): da fermo entra nello stato «in attesa» (D-226), solo l'annuncio, player, UI e servizio intatti; la Jam vera, con `speaker = true` e uscita = solo l'host (invariante 4), nasce alla prima richiesta accettata con la coda di quel momento; da host con Jam attiva `JamHost.makeSpeaker()`. Il pacchetto di scoperta (`discovery.dart`) porta `jam: {name}` finché la Jam della cassa è aperta. Senza ospiti, lo scollegamento la chiude in silenzio.

**Fatto quando:** test: evento «cassa collegata» + interruttore acceso → Jam aperta e campo `jam` nel pacchetto; interruttore spento → niente; scollegamento senza ospiti → chiusa senza messaggi; nessuna uscita diversa dall'host accettata con `speaker = true`.

### 67.5 — Banner e «Dispositivi» (R-112, R-116, D-197, D-198)
Banner «Unisciti alla Jam di X» sopra il mini player (si chiude con ✕, non torna per la stessa Jam) e riga in cima al foglio «Dispositivi», su Android, Linux e Windows; il tocco chiama `JamController.request` e l'host accetta o rifiuta come oggi. Il banner sparisce quando l'annuncio cessa.

**Fatto quando:** test widget del banner (comparsa, ✕, scomparsa con l'annuncio) e della riga; test che il tocco manda la richiesta; RNF-13 controllato in 68.2.

### 67.6 — Cassa assente (R-114, D-199)
Lo scollegamento a Jam con ospiti → comando `speakerAway` dall'host: pausa, `speakerAwaySince`, play/seek/next/jump/previous rifiutati con `noSpeaker` e avviso «Collega una cassa» su tutti; aggiunte e rimozioni accettate. Una cassa (qualsiasi segnata) che si ricollega → `speakerBack`. Dopo 10 minuti senza cassa l'host manda `end`.

**Fatto quando:** test del reducer per ogni comando con la cassa assente; test con orologio finto per lo sblocco e per la fine a 10 minuti; test widget dell'avviso.

### 67.7 — La cassa di un ospite salva la Jam ferma (R-119, D-219, D-220)
Con `speakerAwaySince != null`, un ospite il cui `SpeakerMonitor` vede una cassa collegata riceve il foglio «Suonare la Jam sulla tua cassa?»; sì → comando `offerSpeaker` dall'ospite, accettato solo con `speaker && speakerAwaySince != null`: in un colpo solo uscite = [ospite] e `speakerAwaySince = null`; se la Jam non è ferma l'host risponde 409 `no speaker` (`JamError.noSpeaker`). L'uscita resta all'ospite anche se torna la cassa dell'host; cassa dell'ospite sparita o ospite uscito → di nuovo `speakerAway`.

**Fatto quando:** test host+ospite in memoria per offerta accettata, offerta con cassa presente (rifiutata, nessun foglio), cassa dell'host che torna, uscita dell'ospite-uscita; test widget del foglio.

### 67.8 — Controlli di fase
`flutter analyze`, comando mirato, build di debug, `/code-review high` su protocollo e lato nativo, scheggia in modalità passo su 67.4 e 67.6, review di architettura Opus. Prova sul Motorola con le cuffie JBL segnate come cassa («È una cassa?» → Sì): Jam aperta e annunciata (in autonomia solo verso il Mi A3 come osservatore, D-91: la Jam vera in 68.3).

**Fatto quando:** tutto verde; colonna Fase di R-107 … R-116 e R-119 compilata.
